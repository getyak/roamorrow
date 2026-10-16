# 当前 iOS 页面、按钮与交互体验目录

本轮基于 Pi 最终交付合入后的 integration 工作树更新，沿用 `frontend-design`：地图与地点内容优先，文字准确解释操作，边框表达归属和选中，反馈以真实结果为准。下文按 **27 个 iOS 功能族**归并页面、父子入口、按钮/选择控件、状态和返回；[当前逐控件索引](current/ios-controls.md)提供每个源码候选的当前名称、动作、状态、44pt/AX局部声明和精确 `source:line`，可交叉核查。

**计数边界：**当前扫描 **220 个跨端 UI 文件，974 个源码候选（iOS 864 / Web 110），归入44个跨端功能族，未归组0、解析诊断0**。这些候选含父级呈现、子控件renderer、复用调用点和动态实例，绝不是 864 个实际按钮。918为上一轮工作树历史快照；固定基线892候选的 `inventory.md/json` 保持原样。当前机器清单中的设计判断仍指向 `924f09a4`，不能把原建议当当前缺陷。

**源码绑定：**工作树 HEAD 为 `efcb8fc523f59c8333b010c9bc710d8d5b2e4559`，覆盖未提交改动；UI文件路径及各文件SHA-256写在 [current/inventory.json](current/inventory.json) 的 `source_files`。有序UI文件清单SHA-256为 `e3e637fd843eeb38b19e679feff277e0fb58ef6921bb61dd2609fe43538d801a`。本页人工动作核对覆盖下面声明的当前源码；本轮扫描后已核对全部源文件路径与哈希一致，详见 [source-stability.json](current/source-stability.json)；后续源码若变化需重新绑定。本角色未启动模拟器/浏览器、未使用真实账号或StoreKit，不能据源码宣称所有按钮达到96分。主任务的运行证据与独立评分另记。

**路径与定位：**`Views/`、`Services/`、`Persistence/`、`App/`、`Models/` 相对于 `apps/ios/SoloCompass/`。正文文件名是调用链索引；逐控件精确行号以本轮生成索引为准，避免把历史行号当新代码。后文少量明确行号是本轮实际读取位置。

**状态口径：**`source_fixed`表示已核对源码修正，不等于运行通过；`not_verified`表示本角色未实测；`flag`为开关/身份/数据条件路径；`offline`为仅本地或网络失败边界；`mock`为示意/只读预览；“未挂载”表示未发现生产调用；系统地图、键盘、权限、相册、相机、分享、登录和支付UI不穷举内部动态按钮。下文不把这些标签本身当bug。

## 实际挂载与验证边界

| 范围 | 当前定位 | 不能混淆的内容 |
| --- | --- | --- |
| 默认首页 | `TodayContainer` 在 `todayHome=false` 时进入 `CompassMapView`；地图、对话、发现是稳定工作面。 | `TodayContainer` 出现在 App 根不等于 Today 页面默认启用。`Views/Today/TodayContainer.swift`。 |
| 首次使用 | 条款门槛、引导步骤及可跳过的偏好/照片步骤；随后到地图。 | 系统权限弹窗与本应用按钮分别验收；不能把拒绝权限当接受条款。 |
| 同行/后台功能 | 受 `companion`、`backendSync`、用户可见性、同意与登录等条件影响。 | Release plist 默认关闭部分功能；本地交互、真实远端写入和演示数据不是同一验收。`Services/FeatureFlags.swift`。 |
| 路线同行实际执行者 | `backendSync=false` 使用 `LocalRouteCompanionRemote`，申请/审批/完成写本机SwiftData；这不是跨设备远端回执。 | `backendSync=true` 的 `SupabaseRouteCompanionRemote` 尚未实现：DEBUG操作抛NotImplemented，非DEBUG构造会preconditionFailure。不能把开开关当接入远端。`Services/RouteCompanionRemote.swift`；`LocalRouteCompanionRemote.swift`；`SupabaseRouteCompanionRemote.swift`。 |
| City OS / Today | 城市模式、基地、工具包、活动、印证和 Today 是开关/数据条件路径。 | 开关关闭时不应把它们算默认首页入口；开关开启后仍需检验完整回调。 |
| 归档仪式中心 | 当前多种卡片是明确预览/只读记录，容器将内部内容 `.disabled(true)`，真实主动作是关闭。 | 盲盒“开启”、解锁、分享、壁纸等内部卡片字样不能被当作现有可执行产品功能。`Views/Archive/ArchiveView.swift`。 |
| 真实时光胶囊编辑 | 体验详情长按标题区可打开 `CapsuleComposeView`，成功写入 CapsuleStore 才关闭。 | 与归档里的只读胶囊/预览卡不同。 |
| 共享组件与系统 UI | 自定义按钮/卡片只在实际调用方中出现；系统返回、地图引擎控件、键盘、相册、相机、分享、Apple 登录和付款界面由系统生成。 | 机器清单覆盖源码，不自动证明每个独立组件都挂载；系统内动态按钮不计入静态源码总数。 |

## 本轮修复回读与当前剩余项

IF01～IF29为先前读取时的问题编号，下面用当前源码重新核对。`source_fixed / not_verified`不是审查分数，也不替代保存失败注入、系统UI和辅助技术实测；原始基线问题仍保留在旧清单及审查报告，不在本页重复写成当前缺陷。

| 编号 | 当前源码结果 | 当前依据 |
| --- | --- | --- |
| IF01 | `source_fixed`：路线收藏写 UserPreferences 独立route-id命名空间；加入行程打开真实选择器，保存整条路线站点并读回行程名称。 | `RouteDetailView.swift` isFavorited / refreshItineraryReadBack / bottomDock；`UserPreferences.swift` routeFavorites；`AddToItinerarySheet.swift`。 |
| IF02 | `source_fixed`：缺外部站点callback时内部进入ExperienceDetail；非地图开始路线发统一请求，地图收起Me/设置/路线及对话面再绘路线。 | `RouteDetailView.swift` stopDetailExperience / primaryCTA；`Services/RouteNavigationRequest.swift`；`CompassMapView.swift` didRequestStart。 |
| IF03 | `source_fixed`：群聊按真实conversation及参与权限可用，否则准确禁用；完成确认与回放有不同名称、独立入口。 | `RouteDetailView.swift` chatAccess / primaryCTA / completionReplayRow；`Models/RouteChatAccess.swift`。 |
| IF04 | `source_fixed`：发现空态创建页只取真实同城候选，兼容城市别名；没有城市或同城候选时不跨城填充，而是发城市选择请求，等原呈现关闭后打开地图真实城市选择器。有候选时throwing保存后才开新路线详情。 | `DiscoverRecruitingRoutesView.swift` sameCityCandidates / emptyState；`RouteNavigationRequest.swift` requestCitySelection；`CompassMapView.swift` consumePendingCitySelection。 |
| IF05 | `source_fixed`：反馈保存本机草稿，用户自行发邮件/分享副本；保存不说已上报，邮件取消/失败保留草稿。 | `ReportIssueSheet.swift` composeList / deliverList / handleMailResult；`ExperienceReportDraftStore.swift`。 |
| IF06 | `source_fixed`客户端：postId通过专用post-action函数在后端解析author，按saved receipt确认结果，重试保留actionId；实际部署/RLS和跨账号验收另记。 | `DiscoverListView.swift` sendRequest；`CompanionPostActionService.swift`；`infra/supabase/functions/companion-post-action/index.ts`。 |
| IF07 | `source_fixed`：审批有请求锁、错误与重试；远端不可用的本地fallback也先提交route+conversation，失败保留待处理。 | `ApprovalQueueView.swift` accept / decline / commit / fail。 |
| IF08 | `source_fixed`：远端删除失败保留本地好友，返回Result；页面有进行中、可见错误及重试，成功才播报。 | `FriendService.swift` unfriend；`FriendsListView.swift` removeFriend。 |
| IF09 | `source_fixed`创建/招募路径：savePersisted抛错，失败保留草稿、成功才关闭。InviteFriendsSheet也已迁移原子throwing提交，见IF27。 | `RouteStore.swift` savePersisted；`CreateRouteView.swift` save；`OpenForCompanionsSheet.swift` submit。 |
| IF10 | `source_fixed`：生成任务有尝试/草稿版本，离开取消；过期建议不覆盖新编辑，可采用/忽略；生成时不可保存。 | `CreateRouteView.swift` startGeneration / staleSuggestionBanner；`RouteGenerationGuard.swift`。 |
| IF11 | `source_fixed`：会话列表读取失败保留已有摘要，显示错误/重试，首次失败不只展示暂无对话。 | `ConversationListView.swift` loadError / reload。 |
| IF12 | `source_fixed`写入错误：排序失败回滚且可重试，同行切换失败恢复旧状态，导入失败不显示成功。全部收藏已在行程时隐藏导入入口，见IF28。 | `ItineraryDetailView.swift` persistOrder / activateCompanionPost / removeCompanionPost / importFavorites。 |
| IF13 | `source_fixed`：StopsList为Button、有44pt行和可访问名称；编号圆盘用ScaledMetric随Dynamic Type同步变大；配速Picker补可访问名称；候选站点有选中traits与44pt区。 | `Components/StopsList.swift`；`CreateRouteView.swift` pacePicker / candidateRow。 |
| IF14 | `source_fixed`：路线分析明确写不可用，不再显示可购买的解锁承诺；该说明是只读。 | `RouteDetailView.swift` aiInsightUnavailable。 |
| IF15 | `source_fixed`：Today日期/停留天数、昨日胶囊回执均有真实子页，callback不再默认空实现。 | `TodayContainer.swift` activeSheet；`TodayActionSheets.swift`；`TodayStatusHeader.swift`；`TodaySealReceipt.swift`。 |
| IF16 | `source_fixed`：closed路线先确认，再提交，成功才庆祝；失败可重试；completed回放只读，不在onAppear写入。 | `CompletionMoment.swift`；`CompletionMomentFlow.swift`。 |
| IF17 | `source_fixed`：进行中路线跳过/暂停/结束保留30pt视觉，扩44pt命中区。 | `ActiveRouteOverlay.swift`。 |
| IF18～IF20 | `source_fixed`：紧凑Solo分数、弹层六维行、详情展开六维增加44pt局部目标；分数不再持续闪烁。 | `SoloScoreBadge.swift` compactView / dimensionRow；`ExperienceDetailView.swift` soloScoreCard。 |
| IF21 | `source_fixed`：印证明确仅存本机笔记、不改变公开信心；先成功写笔记再markVerified，错误保留答案。 | `VerifySheet.swift` submitButton；`CompassMapView.swift` submitVerification；EN/ZH cityos.verify文案。 |
| IF22～IF23 | `source_fixed`：缺visa内容也显示独立个人倒计时；日期/已确认天数复用显式表单，支持编辑且不推定30天。 | `KitSheet.swift` orderedKit缺visa分支 / VisaComplianceControl；`TodayActionSheets.swift`。 |
| IF24～IF25 | `source_fixed`：CityOS合规处理/关闭、工具包待办/外链、活动地图按钮、基地查看全部、Today关闭均补44pt局部声明；待办读出事项名和状态。 | `ComplianceBanner.swift`；`KitSheet.swift`；`LiveSheet.swift`；`BasePanelSheet.swift`；`TodayNewHomeBanner.swift`。 |
| IF26 | `source_fixed`：工具包外链根据UIApplication.open completion的opened结果显示成功/失败；不无条件声称已打开。 | `KitSheet.swift` openLink。 |
| IF27 | `source_fixed`：审批页“本机添加好友”一次性原子保存route+conversation，失败不返回added成功、不通知/关闭，保留选择并可重试；进行中锁选择/取消。 | `InviteFriendsSheet.swift:205` invite / `:267` confirmFriendsPersisted；`RouteStore.swift` saveRouteAndConversation。 |
| IF28 | `source_fixed`：导入入口只在有尚未加入行程的收藏时显示；全部已加入时不出现可确认却无新增的动作。 | `ItineraryDetailView.swift:140` favoritedExperiences.subtracting(Set(experienceIds))。 |
| IF29 | `source_fixed`：好友邀请草稿打开私聊期间，输入/打开/Cancel均锁定；进行中不能从Cancel关闭。运行竞态仍待验收。 | `FriendsListView.swift` FriendInviteDraftComposer。 |

