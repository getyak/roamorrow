const $ = (id) => document.getElementById(id);
const esc = (x) =>
  String(x).replace(
    /[&<>"']/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c],
  );
let snapshot = null,
  canEdit = true,
  busy = false,
  lastEdit = null,
  shareURL = null,
  trace = [],
  selected = null,
  zoom = 1,
  drag = null;
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
const themes = ["浅草与上野", "原宿与涩谷", "筑地与银座"];
const clock = (n) =>
  n === null || n === undefined
    ? "待核查"
    : `${String(Math.floor(n / 60)).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;
const key = () => crypto.randomUUID();
function notice(text, error = false) {
  $("notice").textContent = text;
  $("notice").classList.toggle("error", error);
  $("notice").setAttribute("role", error ? "alert" : "status");
}
function setBusy(value) {
  busy = value;
  $("run").disabled = value;
  $("share").disabled = value || !snapshot || !canEdit;
  $("undo").disabled = value || !lastEdit || !canEdit;
  document.body.classList.toggle("working", value);
}
async function rpc(method, params, options = {}) {
  const response = await fetch("/mcp/maps", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json, text/event-stream",
      "MCP-Protocol-Version": "2025-11-25",
      ...(options.fault ? { "X-Demo-Fault": options.fault } : {}),
    },
    body: JSON.stringify({ jsonrpc: "2.0", id: key(), method, params }),
  });
  const body = await response.json();
  if (!response.ok || body.error) throw Error(body.error?.message ?? body.error ?? "请求失败");
  return body.result;
}
async function call(name, args, { fault = "" } = {}) {
  const result = await rpc("tools/call", { name, arguments: args }, { fault });
  const out = result.structuredContent;
  trace.push({ name, input: args, output: out });
  $("trace-count").textContent = trace.length;
  renderTrace();
  if (!out.ok) {
    const err = Error(out.error.message);
    err.code = out.error.code;
    err.details = out.error.details;
    throw err;
  }
  return out.data;
}
function tab(name) {
  $("chat-panel").hidden = name !== "chat";
  $("plan-panel").hidden = name !== "plan";
  $("chat-tab").classList.toggle("active", name === "chat");
  $("plan-tab").classList.toggle("active", name === "plan");
}
$("chat-tab").onclick = () => tab("chat");
$("plan-tab").onclick = () => tab("plan");
function step(text) {
  const li = document.createElement("li");
  li.textContent = text;
  $("flow-steps").append(li);
}
async function run() {
  if (busy) return;
  setBusy(true);
  lastEdit = null;
  shareURL = null;
  trace = [];
  snapshot = null;
  selected = null;
  render();
  tab("chat");
  $("flow-steps").innerHTML = "";
  $("agent-answer").hidden = true;
  try {
    await rpc("initialize", {
      protocolVersion: "2025-11-25",
      capabilities: {},
      clientInfo: { name: "scripted-grok-boundary-demo", version: "1.0" },
    });
    await rpc("tools/list", {});
    const created = await call("create_map", {
      title: "东京 3 天",
      city: "Tokyo, Japan",
      day_count: 3,
      timezone: "Asia/Tokyo",
      idempotency_key: key(),
    });
    snapshot = created.snapshot;
    step("create_map · 建立三天的私有地图");
    const searched = await call("search_places", { map_id: snapshot.map_id, queries: names });
    const places = searched.queries.map((q) => {
      if (q.status !== "resolved") throw Error(`地点需要消歧：${q.query}`);
      return q.candidates[0];
    });
    step("search_places · 解析九个地点（演示资料）");
    const plotted = await call("plot_places", {
      map_id: snapshot.map_id,
      expected_version: snapshot.version,
      idempotency_key: key(),
      items: places.map((p, i) => ({
        place_ref: p.place_ref,
        day_id: snapshot.days[Math.floor(i / 3)].day_id,
        duration_minutes: p.duration_minutes,
      })),
    });
    snapshot = plotted.snapshot;
    step("plot_places · 按区域落点");
    const built = await call("build_route", {
      map_id: snapshot.map_id,
      expected_version: snapshot.version,
      idempotency_key: key(),
      transport_mode: "transit",
      allow_unknown_travel: true,
      day_plans: snapshot.days.map((d) => ({
        day_id: d.day_id,
        stop_ids: d.stops.map((s) => s.stop_id),
        start_minute: 540,
        end_minute: 1080,
        order_policy: "preserve",
      })),
    });
    snapshot = built.snapshot;
    step("build_route · 排好顺序与计划时间");
    const link = await makeLink();
    shareURL = link.share_url;
    step("get_map_link · 保存可重开的只读链接");
    $("agent-answer").innerHTML =
      `已经按浅草与上野、原宿与涩谷、筑地与银座排成 3 天。<br>日期待补，交通为演示估算。<br><a href="${esc(shareURL)}" target="_blank">打开已排好的地图 ↗</a>`;
    $("agent-answer").hidden = false;
    canEdit = true;
    render();
    tab("plan");
    notice("已排成 3 天。选中一个地点，或把 pin 拖到其他天。");
    history.replaceState({}, "", `/m/${snapshot.map_id}`);
  } catch (e) {
    notice(e.message, true);
  } finally {
    setBusy(false);
  }
}
async function makeLink() {
  return call("get_map_link", {
    map_id: snapshot.map_id,
    expected_version: snapshot.version,
    idempotency_key: key(),
    expires_in_days: 7,
    visible_stop_ids: snapshot.days.flatMap((d) => d.stops.map((s) => s.stop_id)),
  });
}
$("run").onclick = run;
$("reset").onclick = run;
function render() {
  $("empty-map").hidden = !!snapshot;
  $("day-rail").hidden = !snapshot;
  $("version").textContent = snapshot ? `版本 ${snapshot.version}` : "等待生成";
  $("plan-status").textContent = snapshot
    ? `${snapshot.days.length} 天 · 日期待补 · 草案`
    : "行程还没生成";
  $("guest-actions").hidden = canEdit;
  $("share").disabled = busy || !snapshot || !canEdit;
  $("undo").disabled = busy || !lastEdit || !canEdit;
  if (!snapshot) {
    $("days").innerHTML = "";
    $("pins").innerHTML = "";
    $("routes").innerHTML = "";
    $("day-rail").innerHTML = "";
    $("selection").hidden = true;
    return;
  }
  $("days").innerHTML = snapshot.days
    .map(
      (d) =>
        `<section class="day day-drop" data-day="${d.day_id}" style="--day:${d.color}"><button class="day-heading" data-day-select="${d.day_id}" aria-label="查看第 ${d.day_index} 天"><span class="day-badge">${d.day_index}</span><strong>${themes[d.day_index - 1] ?? d.label}</strong><small>${d.stops.length} 个地点</small></button><div class="day-sub">${clock(d.start_minute)} 出发　交通 ${d.total_travel_minutes ?? "待核查"} 分钟${d.total_travel_minutes === null ? "" : "（估算）"}</div>${d.stops.map((s, i) => `<div class="stop-row ${s.stop_id === selected ? "selected" : ""}" data-stop="${s.stop_id}" draggable="${canEdit}"><span class="time">${clock(s.start_minute)}</span><button class="stop-info" data-select="${s.stop_id}" aria-label="${esc(s.name)}，第 ${d.day_index} 天，第 ${i + 1} 站"><strong>${i + 1}. ${esc(s.name)}</strong><small>停留 ${s.duration_minutes} 分钟</small></button><button class="drag-handle" data-select="${s.stop_id}" aria-label="调整${esc(s.name)}">⠿</button></div>`).join("") || '<div class="empty-day">这一天空出来了。加入一个想去的地方。</div>'}</section>`,
    )
    .join("");
  $("day-rail").innerHTML = snapshot.days
    .map(
      (d) =>
        `<button class="day-drop" data-day="${d.day_id}" style="--day:${d.color}" aria-label="放到第 ${d.day_index} 天">第 ${d.day_index} 天<span>${d.stops.length}</span></button>`,
    )
    .join("");
  const points = snapshot.days.flatMap((d) =>
    d.stops.map((s, i) => ({ s, d, i, p: project(s.coordinates) })),
  );
  $("pins").innerHTML = points
    .map(
      ({ s, d, i, p }) =>
        `<button class="pin ${s.stop_id === selected ? "selected" : ""}" style="--day:${d.color};left:${(p[0] / mapSize()[0]) * 100}%;top:${(p[1] / mapSize()[1]) * 100}%" data-select="${s.stop_id}" data-pin="${s.stop_id}" data-name="${esc(s.name)}" aria-label="地图：${esc(s.name)}，第 ${d.day_index} 天，第 ${i + 1} 站"><span>${d.day_index}.${i + 1}</span></button>`,
    )
    .join("");
  $("routes").innerHTML = snapshot.days
    .map(
      (d) =>
        `<polyline class="route-line" stroke="${d.color}" points="${d.stops.map((s) => project(s.coordinates).join(",")).join(" ")}"><title>${d.label}，示意连线，非真实导航</title></polyline>`,
    )
    .join("");
  renderSelection();
}
function renderSelection() {
  const day = snapshot?.days.find((d) => d.stops.some((s) => s.stop_id === selected));
  const stop = day?.stops.find((s) => s.stop_id === selected);
  $("selection").hidden = !stop;
  if (!stop) return;
  $("selection").innerHTML =
    `<button class="close-selection" aria-label="关闭地点操作">×</button><strong>${esc(stop.name)}</strong><p>第 ${day.day_index} 天 · 停留 ${stop.duration_minutes} 分钟<br>坐标保持不变，换天时两天一起重算。</p><div class="move-actions">${
      canEdit
        ? snapshot.days
            .filter((d) => d.day_id !== day.day_id)
            .map((d) => `<button data-move="${d.day_id}">移到第 ${d.day_index} 天</button>`)
            .join("")
        : '<button id="selection-fork">复制并编辑</button>'
    }${canEdit ? '<button data-order="up">上移</button><button data-order="down">下移</button>' : ""}</div><p><a href="${esc(stop.source_url)}" target="_blank" rel="noreferrer">地点资料 ↗</a>　坐标未作实时核验</p>`;
}
function select(sid) {
  selected = sid;
  render();
}
async function edit(operation) {
  if (busy || !canEdit) return;
  setBusy(true);
  const k = key(),
    version = snapshot.version;
  notice("正在更新涉及的日期，原行程已保留…");
  try {
    const fault = $("scenario").value;
    await call(
      "update_day",
      {
        map_id: snapshot.map_id,
        expected_version: version,
        idempotency_key: `${k}-preview`,
        dry_run: true,
        operation,
      },
      { fault },
    );
    const result = await call(
      "update_day",
      {
        map_id: snapshot.map_id,
        expected_version: version,
        idempotency_key: k,
        dry_run: false,
        operation,
      },
      { fault },
    );
    snapshot = result.snapshot;
    lastEdit = result.edit_id;
    render();
    notice(`${result.diff.join("；")}。已保存，可撤销。`);
    return result;
  } catch (e) {
    if (e.code === "VERSION_CONFLICT" && e.details?.snapshot) {
      snapshot = e.details.snapshot;
      lastEdit = null;
      render();
      notice("地图已在别处更新，已读回最新版本。请重新执行这次调整。", true);
    } else notice(`${e.message}。位置与原行程未改变。`, true);
  } finally {
    setBusy(false);
  }
}
function move(sid, targetDayId) {
  const day = snapshot.days.find((d) => d.day_id === targetDayId);
  const origin = snapshot.days.find((d) => d.stops.some((s) => s.stop_id === sid));
  if (origin.day_id === targetDayId) return;
  return edit({
    type: "move_stop",
    stop_id: sid,
    target_day_id: targetDayId,
    target_index: day.stops.length,
  });
}
$("undo").onclick = async () => {
  if (!lastEdit) return;
  const result = await edit({ type: "undo", edit_id: lastEdit });
  if (result) {
    lastEdit = null;
    $("undo").disabled = true;
  }
};
document.addEventListener("click", (e) => {
  const sel = e.target.closest("[data-select]");
  if (sel && !drag?.moved) select(sel.dataset.select);
  if (e.target.closest(".close-selection")) {
    selected = null;
    renderSelection();
  }
  const moveButton = e.target.closest("[data-move]");
  if (moveButton) move(selected, moveButton.dataset.move);
  const order = e.target.closest("[data-order]");
  if (order && selected) {
    const d = snapshot.days.find((d) => d.stops.some((s) => s.stop_id === selected));
    const ids = d.stops.map((s) => s.stop_id),
      from = ids.indexOf(selected),
      to = from + (order.dataset.order === "up" ? -1 : 1);
    if (to >= 0 && to < ids.length) {
      [ids[from], ids[to]] = [ids[to], ids[from]];
      edit({ type: "reorder_stops", day_id: d.day_id, stop_ids: ids });
    }
  }
  const rail = e.target.closest("#day-rail [data-day]");
  if (rail && !document.body.classList.contains("dragging")) {
    if (selected && canEdit) move(selected, rail.dataset.day);
    else {
      const day = snapshot.days.find((d) => d.day_id === rail.dataset.day);
      if (day.stops[0]) select(day.stops[0].stop_id);
    }
  }
  if (e.target.closest("[data-close]")) $(e.target.closest("[data-close]").dataset.close).close();
  if (e.target.id === "selection-fork") fork();
});
function clearDrag() {
  document.querySelectorAll(".drop-over").forEach((e) => e.classList.remove("drop-over"));
  document.body.classList.remove("dragging");
  $("drag-ghost").hidden = true;
}
document.addEventListener("pointerdown", (e) => {
  const pin = e.target.closest("[data-pin]");
  if (!pin || !canEdit || busy || e.button !== 0) return;
  drag = { sid: pin.dataset.pin, x: e.clientX, y: e.clientY, moved: false };
  pin.setPointerCapture(e.pointerId);
});
document.addEventListener("pointermove", (e) => {
  if (!drag) return;
  if (Math.hypot(e.clientX - drag.x, e.clientY - drag.y) < 7 && !drag.moved) return;
  drag.moved = true;
  document.body.classList.add("dragging");
  const stop = snapshot.days.flatMap((d) => d.stops).find((s) => s.stop_id === drag.sid);
  $("drag-ghost").textContent = `${stop.name} · 放到另一天`;
  $("drag-ghost").hidden = false;
  $("drag-ghost").style.left = `${e.clientX + 15}px`;
  $("drag-ghost").style.top = `${e.clientY - 30}px`;
  document.querySelectorAll(".drop-over").forEach((el) => el.classList.remove("drop-over"));
  document
    .elementsFromPoint(e.clientX, e.clientY)
    .find((el) => el.closest(".day-drop"))
    ?.closest(".day-drop")
    .classList.add("drop-over");
});
document.addEventListener("pointerup", (e) => {
  if (!drag) return;
  const current = drag;
  drag = null;
  clearDrag();
  if (current.moved) {
    const target = document
      .elementsFromPoint(e.clientX, e.clientY)
      .find((el) => el.closest(".day-drop"))
      ?.closest(".day-drop");
    if (target) move(current.sid, target.dataset.day);
    else notice("已取消，原行程未改变。");
  }
});
document.addEventListener("pointercancel", () => {
  drag = null;
  clearDrag();
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    drag = null;
    clearDrag();
    selected = null;
    renderSelection();
  }
});
document.addEventListener("dragstart", (e) => {
  const row = e.target.closest(".stop-row");
  if (row && canEdit) {
    e.dataTransfer.setData("text/plain", row.dataset.stop);
    document.body.classList.add("dragging");
  }
});
document.addEventListener("dragover", (e) => {
  if (e.target.closest(".day-drop")) {
    e.preventDefault();
    e.target.closest(".day-drop").classList.add("drop-over");
  }
});
document.addEventListener("dragleave", (e) =>
  e.target.closest(".day-drop")?.classList.remove("drop-over"),
);
document.addEventListener("drop", (e) => {
  const target = e.target.closest(".day-drop");
  if (target) {
    e.preventDefault();
    const sid = e.dataTransfer.getData("text/plain");
    clearDrag();
    if (sid && snapshot.days.some((d) => d.stops.some((s) => s.stop_id === sid)))
      move(sid, target.dataset.day);
  }
});
document.addEventListener("dragend", clearDrag);
$("share").onclick = async () => {
  if (!snapshot) return;
  try {
    if (!shareURL) shareURL = (await makeLink()).share_url;
    $("share-url").value = shareURL;
    $("open-share").href = shareURL;
    $("share-dialog").showModal();
  } catch (e) {
    notice(e.message, true);
  }
};
$("copy-link").onclick = async () => {
  try {
    await navigator.clipboard.writeText(shareURL);
    $("copy-link").textContent = "已复制";
  } catch {
    $("share-url").select();
    notice("已选中链接，请复制。");
  }
};
async function fork() {
  const token = location.pathname.match(/^\/s\/(.+)$/)?.[1];
  if (!token) return;
  const res = await fetch(`/api/fork/${token}`, { method: "POST" });
  const data = await res.json();
  if (!res.ok) {
    notice("复制失败，请重试。", true);
    return;
  }
  snapshot = data.snapshot;
  canEdit = true;
  shareURL = null;
  history.replaceState({}, "", `/m/${snapshot.map_id}`);
  render();
  notice("已创建你的副本。现在可以拖动，原图不会改变。");
}
$("fork").onclick = fork;
function renderTrace() {
  $("trace-list").innerHTML =
    trace
      .map(
        (t, i) =>
          `<details><summary>${i + 1}. ${esc(t.name)}　${t.output.ok ? "成功" : "失败"}</summary><pre>${esc(JSON.stringify(t, null, 2))}</pre></details>`,
      )
      .join("") || "<p>点击「规划东京 3 天」后，这里显示实际工具调用。</p>";
}
$("trace-button").onclick = () => {
  renderTrace();
  $("trace-dialog").showModal();
};
function mapSize() {
  const r = $("map-viewport").getBoundingClientRect();
  const width = Math.max(1050, (780 * r.width) / r.height);
  return [width, (width * r.height) / r.width];
}
function project([lng, lat]) {
  const world = 256 * 2 ** 13;
  const merc = ([lon, la]) => [
    ((lon + 180) / 360) * world,
    ((1 - Math.asinh(Math.tan((la * Math.PI) / 180)) / Math.PI) / 2) * world,
  ];
  const [cx, cy] = merc([139.751, 35.6895]),
    [x, y] = merc([lng, lat]);
  const [w, h] = mapSize();
  return [x - cx + w / 2, y - cy + h / 2];
}
function tiles() {
  const world = 256 * 2 ** 13;
  const cx = ((139.751 + 180) / 360) * world,
    cy = ((1 - Math.asinh(Math.tan((35.6895 * Math.PI) / 180)) / Math.PI) / 2) * world;
  const [w, h] = mapSize();
  $("map-svg").setAttribute("viewBox", `0 0 ${w} ${h}`);
  const x0 = cx - w / 2,
    y0 = cy - h / 2;
  let html = "";
  for (let x = Math.floor(x0 / 256); x <= Math.floor((x0 + w) / 256); x++)
    for (let y = Math.floor(y0 / 256); y <= Math.floor((y0 + h) / 256); y++)
      html += `<image href="https://cyberjapandata.gsi.go.jp/xyz/pale/13/${x}/${y}.png" x="${x * 256 - x0}" y="${y * 256 - y0}" width="256" height="256" preserveAspectRatio="none"/>`;
  $("tiles").innerHTML = html;
}
function setZoom(value) {
  zoom = Math.min(1.8, Math.max(0.8, value));
  $("map-world").style.transform = `scale(${zoom})`;
}
$("zoom-in").onclick = () => setZoom(zoom + 0.15);
$("zoom-out").onclick = () => setZoom(zoom - 0.15);
$("fit").onclick = () => setZoom(1);
async function init() {
  tiles();
  const interaction = location.pathname === "/interaction";
  document.body.classList.toggle("interaction", interaction);
  $("interaction-note").hidden = !interaction;
  $(interaction ? "interaction-nav" : "experience-nav").classList.add("current");
  const match = location.pathname.match(/^\/(m|s)\/(.+)$/);
  if (match) {
    const [_, type, identifier] = match;
    try {
      const response = await fetch(
        type === "s" ? `/api/share/${identifier}` : `/api/maps/${identifier}`,
      );
      const data = await response.json();
      if (!response.ok) throw Error(data.error?.message ?? "地图暂不可用");
      snapshot = data.snapshot;
      canEdit = data.can_edit;
      shareURL = type === "s" ? location.href : null;
      render();
      tab("plan");
      notice(
        canEdit ? "已从磁盘读取地图。可以继续调整。" : "只读分享。复制一份即可按自己的想法调整。",
      );
    } catch (e) {
      notice(e.message, true);
    }
  }
  if (interaction) await run();
}
let resizeFrame;
window.addEventListener("resize", () => {
  cancelAnimationFrame(resizeFrame);
  resizeFrame = requestAnimationFrame(() => {
    tiles();
    render();
  });
});
await init();
