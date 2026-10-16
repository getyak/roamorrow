#!/usr/bin/env python3
"""可复核的源码交互清单；不把源码候选数当作实际产品按钮数。

默认固定在本次审查的起始提交，避免其他 agent 的并行修改使行号漂移。
重跑: python3 docs/design/interaction-quality/generate_inventory.py
交付前另存: python3 docs/design/interaction-quality/generate_inventory.py --working-tree --output-dir docs/design/interaction-quality/current
仅使用 Python 标准库，不运行构建、浏览器或 Simulator。
"""
from __future__ import annotations

import argparse
import ast
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BASELINE = "924f09a4"


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True)


def mask_comments(source: str, mask_strings: bool = False) -> str:
    # Preserve character positions and newlines; handles nested Swift block comments.
    result = list(source)
    i = 0
    n = len(source)
    while i < n:
        if source.startswith("//", i):
            end = source.find("\n", i)
            if end < 0:
                end = n
            for k in range(i, end):
                result[k] = " "
            i = end
        elif source.startswith("/*", i):
            start, depth = i, 1
            i += 2
            while i < n and depth:
                if source.startswith("/*", i):
                    depth += 1
                    i += 2
                elif source.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            for k in range(start, i):
                if result[k] != "\n":
                    result[k] = " "
        elif source[i] in ('"', "'", "`"):
            quote = source[i]
            triple = quote == '"' and source.startswith('"""', i)
            start = i
            i += 3 if triple else 1
            while i < n:
                if source[i] == "\\":
                    i += 2
                elif triple and source.startswith('"""', i):
                    i += 3
                    break
                elif not triple and source[i] == quote:
                    i += 1
                    break
                else:
                    i += 1
            if mask_strings:
                for k in range(start, min(i, n)):
                    if result[k] != "\n":
                        result[k] = " "
        else:
            i += 1
    return "".join(result)


def matching(mask: str, start: int) -> int:
    opening = mask[start]
    closing = {"(": ")", "{": "}", "[": "]"}.get(opening)
    if closing is None:
        return start
    depth = 1
    for i in range(start + 1, len(mask)):
        if mask[i] == opening:
            depth += 1
        elif mask[i] == closing:
            depth -= 1
            if depth == 0:
                return i + 1
    return len(mask)


def line_number(source: str, pos: int) -> int:
    return source.count("\n", 0, pos) + 1


def compact(value: str, limit: int = 220) -> str:
    return re.sub(r"\s+", " ", value).strip()[:limit]


def swift_span(source: str, mask: str, start: int, end_token: int) -> tuple[int, int]:
    cursor = end_token
    while cursor < len(mask) and mask[cursor].isspace():
        cursor += 1
    if cursor < len(mask) and mask[cursor] == "(":
        cursor = matching(mask, cursor)
    while cursor < len(mask) and mask[cursor].isspace():
        cursor += 1
    action_start = cursor
    if cursor < len(mask) and mask[cursor] == "{":
        cursor = matching(mask, cursor)
    # Button { action } label: { view }, or Menu/NavigationLink destinations.
    label = re.match(r"\s*(?:label|actions|message|content|preview)\s*:\s*\{", mask[cursor:])
    if label:
        label_start = cursor + label.end() - 1
        cursor = matching(mask, label_start)
    # Include immediately attached modifiers, but not the surrounding sibling.
    for _ in range(40):
        modifier = re.match(r"\s*\.\w+\s*(?:\(|\{)", mask[cursor:])
        if not modifier:
            break
        bracket = cursor + modifier.end() - 1
        cursor = matching(mask, bracket)
        while cursor < len(mask) and mask[cursor].isspace():
            cursor += 1
        if cursor < len(mask) and mask[cursor] == "{":
            cursor = matching(mask, cursor)
    return min(cursor, len(source)), action_start


def read_optional(read, path: str, diagnostics: list[dict], parser: str):
    try:
        return read(path)
    except (OSError, subprocess.CalledProcessError) as error:
        diagnostics.append({"parser": parser, "path": path, "status": "unavailable", "detail": f"源文件不可读取（{type(error).__name__}）；未套用基线内容。"})
        return None


def localizations(read, diagnostics=None) -> dict[str, dict[str, str]]:
    diagnostics = diagnostics if diagnostics is not None else []
    localized = {}
    for locale in ("en", "zh-Hans"):
        path = f"apps/ios/SoloCompass/Resources/{locale}.lproj/Localizable.strings"
        source = read_optional(read, path, diagnostics, "localizations")
        pairs = re.findall(r'"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;', source or "")
        localized[locale] = dict(pairs)
    return localized


SWIFT_CONTROL = re.compile(r"\b(Button|NavigationLink|Toggle|Picker|DatePicker|Slider|Stepper|TextField|TextEditor|SecureField|Menu|ShareLink|Link|PhotosPicker|ColorPicker|Map|MapCompass|MapPitchToggle|MapUserLocationButton|DisclosureGroup|MultiDatePicker)\b(?=\s*[({])")
SWIFT_MODIFIER = re.compile(r"\.(onTapGesture|onLongPressGesture|gesture|simultaneousGesture|highPriorityGesture|sheet|fullScreenCover|confirmationDialog|alert|popover|contextMenu|swipeActions|onDelete|onMove|onSubmit|accessibilityAction|fileImporter|photosPicker|navigationDestination|searchable|refreshable)\b(?=\s*[({])")
PRESENTATIONS = {"sheet", "fullScreenCover", "confirmationDialog", "alert", "popover", "contextMenu", "swipeActions", "navigationDestination", "fileImporter", "photosPicker"}
INPUTS = {"TextField", "TextEditor", "SecureField", "input", "textarea", "select", "DatePicker", "Picker", "Toggle", "Slider", "Stepper", "ColorPicker", "PhotosPicker", "searchable"}


def swift_candidates(path: str, source: str, localized) -> list[dict]:
    mask = mask_comments(source, True)
    clean = mask_comments(source)
    previews = []
    for m in re.finditer(r"#Preview\b", mask):
        brace = mask.find("{", m.end())
        if brace >= 0:
            previews.append((m.start(), matching(mask, brace)))
    declarations = []
    for m in re.finditer(r"\b(?:struct|class|enum)\s+(\w+)(?:[^\n{]*)\{", mask):
        declarations.append((m.start(), matching(mask, m.end() - 1), m.group(1)))
    matches = sorted([*SWIFT_CONTROL.finditer(mask), *SWIFT_MODIFIER.finditer(mask)], key=lambda m: m.start())
    # Custom component/function calls which own callbacks need their concrete call
    # sites in addition to the underlying renderer's Button implementation.
    custom = re.compile(r"\b([A-Z]\w*(?:Button|Sheet)|LegalDocumentLinks|dockIconButton|dockButton|surfaceItem|libraryShortcut|stageButton|ritualTile|actionRow)\s*(?=\()")
    occupied = {m.start() for m in matches}
    for m in custom.finditer(mask):
        if m.start() in occupied:
            continue
        prior = mask[max(0, m.start() - 30):m.start()]
        if re.search(r"\b(?:struct|func|class|enum)\s*$", prior):
            continue
        matches.append(m)
    candidates = []
    for m in sorted(matches, key=lambda m: m.start()):
        if any(a <= m.start() < b for a, b in previews):
            continue
        kind = m.group(1)
        end, action_start = swift_span(source, mask, m.start(), m.end())
        block = clean[m.start():end]
        if not block:
            continue
        is_custom = kind not in INPUTS | PRESENTATIONS | {"Button", "NavigationLink", "Menu", "ShareLink", "Link", "Map", "onTapGesture", "onLongPressGesture", "gesture", "simultaneousGesture", "highPriorityGesture", "onDelete", "onMove", "onSubmit", "accessibilityAction", "refreshable"}
        # Discard custom sheet references without a constructor callback. Their
        # enclosing .sheet is separately catalogued.
        if is_custom and kind.endswith("Sheet") and not re.search(r"\bon[A-Z]\w*\s*:", block):
            continue
        keys = list(dict.fromkeys(re.findall(r'NSLocalizedString\(\s*"([^"\n]+)"', block)))
        keys.extend(k for k in dict.fromkeys(re.findall(r'"([^"\n]+)"', block)) if k in localized["en"] and k not in keys)
        text_labels = list(dict.fromkeys(re.findall(r'(?:Text|Label|Button|Picker|Toggle|NavigationLink|Link|TextField|SecureField|DatePicker)\(\s*"([^"\n]+)"', block)))
        name = re.search(r"\.accessibilityLabel\((.*?)(?:\n|\)\s*\))", block)
        symbols = list(dict.fromkeys(re.findall(r'(?:systemName|systemImage)\s*:\s*"([^"\n]+)"', block)))
        scope = [name for a, b, name in declarations if a <= m.start() < b]
        screen = scope[-1] if scope else Path(path).stem
        selection = re.findall(r"(?:selection|isOn|text|value)\s*:\s*([^,\n)]+)", block[:1000])
        # A short source excerpt is evidence; never infer actual navigation
        # completion from the fact that a callback exists.
        if kind in {"MapCompass", "MapPitchToggle", "MapUserLocationButton"}:
            action = "MapKit内建地图控制：方向恢复/视角/定位；系统可见性和accessible name需运行时核实"
            category = "runtime_map_control"
        elif kind in PRESENTATIONS:
            action = "呈现/导航声明：" + compact(block.split("{", 1)[0], 180)
            category = "presentation_edge"
        elif is_custom:
            callbacks = re.findall(r"\b(on[A-Z]\w*|action)\s*:\s*([^\n]{0,130})", block)
            action = "复用组件调用：" + compact("; ".join(f"{a}: {b}" for a, b in callbacks) or block, 220)
            category = "custom_component_call"
        elif kind in INPUTS:
            action = "编辑/选择绑定：" + ("；".join(selection) if selection else compact(block.split("{", 1)[0], 160))
            category = "input_control"
        else:
            explicit = re.search(r"\baction\s*:\s*([^,)\n]+)", block)
            if explicit:
                action = "执行：" + compact(explicit.group(1))
            elif action_start < end and mask[action_start:action_start + 1] == "{":
                action_end = matching(mask, action_start)
                action = "执行：" + compact(clean[action_start + 1:action_end - 1], 250)
            else:
                action = "源码动作需沿调用方确认：" + compact(block.split("\n", 1)[0])
            category = "gesture_or_semantic_control" if kind not in {"Button", "NavigationLink", "Menu", "ShareLink", "Link"} else "semantic_control"
        states = []
        for expression in re.findall(r"\.disabled\(([^\n]+)", block):
            states.append("disabled(" + compact(expression, 120))
        for binding in re.findall(r"(?:isPresented|item|selection|isOn)\s*:\s*([^\n]+)", block[:600]):
            states.append("binding: " + compact(binding, 100))
        for term in ("isLoading", "isSaving", "isSubmitting", "isRecording", "isListening", "isSelected", "isFavorited", "isCompleted", "showError", "errorMessage", "reduceMotion"):
            if re.search(r"\b" + term + r"\b", block):
                states.append(term)
        if "role: .destructive" in block:
            states.append("destructive")
        if "role: .cancel" in block:
            states.append("cancel")
        candidates.append({
            "platform": "ios", "screen": screen, "control": kind, "category": category,
            "labels": {"localization_keys": keys[:12], "en": [localized["en"].get(k, k) for k in keys[:12]], "zh-Hans": [localized["zh-Hans"].get(k, k) for k in keys[:12]], "literal_candidates": text_labels[:10], "dynamic_label_expressions": re.findall(r'(?:Text|Label|Button|Picker|Toggle|NavigationLink|Link)\(\s*([^,\n]{1,120})', block)[:8], "symbols": symbols[:8], "accessibility_label_source": compact(name.group(1), 180) if name else None},
            "action": action, "states": list(dict.fromkeys(states)) or ["未从本局部块提取显式状态；需结合所在 View 与调用方"],
            "source": {"path": path, "line": line_number(source, m.start()), "end_line": line_number(source, end)},
            "dynamic_or_conditional": bool(kind in {"MapCompass", "MapPitchToggle", "MapUserLocationButton"} or re.search(r"\b(?:ForEach|if|switch|guard)\b", clean[max(0, m.start() - 1000):m.start()]) or re.search(r"\b(?:ForEach|if|switch|guard)\b", block)),
            "runtime_verification": "not_verified", "source_excerpt": compact(block, 700),
        })
    return candidates


