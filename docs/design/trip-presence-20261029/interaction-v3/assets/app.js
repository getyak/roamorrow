/* Fixture-only interaction design. No network, microphone, location or payment. */
const places = [
  {
    id: "park",
    title: "在公园边，读一小时",
    name: "Parkside Café",
    walk: 12,
    why: "有单人窗边位，适合带一本书。",
    limit: "座位较少，营业时间待核实。",
  },
  {
    id: "lane",
    title: "巷子里的手冲咖啡",
    name: "Lane Coffee",
    walk: 16,
    why: "吧台适合一个人坐，节奏更慢。",
    limit: "步行略远，营业时间待核实。",
  },
];
const tabs = [
  ["chat", "message-circle", "对话"],
  ["trip", "calendar-days", "行程"],
  ["saved", "bookmark", "收藏"],
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
    tab: scene === "trip" ? "trip" : "chat",
    draft: scene === "typing" ? "最好能坐久一点。" : "",
    keyboard: scene === "typing",
    selected: "park",
    scope: null,
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
    overlay: scene === "map" ? "map" : null,
    modal: null,
    scroll: { chat: scene === "typing" ? 1000000 : 0 },
    mapOwner: scene === "map" ? { roomId: 1, turn: 0 } : null,
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
  return `<div class="map-canvas ${large ? "large-map" : "mini-map"}"><div class="map-tiles">${[12898, 12899, 12900].map((y) => [29105, 29106, 29107].map((x) => `<img src="assets/maps/${x}-${y}.png" alt="" draggable="false">`).join("")).join("")}</div>${places.map((p, i) => `<${large ? "button" : "span"} class="pin pin-${i} ${s.selected === p.id ? "selected" : ""}" data-place="${p.id}" aria-label="在地图上查看${p.name}">${i + 1}</${large ? "button" : "span"}>`).join("")}<span class="map-attribution">© OpenStreetMap · 位置示意</span></div>`;
}
function answer(s) {
  const p = place(s.selected);
  return `<article class="assistant-message"><p class="reply-intro">那就先不赶路。<br>这两个地方，可以慢慢待一会儿。</p><div class="suggested-places">${places.map((p, i) => `<button class="place-row ${s.selected === p.id ? "selected" : ""}" data-place="${p.id}" aria-label="选择${p.name}"><span class="place-index">${i + 1}</span><span><b>${p.title}</b><small>${p.name} · 步行 ${p.walk} 分钟</small>${s.selected === p.id ? `<small class="row-reason">${p.why}</small>` : ""}</span>${icon(s.selected === p.id ? "check" : "chevron-right")}</button>`).join("")}</div><p class="place-reason">${p.why}</p><button class="map-preview" data-action="map" aria-label="展开推荐地图">${map(s)}<span>在地图上看 ${icon("arrow-up-right")}</span></button><button class="source-link" data-action="source">${icon("file-check-2")} 场所资料 · 营业时间待核实 ${icon("chevron-right")}</button><div class="reply-actions"><button class="save-button ${s.saved.includes(p.id) ? "is-saved" : ""}" data-action="save" aria-label="${s.saved.includes(p.id) ? "取消收藏" : "收藏"}${p.name}">${icon("bookmark")}</button><button class="add-plan" data-action="preview">${s.plan ? "调整今天" : "放进今天"} ${icon("plus")}</button></div></article>`;
}
function chat(s) {
  const turns = s.turns
    .map((t, i) => {
      const view = { ...s, selected: t.selected, scope: t.scope };
      return `<div class="conversation-turn" data-turn="${i}"><div class="user-message">${escapeHTML(t.user)}</div>${t.answer === "followup" ? `<article class="assistant-message followup"><p>你问的是 <b>${escapeHTML(place(t.scope || t.selected).name)}</b>。</p><p>这版原型没有实时场所资料，暂时无法核实这个问题。</p><button class="source-link" data-action="source">查看来源与待核实项 ${icon("chevron-right")}</button><button class="soft-button" data-action="back-results">回到两个选择</button></article>` : answer(view)}</div>`;
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
  return `<div class="composer-area">${s.scope ? `<button class="scope-chip" data-action="clear-scope">关于 ${escapeHTML(place(s.scope).name)} ${icon("x")}</button>` : ""}<div class="composer glass"><button class="composer-plus" data-action="attach" aria-label="添加图片或行程资料">${icon("plus")}</button><textarea rows="1" aria-label="给旅行伙伴发消息" placeholder="说说现在的想法…">${escapeHTML(s.draft)}</textarea><button class="composer-mic ${s.draft.trim() ? "hidden" : ""}" data-action="voice" aria-label="语音输入">${icon("mic")}</button><button class="composer-send ${s.draft.trim() ? "" : "hidden"}" data-action="send" aria-label="发送消息">${icon("arrow-up")}</button></div></div>`;
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
  } else if (s.overlay === "map") {
    const p = place(s.selected);
    return `<div class="map-full" role="dialog" aria-modal="true" aria-label="推荐地图">${map(s, true)}<div class="map-top"><button class="round glass" data-action="close" aria-label="返回${tabs.find((t) => t[0] === s.tab)[2]}">${icon("arrow-left")}</button><span class="map-title glass">两个选择 · 东京</span></div><section class="map-place-card"><small>你正在看 · 步行 ${p.walk} 分钟</small><h2>${p.title}</h2><p>${p.name} · ${p.limit}</p><div><button class="soft-button" data-action="ask-place">聊聊这家</button><button class="dark-button" data-action="preview">放进今天</button></div></section></div>`;
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
  return `${statusbar()}${header(s)}<main data-layout-allow-overflow="true" class="app-scroll ${s.tab === "chat" ? "chat-scroll" : ""}" aria-label="${tabs.find((t) => t[0] === s.tab)[2]}内容">${s.tab === "chat" ? chat(s) : s.tab === "trip" ? itinerary(s) : s.tab === "saved" ? saved(s) : me(s)}</main>${s.tab === "chat" ? composer(s) : ""}${navigation(s)}<div class="keyboard-dock" aria-label="键盘位置示意"><div class="keyboard-toolbar"><span>键盘示意 · 请在输入框编辑</span><button data-action="hide-keyboard">完成 ${icon("chevron-down")}</button></div><img src="assets/keyboard.png" alt="系统键盘位置示意"></div><div class="home-indicator"></div>${overlay(s)}${s.notice ? `<div class="toast" role="status">${escapeHTML(s.notice)}<button data-action="clear-notice" aria-label="关闭状态提示">${icon("x")}</button></div>` : ""}`;
}
const sessions = new WeakMap();
function rememberScroll(host, s) {
  const scroll = host.querySelector(".app-scroll");
  if (scroll) s.scroll[s.tab] = scroll.scrollTop;
}
function render(host, s) {
  host.innerHTML = screen(s);
  host.classList.toggle("typing", s.keyboard);
  host.classList.toggle("non-chat", s.tab !== "chat");
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
  }
}
function focusToken(b) {
  return {
    action: b.dataset.action,
    place: b.dataset.place,
    tab: b.dataset.tab,
    saved: b.dataset.saved,
    room: b.dataset.room,
    turn: b.closest("[data-turn]")?.dataset.turn,
  };
}
function findFocus(root, token) {
  if (!token) return null;
  return [...root.querySelectorAll("button")].find((b) => {
    const t = focusToken(b);
    return ["action", "place", "tab", "saved", "room", "turn"].every((k) => t[k] === token[k]);
  });
}

function info(s, title, text) {
  s.overlay = null;
  s.modal = { title, text };
}
function mount(host, scene = "chat", interactive = false) {
  const s = initial(scene);
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
  host.addEventListener("input", (event) => {
    const el = event.target;
    if (el.matches(".composer textarea")) {
      s.draft = el.value;
      host.querySelector(".composer-mic").classList.toggle("hidden", !!s.draft.trim());
      host.querySelector(".composer-send").classList.toggle("hidden", !s.draft.trim());
      el.style.height = "auto";
      el.style.height = Math.min(el.scrollHeight, 96) + "px";
    }
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
      s.selected = s.turns[s.activeTurn].scope || s.turns[s.activeTurn].selected;
    }
    if (b.dataset.tab) {
      s.tab = b.dataset.tab;
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
    } else if (b.dataset.place) {
      s.selected = b.dataset.place;
      if (s.overlay === "map") {
        if (s.mapOwner?.roomId === s.roomId && s.turns[s.mapOwner.turn]?.answer === "results")
          s.turns[s.mapOwner.turn].selected = s.selected;
      } else if (s.turns[s.activeTurn]?.answer === "results")
        s.turns[s.activeTurn].selected = s.selected;
    } else if (b.dataset.saved) {
      s.selected = b.dataset.saved;
      s.mapOwner = null;
      s.overlay = "map";
      s.notice = "";
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
      s.mapOwner = { roomId: s.roomId, turn: s.activeTurn };
      s.overlay = "map";
      s.keyboard = false;
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
        .map((t) => t.answer)
        .lastIndexOf("results");
      if (index >= 0) s.jumpTurn = index;
      else
        info(s, "这段对话还没有候选", "可以清除提问范围，再说说想找什么。当前追问与回答会保留。");
    } else if (action === "ask-place") {
      s.scope = s.selected;
      s.tab = "chat";
      s.overlay = null;
      s.keyboard = false;
      s.notice = `提问范围：${place(s.scope).name}`;
    } else if (action === "discuss-plan") {
      s.scope = s.plan.id;
      s.selected = s.plan.id;
      s.tab = "chat";
      s.notice = `提问范围：${place(s.scope).name}`;
    } else if (action === "clear-scope") {
      s.scope = null;
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
        s.selected = s.plan.id;
        s.mapOwner = null;
        s.overlay = "map";
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
  s.answer = s.scope ? "followup" : "results";
  if (s.scope) s.selected = s.scope;
  s.turns.push({ user: s.lastMessage, answer: s.answer, selected: s.selected, scope: s.scope });
  s.activeTurn = s.turns.length - 1;
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
      s.mapOwner = s.tab === "chat" ? { roomId: s.roomId, turn: s.activeTurn } : null;
      s.overlay = "map";
      s.modal = null;
      s.keyboard = false;
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