本页逐项跟踪的 IF01～IF29 均已发现对应源码修正；仅确认上述具体静态缺口，不表示整页观感、触摸成功率或远端功能全部验收。主任务后续编译/测试/独立审查结论应单独读取。

已排除的误报：主任务进程采样显示主线程主要在RunLoop，先前SwiftData/Keychain同步初始化只是排查候选，**不作为白屏根因或当前缺陷**。Kit没有30pt固定正文宽度；旧空kit没有正文是数据空态问题，当前已有独立倒计时内容及容器填满约束。`SoloScoreRadarChart`只在自身预览/测试调用，不算当前用户入口。`ConfidenceBadge`已有44pt语义按钮；其四个信号是只读解释。

## I01 · 地图、城市、筛选与位置选择

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 地图标记、聚合标记、候选体验 | 选中体验、浮出快速预览；聚合点聚焦区域；地图长按进入加地点坐标确认。 | 按当前可见体验动态生成；地图平移/缩放不是固定按钮。源：`Views/Map/CompassMapView.swift`、`ClusterAnnotationView.swift`。 |
| 顶部城市、城市列表/最近城市/全部城市、城市搜索、取消 | 打开选择器，筛选城市，切换城市或全部；取消返回地图。 | 城市/体验数/距离随数据变化。老城市picker与新的多页位置选择器均有源码，按调用方使用。`CityPickerSheet.swift`。 |
| 位置选择器：城市/搜索/地图分段 | 地名/地址搜索；结果选择；清空；在Apple地图打开；保存城市；坐标输入/移针；命名“保存并设置”或“不保存直接使用”。 | 搜索loading/error、坐标范围与负数输入、重名和保存失败需分别验；取消不应改变原位置。`LocationPickerSheet.swift`。 |
| 地图菜单：我的收藏、我的行程、地图样式；回到我的位置 | 打开对应列表/选择底图；回到定位或显示权限/位置不可用。 | MapKit控件、样式选项按枚举列出；不要将样式数量当新的能力。`CompassMapView.swift`。 |
| 分类、时段、距离/体验数、偏好筛选；清除、显示全部 | 改变地图和列表筛选；再次点选中的筛选可清除；空态可清筛选。 | 按类别/当前筛选动态实例；选中须同时有文字/形状和可访问性值。`Views/Filter/FilterBarView.swift`；`CompassMapView.swift`。 |
| 偏好、探索、接下来最佳、Ask Solo | 打开设置；按当前位置/所选位置探索；打开即将适合的体验；短点文字输入、长按语音。 | 具体入口受当前surface、权限、Pro和数据影响。`CompassMapView.swift`。 |

已有处理：位置输入显式数值/校验、选择器返回与低数据空态、清筛选和部分44pt控件均有实现。品味与注意力：地图本身是主视觉；类别色、分数圈和置信点只强化当前选中项。观感/点击：大字号下先保住城市和定位名称，再缩装饰。交互：城市切换后保持所选坐标语义，拒绝定位仍可选城探索；需设备实测。

## I02 · 地图 / 对话 / 发现工作面与附近清单

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| WorkspaceDock三个入口 | 切换工作面；重复点当前项guard返回。 | 选中态与草稿/对话需稳定；已有触觉只在真实切换触发。`Views/Map/WorkspaceDock.swift`。 |
| 发现页收藏/行程捷径、排序菜单、下拉刷新 | 打开列表，改变排序，刷新附近数据。 | 排序按枚举、体验按数据生成；loading/空态与搜索无结果不是同一状态。`DiscoverWorkspaceView.swift`。 |
| 附近搜索/清空/地图上搜索、换城市/去热闹处 | 搜索现有体验或交给地图/探索；低覆盖空态可切精选城市。 | “搜索无结果”不能清掉用户查询；可见城市及动态文案由源数据决定。`NearbySectionView.swift`。 |
| 附近体验行与上下文菜单 | 预览、详情、地图定位、问Solo、收藏/取消、导航。 | 每个体验一套参数化动作；导航仅有坐标时可用。`NearbyExperienceRow.swift`。 |
| Peek卡：详情、带我去、换一个 | 打开建议详情，选择地图导航，轮换建议。 | 换一个依赖非空callback；导航无坐标须说明，不能只无声return。`PeekSummaryCard.swift`。 |
| 路线卡/让Solo拼一条 | 进入路线详情或自动生成创建页。 | 主地图创建用完整附近候选，不再仅用“此刻最佳”过滤后空池。`RoutesSectionView.swift`；`CompassMapView.swift`。 |

已有处理：稳定dock、语义附近行和菜单、主地图路线创建候选池。设计建议：附近清单以分隔/留白组织，当前体验一个选中边界；排序与主行动不争同一强调色。按压反馈不应把滚动判成拖动；返回保留搜索与列表位置。

## I03 · 探索同意、进行中与结果批次

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 探索同意：了解了开始、暂不 | 确认数据去向后探索，或返回当前地图。 | 说明已随实际供应商改写；同意不等于后台位置权限。`Views/Map/ExploreConsentSheet.swift`。 |
| 探索进行中：取消 | 停止当前任务；阶段、进度和部分结果供查看。 | 取消语义及返回由上层工作流执行；网络失败后保留已获得信息。`ExploreModeOverlay.swift`。 |
| 探索交接卡：关闭、清除这批、批次行动 | 关闭结果说明，撤掉该次生成批次，或执行上层提供的后续行动。 | 批次撤销不等于删除全部用户体验；动态CTA按父级callback。`ExploreHandoffCard.swift`。 |