def jsx_open_end(mask: str, start: int) -> int:
    i = start
    while i < len(mask):
        if mask[i] == "{":
            i = matching(mask, i)
        elif mask[i] == ">":
            return i + 1
        else:
            i += 1
    return len(mask)


def web_screen(path: str, scope: str) -> str:
    if path == "apps/web/src/app/page.tsx":
        return "/"
    if "/app/" in path and path.endswith("/page.tsx"):
        route = path.split("/app/", 1)[1].removesuffix("/page.tsx")
        route = re.sub(r"\([^/]+\)/?", "", route)
        return "/" + route.strip("/")
    return scope or Path(path).stem


def jsx_attribute_source(opening: str, name: str):
    """Preserve nested/template expressions instead of stopping at an inner }."""
    mask = mask_comments(opening, True)
    attribute = re.search(r"\b" + re.escape(name) + r"\s*=", mask)
    if not attribute:
        return None
    at = attribute.end()
    while at < len(opening) and opening[at].isspace():
        at += 1
    if at >= len(opening):
        return None
    if opening[at] == "{":
        return opening[at:matching(mask, at)]
    if opening[at] in ('"', "'"):
        quote = opening[at]
        end = at + 1
        while end < len(opening):
            if opening[end] == "\\":
                end += 2
            elif opening[end] == quote:
                return opening[at:end + 1]
            else:
                end += 1
    return None


def web_candidates(path: str, source: str) -> list[dict]:
    mask = mask_comments(source, True)
    clean = mask_comments(source)
    candidates = []
    declarations = [(m.start(), m.group(1)) for m in re.finditer(r"\bfunction\s+(\w+)\s*\(", mask)]
    for m in re.finditer(r"<([A-Za-z][\w.]*)\b", mask):
        kind = m.group(1)
        end = jsx_open_end(mask, m.end())
        opening = clean[m.start():end]
        events = re.findall(r"\b(onClick|onPointerDown|onPointerUp|onPointerLeave|onPointerCancel|onKeyDown|onSubmit|onChange|onDragEnd)\s*=", opening)
        semantic = kind in {"button", "a", "Link", "ButtonLink", "Button", "input", "textarea", "select", "summary", "TabButton"}
        custom_interactive = bool(re.search(r"\b(?:onClick|onSelect|onOpenChange|onIntentChange|onCheckin|onClose|onSubmit|onTap|toggleSheet|toggleCheckin|setLang|onOpenPalette)\s*=", opening))
        if not semantic and not events and not custom_interactive:
            continue
        # Parent dialogs/map components are call sites, not extra HTML buttons.
        category = "semantic_control" if semantic else "gesture_or_semantic_control" if kind[0].islower() else "custom_component_call"
        if kind in INPUTS:
            category = "input_control"
        close = clean.find(f"</{kind}>", end)
        body = clean[end:close] if close >= end and close - end < 2500 else ""
        text = compact(re.sub(r"<[^>]*>", " ", body), 250)
        aria = jsx_attribute_source(opening, "aria-label") or jsx_attribute_source(opening, "title")
        href = jsx_attribute_source(opening, "href")
        handlers = []
        for event in events:
            em = re.search(r"\b" + event + r"\s*=\s*", opening)
            if not em:
                continue
            at = em.end()
            event_end = matching(mask_comments(opening, True), at) if at < len(opening) and opening[at] == "{" else opening.find(" ", at)
            handlers.append(event + "=" + compact(opening[at:event_end], 220))
        action = "导航：" + href if href else "；".join(handlers) or "由调用方/浏览器默认语义决定；需核实是否仅装饰"
        states = []
        for a in ("disabled", "aria-pressed", "aria-expanded", "aria-selected", "value", "checked", "role", "tabIndex"):
            attribute = jsx_attribute_source(opening, a)
            if attribute:
                states.append(a + "=" + compact(attribute, 120))
        for term in ("recording", "checkinState", "loading", "selected", "active", "focused", "hover"):
            if re.search(r"\b" + term + r"\b", opening):
                states.append(term)
        scope = [name for start, name in declarations if start <= m.start()]
        candidates.append({
            "platform": "web", "screen": web_screen(path, scope[-1] if scope else ""), "control": kind, "category": category,
            "labels": {"accessible_name_source": aria, "rendered_text_source": text or None},
            "action": action, "states": states or ["依赖浏览器默认/调用方状态，运行时未验证"],
            "source": {"path": path, "line": line_number(source, m.start()), "end_line": line_number(source, end)},
            "dynamic_or_conditional": bool(re.search(r"\.map\(|&&|\?", clean[max(0, m.start() - 700):m.start()]) or "{" in opening),
            "runtime_verification": "not_verified", "source_excerpt": compact(opening + " " + text, 700),
        })
    # Mapbox controls/markers are created imperatively, not via JSX.
    for m in re.finditer(r"\b(?:new\s+(?:mapboxgl|maplibregl)\.(NavigationControl|GeolocateControl|AttributionControl|Marker)|(?:\.addEventListener|\.on)\(\s*[\"'](click|touchstart|keydown)[\"'])", clean):
        category = "runtime_map_control" if m.group(1) else "imperative_event_handler"
        scope = [name for start, name in declarations if start <= m.start()]
        candidates.append({"platform": "web", "screen": web_screen(path, scope[-1] if scope else ""), "control": m.group(1) or m.group(2), "category": category, "labels": {"rendered_text_source": "动态地图控件/标记：需运行时核实 accessible name"}, "action": compact(clean[m.start():m.start() + 350], 280), "states": ["由地图引擎/数据决定；运行时未验证"], "source": {"path": path, "line": line_number(source, m.start()), "end_line": line_number(source, m.end())}, "dynamic_or_conditional": True, "runtime_verification": "not_verified", "source_excerpt": compact(clean[m.start():m.start() + 600], 600)})
    return candidates


