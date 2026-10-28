import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { pathToFileURL } from "node:url";
import { candidateDigest, rubricHash, scoreReceipts, markdown } from "./score.mjs";
import { writeReceipt, fileEvidenceReader } from "./evidence.mjs";
import { assertRuntimeIdentity, assertResponseIdentity, assertMoveResult } from "./integrity.mjs";
export async function collectLive({ outDir, runtimeFile } = {}) {
  const runtime = JSON.parse(readFileSync(runtimeFile, "utf8")),
    agent = JSON.parse(readFileSync(join(outDir, "agent.receipt.json"), "utf8")),
    journey = JSON.parse(readFileSync(join(outDir, "agent.trace.json"), "utf8")),
    digest = candidateDigest();
  assertRuntimeIdentity(runtime, digest, rubricHash());
  if (agent.candidate_digest !== digest || agent.runtime_id !== runtime.runtime_id)
    throw Error("agent evidence belongs to another runtime/candidate");
  if (journey.failure) throw Error("agent journey failed; cannot promote downstream evidence");
  const base = {
    ...agent,
    checks: undefined,
    kind: undefined,
    meta: undefined,
    artifacts: undefined,
    finished_at: new Date().toISOString(),
  };
  let requestId = 1000;
  async function rpc(name, args) {
    const response = await fetch(runtime.url + "/mcp/maps", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${runtime.bearer}`,
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        "MCP-Protocol-Version": "2025-11-25",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: ++requestId,
        method: "tools/call",
        params: { name, arguments: args },
      }),
      signal: AbortSignal.timeout(100000),
    });
    assertResponseIdentity(response.headers, runtime);
    const body = await response.json();
    if (body.error) throw Error(body.error.message);
    return body.result.structuredContent;
  }
  const map = journey.lastSnapshot,
    stops = map.days.flatMap((d) => d.stops),
    candidates = journey.trace
      .filter((t) => t.name === "search_places" && t.output.ok)
      .flatMap((t) => t.output.data.queries)
      .flatMap((q) => q.candidates);
  const placeByRef = new Map(candidates.map((p) => [p.place_ref, p]));
  const cacheDir = join(dirname(runtimeFile), "provider-cache"),
    cache = readdirSync(cacheDir)
      .filter((n) => n.endsWith(".json"))
      .map((n) => JSON.parse(readFileSync(join(cacheDir, n), "utf8"))),
    entities = Object.assign({}, ...cache.map((r) => r.payload?.entities ?? {}));
  const checks = [];
  const add = (id, passed, detail) =>
    checks.push({ case_id: id, status: passed ? "pass" : "fail", detail });
  const sourced = stops.every((s) => {
    const p = placeByRef.get(s.place_ref),
      id = s.place_ref.split(":")[1],
      e = entities[id];
    return (
      p?.provider === "Wikidata" &&
      p.evidence_status === "resolved" &&
      e &&
      s.source_url === `https://www.wikidata.org/wiki/${id}` &&
      (e.claims?.P625 ?? []).some((c) => {
        const v = c.mainsnak?.datavalue?.value;
        return (
          v &&
          Math.abs(v.longitude - s.coordinates[0]) < 1e-7 &&
          Math.abs(v.latitude - s.coordinates[1]) < 1e-7
        );
      })
    );
  });
  add("B1", sourced, "每个 map stop 的实体、坐标和 Wikidata 原始响应逐一核验；不以 fixture 为来源");
  add(
    "B2",
    stops.length >= 6 &&
      new Set(stops.map((s) => s.place_ref)).size === stops.length &&
      stops.every(
        (s) =>
          s.coordinates[0] >= 139.4 &&
          s.coordinates[0] <= 140 &&
          s.coordinates[1] >= 35.5 &&
          s.coordinates[1] <= 35.9,
      ),
    "轴序 [lng,lat]、东京范围与去重通过",
  );
  const existingAmbiguity = journey.trace
    .filter((t) => t.name === "search_places" && t.output.ok)
    .flatMap((t) => t.output.data.queries)
    .find((q) => q.status === "ambiguous" && q.candidates.length > 1);
  const ambiguity =
    existingAmbiguity ??
    (await rpc("search_places", { map_id: map.map_id, queries: ["東京"] })).data?.queries?.[0];
  checks.push({
    case_id: "B3",
    status:
      ambiguity?.status === "ambiguous" && ambiguity.candidates.length > 1 ? "pass" : "unverified",
    detail: "真实歧义结果保留多个实体，未由 server 静默选第一个",
  });
  const missing = await rpc("search_places", {
    map_id: map.map_id,
    queries: ["GET294不存在的火星咖啡馆"],
  });
  add(
    "B4",
    missing.ok &&
      missing.data.queries[0].status === "not_found" &&
      missing.data.queries[0].candidates.length === 0,
    "真实 provider 无结果时不回退演示地点",
  );
  add(
    "B5",
    stops.every((s) => {
      const p = placeByRef.get(s.place_ref);
      return /^\d+$/.test(p?.source_revision ?? "") && Number.isFinite(Date.parse(p.fetched_at));
    }) &&
      journey.trace.some(
        (t) => t.output.ok && t.output.warnings?.some((w) => w.code === "opening_hours_unknown"),
      ),
    "保留来源 revision/获取时间，营业日未知显式警告",
  );
  writeReceipt(outDir, base, {
    kind: "places_live",
    prefix: "places",
    checks,
    trace: {
      source_stops: stops,
      source_candidates: candidates,
      source_entities: entities,
      ambiguity,
      missing,
      provider_observations: cache.map((r) => ({
        url: r.url,
        fetched_at: r.fetched_at,
        status: r.status,
      })),
    },
  });
  const routes = cache
      .filter((r) => r.url?.includes("/route/v1/"))
      .map((r) => r.payload.routes?.[0])
      .filter(Boolean),
    legs = map.days.flatMap((d) => d.legs),
    routeChecks = [];
  const addRoute = (id, passed, detail) =>
    routeChecks.push({ case_id: id, status: passed ? "pass" : "fail", detail });
  addRoute(
    "C1",
    legs.length >= 3 &&
      legs.every(
        (l) =>
          l.mode === "walking" &&
          l.evidence_status === "resolved" &&
          routes.some(
            (r) =>
              JSON.stringify(r.geometry) === JSON.stringify(l.geometry) &&
              Math.ceil(r.duration / 60) === l.duration_minutes,
          ),
      ),
    "逐 leg 对照真实 FOSSGIS foot profile 的原始路线与秒数（不是实时交通）",
  );
  addRoute(
    "C2",
    map.timezone === "Asia/Tokyo" &&
      map.days.length === 3 &&
      map.days.every(
        (d) =>
          d.end_minute > d.start_minute &&
          d.ends_at_minute <= d.end_minute &&
          d.stops.every(
            (s, i) =>
              s.end_minute - s.start_minute === s.duration_minutes &&
              s.start_minute >= d.start_minute &&
              (i === 0 ||
                s.start_minute >= d.stops[i - 1].end_minute + d.legs[i - 1].duration_minutes),
          ),
      ),
    "相对天/城市时区/日窗口/停留与路网交通时间逐项一致；未验营业日",
  );
  addRoute(
    "C5",
    legs.every(
      (l) =>
        l.geometry_status === "routed" &&
        l.geometry?.type === "LineString" &&
        l.geometry.coordinates.length > 2 &&
        routes.some((r) => JSON.stringify(r.geometry) === JSON.stringify(l.geometry)),
    ),
    "地图 leg 使用提供商实际道路 geometry",
  );
  const before = journey.beforeEdit,
    after = journey.afterEdit,
    move = journey.trace.find(
      (t) => t.stage === "editing" && t.name === "update_day" && t.output.ok && !t.input.dry_run,
    )?.input.operation;
  let moveOK = false;
  try {
    const source = before.days.find((d) => d.stops.some((s) => s.stop_id === move.stop_id));
    assertMoveResult(
      before,
      after,
      { stopId: move.stop_id, fromDayId: source.day_id, toDayId: move.target_day_id },
      { normalFinish: true, finalMessage: "verified final model response in agent proof" },
    );
    moveOK = move.order_policy === "optimize";
  } catch {}
  // Explicit insertion is previewed against the same live network and must preserve chosen order.
  const currentSource = map.days.find((d) => d.stops.some((s) => s.stop_id === move?.stop_id)),
    target = map.days.find((d) => d.day_id !== currentSource?.day_id);
  let preserve = null;
  if (currentSource && target)
    preserve = await rpc("update_day", {
      map_id: map.map_id,
      expected_version: map.version,
      idempotency_key: `${agent.run_id}-preserve-check`,
      dry_run: true,
      operation: {
        type: "move_stop",
        stop_id: move.stop_id,
        target_day_id: target.day_id,
        target_index: 0,
        order_policy: "preserve",
      },
    });
  addRoute(
    "C3",
    moveOK &&
      preserve?.ok &&
      preserve.data.preview &&
      preserve.data.snapshot.days.find((d) => d.day_id === target.day_id).stops[0].stop_id ===
        move.stop_id,
    "真实模型换天顺路重排；相同真路网的明确插入 preview 保留位置",
  );
  const impossible = await rpc("build_route", {
    map_id: map.map_id,
    expected_version: map.version,
    idempotency_key: `agent-${agent.run_id}-impossible`,
    transport_mode: "walking",
    allow_unknown_travel: false,
    day_plans: map.days.map((d) => ({
      day_id: d.day_id,
      stop_ids: d.stops.map((s) => s.stop_id),
      start_minute: 540,
      end_minute: 541,
      order_policy: "preserve",
    })),
  });
  routeChecks.push({
    case_id: "C4",
    status: "unverified",
    detail: `真实窗口冲突检查 ${impossible.error?.code ?? "unexpected"}；锁日与 unknown 组合尚未在此 cohort 全部实测，不给完整分`,
  });
  writeReceipt(outDir, base, {
    kind: "routes_live",
    prefix: "routes",
    checks: routeChecks,
    trace: { map, provider_routes: routes, preserve, impossible, model_move: move, before, after },
  });
  if (candidateDigest() !== digest) throw Error("candidate changed during collection");
  const receipts = readdirSync(outDir)
    .filter((n) => n.endsWith(".receipt.json"))
    .map((n) => JSON.parse(readFileSync(join(outDir, n), "utf8")));
  const report = scoreReceipts({
    candidateDigest: digest,
    rubricHash: rubricHash(),
    profile: "deepseek-local",
    receipts,
    readEvidence: fileEvidenceReader(outDir),
    expectedRevision: runtime.source_revision,
  });
  writeFileSync(join(outDir, "score.json"), JSON.stringify(report, null, 2));
  writeFileSync(join(outDir, "score.md"), markdown(report));
  console.log(
    JSON.stringify(
      {
        verified_points: report.verified_points,
        unverified_points: report.unverified_points,
        accepted: report.accepted,
        segments: report.segments.map((s) => ({
          stage: s.title,
          verified: s.verified_points,
          weight: s.weight,
        })),
      },
      null,
      2,
    ),
  );
  return report;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2),
    get = (f, d) => {
      const i = args.indexOf(f);
      return i < 0 ? d : args[i + 1];
    };
  await collectLive({
    outDir: resolve(get("--out", "live-agent-result")),
    runtimeFile: resolve(get("--runtime", "runtime.private.json")),
  });
}