已有处理：明确确认/取消入口、阶段进度和交接。设计建议：只有正在执行阶段用一处动效，进度未知不造百分比；结果卡不再与全地图同时发光。失败写出可重试动作，取消后不应稍后跳出旧结果。

## I04 · 对话面板、历史与消息阅读

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 历史、收起回地图、关闭、最新消息 | 打开历史/恢复session；收起保留对话；关闭当前呈现；跳回最新。 | 当前工作面切换保持草稿；“最新”仅离开跟随模式时出现。`Views/Chat/ChatSheet.swift`。 |
| 面板把手点击/拖动/辅助动作 | 在面板高度间切换，调整地图与对话比例。 | 不能只有拖动手势；已有accessibilityAction备用。`ConversationPanel.swift`。 |
| 历史条目、滑动删除、删除失败重试、完成 | 按session恢复消息和作用域；成功落盘后删除本地历史；回到对话。 | 删除失败保留条目、显示可重试错误；按session动态生成。不是撤回模型供应商已经收到的内容。`ChatHistoryListView.swift`；`Persistence/ChatHistoryStore.swift`。 |
| 空态建议、先选城市、文字输入入口 | 发送具体建议或先进入选城；语音不可用可改文字。 | 建议是实发请求，应显示发送中/错误；不伪装只读提示。`HalfExpandedEmptyState.swift`；`ChatSheet.swift`。 |
| 消息展开/收起、复制、菜单复制 | 展开长消息、复制文本并返回当前会话。 | 按消息参数化；长文本不应默认占满整屏。`MessageBubble.swift`。 |

已有处理：面板辅助动作、历史删除失败保留与重试、最新消息入口。设计建议：文本/卡片边界克制、行宽和段落优先；未读/新回复是局部提示，不能每条消息都动画弹入。复制提示不要遮挡正在输入的文本。

## I05 · 输入、附件与附件阅读

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| AI输入栏：输入、键盘提交、发送、添加附件 | 编辑/发送文字，添加相册/相机/文件的暂存附件。 | 当前AI pipeline不支持附件会保留草稿并说明；预览不表示已发模型。`Views/Chat/ChatInputBar.swift`；`ChatSheet.swift`。 |
| 同行附件输入栏：输入/发送/仅重试附件 | 发送文字及支持的附件；部分失败后不重复已送达文字。 | `SendOutcome`区分未发/已发/文字已发附件失败；已有重试入口。`AttachmentInputBar.swift`；`Services/ChatService.swift`。 |
| 相册、相机、文件、取消；移除附件 | 打开系统选择器；移除某个暂存项，不发送。 | 文件/照片数量、类型、大小限制按当前实现；权限拒绝可改其他方式。`ChatInputBar.swift`；`AttachmentDraftStrip.swift`。 |
| 图片/文件气泡、加载失败重试、全屏关闭/缩放 | 获取附件URL，打开图片或文件；失败可重新解析；关闭回原对话。 | 签名链接可能过期；loading和失败不应一直是同一个空占位。`AttachmentBubble.swift`。 |

已有处理：同行发送结果契约及“只重试附件”、移除附件44pt、失败保留草稿。设计建议：发送是唯一主色；附件菜单/预览弱化边框；上传/失败状态在对应项内，别用全屏禁用阻止用户取消。键盘出现后发送按钮需小屏实测。

## I06 · 语音启停、取消与错误

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 地图语音按钮 | 长按说、松手提交、上滑取消；辅助技术可显式开始/停止。 | VoiceInteractionLifecycle负责一次输入尝试：取消、离开与过期权限返回不得重启录音；拒绝/识别错误可读。权限、后台与返回仍需设备实测。`Views/Shared/VoiceButton.swift`；`Services/VoiceInteractionLifecycle.swift`。 |
| 对话麦克风与录音条 | 点击/长按启动；再次点击或录音条停止；可切文字。 | 录音条已有语义停止按钮；不能仅依赖拖动/松手。`ChatInputBar.swift`。 |
| 权限/识别错误“好” | 关闭说明，返回仍可输入的页面。 | 关闭alert不等于重新授权；系统设置入口是否需要应按错误类型决定。`VoiceButton.swift`。 |

已有处理：录音条按钮化和触达、VoiceOver启停备用动作、地图语音异步权限尝试与取消生命周期。设计建议：状态名称明确区分“录音/停止/发送”；取消有立即反馈，一处波形足够；减少动态时不持续脉冲。

## I07 · AI建议卡、路线建议、来源与撤销

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 地点卡标题/展开/卡组滑动 | 地图打开具体地点；展开细节；卡组切换。 | 每条模型结果动态生成；无细节时不显示假展开动作。`Views/Chat/ChatCardViews.swift`；`ChatCardStack.swift`。 |
| 聊天路线建议的独立站点按钮 | 横向滚动各站点，点击后收起对话并在地图显示具体体验。 | 每站20pt视觉放入独立44×44pt命中区，contentShape与顺序/地点名称；不是压在固定总宽度中的重叠目标。站点按真实体验ID动态生成。`ChatCardViews.swift` ChatRouteProposalCard.beadStrip；`ChatSheet.swift` handleSelectExperience。 |
| 聊天路线建议“保存并查看” | 若路线尚未保存，先用throwing savePersisted取得成功结果；已有路线保留已保存版本。成功后才调用上层收起聊天、刷新路线列表并打开详情。 | 写入失败留当前卡片并显示saveError，不调用onAdopt或提前关闭；主行动至少44pt高。`ChatCardViews.swift` ChatRouteProposalCard.actions；`ChatSheet.swift` handleAdoptRoute；`CompassMapView.swift` onAdoptRoute。 |
| 聊天路线建议“收藏/已收藏” | 先确保存路线成功，再写UserPreferences路线收藏状态；已收藏读回偏好并禁用，取消收藏可在路线详情执行。 | 失败显示saveError，不改收藏/不成功触觉；当前不是只切局部State图标。按钮至少44pt高，已有路线不被提案旧版本覆盖。`ChatCardViews.swift` saved / actions；`RouteStore.swift` savePersisted；`UserPreferences.swift` toggleRouteFavorite。 |
| 来源、提示CTA/关闭、Solo气泡CTA/关掉 | 打开证据或具体恢复动作，关闭当前提示。 | source按模型输出/证据动态生成；来源不应伪造。`ChatCardViews.swift`；`InlineBanner.swift`；`SoloAgentBubbleQueue.swift`。 |
| UndoPill撤回 | 在倒计时内撤回待提交卡片动作。 | 秒数是确认窗口，不代表服务器已删除；要核对过期后按钮消失及操作幂等。`UndoPill.swift`。 |

已有处理：语义卡片/来源入口、局部展开与撤销、聊天路线持久化结果再导航/收藏、44×44pt独立横滑站点。设计建议：一张当前卡片一个重点，来源和标签用文字层级而非多重彩框；模型动作确认和反馈用同一动词，重试不能重复创建。

## I08 · 体验卡、快速预览与收藏

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 体验卡/快速预览：详情、收藏、去过、Ask Solo、导航、更多重编译 | 打开当前体验或执行对应局部动作；长按可展开快捷路径。 | 按体验参数化；坐标、Pro、已收藏/已完成等决定可见/禁用。`Views/Experience/ExperienceCardView.swift`；`Views/Shared/ExperiencePreviewCard.swift`。 |
| 收藏：搜索/清空、未完成/全部、最新/最近、此刻适合/附近 | 筛选/排序收藏，显示正确空态；可清查询或回地图探索。 | “无收藏/搜索无结果/只看未完成为空”分开；动态数量来自偏好和体验。`FavoritesListView.swift`。 |
| 收藏行：预览、取消收藏、撤销、标记去过/未到访、导航 | 行预览；移除可撤销；完成状态写偏好；导航选择地图。 | 已有VoiceOver对应动作与撤销窗口。`FavoritesListView.swift`。 |
| 提示轮播、分页点、去地图探索 | 下一提示/指定提示，或关闭收藏回地图探索。 | 提示索引动态，不能把每页算一个产品能力。`FavoritesListView.swift`。 |

已有处理：收藏筛选辅助语义、行级撤销、导航与完成的辅助技术动作。设计建议：完成与收藏使用不同图形/文案；最佳时段信息不伪称营业；列表以分隔线替代逐行重卡片，移除与导航目标分离。所有“已完成”需与重开状态一致。

