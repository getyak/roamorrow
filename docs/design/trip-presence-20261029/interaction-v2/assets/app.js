/* Fixture-only interaction design. No account, location, microphone, model or payment API. */
const options = [
  {
    id: "park",
    title: "在公园边读一小时",
    place: "Parkside Café · 演示条目",
    walk: 12,
    why: "有单人靠窗座位，适合安静待一会儿。",
    source: "近期场所记录 · 演示",
    verified: true,
  },
  {
    id: "lane",
    title: "去巷子里喝杯手冲",
    place: "Lane Coffee · 演示条目",
    walk: 16,
    why: "吧台座位多，适合一个人短暂停留。",
    source: "旅行者记录 · 演示",
    verified: true,
  },
  {
    id: "books",
    title: "在书店里坐一会儿",
    place: "Book & Brew · 演示条目",
    walk: 18,
    why: "可以边翻书边喝咖啡，但营业时间需要再核对。",
    source: "营业时间待核实 · 演示",
    verified: false,
  },
];
const icon = (name, cls = "") =>
  `<i class="icon ${cls}" style="mask-image:url(${window.ICONS[name] || window.ICONS["map-pin"]})" aria-hidden="true"></i>`;
const escapeText = (value) =>
  String(value).replace(
    /[&<>"']/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c],
  );
const sample = (phase) => ({
  phase,
  selected: "park",
  draft: "",
  scope: "nearby",
  tab: phase === "today" ? "today" : "nearby",
  sidebar: false,
  voice: false,
  modal: null,
  committed: phase === "today",
  plan: phase === "today" ? { id: "park", start: "13:10", end: "14:10" } : null,
  lastQuery: "",
  previousPlan: phase === "today" ? { plan: null, appliedVersion: 2 } : null,
  version: phase === "today" ? 2 : 1,
  areaChanged: false,
  mapX: 0,
  mapY: 0,
  returnPhase: "home",
  status: "",
  unknownAccepted: false,
  start: "13:10",
  end: "14:10",
  beforeCompose: null,
});
const parseTime = (t) =>
  /^([01]\d|2[0-3]):[0-5]\d$/.test(t) ? Number(t.slice(0, 2)) * 60 + Number(t.slice(3)) : NaN;
const pick = (s) => options.find((o) => o.id === s.selected) || options[0];
const departureFor = (p) => {
  const n = parseTime(p.start) - (options.find((o) => o.id === p.id)?.walk || 0);
  return String(Math.floor(n / 60)).padStart(2, "0") + ":" + String(n % 60).padStart(2, "0");
};
const bufferText = (s) => {
  const gap = 870 - parseTime(s.end) - pick(s).walk;
  return !Number.isFinite(gap)
    ? "请先设置完整的结束时间。"
    : gap < 0
      ? "预计比原安排晚到 " + -gap + " 分钟，请调整时间。"
      : "结束后预留 " + gap + " 分钟缓冲（演示估算）。";
};
function basemap(s) {
  return `<div class="map" data-layout-allow-overflow data-map-drag aria-label="交互示意地图，可拖动"><div class="tile-grid" style="left:${-194 + s.mapX}px;top:${-65 + s.mapY}px">${window.MAP_TILES.map((f) => `<img src="assets/maps/${f}" alt="" draggable="false">`).join("")}</div><div class="map-wash"></div>${options.map((o, i) => `<button class="map-pin ${(s.phase === "today" && s.plan ? s.plan.id : s.selected) === o.id && s.phase !== "home" ? "selected" : ""}" style="left:${[210, 95, 278][i]}px;top:${(s.phase === "home" ? [243, 326, 354] : s.phase === "preview" ? [133, 171, 137] : [148, 204, 168])[i]}px" data-select="${o.id}" aria-label="查看候选${i + 1} ${o.title}">${i + 1}</button>`).join("")}<span class="map-you" style="left:159px;top:360px"></span><div class="attribution">© OpenStreetMap contributors · 位置示意</div></div>`;
}
function toolbar(s) {
  return `<header class="topbar"><button class="circle" data-action="sidebar" aria-label="打开旅程资料">${icon("panel-left")}</button><button class="citytitle" data-action="trip"><b>东京，慢慢走 ${icon("chevron-down")}</b><span>10月30日 · 旅程第 3 天</span></button><button class="circle" data-action="locate" aria-label="当前位置与定位说明">${icon("navigation")}</button></header>`;
}
function composer(s) {
  return `<div class="composer-zone">${s.scope !== "nearby" ? `<button class="scope-chip" data-action="clear-scope">${icon("map-pin")} 关于：${s.scope === "area" ? "这片地图" : escapeText((options.find((o) => o.id === s.scope) || options[0]).place.split(" · ")[0])} ${icon("x")}</button>` : ""}<form class="composer" aria-label="旅行意图输入"><button type="button" class="add-button" data-action="attach" aria-label="添加图片或文件">${icon("plus")}</button><input aria-label="说说现在想做什么" placeholder="说说现在想做什么…" value="${escapeText(s.draft)}" autocomplete="off"><button type="button" class="mic-button" data-action="voice" aria-label="语音输入演示">${icon("mic")}</button><button type="submit" class="send-button" aria-label="发送旅行需求">${icon("arrow-up-right")}</button></form></div>`;
}
function tabs(s) {
  return `<div class="panel-header"><div class="content-tabs"><button class="${s.tab === "nearby" ? "active" : ""}" data-tab="nearby">附近</button><button class="${s.tab === "today" ? "active" : ""}" data-tab="today">今天${s.committed ? '<span class="tab-dot"></span>' : ""}</button></div><button class="circle small" data-action="${s.phase === "home" ? "expand" : "collapse"}" aria-label="${s.phase === "home" ? "展开面板" : "收起面板"}">${icon(s.phase === "home" ? "chevron-up" : "chevron-down")}</button></div>`;
}
function candidates(s) {
  const o = pick(s);
  return `<section class="panel-body"><div class="answer-head"><p class="eyebrow">${icon("sparkles")} ${s.scope === "nearby" ? "这附近" : s.scope === "area" ? "这片地图" : "围绕这个体验"}</p><h1>给你留了三个选择</h1><p class="subline">安静 · 步行 20 分钟内 · 演示结果</p></div><div class="candidate-list">${options.map((o, i) => `<button class="candidate ${s.selected === o.id ? "chosen" : ""}" data-select="${o.id}"><span class="candidate-number">${i + 1}</span><span><b>${o.title}</b><small>${o.walk} 分钟步行 · ${o.verified ? "适合一个人" : "营业时间待核实"}</small></span>${s.selected === o.id ? icon("check") : icon("chevron-right")}</button>`).join("")}</div><div class="reason"><p>${o.why}</p><button data-action="source">${icon("receipt")} ${o.source} ${icon("arrow-up-right")}</button></div><div class="candidate-actions"><button class="secondary" data-action="ask-place">问这家</button><button class="primary" data-action="preview">放进今天 ${icon("plus")}</button></div></section>`;
}
function preview(s) {
  const o = pick(s),
    old = s.plan ? options.find((o) => o.id === s.plan.id) : null,
    change = old ? (old.id === o.id ? "update" : "replace") : "add";
  return `<section class="panel-body preview-body"><p class="eyebrow">${change === "replace" ? "替换预览" : change === "update" ? "时间调整预览" : "调整预览"} · 原安排仍保留</p><h1>${change === "replace" ? "确认要替换这一站吗" : change === "update" ? "调一下这站的时间" : "给这一站留点时间"}</h1>${old ? `<div class="replace-note"><small>${change === "replace" ? "将被替换的已确认安排" : "当前已确认时间"}</small><b>${old.title} · ${s.plan.start}—${s.plan.end}</b></div>` : ""}<div class="preview-experience">${icon("bookmark")}<div><b>${o.title}</b><span>${o.place}</span></div></div><div class="time-edit"><label>开始<input type="time" aria-label="开始时间" data-time="start" value="${s.start}"></label><span>—</span><label>结束<input type="time" aria-label="结束时间" data-time="end" value="${s.end}"></label></div><div class="impact-box"><b>这次调整的影响</b><p>${change === "replace" ? "移除上方已确认体验，再保存下方新体验。" : change === "update" ? "只调整这一站的时间。" : "增加一站。"}不移动原有 14:30 的博物馆安排。<br><span data-buffer>${bufferText(s)}</span></p></div>${!o.verified ? `<label class="uncertainty"><input type="checkbox" data-unknown ${s.unknownAccepted ? "checked" : ""}>我知道营业时间尚未核实，先作为计划保存</label>` : ""}<p class="inline-status" role="status">${escapeText(s.status)}</p><div class="preview-buttons"><button class="secondary" data-action="cancel-preview">返回比较</button><button class="primary" data-action="commit">${change === "replace" ? "确认替换这一站" : change === "update" ? "确认更新时间" : "确认加入今天"}</button></div><p class="hint">只更新本页演示计划，不预订、不付款</p></section>`;
}
function today(s) {
  const o = s.plan ? options.find((o) => o.id === s.plan.id) : pick(s);
  const start = s.plan?.start || s.start,
    end = s.plan?.end || s.end;
  return `<section class="panel-body today-body"><p class="eyebrow">${icon("circle-check")} ${s.committed ? "今天已更新 · 版本 " + s.version : "你已安排的今天"}</p><h1>${s.committed ? "安排好了，慢慢走" : "给今天留一点空白"}</h1><div class="agenda">${s.committed ? `<div><time>${start}</time><span class="agenda-dot"></span><article><b>${o.title}</b><p>到 ${end} · 你刚刚确认</p><button data-action="detail">看这一站的详情 ${icon("chevron-right")}</button></article></div>` : ""}<div><time>14:30</time><span class="agenda-dot muted"></span><article><b>在博物馆慢慢看一圈</b><p>原有安排 · 演示条目</p></article></div></div>${s.committed ? `<div class="next-action"><span>下一步 · 建议 ${departureFor(s.plan)} 前出发</span><h2>去${o.place.split(" · ")[0]}</h2><p>${o.walk} 分钟步行 · 时间为演示估算</p><button class="primary" data-action="navigate">查看步行导航 ${icon("navigation")}</button></div>${s.previousPlan && s.previousPlan.appliedVersion === s.version ? '<button class="undo-link" data-action="undo">撤销这次调整</button>' : ""}` : `<button class="primary" data-action="nearby">看看附近可以做什么</button>`}</section>`;
}
function compact(s) {
  if (s.committed)
    return `<div class="compact-action"><span>下一步 · ${s.plan?.start || s.start}</span><button data-action="today"><b>${(options.find((o) => o.id === s.plan?.id) || pick(s)).title}</b>${icon("chevron-right")}</button></div>`;
  return `<div class="suggestion"><button data-action="example">找一家安静的咖啡馆 ${icon("arrow-up-right")}</button><span>或点一下地图上的体验</span></div>`;
}
function details(s) {
  const o = pick(s);
  return `<section class="panel-body"><p class="eyebrow">正在查看这个体验</p><h1>${o.title}</h1><p class="subline">${o.place} · ${o.walk} 分钟步行</p><p class="inline-status" role="status">${escapeText(s.status)}</p><div class="detail-narrative"><h3>适合这样度过一小时</h3><p>${o.why}</p><p>这些是设计用的模拟条目。真实产品应显示场所来源、核对时间与不方便之处。</p></div><button class="source-row" data-action="source">${icon("receipt")} 查看来源与待核实信息 ${icon("chevron-right")}</button><div class="candidate-actions"><button class="secondary" data-action="ask-place">问这家</button><button class="primary" data-action="preview">放进今天 ${icon("plus")}</button></div></section>`;
}
function drawer(s) {
  return `<div class="drawer-overlay"><button class="drawer-scrim" data-action="close-sidebar" aria-label="关闭旅程资料"></button><aside class="drawer" role="dialog" aria-modal="true" aria-label="旅程资料"><div class="drawer-heading"><b>旅程资料</b><button class="circle small" data-action="close-sidebar" aria-label="关闭资料侧栏">${icon("x")}</button></div><div class="drawer-trip">${icon("map-pin")}<b>东京，慢慢走<small>10月28日 — 11月1日</small></b></div><p class="drawer-caption">这趟旅程</p>${[
    ["calendar-days", "已确认的行程", "today"],
    ["receipt", "票据与来源", "records"],
    ["wallet", "预算与花销", "budget"],
  ]
    .map(
      ([i, t, a]) =>
        `<button class="drawer-row" data-action="${a}">${icon(i)}${t}${icon("chevron-right")}</button>`,
    )
    .join(
      "",
    )}<div class="divider"></div><button class="drawer-row" data-action="memory">${icon("bookmark")}我的旅行偏好${icon("chevron-right")}</button><button class="drawer-row" data-action="settings">${icon("settings-2")}权限与设置${icon("chevron-right")}</button><div class="drawer-note">常用操作留在底部。<br>这里保存资料与长期设置。</div></aside></div>`;
}
function voice(s) {
  return `<div class="modal-shade"><section class="voice-sheet" role="dialog" aria-modal="true" aria-label="语音输入演示"><div class="voice-heading"><b>说完，可以改了再发</b><button class="circle small" data-action="cancel-voice" aria-label="取消语音演示">${icon("x")}</button></div><p class="eyebrow">语音转写示意 · 没有使用麦克风</p><textarea aria-label="修改演示转写">找一家安静的咖啡馆，走路别超过二十分钟。</textarea><p class="hint">收起面板或离开 App，原生录音必须停止。</p><div class="candidate-actions"><button class="secondary" data-action="cancel-voice">取消</button><button class="primary" data-action="send-voice">用这句话找一找</button></div></section></div>`;
}
function modal(s) {
  return `<div class="modal-shade"><section class="info-sheet" role="dialog" aria-modal="true" aria-label="${escapeText(s.modal.title)}"><h2>${escapeText(s.modal.title)}</h2><p>${escapeText(s.modal.text)}</p><button class="primary" data-action="dismiss">知道了</button></section></div>`;
}
function screen(s) {
  let phase = s.phase;
  const body =
    phase === "results"
      ? candidates(s)
      : phase === "preview"
        ? preview(s)
        : phase === "today"
          ? today(s)
          : phase === "detail"
            ? details(s)
            : phase === "compose"
              ? `<section class="panel-body compose-body"><p class="eyebrow">继续这趟旅程</p><h1>把你在意的，<br>一起告诉我</h1><p>地点、时间、步行上限，都可以直接说。<br>输入中的草稿会留在这里。</p><button class="source-row" data-action="example">试试：找一家安静的咖啡馆 ${icon("arrow-up-right")}</button></section>`
              : compact(s);
  return `<div class="workspace ${phase === "home" ? "compact" : "opened"} phase-${phase}">${basemap(s)}<div class="statusbar"><b>12:40</b><span>••• ${icon("battery-medium")}</span></div>${toolbar(s)}${s.areaChanged ? `<button class="search-area" data-action="search-area">搜索这片区域</button>` : ""}<section class="task-panel" aria-label="当前旅行任务">${tabs(s)}<div class="task-scroll">${body}</div>${composer(s)}</section></div>${s.sidebar ? drawer(s) : ""}${s.voice ? voice(s) : ""}${s.modal ? modal(s) : ""}<div class="home-line"></div>`;
}
function attachPrototype(host) {
  const phaseParam = new URLSearchParams(location.search).get("phase");
  let state = sample(
    ["home", "results", "preview", "today", "detail", "compose"].includes(phaseParam)
      ? phaseParam
      : "home",
  );
  let drag = null;
  const render = () => {
    host.innerHTML = screen(state);
    host.dataset.phase = state.phase;
    host.querySelector(".workspace").inert = !!(state.sidebar || state.voice || state.modal);
    const dialog = host.querySelector("[role=dialog]");
    dialog?.querySelector("button,textarea")?.focus();
  };
  const result = () => {
    state.lastQuery = state.draft;
    state.draft = "";
    const scoped = options.some((o) => o.id === state.scope);
    if (scoped) state.selected = state.scope;
    state.phase = scoped ? "detail" : "results";
    state.tab = "nearby";
    state.status = state.phase === "detail" ? "已收到演示追问；这里会继续围绕该体验核对来源。" : "";
    state.beforeCompose = null;
  };
  host.addEventListener("input", (e) => {
    if (e.target.matches(".composer input")) state.draft = e.target.value;
    if (e.target.matches("[data-time]")) {
      state[e.target.dataset.time] = e.target.value;
      state.status = "";
      const buffer = host.querySelector("[data-buffer]");
      if (buffer) buffer.textContent = bufferText(state);
      host.querySelector(".inline-status").textContent = "";
    }
    if (e.target.matches("[data-unknown]")) state.unknownAccepted = e.target.checked;
  });
  host.addEventListener("submit", (e) => {
    e.preventDefault();
    if (!state.draft.trim()) {
      state.status = "先写一句想法，或试试下面的示例。";
      state.beforeCompose = state.phase;
      state.phase = "compose";
    } else result();
    render();
  });
  host.addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    const id = b.dataset.select,
      tab = b.dataset.tab,
      a = b.dataset.action;
    if (id) {
      state.selected = id;
      if (state.phase === "home" || state.phase === "today") state.phase = "detail";
      state.unknownAccepted = false;
      render();
      return;
    }
    if (tab) {
      state.tab = tab;
      state.phase = tab === "today" ? "today" : "home";
      render();
      return;
    }
    if (!a) return;
    if (a === "sidebar") state.sidebar = true;
    if (a === "close-sidebar") state.sidebar = false;
    if (a === "collapse") {
      state.phase = "home";
      state.voice = false;
      state.beforeCompose = null;
    }
    if (a === "expand") {
      state.phase = state.tab === "today" ? "today" : "results";
    }
    if (a === "example") {
      state.draft = "找一家安静的咖啡馆，步行不超过20分钟";
      state.scope = "nearby";
      result();
    }
    if (a === "preview") {
      state.returnPhase = state.phase;
      state.phase = "preview";
      state.status = "";
      state.unknownAccepted = false;
    }
    if (a === "cancel-preview") {
      state.phase = state.returnPhase;
      state.status = "";
    }
    if (a === "commit") {
      const min = parseTime;
      if (
        !Number.isFinite(min(state.start)) ||
        !Number.isFinite(min(state.end)) ||
        min(state.start) < 760 ||
        min(state.end) <= min(state.start)
      ) {
        state.status = "请把开始时间设在12:40之后，并让结束晚于开始。";
      } else if (min(state.end) + pick(state).walk > 870) {
        state.status = "这会赶不上原有14:30的安排。请提前结束，或返回选更近的体验。";
      } else if (!pick(state).verified && !state.unknownAccepted) {
        state.status = "营业时间尚未核实，请先确认上方提示。";
      } else {
        state.previousPlan = {
          plan: state.plan ? { ...state.plan } : null,
          appliedVersion: state.version + 1,
        };
        state.committed = true;
        state.plan = { id: state.selected, start: state.start, end: state.end };
        state.version++;
        state.phase = "today";
        state.tab = "today";
        state.status = "";
      }
    }
    if (a === "undo") {
      if (state.previousPlan && state.previousPlan.appliedVersion === state.version) {
        state.plan = state.previousPlan.plan;
        state.committed = !!state.plan;
        state.version++;
        state.previousPlan = null;
      } else if (!state.previousPlan) {
        state.modal = {
          title: "没有待撤销的调整",
          text: "当前已确认安排会保留。可以在预览中发起新的明确调整。",
        };
      } else {
        state.modal = {
          title: "计划已经变化",
          text: "请先查看最新的今天，再决定如何调整；不会覆盖更新的内容。",
        };
      }
      state.phase = "today";
    }
    if (a === "today") {
      state.phase = "today";
      state.tab = "today";
      state.sidebar = false;
    }
    if (a === "nearby") {
      state.phase = "home";
      state.tab = "nearby";
      state.sidebar = false;
    }
    if (a === "detail") {
      if (state.plan) state.selected = state.plan.id;
      state.phase = "detail";
      state.tab = "nearby";
    }
    if (a === "ask-place") {
      state.scope = state.selected;
      state.beforeCompose = state.phase;
      state.phase = "compose";
    }
    if (a === "clear-scope") state.scope = "nearby";
    if (a === "voice") state.voice = true;
    if (a === "cancel-voice") state.voice = false;
    if (a === "send-voice") {
      state.draft = host.querySelector("textarea").value;
      state.voice = false;
      result();
    }
    if (a === "search-area") {
      state.scope = "area";
      state.areaChanged = false;
      result();
    }
    const infos = {
      source: [
        "来源与不确定性",
        pick(state).source +
          "。本条目为交互演示，不代表实际商家、营业信息或实时距离。真实产品应回到原始记录。",
      ],
      navigate: [
        "步行导航入口",
        "原生版在你点击后打开系统地图；本演示没有定位、路线查询或外部导航调用。",
      ],
      trip: [
        "当前旅程",
        "东京，慢慢走 · 10月28日至11月1日。原生版切换旅程时保留各趟草稿，避免把上一趟的问题带过来。",
      ],
      locate: [
        "定位按需开启",
        "当前地图是本地示意，不读取位置。原生版只在你定位或开启明确场景后请求权限，拒绝后仍可手动选区域。",
      ],
      attach: [
        "添加资料",
        "原生版复用当前的图片、相机和文件入口。导入先预览提取结果，来源文件中的文字不能授权执行。",
      ],
      records: [
        "票据与来源",
        "资料入口设计示意。首版可复用已有附件与文件能力，预订提取和冲突核对需要真相层支持。",
      ],
      budget: [
        "预算与花销",
        "这里管理预算与回执。搜索、计划、实际支付分别计量；本原型不会下单或付款。",
      ],
      memory: [
        "我的旅行偏好",
        "跨趟偏好与本趟记录分开。推测先请你确认；删除偏好不会默认删除源票据。",
      ],
      settings: [
        "权限与设置",
        "只有真正需要某项能力时才申请权限。定位、麦克风、日历都可以关闭，并给出手动替代。",
      ],
    };
    if (infos[a]) {
      state.sidebar = false;
      state.modal = { title: infos[a][0], text: infos[a][1] };
    }
    if (a === "dismiss") state.modal = null;
    render();
    if (a === "ask-place") {
      const field = host.querySelector(".composer input");
      field.focus();
      field.setSelectionRange(field.value.length, field.value.length);
    }
  });
  host.addEventListener("focusin", (e) => {
    if (!e.target.matches(".composer input") || state.phase === "compose") return;
    state.beforeCompose = state.phase;
    state.phase = "compose";
    render();
    const field = host.querySelector(".composer input");
    field.focus();
    field.setSelectionRange(field.value.length, field.value.length);
  });
  host.addEventListener("pointerdown", (e) => {
    if (!e.target.closest("[data-map-drag]") || e.target.closest("button")) return;
    drag = { x: e.clientX, y: e.clientY, bx: state.mapX, by: state.mapY };
  });
  host.addEventListener("pointerup", (e) => {
    if (!drag) return;
    const dx = e.clientX - drag.x,
      dy = e.clientY - drag.y;
    if (Math.abs(dx) + Math.abs(dy) > 22) {
      state.mapX = Math.max(-100, Math.min(100, drag.bx + dx));
      state.mapY = Math.max(-100, Math.min(100, drag.by + dy));
      state.areaChanged = true;
      render();
    }
    drag = null;
  });
  host.addEventListener("keydown", (e) => {
    const dialog = host.querySelector("[role=dialog]");
    if (e.key === "Escape") {
      e.preventDefault();
      if (state.modal) state.modal = null;
      else if (state.voice) state.voice = false;
      else if (state.sidebar) state.sidebar = false;
      else if (state.phase === "preview") state.phase = state.returnPhase;
      else if (state.phase === "compose" && state.beforeCompose) {
        state.phase = state.beforeCompose;
        state.beforeCompose = null;
      } else state.phase = "home";
      render();
      host.querySelector(".task-panel button")?.focus();
    }
    if (e.key === "Tab" && dialog) {
      const all = [...dialog.querySelectorAll("button,textarea,input")];
      if (e.shiftKey && document.activeElement === all[0]) {
        e.preventDefault();
        all.at(-1).focus();
      } else if (!e.shiftKey && document.activeElement === all.at(-1)) {
        e.preventDefault();
        all[0].focus();
      }
    }
  });
  render();
  return {
    reset(phase) {
      state = sample(phase);
      render();
    },
  };
}
window.fixtureScreen = screen;
window.fixtureState = sample;
const live = document.querySelector("#interactive-phone");
if (live) {
  window.demo = attachPrototype(live);
  document
    .querySelectorAll("[data-demo-phase]")
    .forEach((b) => b.addEventListener("click", () => window.demo.reset(b.dataset.demoPhase)));
}
document.querySelectorAll("[data-fixture]").forEach((host) => {
  host.innerHTML = screen(sample(host.dataset.fixture));
  host.setAttribute("inert", "");
});
