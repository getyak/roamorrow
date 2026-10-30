/* Fixture-only interaction design. No network, microphone, location or payment. */
const places = [
  {
    id: "park",
    city: "tokyo",
    category: "cafe",
    title: "在公园边，读一小时",
    name: "Parkside Café",
    walk: 12,
    why: "有单人窗边位，适合带一本书。",
    limit: "座位较少，营业时间待核实。",
  },
  {
    id: "lane",
    city: "tokyo",
    category: "cafe",
    title: "巷子里的手冲咖啡",
    name: "Lane Coffee",
    walk: 16,
    why: "吧台适合一个人坐，节奏更慢。",
    limit: "步行略远，营业时间待核实。",
  },
];
places.push({
  id: "book",
  city: "tokyo",
  category: "bookstore",
  title: "在书店里，坐一会儿",
  name: "Book & Brew",
  walk: 18,
  why: "书和咖啡都在手边，适合一个人。",
  limit: "座位有限，营业时间待核实。",
});
const flow = window.TravelMapFlow;
const scopeId = (scope) => flow.experienceId(scope);
const scopeLabel = (scope) => flow.label(scope, places);
const tabs = [
  ["chat", "message-circle", "对话"],
  ["map", "map", "地图"],
  ["trip", "calendar-days", "行程"],
  ["me", "user-round", "我的"],
];
const escapeHTML = (value = "") =>
  String(value).replace(
    /[&<>"']/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c],
  );
const icon = (name) =>
  `<img class="icon" src="${window.ICONS[name] || window.ICONS["circle-check"]}" alt="" draggable="false">`;
const place = (id) => places.find((p) => p.id === id) || places[0];
const timeValue = (value) => {
  const m = /^(\d{2}):(\d{2})$/.exec(value);
  return m && +m[1] < 24 && +m[2] < 60 ? +m[1] * 60 + +m[2] : NaN;
};
const timeString = (n) =>
  `${String(Math.floor(n / 60)).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;
function initial(scene = "chat") {
  return {
    tab:
      scene === "trip"
        ? "trip"
        : ["map", "saved-map", "location-denied"].includes(scene)
          ? "map"
          : "chat",
    mapState: flow.create(),
    draft: ["scoped", "typing-scoped"].includes(scene)
      ? "这里适合带电脑坐一会儿吗？"
      : scene === "typing"
        ? "最好能坐久一点。"
        : "",
    keyboard: ["typing", "typing-scoped"].includes(scene),
    selected: "park",
    scope: ["scoped", "typing-scoped"].includes(scene) ? flow.scopeForPlace("park") : null,
    answer: "results",
    lastMessage: "想找个安静的地方，坐一会儿。",
    turns: [
      { user: "想找个安静的地方，坐一会儿。", answer: "results", selected: "park", scope: null },
    ],
    activeTurn: 0,
    roomId: 1,
    nextRoom: 2,
    rooms: [],
    roomTitle: "东京，下午慢慢走",
    plan: scene === "trip" ? { id: "park", start: "13:10", end: "14:00" } : null,
    version: 1,
    undo: null,
    saved: [],
    overlay: null,
    modal: null,
    scroll: { chat: scene === "typing" ? 1000000 : 0 },

    start: "13:10",
    end: "14:00",
    accepted: false,
    error: "",
    notice: "",
    voiceText: "找一家安静的咖啡馆，走路不要太远。",
  };
}
function statusbar() {
  return `<div class="statusbar"><b>12:40</b><div>${icon("signal")}${icon("wifi")}${icon("battery")}</div></div>`;
}
function header(s) {
  return `<header class="app-header"><button class="round glass" data-action="history" aria-label="查看对话记录">${icon("menu")}</button><button class="companion-heading" data-action="companion" aria-label="Roamorrow 旅行伙伴"><img src="assets/companion.png" alt="Roamorrow 的旅行伙伴" draggable="false"><b>Roamorrow</b></button><button class="city-pill glass" data-action="trip-info">东京 ${icon("chevron-down")}</button></header>`;
}
function navigation(s) {
  return `<nav class="bottom-navigation glass" aria-label="主导航"><div role="tablist" aria-label="旅行内容">${tabs.map(([id, symbol, label]) => `<button role="tab" aria-label="${label}" aria-selected="${s.tab === id}" data-tab="${id}" class="nav-item ${s.tab === id ? "active" : ""}">${icon(symbol)}<span>${label}</span></button>`).join("")}</div></nav>`;
}
function map(s, large = false) {
  const state = s.mapState,
    visible = large ? flow.ids(state, places, s.saved) : s.candidateIds || ["park", "lane"],
    selected = large ? state.selectedId : s.selected,
    pan = large ? state.camera : { x: 0, y: 0 };
  return `<div class="map-canvas ${large ? "large-map" : "mini-map"}" ${large ? 'data-map-pan aria-label="地图视野，可拖动"' : ""}><div class="map-drawing" style="transform:translate(${pan.x}px,${pan.y}px)"><div class="map-tiles">${[12898, 12899, 12900].map((y) => [29105, 29106, 29107].map((x) => `<img src="assets/maps/${x}-${y}.png" alt="" draggable="false">`).join("")).join("")}</div>${places
    .filter((p) => visible.includes(p.id))
    .map((p) => {
      const i = places.indexOf(p);
      return `<${large ? "button" : "span"} class="pin pin-${i} ${selected === p.id ? "selected" : ""}" data-place="${p.id}" aria-label="在地图上查看${p.name}">${i + 1}</${large ? "button" : "span"}>`;
    })
    .join("")}</div><span class="map-attribution">© OpenStreetMap · 位置示意</span></div>`;
}
function mapWorkspace(s) {
  const m = s.mapState,
    visible = flow.ids(m, places, s.saved),
    p = visible.includes(m.selectedId) ? place(m.selectedId) : null;
  return `<section class="map-workspace app-scroll" aria-label="地图内容">${map(s, true)}<div class="map-header"><button class="map-city glass" data-action="trip-info">上野周边 ${icon("chevron-down")}</button><div><button class="round glass" data-action="map-search" aria-label="搜索地图中的体验">${icon("search")}</button><button class="round glass" data-action="map-location" aria-label="定位与地图范围说明">${icon("navigation")}</button></div></div><div class="map-modes glass" role="tablist" aria-label="地图内容"><button role="tab" aria-label="附近" aria-selected="${m.mode === "nearby"}" data-map-mode="nearby">附近</button><button role="tab" aria-label="地图收藏" aria-selected="${m.mode === "saved"}" data-map-mode="saved">收藏 ${s.saved.length ? `<small>${s.saved.length}</small>` : ""}</button></div><div class="map-filter-row">${
    m.mode === "nearby"
      ? [
          ["all", "全部"],
          ["cafe", "咖啡"],
          ["bookstore", "书店"],
        ]
          .map(
            ([id, label]) =>
              `<button data-map-category="${id}" aria-pressed="${m.category === id}" class="${m.category === id ? "chosen" : ""}">${label}</button>`,
          )
          .join("")
      : `<button data-favorite-scope="city" aria-pressed="${m.favoriteScope === "city"}">当前城市</button><button data-favorite-scope="all" aria-pressed="${m.favoriteScope === "all"}">全部收藏</button>`
  }</div>${m.source ? `<div class="map-source glass"><button data-action="expand-nearby">${m.mode === "saved" ? "收藏视图 · 原对话保留" : m.source.label ? escapeHTML(m.source.label) : m.contextIds ? `${m.contextIds.length}个推荐 · 看附近全部` : "附近全部体验"}</button><button data-action="return-to-chat">回到原对话 ${icon("arrow-left")}</button></div>` : `<div class="map-range-label">${m.location === "denied" ? "未授权定位 · 使用手动地图范围" : "手动地图范围 · 没有读取当前位置"}</div>`}${m.query ? `<button class="map-query-chip glass" data-action="clear-map-query">搜索：${escapeHTML(m.query)} ${icon("x")}</button>` : ""}${m.areaDirty ? `<button class="search-map-area glass" data-action="search-map-area">${icon("search")} 搜索这片区域</button>` : ""}<button class="ask-area glass" data-action="ask-area">${icon("message-circle")} 问问这片区域</button>${p ? `<section class="map-experience-card"><div class="map-card-meta"><span>${m.mode === "saved" ? "已收藏 · " : ""}${p.name} · 步行约 ${p.walk} 分钟</span><button data-action="map-source-info" aria-label="查看地图体验来源">${icon("file-check-2")}</button></div><h2>${p.title}</h2><p>${p.why}</p><small>${p.limit}</small><div class="map-card-actions"><button class="map-bookmark ${s.saved.includes(p.id) ? "is-saved" : ""}" data-action="save-map" aria-label="${s.saved.includes(p.id) ? "取消收藏" : "收藏"}${p.name}">${icon("bookmark")}</button><button class="dark-button" data-action="ask-place">聊聊这里</button><button class="soft-button" data-action="map-preview">放进今天</button></div><button class="open-apple-maps" data-action="external-navigation">用 Apple 地图打开 ${icon("arrow-up-right")}</button></section>` : `<section class="map-experience-card map-empty"><h2>${m.mode === "saved" && !s.saved.length ? "还没有收藏" : "这个范围没有匹配的体验"}</h2><p>${m.mode === "saved" ? "先在附近找找，喜欢的体验可以留到这里。" : "试试清除条件，或换一片地图。"}</p><button class="dark-button" data-action="reset-map-filters">${m.mode === "saved" ? "看看附近" : "清除条件"}</button></section>`}</section>`;
}
function restoreMapSource(s) {
  const source = s.mapState.source;
  if (source && source.roomId !== s.roomId) {
    storeRoom(s);
    const room = s.rooms.find((r) => r.roomId === source.roomId);
    if (!room) {
      info(s, "原对话暂不可用", "地图范围仍保留。请从对话记录重新选择，不会把问题放进另一段对话。");
      return false;
    }
    Object.assign(s, { ...room, turns: room.turns.map((t) => ({ ...t })) });
  }
  if (source) s.scroll.chat = source.anchor;
  s.tab = "chat";
  return true;
}
function enterMapFromAnswer(s) {
  storeRoom(s);
  const turn = s.turns[s.activeTurn],
    scope = turn?.scope,
    candidates = turn?.candidateIds || ["park", "lane"],
    source = { roomId: s.roomId, turn: s.activeTurn, anchor: s.scroll.chat || 0 };
  if (scope?.kind === "area") {
    s.mapState = {
      ...s.mapState,
      entered: true,
      mode: "nearby",
      category: scope.category || "all",
      query: scope.query || "",
      contextIds: [...candidates],
      selectedId: candidates.includes(s.selected) ? s.selected : candidates[0] || null,
      camera: { ...scope.viewport },
      searchedCamera: { ...scope.viewport },
      areaDirty: false,
      source: { ...source, label: scopeLabel(scope) },
    };
  } else s.mapState = flow.fromAnswer(s.mapState, source, candidates, s.selected);
  s.tab = "map";
  s.overlay = null;
  s.keyboard = false;
}

function answer(s) {
  const candidates = places.filter((p) => (s.candidateIds || ["park", "lane"]).includes(p.id));
  if (!candidates.length)
    return `<article class="assistant-message"><p class="reply-intro">这片范围里，暂时没有匹配的演示体验。</p><p>已保留你选定的筛选与搜索条件，可以回地图清除条件后再看看。</p><button class="soft-button" data-action="open-map">回到这片地图</button></article>`;
  const p = candidates.find((p) => p.id === s.selected) || candidates[0];
  return `<article class="assistant-message">${s.scope?.kind === "area" ? `<p class="answer-scope">${escapeHTML(scopeLabel(s.scope))}</p>` : ""}<p class="reply-intro">那就先不赶路。<br>${candidates.length === 1 ? "这个地方，可以慢慢待一会儿。" : "这两个地方，可以慢慢待一会儿。"}</p><div class="suggested-places">${candidates
    .map(
      (p, i) =>
        `<button class="place-row ${s.selected === p.id ? "selected" : ""}" data-place="${p.id}" aria-label="选择${p.name}"><span class="place-index">${i + 1}</span><span><b>${p.title}</b><small>${p.name} · 步行 ${p.walk} 分钟</small>${s.selected === p.id ? `<small class="row-reason">${p.why}</small>` : ""}</span>${icon(s.selected === p.id ? "check" : "chevron-right")}</button>`,
    )
    .join(
      "",
    )}</div><p class="place-reason">${p.why}</p><button class="map-preview" data-action="map" aria-label="展开推荐地图">${map(s)}<span>在地图上看 ${icon("arrow-up-right")}</span></button><button class="source-link" data-action="source">${icon("file-check-2")} 场所资料 · 营业时间待核实 ${icon("chevron-right")}</button><div class="reply-actions"><button class="save-button ${s.saved.includes(p.id) ? "is-saved" : ""}" data-action="save" aria-label="${s.saved.includes(p.id) ? "取消收藏" : "收藏"}${p.name}">${icon("bookmark")}</button><button class="add-plan" data-action="preview">${s.plan ? "调整今天" : "放进今天"} ${icon("plus")}</button></div></article>`;
}
function chat(s) {
  const turns = s.turns
    .map((t, i) => {
      const view = { ...s, selected: t.selected, scope: t.scope, candidateIds: t.candidateIds };
      return `<div class="conversation-turn" data-turn="${i}"><div class="user-message">${escapeHTML(t.user)}</div>${t.answer === "followup" ? `<article class="assistant-message followup"><p>你问的是 <b>${escapeHTML(place(scopeId(t.scope) || t.selected).name)}</b>。</p><p>这版原型没有实时场所资料，暂时无法核实这个问题。</p><button class="source-link" data-action="source">查看来源与待核实项 ${icon("chevron-right")}</button><button class="soft-button" data-action="back-results">回到刚才的选择</button></article>` : answer(view)}</div>`;
    })
    .join("");
  return `<div class="chat-feed"><p class="conversation-date">今天 · 东京 · 旅程第 3 天</p>${s.turns.length ? turns : `<div class="empty-chat"><img src="assets/companion.png" alt=""><h1>今天想怎么过？</h1><p>想找个地方坐坐，<br>还是一起理一理接下来的行程？</p><button data-action="example">找个安静的地方 ${icon("arrow-up-right")}</button><button data-action="open-trip">看看今天的安排 ${icon("arrow-up-right")}</button></div>`}</div>`;
}
function roomSnapshot(s) {
  return {
    roomId: s.roomId,
    roomTitle: s.roomTitle,
    turns: s.turns.map((t) => ({ ...t })),
    draft: s.draft,
    scope: s.scope,
    selected: s.selected,
    activeTurn: s.activeTurn,
    chatScroll: s.scroll.chat || 0,
  };
}
function storeRoom(s) {
  if (!s.turns.length && !s.draft.trim()) return;
  const item = roomSnapshot(s),
    index = s.rooms.findIndex((r) => r.roomId === s.roomId);
  if (index >= 0) s.rooms[index] = item;
  else s.rooms.push(item);
}

function itinerary(s) {
  const p = s.plan ? place(s.plan.id) : null;
  return `<section class="page-content trip-page"><p class="section-kicker">东京 · 10 月 30 日</p><h1>今天，慢慢来。</h1><p class="page-subtitle">已确认的安排，都在这里。</p><div class="day-picker"><span>周三<br><b>28</b></span><span>周四<br><b>29</b></span><span class="chosen">周五<br><b>30</b></span><span>周六<br><b>31</b></span><span>周日<br><b>1</b></span></div><div class="next-step"><span>下一步 ${icon("arrow-up-right")}</span><h2>${p ? `去 ${p.name}` : "下午，在博物馆走走"}</h2><p>${p ? `建议 ${timeString(timeValue(s.plan.start) - p.walk)} 前出发 · 步行约 ${p.walk} 分钟` : "14:30 开始 · 出发时间待路线核实"}</p><button class="dark-button" data-action="navigate">${p ? "在地图上看" : "核对出发信息"} ${icon("navigation")}</button></div><div class="timeline">${p ? `<div class="timeline-row"><time>${s.plan.start}</time><div><b>${p.title}</b><p>至 ${s.plan.end} · 你已确认</p><button data-action="discuss-plan">聊聊这一站 ${icon("chevron-right")}</button></div></div>` : ""}<div class="timeline-row"><time>14:30</time><div><b>在博物馆慢慢看一圈</b><p>至 16:00 · 原有演示安排</p><button data-action="booking">查看行程来源 ${icon("chevron-right")}</button></div></div></div>${s.undo && s.undo.version === s.version ? '<button class="undo-button" data-action="undo">撤销刚才的调整</button>' : ""}<button class="trip-documents" data-action="documents">${icon("receipt")} 票据、预算与行程资料 ${icon("chevron-right")}</button><p class="version-note">演示行程 · 版本 ${s.version} · 所有时间为示意</p></section>`;
}
function saved(s) {
  return `<section class="page-content"><p class="section-kicker">留给未来的自己</p><h1>想去的地方。</h1><p class="page-subtitle">收藏是留个念想，加入行程前再决定。</p>${
    s.saved.length
      ? s.saved
          .map((id) => {
            const p = place(id);
            return `<button class="saved-row" data-saved="${id}"><img src="assets/coffee.png" alt="咖啡示意"><span><b>${p.title}</b><small>东京 · ${p.name}</small></span>${icon("chevron-right")}</button>`;
          })
          .join("")
      : `<div class="saved-empty">${icon("bookmark")}<h2>还没有收藏</h2><p>对话里遇到喜欢的体验，<br>点一下收藏，之后随时回来。</p><button class="soft-button" data-action="open-chat">回对话看看</button></div>`
  }</section>`;
}
function me(s) {
  return `<section class="page-content profile-page"><img class="profile-companion" src="assets/companion.png" alt=""><h1>你的旅行方式。</h1><p class="page-subtitle">记住偏好，也把决定权留给你。</p><div class="profile-group"><button data-action="memory">${icon("book-open")}<span><b>旅行记忆</b><small>偏好、来源与确认记录</small></span>${icon("chevron-right")}</button><button data-action="documents">${icon("receipt")}<span><b>旅程档案</b><small>票据与花销记录</small></span>${icon("chevron-right")}</button></div><div class="profile-group"><button data-action="permissions">${icon("shield-check")}<span><b>权限与隐私</b><small>定位、日历与资料授权</small></span>${icon("chevron-right")}</button><button data-action="offline">${icon("wifi-off")}<span><b>离线资料</b><small>查看已保存内容</small></span>${icon("chevron-right")}</button></div></section>`;
}
function composer(s) {
  return `<div class="composer-area">${s.scope ? `<button class="scope-chip" data-action="clear-scope">${s.scope.kind === "area" ? "本次范围：" : "本次关于 "}${escapeHTML(scopeLabel(s.scope))} ${icon("x")}</button>` : ""}<div class="composer glass"><button class="composer-plus" data-action="attach" aria-label="添加图片或行程资料">${icon("plus")}</button><textarea rows="1" aria-label="给旅行伙伴发消息" placeholder="说说现在的想法…">${escapeHTML(s.draft)}</textarea><button class="composer-mic ${s.draft.trim() ? "hidden" : ""}" data-action="voice" aria-label="语音输入">${icon("mic")}</button><button class="composer-send ${s.draft.trim() ? "" : "hidden"}" data-action="send" aria-label="发送消息">${icon("arrow-up")}</button></div></div>`;
}
function preview(s) {
  const p = place(s.selected),
    old = s.plan ? place(s.plan.id) : null;
  const replace = old && old.id !== p.id;
  return `<div class="sheet-grabber"></div><p class="section-kicker">${replace ? "替换预览" : old ? "调整时间" : "加入行程"} · 尚未保存</p><h2>${replace ? "换成这一站？" : "给喜欢的地方，留点时间。"}</h2>${old ? `<p class="old-plan">原安排：${old.name}<br>${s.plan.start}—${s.plan.end} · 确认后${replace ? "替换" : "更新时间"}</p>` : ""}<div class="preview-place"><img src="assets/coffee.png" alt="咖啡示意"><div><b>${p.title}</b><p>${p.name} · 步行 ${p.walk} 分钟</p></div></div><div class="time-fields"><label>开始<input type="time" data-time="start" aria-label="开始时间" value="${s.start}"></label><span>—</span><label>结束<input type="time" data-time="end" aria-label="结束时间" value="${s.end}"></label></div><p class="preview-impact">保留 14:30 的博物馆安排。<br>步行与缓冲会按新时间重新核对。</p><label class="uncertainty"><input type="checkbox" data-accept ${s.accepted ? "checked" : ""}>营业时间尚未核实，先作为计划保存</label><p class="preview-error" role="status">${escapeHTML(s.error)}</p><button class="dark-button" data-action="confirm-plan">${replace ? "确认替换这一站" : old ? "确认调整时间" : "确认加入今天"}</button><p class="sheet-footnote">只更新演示行程，不预订、不付款。</p>`;
}
function overlay(s) {
  if (!s.overlay && !s.modal) return "";
  let body = "",
    label = "旅行资料";
  if (s.modal) {
    label = s.modal.title;
    body = `<h2>${escapeHTML(s.modal.title)}</h2><p class="modal-copy">${escapeHTML(s.modal.text)}</p><button class="dark-button" data-action="close">知道了</button>`;
  } else if (s.overlay === "map-search") {
    label = "搜索地图";
    body = `<h2>想找什么？</h2><p class="page-subtitle">本页只搜索演示体验，真实产品复用 MapKit 文本搜索。</p><input class="map-search-input" aria-label="搜索地点或体验" placeholder="咖啡、书店，或体验名称" value="${escapeHTML(s.mapState.query || "")}" data-map-query><button class="dark-button" data-action="apply-map-search">查看匹配体验</button>`;
  } else if (s.overlay === "preview") {
    label = "行程调整预览";
    body = preview(s);
  } else if (s.overlay === "history") {
    label = "对话记录";
    body = `<h2>我们的对话</h2><button class="history-row" data-action="close">${icon("message-circle")} ${escapeHTML(s.roomTitle)} <small>当前</small></button>${s.rooms
      .filter((r) => r.roomId !== s.roomId)
      .map(
        (r) =>
          `<button class="history-row" data-room="${r.roomId}">${icon("message-circle")} ${escapeHTML(r.roomTitle)}</button>`,
      )
      .join(
        "",
      )}<button class="history-row" data-action="new-chat">${icon("plus")} 开始新对话</button><p class="sheet-footnote">新对话不清空这趟旅程已确认的安排。</p>`;
  } else if (s.overlay === "voice") {
    label = "语音转写演示";
    body = `<h2>把想法说出来。</h2><p class="page-subtitle">转写示意 · 没有调用麦克风</p><textarea class="voice-transcript" aria-label="修改语音转写">${escapeHTML(s.voiceText)}</textarea><button class="dark-button" data-action="apply-voice">放入输入框，再看一眼</button><p class="sheet-footnote">取消会保留原先输入的文字。</p>`;
  } else if (s.overlay === "attach") {
    label = "添加资料";
    body = `<h2>把资料交给我。</h2><button class="history-row" data-action="import-file">${icon("file-text")} 导入确认信或 PDF ${icon("chevron-right")}</button><button class="history-row" data-action="import-photo">${icon("image")} 添加截图或照片 ${icon("chevron-right")}</button><p class="sheet-footnote">本原型仅演示入口，不读取任何文件。</p>`;
  }
  return `<div class="overlay-shade"><button class="overlay-scrim" data-action="close" aria-label="关闭弹层"></button><section class="bottom-sheet" role="dialog" aria-modal="true" aria-label="${label}"><button class="sheet-close round" data-action="close" aria-label="关闭${label}">${icon("x")}</button>${body}</section></div>`;
}
function screen(s) {
  return `${statusbar()}${s.tab === "map" ? "" : header(s)}${s.tab === "map" ? mapWorkspace(s) : `<main data-layout-allow-overflow="true" class="app-scroll ${s.tab === "chat" ? "chat-scroll" : ""}" aria-label="${tabs.find((t) => t[0] === s.tab)[2]}内容">${s.tab === "chat" ? chat(s) : s.tab === "trip" ? itinerary(s) : me(s)}</main>`}${s.tab === "chat" ? composer(s) : ""}${navigation(s)}<div class="keyboard-dock" aria-label="键盘位置示意"><div class="keyboard-toolbar"><span>键盘示意 · 请在输入框编辑</span><button data-action="hide-keyboard">完成 ${icon("chevron-down")}</button></div><img src="assets/keyboard.png" alt="系统键盘位置示意"></div><div class="home-indicator"></div>${overlay(s)}${s.notice ? `<div class="toast" role="status">${escapeHTML(s.notice)}<button data-action="clear-notice" aria-label="关闭状态提示">${icon("x")}</button></div>` : ""}`;
}

const sessions = new WeakMap();
function rememberScroll(host, s) {
  const scroll = host.querySelector(".app-scroll");
  if (scroll) s.scroll[s.tab] = scroll.scrollTop;
}
function render(host, s) {
  const focusComposer = !!s.focusComposer;
  host.innerHTML = screen(s);
  host.classList.toggle("typing", s.keyboard);
  host.classList.toggle("non-chat", s.tab !== "chat");
  host.classList.toggle("map-tab", s.tab === "map");
  const scroll = host.querySelector(".app-scroll");
  scroll.scrollTop = s.scroll[s.tab] || 0;
  if (s.jumpTurn !== undefined) {
    const target = host.querySelector(`[data-turn="${s.jumpTurn}"]`);
    if (target) scroll.scrollTop = target.offsetTop - 8;
    delete s.jumpTurn;
  }
  // The video auditor hit-tests offscreen scroll children against fixed chrome.
  // Exempt only ink that crosses this scroll viewport; visible content is audited.
  const viewport = scroll.getBoundingClientRect();
  for (const el of scroll.querySelectorAll("*")) {
    const r = el.getBoundingClientRect();
    if (r.top < viewport.top || r.bottom > viewport.bottom)
      el.setAttribute("data-layout-allow-occlusion", "true");
  }
  if (s.focusComposer) {
    delete s.focusComposer;
    host.querySelector(".composer textarea")?.focus({ preventScroll: true });
  }
  const behind = !!(s.overlay || s.modal);
  const priorDialog = host.dataset.dialogKey || "";
  host.dataset.dialogKey = s.modal?.title || s.overlay || "";
  for (const child of host.children) {
    if (!child.matches(".overlay-shade,.map-full,.toast")) {
      child.inert = behind;
    }
  }
  const dialog = host.querySelector('[role="dialog"]');
  if (dialog) {
    const target = findFocus(dialog, s.lastFocus) || dialog.querySelector("button,input,textarea");
    target?.focus({ preventScroll: true });
  } else if (priorDialog) {
    (
      findFocus(host, s.returnFocus) || host.querySelector('[role="tab"][aria-selected="true"]')
    )?.focus({ preventScroll: true });
  } else if (!focusComposer && s.lastFocus) {
    (findFocus(host, s.lastFocus) || host.querySelector(".nav-item[aria-selected=true]"))?.focus({
      preventScroll: true,
    });
  }
}
function focusToken(b) {
  return {
    action: b.dataset.action,
    place: b.dataset.place,
    tab: b.dataset.tab,
    saved: b.dataset.saved,
    room: b.dataset.room,
    mapMode: b.dataset.mapMode,
    mapCategory: b.dataset.mapCategory,
    favoriteScope: b.dataset.favoriteScope,
    turn: b.closest("[data-turn]")?.dataset.turn,
  };
}
function findFocus(root, token) {
  if (!token) return null;
  return [...root.querySelectorAll("button")].find((b) => {
    const t = focusToken(b);
    return [
      "action",
      "place",
      "tab",
      "saved",
      "room",
      "turn",
      "mapMode",
      "mapCategory",
      "favoriteScope",
    ].every((k) => t[k] === token[k]);
  });
}

function info(s, title, text) {
  s.overlay = null;
  s.modal = { title, text };
}
function mount(host, scene = "chat", interactive = false) {
  const s = initial(scene);
  if (["map", "saved-map", "location-denied"].includes(scene)) {
    s.mapState.entered = true;
    if (scene === "map") {
      storeRoom(s);
      s.mapState = flow.fromAnswer(
        s.mapState,
        { roomId: s.roomId, turn: 0, anchor: 0 },
        ["park", "lane"],
        "park",
      );
    }
    if (scene === "saved-map") {
      s.saved = ["park", "book"];
      s.mapState.mode = "saved";
    }
    if (scene === "location-denied") s.mapState.location = "denied";
  }
  flow.reconcile(s.mapState, places, s.saved);
  sessions.set(host, s);
  render(host, s);
  if (!interactive) return;
  host.addEventListener("pointerdown", (event) => {
    if (
      event.target.closest("button") &&
      host.querySelector(".composer textarea") === document.activeElement
    )
      event.preventDefault();
  });
  let mapDrag = null;
  host.addEventListener("pointerdown", (event) => {
    const canvas = event.target.closest("[data-map-pan]");
    if (!canvas || event.target.closest("button") || s.tab !== "map") return;
    mapDrag = { x: event.clientX, y: event.clientY, canvas, moved: false };
    canvas.setPointerCapture?.(event.pointerId);
  });
  host.addEventListener("pointermove", (event) => {
    if (!mapDrag) return;
    const dx = event.clientX - mapDrag.x,
      dy = event.clientY - mapDrag.y;
    if (Math.hypot(dx, dy) > 8) mapDrag.moved = true;
    if (mapDrag.moved) {
      const layer = mapDrag.canvas.querySelector(".map-drawing");
      layer.style.transform = `translate(${s.mapState.camera.x + dx}px,${s.mapState.camera.y + dy}px)`;
    }
  });
  const endPan = (event) => {
    if (!mapDrag) return;
    const drag = mapDrag;
    mapDrag = null;
    if (drag.moved) {
      s.mapState = flow.pan(s.mapState, event.clientX - drag.x, event.clientY - drag.y);
      render(host, s);
    }
  };
  host.addEventListener("pointerup", endPan);
  host.addEventListener("pointercancel", () => {
    mapDrag = null;
    render(host, s);
  });
  host.addEventListener("input", (event) => {
    const el = event.target;
    if (el.matches(".composer textarea")) {
      s.draft = el.value;
      host.querySelector(".composer-mic").classList.toggle("hidden", !!s.draft.trim());
      host.querySelector(".composer-send").classList.toggle("hidden", !s.draft.trim());
      el.style.height = "auto";
      el.style.height = Math.min(el.scrollHeight, 96) + "px";
    }
    if (el.matches("[data-map-query]")) s.mapState.queryDraft = el.value;
    if (el.matches("[data-time]")) s[el.dataset.time] = el.value;
    if (el.matches(".voice-transcript")) s.voiceText = el.value;
    if (el.matches("[data-accept]")) s.accepted = el.checked;
  });
  host.addEventListener("focusin", (event) => {
    if (event.target.matches(".composer textarea")) {
      const pane = host.querySelector(".app-scroll"),
        pinned = pane.scrollHeight - pane.clientHeight - pane.scrollTop < 24;
      s.keyboard = true;
      host.classList.add("typing");
      if (pinned) pane.scrollTop = pane.scrollHeight;
    }
  });
  host.addEventListener("focusout", (event) => {
    if (event.target.matches(".composer textarea")) {
      s.keyboard = false;
      host.classList.remove("typing");
    }
  });
  host.addEventListener("keydown", (event) => {
    if (event.isComposing || event.keyCode === 229) return;
    const dialog = host.querySelector('[role="dialog"]');
    if (event.key === "Tab" && dialog) {
      const controls = [...dialog.querySelectorAll("button,input,textarea")].filter(
        (el) => !el.disabled,
      );
      const index = controls.indexOf(document.activeElement),
        next = event.shiftKey
          ? index <= 0
            ? controls.length - 1
            : index - 1
          : (index + 1) % controls.length;
      event.preventDefault();
      controls[next]?.focus();
      return;
    }

    if (event.key === "Escape") {
      s.keyboard = false;
      event.target.blur();
      host.classList.remove("typing");
      if (s.overlay || s.modal) {
        s.overlay = null;
        s.modal = null;
        render(host, s);
      }
    }
    if (event.key === "Enter" && !event.shiftKey && event.target.matches(".composer textarea")) {
      event.preventDefault();
      send(host, s);
    }
  });
  host.addEventListener("click", (event) => {
    const b = event.target.closest("button");
    if (!b) return;
    rememberScroll(host, s);
    const action = b.dataset.action;
    s.lastFocus = focusToken(b);
    if (!host.querySelector('[role="dialog"]')) s.returnFocus = s.lastFocus;
    s.keyboard = false;
    const turnNode = b.closest("[data-turn]");
    if (turnNode) {
      s.activeTurn = +turnNode.dataset.turn;
      s.selected = scopeId(s.turns[s.activeTurn].scope) || s.turns[s.activeTurn].selected;
    }
    if (b.dataset.tab) {
      s.tab = b.dataset.tab;
      if (s.tab === "map") {
        s.mapState = flow.independent(s.mapState);
        flow.reconcile(s.mapState, places, s.saved);
      }
      s.keyboard = false;
      s.notice = "";
      s.overlay = null;
      s.modal = null;
    } else if (b.dataset.room) {
      storeRoom(s);
      const room = s.rooms.find((r) => r.roomId === +b.dataset.room);
      if (room) {
        Object.assign(s, { ...room, turns: room.turns.map((t) => ({ ...t })) });
        s.scroll.chat = room.chatScroll;
        s.tab = "chat";
        s.overlay = null;
      }
    } else if (b.dataset.mapMode) {
      s.mapState.mode = b.dataset.mapMode;
      s.mapState.category = "all";
      flow.reconcile(s.mapState, places, s.saved);
    } else if (b.dataset.mapCategory) {
      s.mapState.category = b.dataset.mapCategory;
      flow.reconcile(s.mapState, places, s.saved);
    } else if (b.dataset.favoriteScope) {
      s.mapState.favoriteScope = b.dataset.favoriteScope;
      flow.reconcile(s.mapState, places, s.saved);
    } else if (b.dataset.place) {
      if (s.tab === "map") {
        if (flow.ids(s.mapState, places, s.saved).includes(b.dataset.place))
          s.mapState.selectedId = b.dataset.place;
      } else {
        s.selected = b.dataset.place;
        if (s.turns[s.activeTurn]?.answer !== "followup")
          s.turns[s.activeTurn].selected = s.selected;
      }
    } else if (action === "send") {
      send(host, s);
      return;
    } else if (action === "hide-keyboard") {
      s.keyboard = false;
    } else if (action === "close") {
      s.overlay = null;
      s.modal = null;
      s.keyboard = false;
    } else if (action === "clear-notice") {
      s.notice = "";
    } else if (action === "map") {
      enterMapFromAnswer(s);
    } else if (action === "open-map") {
      enterMapFromAnswer(s);
    } else if (action === "return-to-chat") {
      restoreMapSource(s);
      s.notice = "";
    } else if (action === "ask-area") {
      const scope = flow.scopeForArea(s.mapState, flow.ids(s.mapState, places, s.saved));
      if (restoreMapSource(s)) {
        s.scope = scope;
        s.notice = "";
        s.focusComposer = true;
      }
    } else if (action === "save-map") {
      const id = s.mapState.selectedId;
      if (id) {
        s.saved = s.saved.includes(id) ? s.saved.filter((x) => x !== id) : [...s.saved, id];
        flow.reconcile(s.mapState, places, s.saved);
        s.notice = s.saved.includes(id) ? "已收藏，行程保持不变" : "已取消收藏";
      }
    } else if (action === "map-preview") {
      if (s.mapState.selectedId) {
        s.selected = s.mapState.selectedId;
        s.overlay = "preview";
        s.start = s.plan?.start || "13:10";
        s.end = s.plan?.end || "14:00";
        s.accepted = false;
        s.error = "";
      }
    } else if (action === "reset-map-filters") {
      s.mapState.mode = "nearby";
      s.mapState.category = "all";
      s.mapState.contextIds = null;
      s.mapState.query = "";
      flow.reconcile(s.mapState, places, s.saved);
    } else if (action === "expand-nearby") {
      s.mapState.mode = "nearby";
      s.mapState.contextIds = null;
      s.mapState.category = "all";
      s.mapState.query = "";
      flow.reconcile(s.mapState, places, s.saved);
    } else if (action === "clear-map-query") {
      s.mapState.query = "";
      flow.reconcile(s.mapState, places, s.saved);
    } else if (action === "map-search") {
      s.overlay = "map-search";
      s.mapState.queryDraft = s.mapState.query || "";
    } else if (action === "apply-map-search") {
      s.mapState.query = (s.mapState.queryDraft || "").trim();
      s.mapState.contextIds = null;
      s.overlay = null;
      flow.reconcile(s.mapState, places, s.saved);
      s.notice = "仅在演示体验中匹配，未联网搜索";
    } else if (action === "search-map-area") {
      s.mapState = flow.searchArea(s.mapState);
      flow.reconcile(s.mapState, places, s.saved);
      s.notice = "地图范围已更新 · 演示未联网查询";
    } else if (action === "map-location") {
      info(
        s,
        "以这片地图为范围",
        "没有读取你的当前位置。定位未授权时，仍可手动选择城市或地图区域；这里的步行时间是演示估算。",
      );
    } else if (action === "map-source-info") {
      s.selected = s.mapState.selectedId || s.selected;
      info(
        s,
        "地图体验的来源",
        `${place(s.selected).name} 是演示条目。真实产品使用已有来源、置信度与不便字段；营业时间未核实，步行时间不是实时导航。`,
      );
    } else if (action === "external-navigation") {
      info(
        s,
        "明确点击后，才打开导航",
        "正式产品复用已有 Apple Maps 打开能力，只打开当前体验的路线。本页不打开外部 App，不表示你已经出发，不叫车、不付款。",
      );
    } else if (action === "preview") {
      s.overlay = "preview";
      s.modal = null;
      s.start = s.plan?.start || "13:10";
      s.end = s.plan?.end || "14:00";
      s.accepted = false;
      s.error = "";
      s.keyboard = false;
    } else if (action === "save") {
      const id = s.selected;
      s.saved = s.saved.includes(id) ? s.saved.filter((x) => x !== id) : [...s.saved, id];
      s.notice = s.saved.includes(id) ? "已收藏，行程保持不变" : "已取消收藏";
    } else if (action === "confirm-plan") {
      const start = timeValue(s.start),
        end = timeValue(s.end),
        p = place(s.selected);
      if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
        s.error = "请填写有效的开始和结束时间。";
      } else if (start < 12 * 60 + 40 + p.walk) {
        s.error = `步行约 ${p.walk} 分钟，最早 ${timeString(12 * 60 + 40 + p.walk)} 才能到达，请调整开始时间。`;
      } else if (end + p.walk > 14 * 60 + 30) {
        s.error = "与 14:30 的安排冲突，请提前结束或换一个选择。";
      } else if (!s.accepted) {
        s.error = "请先确认你知道营业时间尚未核实。";
      } else {
        s.version++;
        s.undo = { plan: s.plan ? { ...s.plan } : null, version: s.version };
        s.plan = { id: s.selected, start: s.start, end: s.end };
        s.overlay = null;
        s.tab = "trip";
        s.scroll.trip = 0;
        s.notice = "已加入今天 · 尚未预订";
      }
    } else if (action === "undo") {
      if (s.undo?.version === s.version) {
        s.plan = s.undo.plan;
        s.undo = null;
        s.version++;
        s.notice = "已撤销刚才的调整";
      }
    } else if (action === "history") {
      s.overlay = "history";
      s.keyboard = false;
    } else if (action === "new-chat") {
      storeRoom(s);
      s.roomId = s.nextRoom++;
      s.roomTitle = "新对话";
      s.turns = [];
      s.activeTurn = 0;
      s.answer = "empty";
      s.lastMessage = "";
      s.scope = null;
      s.draft = "";
      s.overlay = null;
      s.tab = "chat";
      s.scroll.chat = 0;
    } else if (action === "example") {
      s.lastMessage = "找个安静的地方，坐一会儿。";
      s.turns.push({ user: s.lastMessage, answer: "results", selected: s.selected, scope: null });
      s.activeTurn = s.turns.length - 1;
      s.roomTitle = "东京，下午慢慢走";
      s.answer = "results";
      s.scope = null;
      s.scroll.chat = 0;
    } else if (action === "open-trip") {
      s.tab = "trip";
    } else if (action === "open-chat") {
      s.tab = "chat";
    } else if (action === "back-results") {
      s.answer = "results";
      const index = s.turns
        .slice(0, s.activeTurn + 1)
        .map((t) => t.answer === "results" || t.answer === "area-results")
        .lastIndexOf(true);
      if (index >= 0) s.jumpTurn = index;
      else
        info(s, "这段对话还没有候选", "可以清除提问范围，再说说想找什么。当前追问与回答会保留。");
    } else if (action === "ask-place") {
      const id = s.mapState.selectedId;
      if (id && restoreMapSource(s)) {
        s.scope = flow.scopeForPlace(id);
        s.selected = id;
        s.overlay = null;
        s.notice = "";
        s.focusComposer = true;
      }
    } else if (action === "discuss-plan") {
      s.scope = flow.scopeForPlace(s.plan.id);
      s.selected = s.plan.id;
      s.tab = "chat";
      s.notice = `提问范围：${scopeLabel(s.scope)}`;
    } else if (action === "clear-scope") {
      s.scope = null;
      s.focusComposer = true;
    } else if (action === "voice") {
      s.overlay = "voice";
      s.keyboard = false;
    } else if (action === "apply-voice") {
      s.draft = [s.draft, s.voiceText.trim()].filter(Boolean).join("\n");
      s.overlay = null;
      s.keyboard = false;
    } else if (action === "attach") {
      s.overlay = "attach";
      s.keyboard = false;
    } else if (action === "booking") {
      info(
        s,
        "博物馆行程来源",
        "14:30—16:00 是本页预先保存的博物馆演示安排，没有绑定真实订单或导航地址。请核实具体场馆与票据后再出发。",
      );
    } else if (action === "source") {
      info(
        s,
        "来源与待核实信息",
        `${place(s.selected).name}、距离及营业信息均为演示。真实产品需要显示原始来源、最后核对时间和变更记录；当前不能据此确认营业或预订。`,
      );
    } else if (action === "trip-info") {
      info(
        s,
        "东京，慢慢走",
        "10 月 28 日—11 月 1 日 · Asia/Tokyo。当前只有这一趟演示旅程。真实切换旅程时，对话草稿与提问范围按旅程隔离。",
      );
    } else if (action === "companion") {
      info(
        s,
        "Roamorrow",
        "和你一起理清旅行中的下一步。使用已有旅程资料；需要支付、改签或取消时，必须另行明确确认。",
      );
    } else if (action === "navigate") {
      if (!s.plan) {
        info(
          s,
          "出发信息待核实",
          "博物馆尚未绑定可导航地址，不能用咖啡馆的位置代替。正式产品需要核对目的地与路线后，再给出出发时间。",
        );
      } else {
        s.mapState = {
          ...s.mapState,
          entered: true,
          mode: "nearby",
          category: "all",
          source: null,
          contextIds: [s.plan.id],
          selectedId: s.plan.id,
        };
        s.tab = "map";
      }
      s.keyboard = false;
    } else if (action === "documents") {
      info(
        s,
        "这趟旅程的资料",
        "票据、订单、预算和花销归属于同一个 Trip。这里展示资料入口；没有接入任何真实订单，也不会发起支付。",
      );
    } else if (action === "memory") {
      info(
        s,
        "关于我的旅行记忆",
        "偏好需要你的确认，且可以查看来源、修改或删除。证件号与支付信息不进入明文对话记忆。本页没有读取真实个人资料。",
      );
    } else if (action === "permissions") {
      info(
        s,
        "由你决定如何授权",
        "位置、日历和文件只为当前旅行任务服务。缺少权限时，仍可手动提供城市或确认号。本原型未申请任何系统权限。",
      );
    } else if (action === "offline") {
      info(
        s,
        "离线时也能继续",
        "正式产品应保留已确认行程与关键资料，并显示更新时间。本页数据只在内存里，刷新会重置，不具备真实离线持久化。",
      );
    } else if (action === "import-file" || action === "import-photo") {
      info(
        s,
        "资料导入演示",
        "正式产品会先抽取预订事实、显示来源与冲突，再由你确认写入行程。此原型不打开文件选择器、不读取文件。",
      );
    }
    render(host, s);
  });
}
function send(host, s) {
  if (!s.draft.trim()) return;
  rememberScroll(host, s);
  s.lastMessage = s.draft.trim();
  s.draft = "";
  s.keyboard = false;
  s.answer = scopeId(s.scope) ? "followup" : s.scope?.kind === "area" ? "area-results" : "results";
  if (scopeId(s.scope)) s.selected = scopeId(s.scope);
  const candidateIds =
    s.scope?.kind === "area" ? [...(s.scope.experienceIds || [])] : ["park", "lane"];
  if (!scopeId(s.scope) && !candidateIds.includes(s.selected)) s.selected = candidateIds[0] || null;
  s.turns.push({
    user: s.lastMessage,
    answer: s.answer,
    selected: s.selected,
    scope: s.scope,
    candidateIds,
  });
  s.activeTurn = s.turns.length - 1;
  s.scope = null;
  if (s.roomTitle === "新对话") s.roomTitle = s.lastMessage.slice(0, 16);
  s.scroll.chat = 1000000;
  s.notice = "演示回复 · 没有调用模型";
  render(host, s);
}
document
  .querySelectorAll("[data-fixture]")
  .forEach((host) => mount(host, host.dataset.fixture, host.id === "interactive-phone"));
document.querySelectorAll("[data-scene]").forEach((button) =>
  button.addEventListener("click", () => {
    const host = document.querySelector("#interactive-phone"),
      s = sessions.get(host),
      scene = button.dataset.scene;
    rememberScroll(host, s);
    if (scene === "chat") {
      s.tab = "chat";
      s.keyboard = false;
      s.overlay = null;
      s.modal = null;
    } else if (scene === "typing") {
      s.tab = "chat";
      s.overlay = null;
      s.modal = null;
      s.keyboard = true;
      if (!s.draft) s.draft = "最好能坐久一点。";
    } else if (scene === "trip") {
      s.tab = "trip";
      s.keyboard = false;
      s.overlay = null;
      s.modal = null;
    } else if (scene === "map") {
      if (s.tab === "chat") enterMapFromAnswer(s);
      else {
        s.tab = "map";
        s.mapState = flow.independent(s.mapState);
      }
    } else if (scene === "saved-map") {
      s.tab = "map";
      s.mapState = flow.independent(s.mapState);
      s.mapState.mode = "saved";
      flow.reconcile(s.mapState, places, s.saved);
    } else if (scene === "location-denied") {
      s.tab = "map";
      s.mapState.location = "denied";
      s.mapState.contextIds = null;
      s.mapState.source = null;
      flow.reconcile(s.mapState, places, s.saved);
    }
    render(host, s);
    document
      .querySelectorAll("[data-scene]")
      .forEach((b) => b.classList.toggle("selected", b === button));
  }),
);

const stage = document.querySelector(".phone-stage");
if (stage) {
  const fit = () => {
    stage.style.zoom = Math.min(1, (window.innerHeight - 48) / 852, (window.innerWidth - 24) / 393);
  };
  fit();
  window.addEventListener("resize", fit);
}