## I09 · 体验详情、位置与主行动

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 关闭、更多菜单：深度重编译/导出笔记/反馈问题 | 返回原入口，或进入重编译feed/分享/本机反馈草稿与用户邮件。 | 重编译要求有callback及坐标；反馈先保存本机、不声称已发支持，详见I10。`Views/Experience/ExperienceDetailView.swift`；`ReportIssueSheet.swift`。 |
| 收藏、问Solo、去过、加入行程 | 切收藏/完成；打开作用域对话或付费页；选择/创建行程并加地点。 | Pro解锁后返回原任务；加入成功toast可“查看行程”。`ExperienceDetailView.swift`。 |
| 导航、地图应用选择、地址复制 | 用可用地图导航；单一地图可直接打开；复制地址有结果。 | 无坐标/无地图不应让按钮无声失效。`ExperienceDetailView.swift`；`LocationCard.swift`。 |
| 推荐时段定位、评分展开/六维解释、原始来源、附近体验 | 滚到时间轴、展开解释、开真实URL、切换体验。 | 来源URL、分数维度、附近体验按数据变化；没有URL的是说明行。`ExperienceDetailView.swift`。 |
| 长按标题/首屏埋胶囊 | 打开真实胶囊编辑器，成功落盘才关闭并提示。 | 当前隐藏手势有发现性成本，建议更多菜单再提供一个显式入口。`ExperienceDetailView.swift`。 |

已有处理：详情主行动层级、行程成功回看、胶囊失败保留草稿和分享失败路径。设计建议：先给地点/能否去/来源再给评分装饰；底部主行动和关闭在大字/长文中始终可达；更多菜单的动作必须有真实结果。

## I10 · 新增体验、反馈、共建笔记与重编译

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 新增体验：名称/当地名/一句话/描述/类别、照片删除/相册/相机、语音替代、保存/取消 | 编辑固定坐标地点；每张照片以稳定draft ID保存，全部写成功后交onSave。 | 名称空、照片加载中、存在未确认读取失败时禁保存；原始体验保存仍由父回调处理，沿父级回读验收。`Views/Experience/CreateExperienceSheet.swift`；`Services/PlacePhotoStore.swift`。 |
| 照片读取进行中、读取失败数量、明确跳过不可读照片 | 相册读取/解码时显示无百分比ProgressView；成功项加入当前草稿；失败有数量，用户可重新选取或明确跳过不可读项后继续。 | 只跳过读失败项，不删除已读照片；不把读取进度当上传/写磁盘成功。离开取消读取，generation token忽略过期返回，加载中锁照片编辑/保存。`CreateExperienceSheet.swift:350` photoLoadingSection / `:367` loadPickedImages。 |
| 照片写入失败：重试、不带失败照片保存、返回编辑 | 每张写结果可定位；重试复用同一照片ID；明确省略只接受同一批次receipt的已存URL；返回编辑清旧receipt再解锁。 | 失败保留字段和原图，不自动省略；待决写批次期间锁照片增删；最终只清理本草稿实际写过且未引用的文件，不动用户旧照片。`CreateExperienceSheet.swift:274` photoSaveErrorSection / `:399` returnToPhotoEditing / `:438` submitOmittingFailedPhotos；`Services/PlacePhotoStore.swift` PlacePhotoDraftBatch。 |
| MicroSurvey：舒适度/压力星级、是否推荐、提交/跳过 | 编辑体验反馈并交父级处理；跳过不提交。 | 星级按1～5动态参数化；拖动评分需等价辅助动作；成功反馈以父级真实保存为准。`MicroSurveySheet.swift`。 |
| ReportIssue：原因、可选详情、保存草稿/取消；邮件、分享副本、完成 | 原因是真实Button并有selected；200字符限制；保存本机草稿后进入投递页。可打开系统邮件/邮件链接或分享副本；仅邮件composer返回sent才记录已发送。 | 无自动上报后端；保存不冒充已发送。取消/失败保留已存草稿，编辑时防误滑；系统邮件/分享取消返回同页。`ReportIssueSheet.swift`；`Services/ExperienceReportDraftStore.swift`。 |
| 共建：确认/不准确、笔记筛选、展开全部、我也确认、mood、文本/发送 | 接受/驳回修正、筛选、确认已有笔记或写自己的观察；各写入先收成功结果，失败显示错误并可再试。 | mood与筛选有选中traits；发送30pt视觉扩44pt，写失败保留文本与mood，不成功触觉/清空。感谢只确认本地操作，不假造公开信心分。`TravelerNotesSection.swift`；`Persistence/TravelerNoteStore.swift`。 |
| 深度重编译Feed：隐藏/完成 | 隐藏运行进度或完成后返回。 | “隐藏”不等于取消任务，名称与生命周期须一致。`RecompileFeedSheet.swift`。 |

已有处理：表单防误滑、照片逐张保存结果、笔记落盘回执与失败保留、筛选/mood选中语义、反馈草稿和用户投递。设计建议：选择原因用简洁行而非每项彩色卡；错误留在原操作附近，保存/发送用具体动词；本机记录和公开贡献在文案中区分。

## I11 · 体验分享与笔记导出

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 分享样式：竖图/横图/方图/极简/Markdown | 切换当前导出预览；视觉卡片渲染成图片，Markdown展示文本。 | 单个动态样式枚举；44pt选项和选中语义已有实现。`Views/Experience/Share/ShareSheet.swift`。 |
| 分享、复制文本/Markdown、Notion、预览重试、关闭 | 交系统分享、复制、打开Notion预填标题，或重试渲染。 | 失败说明替代无限spinner；外部软件是否可用、最终保存/发送由系统决定。`ShareSheet.swift`及actionButtons；`MarkdownShareSheet.swift`。 |

已有处理：分享预览失败/重试、样式选中与触达。设计建议：保留一张真实地点图而非多模板装饰竞争；“分享”不写成已发布。小屏预览可滚动，底部主行动不被图片挤掉。

## I12 · 行程列表、创建与把体验加入行程

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 行程条目、新建、下拉刷新、删除/撤销、写入失败重试、完成 | 打开详情、创建、重读本地/同步状态；确认删除/撤销均以本地持久结果为准。 | 每行按行程生成；删除失败保留列表，撤销失败显示结果；回原页。列表读取与真实远端同步仍需环境验收。`Views/Companion/ItineraryListView.swift`；`Persistence/ItineraryStore.swift`。 |
| 创建表单：标题、城市、起止日、欢迎同行、备注、保存/取消 | 城市可搜索；日期范围校验；保存落盘成功后才结束表单。 | 有dirty保护、保存错误alert；取消当前仍是明确退出，应考虑丢弃确认的一致性。`ItineraryFormView.swift`。 |
| 加入行程：已有行程、新建/先创建、取消 | 从体验传单个ID，从路线详情传整条experienceIds；把尚未加入的站点一次保存，或创建新行程后添加。 | 已包含全部ID的行程禁用；成功才onSuccess/关闭，失败保留选择与错误供重试，支持部分已存在的去重。`AddToItinerarySheet.swift`。 |

已有处理：行程创建结果契约、禁用重复添加、删除撤销。设计建议：日期字段与错误紧邻，按钮同样叫“保存/添加”；列表不要再套第二层卡。同行开关的结果/可见性需明白展示，不能把本地行程发布成已经远端可发现。

## I13 · 行程详情、排序与同行可见性

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 体验列表/拖动重排、从收藏导入/确认、保存失败重试 | 重排行程站点；失败回滚屏幕顺序，重试原新顺序；导入有新增时显示真实数量，失败保留原列表。 | 保存异常有可见结果；无新收藏时隐藏导入入口，避免确认后无结果。体验行目前是只读内容及重排句柄，不推断为点击进入详情。`Views/Companion/ItineraryDetailView.swift` persistOrder / importFavorites。 |
| 欢迎同行Toggle、发布说明文本/类别/保存、关闭同行 | 开启前检查可见性；本地行程先写成功再开关/记录CompanionPost，失败恢复旧状态并可重试。关闭成功才移除本地activePost。 | 可见性off有“打开档案设置”恢复并在返回后继续；本地字段不证明远端已发布或有人能发现。`ItineraryDetailView.swift` activateCompanionPost / removeCompanionPost / resumeBlockedFlow。 |
| 开为招募路线 | 打开有出发窗口、人数和可见性的招募表单。 | 表单需要真实保存结果与明确创建路线后去向。`ItineraryDetailView.swift`。 |

已有处理：可见性设置恢复、排序错误回滚与重试、同行开关先落盘后反馈、导入失败不丢列表。设计建议：Toggle旁显示受众与本地/同步状态；无新增也给结果；重排语义需VoiceOver实测。