# Manual grouping: these are product capabilities/flows, not counts of rendered
# buttons. All source candidates remain individually addressable below.
GROUPS = [
    ("W01", "web", "官网 EN/ZH 导航", "品牌返回首页、功能锚点、定价、宣言、语言切换、获取 App", ["components/marketing/sections.tsx", "app/page.tsx", "app/zh/page.tsx"], "P1"),
    ("W02", "web", "官网 Hero/功能/信任/页脚", "下载 CTA、探索功能、底部法律与支持链接；电话内 mock 中装饰形控件", ["components/marketing/DayPageMock.tsx", "components/marketing/CapabilityMocks.tsx", "components/marketing/HeroCanvas.tsx"], "P1"),
    ("W03", "web", "定价 EN/ZH", "免费/Pro 方案 CTA、比较表、FAQ、页头与页脚", ["app/(marketing)/pricing/page.tsx", "app/zh/pricing/page.tsx"], "P1"),
    ("W04", "web", "宣言 EN/ZH", "官网导航、末尾行动链接、页脚", ["app/(marketing)/manifesto/page.tsx", "app/zh/manifesto/page.tsx"], "P2"),
    ("W05", "web", "隐私 EN/ZH", "隐私邮件、官网导航与页脚", ["app/(marketing)/privacy/page.tsx", "app/zh/privacy/page.tsx"], "P2"),
    ("W06", "web", "下载", "App Store/候补联系方式、官网导航与页脚", ["app/(marketing)/download/page.tsx"], "P1"),
    ("W07", "web", "共享 Web 控件", "营销 Button/ButtonLink 的 hover/pressed/focus；跳到主内容；设计原型入口", ["components/marketing/primitives.tsx", "components/DesignNav.tsx", "app/layout.tsx", "app/global-error.tsx"], "P1"),
    ("W08", "web", "/app 地图", "地图平移缩放、标记选择、定位/缩放/署名控件、体验浮层", ["app/app/page.tsx", "components/MapView.tsx"], "P1"),
    ("W09", "web", "/app 附近和足迹", "抽屉展开/收起、附近/时间线切换、体验行选择、空态与 loading", ["components/NearbySheet.tsx", "components/TimelineList.tsx"], "P1"),
    ("W10", "web", "/app 今日", "今日建议打开详情、关闭推荐横幅", ["components/TodayBanner.tsx"], "P1"),
    ("W11", "web", "/app 语音/文本意图", "按住说话、松手/离开停止、清除意图、权限/不支持时文本发送", ["components/VoiceIntent.tsx"], "P1"),
    ("W12", "web", "/app 体验详情", "来源外链、关闭抽屉、我去过、可选 1–5 评分、saving/done", ["components/ExperienceSheet.tsx"], "P1"),
    ("W13", "web", "/[city] 城市工作台", "城市入口、命令面板、语言、排序、分类切换、体验行与地图标记、详情与路线入口", ["app/[city]/page.tsx", "components/lisbon/WebLisbonMap.tsx"], "P1"),
    ("W14", "web", "城市命令面板", "打开、搜索、方向键/回车、鼠标结果、Escape/遮罩关闭", ["components/lisbon/CommandPalette.tsx"], "P1"),
    ("W15", "web", "/mobile-preview", "语言、命令面板、抽屉、建议提示关闭、体验详情、签到", ["app/mobile-preview/page.tsx"], "P2"),
    ("W16", "web", "/experience/[id] 分享体验", "返回城市、地图导航、下载 App、来源、附近体验和页脚", ["app/experience/[id]/page.tsx"], "P1"),
    ("W17", "web", "/trip/[slug] 分享行程", "语言切换、体验/站点链接、地图、下载/返回城市", ["app/trip/[slug]/page.tsx"], "P1"),
    ("I01", "ios", "地图主场景/城市", "城市 pill、城市/地址/坐标选择、地图样式、回到定位、标记/聚类、筛选/排序、空态、快捷收藏与行程", ["Map/CompassMapView.swift", "Map/CityPickerSheet.swift", "Map/LocationPickerSheet.swift", "Map/MapPinPickerView.swift", "Map/ClusterAnnotationView.swift", "Filter/FilterBarView.swift"], "P1"),
    ("I02", "ios", "稳定导航/发现", "地图/问问/发现三项 dock；问问长按语音；发现收藏与行程快捷入口、附近与路线、重试", ["Map/WorkspaceDock.swift", "Map/DiscoverWorkspaceView.swift", "Map/NearbySectionView.swift", "Map/NearbyExperienceRow.swift", "Map/RoutesSectionView.swift", "Map/PeekSummaryCard.swift"], "P1"),
    ("I03", "ios", "探索工作流", "探索同意、进行中控制、取消/结束、handoff、进度与失败恢复", ["Map/ExploreConsentSheet.swift", "Map/ExploreModeOverlay.swift", "Map/ExploreHandoffCard.swift", "Map/ExploreProgressBar.swift", "Map/POILoadingBanner.swift"], "P1"),
    ("I04", "ios", "保留对话/历史", "展开/收起对话、历史选择/重命名/删除、新对话、建议问题、消息相关操作", ["Chat/ChatSheet.swift", "Chat/ConversationPanel.swift", "Chat/ChatHistoryListView.swift", "Chat/HalfExpandedEmptyState.swift", "Chat/MessageBubble.swift", "Chat/MarkdownMessageText.swift"], "P1"),
    ("I05", "ios", "对话输入/附件", "文本、多行输入、附件加号、照片/相机/文件、删除附件、发送/停止、地点上下文、错误清除", ["Chat/ChatInputBar.swift", "Chat/AttachmentInputBar.swift", "Chat/AttachmentDraftStrip.swift", "Chat/AttachmentBubble.swift"], "P1"),
    ("I06", "ios", "语音", "按住/切换录音、松手发送、上滑取消、倒计时、权限/识别错误、自动停止、录音条停止", ["Shared/VoiceButton.swift", "Map/VoiceProcessingToast.swift", "Shared/VoiceWaveformView.swift"], "P1"),
    ("I07", "ios", "AI 卡片/撤销/诊断", "地点/路线卡打开、保存路线、provisional 校验、诊断同意/拒绝、banner action/关闭、撤销", ["Chat/ChatCardViews.swift", "Chat/ChatCardStack.swift", "Chat/DiagnosticsRequestCard.swift", "Chat/InlineBanner.swift", "Chat/UndoPill.swift", "Chat/SoloAgentBubbleQueue.swift"], "P1"),
    ("I08", "ios", "体验卡/预览", "打开详情、收藏、长按菜单、上下文 Ask、收藏列表", ["Experience/ExperienceCardView.swift", "Shared/ExperiencePreviewCard.swift", "Shared/FavoritesListView.swift", "Shared/LongPressCardModifier.swift"], "P1"),
    ("I09", "ios", "体验详情主动作", "关闭、收藏、Ask Solo/付费门槛、完成/取消完成、加入行程、更多菜单、分享、导航应用选择、最佳时间跳转、雷达说明、附近体验", ["Experience/ExperienceDetailView.swift", "Experience/LocationCard.swift"], "P1"),
    ("I10", "ios", "体验新增/修正/反馈", "创建标题/分类/位置等字段、保存/取消、微调查、报告类型与详情、旅行者笔记、重新编译", ["Experience/CreateExperienceSheet.swift", "Experience/MicroSurveySheet.swift", "Experience/ReportIssueSheet.swift", "Experience/TravelerNotesSection.swift", "Experience/RecompileFeedSheet.swift"], "P1"),
    ("I11", "ios", "体验分享/导出", "分享卡样式、导出图片、系统分享、Markdown 复制/分享/Notion、关闭", ["Experience/Share/ShareSheet.swift", "Experience/MarkdownShareSheet.swift"], "P2"),
    ("I12", "ios", "行程列表/创建", "新建、类型/城市/日期/名称/备注、保存、取消、列表行与删除", ["Companion/ItineraryListView.swift", "Companion/ItineraryFormView.swift", "Companion/AddToItinerarySheet.swift"], "P1"),
    ("I13", "ios", "行程详情", "编辑/删除/重排站点、导入收藏确认、添加体验、公开招募、关闭可见性提示、显示更多", ["Companion/ItineraryDetailView.swift"], "P1"),
    ("I14", "ios", "路线创建/详情", "新建路线、选站、顺序、路线详情、开始/结束、加入/发布、分享、招募状态", ["Companion/CreateRouteView.swift", "Companion/RouteDetailView.swift", "Companion/Components/RouteCard.swift", "Companion/Components/StopsList.swift", "Companion/Components/RecruitingModule.swift", "Map/ActiveRouteOverlay.swift"], "P1"),
    ("I15", "ios", "路线招募/申请", "开放招募、步速/留言、发送申请、我的申请撤回、审批接受/拒绝、自己发起/走过路线", ["Companion/OpenForCompanionsSheet.swift", "Companion/JoinRouteRequestSheet.swift", "Companion/ApprovalQueueView.swift", "Companion/MyRequestsListView.swift", "Companion/MyHostedRoutesListView.swift", "Companion/MyWalkedRoutesListView.swift", "Companion/DiscoverRecruitingRoutesView.swift"], "P1"),
    ("I16", "ios", "同伴发现/安全", "列表排序/刷新、招募详情、联系申请、收件箱、举报/屏蔽、同意安全条款", ["Companion/DiscoverListView.swift", "Companion/DiscoverPostDetailView.swift", "Companion/SendRequestSheet.swift", "Companion/RequestInboxView.swift", "Companion/ReportBlockSheet.swift", "Companion/CompanionSafetyConsentSheet.swift"], "P1"),
    ("I17", "ios", "同伴资料/消息", "昵称/简介/偏好/可见性、保存、会话选择、发消息、邀请好友、完成瞬间", ["Companion/CompanionProfileView.swift", "Companion/ChatView.swift", "Companion/ConversationListView.swift", "Companion/InviteFriendsSheet.swift", "Companion/CompletionMoment.swift"], "P1"),
    ("I18", "ios", "路线分享", "分享样式、系统分享、邀请、关闭", ["Companion/RouteShareSheet.swift"], "P2"),
    ("I19", "ios", "好友入口/邀请/扫码", "好友码、复制/分享、扫码、输入码、预览资料、发送/接受/拒绝/撤回请求、移除/屏蔽好友、重试", ["Friends/FriendsHubView.swift", "Friends/FriendsListView.swift", "Friends/AddFriendSheet.swift", "Friends/AddFriendButton.swift", "Friends/FriendProfileView.swift", "Friends/QRScannerView.swift"], "P1"),
    ("I20", "ios", "我的/权益", "个人/仪式切换、资料/收藏/行程/好友/消息入口、设置、付费入口、关闭", ["Me/MeSheet.swift", "Me/EntitlementBanner.swift"], "P1"),
    ("I21", "ios", "设置及子页", "旅行风格、偏爱/隐藏/可见分类、自定义标签、语言/主题、AI/数据源/通知、同伴 hub、导出、删除/重置、开发选项解锁", ["Settings/SettingsView.swift", "Settings/AIProviderSettingsView.swift", "Settings/DataSourceSettingsView.swift", "Settings/NotificationsSettingsView.swift", "Settings/DeveloperOptionsView.swift"], "P1"),
    ("I22", "ios", "首次使用/条款", "跳过、前进/后退、城市与偏好、照片、接受/拒绝隐私条款、位置权限", ["Onboarding/OnboardingView.swift", "Onboarding/OnboardingCityStep.swift", "Onboarding/OnboardingCohortStep.swift", "Onboarding/OnboardingVibeStep.swift", "Onboarding/TermsConsentSheet.swift"], "P1"),
    ("I23", "ios", "付费", "月/年方案、购买、继续免费、恢复购买、关闭、错误确认", ["Paywall/PaywallView.swift"], "P1"),
    ("I24", "ios", "今日/城市工具", "入境日期、今日三件事、下一步/附近、提醒横幅关闭、回执、基地确认/切换、城市工具待办/导航、Visa 提醒/日期、活动去地图、核实问答", ["Today/TodayContainer.swift", "Today/TodayStatusHeader.swift", "Today/TodayThreeThings.swift", "Today/TodayNearbyRow.swift", "Today/TodayNewHomeBanner.swift", "Today/TodaySealReceipt.swift", "CityOS/BaseCard.swift", "CityOS/BasePanelSheet.swift", "CityOS/KitSheet.swift", "CityOS/LiveSheet.swift", "CityOS/VerifySheet.swift", "CityOS/ComplianceBanner.swift", "CityOS/EventMarkerView.swift"], "P1"),
    ("I25", "ios", "仪式/归档", "归档/城市手册、解锁、盲盒时长/开始/稍后/分享、时光胶囊输入/时间/埋藏/回复/关闭、今日签完成、分享卡/壁纸/视频解锁", ["Archive/ArchiveView.swift", "Archive/CityCodexView.swift", "Blindbox/BlindboxLaunchView.swift", "Blindbox/BlindboxRecapCard.swift", "Capsule/CapsuleComposeView.swift", "Capsule/CapsuleOpenView.swift", "Omen/OmenCardView.swift", "Brag/BragCardView.swift", "Insight/InsightCardView.swift", "Ost/OstShareCard.swift"], "P2"),
    ("I26", "ios", "管理/共享反馈组件", "管理审核、banner 关闭/重试、check-in 提示、空态 action、全局手势和通用按压样式", ["Admin/ModerationView.swift", "Shared/DismissibleBanner.swift", "Shared/PendingCheckInBanner.swift", "Shared/SoloEmptyState.swift", "Shared/OfflineBanner.swift", "Shared/BottomInfoBar.swift", "Map/BottomInfoSheet.swift", "Shared/PressableButtonStyle.swift"], "P1"),
    ("I27", "ios", "信任解释/独行评分", "置信度说明 popover、独行评分说明、雷达维度点击/拖动与 VoiceOver 调整、关闭解释", ["Shared/ConfidenceBadge.swift", "Shared/SoloScoreBadge.swift", "Shared/SoloScoreRadarChart.swift", "Shared/TrustBadge.swift"], "P1"),
]


# Explicitly reviewed additions after the fixed baseline. These only affect
# source grouping when the files exist in the scanned snapshot; GROUP_DESIGN
# remains the original design assessment, not a post-fix evaluation.
CURRENT_SOURCE_GROUP_ADDITIONS = [
    {"path": "apps/web/src/components/marketing/MobileNav.tsx", "group_ids": ["W01", "W03", "W04", "W05", "W06"], "reason": "MarketingNav调用的共享移动导航，覆盖官网及营销子页的菜单/语言/下载入口。", "binding_source": "apps/web/src/components/marketing/sections.tsx"},
    {"path": "apps/web/src/components/marketing/HeroMotif.tsx", "group_ids": ["W02"], "reason": "Hero使用的静态罗盘/路线SVG，仅视觉，无直接交互候选。", "binding_source": "apps/web/src/components/marketing/sections.tsx"},
    {"path": "apps/web/src/components/ShareButton.tsx", "group_ids": ["W07", "W17"], "reason": "共享Web Share/复制链接控件；当前调用方是行程分享页。", "binding_source": "apps/web/src/app/trip/[slug]/page.tsx"},
    {"path": "apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift", "group_ids": ["I21", "I22", "I23"], "screens": ["LegalDocumentLinks"], "reason": "共享隐私/用户协议Link renderer；由首次使用、设置和付费页调用。仅归入共享法律链接，不把条款接受/退出按钮误归到设置或付费页。", "binding_sources": ["apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift", "apps/ios/SoloCompass/Views/Settings/SettingsView.swift", "apps/ios/SoloCompass/Views/Paywall/PaywallView.swift"]},
]


