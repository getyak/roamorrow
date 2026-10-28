import { readFileSync, writeFileSync, mkdirSync, readdirSync } from "node:fs";
import { resolve, join } from "node:path";
import { pathToFileURL } from "node:url";
import { candidateDigest, rubricHash, scoreReceipts, markdown } from "./score.mjs";
import { writeReceipt, fileEvidenceReader } from "./evidence.mjs";
import { assertRuntimeIdentity } from "./integrity.mjs";
export async function runBrowser({ outDir, runtimeFile, playwrightModule } = {}) {
  if (!playwrightModule)
    throw Error(
      "set MAP_CHAIN_PLAYWRIGHT to installed Playwright index.mjs; no browser dependencies are installed by this runner",
    );
  const { chromium } = await import(pathToFileURL(playwrightModule).href);
  const runtime = JSON.parse(readFileSync(runtimeFile, "utf8")),
    agent = JSON.parse(readFileSync(join(outDir, "agent.receipt.json"), "utf8")),
    mapInfo = JSON.parse(readFileSync(join(outDir, "map.private.json"), "utf8"));
  assertRuntimeIdentity(runtime, candidateDigest(), rubricHash());
  if (agent.runtime_id !== runtime.runtime_id) throw Error("wrong runtime");
  const base = {
    ...agent,
    checks: undefined,
    kind: undefined,
    meta: undefined,
    artifacts: undefined,
    finished_at: new Date().toISOString(),
  };
  const browser = await chromium.launch({
      headless: true,
      executablePath:
        process.env.MAP_CHAIN_BROWSER ??
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    }),
    context = await browser.newContext({ viewport: { width: 1440, height: 1000 } }),
    page = await context.newPage(),
    errors = [],
    checks = [],
    events = [];
  const shots = [];
  mkdirSync(join(outDir, "screenshots"), { recursive: true });
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => {
    if (m.type() === "error") errors.push(m.text());
  });
  const read = async () => {
    const response = await context.request.get(
      runtime.url + "/api/maps/" + mapInfo.snapshot.map_id,
    );
    return (await response.json()).snapshot;
  };
  const check = (id, ok, detail) =>
    checks.push({ case_id: id, status: ok ? "pass" : "fail", detail });
  const shot = async (name) => {
    const filename = `screenshots/${name}.png`;
    await page.screenshot({ path: join(outDir, filename), fullPage: true });
    shots.push(filename);
  };
  try {
    const session = await context.request.post(runtime.url + "/api/session", {
      headers: { Authorization: `Bearer ${runtime.bearer}` },
    });
    if (!session.ok()) throw Error("owner session failed");
    await page.goto(runtime.url + "/m/" + mapInfo.snapshot.map_id, {
      waitUntil: "domcontentloaded",
    });
    await page.locator(".pin").first().waitFor();
    await page.waitForTimeout(1500);
    const before = await read();
    await shot("real-map");
    const label = await page.locator("#evidence-label").textContent();
    const routes = await page.locator(".actual-route").count();
    check(
      "C5",
      !before.demo &&
        label.includes("OSRM") &&
        routes === before.days.flatMap((d) => d.legs).length,
      "真实 leg geometry 绘制到 SVG，未画成 stop 直线",
    );
    const row = page.locator(".stop-info").first();
    await row.click();
    const fromRow = await page.locator(".pin.selected").getAttribute("data-pin");
    const selectedRow = await page.locator(".stop-row.selected").getAttribute("data-stop");
    await page.locator(".pin").last().click();
    const fromPin = await page.locator(".pin.selected").getAttribute("data-pin");
    check(
      "E2",
      fromRow === selectedRow &&
        (await page
          .locator(`.stop-row[data-stop="${fromPin}"]`)
          .evaluate((el) => el.classList.contains("selected"))),
      "时间轴按钮和 pin 点击都更新同一个选择状态",
    );
    await page.locator(".close-selection").click();
    const candidates = await page.locator(".pin").evaluateAll((pins) =>
      pins.map((p) => {
        const r = p.getBoundingClientRect();
        return { sid: p.dataset.pin, x: r.x + r.width / 2, y: r.y + r.height / 2 };
      }),
    );
    const chosen = candidates
      .map((p) => ({
        ...p,
        clearance: Math.min(
          ...candidates.filter((q) => q.sid !== p.sid).map((q) => Math.hypot(q.x - p.x, q.y - p.y)),
        ),
      }))
      .sort((a, b) => b.clearance - a.clearance)[0];
    const source = before.days.find((d) => d.stops.some((s) => s.stop_id === chosen.sid)),
      target = before.days
        .filter((d) => d.day_id !== source.day_id)
        .sort((a, b) => a.stops.length - b.stops.length)[0],
      targetIndex = before.days.findIndex((d) => d.day_id === target.day_id);
    const drop = await page.locator("#day-rail .day-drop").nth(targetIndex).boundingBox();
    await page.mouse.move(chosen.x, chosen.y);
    await page.mouse.down();
    await page.mouse.move(drop.x + drop.width / 2, drop.y + drop.height / 2, { steps: 14 });
    await page.mouse.up();
    await page.waitForFunction(
      (v) => document.querySelector("#version").textContent !== `版本 ${v}`,
      before.version,
      { timeout: 60000 },
    );
    const after = await read();
    const moved = after.days
      .find((d) => d.day_id === target.day_id)
      ?.stops.find((s) => s.stop_id === chosen.sid);
    check(
      "E1",
      !!moved &&
        !after.days
          .find((d) => d.day_id === source.day_id)
          .stops.some((s) => s.stop_id === chosen.sid) &&
        after.version === before.version + 1 &&
        JSON.stringify(
          before.days.filter((d) => ![source.day_id, target.day_id].includes(d.day_id)),
        ) ===
          JSON.stringify(
            after.days.filter((d) => ![source.day_id, target.day_id].includes(d.day_id)),
          ),
      "真实 pointer 拖动，两个日期原子更新，其他日期不变",
    );
    events.push({ type: "drag", before, after });
    await shot("real-dragged");
    await page.getByRole("button", { name: "撤销上一步" }).click();
    await page.waitForFunction(
      (v) => document.querySelector("#version").textContent === `版本 ${v}`,
      after.version + 1,
    );
    const undo = await read();
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.locator(".pin").first().waitFor();
    check(
      "E3",
      JSON.stringify(undo.days) === JSON.stringify(before.days) &&
        undo.version === after.version + 1,
      "撤销是新版本，刷新读回一致；其他冲突由 HTTP 验收覆盖",
    );
    events.push({ type: "undo", snapshot: undo });
    const guest = await browser.newContext({ viewport: { width: 1440, height: 1000 } }),
      gp = await guest.newPage();
    await gp.goto(mapInfo.share_url, { waitUntil: "domcontentloaded" });
    await gp.locator("#fork").waitFor({ state: "visible" });
    check(
      "D2",
      (await gp.locator(".pin").count()) === before.days.flatMap((d) => d.stops).length &&
        (await gp.locator("#share").isDisabled()),
      "全新浏览器无所有者会话，实际分享 URL 可读且原图不可改",
    );
    await guest.request.post(runtime.url + "/api/session", {
      headers: { Authorization: `Bearer ${runtime.guest_bearer}` },
    });
    await gp.locator("#fork").click();
    await gp.waitForURL(/\/m\//, { waitUntil: "domcontentloaded" });
    check(
      "D3",
      !gp.url().endsWith(before.map_id) && (await read()).version === undo.version,
      "另一授权身份复制为新 map，原图版本未变",
    );
    await guest.close();
    await page.setViewportSize({ width: 390, height: 844 });
    await page.reload({ waitUntil: "domcontentloaded" });
    await page.locator(".pin").first().waitFor();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);
    const touch = await page
      .locator(".pin,.stop-info,#day-rail button,.map-tools button")
      .evaluateAll((es) =>
        es.every((e) => {
          const r = e.getBoundingClientRect();
          return r.height >= 44 && r.width >= 44;
        }),
      );
    await page.locator(".stop-info").first().focus();
    await page.keyboard.press("Enter");
    const keyboardMenu = await page.locator("#selection").isVisible();
    check(
      "E4",
      !overflow && touch && keyboardMenu,
      "390px 无横向溢出，主要操作目标≥44px，键盘 Enter 打开替代操作菜单；非真机结论",
    );
    await shot("real-mobile");
    check("G3", errors.length === 0, "最终页面无应用 console error，错误/未知来源标签可见");
    checks.push({
      case_id: "E5",
      status: "unverified",
      detail:
        "公网 scoped 模式禁用故障注入，本 cohort 尚未完成安全的 provider 故障与重试注入，不计分",
    });
  } catch (error) {
    checks.push({
      case_id: "E1",
      status: "fail",
      detail: `浏览器旅程未完成：${error.message.slice(0, 240)}`,
    });
    checks.push({
      case_id: "G3",
      status: "fail",
      detail: "页面未完成主要交互，不能用缺少 console error 代替正常渲染",
    });
    events.push({
      type: "browser_failure",
      message: error.message,
      notice: await page
        .locator("#notice")
        .textContent()
        .catch(() => null),
    });
    await shot("failure").catch(() => {});
  } finally {
    await browser.close();
  }
  if (candidateDigest() !== runtime.candidate_digest)
    throw Error("candidate changed during browser run");
  writeReceipt(outDir, base, {
    kind: "browser_live",
    prefix: "browser",
    checks,
    trace: { events, errors, viewports: ["1440x1000", "390x844"], screenshots: shots },
    attachments: shots,
  });
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
  if (checks.some((c) => c.status === "fail")) process.exitCode = 1;
  console.log(
    JSON.stringify(
      {
        verified_points: report.verified_points,
        unverified_points: report.unverified_points,
        accepted: report.accepted,
        errors,
        checks: checks.map((c) => ({ case: c.case_id, status: c.status })),
      },
      null,
      2,
    ),
  );
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2),
    get = (f, d) => {
      const i = args.indexOf(f);
      return i < 0 ? d : args[i + 1];
    };
  await runBrowser({
    outDir: resolve(get("--out", "live-agent-result")),
    runtimeFile: resolve(get("--runtime", "runtime.private.json")),
    playwrightModule: process.env.MAP_CHAIN_PLAYWRIGHT,
  });
}
