import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { resolve, join } from "node:path";
import { pathToFileURL } from "node:url";
import { writeReceipt, fileEvidenceReader } from "./evidence.mjs";
import { candidateDigest, rubricHash, scoreReceipts, markdown } from "./score.mjs";
import { assertRuntimeIdentity, assertResponseIdentity } from "./integrity.mjs";
export async function collectSecurity({ outDir, runtimeFile, envFile } = {}) {
  const runtime = JSON.parse(readFileSync(runtimeFile, "utf8")),
    agent = JSON.parse(readFileSync(join(outDir, "agent.receipt.json"), "utf8")),
    info = JSON.parse(readFileSync(join(outDir, "map.private.json"), "utf8"));
  assertRuntimeIdentity(runtime, candidateDigest(), rubricHash());
  const base = {
    ...agent,
    checks: undefined,
    meta: undefined,
    artifacts: undefined,
    kind: undefined,
    finished_at: new Date().toISOString(),
  };
  let counter = 3000;
  const events = [];
  async function call(name, args) {
    const res = await fetch(runtime.url + "/mcp/maps", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${runtime.bearer}`,
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: ++counter,
        method: "tools/call",
        params: { name, arguments: args },
      }),
      signal: AbortSignal.timeout(100000),
    });
    assertResponseIdentity(res.headers, runtime);
    const raw = await res.json();
    if (raw.error) throw Error(raw.error.message);
    const value = raw.result.structuredContent;
    events.push({ name, input: args, output: value });
    return value;
  }
  const ownerResponse = await fetch(runtime.url + "/api/maps/" + info.snapshot.map_id, {
      headers: { Authorization: `Bearer ${runtime.bearer}` },
    }),
    current = (await ownerResponse.json()).snapshot;
  const other = await fetch(runtime.url + "/api/maps/" + current.map_id, {
      headers: { Authorization: `Bearer ${runtime.guest_bearer}` },
    }),
    anonymous = await fetch(runtime.url + "/api/maps/" + current.map_id),
    origin = await fetch(runtime.url + "/mcp/maps", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${runtime.bearer}`,
        Origin: "https://untrusted.invalid",
        "Content-Type": "application/json",
      },
      body: "{}",
    });
  const securityChecks = [
    {
      case_id: "F1",
      status:
        ownerResponse.ok &&
        other.status === 404 &&
        anonymous.status === 404 &&
        origin.status === 403
          ? "pass"
          : "fail",
      detail: "实际 scoped 所有者/其他身份/匿名隔离与 Origin 拒绝；不代表生产 OAuth/RLS 验收",
    },
  ];
  const prefix = agent.run_id + "-security",
    sourceStops = current.days.flatMap((d) => d.stops);
  let control = (
    await call("create_map", {
      title: "隔离分享验收",
      city: "Tokyo, Japan",
      day_count: 2,
      timezone: "Asia/Tokyo",
      idempotency_key: prefix + "-create",
    })
  ).data.snapshot;
  control = (
    await call("plot_places", {
      map_id: control.map_id,
      expected_version: control.version,
      idempotency_key: prefix + "-plot",
      items: [
        {
          place_ref: sourceStops[0].place_ref,
          day_id: control.days[0].day_id,
          duration_minutes: 30,
        },
      ],
    })
  ).data.snapshot;
  control = (
    await call("build_route", {
      map_id: control.map_id,
      expected_version: control.version,
      idempotency_key: prefix + "-build",
      transport_mode: "walking",
      allow_unknown_travel: false,
      day_plans: control.days.map((d) => ({
        day_id: d.day_id,
        stop_ids: d.stops.map((s) => s.stop_id),
        start_minute: 540,
        end_minute: 1080,
        order_policy: "preserve",
      })),
    })
  ).data.snapshot;
  const link = await call("get_map_link", {
    map_id: control.map_id,
    expected_version: control.version,
    idempotency_key: prefix + "-share",
    expires_in_days: 7,
    visible_stop_ids: [control.days[0].stops[0].stop_id],
  });
  const added = await call("plot_places", {
    map_id: control.map_id,
    expected_version: control.version,
    idempotency_key: prefix + "-private",
    items: [
      { place_ref: sourceStops[1].place_ref, day_id: control.days[1].day_id, duration_minutes: 30 },
    ],
  });
  const shareToken = new URL(link.data.share_url).pathname.split("/").at(-1),
    view = await fetch(runtime.url + "/api/share/" + shareToken).then((r) => r.json());
  const filtered =
    view.snapshot.days.flatMap((d) => d.stops).length === 1 &&
    view.snapshot.days.every((d) => d.legs.length === 0) &&
    !JSON.stringify(view).includes(added.data.stop_ids[0]);
  securityChecks.push({
    case_id: "F2",
    status: filtered ? "pass" : "fail",
    detail: "公开集合和几何过滤一致；后来新增的实际地点未出现在旧链接",
  });
  let secrets = [runtime.bearer, runtime.guest_bearer];
  if (envFile) {
    const text = readFileSync(envFile, "utf8");
    secrets.push(
      ...text
        .split("\n")
        .filter((l) => /^[A-Z_]*(KEY|TOKEN|PASSWORD)[A-Z_]*=/.test(l))
        .map((l) =>
          l
            .slice(l.indexOf("=") + 1)
            .trim()
            .replace(/^['"]|['"]$/g, ""),
        ),
    );
  }
  secrets = secrets.filter((s) => s.length > 12);
  const publicEvidence = readdirSync(outDir).filter(
    (n) => n.endsWith(".json") && !n.endsWith(".private.json"),
  );
  const leaks = publicEvidence.filter((n) => {
    const body = readFileSync(join(outDir, n), "utf8");
    return secrets.some((s) => body.includes(s));
  });
  securityChecks.push({
    case_id: "F4",
    status: leaks.length === 0 ? "pass" : "fail",
    detail:
      "本 cohort 的导出 JSON 不含配置密钥或 scoped bearer，浏览器只通过 HttpOnly session 操作",
  });
  securityChecks.push({
    case_id: "F3",
    status: "unverified",
    detail: "本 cohort 尚未完成链接撤销及过期的端到端测试；不给分",
  });
  writeReceipt(outDir, base, {
    kind: "security_live",
    prefix: "security",
    checks: securityChecks,
    trace: {
      owner_http_status: ownerResponse.status,
      other_http_status: other.status,
      anonymous_http_status: anonymous.status,
      origin_http_status: origin.status,
      events,
      view,
      leak_files: leaks,
    },
  });
  const concurrentArgs = {
    map_id: current.map_id,
    expected_version: current.version,
    dry_run: false,
    operation: {
      type: "set_stop_duration",
      stop_id: sourceStops[0].stop_id,
      duration_minutes: sourceStops[0].duration_minutes,
    },
  };
  const concurrent = await Promise.all([
    call("update_day", { ...concurrentArgs, idempotency_key: prefix + "-concurrent-a" }),
    call("update_day", { ...concurrentArgs, idempotency_key: prefix + "-concurrent-b" }),
  ]);
  const successful = concurrent.filter((r) => r.ok),
    conflicts = concurrent.filter((r) => !r.ok && r.error.code === "VERSION_CONFLICT");
  const concurrencyPass =
    successful.length === 1 &&
    conflicts.length === 1 &&
    successful[0].data.snapshot.version === current.version + 1;
  writeReceipt(outDir, base, {
    kind: "concurrency_live",
    prefix: "concurrency",
    checks: [
      {
        case_id: "D4",
        status: concurrencyPass ? "pass" : "fail",
        detail: "两个独立 HTTP 请求竞争同一版本，仅一次提交；单 runtime，不外推多进程 DB 事务",
      },
    ],
    trace: { concurrentArgs, concurrent },
  });
  writeReceipt(outDir, base, {
    kind: "persistence_live",
    prefix: "persistence",
    checks: [
      {
        case_id: "D5",
        status: filtered ? "pass" : "fail",
        detail: "旧分享 URL 读取最新 committed 公开集合，未公开新增点",
      },
      {
        case_id: "D1",
        status: "unverified",
        detail: "已写磁盘，但本 cohort 未执行独立重启后的证据核验；不给完整分",
      },
    ],
    trace: { events, view },
  });
  if (candidateDigest() !== runtime.candidate_digest)
    throw Error("candidate changed during security checks");
  const receipts = readdirSync(outDir)
    .filter((n) => n.endsWith(".receipt.json"))
    .map((n) => JSON.parse(readFileSync(join(outDir, n), "utf8")));
  const report = scoreReceipts({
    candidateDigest: candidateDigest(),
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
        security: securityChecks.map((c) => ({ id: c.case_id, status: c.status })),
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
  await collectSecurity({
    outDir: resolve(get("--out", "live-agent-result")),
    runtimeFile: resolve(get("--runtime", "runtime.private.json")),
    envFile: get("--env-file", undefined),
  });
}
