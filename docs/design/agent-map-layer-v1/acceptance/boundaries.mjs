import assert from "node:assert/strict";
import { fork } from "node:child_process";
import { once } from "node:events";
import { readFileSync, writeFileSync, mkdirSync, cpSync, existsSync } from "node:fs";
import { resolve, join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { candidateDigest, rubricHash, scoreReceipts, markdown } from "./score.mjs";
import { writeReceipt, fileEvidenceReader } from "./evidence.mjs";
import { assertRuntimeIdentity, assertResponseIdentity } from "./integrity.mjs";
import { readdirSync } from "node:fs";

export async function collectBoundaries({ outDir, runtimeFile, dir, envFile, playwrightModule }) {
  const source = JSON.parse(readFileSync(runtimeFile, "utf8"));
  const agent = JSON.parse(readFileSync(join(outDir, "agent.receipt.json"), "utf8"));
  const info = JSON.parse(readFileSync(join(outDir, "map.private.json"), "utf8"));
  assertRuntimeIdentity(source, candidateDigest(), rubricHash());
  assert.equal(agent.runtime_id, source.runtime_id);
  if (existsSync(dir))
    throw Error("boundary directory must be new; retained evidence is never overwritten");
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  cpSync(join(dirname(runtimeFile), "state"), join(dir, "state"), { recursive: true });
  let child,
    runtime,
    port = 0,
    browser,
    commandId = 0,
    requestId = 4000;
  const events = [],
    checks = [],
    shots = [];
  const cache = join(dirname(runtimeFile), "provider-cache");
  async function boot() {
    child = fork(
      fileURLToPath(new URL("./control-server.mjs", import.meta.url)),
      [dir, cache, String(port)],
      {
        env: { ...process.env, ...(envFile ? { MAP_CHAIN_ENV_FILE: envFile } : {}) },
        stdio: ["ignore", "ignore", "pipe", "ipc"],
      },
    );
    let failure = "";
    child.stderr.on("data", (b) => {
      failure += b.toString();
    });
    await new Promise((done, reject) => {
      const timer = setTimeout(() => {
        child.kill("SIGTERM");
        reject(Error("controller startup timeout"));
      }, 15000);
      child.once("message", (m) => {
        clearTimeout(timer);
        m.ready ? done() : reject(Error("controller not ready"));
      });
      child.once("exit", () => {
        clearTimeout(timer);
        reject(Error("controller exited: " + failure));
      });
    });
    runtime = JSON.parse(readFileSync(join(dir, "runtime.private.json"), "utf8"));
    assertRuntimeIdentity(runtime, candidateDigest(), rubricHash());
    port = Number(new URL(runtime.listen_url).port);
    events.push({ type: "process_started", runtime_id: runtime.runtime_id, pid: child.pid });
  }
  async function stop() {
    if (!child || child.exitCode !== null) return;
    const exited = once(child, "exit");
    child.kill("SIGTERM");
    await exited;
    events.push({ type: "process_stopped", pid: child.pid });
  }
  async function control(type, value) {
    const id = ++commandId;
    const ack = new Promise((done, reject) => {
      const timer = setTimeout(() => reject(Error("IPC acknowledgement timeout")), 5000);
      const listener = (m) => {
        if (m.ack === id) {
          clearTimeout(timer);
          child.off("message", listener);
          done();
        }
      };
      child.on("message", listener);
    });
    child.send({ type, value, id });
    await ack;
    events.push({ type: "controlled_" + type, value });
  }
  async function http(path, { other = false, anonymous = false, method = "GET" } = {}) {
    const r = await fetch(runtime.url + path, {
      method,
      headers: anonymous
        ? {}
        : {
            Authorization: `Bearer ${other ? runtime.guest_bearer : runtime.bearer}`,
          },
    });
    assertResponseIdentity(r.headers, runtime);
    const value = await r.json();
    events.push({
      type: "http",
      runtime_id: runtime.runtime_id,
      path,
      method,
      status: r.status,
      value,
    });
    return { status: r.status, value };
  }
  async function call(name, args) {
    const r = await fetch(runtime.url + "/mcp/maps", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${runtime.bearer}`,
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: ++requestId,
        method: "tools/call",
        params: { name, arguments: args },
      }),
      signal: AbortSignal.timeout(100000),
    });
    assertResponseIdentity(r.headers, runtime);
    const body = await r.json();
    assert.equal(r.status, 200);
    const value = body.result.structuredContent;
    events.push({
      type: "mcp_call",
      runtime_id: runtime.runtime_id,
      name,
      input: args,
      output: value,
    });
    return value;
  }
  const prefix = agent.run_id + "-boundaries";
  try {
    await boot();
    const read = async () => (await http("/api/maps/" + info.snapshot.map_id)).value.snapshot;
    const initial = await read();
    const sources = initial.days.flatMap((d) => d.stops).slice(0, 3);
    assert.equal(sources.length, 3);
    let map = (
      await call("create_map", {
        title: "真实来源约束验收",
        city: "Tokyo",
        timezone: "Asia/Tokyo",
        day_count: 2,
        idempotency_key: prefix + "-create",
      })
    ).data.snapshot;
    const resolved = await call("search_places", {
      map_id: map.map_id,
      queries: sources.map((s) => s.name),
    });
    assert(resolved.ok);
    for (const s of sources)
      assert(
        resolved.data.queries.some((q) => q.candidates.some((c) => c.place_ref === s.place_ref)),
      );
    map = (
      await call("plot_places", {
        map_id: map.map_id,
        expected_version: map.version,
        idempotency_key: prefix + "-plot",
        items: sources.map((s, i) => ({
          place_ref: s.place_ref,
          day_id: map.days[i ? 1 : 0].day_id,
          duration_minutes: 30,
          ...(i ? {} : { lock_to_day: true, fixed_start_minute: 540 }),
        })),
      })
    ).data.snapshot;
    const buildArgs = {
      map_id: map.map_id,
      expected_version: map.version,
      idempotency_key: prefix + "-build",
      transport_mode: "walking",
      allow_unknown_travel: false,
      day_plans: map.days.map((d) => ({
        day_id: d.day_id,
        stop_ids: d.stops.map((s) => s.stop_id),
        start_minute: 540,
        end_minute: 1080,
        order_policy: "preserve",
      })),
    };
    const built = await call("build_route", buildArgs);
    assert(built.ok, JSON.stringify(built.error));
    map = built.data.snapshot;
    const update = async (operation, key, dry_run = false) =>
      call("update_day", {
        map_id: map.map_id,
        expected_version: map.version,
        idempotency_key: prefix + key,
        dry_run,
        operation,
      });
    const locked = await update(
      {
        type: "move_stop",
        stop_id: map.days[0].stops[0].stop_id,
        target_day_id: map.days[1].day_id,
        target_index: 0,
      },
      "-lock",
    );
    assert.equal(locked.error?.code, "INFEASIBLE");
    const late = await update(
      { type: "set_start_time", day_id: map.days[0].day_id, start_minute: 600 },
      "-late",
    );
    assert.equal(late.error?.code, "INFEASIBLE");
    const unchanged = (await http("/api/maps/" + map.map_id)).value.snapshot;
    assert.deepEqual(unchanged, map);
    await control("fault", "unknown");
    const unavailable = await call("build_route", {
      ...buildArgs,
      expected_version: map.version,
      idempotency_key: prefix + "-unknown-denied",
    });
    assert.equal(unavailable.error?.code, "PROVIDER_UNAVAILABLE");
    const unknown = await call("build_route", {
      ...buildArgs,
      expected_version: map.version,
      idempotency_key: prefix + "-unknown-allowed",
      allow_unknown_travel: true,
    });
    assert(unknown.ok);
    map = unknown.data.snapshot;
    assert(
      map.days[1].legs.every((l) => l.duration_minutes === null && l.evidence_status === "unknown"),
    );
    const bounded = await call("build_route", {
      ...buildArgs,
      expected_version: map.version,
      idempotency_key: prefix + "-lower-bound",
      allow_unknown_travel: true,
      day_plans: buildArgs.day_plans.map((d, i) => ({ ...d, end_minute: i ? 590 : 1080 })),
    });
    assert.equal(bounded.error?.code, "INFEASIBLE"); // 2 × 30min cannot fit 50min even when travel is unknown.
    assert.deepEqual((await http("/api/maps/" + map.map_id)).value.snapshot, map);
    await control("fault", null);
    checks.push({
      case_id: "C4",
      status: "pass",
      detail:
        "实际 HTTP 锁日/预约迟到拒绝；受控交通缺失时不编 ETA，已知停留60分钟仍不能塞进50分钟窗口",
    });

    const makeLink = async (key, days) => {
      const r = await call("get_map_link", {
        map_id: initial.map_id,
        expected_version: initial.version,
        idempotency_key: prefix + key,
        expires_in_days: days,
        visible_stop_ids: initial.days.flatMap((d) => d.stops).map((s) => s.stop_id),
      });
      assert(r.ok);
      return r.data;
    };
    const revoked = await makeLink("-revoke", 7),
      expires = await makeLink("-expiry", 1),
      durable = await makeLink("-durable", 7);
    const path = (l) => "/api/share/" + new URL(l.share_url).pathname.split("/").at(-1);
    assert.equal((await http(path(revoked), { anonymous: true })).status, 200);
    assert.equal(
      (await http(path(revoked) + "/revoke", { method: "POST", other: true })).status,
      404,
    );
    assert.equal(
      (await http(path(revoked) + "/revoke", { method: "POST", anonymous: true })).status,
      404,
    );
    assert.equal((await http(path(revoked) + "/revoke", { method: "POST" })).status, 200);
    for (let i = 0; i < 2; i++)
      assert.equal((await http(path(revoked), { anonymous: true })).status, 404);
    await control("clock", 86401000);
    assert.equal((await http(path(expires), { anonymous: true })).status, 404);
    assert.equal((await http(path(durable), { anonymous: true })).status, 200);
    await control("clock", 0);

    const { chromium } = await import(pathToFileURL(playwrightModule).href);
    browser = await chromium.launch({
      headless: true,
      executablePath:
        process.env.MAP_CHAIN_BROWSER ??
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    });
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
    const page = await context.newPage();
    const pageErrors = [];
    page.on("pageerror", (e) => pageErrors.push(e.message));
    assert(
      (
        await context.request.post(runtime.url + "/api/session", {
          headers: { Authorization: `Bearer ${runtime.bearer}` },
        })
      ).ok(),
    );
    await page.goto(runtime.url + "/m/" + initial.map_id);
    await page.locator(".pin").first().waitFor();
    const chosen = (
      await page.locator(".pin").evaluateAll((pins) =>
        pins.map((p) => {
          const r = p.getBoundingClientRect();
          return { sid: p.dataset.pin, x: r.x + r.width / 2, y: r.y + r.height / 2 };
        }),
      )
    )
      .map((p, _, all) => ({
        ...p,
        clearance: Math.min(
          ...all.filter((q) => p.sid !== q.sid).map((q) => Math.hypot(p.x - q.x, p.y - q.y)),
        ),
      }))
      .sort((a, b) => b.clearance - a.clearance)[0];
    const sourceDay = initial.days.find((d) => d.stops.some((s) => s.stop_id === chosen.sid));
    const target = initial.days
      .filter((d) => d.day_id !== sourceDay.day_id)
      .sort((a, b) => a.stops.length - b.stops.length)[0];
    const drop = await page
      .locator("#day-rail .day-drop")
      .nth(initial.days.indexOf(target))
      .boundingBox();
    const drag = async () => {
      await page.mouse.move(chosen.x, chosen.y);
      await page.mouse.down();
      await page.mouse.move(drop.x + drop.width / 2, drop.y + drop.height / 2, { steps: 14 });
      await page.mouse.up();
    };
    await control("fault", "provider");
    await drag();
    await page.locator("#notice.error").waitFor();
    assert.match(await page.locator("#notice").textContent(), /原行程|保留|未改变/);
    assert.deepEqual(await read(), initial);
    assert.equal(await page.locator(".pin").count(), initial.days.flatMap((d) => d.stops).length);
    mkdirSync(join(outDir, "screenshots"), { recursive: true });
    const screenshot = "screenshots/real-provider-failure.png";
    await page.screenshot({ path: join(outDir, screenshot), fullPage: true });
    shots.push(screenshot);
    await control("fault", null);
    await drag();
    await page.waitForFunction(
      (v) => document.querySelector("#version").textContent !== `版本 ${v}`,
      initial.version,
      { timeout: 60000 },
    );
    const edited = await read();
    assert.equal(edited.version, initial.version + 1);
    assert(
      edited.days
        .find((d) => d.day_id === target.day_id)
        .stops.some((s) => s.stop_id === chosen.sid),
    );
    assert.deepEqual(pageErrors, []);
    events.push({
      type: "browser_assertion",
      failed_drag_rolled_back: true,
      retry_committed: true,
      before: initial,
      after: edited,
    });
    checks.push({
      case_id: "E5",
      status: "pass",
      detail:
        "真实浏览器拖动触发受控 provider 故障，显示失败并保留地图；解除故障后再次指针拖动成功；故障仅由私有IPC设置",
    });

    const retryArgs = {
      map_id: edited.map_id,
      expected_version: edited.version,
      idempotency_key: prefix + "-restart-idempotent",
      dry_run: false,
      operation: {
        type: "set_stop_duration",
        stop_id: edited.days[0].stops[0].stop_id,
        duration_minutes: edited.days[0].stops[0].duration_minutes,
      },
    };
    const committed = await call("update_day", retryArgs);
    assert(committed.ok);
    const previousRuntime = runtime.runtime_id,
      previousPid = child.pid;
    await stop();
    await boot();
    assert.notEqual(child.pid, previousPid);
    assert.notEqual(runtime.runtime_id, previousRuntime);
    assert.deepEqual(await read(), committed.data.snapshot);
    assert.deepEqual(await call("update_day", retryArgs), committed);
    // Same browser cookie remains authorized because the signing secret survived the process restart.
    const cookieRead = await context.request.get(runtime.url + "/api/maps/" + initial.map_id);
    assert.equal(cookieRead.status(), 200);
    assert.deepEqual((await cookieRead.json()).snapshot, committed.data.snapshot);
    assert.equal((await http(path(revoked), { anonymous: true })).status, 404);
    assert.equal((await http(path(durable), { anonymous: true })).status, 200);
    await control("clock", 86401000);
    assert.equal((await http(path(expires), { anonymous: true })).status, 404);
    checks.push({
      case_id: "D1",
      status: "pass",
      detail:
        "独立 Node 子进程退出并从磁盘重新启动；地图、撤销授权、浏览器cookie和已提交幂等重试均存续，拒绝的事务未写入",
    });
    checks.push({
      case_id: "F3",
      status: "pass",
      detail:
        "真实 HTTP 撤销与跨身份拒绝、重复访问、重启后撤销保持；注入服务时钟跨过1日期限后拒绝，系统时钟未改变",
    });
    const base = {
      ...agent,
      checks: undefined,
      kind: undefined,
      artifacts: undefined,
      meta: undefined,
      runtime_id: runtime.runtime_id,
    };
    const trace = {
      source_runtime_id: source.runtime_id,
      controlled_clock: true,
      controlled_provider_failure: true,
      events,
    };
    for (const [kind, ids] of [
      ["routes_live", ["C4"]],
      ["browser_live", ["E5"]],
      ["persistence_live", ["D1"]],
      ["security_live", ["F3"]],
    ])
      writeReceipt(outDir, base, {
        kind,
        prefix: "boundaries-" + kind,
        checks: checks.filter((c) => ids.includes(c.case_id)),
        trace,
        attachments: kind === "browser_live" ? shots : [],
      });
    const receipts = readdirSync(outDir)
      .filter((n) => n.endsWith(".receipt.json"))
      .map((n) => JSON.parse(readFileSync(join(outDir, n), "utf8")));
    const report = scoreReceipts({
      candidateDigest: candidateDigest(),
      rubricHash: rubricHash(),
      profile: agent.profile,
      receipts,
      readEvidence: fileEvidenceReader(outDir),
      expectedRevision: runtime.source_revision,
    });
    writeFileSync(join(outDir, "score.json"), JSON.stringify(report, null, 2));
    writeFileSync(join(outDir, "score.md"), markdown(report));
    console.log(JSON.stringify({ verified_points: report.verified_points, checks }));
    return report;
  } finally {
    await browser?.close();
    await stop();
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2),
    get = (k) => args[args.indexOf(k) + 1];
  await collectBoundaries({
    outDir: resolve(get("--out")),
    runtimeFile: resolve(get("--runtime")),
    dir: resolve(get("--dir")),
    envFile: get("--env-file"),
    playwrightModule: process.env.MAP_CHAIN_PLAYWRIGHT,
  });
}
