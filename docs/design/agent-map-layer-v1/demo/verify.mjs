// Run the boundary through HTTP, not direct UI-state mutation.
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { startServer } from "./server.mjs";
import { tools, validate } from "./contract.mjs";
const dir = mkdtempSync(join(process.env.MAP_DEMO_TEST_ROOT ?? tmpdir(), "map-boundary-"));
let runtime = await startServer({ dir }),
  requestId = 0,
  results = [],
  trace = [];
const headers = () => ({
  "Content-Type": "application/json",
  Accept: "application/json, text/event-stream",
  "MCP-Protocol-Version": "2025-11-25",
  Authorization: `Bearer ${runtime.bearer}`,
});
async function rpc(method, params = {}, extra = {}) {
  const res = await fetch(runtime.baseURL + "/mcp/maps", {
    method: "POST",
    headers: { ...headers(), ...extra },
    body: JSON.stringify({ jsonrpc: "2.0", id: ++requestId, method, params }),
  });
  assert.equal(res.status, 200);
  const data = await res.json();
  assert(!data.error, JSON.stringify(data));
  return data.result;
}
async function call(name, args, extra = {}) {
  const data = await rpc("tools/call", { name, arguments: args }, extra);
  validate(tools.find((t) => t.name === name).outputSchema, data.structuredContent);
  assert.deepEqual(JSON.parse(data.content[0].text), data.structuredContent);
  assert.equal(data.isError, !data.structuredContent.ok);
  trace.push({ name, input: args, output: data.structuredContent });
  return data.structuredContent;
}
function pass(name) {
  results.push(name);
  console.log(`PASS ${name}`);
}
try {
  const init = await rpc("initialize", {
    protocolVersion: "2025-11-25",
    capabilities: {},
    clientInfo: { name: "boundary-verifier", version: "1" },
  });
  assert.equal(init.protocolVersion, "2025-11-25");
  const registry = (await rpc("tools/list")).tools;
  assert.equal(registry.length, 6);
  assert(
    registry.every((t) => t.inputSchema.type === "object" && t.outputSchema.type === "object"),
  );
  pass("2025-11-25 handshake + six tools");
  const createArgs = {
    title: "东京 3 天",
    city: "Tokyo, Japan",
    day_count: 3,
    timezone: "Asia/Tokyo",
    idempotency_key: "create-once",
  };
  const created = await call("create_map", createArgs);
  assert(created.ok);
  let map = created.data.snapshot;
  const mid = map.map_id;
  const concurrent = await Promise.all([
    call("create_map", createArgs),
    call("create_map", createArgs),
  ]);
  assert(concurrent.every((x) => x.data.snapshot.map_id === mid));
  pass("identical + concurrent retries reuse map");
  assert.equal(
    (await call("create_map", { ...createArgs, title: "different" })).error.code,
    "IDEMPOTENCY_CONFLICT",
  );
  pass("same key + different payload rejected");
  assert.equal(
    (await call("create_map", { ...createArgs, idempotency_key: "bad-owner", owner_id: "other" }))
      .error.code,
    "VALIDATION_ERROR",
  );
  pass("caller cannot inject owner");
  const names = [
    "浅草寺",
    "隅田公园",
    "上野公园",
    "明治神宫",
    "原宿",
    "涩谷十字路口",
    "筑地场外市场",
    "银座",
    "东京站",
  ];
  const search = await call("search_places", { map_id: mid, queries: names });
  assert(search.data.queries.every((q) => q.status === "resolved"));
  assert.equal(
    (await call("search_places", { map_id: mid, queries: ["不存在的咖啡馆"] })).data.queries[0]
      .status,
    "not_found",
  );
  pass("resolved fixture + missing POI");
  const get = async () => {
    const response = await fetch(`${runtime.baseURL}/api/maps/${mid}`, {
      headers: { Authorization: `Bearer ${runtime.bearer}` },
    });
    return (await response.json()).snapshot;
  };
  const plotted = await call("plot_places", {
    map_id: mid,
    expected_version: map.version,
    idempotency_key: "plot-once",
    items: search.data.queries.map((q, i) => ({
      place_ref: q.candidates[0].place_ref,
      day_id: map.days[Math.floor(i / 3)].day_id,
      duration_minutes: q.candidates[0].duration_minutes,
    })),
  });
  assert(plotted.ok);
  map = plotted.data.snapshot;
  assert.equal(map.version, 2);
  const invalidPlot = await call("plot_places", {
    map_id: mid,
    expected_version: 2,
    idempotency_key: "bad-place",
    items: [{ place_ref: "fixture:made-up", day_id: map.days[0].day_id, duration_minutes: 30 }],
  });
  assert.equal(invalidPlot.error.code, "PLACE_UNRESOLVED");
  assert.deepEqual(await get(), map);
  pass("unknown place rollback");
  const built = await call("build_route", {
    map_id: mid,
    expected_version: map.version,
    idempotency_key: "build-once",
    transport_mode: "transit",
    allow_unknown_travel: true,
    day_plans: map.days.map((d) => ({
      day_id: d.day_id,
      stop_ids: d.stops.map((s) => s.stop_id),
      start_minute: 540,
      end_minute: 1080,
      order_policy: "preserve",
    })),
  });
  assert(built.ok);
  map = built.data.snapshot;
  assert(map.days.every((d) => d.legs.length === 2));
  pass("three days scheduled via HTTP");
  const link = await call("get_map_link", {
    map_id: mid,
    expected_version: map.version,
    idempotency_key: "share-once",
    expires_in_days: 7,
    visible_stop_ids: map.days.flatMap((d) => d.stops.map((s) => s.stop_id)),
  });
  assert(link.ok);
  const token = new URL(link.data.share_url).pathname.split("/").at(-1);
  const shared = await fetch(`${runtime.baseURL}/api/share/${token}`).then((r) => r.json());
  assert.equal(shared.can_edit, false);
  assert.deepEqual(shared.snapshot, map);
  pass("fresh unauthenticated viewer can read persisted link");
  const unauth = await fetch(`${runtime.baseURL}/mcp/maps`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }),
  });
  assert.equal(unauth.status, 401);
  assert.equal((await fetch(`${runtime.baseURL}/api/maps/${mid}`)).status, 404);
  pass("view link grants no write or owner read");
  const move = {
    map_id: mid,
    expected_version: 3,
    idempotency_key: "move-once",
    dry_run: false,
    operation: {
      type: "move_stop",
      stop_id: map.days[0].stops[0].stop_id,
      target_day_id: map.days[1].day_id,
      target_index: 3,
    },
  };
  const preview = await call("update_day", { ...move, idempotency_key: "preview", dry_run: true });
  assert(preview.ok);
  assert.equal(preview.data.snapshot.version, 3);
  assert.deepEqual(await get(), map);
  pass("preview computes both days without saving");
  const failure = await call("update_day", move, { "X-Demo-Fault": "provider" });
  assert.equal(failure.error.code, "PROVIDER_UNAVAILABLE");
  assert.deepEqual(await get(), map);
  pass("provider failure preserves both days and frees retry key");
  const moved = await call("update_day", move);
  assert(moved.ok);
  assert.equal(moved.data.snapshot.version, 4);
  assert.deepEqual(
    moved.data.snapshot.days.map((d) => d.stops.length),
    [2, 4, 3],
  );
  assert.deepEqual(
    moved.data.snapshot.days[1].stops.at(-1).coordinates,
    map.days[0].stops[0].coordinates,
  );
  assert.equal(moved.data.affected_day_ids.length, 2);
  const retried = await call("update_day", move);
  assert.deepEqual(retried, moved);
  pass("cross-day atomic move + stable coordinates + retry");
  const conflict = await call("update_day", { ...move, idempotency_key: "stale-version" });
  assert.equal(conflict.error.code, "VERSION_CONFLICT");
  assert.equal(conflict.error.details.current_version, 4);
  pass("stale version blocked with current snapshot");
  const beforeUndo = await get();
  const infeasible = await call("update_day", {
    map_id: mid,
    expected_version: 4,
    idempotency_key: "too-late",
    dry_run: false,
    operation: { type: "set_start_time", day_id: map.days[1].day_id, start_minute: 1079 },
  });
  assert.equal(infeasible.error.code, "INFEASIBLE");
  assert.deepEqual(await get(), beforeUndo);
  pass("infeasible schedule rolls back");
  const undo = await call("update_day", {
    map_id: mid,
    expected_version: 4,
    idempotency_key: "undo-once",
    dry_run: false,
    operation: { type: "undo", edit_id: moved.data.edit_id },
  });
  assert(undo.ok);
  assert.equal(undo.data.snapshot.version, 5);
  assert.deepEqual(undo.data.snapshot.days, map.days);
  map = undo.data.snapshot;
  pass("undo is a new committed version");
  const undoAgain = await call("update_day", {
    map_id: mid,
    expected_version: 5,
    idempotency_key: "undo-different",
    dry_run: false,
    operation: { type: "undo", edit_id: moved.data.edit_id },
  });
  assert.equal(undoAgain.error.code, "UNDO_CONFLICT");
  pass("undo cannot replay over newer state");
  const unknown = await call(
    "update_day",
    {
      map_id: mid,
      expected_version: 5,
      idempotency_key: "unknown",
      dry_run: false,
      operation: { type: "set_start_time", day_id: map.days[0].day_id, start_minute: 550 },
    },
    { "X-Demo-Fault": "unknown" },
  );
  assert(unknown.ok);
  const day = unknown.data.snapshot.days[0];
  assert.equal(day.total_travel_minutes, null);
  assert.equal(day.stops[1].start_minute, null);
  assert.equal(day.feasibility_status, "unknown");
  map = unknown.data.snapshot;
  pass("unknown travel is null, never zero or fake arrival");
  const tooMuchUnknown = await call(
    "update_day",
    {
      map_id: mid,
      expected_version: map.version,
      idempotency_key: "known-duration-overflow",
      dry_run: false,
      operation: {
        type: "set_stop_duration",
        stop_id: map.days[0].stops[0].stop_id,
        duration_minutes: 480,
      },
    },
    { "X-Demo-Fault": "unknown" },
  );
  assert.equal(tooMuchUnknown.error.code, "INFEASIBLE");
  assert.deepEqual(await get(), map);
  pass("known duration lower bound still rejects impossible unknown route");
  const otherDay = map.days[1];
  const partialBuild = await call("build_route", {
    map_id: mid,
    expected_version: map.version,
    idempotency_key: "partial-walking",
    transport_mode: "walking",
    allow_unknown_travel: true,
    day_plans: [
      {
        day_id: otherDay.day_id,
        stop_ids: otherDay.stops.map((s) => s.stop_id),
        start_minute: 540,
        end_minute: 1080,
        order_policy: "preserve",
      },
    ],
  });
  assert(partialBuild.ok);
  map = partialBuild.data.snapshot;
  assert.equal(map.days[0].transport_mode, "transit");
  assert.equal(map.days[1].transport_mode, "walking");
  const preserveMode = await call("update_day", {
    map_id: mid,
    expected_version: map.version,
    idempotency_key: "keep-day-mode",
    dry_run: false,
    operation: { type: "set_start_time", day_id: map.days[0].day_id, start_minute: 550 },
  });
  assert(preserveMode.ok);
  map = preserveMode.data.snapshot;
  assert(map.days[0].legs.every((l) => l.mode === "transit"));
  pass("partial build does not change other day travel mode");
  const partial = await call("get_map_link", {
    map_id: mid,
    expected_version: map.version,
    idempotency_key: "share-partial",
    expires_in_days: 7,
    visible_stop_ids: [map.days[0].stops[0].stop_id],
  });
  const partialToken = new URL(partial.data.share_url).pathname.split("/").at(-1);
  const visible = await fetch(`${runtime.baseURL}/api/share/${partialToken}`).then((r) => r.json());
  assert.equal(visible.snapshot.days.flatMap((d) => d.stops).length, 1);
  assert(visible.snapshot.days.every((d) => d.legs.length === 0));
  pass("explicit share allowlist filters stops and geometry");
  const resource = await rpc("resources/read", { uri: `roamorrow://maps/${mid}` });
  assert.deepEqual(JSON.parse(resource.contents[0].text), map);
  pass("authenticated resource reads latest version");
  const bearer = runtime.bearer;
  await runtime.close();
  runtime = await startServer({ dir, bearer });
  assert.deepEqual(await get(), map);
  const afterRestart = await fetch(`${runtime.baseURL}/api/share/${token}`).then((r) => r.json());
  assert.deepEqual(afterRestart.snapshot, map);
  pass("disk restart preserves map + share grant");
  const originDenied = await fetch(runtime.baseURL + "/mcp/maps", {
    method: "POST",
    headers: { ...headers(), Origin: "https://untrusted.invalid" },
    body: "{}",
  });
  assert.equal(originDenied.status, 403);
  pass("untrusted Origin rejected");
  const forkResponse = await fetch(`${runtime.baseURL}/api/fork/${token}`, { method: "POST" });
  assert.equal(forkResponse.status, 200);
  const fork = await forkResponse.json();
  assert.notEqual(fork.snapshot.map_id, mid);
  assert.deepEqual(await get(), map);
  assert(
    fork.snapshot.days
      .flatMap((d) => d.stops)
      .every((s) => !map.days.flatMap((d) => d.stops).some((old) => old.stop_id === s.stop_id)),
  );
  pass("visitor fork owns a separate map and remapped primary keys");
  const constrained = await call("create_map", {
    title: "长".repeat(160),
    city: "Tokyo, Japan",
    day_count: 2,
    timezone: "Asia/Tokyo",
    idempotency_key: "constraint-map",
  });
  let cm = constrained.data.snapshot;
  const constraints = await call("plot_places", {
    map_id: cm.map_id,
    expected_version: cm.version,
    idempotency_key: "constraint-pins",
    items: [
      { place_ref: "fixture:sensoji", day_id: cm.days[0].day_id, duration_minutes: 30 },
      {
        place_ref: "fixture:sumida",
        day_id: cm.days[0].day_id,
        duration_minutes: 30,
        fixed_start_minute: 630,
        lock_to_day: true,
      },
    ],
  });
  assert(constraints.ok);
  cm = constraints.data.snapshot;
  const scheduled = await call(
    "build_route",
    {
      map_id: cm.map_id,
      expected_version: cm.version,
      idempotency_key: "constraint-route",
      transport_mode: "transit",
      allow_unknown_travel: true,
      day_plans: cm.days.map((d) => ({
        day_id: d.day_id,
        stop_ids: d.stops.map((s) => s.stop_id),
        start_minute: 540,
        end_minute: 1080,
        order_policy: "preserve",
      })),
    },
    { "X-Demo-Fault": "unknown" },
  );
  assert(scheduled.ok);
  cm = scheduled.data.snapshot;
  const appointment = cm.days[0].stops[1];
  assert.equal(appointment.arrival_minute, null);
  assert.equal(appointment.start_minute, 630);
  assert.equal(appointment.feasibility_status, "unknown");
  assert.equal(appointment.locked_day_id, cm.days[0].day_id);
  pass("public contract can express fixed slot while reachability remains unknown");
  const locked = await call("update_day", {
    map_id: cm.map_id,
    expected_version: cm.version,
    idempotency_key: "locked-move",
    dry_run: false,
    operation: {
      type: "move_stop",
      stop_id: appointment.stop_id,
      target_day_id: cm.days[1].day_id,
      target_index: 0,
    },
  });
  assert.equal(locked.error.code, "INFEASIBLE");
  pass("appointment day lock rejects cross-day move");
  const cs = await call("get_map_link", {
    map_id: cm.map_id,
    expected_version: cm.version,
    idempotency_key: "constraint-share",
    expires_in_days: 7,
    visible_stop_ids: cm.days[0].stops.map((s) => s.stop_id),
  });
  const ct = new URL(cs.data.share_url).pathname.split("/").at(-1);
  const later = await call("plot_places", {
    map_id: cm.map_id,
    expected_version: cm.version,
    idempotency_key: "new-private-point",
    items: [{ place_ref: "fixture:ueno", day_id: cm.days[1].day_id, duration_minutes: 40 }],
  });
  assert(later.ok);
  const oldGrant = await fetch(`${runtime.baseURL}/api/share/${ct}`).then((r) => r.json());
  assert.equal(oldGrant.snapshot.days.flatMap((d) => d.stops).length, 2);
  pass("new stop is not published through an existing live link");
  const longForkResponse = await fetch(`${runtime.baseURL}/api/fork/${ct}`, { method: "POST" });
  const cookie = longForkResponse.headers.getSetCookie()[0].split(";")[0],
    longFork = await longForkResponse.json();
  assert(longFork.snapshot.title.length <= 160);
  validate(tools[0].outputSchema.$defs.Map, longFork.snapshot, {
    $defs: tools[0].outputSchema.$defs,
  });
  const fm = longFork.snapshot;
  const editableFork = await call(
    "update_day",
    {
      map_id: fm.map_id,
      expected_version: fm.version,
      idempotency_key: "edit-long-fork",
      dry_run: false,
      operation: {
        type: "set_stop_duration",
        stop_id: fm.days[0].stops[0].stop_id,
        duration_minutes: 35,
      },
    },
    { Authorization: "", Cookie: cookie },
  );
  assert(editableFork.ok);
  pass("max-length title fork remains schema-valid and editable");
  writeFileSync(
    join(dir, "receipt.json"),
    JSON.stringify(
      {
        verdict: "supported",
        scope: "local HTTP protocol + fixture boundary only",
        checks: results,
        trace,
      },
      null,
      2,
    ),
  );
  console.log(`\n${results.length} checks passed. Evidence: ${dir}/receipt.json`);
} finally {
  await runtime.close();
}