GROUP_DESIGN = {
    "W01": "保留罗盘标记和安静导航，旅行内容优先于品牌 chrome|移动端必须保留菜单和语言入口；当前 md 以下全部隐藏|hover 下划线应同步 keyboard focus，下载目标必须真实|首页/定价/宣言/语言切换保持所在页面的语境|页头一条细分隔线足够，避免每个导航项都变成卡片",
    "W02": "地图纹理与旅行时段最能表达产品，减少通用暖色卡片套件感|手机 mock 必须明确为演示，不能给出可点击假按钮|装饰图形不进入 Tab 序列；真实 CTA 按下后有确定结果|功能展示到体验入口的去向一致，来源和示例标识诚实|热力图/置信度已有信息量，装饰渐变和反复 reveal 应收敛",
    "W03": "两方案比较有价值，强调真实差异而非推荐徽章|官网定价需要与 iOS 实际可售方案和试用条件一致|选择方案的动作要说明下一步为下载或购买，避免误承诺|免费试用不能跳回当前 pricing 页面形成循环|选中/推荐只用一种边界强调，套餐内容保留同等可读性",
    "W04": "宣言使用有停顿的长文排版，避免每段都加装饰标签|中英正文行长与段距分别检查；中文不机械套英文样式|文字链接聚焦后仍可识别，返回入口稳定|宣言末尾提供与内容一致的产品入口|长文靠留白组织，分隔线仅服务章节",
    "W05": "隐私用可检索的事实结构建立信任|联系方式、收集范围与保留规则要易读|邮件链接必须能打开系统邮件客户端|读政策后返回来源页面的路径明确|表格边线表达字段归属，避免装饰性多层框",
    "W06": "下载页只承担下载决策，不扩张营销装饰|未发布状态需要清楚说明，不展示假 App Store 链接|可用入口说明平台和结果，失败有替代路径|支持邮件是联系方式，不能伪装即时下载|主要下载 CTA 一个重心，次级支持链接用文字",
    "W07": "共享控件先统一层级和半径再微调皮肤|48px 基础按钮已有合理触达，检查长中文标签|通用 focus 可见且按下不导致布局跳动|Button 默认 type 与 form 中提交语义明确|primary 填色/secondary 描边/ghost 文字已有层级，勿再叠加同权阴影",
    "W08": "真实地图优先显示体验与选中地点，保留地图内容呼吸|缩放/marker 不被 banner、语音按钮和抽屉遮挡|标记选择、关闭与地图平移不互相误触|定位拒绝后仍可选城市/拖动并理解当前位置|每个 marker 目前圆环/分数/置信点较多，需按重要性压低次要描边",
    "W09": "附近是选择清单，足迹是时间序列，两者视觉结构应区别|折叠把手需有明确名称和大目标；短列表不留无意义空白|Tab 选中、抽屉开合和当前选中体验可感知|重开抽屉保留浏览位置，空态给出可执行恢复|行分隔比逐行卡片更安静，选中项单独加强边缘",
    "W10": "今日推荐只表达可验证的当下价值|营业/天气等状态没有数据时不写成事实|打开建议与关闭推荐均有稳定触达，不互相挤压|关闭后维持关闭偏好，推荐更新不造成惊跳|一块轻量背景即可，避免横幅边框争抢地图重心",
    "W11": "语音是快捷方式，文本仍应始终可用|按钮文案区分开始、录音、停止、发送、失败|同时支持 pointer、键盘与辅助技术，拒绝权限有恢复|滑出/取消不能意外提交；识别结果先有明确去向|录音态只用一处波形/色彩强调，常态不持续脉冲",
    "W12": "体验详情先给能否/何时去，再给来源和细节|评分 28px 偏小；内容长时主行动和关闭仍可达|saving/done 已有分支，但失败不能静默回 idle|评分是否直接签到需要通过文案说明；双击防重复|证据信息与行动区分层，避免每个 Section 都被 ring 包围",
    "W13": "城市工作台可紧凑，但不以 10px 数据标签牺牲旅行可读性|当前多个真实 button 没动作，必须实现或明确演示状态|列表、地图 marker、排序、语言切换共享选中反馈|加入计划必须能找到保存结果，+City 需有可用目的地|左右面板用分组和留白，选中行才用类别色细边",
    "W14": "命令面板按任务和城市组织，不暴露 Scenario 编号给普通用户|搜索框具备名称，选中结果和无结果读屏可感知|方向键/回车之外，Tab、Esc、焦点恢复形成完整 modal|关闭回原触发点，搜索切换城市保留语言|一条选中指示边足够，输入框焦点可见但不堆叠边框",
    "W15": "预览明确是预览，手机壳装饰不挤压实际操作|语言/抽屉/签到目标应按移动触摸而非桌面密度设计|签到与提示关闭有可见即时结果|预览本地完成状态与真实账户签到明确区分|浮层不同时出现多个强色框，选中/主 CTA 优先",
    "W16": "分享页像一张可行动的旅行页，真实地点内容当主角|来源、时间、限制和地图去向在屏内易读|外链/导航/下载均有清楚名称，不能用相同箭头假装同结果|返回城市、打开地图与附近体验形成不迷路路径|来源作为安静文字链接，主要导航使用一个重点按钮",
    "W17": "回顾保留时间与真实站点的顺序感|语言切换、作者/日期/体验数不挤成小字装饰|站点可打开且焦点顺序跟时间顺序一致|回顾是分享快照，不能把展示数据当当前实时推荐|时间轴本身能分组，不再给每个站点叠一层重边框",
    "I01": "地图和城市名称承担识别，浮层不争抢地图视野|44pt 点击区与 Dynamic Type 分开检验；坐标需可输入负数|选城/样式/定位各自有明确状态与失败恢复|城市与地址选择必须保持 canonical 坐标，后退不丢原选择|顶部控件只在当前操作时增强边缘，普通描边降低",
    "I02": "三项 dock 与吉祥物问问已形成辨识度|地图/问问/发现的选中状态同时有文字和形状|重复点击当前 surface 不应震动，长按语音应可被发现|切换保留对话、草稿、附件与选中体验；发现加载/空态可恢复|选中 capsule 一个重心，dock 外框不能与每项都叠强框",
    "I03": "探索是有开始/结束的任务，进度表达要克制|当前阶段、耗时未知与取消结果说清楚|取消立即响应，后台阶段变化不可抢夺当前输入焦点|部分结果/网络失败/权限拒绝后允许继续浏览或重试|只给活动探索边缘强调，普通地图内容不同时 dim/发光",
    "I04": "对话保留连续性，历史列表靠内容与时间识别|折叠层级、拖动把手、键盘和列表滚动要可预测|新建/删除/重命名有明确确认与恢复|切换 surface 不清空会话；删除当前会话后落点稳定|消息气泡和卡片边缘弱化，输入与当前动作优先",
    "I05": "附件加号/文本/发送构成一条清晰输入线|长中文、附件缩略图和键盘不挤压发送/停止|发送中的禁用原因、错误重试与附件删除即时可感知|地点上下文可解除；失败保留输入与附件，不强迫重写|只在焦点/错误/上传时强调输入边框，避免常态强描边",
    "I06": "录音用波形和时间表达状态，避免装饰性持续动效|录音条需要可访问的停止/取消动作，不只视觉点击|按住、松手、上滑取消与自动停止必须显示实际提交结果|权限拒绝可进入设置或文本；后台/消失停止录音|录音是唯一高注意力色块，倒计时和取消态互斥展示",
    "I07": "推荐卡使用真实体验字段，不给普通地点编号|保存路线与打开地点要区分名称和结果|诊断请求能拒绝，撤销有足够可见时间|provisional 内容不能冒充已验证，失败提供恢复动作|证据/置信标签是辅助信息，主卡不重复多色框",
    "I08": "卡片用地点和一句具体体验建立吸引力|整卡点击与卡内收藏互不冲突，小图标保留44pt区域|收藏/取消收藏有明确状态，长按不误触打开|预览→详情→返回保留当前地点和列表位置|一层卡片表面足够；标签与次级图标少用独立边框",
    "I09": "详情底部保留收藏/问问/去过与加入行程，文字已有帮助|长名字、大字号与 compact 下四动作需真机检查|secondary .plain 仍需可感知按压；状态变化符合可撤销逻辑|付费返回应继续原来的 Ask 意图，避免再次找入口|加入行程是主重心；其他动作安静，不再给每项强描边",
    "I10": "新增和修正像简明表单，避免展示内部编译术语|字段错误贴近字段；必填、字符限制和可选项可见|提交中不能重复；失败保留草稿，成功明确保存位置|修正/报告之后能回到同一体验并看到状态|仅错误字段/当前选择增强边框，整页无需逐段容器",
    "I11": "分享卡服务旅行内容，而非塞满产品徽章|文字、图片比例和背景选择可预览；导出可读|渲染/分享 pending、失败重试、复制成功均需反馈|复制/分享/Notion 是不同结果，文案精确|预览的纸张边缘与工具区分开，避免卡片套卡片",
    "I12": "行程以名称、城市和日期识别；创建流程保持直接|名称/日期/城市错误要可理解，禁用保存需有原因|保存后立刻看到新行程；删除可确认或撤销|加入已有/新建两路径成功后返回正确上下文|选择态行程用一处勾选与边缘，普通行保持安静",
    "I13": "站点顺序就是信息结构，支持直接重排|公开招募条件明确，不让用户点到空 action|导入收藏给实际新增数量，删除站点有恢复|可见性关闭提示必须真正打开个人资料设置|重排手柄/行分隔表达顺序，不给每站多层框",
    "I14": "路线只在确有顺序时编号，地图与站点同步|起点/终点/进行中与已完成区分，宿主/参与者角色明确|开始、下一站、结束分别给对应状态和取消|活动路线退出后能恢复；站点缺坐标有解释和替代路径|当前站/主行动单一强调，已走过站点降低边缘注意力",
    "I15": "申请和审批保持事实语气，不包装成社交刺激|步速、人数、截止与身份先读得懂再提交|发送/撤回/接受/拒绝皆有 pending 和失败恢复|申请状态变化与消息/路线同步，重复操作幂等|危险动作与普通选择区分，拒绝不必给全卡红框",
    "I16": "同伴功能作为次级目的地，不挤压独行主任务|联系前说明可见性、发送范围与安全条款|举报/屏蔽/同意有具体结果，拒绝仍能离开|被屏蔽和不可见用户路径一致，后台失败不能显示成功|仅风险确认用危险色，普通资料保持安静",
    "I17": "资料尊重匿名与最少输入，消息用自然会话结构|昵称/简介限制与可见性即时可理解|保存/发送/邀请加载反馈，网络错误不丢草稿|改可见性后读回状态；会话列表能恢复正确对话|输入焦点和未读状态各一处强调，头像不叠装饰框",
    "I18": "路线分享让顺序和地理关系优先|样式选择有可读名称，长中文路线名不可截断意义|渲染中/分享取消/保存成功均有真实状态|系统 share sheet 失败返回同一预览，邀请与公开分享不同|分享预览与底部工具一条边界即可",
    "I19": "好友码和扫码是工具入口，避免社交 feed 语汇|扫码与手输同等可达，权限拒绝可返回手输|复制成功、请求等待/接受/移除反馈明确|请求过期/码无效/重复好友有可执行解释|主要扫码/添加入口明确，其余请求状态不争主色",
    "I20": "我的按资料和旅行仪式分组，保持主地图轻量|分段选择需名称；消息未读信息不能只靠颜色|设置、关闭、付费入口目标明确|返回上级保留当前分段与滚动，不叠多层 modal|导航行不额外包胶囊，权益 banner 保留次级权重",
    "I21": "设置采用系统列表，减少每行彩色符号竞争|偏爱/隐藏分类需要按钮与选中语义；仅手势不够|即时偏好保存有状态；导出/删除有结果与恢复|隐藏高级项不影响正常偏好；语言切换后状态不丢|分组标题和系统分隔线足够，不为每行增加框",
    "I22": "首次使用展示一次具体旅行任务，避免连续营销页|跳过/后退可达，大字号和照片权限拒绝仍可继续|进度与下一步说明当前行为，条款拒绝不意外接受|跳过不创建假偏好，重开 App 不重复门槛|单一主行动与安静跳过，不把所有选项做主色大卡",
    "I23": "付费强调真实权益和周期，不靠推荐徽章施压|VoiceOver 要同时读产品、价格、周期与选中状态|购买/恢复进行中和错误清楚；继续免费易点击|StoreKit 返回后恢复原任务，取消购买保持免费|选中边框必须配合选中语义和勾选，未选项不需重边框",
    "I24": "今日和城市工具表达当下可执行事项，减少仪式层压迫|核实关闭30pt/置信解释32pt需要扩大触达|待办勾选/核实提交/日期保存要有真实结果|Visa/基地等数据由用户确认，不把推断写成事实|待办、活动和提醒各自层级清晰，不并排多强色框",
    "I25": "旅行仪式应可选、轻量；真实旅记比印章装饰重要|硬编码英文按钮影响中文完整感，月份/时长单位需本地化|生成/埋藏/分享 pending 与失败不丢正文|盲盒允许稍后；胶囊成功显示可再次找到的记录|纪念内容一处视觉重心，工具按钮和卡边界退后",
    "I26": "共享反馈组件保持统一语气，错误给方向|关闭/重试图标触达与可访问名称一致|成功只在落盘或服务器确认后出现，自动消失不抢读屏|管理危险操作确认；空态提供准确恢复路径|警告和危险使用语义色，普通 banner 不长期发光",
    "I27": "信任信息值得解释，但不应像促销徽章|compact 标记小字与固定宽度需看大字号/深色|评分说明与置信度 popover 关闭可达，触摸与读屏等价|未知值、无信号与多来源区别；雷达调整读出维度和值|非健康 pulse 与高评分 twinkle 同屏可能争抢，优先仅点开后动画",
}