## I14 · 创建路线、路线详情与进行中的路线

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 地图创建入口、发现招募空态创建入口、AI帮我串路线 | 从当前真实体验候选进入创建页；AI生成建议顺序、摘要/配速，用户仍可编辑后保存。 | 少于2候选禁AI并变淡，零候选给说明；发现只用同城且兼容别名，无城市/无同城候选时走真实城市选择器，绝不跨城全量回退。`CreateRouteView.swift`；`DiscoverRecruitingRoutesView.swift` sameCityCandidates / emptyState；`CompassMapView.swift` consumePendingCitySelection。 |
| 创建：标题、配速Picker、候选站点、保存、取消 | 点击顺序为步行顺序，再点移除；至少2站且非生成中可保存；空标题用默认名；保存成功后地图原sheet转详情，列表来源先关表单再打开详情。 | candidate行是语义Button、44pt区、selected；配速有可访问名称。dirty防误滑，取消是显式退出并取消生成。throwing保存失败保留所有字段、站点、摘要，显示可重试错误。`CreateRouteView.swift`；`RouteStore.swift` savePersisted；`CompassMapView.swift` routeSheetContent。 |
| 生成中的编辑、过期建议采用/忽略、生成错误重试 | 每次生成有attempt，title/pace/站点修改增加版本；过期结果进入待采用状态而不覆盖；采用或忽略由用户决定。 | 生成时不可保存/重复生成；离开、保存或重开生成取消旧任务。真实模型与本地fallback区分provenance，不伪造AI已生成。`CreateRouteView.swift` staleSuggestionBanner / startGeneration；`RouteGenerationGuard.swift`；`AIService.swift`。 |
| 路线站点、开始路线、主理人审批、申请加入/等待确认 | 站点进真实ExperienceDetail：主地图交父回调，其余来源走内部目的地。单人路线开始发统一地图请求；招募状态按身份进审批、申请或禁用等待。 | StopsList Button有名称/44pt区，编号圆盘和其列宽随Dynamic Type同步增大；统一RouteNavigationRequest被地图消费，先收起Me/设置/对话/路线再绘线。缺体验ID不制造假地点。`RouteDetailView.swift` stopsSection / primaryCTA；`Components/StopsList.swift`；`RouteNavigationRequest.swift`；`CompassMapView.swift` didRequestStart。 |
| 路线收藏、加入行程、分享 | 收藏持久到偏好并读回；行程按钮打开真实选择器，把所有路线站点去重加入并读回名称；分享打开RouteShareSheet。 | 收藏/加入行程图标44pt并有名称和值；不是一次性State图标。单独分享样式见I18。`RouteDetailView.swift` isFavorited / refreshItineraryReadBack / bottomDock / shareButton。 |
| 群聊、完成确认、完成回放 | closed/completed路线有真实且有权限的group conversation才打开群聊；无会话/未授权准确禁用。closed主理人可确认完成；completed主理人可只读回放。 | 群聊、确认完成、回放是不同控件和结果，不共用“进入群聊”标签；完成流程见I17。路线分析说明只读不可用，没有购买解锁入口。`RouteDetailView.swift` chatAccess / completionReplayRow / aiInsightUnavailable；`RouteChatAccess.swift`。 |
| 招募模块CTA、成员头像全部、同行图层 | 状态驱动CTA；展开成员；切换地图同行图层。 | 图层受开关/数据限制，不以图标亮起证明有真实附近人；成员/状态按route动态。`Components/RecruitingModule.swift`；`AvatarStack.swift`；`CompanionMapLayer.swift`。 |
| 进行中路线跳过、暂停、结束 | 交主地图进度状态；缺跳过/暂停callback则不显示；结束与完成确认分别处理。 | 30pt视觉扩44pt命中区；暂停与结束需读回进度验收，不仅看overlay消失。`Map/ActiveRouteOverlay.swift`；`CompassMapView.swift` activeRoute。 |

已有处理：持久收藏和行程选择、所有来源的站点详情/开始兜底、准确群聊/回放、生成竞态与失败保留、44pt站点和配速语义。设计建议：路线编号服务顺序；路线主行动只留一个强色，收藏/行程用安静图标但保持读屏名称；不可用分析保留普通说明，避免锁和虚线制造假按钮。

## I15 · 路线招募、申请、审批与列表

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 开放招募：起止日/时间、配速、人数Stepper、公开/仅链接、留言、创建/取消 | 从真实行程创建含companion的路线，保存成功才成功触觉/关闭。 | civil-day展示与存储使用同一日期规则；日期/人数校验、重复提交锁、失败保留草稿/重试。本地保存与后端公开发现不同。`OpenForCompanionsSheet.swift`；`Models/RouteDepartureDates.swift`；`RouteStore.swift`。 |
| 申请加入：配速、介绍、提交/取消 | 由路线ID提交申请，成功后更新状态并关闭。 | 非法/重复/满员/网络错误需明确，失败保留输入；后端不可用的本地模式不能等同对方已收到。`JoinRouteRequestSheet.swift`。 |
| 审批：接受、拒绝、失败重试、邀请好友 | 接受/拒绝请求先提交结果，再重读route；本地fallback接受同时提交route+conversation，失败保留pending。 | processingRequestId互斥，错误记录失败请求及动作并可重试；邀请好友进入另一sheet，使用一次原子throwing提交，失败保留选择可重试；标签明确“本机添加好友”，不远程发邀。每个pending请求参数化。`ApprovalQueueView.swift` accept / decline / commit / fail；`InviteFriendsSheet.swift`。 |
| 我的申请：撤回、刷新、路线条目 | 撤回待处理请求、回读状态；打开路线详情后具备I14统一能力。 | 按请求动态；本地fallback与远端结果分开，撤回失败恢复仍待环境验收。`MyRequestsListView.swift`。 |
| 我主理：路线/审批、创建；已走过：路线/发现；发现招募：路线/创建 | NavigationLink进入对应路线/审批；空态引向真实创建候选/保存链。 | 不再继承空开始/站点callback；发现表单保存后等sheet消失再开详情。`MyHostedRoutesListView.swift`；`MyWalkedRoutesListView.swift`；`DiscoverRecruitingRoutesView.swift`。 |

已有处理：申请失败保留、创建/招募持久错误反馈、审批互斥/重试与原子本地提交、civil-day日期一致性。设计建议：用“待确认/已撤回/已满”说明当前结果，选中同时用traits；公开与仅链接受众要用文字解释。不要把本机通知当对方已收到邀请。

## I16 · 发现旅伴、安全同意、请求收件箱与举报

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 安全同意：18+、规则两Toggle、接受继续/取消 | 明确自我声明和安全规则，同意后进入原同行意图；取消返回。 | 两项未选禁用；不是年龄核验。`Views/Companion/CompanionSafetyConsentSheet.swift`。 |
| 发现：刷新/重试/下拉、发布可用时间、请求/添加好友、举报/屏蔽 | 查询当前城市；post动作交专用后端解析真实author，不再把postId当userId。空态本地可用路线与远端发现分开。 | loading/error/retry/empty；每次意图保留actionId重试，服务器receipt.saved才确认成功。实际部署/登录/RLS仍需环境验收。`DiscoverListView.swift`；`CompanionPostActionService.swift`。 |
| 发现详情：介绍、发送、完成 | 按postId发送好友动作，成功确认后更改状态。 | sending/didSend/error；目标过期、未登录、未保存、与前次已保存版本不符均有错误，不制造已发送。`DiscoverPostDetailView.swift`；`CompanionPostActionService.swift`。 |
| SendRequestSheet：介绍、发送、失败再试、取消 | 当前发现入口使用异步Result回调：进行中锁输入/发送/取消，成功才关闭；失败原地保留文本与可读错误。 | dirty/进行中防误滑；文本按长度限制。另有供其他来源使用的同步callback构造器，不能用它推断本页异步失败处理。`SendRequestSheet.swift`；`DiscoverListView.swift` onSendAsync。 |
| 收件箱：刷新/重试、接受/拒绝/撤销、打开对话/好的、举报 | 处理请求；接受后真实打开创建的conversation；拒绝有撤销窗口。 | 无结果与错误分开；发送进行中/撤销后过期需实测。`RequestInboxView.swift`。 |
| 举报/屏蔽：原因、详情、提交、屏蔽确认、成功/错误确认、取消 | 发现来源按postId经可信后端解析，再写report/block；其他已知user来源用其真实ID。成功才回父页移除目标。 | 提交锁定、错误保留、稳定actionId；原因选择有语义及44pt区。后端不可用不能当地成功关闭。`ReportBlockSheet.swift`；`CompanionPostActionService.swift`。 |

已有处理：安全勾选门槛、post与user身份边界、专用服务器回执、发送失败留草稿、收件箱失败/重试、举报44pt选择。设计建议：说明安全动作后果，屏蔽与举报不混同；陌生人资料的装饰徽章不能替代证据；失败留在原处，避免短toast成为唯一错误。

