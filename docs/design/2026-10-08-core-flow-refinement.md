# Solo Compass 核心流程精调

日期：2026-10-08。当前交付：TestFlight 真实采集来源、10 个可编辑现状页面与 12 个 iPhone 精调状态已在 Figma 分区建立，并保存完整本地副本。采集来源是 Mac 兼容窗口；尚未完成 iPhone 真机逐屏对照、Dynamic Type 验收或云端同步。用户授权：新建设计项目、还原核心页面、精调页面展示与流程，并清理过时代码样式；没有将精调稿发布为新 TestFlight 构建。

### TestFlight 与 Figma V2 交付（2026-10-08）

- 已安装、启动并读回 TestFlight `0.1.305 (1570)`；用户明确同意后接受首次使用条款，选择 Browse first / 跳过可选引导。没有授予定位或麦克风权限，没有购买订阅，没有发送聊天或创建真实行程。
- 实际环境为 iOS 应用在 Mac 兼容模式下的 `1024×800` 窗口。原始截图与 AX 覆盖引导、地图 All / Now、Pro、预览、详情、操作说明、空行程、新行程表单、AI 未配置及 Discover；不能标记为物理 iPhone 实屏。
- [Figma 文件](https://www.figma.com/design/6kgoI04LJ1gbF5WWHNCNZF)：`7:55`「00 · TestFlight AS-IS / 0.1.305 (1570)」包含 10 个原始截图对照板与 10 个可编辑页面；`7:56`「01 · UI 精调 / TO-BE」包含 12 个 `390×844` iPhone 提案、来源注释、总览和 3 个复用工作区组件。旧 27 屏保留在「90 · 概念流程草稿 / 非 TestFlight 还原」。
- 现状页使用 Inter 近似 SF，地图通过原始 MapKit 截图区域在 Figma 原生容器内裁切，镜头并非逐像素一致。以每页旁边的原始截图为现状视觉证据；页面控件、文字及布局为可编辑节点。
- 精调主线：地图 → 预览 → 详情 / 来源 → 收藏或加入行程 → 导航选择。保留 Map / Ask Solo / Discover 工作区；将未配置 AI 的诊断移至聊天分支；详情提前呈现时长、可信度与不便。加入行程成功、收藏列表、AI 候选和导航后续均标注为提案，没有冒充本轮实际成功操作。
- 读回验证：22 页导出检查；新增图结构 1053 个节点；201 条原型连线目的地有效；精调稿带连线的可点击区域全部达到 44pt；没有发现意外裁切，长文本重叠已修复。这些是 Figma 静态与结构验证，不能代替运行时验收。
- 收藏入口实际崩溃：点击 Discover 的 Saved places 后进程退出；系统日志显示 `EXC_BREAKPOINT / SIGTRAP`，栈涉及 SwiftUI `EnvironmentValues.subscript.getter` 与 `_assertionFailure`。确切缺失的 environment 尚未符号化确认，未宣称修复。聊天实屏显示 `Chat is not configured yet`，没有采集成功 AI 推荐。
- Figma 明确提示未同步，本轮使用本地 Figwright 完成写入。已通过原生 Save Local Copy 保存完整 V2 `.fig`，大小 `6,429,202` bytes，SHA-256 `f9a65d0da1a58bb8d09919bf8195de8ba2fd3a527ab4e6981c46f662b308df02`。文件保持打开，等待恢复连接后同步；不能把本地写入视为云端完成。
- 永久证据目录：`/Users/cubxxw/.codex/visualizations/2026/10/08/01a11945-2562-7a60-b1da-5748f3dcbc43/solo-compass-core/`。`testflight/` 保存原始截图、AX 和崩溃摘要；`v2-screenshots/` 保存 22 页导出；`v2-validation.json` 为读回结果；`SoloCompass-TestFlight-V2-20261008.fig` 为包含本轮 22 页的完整备份。
- 代码清理独立保存在 `codex/pi-20261008-130717-7c592093`、commit `ef4db932`：移除已确认未使用的旧样式/helper 与 BilingualCityRow，项目引用同步更新。局部类型检查与 plist 验证通过；尚未提交 PR、合并或做整个 App 构建。不能据此声称整套 UI 已按精调稿落地。

以下第 1–4 节保留早期源码和概念分析背景；现状依据以本节、AS-IS 原始截图和 V2 提案注释为准。

## 1. 结论与依据

优先设计「地图发现 → 体验判断 → 保存 / 规划 → 出发 → 完成反馈」，Solo 对话可在发现和判断时介入。地图保持默认首页；真实版本已有 Map / Ask Solo / Discover 工作区，V2 沿用此结构。

“60%”是设计选取目标，不是已验证数据。当前没有读取真实用户分析报表。`InteractionTracker.swift` 保存会话事件；`AnalyticsService.swift` 保存本机缓冲，当前实现未提供跨用户汇总。因此不声称某模块被 60% 用户使用，也不把预估比例相加伪装覆盖率。

| 优先级 | 模块 | 判断理由 | 设计处理 |
|---|---|---|---|
| P0 | 地图、定位、此刻 / 全部筛选、附近列表 | 默认入口，承担发现与比较，贯穿整个旅途 | 三个 sheet 高度；选中 pin 与列表联动；地图区域保留 |
| P0 | 体验预览、详情、来源与不便 | 每次决定要不要去都会经过，且真实性是产品差异 | 首屏呈现做什么、时机、距离、时长、独行理由、不便、可信度；细节下沉 |
| P1 | Solo 对话、结构化推荐、地图回流 | 意图表达和解释入口，频率尚未量化 | 保留全局与体验上下文入口；显示候选卡；明确应用到地图 |
| P1 | 收藏、加入行程、路线详情 | 连接探索与执行，支持中断后继续 | 收藏与行程分开；即刻反馈；保留回看和撤销 |
| P1 | 活跃路线、完成 / 跳过 / 暂停 | 用户在途时反复使用，属于任务关键环节 | 下一站、剩余距离、明确控制；跳过不算完成 |
| P2 | 结束反馈 | 频率低于发现但闭环关键 | 轻量完成确认，反馈可跳过 |
| P2 | 城市选择、定位拒绝、空结果、离线、AI 失败 | 不是高频目的，但会阻断所有高频操作 | 一屏一个主要恢复动作，允许手动城市浏览 |
| 扩展 | 同伴、消息、城市 Kit / Live、Today、回忆 / 胶囊 | 存在代码但部分受功能开关控制；没有高频证据 | 独立扩展分支，不挤占默认首页 |

数据验证口径：用户覆盖率 = 在观察窗口内至少进入核心模块集合一次的独立活跃用户数 / 全部独立活跃用户数；操作覆盖率 = 核心集合内去重有效操作数 / 全产品去重有效操作数；时间覆盖率 = 核心集合前台有效停留时长 / 全产品前台有效停留时长。三种口径分开统计，排除后台导航时长、自动曝光与重复触发；按新 / 老用户、城市、功能开关版本分组。只在已有隐私许可内评估，原始坐标、用户文本不进入分析。

## 2. 现状证据与展示问题

- `CompassMapView.swift` 是默认 root；地图叠加筛选、sheet、选中体验、路线状态、City OS 与 Solo 入口。页面复杂度来自同时竞争同一地图空间，而非缺少模块。
- `BottomInfoSheet.swift` 支持 peek / mid / full；`PeekSummaryCard.swift` 的卡片主体点击先展开附近列表，`NearbyExperienceRow.swift` 点击直接到详情。相近视觉对应不同结果。现状还原保留该行为；提案改为卡片主体统一到详情，列表使用独立「查看附近」入口。
- `ExperienceDetailView.swift` 按 hero、highlights、corrections、why、how-to、inconveniences、traveler notes、best times、solo score、location、AI insight、opening hours、sources、nearby 顺序渲染。用户最需要的行动信息分散。精调首屏把时间、事实状态、独行理由和不便靠近标题，并保留详细信息入口。
- `FilterBarView.swift` 混合筛选和 Ask Solo 行为，并有横向溢出。现状还原保留；精调把筛选与启动对话分开，减少「此刻」既是过滤又可能启动智能体的歧义。
- `RouteDetailView.swift` 与 `ItineraryDetailView.swift` 是不同对象：路线用于连续执行，行程用于计划；不能在设计稿中合并成同一数据模型。
- `FeatureFlags.swift`：Today 默认关闭；Companion、City OS 在 Debug 和 Release 默认值不同。`Resources/FeatureFlags.plist` 中 backendSync、companion、companionLayer 关闭。可见源码不能证明发布环境开启这些能力。
- 本次只阅读已有 QA 截图作为视觉参考；截图显示一个历史空结果场景，不代表当前完整 UI 或真实用户统计。地图底图在提案中是可编辑示意图，非导航数据。

## 3. 页面内信息结构

1. 地图首屏：城市 / 所在位置 → 筛选 → 可探索地图 → 此刻卡片。常驻操作保留定位、查看附近与 Ask Solo。路线执行时由路线面板接管底部位置。
2. 列表行：体验动作标题 → 独行理由 → 时长 / 距离 / 事实状态。选中 pin 使用相同标题；不能仅用颜色表达状态。
3. 详情首屏：体验标题 → 时间 / 时长 / 费用 → 独行理由 → 已知不便 → 来源强度与更新时间 → 主要行动。营业未知与最佳时机分开，不以最佳时机推断开门。
4. 对话：用户意图 → 筛选条件 → 至多三个候选与理由 → 详情 / 地图入口。AI 不直接替用户开始路线；事实缺失明确标注，不补造营业时间或费用。
5. 路线执行：下一站 → 进度 → 导航 / 到过了 → 暂停 / 跳过。定位不可用时不宣称「已到达」，保留手动确认。

字体：原生使用系统 SF 默认 / Rounded / Monospaced；Figma 中文使用已确认存在的 PingFang SC，并标注 SF 的对应角色。颜色来源 `CompareTokens.swift`，间距 / 圆角 / 动效来源 `DesignTokens.swift`。暖底 #FAF8F6、正文 #1F1A14、次正文 #6D6358、主行动 #5D3000、此刻 #C9A677。控件目标至少 44pt；长中文和大字体允许换行；有文本状态而非纯颜色；Reduced Transparency 使用实色面板；Reduced Motion 禁止装饰弹跳。

## 4. 流程与页面目录

主流程：R01 地图 → R02 附近列表 / R03 体验预览 → R04 详情 → R05 导航选择 / R06 收藏；连续路线分支为 R08 路线详情 → R09 在途 → R10 完成。单体验导航不会自动进入多站路线。

对话分支：R01 / R04 → R11 Solo 空态 → R12 候选 → R13 地图回流 → R04。体验上下文对话保留当前体验，关闭后返回原选中项。

规划分支：R04 → R07 加入行程 → R22 行程审阅；需要连续步行时另行进入 R08 路线审阅 → R09。收藏 R06 可再次进入 R04。事实核对分支：R04 → R21 来源与事实 → R04 / R02。

筛选分支：R01 / R02 / R03 / R13 → R24 筛选条件 → R02 候选；筛选与 Ask Solo 分开，顶部此刻 / 全部 / 收藏提供直接入口。

恢复分支：R01 → R14 城市；定位拒绝 R15 → 手动城市；空结果 R16 → 扩大范围 / 清除筛选；AI 失败 R17 → 原始候选 / 重试；离线 R18 → 本地收藏；数据稀疏 R19 → 有限事实与核对。

扩展分支：R20 同伴路线详情，要求功能开关开启；默认不呈现在线人数或招募成功保证。Today 为待决实验，未改变默认首页。

现状结构还原：B01 地图 peek、B02 附近 full、B03 体验详情信息顺序、B04 Solo 对话卡片。它们保留代码结构和关键行为，但不是逐像素截图复刻；示例内容和地图均为设计占位。

## 5. 原型验收

- 每张精调页面标明页面 ID、来源、主行动和返回点；示例体验、距离、时间、价格与来源状态统一标记为演示，不可当成真实推荐。
- 点卡片有明确去向；收藏、加入行程、取消、回地图、返回上一层不丢选中体验。
- 详情没有来源时显示未核验；定位拒绝时距离 / 到达不伪报；营业未知不显示正在营业；AI 失败仍保留本地能力。
- Figma 必须是可编辑 text / frame 层级，布局容器使用 auto-layout，主要按钮建立 prototype reactions。不得把整屏 PNG 当交付。
- 先核对 Figwright 连接文件名与新文件 URL，再写入；不能把 Solo Compass 页面写到当前 Daypage 文件。
- 本地预览验证的是页面与跳转内容；只有 Figma 写入读回及截图通过后，才能宣称 Figma 完成。

## 6. 已完成的交付与验证

- [Figma 文件：Solo Compass · 核心流程精调](https://www.figma.com/design/6kgoI04LJ1gbF5WWHNCNZF)，页名已更正为 `90 · 概念流程草稿 / 非 TestFlight 还原`。总览提供发现、判断、安排、出发、完成五个入口，提案与现状区分排布。
- [从地图进入原型](https://www.figma.com/proto/6kgoI04LJ1gbF5WWHNCNZF?node-id=1-14)：27 张手机页面，23 张精调 / 恢复状态与 4 张现状结构还原；节点为原生可编辑 frames 与 texts，包含共享颜色样式、auto-layout 内容容器和 prototype reactions。
- 最终节点读回：1024 个节点、533 个文本节点、161 个原型交互；目标节点全部存在；容器溢出与内容 / 底部动作重叠检查为 0。按钮最小高度 44pt，主按钮 48pt；返回使用 BACK 保留进入来源。
- 已导出并目视检查全部 27 张 390×844 PNG，以及总览。筛选页写入超时遗留的 4 个重复节点已精确清除，重新读回与导出后通过检查。未启动模拟器、未修改 App 功能代码；此验收针对 Figma 设计与原型。
- 证据目录：`/Users/cubxxw/.codex/visualizations/2026/10/08/01a11945-2562-7a60-b1da-5748f3dcbc43/solo-compass-core/`。`figma-validation.json` 为实际 Figma 读回结果，`final-canvas.json` 为最终节点树，`screenshots/` 为全部页面导出，`contact-1.png` 至 `contact-3.png` 为视觉检查总表，`figma-state.json` 记录页面与真实节点映射。

范围说明：这是现状结构还原与核心流程精调提案；四张 baseline 不是逐像素复刻，地图、体验及事实状态是明确标注的演示内容。“60%”仍是待真实使用数据验证的优先级目标。原型中的筛选、对话、保存和导航为预设状态演示，未连接真实业务服务。

连接恢复记录：云端 Figma MCP Starter 写入额度限制后，改用 Figma 桌面端的新 Draft 与 Figwright 插件完成交付，没有升级或产生付费请求。早期创建的空白文件 `kLeYSoG0ifLuZGqBXwGUVI` 不是交付文件；最终文件为上面的 `6kgoI04LJ1gbF5WWHNCNZF`。

共享补充（2026-10-08）：按用户指令移入 `Team project`（team `1377887350597504361` / project `239182757`），给指定邮箱发送 `can edit` 文件邀请；共享面板已读回 `Invite sent`。面板仅提供 can view / can edit，没有独立文件管理等级；未变更团队管理员权限，未付费升级。证据见永久目录 `sharing-validation.json`。

后续设计来源更正：用户要求真实 TestFlight 基线与精调稿分区对照，后续 UI 以完成实屏核验的 Figma 设计为准。现有页、总览与 B01–B04 已明确标为概念 / 源码结构说明。候选成功上传版本 `0.1.305 (1570)`，commit `02be5314ab06d7c6219a7d3e4c995ec8e7a56390`；本轮已读回并启动该版本。已完成 Mac 兼容模式下的核心采集与可编辑还原，iPhone 真机视觉还原仍待验收。

第一批代码清理已在独立 worktree 完成并由主代理复核：分支 `codex/pi-20261008-130717-7c592093`，提交 `ef4db932`。删除 8 个无引用的样式 / 字体 / modifier / 内部 helper，以及旧 `BilingualCityRow`；XcodeGen 只移除该组件 4 个注册。样式层 iOS SDK 类型检查通过；没有运行完整 App 构建或真实 TestFlight 验收。设计来源政策与清理明细位于该分支 `docs/design/README.md`、`docs/design/2026-10-08-ui-cleanup-audit.md`。源码 checkout 的其他未提交改动保持原样。