BASELINE_FINDINGS = [
    ("Q01", "web", "P1", "下载 CTA 指向占位 App Store SKU", "apps/web/src/components/marketing/sections.tsx", 'const APP_STORE_URL = "https://apps.apple.com/app/solo-compass/id0000000000"', "官网导航、Hero 和方案按钮共用占位 ID。", "统一真实下载落点；未发布时明确状态并提供可用联系/候补入口。", "逐个 CTA 到可用目标，且文案准确描述落点。"),
    ("Q02", "web", "P1", "移动端营销导航/语言/下载全部隐藏", "apps/web/src/components/marketing/sections.tsx", 'className="hidden items-center gap-1 md:flex"', "菜单与语言/Get App 使用 md 以下 hidden，当前无对应移动替代。", "提供紧凑菜单，保留语言和主要行动。", "320/390px 能进入功能、价格、宣言、语言与下载；Tab 顺序正确。"),
    ("Q03", "web", "P2", "Hero 装饰图使用无动作且无名称的 button", "apps/web/src/components/marketing/DayPageMock.tsx", '<button className="flex h-7 w-7', "返回与心形 mock 是原生 button，无事件、名称或说明。", "纯展示改为不可聚焦装饰；若可演示则实现真实状态并标明演示。", "键盘不会停在无效装饰按钮；辅助技术不会读出无名称按钮。"),
    ("Q04", "web", "P1", "免费试用链接回到定价页", "apps/web/src/components/marketing/sections.tsx", "href={pricingPath}", "Pricing 中的免费试用文案指向 /pricing 或 /zh/pricing，独立定价页上形成自身循环。", "免费 CTA 打开可用试用/下载路径，保留语言。", "从首页和定价页点击免费入口均能开始真实下一步。"),
    ("Q05", "web", "P1", "城市工作台 +City 是死按钮", "apps/web/src/app/[city]/page.tsx", "+ City", "button 显示 pointer 样式，却没有 onClick/href。", "实现选城入口或替换为清楚的不可交互预览说明。", "点击与键盘激活都有实际、相同的选城结果。"),
    ("Q06", "web", "P1", "示意图缩放/定位三个按钮无动作", "apps/web/src/app/[city]/page.tsx", '{["+", "−", "⌖"].map', "三种地图工具循环为 button，均没有事件；示意 SVG 不支持真实定位。", "实现真实缩放/定位或移除工具假象，保留演示说明。", "每个展示为可用的地图控件都有可见且诚实的效果。"),
    ("Q07", "web", "P1", "加入计划主 CTA 无动作", "apps/web/src/app/[city]/page.tsx", "{T.addToPlan}", "聚焦体验中的主要填色 button 只有样式，没有点击处理。", "实现加入并反馈保存结果；展示具体查看入口与撤销。", "同一体验不能重复添加；刷新后或指定持久层能找回结果。"),
    ("Q08", "web", "P1", "城市体验行和 SVG 标记仅鼠标可达", "apps/web/src/app/[city]/page.tsx", "onMouseEnter={onMouseEnter}", "体验行 div onClick，无 button/link 语义、tabIndex 和键盘等价；WebLisbonMap g 同样仅 click。", "使用语义控件或补完整键盘/辅助技术行为，并显示焦点。", "Tab/Enter/Space 与鼠标能选择同一体验，读出名称和选中状态。"),
    ("Q09", "web", "P1", "Web 语音只支持 pointer，正常态没有主动文本入口", "apps/web/src/components/VoiceIntent.tsx", "onPointerDown={handlePressStart}", "支持 Web Speech 时仅显示按住语音；没有 onClick/onKeyDown，文本只在拒绝或不支持时出现。", "保留文本输入与键盘可用语音切换，录音可显式取消。", "纯键盘可输入需求并发送；录音启停不依赖 pointer。"),
    ("Q10", "web", "P1", "签到失败静默，评分触达过小", "apps/web/src/components/ExperienceSheet.tsx", 'setCheckinState("idle");', "catch 直接回 idle 无错误信息；评分数字 button 仅 h-7 w-7。", "错误说明并可重试，保留评分；扩大触达且声明评分会立即签到。", "模拟非2xx：看到失败/重试且无假成功；触摸评分不误触相邻项。"),
    ("Q11", "web", "P1", "命令面板缺完整 modal 焦点管理", "apps/web/src/components/lisbon/CommandPalette.tsx", "if (open) inputRef.current?.focus();", "有初始 focus、方向键和 Esc，但未圈定 Tab、恢复触发焦点；input 没有显式 label。", "补框内焦点循环/关闭恢复、搜索框名称和选中项读屏关联。", "Tab 不进入背景；Esc 回原触发点；读屏能读查询和当前结果。"),
    ("Q12", "ios", "P1", "行程可见性提示的打开设置 action 为空", "apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift", 'Button(NSLocalizedString("companion.post.visibilityOff.action"', "打开个人资料设置的按钮内部只有 Phase 2 注释。", "直接呈现 CompanionProfileView，编辑后重读可见性并可继续原任务。", "关闭可见性→尝试招募→打开设置→调整→返回，流程真实闭环。"),
    ("Q13", "ios", "P1", "录音条视觉可停止，VoiceOver 只读标签", "apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift", ".onTapGesture { onMicToggle(false) }", "录音条随后 accessibility children ignore，仅 label，缺默认 stop action/按钮语义。", "为停止与取消提供可访问动作，朗读当前录音状态与结果。", "VoiceOver 可单独完成录音→停止/取消→得到预期结果。"),
    ("Q14", "ios", "P1", "偏爱分类使用未说明状态的点击手势", "apps/ios/SoloCompass/Views/Settings/SettingsView.swift", ".onTapGesture { togglePreferred(category) }", "CategoryPreferencesView 的 row 手势无按钮/selected traits；隐藏项移除 xmark 的含义和触达也需补齐。", "改为语义 Button/Toggle，朗读偏爱/隐藏/普通状态与操作。", "VoiceOver 读出分类、当前状态与操作，完成偏爱/隐藏/恢复。"),
    ("Q15", "ios", "P2", "经纬度手输键盘缺负号入口", "apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift", ".keyboardType(.decimalPad)", "CoordinateField 使用 decimalPad，常规屏幕键盘没有负号，西经/南纬输入受阻；粘贴/硬件键盘另论。", "支持带符号小数输入或半球切换，保留范围验证和坐标顺序。", "屏幕键盘能输入 Lisbon -9.14、西经与南纬，保存后坐标正确。"),
    ("Q16", "ios", "P2", "多个紧凑控件未满足项目44pt触达约定", "apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift", ".frame(width: 30, height: 30)", "核实关闭30×30；ConfidenceBadge 最小高32；SoloScoreBadge 仅内容 padding，未见44pt扩展。", "保持小视觉图形，同时把语义按钮标签的 hit region 扩大到44pt。", "实际命中区至少44×44；相邻目标不重叠，compact 与大字可操作。"),
    ("Q17", "ios", "P1", "付费方案读屏隐藏价格周期和选择状态", "apps/ios/SoloCompass/Views/Paywall/PaywallView.swift", ".accessibilityLabel(Text(product.displayName))", "productCard Button 覆盖 label 为 displayName，未附 displayPrice、periodLabel、selected value/trait。", "朗读方案名、价格、周期、试用条件和选中状态，并保留所有方案同等可达。", "闭眼用 VoiceOver 能区分每个实际方案和选中项，再确认准确购买信息。"),
    ("Q18", "ios", "P2", "原生仪式界面仍有硬编码英文控件", "apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift", 'Picker("Surface in",', "Capsule 的 Surface in/Cancel，Blindbox 的 Duration/Not now，Omen 的 Mark done，以及 Paywall 周期 /month 等未本地化。", "按项目双语资源统一按钮、单位和结果文案。", "简中环境这些流程无混入英文操作词，英文环境周期/复数自然。"),
    ("Q19", "ios", "P2", "徽章持续动效可能分散体验内容注意力", "apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift", ".repeatForever(autoreverses: false)", "非健康 confidence 反复 pulse，高评分 SoloScoreBadge 另有 twinkle/pulse；同屏可能同时争抢。此项为源码设计风险，需视觉实测。", "把主动动画限制到首次变化或用户展开；静态常态保留语义色和文字。", "同屏多个卡片仍能立即识别主要行动；减少动态开启时无残余循环。"),
    ("Q20", "web", "P1", "深色主题主CTA前景复用背景变量导致低对比", "apps/web/src/components/marketing/primitives.tsx", "bg-accent text-bg-warm", "dark media将--bg-warm变为#171410，而--accent仍#5d3000；primary变成深棕底近黑文字，静态颜色比约1.651:1。全局focus使用同accent，在#0f0d0b上约1.744:1。", "新增语义on-accent固定高对比前景和自适应focus token；不要用页面背景变量作为按钮文字。", "深色浏览器截图与computedStyle核对主CTA/所有focus；文字颜色比符合目标且焦点清楚。"),
]


def baseline_findings():
    findings = []
    for fid, platform, priority, title, path, anchor, evidence, recommendation, acceptance in BASELINE_FINDINGS:
        source = git("show", f"{BASELINE}:{path}")
        pos = source.find(anchor)
        findings.append({"id": fid, "platform": platform, "priority": priority, "title": title, "source": {"path": path, "line": line_number(source, pos) if pos >= 0 else None, "ref": BASELINE}, "source_anchor": anchor, "source_anchor_verified": pos >= 0, "evidence": evidence, "status": "source_design_risk_runtime_not_verified" if fid == "Q19" else "baseline_source_confirmed_runtime_not_verified", "recommendation": recommendation, "acceptance": acceptance})
    return findings


VISUAL_AUDITS = [
    ("V01", "apps/web/src/components/marketing/HeroCanvas.tsx", "export function HeroCanvas", "Hero氛围：极光shader/罗盘环/120或220粒子", "已有idle mount、WebGL不可用降级、出视口/减少动态暂停和DPR上限；这些是可保留的节制措施。", "与标题及手机mock同时截图核实，装饰不降低文字清晰度；测真实帧率前不声称卡顿。"),
    ("V02", "apps/web/src/components/marketing/DayPageMock.tsx", "linear-gradient(135deg", "手机mock：渐变图/信任chips/评分条/热力图", "图案应说明真实体验结构，明确示例；装饰按钮不能制造操作承诺。", "中英/深色/320px查看文字与图案；热力图减少动态时静止。"),
    ("V03", "apps/web/src/components/marketing/CapabilityMocks.tsx", "export function", "功能示意图：问问/盲盒/胶囊/预兆/BestNow/旅记", "同一视觉材质可保留，六功能不必各自用新强色/边框。", "核实示例标签、来源可信度和当前真实能力一致；不把示例AI理由写成可验证事实。"),
    ("V04", "apps/web/src/components/marketing/sections.tsx", 'animationDelay: "1040ms"', "Hero逐层reveal", "标题逐行、正文、CTA、手机多段延迟与氛围并存，注意力可能过多。", "首次可用CTA不能依赖漫长入场；开启减少动态完全可见；仅通过实测决定压缩入场。"),
    ("V05", "apps/web/src/app/globals.css", ".sc-halo {", "城市示意图选中/hover光环", "2.4秒无限循环，基线没有对应prefers-reduced-motion停用分支。", "减少动态时停用；选中用静态颜色/形状也能识别，避免常态脉冲争抢。"),
    ("V06", "apps/web/src/app/globals.css", "--font-display:", "字体与中英排版", "当前Space Grotesk/Inter/JetBrains Mono/Fraunces/中文fallback五角色需节制；数据标签uppercase不适合泛化每段。", "只保留有信息作用的标签；正文行长、汉字字重和字体加载前后分别核实。"),
    ("V07", "apps/web/src/components/lisbon/WebLisbonMap.tsx", '<pattern id="webPaper"', "城市示意地图：纸纹/等高线/河流/街道/标签", "与地图主题有关的图案比通用渐变更能表达旅行，但必须继续明确非地理导航示意。", "低对比纹理不抢marker，选中点/列表关联清楚，键盘仍可选点。"),
    ("V08", "apps/web/src/components/marketing/primitives.tsx", "const buttonBase", "按钮层级/边框/阴影", "primary填色、secondary描边、ghost文字已有层级；不要再给每个普通交互增加强阴影。", "按下/hover/focus均可辨，减少动态下不位移；dark on-accent见Q20。"),
    ("V09", "apps/ios/SoloCompass/Views/Shared/DesignTokens.swift", "public enum Space", "iOS空间/圆角/材质/阴影", "已存在4pt空间与语义材质，新增界面优先复用；不做单纯全局换半径。", "在真正使用点检查token采用与大小层级，不能仅看token定义声称全局统一。"),
    ("V10", "apps/ios/SoloCompass/Views/Shared/CompareTokens.swift", "public enum CT", "iOS颜色与跨端token", "固定明色token和自适应dark token并存；调用方必须与实际背景匹配。", "实际组合测正文/徽章/禁用态/焦点对比；用语义状态而非为不同卡随意添色。"),
    ("V11", "apps/ios/SoloCompass/Views/Shared/TrustBadge.swift", "CT.mono(9.5, .semibold)", "来源徽章小字/描边", "compact9.5pt、uppercase/字距、fixedSize和独立边界可能降低可读性并增加边缘密度，此处仅为设计风险。", "大字号、深色、小屏、长来源词实测；扩大内容可读性，不把静态说明变主CTA。"),
    ("V12", "apps/ios/SoloCompass/Views/Shared/PressableButtonStyle.swift", "public init(pressedScale:", "通用按压缩放与触觉", "默认0.92缩放8%，haptic默认关闭并尊重减少动态；不能为了感觉有交互让所有导航都震动。", "小标签与大主按钮分别实测按压幅度；提交才触觉确认，取消手势不假报成功。"),
]


def visual_audits(read, ref, diagnostics=None):
    diagnostics = diagnostics if diagnostics is not None else []
    result = []
    for vid, path, anchor, subject, observation, acceptance in VISUAL_AUDITS:
        source = read_optional(read, path, diagnostics, "visual_audits")
        pos = source.find(anchor) if source is not None else -1
        result.append({"id": vid, "subject": subject, "source": {"path": path, "line": line_number(source, pos) if pos >= 0 else None, "ref": ref, "sha256": hashlib.sha256(source.encode()).hexdigest() if source is not None else None}, "anchor_found_in_snapshot": pos >= 0, "observation_ref": BASELINE, "observation": observation, "runtime_acceptance": acceptance, "verification_status": "baseline_design_observation_current_runtime_not_verified"})
    return result