## I17 · 个人资料、消息、邀请入队与完成仪式

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| MyProfileEditView / CompanionProfile别名 | emoji展开/选择；显示名、bio、语言；可见性与资料项即时写偏好。 | 别名不是第二套页面；昵称/bio长度有约束；本地保存不证明远端已同步。`CompanionProfileView.swift`。 |
| 已走过路线“查看全部” | 超过5条时展开完整列表；前5张是展示卡。 | 不把WalkedRouteCard本身推断为详情按钮；完整列表的NavigationLink按I15。`CompanionProfileView.swift` walkedRoutesSection。 |
| 消息列表、刷新、失败重试、会话行、推送深链 | 拉摘要并进私聊/同行/路线群聊；深链匹配后进会话。 | 失败保留已有列表，首次失败显示错误而非单一暂无；加载/空/失败分开；找不到目标会话的恢复仍需环境验收。`ConversationListView.swift` loadError / reload。 |
| ChatView输入、附件、发送，更多添加好友/举报屏蔽，固定路线 | 文字/附件按发送结果清理；离开停止订阅；固定路线进真实详情，开始路线用I14统一请求。 | 可预填用户审过的initialDraft但不自动发送；附件失败保留可重试；关系动作按真实userId，路线群聊无一对一举报入口。`ChatView.swift`；`AttachmentInputBar.swift`。 |
| InviteFriendsSheet“本机添加好友”、选择、添加、失败重试、取消 | 按剩余席位把好友加入本机路线成员/群聊，route+conversation整批原子提交；成功后才本机提醒/关闭。 | UI明确不向好友发送邀请或消息；空选择/进行中禁提交，进行中锁行/取消/误滑；失败原地保留选择，不通知或声称添加成功；零实际新增也留表单说明。`InviteFriendsSheet.swift` confirmFriendsPersisted / invite。 |
| CompletionMoment确认完成、失败重试、关闭 | closed路线先确认；committing仅显示进行中；所选执行者markCompleted成功后转celebrating，错误/NotImplemented显示失败可重试；关闭回父页。 | 默认本机执行者先保存，不能宣称跨设备远端完成；流程守卫防重复。进行中关闭仍可点，离开不等于撤销已确认提交。开页不写。主按钮/关闭有44pt以上局部声明。`CompletionMoment.swift` confirmView / failureView / closeButton；`CompletionMomentFlow.swift` confirmCompletion；`LocalRouteCompanionRemote.swift`。 |
| CompletionMoment只读回放 | 已完成路线直接展示历史仪式，只有关闭；回放绝不markCompleted。 | 来源是I14独立回放入口，不能称正在保存/刚完成；减少动态不持续脉动。`CompletionMomentFlow.swift` isReplay / phase。 |

已有处理：消息结果契约、读取错误/重试、订阅生命周期、完成确认/提交/失败/成功/回放状态机。设计建议：庆祝只占一次成功结果，不抢占恢复错误；资料和聊天草稿不因重导航丢失；邀请入队需明确“本机”范围和真实加入数量。

## I18 · 路线分享

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 地图卡/轨迹卡/文字等样式、分享/复制/关闭 | 渲染选中样式，交系统分享或复制路线文本/链接。 | 渲染key/token防旧异步结果覆盖新选择；地图底图失败可降级为轨迹并提示。`Views/Companion/RouteShareSheet.swift`。 |

已有处理：路线分享异步竞态修复。设计建议：来源/地点和降级状态可读；渲染中允许取消，分享以当前样式为准，不能沿用旧预览。系统分享菜单内容不列固定按钮总数。

## I19 · 好友码、扫码、好友资料与好友关系

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| FriendsHub：好友码输入/查找、扫码、显示/收起我的码、复制/分享 | 查找本人输入码、扫码后进入解析结果；展示/复制自己的码。 | 格式校验/processing锁/错误状态；相机拒绝可手输。`Views/Friends/FriendsHubView.swift`。 |
| AddFriendSheet：我的码/添加好友、复制/分享/更换、重试、扫描/手输、完成/取消 | 另一可调用的好友码sheet，包含轮换码和解析profile流程。 | 新旧码语义要说明；请求失败不显示假码；镜头/识别生命周期已有修复。`AddFriendSheet.swift`。 |
| FriendsList：好友资料、请求接受/拒绝、刷新/重试、移除确认/取消、移除失败重试 | 查看关系与请求；移除先等远端删除成功再移除本地/播报；失败保留好友及重试目标。 | 只有一个移除任务进行；按好友/请求动态，离线/权限/后端关闭结果如实显示。`FriendsListView.swift` removeFriend；`FriendService.swift` unfriend。 |
| FriendProfile：发消息、邀请草稿、添加好友/待处理 | 既有好友打开/创建DM；“邀请”先打开本地文本草稿，陌生人发好友申请。 | 按关系显示不同dock动作；不是自动创建虚构companion post或自动发邀。`FriendProfileView.swift`；`FriendsListView.swift` FriendProfileHost。 |
| 好友邀请草稿：文本编辑、打开邀请草稿、取消 | 用户审阅文字后打开真实friendDirect会话并预填initialDraft；进聊天后由用户再次点发送，打开草稿本身不发送任何消息。 | TextEditor/打开/取消在isOpening期间锁定；草稿空禁用；打开失败留表单与文字；成功先关闭sheet，onDismiss后进入会话；防误滑。取消有明确退出，草稿不自动当已发送。`FriendsListView.swift` FriendInviteDraftComposer / openConversationWithDraft；`ChatView.swift` initialDraft。 |
| AddFriendButton：添加/发送中/已好友/已申请 | 封装各来源的好友请求动作。 | 自己/好友/待处理禁止重复；门槛、错误与结果由service验证。`AddFriendButton.swift`。 |
| QRScanner：相机、关闭、识别结果 | 真实摄像头扫码并交父级，关闭返回。 | 相机授权、前后台、sheet关闭后停止session已有处理；系统弹窗单验。`QRScannerView.swift`及父级cancel入口。 |

已有处理：扫码相机生命周期/授权守卫、码格式/重复请求、删除持久回执、好友邀请本地审阅→真实私聊草稿、失败保留/进行中互斥。设计建议：二维码主视觉，复制/分享次级；资料用可理解名字替代UUID；“打开草稿”和“发送”用不同动词及反馈。

## I20 · 我的与权益入口

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 我的/归档分段、个人资料卡、订阅权益、好友、消息、旅伴、设置、完成 | 切内容区；进入资料/付费/关系/消息/设置；完成回地图。 | 资料header整行可点；权益状态实际来自StoreKit/缓存，不能只由视觉badge证明。`Views/Me/MeSheet.swift`；`EntitlementBanner.swift`。 |
| 空收藏“探索地图”、地图头像bubble | 返回地图探索，或打开个人中心/待处理请求。 | 空态CTA不增加新权限/支付步骤；badge按请求数据动态。`MeSheet.swift`。 |
| 管理员举报队列 | 仅 `admin.canModerate` 时进入。 | 普通用户不当作常见功能；role未加载前隐藏。`MeSheet.swift`。 |

已有处理：资料整行入口、昵称/头像读真实偏好、权益banner进详情；免费/过期态用“查看方案”，不固定承诺一个月；试用进度只在StoreKit商品优惠周期可确定时显示。设计建议：我的页以身份与记录为主，订阅块不盖过返回任务；“归档/我的”的分段需要独立可读名称，当前 `Picker("")` 建议补AX label。

## I21 · 设置与子页

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 旅行风格、类别喜欢/隐藏/重显、可见分类、自定义标签添加/删除 | 即时修改旅行偏好和地图过滤；标签输入有添加动作。 | 每个类别/标签动态实例；已选/隐藏语义需与源状态一致。`Views/Settings/SettingsView.swift`。 |
| 靠近提醒、主题、触觉、语言 | 开关或选择系统权限相关功能与外观；切语言。 | 已有主题自适应、触觉开关；权限拒绝不应只保留Toggle“开”的假状态。`SettingsView.swift`。 |
| 同行开关、同行中心子页 | 进入资料、招募申请、群聊、发现招募、我主理路线。 | 同行安全同意/可见性/后台开关共同决定效果。`SettingsView.swift`。 |
| 恢复购买、管理订阅、用Apple保存 | 运行StoreKit恢复、打开Apple订阅管理、关联Apple身份。 | 已有恢复三种结果与错误toast；取消Apple不当成功；回到原设置。`SettingsView.swift`。 |
| 导出包含地图、导出数据、清除全部数据、忘记我及确认/取消 | 导出支持的本地记录；清列明本地表；忘记两项AI个性化模型。 | 不等于远端注销；结果/草稿/失败需如实说明；法律数据审计另列范围。`SettingsView.swift`；[事实审计](evidence/legal-data-audit.md)。 |
| 隐私政策、用户协议 | 语义Link打开两个公开中英Gist，至少44pt。 | 三处复用同组件，不双算renderer；外部浏览器返回由系统管理。`TermsConsentSheet.swift`；`SettingsView.swift`。 |
| AI提供商子页 | DeepSeek/OpenAI/自定义选择，API密钥、baseURL、模型编辑。 | 已有语义选择和URL说明；错误配置不应让对话静默。`AIProviderSettingsView.swift`。 |
| 通知子页、数据源子页 | 通知Toggle；编译策略/地点数/测试各源。 | 部分属于开发/实验入口；“测试”有运行中/成功/错误，真实通知投递需授权和系统验收。`NotificationsSettingsView.swift`；`DataSourceSettingsView.swift`。 |
| 版本多点解锁高级、测试邮箱、开发选项 | 输入测试邮箱解锁；强制权益、重置引导/覆盖、密钥覆盖、采样清理、锁回开发模式。 | 面向开发/测试，不能当普通用户主流程；操作需防误触、敏感输入不显示在截图。`SettingsView.swift`；`DeveloperOptionsView.swift`。 |

