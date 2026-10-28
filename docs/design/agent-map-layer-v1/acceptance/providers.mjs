import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { DomainError } from "../demo/domain.mjs";
const here = dirname(fileURLToPath(import.meta.url));
const hash = (x) => createHash("sha256").update(x).digest("hex");
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const problem = (message) => new DomainError("PROVIDER_UNAVAILABLE", message, {}, true);
export async function network(request, { envFile } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn("python3", [join(here, "network.py")], {
      env: { ...process.env, ...(envFile ? { MAP_CHAIN_ENV_FILE: envFile } : {}) },
      stdio: ["pipe", "pipe", "pipe"],
    });
    let output = "",
      bytes = 0;
    child.stdout.on("data", (chunk) => {
      bytes += chunk.length;
      if (bytes > 5_000_000) {
        child.kill();
        reject(problem("上游响应过大"));
      } else output += chunk;
    });
    child.stderr.resume();
    child.on("error", () => reject(problem("网络 helper 无法启动")));
    child.on("close", () => {
      try {
        resolve(JSON.parse(output));
      } catch {
        reject(problem("上游未返回可解析 JSON"));
      }
    });
    child.stdin.end(JSON.stringify(request));
  });
}
export function createProviders(dir, { envFile, maxRequests = 45 } = {}) {
  mkdirSync(dir, { recursive: true });
  let queue = Promise.resolve(),
    lastRequest = 0,
    requests = 0;
  const catalog = [],
    cells = new Map();
  const observations = [];
  async function get(url) {
    const file = join(dir, hash(url) + ".json");
    if (existsSync(file)) {
      const cached = JSON.parse(readFileSync(file, "utf8"));
      if (Date.now() - Date.parse(cached.fetched_at) < 12 * 3600000) return cached;
    }
    const task = queue.then(async () => {
      await sleep(Math.max(0, 1050 - (Date.now() - lastRequest)));
      if (++requests > maxRequests) throw problem("本次验收 provider 请求预算已用完");
      lastRequest = Date.now();
      const result = await network({ service: "public", url }, { envFile });
      if (!result.ok) throw problem(`真实 provider 请求失败：${result.status ?? result.error}`);
      const receipt = { url, fetched_at: new Date().toISOString(), ...result };
      writeFileSync(file, JSON.stringify(receipt, null, 2));
      observations.push({ url, elapsed_ms: result.elapsed_ms, status: result.status });
      return receipt;
    });
    queue = task.catch(() => {});
    return task;
  }
  async function resolvePlace(query) {
    if (catalog.some((p) => p.name === query)) return catalog.filter((p) => p.name === query);
    const searchURL =
      "https://www.wikidata.org/w/api.php?" +
      new URLSearchParams({
        action: "wbsearchentities",
        search: query,
        language: /[\u3040-\u30ff]/.test(query) ? "ja" : "zh",
        uselang: "zh",
        format: "json",
        limit: "5",
      });
    const search = await get(searchURL);
    const ids = (search.payload.search ?? []).map((s) => s.id).filter((id) => /^Q\d+$/.test(id));
    if (!ids.length) return [];
    const entityURL =
      "https://www.wikidata.org/w/api.php?" +
      new URLSearchParams({
        action: "wbgetentities",
        ids: ids.join("|"),
        props: "claims|labels|info",
        languages: "zh|ja|en",
        format: "json",
      });
    const entities = await get(entityURL),
      candidates = [];
    for (const id of ids) {
      const entity = entities.payload.entities?.[id];
      if (!entity) continue;
      const claims = (entity.claims?.P625 ?? []).filter(
        (c) => c.rank !== "deprecated" && c.mainsnak?.datavalue?.value,
      );
      const preferred = claims.filter((c) => c.rank === "preferred");
      const relevant = preferred.length ? preferred : claims;
      const positions = relevant
        .map((c) => c.mainsnak.datavalue.value)
        .filter((p) => p.globe === "http://www.wikidata.org/entity/Q2");
      const tokyo = positions.filter(
        (p) =>
          p.longitude >= 139.4 && p.longitude <= 140.0 && p.latitude >= 35.5 && p.latitude <= 35.9,
      );
      if (!tokyo.length) continue;
      // Conflicting coordinate claims are not silently merged into a resolved point.
      if (
        tokyo.some(
          (p) =>
            Math.abs(p.longitude - tokyo[0].longitude) > 0.001 ||
            Math.abs(p.latitude - tokyo[0].latitude) > 0.001,
        )
      )
        continue;
      const point = tokyo[0];
      const p = {
        place_ref: `wikidata:${id}`,
        name: query,
        canonical_name:
          entity.labels?.zh?.value ?? entity.labels?.ja?.value ?? entity.labels?.en?.value ?? query,
        coordinates: [point.longitude, point.latitude],
        provider: "Wikidata",
        source_url: `https://www.wikidata.org/wiki/${id}`,
        source_revision: String(entity.lastrevid ?? "unknown"),
        fetched_at: entities.fetched_at,
        evidence_status: "resolved",
        duration_minutes: 60,
      };
      candidates.push(p);
    }
    const unique = [...new Map(candidates.map((p) => [p.place_ref, p])).values()].slice(0, 3);
    catalog.push(...unique);
    return unique;
  }
  const cellKey = (a, b) => `${a.place_ref}>${b.place_ref}`;
  async function prepareMap(snapshot) {
    const stops = snapshot.days
      .flatMap((d) => d.stops)
      .sort((a, b) => a.place_ref.localeCompare(b.place_ref));
    if (stops.length < 2) return;
    // One real foot-network matrix supplies candidate costs; no straight-line fallback.
    const coords = stops.map((s) => s.coordinates.join(",")).join(";");
    const result = await get(
      `https://routing.openstreetmap.de/routed-foot/table/v1/driving/${coords}?annotations=duration,distance`,
    );
    if (result.payload.code !== "Ok" || !Array.isArray(result.payload.durations))
      throw problem("真实步行矩阵不可用");
    for (let i = 0; i < stops.length; i++)
      for (let j = 0; j < stops.length; j++) {
        const seconds = result.payload.durations[i]?.[j],
          meters = result.payload.distances?.[i]?.[j];
        if (i === j || seconds === null || seconds === undefined) continue;
        if (!Number.isFinite(seconds) || seconds < 0 || !Number.isFinite(meters) || meters < 0)
          throw problem("真实矩阵含无效数值");
        const previous = cells.get(cellKey(stops[i], stops[j]));
        cells.set(cellKey(stops[i], stops[j]), {
          ...previous,
          duration_seconds: seconds,
          distance_meters: meters,
          source_url: "https://routing.openstreetmap.de/about.html",
          fetched_at: result.fetched_at,
        });
      }
  }
  async function geometryFor(days) {
    for (const day of days)
      for (let i = 1; i < day.stops.length; i++) {
        const from = day.stops[i - 1],
          to = day.stops[i],
          key = cellKey(from, to);
        if (cells.get(key)?.geometry) continue;
        const route = await get(
          `https://routing.openstreetmap.de/routed-foot/route/v1/driving/${from.coordinates.join(",")};${to.coordinates.join(",")}?overview=full&geometries=geojson&steps=false`,
        );
        const r = route.payload.routes?.[0];
        if (
          route.payload.code !== "Ok" ||
          !r?.geometry?.coordinates?.length ||
          !Number.isFinite(r.duration) ||
          !Number.isFinite(r.distance)
        )
          throw problem("真实步行路线/geometry 不可用");
        if (route.payload.waypoints.some((p) => p.distance > 500))
          throw problem("路线吸附点距地点超过 500 米，需要选择入口");
        cells.set(key, {
          duration_seconds: r.duration,
          distance_meters: r.distance,
          geometry: r.geometry,
          source_url: "https://routing.openstreetmap.de/about.html",
          fetched_at: route.fetched_at,
        });
      }
  }
  function routeLookup(a, b, mode) {
    if (mode !== "walking") return null;
    return cells.get(cellKey(a, b)) ?? null;
  }
  async function prepareTool(name, args, subject, domain) {
    if (name === "search_places") {
      if (!/tokyo|东京|東京/i.test(domain.get(args.map_id, subject).city)) return;
      for (const q of args.queries) await resolvePlace(q);
    }
    if (name === "build_route" || name === "update_day") {
      const map = domain.get(args.map_id, subject);
      if (args.expected_version !== map.version) return;
      const mode = name === "build_route" ? args.transport_mode : null;
      if (mode && mode !== "walking")
        throw problem("此真实验收配置只接入步行；公交/驾驶未验证，不能用步行结果代替");
      await prepareMap(map);
      const preview = domain.call(name, args, subject, { previewOnly: true });
      await geometryFor(
        preview.data.snapshot.days.filter((d) => preview.data.affected_day_ids.includes(d.day_id)),
      );
    }
  }
  return {
    catalog,
    routeLookup,
    prepareTool,
    resolvePlace,
    observations,
    get network_requests() {
      return requests;
    },
  };
}