def parse_js_literal(source: str, bindings=None):
    """Parse static values and explicitly supplied bindings without executing JS."""
    bindings = bindings or {}
    clean = mask_comments(source)
    token_pattern = re.compile(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`|[A-Za-z_$][\w$]*|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?|[{}\[\]:,.]''')
    tokens = []
    last = 0
    for match in token_pattern.finditer(clean):
        if clean[last:match.start()].strip():
            raise ValueError("不可解析：包含表达式、模板字符串或不支持的语法。")
        tokens.append(match.group())
        last = match.end()
    if clean[last:].strip() or not tokens:
        raise ValueError("不可解析：不是完整的静态字面量。")
    cursor = 0

    def reference(name):
        parts = name.split(".")
        if parts[0] not in bindings:
            raise ValueError(f"不可解析：{name}不是显式解析的静态绑定。")
        result = bindings[parts[0]]
        for part in parts[1:]:
            if not isinstance(result, dict) or part not in result:
                raise ValueError(f"不可解析：静态绑定{name}的成员缺失。")
            result = result[part]
        return result

    def value():
        nonlocal cursor
        if cursor >= len(tokens):
            raise ValueError("不可解析：字面量不完整。")
        token = tokens[cursor]
        cursor += 1
        if token == "{":
            result = {}
            while tokens[cursor] != "}":
                key = tokens[cursor]
                cursor += 1
                if key.startswith(('"', "'")):
                    key = ast.literal_eval(key)
                if cursor >= len(tokens) or tokens[cursor] != ":":
                    raise ValueError("不可解析：对象成员缺少冒号或使用了表达式。")
                cursor += 1
                result[key] = value()
                if tokens[cursor] == ",":
                    cursor += 1
            cursor += 1
            return result
        if token == "[":
            result = []
            while tokens[cursor] != "]":
                result.append(value())
                if tokens[cursor] == ",":
                    cursor += 1
            cursor += 1
            return result
        if token.startswith("`"):
            # Only ${identifier.member} is supported; no JS operators/calls.
            body = token[1:-1]
            if "\\" in body:
                raise ValueError("不可解析：模板字符串转义未实现。")
            def interpolate(match):
                name = match.group(1).strip()
                if not re.fullmatch(r"[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*", name):
                    raise ValueError("不可解析：模板字符串包含非静态引用表达式。")
                result = reference(name)
                if not isinstance(result, (str, int, float, bool)):
                    raise ValueError("不可解析：模板引用不是标量。")
                return str(result)
            rendered = re.sub(r"\$\{([^{}]*)\}", interpolate, body)
            if "${" in rendered:
                raise ValueError("不可解析：模板字符串未完整展开。")
            return rendered
        if token.startswith(('"', "'")):
            return ast.literal_eval(token)
        if token in {"true", "false", "null"}:
            return {"true": True, "false": False, "null": None}[token]
        if re.fullmatch(r"[A-Za-z_$][\w$]*", token):
            name = token
            while cursor < len(tokens) and tokens[cursor] == ".":
                cursor += 1
                if cursor >= len(tokens) or not re.fullmatch(r"[A-Za-z_$][\w$]*", tokens[cursor]):
                    raise ValueError("不可解析：静态成员引用不完整。")
                name += "." + tokens[cursor]
                cursor += 1
            return reference(name)
        if not re.fullmatch(r"-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?", token):
            raise ValueError(f"不可解析：{token}不是静态字面量。")
        return float(token) if re.search(r"[.eE]", token) else int(token)

    try:
        result = value()
    except (IndexError, SyntaxError, AssertionError) as error:
        raise ValueError("不可解析：字面量结构不完整或包含不支持的语法。") from error
    if cursor != len(tokens):
        raise ValueError("不可解析：字面量后还有未消费的源码。")
    return result


def literal_initializer(source: str, name: str, bindings=None):
    """Locate a const/let initializer; unsupported computed values stay unresolved."""
    mask = mask_comments(source, True)
    declaration = re.search(r"\b(?:const|let|var)\s+" + re.escape(name) + r"\b", mask)
    if not declaration:
        raise ValueError(f"不可解析：没有找到变量{name}。")
    equals = mask.find("=", declaration.end())
    if equals < 0:
        raise ValueError(f"不可解析：变量{name}没有初始化值。")
    at = equals + 1
    while at < len(mask) and mask[at].isspace():
        at += 1
    if at >= len(mask) or mask[at] not in "{[":
        raise ValueError(f"不可解析：变量{name}改为计算值或非对象/数组。")
    end = matching(mask, at)
    return parse_js_literal(source[at:end], bindings)


def static_marketing_imports(read, source, diagnostics):
    """Resolve named @/lib imports only from their current static declarations."""
    bindings = {}
    clean = mask_comments(source)
    for imported in re.finditer(r'import\s*\{([^}]+)\}\s*from\s*[\'\"](@/lib/[\w/-]+)[\'\"]', clean):
        path = "apps/web/src/" + imported.group(2).removeprefix("@/") + ".ts"
        dependency = read_optional(read, path, diagnostics, "marketing_static_imports")
        if dependency is None:
            continue
        dep_clean = mask_comments(dependency)
        for member in imported.group(1).split(","):
            name_match = re.fullmatch(r"\s*([A-Za-z_$][\w$]*)(?:\s+as\s+([A-Za-z_$][\w$]*))?\s*", member)
            if not name_match:
                diagnostics.append({"parser": "marketing_static_imports", "path": path, "status": "unparseable", "detail": "当前named import无法静态解析；未假定原常量值。"})
                continue
            name, alias = name_match.group(1), name_match.group(2) or name_match.group(1)
            declaration = re.search(r"\bexport\s+const\s+" + re.escape(name) + r"\s*=\s*", dep_clean)
            try:
                if not declaration:
                    raise ValueError(f"不可解析：未找到export const {name}的静态声明。")
                start = declaration.end()
                if dep_clean[start:start + 1] in "{[":
                    bindings[alias] = literal_initializer(dependency, name)
                else:
                    scalar = re.match(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|true\b|false\b|null\b|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?''', dep_clean[start:])
                    if not scalar or not re.match(r"\s*(?:;|as\s+const\b|$)", dep_clean[start + scalar.end():]):
                        raise ValueError(f"不可解析：{name}不是完整静态标量。")
                    bindings[alias] = parse_js_literal(scalar.group())
            except (ValueError, TypeError) as error:
                diagnostics.append({"parser": "marketing_static_imports", "path": path, "status": "unparseable", "detail": str(error)})
    return bindings


def property_expression(source: str, key: str):
    mask = mask_comments(source, True)
    member = re.search(r"\b" + re.escape(key) + r"\s*:", mask)
    if not member:
        return None
    cursor = member.end()
    start = cursor
    while cursor < len(mask):
        if mask[cursor] in "{[":
            cursor = matching(mask, cursor)
        elif mask[cursor] == "(":
            cursor = matching(mask, cursor)
        elif mask[cursor] in ",}":
            break
        else:
            cursor += 1
    return source[start:cursor].strip() or None


def resolved_marketing_controls(read, diagnostics=None):
    """Resolve current source bindings; never infer hrefs from former constant names."""
    diagnostics = diagnostics if diagnostics is not None else []
    copy_path = "apps/web/src/components/marketing/copy.ts"
    binding_path = "apps/web/src/components/marketing/sections.tsx"
    source = read_optional(read, copy_path, diagnostics, "marketing_copy")
    bindings = read_optional(read, binding_path, diagnostics, "marketing_bindings")
    if source is None or bindings is None:
        return []
    try:
        data = literal_initializer(source, "copy", static_marketing_imports(read, source, diagnostics))
    except (ValueError, TypeError) as error:
        diagnostics.append({"parser": "marketing_copy", "path": copy_path, "status": "unparseable", "detail": str(error)})
        return []
    if not isinstance(data, dict):
        diagnostics.append({"parser": "marketing_copy", "path": copy_path, "status": "unparseable", "detail": "copy不是语言字典；未套用旧字段结构。"})
        return []
    controls = web_candidates(binding_path, bindings)
    resolved_bindings = []
    for control in controls:
        text = control["labels"].get("rendered_text_source") or ""
        paths = list(dict.fromkeys(re.findall(r"\bcopy\.([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*)", text)))
        target = control["action"].removeprefix("导航：") if control["action"].startswith("导航：") else None
        for path in paths:
            resolved_bindings.append((path, target, control["source"]["line"], None))
        if not paths and text and "{" not in text and control["control"] in {"a", "Link", "ButtonLink"}:
            resolved_bindings.append((f"literal@{control['source']['line']}", target, control["source"]["line"], text))
    # Nav item maps bind labels in a data object rather than directly in JSX.
    binding_mask = mask_comments(bindings, True)
    for match in re.finditer(r"\blabel\s*:\s*copy\.([A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*)", binding_mask):
        enclosing = None
        for brace in (m.start() for m in re.finditer(r"\{", binding_mask[:match.start()])):
            end = matching(binding_mask, brace)
            if end > match.end():
                enclosing = bindings[brace:end]
        target = property_expression(enclosing, "href") if enclosing else None
        resolved_bindings.append((match.group(1), target, line_number(bindings, match.start()), None))
    rows = []
    for locale, copy in data.items():
        if not isinstance(copy, dict):
            diagnostics.append({"parser": "marketing_copy", "path": copy_path, "status": "unparseable", "detail": f"语言{locale}的值不是对象。"})
            continue
        entries = []
        for key, href, source_line, literal in resolved_bindings:
            value = copy
            if literal is not None:
                value = literal
            else:
                for segment in key.split("."):
                    value = value.get(segment) if isinstance(value, dict) else None
            if not isinstance(value, str):
                diagnostics.append({"parser": "marketing_bindings", "path": binding_path, "status": "unparseable", "detail": f"{locale}: copy.{key}缺失或不是静态字符串；保留源码绑定，未补旧文案。"})
            entries.append((key, value if isinstance(value, str) else None, href, source_line))
        # Only expand a footer data shape when the current component still uses it.
        if re.search(r"\bcopy\.footer\.columns\b", binding_mask):
            footer = copy.get("footer")
            columns = footer.get("columns") if isinstance(footer, dict) else None
            if not isinstance(columns, list):
                diagnostics.append({"parser": "marketing_footer", "path": copy_path, "status": "unparseable", "detail": f"{locale}:当前绑定footer.columns无法解析；未使用旧页脚。"})
            else:
                for col in columns:
                    links = col.get("links") if isinstance(col, dict) else None
                    if not isinstance(links, list):
                        diagnostics.append({"parser": "marketing_footer", "path": copy_path, "status": "unparseable", "detail": f"{locale}:页脚列缺失links数组。"})
                        continue
                    for link in links:
                        label = link.get("label") if isinstance(link, dict) else None
                        href = link.get("href") if isinstance(link, dict) else None
                        if not isinstance(label, str) or not isinstance(href, str):
                            diagnostics.append({"parser": "marketing_footer", "path": copy_path, "status": "unparseable", "detail": f"{locale}:页脚链接缺少静态label/href。"})
                        entries.append(("footer." + str(col.get("heading", "不可解析的列名")), label if isinstance(label, str) else None, href if isinstance(href, str) else None, None))
        for key, label, href, source_line in entries:
            if href is None:
                diagnostics.append({"parser": "marketing_bindings", "path": binding_path, "status": "unparseable", "detail": f"{locale}: {key}的当前href无法静态提取；未使用基线落点。"})
            rows.append({"id": f"MR-{locale}-{len(rows) + 1:03}", "locale": locale, "component_path": key, "label": label, "target_source": href, "source": {"path": binding_path, "line": source_line}, "parse_status": "source_expression_only" if label is not None and href is not None else "unparseable", "runtime_verification": "not_verified", "counting_note": "当前源码绑定的实例规则；表达式未执行，不假定常量名、下载URL或运行时落点。"})
    if not rows:
        diagnostics.append({"parser": "marketing_bindings", "path": binding_path, "status": "unparseable", "detail": "未找到可展开的当前营销绑定；请检查新组件，不能据此断言零链接。"})
    return rows


def resolved_web_data_instances(read, diagnostics=None):
    diagnostics = diagnostics if diagnostics is not None else []
    lisbon_path = "apps/web/src/lib/lisbon-data.ts"
    cities_path = "apps/web/src/lib/cities-data.ts"
    trips_path = "apps/web/src/lib/trips-data.ts"
    sources = {path: read_optional(read, path, diagnostics, "web_data") for path in (lisbon_path, cities_path, trips_path)}
    failures_before = len(diagnostics)

    def parse_named(path, name, shape):
        source = sources[path]
        if source is None:
            return shape()
        try:
            value = literal_initializer(source, name)
            if not isinstance(value, shape):
                raise ValueError(f"不可解析：{name}不再是{shape.__name__}。")
            return value
        except (ValueError, TypeError) as error:
            diagnostics.append({"parser": "web_data", "path": path, "status": "unparseable", "detail": str(error)})
            return shape()

    def field(value, key, path, identity):
        result = value.get(key) if isinstance(value, dict) else None
        if not isinstance(result, str):
            diagnostics.append({"parser": "web_data", "path": path, "status": "unparseable", "detail": f"{identity}.{key}缺少静态字符串；未补旧标签。"})
            return None
        return result

    cats = parse_named(lisbon_path, "WEB_CATS", dict)
    lisbon = parse_named(lisbon_path, "WEB_CITY", dict)
    city_order = parse_named(cities_path, "CITY_ORDER", list)
    city_metadata = {}
    if isinstance(lisbon.get("slug"), str):
        city_metadata[lisbon["slug"]] = lisbon
    # Other city objects may reference arrays; extract only literal metadata,
    # without executing identifiers or substituting former city names.
    for path, source in sources.items():
        if source is None:
            continue
        mask = mask_comments(source, True)
        for declaration in re.finditer(r"\b(?:const|let)\s+(\w*CITY\w*)\b[^=;]*=\s*\{", mask):
            at = declaration.end() - 1
            block = source[at:matching(mask, at)]
            metadata = {}
            for key in ("slug", "en", "zh"):
                expression = property_expression(block, key)
                try:
                    metadata[key] = parse_js_literal(expression or "")
                except ValueError:
                    pass
            if isinstance(metadata.get("slug"), str):
                city_metadata[metadata["slug"]] = metadata
    cities = []
    for slug in city_order:
        if not isinstance(slug, str):
            diagnostics.append({"parser": "web_data", "path": cities_path, "status": "unparseable", "detail": "CITY_ORDER包含非静态字符串；未推断城市。"})
            continue
        metadata = city_metadata.get(slug, {})
        cities.append({"slug": slug, "en": field(metadata, "en", cities_path, slug), "zh": field(metadata, "zh", cities_path, slug), "href": "/" + slug, "target_status": "route_pattern_only_not_control_binding"})
    exps = [(lisbon.get("slug"), lisbon_path, e) for e in parse_named(lisbon_path, "WEB_EXPS", list)]
    porto_metadata = next((value for value in city_metadata.values() if value.get("slug") == "porto"), {})
    exps.extend((porto_metadata.get("slug"), cities_path, e) for e in parse_named(cities_path, "PORTO_EXPS", list))
    trips = parse_named(trips_path, "TRIPS", dict)
    categories = [{"id": key, "en": field(value, "en", lisbon_path, key), "zh": field(value, "zh", lisbon_path, key), "action": "静态分类值；实际切换/清除逻辑需沿当前控件核实。"} for key, value in cats.items()]
    experiences = []
    for city, path, e in exps:
        exp_id = field(e, "id", path, "experience")
        experiences.append({"id": exp_id, "city": city, "en": field(e, "title", path, str(exp_id)), "zh": field(e, "titleZh", path, str(exp_id)), "detail_href": "/experience/" + exp_id if exp_id is not None else None, "target_status": "baseline_route_pattern_only_not_current_control_binding", "instance_roles": ["静态数据实例；当前列表/marker/命令/分享绑定需逐项核实"]})
    result = {"counting_note": "仅可解析的当前静态数据；列表为空时先检查parsing_diagnostics，不能断言没有该功能。route_pattern不代表当前控件已绑定href。", "cities": cities, "categories": categories, "experiences": experiences, "trips": [{"slug": key, "en": field(trip, "titleEn", trips_path, key), "zh": field(trip, "titleZh", trips_path, key), "href": "/trip/" + str(key), "target_status": "baseline_route_pattern_only_not_current_control_binding"} for key, trip in trips.items()]}
    result["parse_status"] = "partial_or_unparseable" if len(diagnostics) > failures_before or any(source is None for source in sources.values()) else "parsed_static_data_only"
    return result


def manual_groups(candidates, source_files=None):
    present_paths = set(source_files) if source_files is not None else {c["source"]["path"] for c in candidates}
    groups = []
    for gid, platform, name, functions, suffixes, priority in GROUPS:
        prefix = "apps/web/src/" if platform == "web" else "apps/ios/SoloCompass/Views/"
        paths = [prefix + suffix for suffix in suffixes]
        paths.extend({
            "I01": ["apps/ios/SoloCompass/Views/Map/MapCoordinatePresentation.swift"],
            "I14": ["apps/ios/SoloCompass/Views/Companion/CompanionMapLayer.swift", "apps/ios/SoloCompass/Views/Companion/Components/AvatarStack.swift"],
            "I22": ["apps/ios/SoloCompass/App/SoloCompassApp.swift"],
        }.get(gid, []))
        additions = [addition for addition in CURRENT_SOURCE_GROUP_ADDITIONS if gid in addition["group_ids"] and addition["path"] in present_paths]
        members = [c["id"] for c in candidates if c["source"]["path"] in paths]
        for addition in additions:
            paths.append(addition["path"])
            members.extend(c["id"] for c in candidates if c["source"]["path"] == addition["path"] and (not addition.get("screens") or c["screen"] in addition["screens"]))
        paths = list(dict.fromkeys(paths))
        marketing_scopes = {
            "W01": {"MarketingNav"}, "W02": {"Hero", "Footer"},
            "W03": {"MarketingNav", "Pricing", "Footer"},
            "W04": {"MarketingNav", "Footer"}, "W05": {"MarketingNav", "Footer"}, "W06": {"MarketingNav", "Footer"},
        }
        if gid in marketing_scopes:
            section_path = "apps/web/src/components/marketing/sections.tsx"
            members = [cid for cid in members if next(c for c in candidates if c["id"] == cid)["source"]["path"] != section_path]
            members.extend(c["id"] for c in candidates if c["source"]["path"] == section_path and c["screen"] in marketing_scopes[gid])
        analysis = dict(zip(("taste", "perception", "click_feedback", "interaction", "border_attention"), GROUP_DESIGN[gid].split("|")))
        groups.append({"id": gid, "platform": platform, "screen_or_route": name, "functions": functions, "source_paths": paths, "candidate_ids": list(dict.fromkeys(members)), "source_group_additions": additions, "priority": priority, "assessment": analysis, "assessment_ref": BASELINE, "verification_status": "source_reviewed_runtime_not_verified", "score": None})
    return groups


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--working-tree", action="store_true")
    parser.add_argument("--ref", default=BASELINE)
    parser.add_argument("--output-dir", type=Path, default=OUT, metavar="DIR", help="输出inventory.md/json的目录；省略时沿用脚本所在目录。工作树快照请指定独立目录以保留固定基线。")
    args = parser.parse_args()
    output_dir = args.output_dir.expanduser().resolve()
    diagnostics = []
    ref = "working-tree" if args.working_tree else git("rev-parse", args.ref).strip()
    if args.working_tree:
        files = sorted(str(p.relative_to(ROOT)) for base in (ROOT / "apps/web/src", ROOT / "apps/ios/SoloCompass/Views", ROOT / "apps/ios/SoloCompass/App") for p in base.rglob("*") if p.is_file() and p.suffix in {".tsx", ".swift"})
        read = lambda path: (ROOT / path).read_text()
    else:
        files = sorted(path for path in git("ls-tree", "-r", "--name-only", args.ref, "apps/web/src", "apps/ios/SoloCompass/Views", "apps/ios/SoloCompass/App").splitlines() if path.endswith((".tsx", ".swift")))
        read = lambda path: git("show", f"{args.ref}:{path}")
    localized = localizations(read, diagnostics)
    candidates = []
    coverage = []
    for path in files:
        source = read_optional(read, path, diagnostics, "ui_candidates")
        if source is None:
            coverage.append({"platform": "ios" if path.endswith(".swift") else "web", "path": path, "source_sha256": None, "lines": None, "candidate_count": 0, "category_counts": {}, "review_status": "unavailable_not_zero_controls", "zero_candidate_note": "文件不可读取；不能认定没有交互。"})
            continue
        rows = swift_candidates(path, source, localized) if path.endswith(".swift") else web_candidates(path, source)
        platform = "ios" if path.endswith(".swift") else "web"
        for row in rows:
            row["id"] = ("IC" if platform == "ios" else "WC") + "-" + hashlib.sha1(f"{path}:{row['source']['line']}:{row['control']}".encode()).hexdigest()[:10]
            row["source"]["ref"] = ref
        candidates.extend(rows)
        coverage.append({"platform": platform, "path": path, "source_sha256": hashlib.sha256(source.encode()).hexdigest(), "lines": len(source.splitlines()), "candidate_count": len(rows), "category_counts": dict(collections.Counter(row["category"] for row in rows)), "review_status": "scanned_source_not_runtime", "zero_candidate_note": "仅视觉/包装/静态页面/调用组件；不表示页面没有交互" if not rows else None})
    groups = manual_groups(candidates, files)
    assigned = {c for group in groups for c in group["candidate_ids"]}
    if any(row["id"] not in assigned for row in candidates):
        diagnostics.append({"parser": "manual_function_groups", "path": None, "status": "manual_review_required", "detail": "当前有新增/移动控件未归入基线人工分组；完整候选仍保留，不能宣称人工归并完整。"})
    for row in candidates:
        row["function_group_ids"] = [group["id"] for group in groups if row["id"] in group["candidate_ids"]]
        row["priority"] = "P1" if any(g["priority"] == "P1" and row["id"] in g["candidate_ids"] for g in groups) else "P2"
        if row["category"] == "presentation_edge":
            row["counting_note"] = "导航/呈现关系，不是额外一个用户按钮；其内容控件独立列出"
        elif row["category"] == "custom_component_call":
            row["counting_note"] = "复用组件实例/调用点；勿与底层 renderer Button 相加作为运行时按钮总数"
        else:
            row["counting_note"] = "源码候选；循环、条件、helper 复用均影响运行时数量"
    metadata = {"title": "Solo Compass Web/iOS 交互清单", "snapshot_date": "2026-10-16", "source_ref": ref, "baseline_ref": BASELINE, "method": "固定 Git 源码、去注释和 Swift #Preview、语义控件/手势/呈现声明/动态地图事件提取 + 人工产品功能归并", "is_runtime_button_count": False, "runtime_verified_by_this_inventory": False, "candidate_count": len(candidates), "candidate_counts_by_platform": dict(collections.Counter(c["platform"] for c in candidates)), "category_counts": dict(collections.Counter(c["category"] for c in candidates)), "manual_function_group_count": len(groups), "scanned_files": len(coverage), "unassigned_candidates": [c["id"] for c in candidates if c["id"] not in assigned], "limitations": ["源码扫描不穷举所有运行时动态实例、地图引擎内建 UI、系统菜单和分享/权限面板。", "候选 action/state/label 是局部提取的源码证据；复杂 label helper、条件局部变量和上层 callback 需沿调用链确认。", "同一个可复用控件的 renderer 与调用点、以及父 sheet 与内容按钮会分别列出，不能直接相加为按钮数。", "未用 Simulator、真实账号、StoreKit、摄像头或后端执行各个候选；评分不得据此宣称达到 96。", "Markdown 中所有行号属于 source_ref；并行修改后须 --working-tree 重跑并补运行时验收。"], "state_matrix_required": ["default", "pressed/focused", "selected", "disabled/reason", "loading/cancel", "success/undo", "error/retry", "empty/offline", "VoiceOver/keyboard", "Dynamic Type/compact", "dark/reduce-motion", "locale EN/ZH"]}
    route_compositions = []
    for path in files:
        if path.startswith("apps/web/src/app/") and path.endswith("/page.tsx"):
            source = read_optional(read, path, diagnostics, "route_compositions")
            if source is None:
                continue
            components = list(dict.fromkeys(re.findall(r"<([A-Z]\w*)\b", mask_comments(source, True))))
            route_compositions.append({"route": web_screen(path, ""), "source_path": path, "component_names_in_source": components, "direct_candidate_ids": [c["id"] for c in candidates if c["source"]["path"] == path], "note": "组件名来自该页面模块；内部 helper 及共享组件的候选在各自源文件，单页零直接候选不等于零按钮。"})
    result = {"metadata": metadata, "function_groups": groups, "route_compositions": route_compositions, "resolved_marketing_instances": resolved_marketing_controls(read, diagnostics), "resolved_web_data_instances": resolved_web_data_instances(read, diagnostics), "baseline_findings": baseline_findings(), "visual_audits": visual_audits(read, ref, diagnostics), "source_files": coverage, "candidates": candidates}
    metadata["parsing_diagnostics"] = diagnostics
    metadata["parsing_status"] = "partial_or_manual_review_required" if diagnostics else "parsed_source_only"
    metadata["design_assessment_ref"] = BASELINE
    metadata["manual_source_group_additions"] = [addition for addition in CURRENT_SOURCE_GROUP_ADDITIONS if addition["path"] in set(files)]
    metadata["output_dir"] = str(output_dir)
    if args.working_tree:
        metadata["working_tree_head"] = git("rev-parse", "HEAD").strip()
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "inventory.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    render_markdown(result, output_dir)
    print(json.dumps({"source_ref": ref, "files": len(coverage), "candidates": len(candidates), "platforms": metadata["candidate_counts_by_platform"], "groups": len(groups), "unassigned": len(metadata["unassigned_candidates"]), "output_dir": str(output_dir), "parsing_diagnostics": len(diagnostics)}, ensure_ascii=False))


def escape(value):
    if value is None:
        return "不可解析（待人工确认）"
    return str(value).replace("|", "\\|").replace("\n", " ")


def label_text(row):
    label = row["labels"]
    if row["platform"] == "ios":
        labels = label["zh-Hans"] or label["literal_candidates"] or label["symbols"]
        return " / ".join(labels[:5]) or "动态 label/无显式名称：需复核"
    return compact(label.get("accessible_name_source") or label.get("rendered_text_source") or "动态/仅图形：需复核", 140)


def render_markdown(data, output_dir=OUT):
    meta = data["metadata"]
    rows = ["# Web / iOS 全量源码交互清单", "", f"源码快照：`{meta['source_ref']}`；设计判断基线：`{meta.get('design_assessment_ref', BASELINE)}`；盘点日期：2026-10-16。", "", f"扫描 **{meta['scanned_files']} 个 UI 源文件**，得到 **{meta['candidate_count']} 个源码交互候选**（Web {meta['candidate_counts_by_platform'].get('web', 0)}、iOS {meta['candidate_counts_by_platform'].get('ios', 0)}），使用 **{meta['manual_function_group_count']} 个基线产品功能组**归并，仍有 **{len(meta['unassigned_candidates'])} 个候选待人工归组**。这些数字都不是实际渲染按钮总数。", "", "## 如何使用与审查边界", "", "每个候选包含 route/screen、control、label、action、states、`source:line`、动态/条件标记、优先级与未验证状态。JSON 保存完整源码摘录和机器字段；下面保留逐文件覆盖和逐候选索引。", "", "- `semantic_control`：Button / NavigationLink / Link 等语义控件。", "- `input_control`：输入、选择、切换等控件，包含键盘提交。", "- `gesture_or_semantic_control`：手势、可点击非语义容器与可访问性动作。", "- `presentation_edge`：sheet / alert / menu 等导航和呈现关系，不应另计为一个按钮。", "- `custom_component_call`：复用组件具体调用点，应与底层 renderer 联合核实，避免双算。", "- `runtime_map_control` / `imperative_event_handler`：地图动态 marker、定位、缩放及手工事件。", "", "已排除注释和 Swift `#Preview`。循环项目、菜单选项、条件可见性、SDK 控件随数据或环境变化；函数分组是能力目录，单组可包含多按钮，单控件也可能进入多个流程。所有运行时验收目前都标为 `not_verified`，不能将源码静态审查包装成每项 96 分。", "", "## 解析诊断", "", "无法解析或已改变结构的字段不会套用旧文案/链接；这里只列当前可提取的源码，空列表不等于没有该功能。", ""]
    if meta.get("parsing_diagnostics"):
        rows.extend(["| 解析器 | 路径 | 状态 | 说明 |", "|---|---|---|---|"])
        for diagnostic in meta["parsing_diagnostics"]:
            rows.append(f"| {escape(diagnostic['parser'])} | {escape(diagnostic.get('path'))} | {escape(diagnostic['status'])} | {escape(diagnostic['detail'])} |")
    else:
        rows.append("本次支持的静态结构未产生解析错误；这不代表运行时功能已验证。")
    rows.extend(["", "## 设计判断口径", "", "遵循 `frontend-design`：旅行的地图、真实体验和当前决策承担主体表达；色彩、边界和图案服务状态与信息层级。主动作只保留一个视觉重心；次级导航有稳定位置；触摸/键盘/VoiceOver 能到达相同动作；反馈说明动作结果；失败/空态有下一步；动效回应用户且尊重减少动态。", "", "每组都需要核实默认、按下/焦点、选中、禁用原因、加载/取消、成功/撤销、失败/重试、空态/离线、键盘/VoiceOver、大字号/小屏、深色/减少动态、中英文本。局部源码出现状态变量仅表示已发现实现线索。", "", "## 人工归并的产品功能目录", "", "| ID | 平台 / route 或 screen | 控件与功能 | 优先级 | 源级候选 |", "|---|---|---|---|---|"])
    for g in data["function_groups"]:
        rows.append(f"| {g['id']} | {g['platform']} · {escape(g['screen_or_route'])} | {escape(g['functions'])} | {g['priority']} | {len(g['candidate_ids'])} |")
    if meta.get("manual_source_group_additions"):
        rows.extend(["", "## 本轮新增组件的人工归组", "", "这里只补充已核对的源码归属；不修改起始基线设计判断，也不据此宣布体验已通过。", "", "| 当前新增源文件 | 功能组 | 调用来源 | 归组依据 |", "|---|---|---|---|"])
        for addition in meta["manual_source_group_additions"]:
            binding_sources = addition.get("binding_sources") or [addition.get("binding_source", "不可解析（待人工确认）")]
            rows.append(f"| `{addition['path']}` | {', '.join(addition['group_ids'])} | {escape(' / '.join(binding_sources))} | {escape(addition['reason'])} |")
    rows.extend(["", "## 逐组设计分析", "", "以下保留起始基线的设计建议，未因重新扫描而自动升级为当前结论；控件变化需人工复核，观感、动效、触摸成功率仍需运行时验收。", "", "| ID / 功能组 | 品味与用户观感 | 点击反馈与交互逻辑 | 边框与注意力 |", "|---|---|---|---|"])
    for g in data["function_groups"]:
        a = g["assessment"]
        rows.append(f"| {g['id']} · {escape(g['screen_or_route'])} | {escape(a['taste'])}；{escape(a['perception'])} | {escape(a['click_feedback'])}；{escape(a['interaction'])} | {escape(a['border_attention'])} |")
    rows.extend(["", "## 优先处理的20个基线发现", "", "`Q01–Q18`与`Q20`是已核对源码的功能/语义/输入/色值问题，仍需复现和修复后验收；`Q19`明确是待视觉验证的设计风险。这里保留起始基线，不能据此认定当前并行修改仍有同一问题，也不能自动标记已修复。独立审查报告可以包含其他发现。", "", "| ID / 优先级 | 问题与证据 | 建议与验收 | 基线 source:line |", "|---|---|---|---|"])
    for finding in data["baseline_findings"]:
        rows.append(f"| {finding['id']} · {finding['priority']} | **{escape(finding['title'])}**：{escape(finding['evidence'])} | {escape(finding['recommendation'])} 验收：{escape(finding['acceptance'])} | `{finding['source']['path']}:{finding['source']['line']}` |")
    rows.extend(["", "## 官网图案与跨端视觉细节", "", "图案不是按钮，单列审查。以下观察与建议源于起始基线；重跑可更新源码定位，仍须根据实际修改复核结论。CSS/token为补充视觉源，不计入上面的UI候选数。", "", "| ID / 对象 | 观察与品味判断 | 运行时验收 | source:line |", "|---|---|---|---|"])
    for visual in data["visual_audits"]:
        rows.append(f"| {visual['id']} · {escape(visual['subject'])} | {escape(visual['observation'])} | {escape(visual['runtime_acceptance'])} | `{visual['source']['path']}:{escape(visual['source']['line'])}` |")
    rows.extend(["", "## 官网 EN / ZH 数据驱动链接展开", "", "以下只列当前源码可解析的标签与href表达式，不执行表达式、不假定下载常量名称或最终落点；缺字段见解析诊断。它们是上述候选的实例说明，不能另加到候选数。", "", "| 实例 / 语言 | 位置 | label | target源码表达式（未执行） |", "|---|---|---|---|"])
    for r in data["resolved_marketing_instances"]:
        rows.append(f"| {r['id']} · {r['locale']} | {escape(r['component_path'])} | {escape(r['label'])} | `{escape(r['target_source'])}` |")
    rows.extend(["", "## Web route 与组件组合", "", "| route | 页面模块 | 组件集合（含本模块 helper） |", "|---|---|---|"])
    for r in data["route_compositions"]:
        rows.append(f"| `{r['route']}` | `{r['source_path']}` | {escape(', '.join(r['component_names_in_source']))} |")
    web_data = data["resolved_web_data_instances"]
    rows.extend(["", "## 城市 / 分类 / 体验 / 行程动态实例", "", f"当前已解析静态数据为{len(web_data['cities'])}个城市、{len(web_data['categories'])}个分类、{len(web_data['experiences'])}个体验、{len(web_data['trips'])}个回顾行程，解析状态：`{web_data.get('parse_status', 'unknown')}`。空列表/缺字段不能推断功能消失；下列路径只是数据实例的路由模式，当前控件是否绑定仍需沿候选核实。/app后端数据和原生持久层数量由环境决定。", "", "| 类别 / ID | 中文 / English | 数据候选或路由模式 |", "|---|---|---|"])
    for city in web_data["cities"]:
        rows.append(f"| 城市 · {escape(city['slug'])} | {escape(city['zh'])} / {escape(city['en'])} | `{escape(city['href'])}` |")
    for cat in web_data["categories"]:
        rows.append(f"| 分类 · {escape(cat['id'])} | {escape(cat['zh'])} / {escape(cat['en'])} | {escape(cat['action'])} |")
    for exp in web_data["experiences"]:
        rows.append(f"| 体验 · {escape(exp['id'])} | {escape(exp['zh'])} / {escape(exp['en'])} | 基线路由模式 `{escape(exp['detail_href'])}`，当前绑定未确认 |")
    for trip in web_data["trips"]:
        rows.append(f"| 行程 · {escape(trip['slug'])} | {escape(trip['zh'])} / {escape(trip['en'])} | 基线路由模式 `{escape(trip['href'])}`，当前绑定未确认 |")
    rows.extend(["", "## 逐文件覆盖", "", "候选为零的文件仍列出：静态页面会通过公共导航/CTA 获得交互，纯视觉组件也属于图案与注意力审查范围。", "", "| 文件 | 行数 | 候选 | 类别 |", "|---|---:|---:|---|"])
    for f in data["source_files"]:
        cats = ", ".join(f"{key}: {count}" for key, count in f["category_counts"].items()) or "无直接候选；检查调用组件"
        rows.append(f"| `{f['path']}` | {escape(f['lines'])} | {f['candidate_count']} | {escape(cats)} |")
    rows.extend(["", "## 逐项源码清单", "", "所有候选运行时状态均为 **未验证**。`动态`表示条件/循环/绑定线索；表内 action 是源码动作摘录，复杂 callback 仍需沿调用方确认。标签列可能列出复合控件内部的多个名称，机器清单保留可区分的 label 来源。", ""])
    last_path = None
    for c in data["candidates"]:
        if c["source"]["path"] != last_path:
            last_path = c["source"]["path"]
            rows.extend(["", f"### `{last_path}`", "", "| ID / screen / 控件 | label | action | states | source:line / 优先级 |", "|---|---|---|---|---|"])
        rows.append(f"| {c['id']} · {escape(c['screen'])} · {c['control']} {'· 动态' if c['dynamic_or_conditional'] else ''} | {escape(label_text(c))} | {escape(compact(c['action'], 180))} | {escape('; '.join(c['states'])[:200])} | `{c['source']['path']}:{c['source']['line']}` · {c['priority']} |")
    rows.extend(["", "## 未覆盖与验收要求", ""])
    rows.extend(f"- {note}" for note in meta["limitations"])
    rows.extend(["", "重复生成固定基线清单：", "", "```bash", "python3 docs/design/interaction-quality/generate_inventory.py", "```", "", "将交付中的工作区另存独立目录（保留固定基线）：", "", "```bash", "python3 docs/design/interaction-quality/generate_inventory.py --working-tree --output-dir docs/design/interaction-quality/current", "```", ""])
    (Path(output_dir) / "inventory.md").write_text("\n".join(rows))


if __name__ == "__main__":
    main()