已有处理：恢复结果、AI选择语义、删除范围提示和法律链接三处一致。设计建议：系统分组行优先，行图标用辅助色，避免每项彩底；危险操作靠文案和独立分组，不给整个设置页红边框。数据删除承诺与实际范围必须一致。

## I22 · 首次使用、条款与偏好

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 条款：隐私/协议链接、同意继续、暂不、重新查看 | 打开全文；记录接受后继续；拒绝显示对应状态，可重新查看。 | 数据去向说明已更新；“暂不”不能暗中接受。`Views/Onboarding/TermsConsentSheet.swift`。 |
| 在地图上找到我 / 先逛逛、了解了/明白了/探索/稍后、跳过 | 申请定位或跳过定位；推进引导；跳过进入可用产品。 | 权限异步结果不能阻塞后续文字/选城路径。`OnboardingView.swift`。 |
| cohort、旅行风格、城市、下午需求文本 | 保存用户实际选择，再继续/暂时跳过。 | 跳过不应制造用户没选的偏好；选中带文字/traits。`OnboardingCohortStep.swift`；`OnboardingCityStep.swift`；`OnboardingView.swift`。 |
| Vibe照片、偏好文字、继续/跳过 | 用户选择照片后本地生成当前口味表示。 | loading时防双提交、拒绝相册可跳过；图片处理不等于发视觉模型。`OnboardingVibeStep.swift`。 |
| 引导中的试用/稍后 | 根据实际StoreKit资格购买，或继续免费。 | 商品未加载、无资格、取消/失败必须区分；固定“1个月”文案不可超出商店真实优惠。`OnboardingView.swift`。 |

已有处理：真实条款全文和数据去向、可跳过路径。设计建议：引导每屏只完成一个决定；不让连续多屏介绍占据第一次旅行任务。清晰免费退出与返回，不靠微小灰字隐藏“稍后”。

## I23 · 付费、恢复与订阅管理

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 商品方案选择、主购买、继续免费、关闭 | 选择当前StoreKit返回的商品并购买；成功交onUnlocked；免费/关闭返回原任务。 | selected/product/price/period要一起朗读；loading、取消、失败与成功区分。`Views/Paywall/PaywallView.swift`。 |
| 方案为空时“重试加载方案”、加载失败“好” | 点击只重新读取商品；读取成功先显示真实价格，用户再次明确点订阅才进入Apple确认。 | 加载失败标题为“方案加载失败”，与购买失败分开；读取/购买均有互斥，重试读取不自动扣款。`PaywallView.swift` ctaTitle / purchase / errorTitleKey。 |
| 恢复、管理订阅、错误好的 | 恢复当前账户权益、打开系统订阅设置、关闭错误提示。 | 已有恢复成功/未找到/失败区分；不要用旧缓存成功掩盖当前请求失败。`PaywallView.swift`。 |
| 隐私、用户协议 | 购买前可打开公开全文。 | 同一语义组件两个44pt Link。`PaywallView.swift`。 |

已有处理：44pt方案、读取真实商品、方案重试与独立错误标题、恢复结果与法律入口。设计建议：价格/周期/试用资格同等清楚，推荐/最划算只一个强调；选中配勾选与traits，非选卡轻分隔；强色前景在深色仍需实机核对。

## I24 · Today、城市基地、工具包、活动与印证

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| Today地图把手：打开地图/返回Today，拖动；新家提示关闭 | 按钮或拖动在地图层与Today间切换；一次性提示关闭写本地标记。 | `flag`：todayHome关闭时仍直接地图；把手96pt高语义按钮，新家提示关闭44pt；地图首次拉起才挂载。地图拖动与滚动边界仍需运行验收。`TodayContainer.swift` mapHandle / mapDragGesture；`TodayNewHomeBanner.swift`。 |
| Today入境日期入口、表单日期/已确认停留天数、取消/保存 | 进入独立表单；只允许截至今天日期；天数空/超1～365禁保存；保存才一起写用户值，并同步提醒后关闭；取消不写。 | 不推定30天，不通过城市政策断言用户实际资格；保存中锁表单/保存/取消，防误滑；辅助功能字号把日期切为纵向graphical DatePicker，普通字号保留原样；天数字段有持久标签、单位和44pt下限。两个日期声明是互斥布局分支，不是两个用户功能。日期/天数/前台恢复触发Today头部重读。`TodayStatusHeader.swift`；`TodayActionSheets.swift` TodayEntryDateSheet；`TodayContainer.swift` activeSheet。 |
| 昨日封存回执、详情完成 | 有昨天胶囊才显示入口；打开只读封存日期/可返回日期，完成关闭。 | 不提前解封或承诺在此看到内容；无昨日胶囊不渲染占位。`TodaySealReceipt.swift`；`TodayActionSheets.swift` TodayCapsuleReceiptDetail。 |
| 附近旅人、ThreeThings工作/此刻/今晚 | 附近行进入发现列表，空态可成为首位；ThreeThings当前只读。 | `flag` companion；不把只读卡当点击建议按钮，不造真实旅人数。`TodayNearbyRow.swift`；`TodayThreeThings.swift`。 |
| BaseCard、基地面板各行、查看全部、完成 | 开基地；按face与可用数据进入日期/工具包、当地活动、工作体验、待印证或预填Solo问题；完成回地图。 | 父级先关sheet，onDismiss消费baseFollowUp再进下一层；不以同屏双sheet竞争导航。天气缺失/失败隐藏，不能造数值；查看全部44pt局部目标。`BaseCard.swift`；`BasePanelSheet.swift`；`CompassMapView.swift` baseSheetContent / handleBaseFollowUp。 |
| Kit待办勾选、外链、电话、完成 | 待办写当前城市本地集合；链接通过系统打开，completion成功/失败用不同提示；电话交系统。 | 待办26pt视觉扩44pt，AX事项名称+完成状态；外链44pt局部目标。实际电话/软件可用性由系统决定，点击不等于拨通/已完成事项。`KitSheet.swift` tickCircle / deepLinkPill / emergencyNumbers / openLink。 |
| Kit个人倒计时：设置/编辑日期、到期提醒Toggle | 城市没有visa行也独立显示；设置/编辑均打开TodayEntryDateSheet；可选择提醒，按用户确认值本地计算。 | 无城市kit也有输入，不空白；不根据选择日期自动补天数。正文列与ScrollViewReader填满父容器；计数不是官方签证或税务判断，权限/提醒投递需系统验收。`KitSheet.swift` orderedKit缺visa分支 / VisaComplianceControl；`ComplianceService.swift`；`TodayActionSheets.swift`。 |
| Live活动“在地图上看”、完成；EventMarker | 有坐标时关闭列表并定位/选中真实活动；marker点击交父级；完成回地图。 | 没坐标不提供假地图按钮；无/过期活动走空态，不制造新活动；地图按钮44pt局部目标。`LiveSheet.swift`；`EventMarkerView.swift`；`CompassMapView.swift` focusEventOnMap。 |
| Verify三组选择、提交、失败再试、关闭 | 全部回答后可提交；先持久化一条本机笔记，再记本地已印证，成功才关闭；异常留答案和错误可重试。 | 选项有44pt和selected，关闭44pt；本地保存不改变公开confidence，EN/ZH文案已明确；readonly信心标记不是额外输入。`VerifySheet.swift`；`CompassMapView.swift` submitVerification；`TravelerNoteStore.swift` addNotePersisted。 |
| ComplianceBanner处理/关闭 | 处理进入基地；关闭仅本会话隐藏提示，不改变倒计时或用户记录。 | 有真实个人倒计时且满足提醒预算/优先级才出现；处理与关闭各44pt。离线/POI加载优先，不叠多条强提示。`ComplianceBanner.swift`；`CompassMapView.swift` shouldShowComplianceBanner。 |

已有处理：Today两个真实子页、日期/天数显式确认、Kit无数据独立输入/编辑及宽度加固、外链准确结果、印证先落盘且不假造公开分数、CityOS独立命中区、基地串行跳转。设计建议：倒计时只表达用户确认值；未知写未知；风险与选中用边框，普通统计不用逐项框；Today和地图同一时刻只保留一个行动重心。启动曾见旧部分构建空白不能据源码复核写为当前布局已通过，运行证据由主任务记录。

## I25 · 归档、城市收藏册与旅行仪式

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 归档旅行/城市记录 | 展示实际到访分组、旅行阶段/统计；有记录才展示内容，无记录给空态。 | 不伪造用户历史；日期/标题/条数按SwiftData记录。`Views/Archive/ArchiveView.swift`。 |
| 今日灵感、盲盒、城市收藏册、分享瞬间、配乐、回顾、打开胶囊等tile | 进入明确“预览”或“只读记录”容器；唯一真实外部行动是关闭。 | 内部“完成/开启/解锁/分享/壁纸/回信/新风格”disabled，不能列成已可用操作。`ArchiveView.swift`。 |
| 城市收藏册/到期胶囊 | 从真实记录构建；空时有真实空态，不再造“A note from you”。 | 展示不是实际解锁/回复；公开动作按容器禁用。`ArchiveView.swift`。 |
| 体验详情中的真实胶囊：文本、开启月份、埋下、取消/丢弃/继续编辑 | 输入文本与时长，写成功关闭；失败保留；取消有dirty确认。 | 当前真实编辑支持文本，不把model的voice/photo枚举写成UI已有选择器。`Views/Capsule/CapsuleComposeView.swift`。 |

已有处理：仪式预览真实标记/禁用假CTA、真实城市记录/胶囊空态、胶囊保存失败不丢草稿。设计建议：有内容时让地点/日期/文字承担辨识，仪式只留一个记忆点；预览卡内部仍像按钮的disabled装饰建议进一步静态化，减少用户试点成本。真实胶囊入口仍以长按进入；建议增加显式菜单入口提高发现性。

## I26 · 管理队列、面板和共享反馈

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 管理队列：刷新、封禁、标记处理 | 按管理员权限处理举报。 | 只有管理员挂载；动作错误/进行中/二次确认需单独验，不能从普通用户无入口推断完成。`Views/Admin/ModerationView.swift`。 |
| BottomInfoSheet把手、展开、排序/选项 | 调整面板高度、选择体验排序。 | 手势与内部列表滚动存在边界；共享renderer不另算新页面。`Views/Map/BottomInfoSheet.swift`。 |
| 离线banner重试、通用banner滑走/关闭/CTA、空态CTA | 重试连接、关闭当前说明，或执行父级恢复动作。 | retry有互斥与重读网络状态；关闭不改变数据事实。`Views/Shared/OfflineBanner.swift`；`DismissibleBanner.swift`；`SoloEmptyState.swift`。 |
| 待签到：来过/关闭 | 确认一次到访并停止自动关闭计时，或忽略提醒。 | 成功反馈以父级保存为准，重复点guard；需旁路系统地理围栏验收。`PendingCheckInBanner.swift`。 |
| PressableButtonStyle | 复用按下缩放、触觉/减少动态策略。 | 是样式，不是额外可点击按钮；不能使ScrollView内点击被拖动手势吞掉。 |

已有处理：离线重试状态、待签到防双击、统一按压与触觉。设计建议：banner只有当前最相关一条；错误文本允许换行，CTA/关闭目标分开；错误/空态不能都靠同一图标占位。

## I27 · 置信度、独行评分与解释

| 页面 / 控件 | 真实操作与结果 | 状态、返回及动态规则 |
| --- | --- | --- |
| 置信度badge | 语义Button打开证据信号popover；四类信号行、最强信号及验证时间是只读解释。 | 44pt独立区域+contentShape；AX名称/提示/验证时间；无信号用估计说明。置信度不等于安全/营业保证，弹层由系统popover关闭行为退出。`ConfidenceBadge.swift`。 |
| 紧凑Solo分数badge | 分数已评估才提供入口，打开固定六维解释；未评估时只读状态。 | 小胶囊视觉外扩44pt，分值AX名称与点击提示保留；去掉持续twinkle/pulse与初始不可见，初次出现即可看到内容。`SoloScoreBadge.swift` compactView。 |
| Solo弹层六维行 | 一次展开一个维度的通俗解释，再点收起；显示真实分值。 | 固定6维参数化，不能把每种分值算新按钮；整行至少44pt与contentShape，Button已有AX名称/值/提示；最强/最弱/安全提示只读。`SoloScoreBadge.swift` dimensionRow / SoloScorePopoverContent。 |
| 体验详情查看全部六维/收起 | 默认前三维，展开后六维条形；只变显示范围，不提交用户评分。 | 局部条形卡不是雷达图；展开按钮至少44pt，维度条形本身只读。`ExperienceDetailView.swift` soloScoreCard。 |
| TrustBadge、完整Solo标题、最强信号说明 | 只读来源/总分/证据文字，无点击回调。 | 不因胶囊边框/分值色彩就统计成按钮。`TrustBadge.swift`；`SoloScoreBadge.swift` fullView；`ConfidenceBadge.swift` PopoverContent。 |

已有处理：真实Button的辅助名称/分值/提示、44pt命中声明、分数徽章静态可见和减少动态分支。设计建议：解释优先，证据和评分一个视觉重心；解释入口与只读标签可区分；不要每个数值加独立外框。`SoloScoreRadarChart.swift`仅自身预览和测试调用；轴、最强/最弱与重播是未挂载组件能力，不能当当前产品功能或当前VoiceOver已通过。

## 组件、预览与未挂载项的额外核对

以下补齐当前清单中有候选、但不能直接作为独立可用页面的组件。包含iOS候选的源文件均在下表与[逐控件索引](current/ios-controls.md)按真实父页面或复用组件覆盖；新状态机无直接候选也单列。零直接候选的文件仍可能组合真实子组件，不能据此认定没有交互；逐文件扫描覆盖保留在机器清单中，不额外制造用户动作。

| 源文件 / 组件 | 所属真实范围 | 控件边界 |
| --- | --- | --- |
| `App/SoloCompassApp.swift` | 首次使用/条款呈现关系、根工作面及全局环境。 | fullScreenCover/sheet是呈现关系，不另算用户按钮。 |
| `Views/Map/MapPinPickerView.swift`、`MapCoordinatePresentation.swift` | 多页位置选择器内地图与坐标校准/定位包装。 | 地图拖移/选点属于I01；不把每个Map声明算新增按钮。 |
| `Views/Shared/LongPressCardModifier.swift` | 体验卡的长按行为包装。 | 同一体验的快捷手势，不和父卡相加为两个产品功能。 |
| `Views/Shared/SoloScoreRadarChart.swift` | 当前仅自身 `#Preview` 和测试调用，未发现生产页面挂载。 | 雷达轴、最强/最弱按钮、重播是组件能力；不列当前用户入口，不用其组件测试替代真实Solo弹层验收。详情的条形卡由`ExperienceDetailView`局部实现。 |
| `Views/CityOS/BaseCard.swift` | I24基地入口。 | 点击交onOpen；具体目的地由CompassMapView装配。 |
| `Views/Archive/CityCodexView.swift` | 归档里的真实城市记录展示，套只读容器。 | 组件里Unlock按钮在当前挂载下disabled，不宣称有购买/解锁结果。 |
| `Views/Blindbox/BlindboxLaunchView.swift` | 归档盲盒预览。 | 时长/开启/暂不在当前容器内disabled；不能当已能开始盲盒旅行。 |
| `Views/Blindbox/BlindboxRecapCard.swift` | 当前仅发现本文件 `#Preview` 调用。 | 源码有Share按钮renderer，但未发现实际产品挂载；不列可用分享入口。 |
| `Views/Brag/BragCardView.swift`、`Views/Insight/InsightCardView.swift` | 归档只读预览。 | 分享/壁纸/视频解锁等内部动作disabled。 |
| `Views/Omen/OmenCardView.swift`、`Views/Ost/OstShareCard.swift` | 归档灵感/配乐预览。 | 标记任务、分享、换风格为组件能力，当前挂载不执行。 |
| `Views/Capsule/CapsuleOpenView.swift` | 归档到期胶囊只读展示。 | 内部回信/关闭被容器禁用；使用容器真实关闭。真实编辑是I25单列的CapsuleComposeView。 |

## 逐按钮评估采用的共同标准

| 维度 | 具体判断 | 仍须运行时证据 |
| --- | --- | --- |
| 品味 | 地点、路线顺序、地图与旅行文字有主次；颜色/字体/图案服务内容，不用统一卡片模板包装全部功能。 | 同一真实任务中连续截图，看页面是否有明确注意力重心。 |
| 观感 | 中文/英文、大字号、深浅色下文字不截断；所有状态保留名称；44pt目标与视觉尺寸分开设计。 | Primary iPhone和必要Compact布局、Dynamic Type、深色真实截图与读屏。 |
| 点击反馈 | 触觉、按下、选中、进行中、成功/失败对应真实结果；返回不丢草稿；不能只改图标。 | 双击/慢网/取消/失败注入后回读数据，尤其IF01/05/07～12。 |
| 交互逻辑 | 每个入口都有具体目标、退出与失败恢复；默认空callback不能承诺可操作；系统UI返回保留上下文。 | 从所有实际来源走完同一动作，不能只测主地图一条路径。 |
| 边框与注意力 | 框线表示输入、选中、危险或分组；普通文字行用留白和弱分隔；只有当前主动作用强色。 | 同屏检查当前主行动、次级链接、危险操作是否可区分，触摸区无重叠。 |

**下一轮验收依据：**当前目录和候选清单只提供可追踪范围；明确缺陷先修复、逐调用方复核，再用浏览器/模拟器、辅助技术和真实状态证据评分。未实测项保持 `not_verified`，不通过源码静态检查批量宣称达到 96 分。

最终评分徽章颜色复核：紧凑徽章文字/符号改深色，完整数值采用自适应可读前景；最低对比度计算见[evidence/round02-score-badge-contrast.json](evidence/round02-score-badge-contrast.json)。颜色验算不代替全界面辅助使用验收。
