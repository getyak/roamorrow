# Web / iOS 全量源码交互清单

源码快照：`working-tree`；设计判断基线：`924f09a4`；盘点日期：2026-10-16。

扫描 **220 个 UI 源文件**，得到 **974 个源码交互候选**（Web 110、iOS 864），使用 **44 个基线产品功能组**归并，仍有 **0 个候选待人工归组**。这些数字都不是实际渲染按钮总数。

## 如何使用与审查边界

每个候选包含 route/screen、control、label、action、states、`source:line`、动态/条件标记、优先级与未验证状态。JSON 保存完整源码摘录和机器字段；下面保留逐文件覆盖和逐候选索引。

- `semantic_control`：Button / NavigationLink / Link 等语义控件。
- `input_control`：输入、选择、切换等控件，包含键盘提交。
- `gesture_or_semantic_control`：手势、可点击非语义容器与可访问性动作。
- `presentation_edge`：sheet / alert / menu 等导航和呈现关系，不应另计为一个按钮。
- `custom_component_call`：复用组件具体调用点，应与底层 renderer 联合核实，避免双算。
- `runtime_map_control` / `imperative_event_handler`：地图动态 marker、定位、缩放及手工事件。

已排除注释和 Swift `#Preview`。循环项目、菜单选项、条件可见性、SDK 控件随数据或环境变化；函数分组是能力目录，单组可包含多按钮，单控件也可能进入多个流程。所有运行时验收目前都标为 `not_verified`，不能将源码静态审查包装成每项 96 分。

## 解析诊断

无法解析或已改变结构的字段不会套用旧文案/链接；这里只列当前可提取的源码，空列表不等于没有该功能。

本次支持的静态结构未产生解析错误；这不代表运行时功能已验证。

## 设计判断口径

遵循 `frontend-design`：旅行的地图、真实体验和当前决策承担主体表达；色彩、边界和图案服务状态与信息层级。主动作只保留一个视觉重心；次级导航有稳定位置；触摸/键盘/VoiceOver 能到达相同动作；反馈说明动作结果；失败/空态有下一步；动效回应用户且尊重减少动态。

每组都需要核实默认、按下/焦点、选中、禁用原因、加载/取消、成功/撤销、失败/重试、空态/离线、键盘/VoiceOver、大字号/小屏、深色/减少动态、中英文本。局部源码出现状态变量仅表示已发现实现线索。

## 人工归并的产品功能目录

| ID | 平台 / route 或 screen | 控件与功能 | 优先级 | 源级候选 |
|---|---|---|---|---|
| W01 | web · 官网 EN/ZH 导航 | 品牌返回首页、功能锚点、定价、宣言、语言切换、获取 App | P1 | 9 |
| W02 | web · 官网 Hero/功能/信任/页脚 | 下载 CTA、探索功能、底部法律与支持链接；电话内 mock 中装饰形控件 | P1 | 3 |
| W03 | web · 定价 EN/ZH | 免费/Pro 方案 CTA、比较表、FAQ、页头与页脚 | P1 | 13 |
| W04 | web · 宣言 EN/ZH | 官网导航、末尾行动链接、页脚 | P2 | 10 |
| W05 | web · 隐私 EN/ZH | 隐私邮件、官网导航与页脚 | P2 | 12 |
| W06 | web · 下载 | App Store/候补联系方式、官网导航与页脚 | P1 | 12 |
| W07 | web · 共享 Web 控件 | 营销 Button/ButtonLink 的 hover/pressed/focus；跳到主内容；设计原型入口 | P1 | 7 |
| W08 | web · /app 地图 | 地图平移缩放、标记选择、定位/缩放/署名控件、体验浮层 | P1 | 12 |
| W09 | web · /app 附近和足迹 | 抽屉展开/收起、附近/时间线切换、体验行选择、空态与 loading | P1 | 13 |
| W10 | web · /app 今日 | 今日建议打开详情、关闭推荐横幅 | P1 | 2 |
| W11 | web · /app 语音/文本意图 | 按住说话、松手/离开停止、清除意图、权限/不支持时文本发送 | P1 | 5 |
| W12 | web · /app 体验详情 | 来源外链、关闭抽屉、我去过、可选 1–5 评分、saving/done | P1 | 8 |
| W13 | web · /[city] 城市工作台 | 城市入口、命令面板、语言、排序、分类切换、体验行与地图标记、详情与路线入口 | P1 | 24 |
| W14 | web · 城市命令面板 | 打开、搜索、方向键/回车、鼠标结果、Escape/遮罩关闭 | P1 | 5 |
| W15 | web · /mobile-preview | 语言、命令面板、抽屉、建议提示关闭、体验详情、签到 | P2 | 10 |
| W16 | web · /experience/[id] 分享体验 | 返回城市、地图导航、下载 App、来源、附近体验和页脚 | P1 | 4 |
| W17 | web · /trip/[slug] 分享行程 | 语言切换、体验/站点链接、地图、下载/返回城市 | P1 | 2 |
| I01 | ios · 地图主场景/城市 | 城市 pill、城市/地址/坐标选择、地图样式、回到定位、标记/聚类、筛选/排序、空态、快捷收藏与行程 | P1 | 110 |
| I02 | ios · 稳定导航/发现 | 地图/问问/发现三项 dock；问问长按语音；发现收藏与行程快捷入口、附近与路线、重试 | P1 | 31 |
| I03 | ios · 探索工作流 | 探索同意、进行中控制、取消/结束、handoff、进度与失败恢复 | P1 | 8 |
| I04 | ios · 保留对话/历史 | 展开/收起对话、历史选择/重命名/删除、新对话、建议问题、消息相关操作 | P1 | 32 |
| I05 | ios · 对话输入/附件 | 文本、多行输入、附件加号、照片/相机/文件、删除附件、发送/停止、地点上下文、错误清除 | P1 | 35 |
| I06 | ios · 语音 | 按住/切换录音、松手发送、上滑取消、倒计时、权限/识别错误、自动停止、录音条停止 | P1 | 8 |
| I07 | ios · AI 卡片/撤销/诊断 | 地点/路线卡打开、保存路线、provisional 校验、诊断同意/拒绝、banner action/关闭、撤销 | P1 | 15 |
| I08 | ios · 体验卡/预览 | 打开详情、收藏、长按菜单、上下文 Ask、收藏列表 | P1 | 43 |
| I09 | ios · 体验详情主动作 | 关闭、收藏、Ask Solo/付费门槛、完成/取消完成、加入行程、更多菜单、分享、导航应用选择、最佳时间跳转、雷达说明、附近体验 | P1 | 37 |
| I10 | ios · 体验新增/修正/反馈 | 创建标题/分类/位置等字段、保存/取消、微调查、报告类型与详情、旅行者笔记、重新编译 | P1 | 39 |
| I11 | ios · 体验分享/导出 | 分享卡样式、导出图片、系统分享、Markdown 复制/分享/Notion、关闭 | P2 | 14 |
| I12 | ios · 行程列表/创建 | 新建、类型/城市/日期/名称/备注、保存、取消、列表行与删除 | P1 | 33 |
| I13 | ios · 行程详情 | 编辑/删除/重排站点、导入收藏确认、添加体验、公开招募、关闭可见性提示、显示更多 | P1 | 20 |
| I14 | ios · 路线创建/详情 | 新建路线、选站、顺序、路线详情、开始/结束、加入/发布、分享、招募状态 | P1 | 29 |
| I15 | ios · 路线招募/申请 | 开放招募、步速/留言、发送申请、我的申请撤回、审批接受/拒绝、自己发起/走过路线 | P1 | 35 |
| I16 | ios · 同伴发现/安全 | 列表排序/刷新、招募详情、联系申请、收件箱、举报/屏蔽、同意安全条款 | P1 | 51 |
| I17 | ios · 同伴资料/消息 | 昵称/简介/偏好/可见性、保存、会话选择、发消息、邀请好友、完成瞬间 | P1 | 29 |
| I18 | ios · 路线分享 | 分享样式、系统分享、邀请、关闭 | P2 | 7 |
| I19 | ios · 好友入口/邀请/扫码 | 好友码、复制/分享、扫码、输入码、预览资料、发送/接受/拒绝/撤回请求、移除/屏蔽好友、重试 | P1 | 56 |
| I20 | ios · 我的/权益 | 个人/仪式切换、资料/收藏/行程/好友/消息入口、设置、付费入口、关闭 | P1 | 13 |
| I21 | ios · 设置及子页 | 旅行风格、偏爱/隐藏/可见分类、自定义标签、语言/主题、AI/数据源/通知、同伴 hub、导出、删除/重置、开发选项解锁 | P1 | 90 |
| I22 | ios · 首次使用/条款 | 跳过、前进/后退、城市与偏好、照片、接受/拒绝隐私条款、位置权限 | P1 | 29 |
| I23 | ios · 付费 | 月/年方案、购买、继续免费、恢复购买、关闭、错误确认 | P1 | 11 |
| I24 | ios · 今日/城市工具 | 入境日期、今日三件事、下一步/附近、提醒横幅关闭、回执、基地确认/切换、城市工具待办/导航、Visa 提醒/日期、活动去地图、核实问答 | P1 | 34 |
| I25 | ios · 仪式/归档 | 归档/城市手册、解锁、盲盒时长/开始/稍后/分享、时光胶囊输入/时间/埋藏/回复/关闭、今日签完成、分享卡/壁纸/视频解锁 | P2 | 30 |
| I26 | ios · 管理/共享反馈组件 | 管理审核、banner 关闭/重试、check-in 提示、空态 action、全局手势和通用按压样式 | P1 | 16 |
| I27 | ios · 信任解释/独行评分 | 置信度说明 popover、独行评分说明、雷达维度点击/拖动与 VoiceOver 调整、关闭解释 | P1 | 13 |

## 本轮新增组件的人工归组

这里只补充已核对的源码归属；不修改起始基线设计判断，也不据此宣布体验已通过。

| 当前新增源文件 | 功能组 | 调用来源 | 归组依据 |
|---|---|---|---|
| `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift` | I24 | apps/ios/SoloCompass/Views/Today/TodayContainer.swift / apps/ios/SoloCompass/Views/CityOS/KitSheet.swift | Today与CityOS工具包复用的入境日期/确认停留天数表单、只读胶囊回执详情；由TodayContainer和VisaComplianceControl实际挂载。 |
| `apps/ios/SoloCompass/Views/Companion/CompletionMomentFlow.swift` | I17 | apps/ios/SoloCompass/Views/Companion/CompletionMoment.swift | 完成仪式状态机：确认、提交、失败重试、成功庆祝与只读回放；本文件不直接声明UI控件。 |
| `apps/web/src/components/marketing/MobileNav.tsx` | W01, W03, W04, W05, W06 | apps/web/src/components/marketing/sections.tsx | MarketingNav调用的共享移动导航，覆盖官网及营销子页的菜单/语言/下载入口。 |
| `apps/web/src/components/marketing/HeroMotif.tsx` | W02 | apps/web/src/components/marketing/sections.tsx | Hero使用的静态罗盘/路线SVG，仅视觉，无直接交互候选。 |
| `apps/web/src/components/ShareButton.tsx` | W07, W17 | apps/web/src/app/trip/[slug]/page.tsx | 共享Web Share/复制链接控件；当前调用方是行程分享页。 |
| `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift` | I21, I22, I23 | apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift / apps/ios/SoloCompass/Views/Settings/SettingsView.swift / apps/ios/SoloCompass/Views/Paywall/PaywallView.swift | 共享隐私/用户协议Link renderer；由首次使用、设置和付费页调用。仅归入共享法律链接，不把条款接受/退出按钮误归到设置或付费页。 |

## 逐组设计分析

以下保留起始基线的设计建议，未因重新扫描而自动升级为当前结论；控件变化需人工复核，观感、动效、触摸成功率仍需运行时验收。

| ID / 功能组 | 品味与用户观感 | 点击反馈与交互逻辑 | 边框与注意力 |
|---|---|---|---|
| W01 · 官网 EN/ZH 导航 | 保留罗盘标记和安静导航，旅行内容优先于品牌 chrome；移动端必须保留菜单和语言入口；当前 md 以下全部隐藏 | hover 下划线应同步 keyboard focus，下载目标必须真实；首页/定价/宣言/语言切换保持所在页面的语境 | 页头一条细分隔线足够，避免每个导航项都变成卡片 |
| W02 · 官网 Hero/功能/信任/页脚 | 地图纹理与旅行时段最能表达产品，减少通用暖色卡片套件感；手机 mock 必须明确为演示，不能给出可点击假按钮 | 装饰图形不进入 Tab 序列；真实 CTA 按下后有确定结果；功能展示到体验入口的去向一致，来源和示例标识诚实 | 热力图/置信度已有信息量，装饰渐变和反复 reveal 应收敛 |
| W03 · 定价 EN/ZH | 两方案比较有价值，强调真实差异而非推荐徽章；官网定价需要与 iOS 实际可售方案和试用条件一致 | 选择方案的动作要说明下一步为下载或购买，避免误承诺；免费试用不能跳回当前 pricing 页面形成循环 | 选中/推荐只用一种边界强调，套餐内容保留同等可读性 |
| W04 · 宣言 EN/ZH | 宣言使用有停顿的长文排版，避免每段都加装饰标签；中英正文行长与段距分别检查；中文不机械套英文样式 | 文字链接聚焦后仍可识别，返回入口稳定；宣言末尾提供与内容一致的产品入口 | 长文靠留白组织，分隔线仅服务章节 |
| W05 · 隐私 EN/ZH | 隐私用可检索的事实结构建立信任；联系方式、收集范围与保留规则要易读 | 邮件链接必须能打开系统邮件客户端；读政策后返回来源页面的路径明确 | 表格边线表达字段归属，避免装饰性多层框 |
| W06 · 下载 | 下载页只承担下载决策，不扩张营销装饰；未发布状态需要清楚说明，不展示假 App Store 链接 | 可用入口说明平台和结果，失败有替代路径；支持邮件是联系方式，不能伪装即时下载 | 主要下载 CTA 一个重心，次级支持链接用文字 |
| W07 · 共享 Web 控件 | 共享控件先统一层级和半径再微调皮肤；48px 基础按钮已有合理触达，检查长中文标签 | 通用 focus 可见且按下不导致布局跳动；Button 默认 type 与 form 中提交语义明确 | primary 填色/secondary 描边/ghost 文字已有层级，勿再叠加同权阴影 |
| W08 · /app 地图 | 真实地图优先显示体验与选中地点，保留地图内容呼吸；缩放/marker 不被 banner、语音按钮和抽屉遮挡 | 标记选择、关闭与地图平移不互相误触；定位拒绝后仍可选城市/拖动并理解当前位置 | 每个 marker 目前圆环/分数/置信点较多，需按重要性压低次要描边 |
| W09 · /app 附近和足迹 | 附近是选择清单，足迹是时间序列，两者视觉结构应区别；折叠把手需有明确名称和大目标；短列表不留无意义空白 | Tab 选中、抽屉开合和当前选中体验可感知；重开抽屉保留浏览位置，空态给出可执行恢复 | 行分隔比逐行卡片更安静，选中项单独加强边缘 |
| W10 · /app 今日 | 今日推荐只表达可验证的当下价值；营业/天气等状态没有数据时不写成事实 | 打开建议与关闭推荐均有稳定触达，不互相挤压；关闭后维持关闭偏好，推荐更新不造成惊跳 | 一块轻量背景即可，避免横幅边框争抢地图重心 |
| W11 · /app 语音/文本意图 | 语音是快捷方式，文本仍应始终可用；按钮文案区分开始、录音、停止、发送、失败 | 同时支持 pointer、键盘与辅助技术，拒绝权限有恢复；滑出/取消不能意外提交；识别结果先有明确去向 | 录音态只用一处波形/色彩强调，常态不持续脉冲 |
| W12 · /app 体验详情 | 体验详情先给能否/何时去，再给来源和细节；评分 28px 偏小；内容长时主行动和关闭仍可达 | saving/done 已有分支，但失败不能静默回 idle；评分是否直接签到需要通过文案说明；双击防重复 | 证据信息与行动区分层，避免每个 Section 都被 ring 包围 |
| W13 · /[city] 城市工作台 | 城市工作台可紧凑，但不以 10px 数据标签牺牲旅行可读性；当前多个真实 button 没动作，必须实现或明确演示状态 | 列表、地图 marker、排序、语言切换共享选中反馈；加入计划必须能找到保存结果，+City 需有可用目的地 | 左右面板用分组和留白，选中行才用类别色细边 |
| W14 · 城市命令面板 | 命令面板按任务和城市组织，不暴露 Scenario 编号给普通用户；搜索框具备名称，选中结果和无结果读屏可感知 | 方向键/回车之外，Tab、Esc、焦点恢复形成完整 modal；关闭回原触发点，搜索切换城市保留语言 | 一条选中指示边足够，输入框焦点可见但不堆叠边框 |
| W15 · /mobile-preview | 预览明确是预览，手机壳装饰不挤压实际操作；语言/抽屉/签到目标应按移动触摸而非桌面密度设计 | 签到与提示关闭有可见即时结果；预览本地完成状态与真实账户签到明确区分 | 浮层不同时出现多个强色框，选中/主 CTA 优先 |
| W16 · /experience/[id] 分享体验 | 分享页像一张可行动的旅行页，真实地点内容当主角；来源、时间、限制和地图去向在屏内易读 | 外链/导航/下载均有清楚名称，不能用相同箭头假装同结果；返回城市、打开地图与附近体验形成不迷路路径 | 来源作为安静文字链接，主要导航使用一个重点按钮 |
| W17 · /trip/[slug] 分享行程 | 回顾保留时间与真实站点的顺序感；语言切换、作者/日期/体验数不挤成小字装饰 | 站点可打开且焦点顺序跟时间顺序一致；回顾是分享快照，不能把展示数据当当前实时推荐 | 时间轴本身能分组，不再给每个站点叠一层重边框 |
| I01 · 地图主场景/城市 | 地图和城市名称承担识别，浮层不争抢地图视野；44pt 点击区与 Dynamic Type 分开检验；坐标需可输入负数 | 选城/样式/定位各自有明确状态与失败恢复；城市与地址选择必须保持 canonical 坐标，后退不丢原选择 | 顶部控件只在当前操作时增强边缘，普通描边降低 |
| I02 · 稳定导航/发现 | 三项 dock 与吉祥物问问已形成辨识度；地图/问问/发现的选中状态同时有文字和形状 | 重复点击当前 surface 不应震动，长按语音应可被发现；切换保留对话、草稿、附件与选中体验；发现加载/空态可恢复 | 选中 capsule 一个重心，dock 外框不能与每项都叠强框 |
| I03 · 探索工作流 | 探索是有开始/结束的任务，进度表达要克制；当前阶段、耗时未知与取消结果说清楚 | 取消立即响应，后台阶段变化不可抢夺当前输入焦点；部分结果/网络失败/权限拒绝后允许继续浏览或重试 | 只给活动探索边缘强调，普通地图内容不同时 dim/发光 |
| I04 · 保留对话/历史 | 对话保留连续性，历史列表靠内容与时间识别；折叠层级、拖动把手、键盘和列表滚动要可预测 | 新建/删除/重命名有明确确认与恢复；切换 surface 不清空会话；删除当前会话后落点稳定 | 消息气泡和卡片边缘弱化，输入与当前动作优先 |
| I05 · 对话输入/附件 | 附件加号/文本/发送构成一条清晰输入线；长中文、附件缩略图和键盘不挤压发送/停止 | 发送中的禁用原因、错误重试与附件删除即时可感知；地点上下文可解除；失败保留输入与附件，不强迫重写 | 只在焦点/错误/上传时强调输入边框，避免常态强描边 |
| I06 · 语音 | 录音用波形和时间表达状态，避免装饰性持续动效；录音条需要可访问的停止/取消动作，不只视觉点击 | 按住、松手、上滑取消与自动停止必须显示实际提交结果；权限拒绝可进入设置或文本；后台/消失停止录音 | 录音是唯一高注意力色块，倒计时和取消态互斥展示 |
| I07 · AI 卡片/撤销/诊断 | 推荐卡使用真实体验字段，不给普通地点编号；保存路线与打开地点要区分名称和结果 | 诊断请求能拒绝，撤销有足够可见时间；provisional 内容不能冒充已验证，失败提供恢复动作 | 证据/置信标签是辅助信息，主卡不重复多色框 |
| I08 · 体验卡/预览 | 卡片用地点和一句具体体验建立吸引力；整卡点击与卡内收藏互不冲突，小图标保留44pt区域 | 收藏/取消收藏有明确状态，长按不误触打开；预览→详情→返回保留当前地点和列表位置 | 一层卡片表面足够；标签与次级图标少用独立边框 |
| I09 · 体验详情主动作 | 详情底部保留收藏/问问/去过与加入行程，文字已有帮助；长名字、大字号与 compact 下四动作需真机检查 | secondary .plain 仍需可感知按压；状态变化符合可撤销逻辑；付费返回应继续原来的 Ask 意图，避免再次找入口 | 加入行程是主重心；其他动作安静，不再给每项强描边 |
| I10 · 体验新增/修正/反馈 | 新增和修正像简明表单，避免展示内部编译术语；字段错误贴近字段；必填、字符限制和可选项可见 | 提交中不能重复；失败保留草稿，成功明确保存位置；修正/报告之后能回到同一体验并看到状态 | 仅错误字段/当前选择增强边框，整页无需逐段容器 |
| I11 · 体验分享/导出 | 分享卡服务旅行内容，而非塞满产品徽章；文字、图片比例和背景选择可预览；导出可读 | 渲染/分享 pending、失败重试、复制成功均需反馈；复制/分享/Notion 是不同结果，文案精确 | 预览的纸张边缘与工具区分开，避免卡片套卡片 |
| I12 · 行程列表/创建 | 行程以名称、城市和日期识别；创建流程保持直接；名称/日期/城市错误要可理解，禁用保存需有原因 | 保存后立刻看到新行程；删除可确认或撤销；加入已有/新建两路径成功后返回正确上下文 | 选择态行程用一处勾选与边缘，普通行保持安静 |
| I13 · 行程详情 | 站点顺序就是信息结构，支持直接重排；公开招募条件明确，不让用户点到空 action | 导入收藏给实际新增数量，删除站点有恢复；可见性关闭提示必须真正打开个人资料设置 | 重排手柄/行分隔表达顺序，不给每站多层框 |
| I14 · 路线创建/详情 | 路线只在确有顺序时编号，地图与站点同步；起点/终点/进行中与已完成区分，宿主/参与者角色明确 | 开始、下一站、结束分别给对应状态和取消；活动路线退出后能恢复；站点缺坐标有解释和替代路径 | 当前站/主行动单一强调，已走过站点降低边缘注意力 |
| I15 · 路线招募/申请 | 申请和审批保持事实语气，不包装成社交刺激；步速、人数、截止与身份先读得懂再提交 | 发送/撤回/接受/拒绝皆有 pending 和失败恢复；申请状态变化与消息/路线同步，重复操作幂等 | 危险动作与普通选择区分，拒绝不必给全卡红框 |
| I16 · 同伴发现/安全 | 同伴功能作为次级目的地，不挤压独行主任务；联系前说明可见性、发送范围与安全条款 | 举报/屏蔽/同意有具体结果，拒绝仍能离开；被屏蔽和不可见用户路径一致，后台失败不能显示成功 | 仅风险确认用危险色，普通资料保持安静 |
| I17 · 同伴资料/消息 | 资料尊重匿名与最少输入，消息用自然会话结构；昵称/简介限制与可见性即时可理解 | 保存/发送/邀请加载反馈，网络错误不丢草稿；改可见性后读回状态；会话列表能恢复正确对话 | 输入焦点和未读状态各一处强调，头像不叠装饰框 |
| I18 · 路线分享 | 路线分享让顺序和地理关系优先；样式选择有可读名称，长中文路线名不可截断意义 | 渲染中/分享取消/保存成功均有真实状态；系统 share sheet 失败返回同一预览，邀请与公开分享不同 | 分享预览与底部工具一条边界即可 |
| I19 · 好友入口/邀请/扫码 | 好友码和扫码是工具入口，避免社交 feed 语汇；扫码与手输同等可达，权限拒绝可返回手输 | 复制成功、请求等待/接受/移除反馈明确；请求过期/码无效/重复好友有可执行解释 | 主要扫码/添加入口明确，其余请求状态不争主色 |
| I20 · 我的/权益 | 我的按资料和旅行仪式分组，保持主地图轻量；分段选择需名称；消息未读信息不能只靠颜色 | 设置、关闭、付费入口目标明确；返回上级保留当前分段与滚动，不叠多层 modal | 导航行不额外包胶囊，权益 banner 保留次级权重 |
| I21 · 设置及子页 | 设置采用系统列表，减少每行彩色符号竞争；偏爱/隐藏分类需要按钮与选中语义；仅手势不够 | 即时偏好保存有状态；导出/删除有结果与恢复；隐藏高级项不影响正常偏好；语言切换后状态不丢 | 分组标题和系统分隔线足够，不为每行增加框 |
| I22 · 首次使用/条款 | 首次使用展示一次具体旅行任务，避免连续营销页；跳过/后退可达，大字号和照片权限拒绝仍可继续 | 进度与下一步说明当前行为，条款拒绝不意外接受；跳过不创建假偏好，重开 App 不重复门槛 | 单一主行动与安静跳过，不把所有选项做主色大卡 |
| I23 · 付费 | 付费强调真实权益和周期，不靠推荐徽章施压；VoiceOver 要同时读产品、价格、周期与选中状态 | 购买/恢复进行中和错误清楚；继续免费易点击；StoreKit 返回后恢复原任务，取消购买保持免费 | 选中边框必须配合选中语义和勾选，未选项不需重边框 |
| I24 · 今日/城市工具 | 今日和城市工具表达当下可执行事项，减少仪式层压迫；核实关闭30pt/置信解释32pt需要扩大触达 | 待办勾选/核实提交/日期保存要有真实结果；Visa/基地等数据由用户确认，不把推断写成事实 | 待办、活动和提醒各自层级清晰，不并排多强色框 |
| I25 · 仪式/归档 | 旅行仪式应可选、轻量；真实旅记比印章装饰重要；硬编码英文按钮影响中文完整感，月份/时长单位需本地化 | 生成/埋藏/分享 pending 与失败不丢正文；盲盒允许稍后；胶囊成功显示可再次找到的记录 | 纪念内容一处视觉重心，工具按钮和卡边界退后 |
| I26 · 管理/共享反馈组件 | 共享反馈组件保持统一语气，错误给方向；关闭/重试图标触达与可访问名称一致 | 成功只在落盘或服务器确认后出现，自动消失不抢读屏；管理危险操作确认；空态提供准确恢复路径 | 警告和危险使用语义色，普通 banner 不长期发光 |
| I27 · 信任解释/独行评分 | 信任信息值得解释，但不应像促销徽章；compact 标记小字与固定宽度需看大字号/深色 | 评分说明与置信度 popover 关闭可达，触摸与读屏等价；未知值、无信号与多来源区别；雷达调整读出维度和值 | 非健康 pulse 与高评分 twinkle 同屏可能争抢，优先仅点开后动画 |

## 优先处理的20个基线发现

`Q01–Q18`与`Q20`是已核对源码的功能/语义/输入/色值问题，仍需复现和修复后验收；`Q19`明确是待视觉验证的设计风险。这里保留起始基线，不能据此认定当前并行修改仍有同一问题，也不能自动标记已修复。独立审查报告可以包含其他发现。

| ID / 优先级 | 问题与证据 | 建议与验收 | 基线 source:line |
|---|---|---|---|
| Q01 · P1 | **下载 CTA 指向占位 App Store SKU**：官网导航、Hero 和方案按钮共用占位 ID。 | 统一真实下载落点；未发布时明确状态并提供可用联系/候补入口。 验收：逐个 CTA 到可用目标，且文案准确描述落点。 | `apps/web/src/components/marketing/sections.tsx:19` |
| Q02 · P1 | **移动端营销导航/语言/下载全部隐藏**：菜单与语言/Get App 使用 md 以下 hidden，当前无对应移动替代。 | 提供紧凑菜单，保留语言和主要行动。 验收：320/390px 能进入功能、价格、宣言、语言与下载；Tab 顺序正确。 | `apps/web/src/components/marketing/sections.tsx:52` |
| Q03 · P2 | **Hero 装饰图使用无动作且无名称的 button**：返回与心形 mock 是原生 button，无事件、名称或说明。 | 纯展示改为不可聚焦装饰；若可演示则实现真实状态并标明演示。 验收：键盘不会停在无效装饰按钮；辅助技术不会读出无名称按钮。 | `apps/web/src/components/marketing/DayPageMock.tsx:25` |
| Q04 · P1 | **免费试用链接回到定价页**：Pricing 中的免费试用文案指向 /pricing 或 /zh/pricing，独立定价页上形成自身循环。 | 免费 CTA 打开可用试用/下载路径，保留语言。 验收：从首页和定价页点击免费入口均能开始真实下一步。 | `apps/web/src/components/marketing/sections.tsx:458` |
| Q05 · P1 | **城市工作台 +City 是死按钮**：button 显示 pointer 样式，却没有 onClick/href。 | 实现选城入口或替换为清楚的不可交互预览说明。 验收：点击与键盘激活都有实际、相同的选城结果。 | `apps/web/src/app/[city]/page.tsx:287` |
| Q06 · P1 | **示意图缩放/定位三个按钮无动作**：三种地图工具循环为 button，均没有事件；示意 SVG 不支持真实定位。 | 实现真实缩放/定位或移除工具假象，保留演示说明。 验收：每个展示为可用的地图控件都有可见且诚实的效果。 | `apps/web/src/app/[city]/page.tsx:802` |
| Q07 · P1 | **加入计划主 CTA 无动作**：聚焦体验中的主要填色 button 只有样式，没有点击处理。 | 实现加入并反馈保存结果；展示具体查看入口与撤销。 验收：同一体验不能重复添加；刷新后或指定持久层能找回结果。 | `apps/web/src/app/[city]/page.tsx:1160` |
| Q08 · P1 | **城市体验行和 SVG 标记仅鼠标可达**：体验行 div onClick，无 button/link 语义、tabIndex 和键盘等价；WebLisbonMap g 同样仅 click。 | 使用语义控件或补完整键盘/辅助技术行为，并显示焦点。 验收：Tab/Enter/Space 与鼠标能选择同一体验，读出名称和选中状态。 | `apps/web/src/app/[city]/page.tsx:628` |
| Q09 · P1 | **Web 语音只支持 pointer，正常态没有主动文本入口**：支持 Web Speech 时仅显示按住语音；没有 onClick/onKeyDown，文本只在拒绝或不支持时出现。 | 保留文本输入与键盘可用语音切换，录音可显式取消。 验收：纯键盘可输入需求并发送；录音启停不依赖 pointer。 | `apps/web/src/components/VoiceIntent.tsx:159` |
| Q10 · P1 | **签到失败静默，评分触达过小**：catch 直接回 idle 无错误信息；评分数字 button 仅 h-7 w-7。 | 错误说明并可重试，保留评分；扩大触达且声明评分会立即签到。 验收：模拟非2xx：看到失败/重试且无假成功；触摸评分不误触相邻项。 | `apps/web/src/components/ExperienceSheet.tsx:50` |
| Q11 · P1 | **命令面板缺完整 modal 焦点管理**：有初始 focus、方向键和 Esc，但未圈定 Tab、恢复触发焦点；input 没有显式 label。 | 补框内焦点循环/关闭恢复、搜索框名称和选中项读屏关联。 验收：Tab 不进入背景；Esc 回原触发点；读屏能读查询和当前结果。 | `apps/web/src/components/lisbon/CommandPalette.tsx:169` |
| Q12 · P1 | **行程可见性提示的打开设置 action 为空**：打开个人资料设置的按钮内部只有 Phase 2 注释。 | 直接呈现 CompanionProfileView，编辑后重读可见性并可继续原任务。 验收：关闭可见性→尝试招募→打开设置→调整→返回，流程真实闭环。 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:144` |
| Q13 · P1 | **录音条视觉可停止，VoiceOver 只读标签**：录音条随后 accessibility children ignore，仅 label，缺默认 stop action/按钮语义。 | 为停止与取消提供可访问动作，朗读当前录音状态与结果。 验收：VoiceOver 可单独完成录音→停止/取消→得到预期结果。 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:319` |
| Q14 · P1 | **偏爱分类使用未说明状态的点击手势**：CategoryPreferencesView 的 row 手势无按钮/selected traits；隐藏项移除 xmark 的含义和触达也需补齐。 | 改为语义 Button/Toggle，朗读偏爱/隐藏/普通状态与操作。 验收：VoiceOver 读出分类、当前状态与操作，完成偏爱/隐藏/恢复。 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:945` |
| Q15 · P2 | **经纬度手输键盘缺负号入口**：CoordinateField 使用 decimalPad，常规屏幕键盘没有负号，西经/南纬输入受阻；粘贴/硬件键盘另论。 | 支持带符号小数输入或半球切换，保留范围验证和坐标顺序。 验收：屏幕键盘能输入 Lisbon -9.14、西经与南纬，保存后坐标正确。 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:721` |
| Q16 · P2 | **多个紧凑控件未满足项目44pt触达约定**：核实关闭30×30；ConfidenceBadge 最小高32；SoloScoreBadge 仅内容 padding，未见44pt扩展。 | 保持小视觉图形，同时把语义按钮标签的 hit region 扩大到44pt。 验收：实际命中区至少44×44；相邻目标不重叠，compact 与大字可操作。 | `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift:92` |
| Q17 · P1 | **付费方案读屏隐藏价格周期和选择状态**：productCard Button 覆盖 label 为 displayName，未附 displayPrice、periodLabel、selected value/trait。 | 朗读方案名、价格、周期、试用条件和选中状态，并保留所有方案同等可达。 验收：闭眼用 VoiceOver 能区分每个实际方案和选中项，再确认准确购买信息。 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:298` |
| Q18 · P2 | **原生仪式界面仍有硬编码英文控件**：Capsule 的 Surface in/Cancel，Blindbox 的 Duration/Not now，Omen 的 Mark done，以及 Paywall 周期 /month 等未本地化。 | 按项目双语资源统一按钮、单位和结果文案。 验收：简中环境这些流程无混入英文操作词，英文环境周期/复数自然。 | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:52` |
| Q19 · P2 | **徽章持续动效可能分散体验内容注意力**：非健康 confidence 反复 pulse，高评分 SoloScoreBadge 另有 twinkle/pulse；同屏可能同时争抢。此项为源码设计风险，需视觉实测。 | 把主动动画限制到首次变化或用户展开；静态常态保留语义色和文字。 验收：同屏多个卡片仍能立即识别主要行动；减少动态开启时无残余循环。 | `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift:80` |
| Q20 · P1 | **深色主题主CTA前景复用背景变量导致低对比**：dark media将--bg-warm变为#171410，而--accent仍#5d3000；primary变成深棕底近黑文字，静态颜色比约1.651:1。全局focus使用同accent，在#0f0d0b上约1.744:1。 | 新增语义on-accent固定高对比前景和自适应focus token；不要用页面背景变量作为按钮文字。 验收：深色浏览器截图与computedStyle核对主CTA/所有focus；文字颜色比符合目标且焦点清楚。 | `apps/web/src/components/marketing/primitives.tsx:15` |

## 官网图案与跨端视觉细节

图案不是按钮，单列审查。以下观察与建议源于起始基线；重跑可更新源码定位，仍须根据实际修改复核结论。CSS/token为补充视觉源，不计入上面的UI候选数。

| ID / 对象 | 观察与品味判断 | 运行时验收 | source:line |
|---|---|---|---|
| V01 · Hero氛围：极光shader/罗盘环/120或220粒子 | 已有idle mount、WebGL不可用降级、出视口/减少动态暂停和DPR上限；这些是可保留的节制措施。 | 与标题及手机mock同时截图核实，装饰不降低文字清晰度；测真实帧率前不声称卡顿。 | `apps/web/src/components/marketing/HeroCanvas.tsx:239` |
| V02 · 手机mock：渐变图/信任chips/评分条/热力图 | 图案应说明真实体验结构，明确示例；装饰按钮不能制造操作承诺。 | 中英/深色/320px查看文字与图案；热力图减少动态时静止。 | `apps/web/src/components/marketing/DayPageMock.tsx:47` |
| V03 · 功能示意图：问问/盲盒/胶囊/预兆/BestNow/旅记 | 同一视觉材质可保留，六功能不必各自用新强色/边框。 | 核实示例标签、来源可信度和当前真实能力一致；不把示例AI理由写成可验证事实。 | `apps/web/src/components/marketing/CapabilityMocks.tsx:15` |
| V04 · Hero逐层reveal | 标题逐行、正文、CTA、手机多段延迟与氛围并存，注意力可能过多。 | 首次可用CTA不能依赖漫长入场；开启减少动态完全可见；仅通过实测决定压缩入场。 | `apps/web/src/components/marketing/sections.tsx:不可解析（待人工确认）` |
| V05 · 城市示意图选中/hover光环 | 2.4秒无限循环，基线没有对应prefers-reduced-motion停用分支。 | 减少动态时停用；选中用静态颜色/形状也能识别，避免常态脉冲争抢。 | `apps/web/src/app/globals.css:441` |
| V06 · 字体与中英排版 | 当前Space Grotesk/Inter/JetBrains Mono/Fraunces/中文fallback五角色需节制；数据标签uppercase不适合泛化每段。 | 只保留有信息作用的标签；正文行长、汉字字重和字体加载前后分别核实。 | `apps/web/src/app/globals.css:97` |
| V07 · 城市示意地图：纸纹/等高线/河流/街道/标签 | 与地图主题有关的图案比通用渐变更能表达旅行，但必须继续明确非地理导航示意。 | 低对比纹理不抢marker，选中点/列表关联清楚，键盘仍可选点。 | `apps/web/src/components/lisbon/WebLisbonMap.tsx:141` |
| V08 · 按钮层级/边框/阴影 | primary填色、secondary描边、ghost文字已有层级；不要再给每个普通交互增加强阴影。 | 按下/hover/focus均可辨，减少动态下不位移；dark on-accent见Q20。 | `apps/web/src/components/marketing/primitives.tsx:10` |
| V09 · iOS空间/圆角/材质/阴影 | 已存在4pt空间与语义材质，新增界面优先复用；不做单纯全局换半径。 | 在真正使用点检查token采用与大小层级，不能仅看token定义声称全局统一。 | `apps/ios/SoloCompass/Views/Shared/DesignTokens.swift:21` |
| V10 · iOS颜色与跨端token | 固定明色token和自适应dark token并存；调用方必须与实际背景匹配。 | 实际组合测正文/徽章/禁用态/焦点对比；用语义状态而非为不同卡随意添色。 | `apps/ios/SoloCompass/Views/Shared/CompareTokens.swift:7` |
| V11 · 来源徽章小字/描边 | compact9.5pt、uppercase/字距、fixedSize和独立边界可能降低可读性并增加边缘密度，此处仅为设计风险。 | 大字号、深色、小屏、长来源词实测；扩大内容可读性，不把静态说明变主CTA。 | `apps/ios/SoloCompass/Views/Shared/TrustBadge.swift:66` |
| V12 · 通用按压缩放与触觉 | 默认0.92缩放8%，haptic默认关闭并尊重减少动态；不能为了感觉有交互让所有导航都震动。 | 小标签与大主按钮分别实测按压幅度；提交才触觉确认，取消手势不假报成功。 | `apps/ios/SoloCompass/Views/Shared/PressableButtonStyle.swift:31` |

## 官网 EN / ZH 数据驱动链接展开

以下只列当前源码可解析的标签与href表达式，不执行表达式、不假定下载常量名称或最终落点；缺字段见解析诊断。它们是上述候选的实例说明，不能另加到候选数。

| 实例 / 语言 | 位置 | label | target源码表达式（未执行） |
|---|---|---|---|
| MR-en-001 · en | literal@53 | Solo Compass | `{homePath}` |
| MR-en-002 · en | langSwitch | 中文 | `{altPath}` |
| MR-en-003 · en | hero.ctaSecondary | See how it works | `"#features"` |
| MR-en-004 · en | pricing.free | Or explore the web map first — free, no account | `"/app"` |
| MR-en-005 · en | nav.features | Features | ``${homePath === "/" ? "" : homePath}/#features`` |
| MR-en-006 · en | nav.cities | Cities | ``/lisbon${locale === "en" ? "?lang=en" : ""}`` |
| MR-en-007 · en | nav.pricing | Pricing | `locale === "zh" ? "/zh/pricing" : "/pricing"` |
| MR-en-008 · en | nav.manifesto | Manifesto | `locale === "zh" ? "/zh/manifesto" : "/manifesto"` |
| MR-en-009 · en | footer.Product | Features | `/#features` |
| MR-en-010 · en | footer.Product | Pricing | `/pricing` |
| MR-en-011 · en | footer.Product | Download | `/download` |
| MR-en-012 · en | footer.Company | Manifesto | `/manifesto` |
| MR-en-013 · en | footer.Company | Contact | `mailto:cubxxw@gmail.com` |
| MR-en-014 · en | footer.Legal | Privacy | `https://gist.github.com/kubbot/e177b6ab042c8d5bd79417300031a5c9` |
| MR-en-015 · en | footer.Legal | Terms | `https://gist.github.com/kubbot/08f720b1191b6f9c913699c16227581a` |
| MR-zh-016 · zh | literal@53 | Solo Compass | `{homePath}` |
| MR-zh-017 · zh | langSwitch | English | `{altPath}` |
| MR-zh-018 · zh | hero.ctaSecondary | 看看它是什么样 | `"#features"` |
| MR-zh-019 · zh | pricing.free | 或先玩网页地图 —— 免费，不用账号 | `"/app"` |
| MR-zh-020 · zh | nav.features | 功能 | ``${homePath === "/" ? "" : homePath}/#features`` |
| MR-zh-021 · zh | nav.cities | 城市 | ``/lisbon${locale === "en" ? "?lang=en" : ""}`` |
| MR-zh-022 · zh | nav.pricing | 价格 | `locale === "zh" ? "/zh/pricing" : "/pricing"` |
| MR-zh-023 · zh | nav.manifesto | 宣言 | `locale === "zh" ? "/zh/manifesto" : "/manifesto"` |
| MR-zh-024 · zh | footer.产品 | 功能 | `/zh/#features` |
| MR-zh-025 · zh | footer.产品 | 价格 | `/zh/pricing` |
| MR-zh-026 · zh | footer.产品 | 下载 | `/download` |
| MR-zh-027 · zh | footer.关于 | 宣言 | `/zh/manifesto` |
| MR-zh-028 · zh | footer.关于 | 联系 | `mailto:cubxxw@gmail.com` |
| MR-zh-029 · zh | footer.法律 | 隐私 | `https://gist.github.com/kubbot/e177b6ab042c8d5bd79417300031a5c9` |
| MR-zh-030 · zh | footer.法律 | 用户协议 | `https://gist.github.com/kubbot/08f720b1191b6f9c913699c16227581a` |

## Web route 与组件组合

| route | 页面模块 | 组件集合（含本模块 helper） |
|---|---|---|
| `/download` | `apps/web/src/app/(marketing)/download/page.tsx` | MarketingNav, Section, Container, Eyebrow, ButtonLink, Footer |
| `/manifesto` | `apps/web/src/app/(marketing)/manifesto/page.tsx` | MarketingNav, Section, Container, Eyebrow, Footer |
| `/pricing` | `apps/web/src/app/(marketing)/pricing/page.tsx` | HomeJsonLd, MarketingNav, Section, Container, Eyebrow, Pricing, Footer |
| `/privacy` | `apps/web/src/app/(marketing)/privacy/page.tsx` | MarketingNav, Section, Container, Eyebrow, Footer |
| `/[city]` | `apps/web/src/app/[city]/page.tsx` | WebCategoryId, HTMLButtonElement, TopBar, ListColumn, RightSurface, StatusBar, CommandPalette, Logo, Link, CatChip, ListRow, WebLisbonMap, MapControl, DetailDock, MetaRow |
| `/app` | `apps/web/src/app/app/page.tsx` | Selection, MapView, TodayBanner, VoiceIntent, ExperienceSheet, NearbySheet, Suspense, HomeInner |
| `/experience/[id]` | `apps/web/src/app/experience/[id]/page.tsx` | Record, Metadata, ExperienceView, Link |
| `/mobile-preview` | `apps/web/src/app/mobile-preview/page.tsx` | Set, Link, PhoneFrame, CommandPalette, Suspense, MobilePreviewInner, WebLisbonMap |
| `/` | `apps/web/src/app/page.tsx` | HomeJsonLd, MarketingNav, Hero, Problem, Pillars, Capabilities, Trust, Pricing, Footer |
| `/trip/[slug]` | `apps/web/src/app/trip/[slug]/page.tsx` | Record, Metadata, TripRecap, ShareButton, Link |
| `/zh/manifesto` | `apps/web/src/app/zh/manifesto/page.tsx` | MarketingNav, Section, Container, Eyebrow, Footer |
| `/zh` | `apps/web/src/app/zh/page.tsx` | HomeJsonLd, MarketingNav, Hero, Problem, Pillars, Capabilities, Trust, Pricing, Footer |
| `/zh/pricing` | `apps/web/src/app/zh/pricing/page.tsx` | HomeJsonLd, MarketingNav, Section, Container, Eyebrow, Pricing, Footer |
| `/zh/privacy` | `apps/web/src/app/zh/privacy/page.tsx` | MarketingNav, Section, Container, Eyebrow, Footer |

## 城市 / 分类 / 体验 / 行程动态实例

当前已解析静态数据为2个城市、7个分类、12个体验、1个回顾行程，解析状态：`parsed_static_data_only`。空列表/缺字段不能推断功能消失；下列路径只是数据实例的路由模式，当前控件是否绑定仍需沿候选核实。/app后端数据和原生持久层数量由环境决定。

| 类别 / ID | 中文 / English | 数据候选或路由模式 |
|---|---|---|
| 城市 · lisbon | 里斯本 / Lisbon | `/lisbon` |
| 城市 · porto | 波尔图 / Porto | `/porto` |
| 分类 · miradouro | 观景台 / Viewpoints | 静态分类值；实际切换/清除逻辑需沿当前控件核实。 |
| 分类 · cafe | 咖啡 / Cafés | 静态分类值；实际切换/清除逻辑需沿当前控件核实。 |
| 分类 · food | 吃饭 / Food | 静态分类值；实际切换/清除逻辑需沿当前控件核实。 |
| 分类 · fado | 法多 / Fado | 静态分类值；实际切换/清除逻辑需沿当前控件核实。 |
| 分类 · walk | 散步 / Walks | 静态分类值；实际切换/清除逻辑需沿当前控件核实。 |
| 分类 · hidden | 冷门 / Hidden | 静态分类值；实际切换/清除逻辑需沿当前控件核实。 |
| 分类 · bookshop | 书店 / Bookshops | 静态分类值；实际切换/清除逻辑需沿当前控件核实。 |
| 体验 · miradouro-graca | 在倾斜的城市里等日落 / Watch the city tilt at sunset | 基线路由模式 `/experience/miradouro-graca`，当前绑定未确认 |
| 体验 · pasteis-de-belem | 在发明它的地方吃一只蛋挞 / Eat a pastel where they invented it | 基线路由模式 `/experience/pasteis-de-belem`，当前绑定未确认 |
| 体验 · a-vida-portuguesa | 在百年老店里把每一样东西摸一遍 / Touch every object in a hundred-year shop | 基线路由模式 `/experience/a-vida-portuguesa`，当前绑定未确认 |
| 体验 · tasca-do-chico | 站在一家小酒馆里让法多找到你 / Stand in a tasca and let fado find you | 基线路由模式 `/experience/tasca-do-chico`，当前绑定未确认 |
| 体验 · feira-da-ladra | 周二一早去逛贼市 / Walk the thieves' market on a Tuesday morning | 基线路由模式 `/experience/feira-da-ladra`，当前绑定未确认 |
| 体验 · livraria-bertrand | 在世界上最古老的书店楼上读一会儿 / Read upstairs at the world's oldest bookshop | 基线路由模式 `/experience/livraria-bertrand`，当前绑定未确认 |
| 体验 · tram-28 | 7 点骑 28 路电车，在游客醒之前 / Ride tram 28 at 7am before the tourists wake up | 基线路由模式 `/experience/tram-28`，当前绑定未确认 |
| 体验 · porto-livraria-lello | 在拍照人群到来之前爬上那道红楼梯 / Climb the red staircase before the photographers arrive | 基线路由模式 `/experience/porto-livraria-lello`，当前绑定未确认 |
| 体验 · porto-ribeira-walk | 在金色时分沿杜罗河走一程 / Walk the Douro at golden hour | 基线路由模式 `/experience/porto-ribeira-walk`，当前绑定未确认 |
| 体验 · porto-majestic-cafe | 像 1921 年那样点一份热三明治 / Order a tostada mista like it's 1921 | 基线路由模式 `/experience/porto-majestic-cafe`，当前绑定未确认 |
| 体验 · porto-azulejos | 在瓷砖上读完一个国家的历史 / Read the entire history of a country in tiles | 基线路由模式 `/experience/porto-azulejos`，当前绑定未确认 |
| 体验 · porto-vinho-do-porto | 过河喝一杯波特酒 / Cross the river for a port tasting | 基线路由模式 `/experience/porto-vinho-do-porto`，当前绑定未确认 |
| 行程 · sofia-lisbon-may-2025 | 四天 · 在里斯本 / Four days, in Lisbon | 基线路由模式 `/trip/sofia-lisbon-may-2025`，当前绑定未确认 |

## 逐文件覆盖

候选为零的文件仍列出：静态页面会通过公共导航/CTA 获得交互，纯视觉组件也属于图案与注意力审查范围。

| 文件 | 行数 | 候选 | 类别 |
|---|---:|---:|---|
| `apps/ios/SoloCompass/App/SoloCompassApp.swift` | 386 | 2 | presentation_edge: 1, custom_component_call: 1 |
| `apps/ios/SoloCompass/Views/Admin/ModerationView.swift` | 189 | 4 | gesture_or_semantic_control: 1, presentation_edge: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift` | 747 | 10 | presentation_edge: 1, custom_component_call: 7, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Archive/CityCodexView.swift` | 112 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift` | 102 | 3 | input_control: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Blindbox/BlindboxRecapCard.swift` | 95 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Brag/BragCardTemplateBackground.swift` | 173 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Brag/BragCardView.swift` | 118 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift` | 161 | 7 | input_control: 2, semantic_control: 4, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift` | 127 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift` | 321 | 6 | presentation_edge: 1, gesture_or_semantic_control: 3, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Chat/AttachmentDraftStrip.swift` | 148 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift` | 458 | 13 | semantic_control: 7, presentation_edge: 4, input_control: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/ChatCardStack.swift` | 551 | 2 | gesture_or_semantic_control: 1, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift` | 591 | 8 | semantic_control: 7, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift` | 159 | 8 | semantic_control: 5, presentation_edge: 2, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift` | 885 | 15 | presentation_edge: 4, semantic_control: 7, input_control: 1, gesture_or_semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift` | 2343 | 12 | presentation_edge: 1, semantic_control: 8, gesture_or_semantic_control: 2, custom_component_call: 1 |
| `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift` | 298 | 3 | gesture_or_semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Chat/DiagnosticsRequestCard.swift` | 128 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/HalfExpandedEmptyState.swift` | 245 | 2 | semantic_control: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/InlineBanner.swift` | 182 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Chat/LocalAttachment.swift` | 48 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/MarkdownMessageText.swift` | 201 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift` | 527 | 7 | semantic_control: 4, gesture_or_semantic_control: 1, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Chat/SoloAgentBubbleQueue.swift` | 186 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Chat/SoloOrb.swift` | 91 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/ThinkingBorderShimmer.swift` | 56 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/UndoPill.swift` | 81 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/CityOS/BaseCard.swift` | 279 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/CityOS/BaseFace.swift` | 73 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift` | 546 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/CityOS/CityOSComponents.swift` | 82 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/CityOS/ComplianceBanner.swift` | 105 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/CityOS/EventMarkerView.swift` | 127 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift` | 420 | 7 | semantic_control: 5, presentation_edge: 1, input_control: 1 |
| `apps/ios/SoloCompass/Views/CityOS/LiveSheet.swift` | 223 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift` | 188 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift` | 291 | 8 | semantic_control: 6, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift` | 692 | 7 | semantic_control: 5, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Companion/ChatView.swift` | 464 | 8 | semantic_control: 4, custom_component_call: 2, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Companion/CompanionMapLayer.swift` | 147 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift` | 432 | 8 | presentation_edge: 1, semantic_control: 5, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift` | 214 | 5 | semantic_control: 3, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/CompletionMoment.swift` | 345 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Companion/CompletionMomentFlow.swift` | 101 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Components/AvatarStack.swift` | 195 | 2 | semantic_control: 1, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Companion/Components/RecruitingModule.swift` | 533 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/Components/RouteCard.swift` | 575 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Components/StopsList.swift` | 275 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/Components/VerifiedBadge.swift` | 234 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift` | 308 | 4 | semantic_control: 2, presentation_edge: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift` | 569 | 11 | semantic_control: 9, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift` | 474 | 14 | semantic_control: 7, presentation_edge: 5, custom_component_call: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift` | 200 | 3 | semantic_control: 2, input_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift` | 401 | 5 | presentation_edge: 2, semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift` | 417 | 6 | semantic_control: 5, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift` | 787 | 20 | gesture_or_semantic_control: 1, semantic_control: 12, presentation_edge: 5, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift` | 352 | 13 | semantic_control: 5, presentation_edge: 2, input_control: 6 |
| `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift` | 465 | 12 | semantic_control: 7, presentation_edge: 3, gesture_or_semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift` | 329 | 4 | semantic_control: 2, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/MyHostedRoutesListView.swift` | 212 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/MyRequestsListView.swift` | 358 | 5 | presentation_edge: 2, semantic_control: 2, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/MyWalkedRoutesListView.swift` | 143 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift` | 324 | 10 | semantic_control: 3, input_control: 7 |
| `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift` | 275 | 12 | semantic_control: 8, presentation_edge: 3, input_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift` | 463 | 14 | semantic_control: 8, presentation_edge: 4, gesture_or_semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift` | 940 | 12 | presentation_edge: 6, custom_component_call: 1, semantic_control: 5 |
| `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift` | 295 | 7 | semantic_control: 6, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift` | 192 | 3 | input_control: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteMapSnapshotter.swift` | 74 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RoutePolylineShape.swift` | 90 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteShareCardView.swift` | 360 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteSharePayload.swift` | 140 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteShareRenderer.swift` | 82 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteShareStyle.swift` | 35 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift` | 562 | 14 | semantic_control: 9, presentation_edge: 1, input_control: 4 |
| `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift` | 1146 | 14 | semantic_control: 9, gesture_or_semantic_control: 5 |
| `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift` | 1993 | 32 | gesture_or_semantic_control: 2, semantic_control: 17, presentation_edge: 8, custom_component_call: 5 |
| `apps/ios/SoloCompass/Views/Experience/LocationCard.swift` | 236 | 5 | semantic_control: 4, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Experience/MarkdownShareSheet.swift` | 107 | 5 | semantic_control: 4, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Experience/MicroSurveySheet.swift` | 281 | 5 | semantic_control: 4, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Experience/RecompileFeedSheet.swift` | 202 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift` | 448 | 10 | semantic_control: 8, presentation_edge: 1, input_control: 1 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareCardComponents.swift` | 100 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareCardModel.swift` | 177 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareCardRenderer.swift` | 45 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareCardView.swift` | 350 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift` | 341 | 9 | semantic_control: 8, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift` | 618 | 9 | semantic_control: 7, input_control: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift` | 790 | 8 | gesture_or_semantic_control: 1, semantic_control: 7 |
| `apps/ios/SoloCompass/Views/Friends/AddFriendButton.swift` | 203 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift` | 511 | 15 | input_control: 2, semantic_control: 9, presentation_edge: 3, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Friends/FriendProfileView.swift` | 448 | 4 | custom_component_call: 3, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift` | 510 | 11 | presentation_edge: 2, input_control: 1, gesture_or_semantic_control: 1, semantic_control: 7 |
| `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift` | 860 | 25 | gesture_or_semantic_control: 4, semantic_control: 14, presentation_edge: 6, input_control: 1 |
| `apps/ios/SoloCompass/Views/Friends/QRScannerView.swift` | 261 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Insight/InsightCardView.swift` | 91 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/ActiveRouteOverlay.swift` | 139 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift` | 1181 | 7 | gesture_or_semantic_control: 4, presentation_edge: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Map/CityPickerSheet.swift` | 404 | 5 | semantic_control: 4, input_control: 1 |
| `apps/ios/SoloCompass/Views/Map/ClusterAnnotationView.swift` | 30 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/CompassMapView.swift` | 5099 | 63 | presentation_edge: 17, semantic_control: 20, custom_component_call: 14, gesture_or_semantic_control: 10, runtime_map_control: 1, input_control: 1 |
| `apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift` | 243 | 5 | semantic_control: 4, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift` | 166 | 4 | semantic_control: 2, presentation_edge: 1, custom_component_call: 1 |
| `apps/ios/SoloCompass/Views/Map/ExploreHandoffCard.swift` | 271 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Map/ExploreModeOverlay.swift` | 268 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/ExploreProgressBar.swift` | 67 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/ExploreSessionDimModifier.swift` | 34 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift` | 822 | 29 | input_control: 7, semantic_control: 16, presentation_edge: 4, gesture_or_semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Map/MapCoordinatePresentation.swift` | 114 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/MapPinPickerView.swift` | 110 | 3 | gesture_or_semantic_control: 2, runtime_map_control: 1 |
| `apps/ios/SoloCompass/Views/Map/MarkerIconView.swift` | 485 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift` | 625 | 8 | semantic_control: 6, presentation_edge: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/NearbySectionView.swift` | 686 | 5 | semantic_control: 4, input_control: 1 |
| `apps/ios/SoloCompass/Views/Map/POILoadingBanner.swift` | 162 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/PeekPickResolver.swift` | 80 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift` | 794 | 7 | gesture_or_semantic_control: 3, presentation_edge: 1, semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Map/RoutesSectionView.swift` | 185 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Map/UserLocationMarker.swift` | 57 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/VoiceProcessingToast.swift` | 133 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/WorkspaceDock.swift` | 133 | 4 | custom_component_call: 3, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Me/EntitlementBanner.swift` | 207 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Me/MeSheet.swift` | 615 | 12 | input_control: 1, semantic_control: 9, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Omen/OmenCardView.swift` | 105 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Onboarding/OnboardingCityStep.swift` | 133 | 3 | input_control: 2, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Onboarding/OnboardingCohortStep.swift` | 189 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Onboarding/OnboardingVibeStep.swift` | 231 | 4 | input_control: 2, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift` | 721 | 11 | semantic_control: 10, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift` | 189 | 6 | semantic_control: 5, custom_component_call: 1 |
| `apps/ios/SoloCompass/Views/Ost/OstShareCard.swift` | 80 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift` | 564 | 9 | custom_component_call: 1, semantic_control: 7, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift` | 236 | 4 | semantic_control: 1, input_control: 3 |
| `apps/ios/SoloCompass/Views/Settings/DataSourceSettingsView.swift` | 197 | 3 | input_control: 2, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift` | 491 | 15 | presentation_edge: 2, semantic_control: 10, input_control: 3 |
| `apps/ios/SoloCompass/Views/Settings/NotificationsSettingsView.swift` | 46 | 3 | input_control: 3 |
| `apps/ios/SoloCompass/Views/Settings/SettingsView.swift` | 1434 | 63 | semantic_control: 36, presentation_edge: 11, custom_component_call: 2, input_control: 9, gesture_or_semantic_control: 5 |
| `apps/ios/SoloCompass/Views/Shared/BestNowChipState.swift` | 115 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/BilingualCityRow.swift` | 55 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/BottomInfoBar.swift` | 95 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/ChatStateModifier.swift` | 149 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/Color+Hex.swift` | 14 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/CompareTokens.swift` | 241 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/CompletionCelebrationView.swift` | 221 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift` | 389 | 2 | semantic_control: 1, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Shared/DesignTokens.swift` | 299 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/DismissibleBanner.swift` | 153 | 1 | gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Shared/ExperiencePreviewCard.swift` | 183 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift` | 1791 | 28 | semantic_control: 19, input_control: 2, gesture_or_semantic_control: 4, presentation_edge: 3 |
| `apps/ios/SoloCompass/Views/Shared/FlowLayout.swift` | 79 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/GlassmorphismCapsule.swift` | 161 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/HeartBurstView.swift` | 174 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/HitTargetMetrics.swift` | 16 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/LiveActivityLockScreenPreview.swift` | 208 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/LongPressCardModifier.swift` | 37 | 1 | gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Shared/OfflineBanner.swift` | 203 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Shared/PendingCheckInBanner.swift` | 327 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Shared/PressableButtonStyle.swift` | 63 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SkeletonBadgeView.swift` | 47 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SkeletonView.swift` | 206 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SoloCompassTips.swift` | 69 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SoloEmptyState.swift` | 103 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Shared/SoloMascotView.swift` | 319 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift` | 546 | 3 | semantic_control: 2, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift` | 642 | 8 | gesture_or_semantic_control: 6, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Shared/ToolRouterContractPreview.swift` | 168 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/TrustBadge.swift` | 155 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/UrgencyPulse.swift` | 36 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift` | 581 | 8 | gesture_or_semantic_control: 4, presentation_edge: 2, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Shared/VoiceWaveformView.swift` | 94 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift` | 113 | 6 | input_control: 3, semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Today/TodayContainer.swift` | 280 | 4 | presentation_edge: 2, gesture_or_semantic_control: 1, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Today/TodayNearbyRow.swift` | 128 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Today/TodayNewHomeBanner.swift` | 94 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Today/TodaySealReceipt.swift` | 99 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Today/TodayStatusHeader.swift` | 169 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Today/TodayThreeThings.swift` | 238 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/(marketing)/download/page.tsx` | 115 | 2 | semantic_control: 2 |
| `apps/web/src/app/(marketing)/manifesto/page.tsx` | 106 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/(marketing)/pricing/page.tsx` | 102 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/(marketing)/privacy/page.tsx` | 183 | 1 | semantic_control: 1 |
| `apps/web/src/app/[city]/page.tsx` | 1318 | 23 | custom_component_call: 10, semantic_control: 13 |
| `apps/web/src/app/_seo.tsx` | 68 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/app/page.tsx` | 224 | 6 | custom_component_call: 5, semantic_control: 1 |
| `apps/web/src/app/apple-icon.tsx` | 30 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/experience/[id]/opengraph-image.tsx` | 218 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/experience/[id]/page.tsx` | 665 | 4 | semantic_control: 4 |
| `apps/web/src/app/global-error.tsx` | 69 | 2 | semantic_control: 2 |
| `apps/web/src/app/icon.tsx` | 28 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/layout.tsx` | 51 | 1 | semantic_control: 1 |
| `apps/web/src/app/mobile-preview/page.tsx` | 692 | 10 | semantic_control: 8, custom_component_call: 2 |
| `apps/web/src/app/opengraph-image.tsx` | 63 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/page.tsx` | 82 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/trip/[slug]/opengraph-image.tsx` | 197 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/trip/[slug]/page.tsx` | 499 | 1 | semantic_control: 1 |
| `apps/web/src/app/zh/manifesto/page.tsx` | 107 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/zh/opengraph-image.tsx` | 63 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/zh/page.tsx` | 81 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/zh/pricing/page.tsx` | 100 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/zh/privacy/page.tsx` | 172 | 1 | semantic_control: 1 |
| `apps/web/src/components/DesignNav.tsx` | 46 | 1 | semantic_control: 1 |
| `apps/web/src/components/ExperienceSheet.tsx` | 364 | 8 | custom_component_call: 3, semantic_control: 5 |
| `apps/web/src/components/MapView.tsx` | 327 | 6 | semantic_control: 2, runtime_map_control: 2, imperative_event_handler: 2 |
| `apps/web/src/components/NearbySheet.tsx` | 373 | 10 | semantic_control: 7, custom_component_call: 3 |
| `apps/web/src/components/ShareButton.tsx` | 76 | 1 | semantic_control: 1 |
| `apps/web/src/components/TimelineList.tsx` | 187 | 3 | semantic_control: 2, custom_component_call: 1 |
| `apps/web/src/components/TodayBanner.tsx` | 86 | 2 | semantic_control: 2 |
| `apps/web/src/components/VoiceIntent.tsx` | 277 | 5 | semantic_control: 3, gesture_or_semantic_control: 1, input_control: 1 |
| `apps/web/src/components/lisbon/CommandPalette.tsx` | 449 | 5 | gesture_or_semantic_control: 2, input_control: 1, semantic_control: 1, imperative_event_handler: 1 |
| `apps/web/src/components/lisbon/WebLisbonMap.tsx` | 350 | 1 | semantic_control: 1 |
| `apps/web/src/components/marketing/CapabilityMocks.tsx` | 396 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/components/marketing/Container.tsx` | 25 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/components/marketing/DayPageMock.tsx` | 155 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/components/marketing/HeroCanvas.tsx` | 352 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/components/marketing/HeroMotif.tsx` | 53 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/components/marketing/MobileNav.tsx` | 134 | 5 | semantic_control: 4, imperative_event_handler: 1 |
| `apps/web/src/components/marketing/primitives.tsx` | 193 | 2 | semantic_control: 2 |
| `apps/web/src/components/marketing/sections.tsx` | 584 | 10 | semantic_control: 10 |
| `apps/web/src/lib/analytics.tsx` | 78 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/lib/query-client.tsx` | 21 | 0 | 无直接候选；检查调用组件 |

## 逐项源码清单

所有候选运行时状态均为 **未验证**。`动态`表示条件/循环/绑定线索；表内 action 是源码动作摘录，复杂 callback 仍需沿调用方确认。标签列可能列出复合控件内部的多个名称，机器清单保留可区分的 label 来源。


### `apps/ios/SoloCompass/App/SoloCompassApp.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-fd43522857 · SoloCompassApp · fullScreenCover · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fullScreenCover(item: $firstLaunchCover) | binding: $firstLaunchCover) { cover in | `apps/ios/SoloCompass/App/SoloCompassApp.swift:195` · P1 |
| IC-54914f9f18 · SoloCompassApp · TermsConsentSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onAccept: {; onDecline: { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/App/SoloCompassApp.swift:205` · P1 |

### `apps/ios/SoloCompass/Views/Admin/ModerationView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3669776795 · ModerationView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await service.refreshReports() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Admin/ModerationView.swift:56` · P1 |
| IC-91be26f3c1 · ModerationView · swipeActions · 动态 | 封禁 / 标记已处理 | 呈现/导航声明：.swipeActions(edge: .trailing, allowsFullSwipe: false) | destructive | `apps/ios/SoloCompass/Views/Admin/ModerationView.swift:78` · P1 |
| IC-4c7a39a4e7 · ModerationView · Button · 动态 | 封禁 | 执行：act(.ban(targetUserId: report.targetUserId), id: report.id.rawValue) | destructive | `apps/ios/SoloCompass/Views/Admin/ModerationView.swift:79` · P1 |
| IC-a3f75d5d03 · ModerationView · Button · 动态 | 标记已处理 | 执行：act(.resolveReport(reportId: report.id.rawValue), id: report.id.rawValue) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Admin/ModerationView.swift:84` · P1 |

### `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-2b92974532 · ArchiveView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $ritualsSheet, content: ritualSheetContent(for:)) | binding: $ritualsSheet, content: ritualSheetContent(for:)) | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:96` · P2 |
| IC-860862c122 · ArchiveView · ritualTile · 动态 | 今日灵感 | 复用组件调用：ritualTile(NSLocalizedString("ux.ritual.omen", comment: "Travel ritual"), "sparkles", accent: CT.omenGold, tap: .omen) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:111` · P2 |
| IC-dd1d6de914 · ArchiveView · ritualTile  | 旅行盲盒 | 复用组件调用：ritualTile(NSLocalizedString("ux.ritual.blindbox", comment: "Travel ritual"), "shippingbox.fill", accent: CT.blindboxAmber, tap: .blindbox) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:112` · P2 |
| IC-c7e4290f8d · ArchiveView · ritualTile  | 城市收藏册 | 复用组件调用：ritualTile(NSLocalizedString("ux.ritual.codex", comment: "Travel ritual"), "square.grid.3x3.fill", accent: CT.omenGold, tap: .cityCodex) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:113` · P2 |
| IC-b12b865802 · ArchiveView · ritualTile  | 分享旅行瞬间 | 复用组件调用：ritualTile(NSLocalizedString("ux.ritual.brag", comment: "Travel ritual"), "square.and.arrow.up.on.square.fill", accent: CT.sunGoldDeep, tap: .brag) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:114` · P2 |
| IC-bdfa08d9a5 · ArchiveView · ritualTile  | 旅行配乐 | 复用组件调用：ritualTile(NSLocalizedString("ux.ritual.ost", comment: "Travel ritual"), "music.note", accent: CT.accent, tap: .ost) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:116` · P2 |
| IC-4d2a7a5cb4 · ArchiveView · ritualTile  | 每月回顾 | 复用组件调用：ritualTile(NSLocalizedString("ux.ritual.insight", comment: "Travel ritual"), "chart.bar.doc.horizontal.fill", accent: CT.sunGold, tap: .insight) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:117` · P2 |
| IC-43b79f6cba · ArchiveView · ritualTile  | 打开时光胶囊 | 复用组件调用：ritualTile(NSLocalizedString("ux.ritual.capsule", comment: "Travel ritual"), "envelope.open.fill", accent: CT.capsuleGlow, tap: .capsuleOpen) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:119` · P2 |
| IC-063c8edbe3 · ArchiveView · Button  | 动态 label/无显式名称：需复核 | 执行：ritualsSheet = tap | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:130` · P2 |
| IC-83344268da · RitualPreviewScaffold · Button  | 关闭 | 执行：onClose | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:709` · P2 |

### `apps/ios/SoloCompass/Views/Archive/CityCodexView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-104adb62b4 · CityCodexView · Button  | Unlock | 执行：onUpsell | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/CityCodexView.swift:89` · P2 |

### `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-18c1c52948 · BlindboxLaunchView · Picker · 动态 | 时长 | 编辑/选择绑定：$selected | binding: $selected | `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift:59` · P2 |
| IC-b070d31ad4 · BlindboxLaunchView · Button · 动态 | 开启 | 执行：{ onLaunch(selected | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift:76` · P2 |
| IC-3373658f35 · BlindboxLaunchView · Button  | 暂不 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift:88` · P2 |

### `apps/ios/SoloCompass/Views/Blindbox/BlindboxRecapCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-32697bc98d · BlindboxRecapCard · Button · 动态 | Share | 执行：onShare | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Blindbox/BlindboxRecapCard.swift:66` · P2 |

### `apps/ios/SoloCompass/Views/Brag/BragCardView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-57f343dcca · BragCardView · Button · 动态 | 分享 / 分享这张卡片 | 执行：onShare | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Brag/BragCardView.swift:55` · P2 |
| IC-62ca61fac5 · BragCardView · Button · 动态 | 壁纸 / 保存卡片用作壁纸 | 执行：onWallpaper | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Brag/BragCardView.swift:61` · P2 |

### `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-285ad800e7 · CapsuleComposeView · TextEditor  | 写给未来自己的笔记 | 编辑/选择绑定：$text | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:64` · P2 |
| IC-8bc502f44d · CapsuleComposeView · Picker · 动态 | 开启时间 / %d 个月 | 编辑/选择绑定：$months | binding: $months) { | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:75` · P2 |
| IC-5ba029bc1f · CapsuleComposeView · Button · 动态 | 埋下 | 执行：bury | disabled(!canBury) | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:95` · P2 |
| IC-27e122f33e · CapsuleComposeView · Button · 动态 | 取消 | 执行：if isDirty { showCancelConfirm = true } else { onCancel() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:111` · P2 |
| IC-8ad34cb858 · CapsuleComposeView · confirmationDialog · 动态 | 丢弃这条笔记？ / 丢弃 / 继续编辑 / 这条笔记还没有埋下。 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("capsule.compose.discard.title", comment: "Discard this note?"), isPresented: $showCancelConfirm, titleVisibility: .visible ) | binding: $showCancelConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:121` · P2 |
| IC-c518533297 · CapsuleComposeView · Button · 动态 | 丢弃 | 执行：onCancel() | destructive | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:126` · P2 |
| IC-9492bd4ce3 · CapsuleComposeView · Button · 动态 | 继续编辑 | 执行： | cancel | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:129` · P2 |

### `apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-288bd275ca · CapsuleOpenView · Button · 动态 | 给未来的自己回信 | 执行：onReply | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift:91` · P2 |
| IC-6d396bcc9b · CapsuleOpenView · Button  | 关闭 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift:100` · P2 |

### `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-817a5e9d87 · AttachmentBubble · fullScreenCover · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fullScreenCover(item: $zoomURL) | binding: $zoomURL) { wrapped in | `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift:37` · P1 |
| IC-3a45a3eceb · ResolvedThumbnail · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：onTap(url) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift:105` · P1 |
| IC-1e6c2c26eb · ResolvedThumbnail · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：Task { await resolve() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift:121` · P1 |
| IC-8912c3769b · FileCard · Button · 动态 | doc.fill | 执行：if let url { openURL(url) } else if !resolving { Task { await resolve() } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift:175` · P1 |
| IC-b9c02aadc8 · ZoomImageView · gesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.gesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift:261` · P1 |
| IC-7111c30820 · ZoomImageView · Button · 动态 | 关闭附件 | 执行：onClose | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift:278` · P1 |

### `apps/ios/SoloCompass/Views/Chat/AttachmentDraftStrip.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-8fd2b77d17 · AttachmentDraftStrip · Button  | 移除附件 | 执行：onRemove(id) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentDraftStrip.swift:107` · P1 |

### `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-44c8301f81 · AttachmentInputBar · Button · 动态 | 仅重试附件 | 执行：retryFailedAttachments | disabled(isSending \|\| isSubmitInFlight) | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:101` · P1 |
| IC-acb2b2f663 · AttachmentInputBar · confirmationDialog · 动态 | 添加附件 / 相册 / 相机 / 文件 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("chat.attachment.add.title", comment: "Add attachment"), isPresented: $showAttachmentDialog, titleVisibility: .visible ) | binding: $showAttachmentDialog,; cancel | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:136` · P1 |
| IC-0f2ad82b3c · AttachmentInputBar · Button  | 相册 | 执行：showPhotosPicker = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:141` · P1 |
| IC-c876b4641b · AttachmentInputBar · Button · 动态 | 相机 | 执行：showCamera = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:145` · P1 |
| IC-ffb67d5173 · AttachmentInputBar · Button · 动态 | 文件 | 执行：showFileImporter = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:149` · P1 |
| IC-84f4ce5d90 · AttachmentInputBar · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:152` · P1 |
| IC-b4f4b35f93 · AttachmentInputBar · photosPicker · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.photosPicker( isPresented: $showPhotosPicker, selection: $photoSelections, maxSelectionCount: 5, matching: .images ) .onChange(of: photoSelections) | binding: $showPhotosPicker,; binding: $photoSelections,; binding: $showCamera) {; binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:154` · P1 |
| IC-fcba9964eb · AttachmentInputBar · fullScreenCover · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fullScreenCover(isPresented: $showCamera) | binding: $showCamera) {; binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:163` · P1 |
| IC-262f576a86 · AttachmentInputBar · fileImporter · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fileImporter( isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true ) | binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:169` · P1 |
| IC-3000195e03 · AttachmentInputBar · Button · 动态 | 添加附件 | 执行：showAttachmentDialog = true | disabled(isSending \|\| isSubmitInFlight) | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:190` · P1 |
| IC-4c8e338428 · AttachmentInputBar · TextField  | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$draftText | disabled(isSending \|\| isSubmitInFlight) | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:212` · P1 |
| IC-d02721923f · AttachmentInputBar · onSubmit  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onSubmit(submitDraft) | disabled(isSending \|\| isSubmitInFlight) | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:226` · P1 |
| IC-9b12f4443c · AttachmentInputBar · Button · 动态 | 发送 | 执行：submitDraft | disabled(!canSend) | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:235` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatCardStack.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-c8fdb4bcbb · ProvisionalCardRow · gesture  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.gesture(swipeGesture) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardStack.swift:161` · P1 |
| IC-35ce3d6d0c · ReasoningSummaryChip · Button · 动态 | checkmark | 执行：guard summary.hasDetail else { return } Haptics.impact(.light) withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { expanded.toggle() } | disabled(!summary.hasDetail); reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatCardStack.swift:433` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-e72b8501ad · ChatExperienceCard · Button  | 在地图上打开 %@ | 执行：onTap | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:51` · P1 |
| IC-06401b098a · ChatExperienceCard · Button  | 展开这个地点的更多信息 | 执行：withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) { expanded.toggle() } Haptics.impact(.light) | reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:93` · P1 |
| IC-a34fc55b60 · ChatRouteProposalCard · alert · 动态 | 路线未能保存。提案仍保留在这里，请重试。 / 好的 | 呈现/导航声明：.alert(NSLocalizedString("chat.route.saveFailed", comment: "Route save failure"), isPresented: $saveError) | binding: $saveError) {; cancel | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:266` · P1 |
| IC-aa05f7d358 · ChatRouteProposalCard · Button · 动态 | 好的 | 执行： | cancel | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:267` · P1 |
| IC-14cde7b2ff · ChatRouteProposalCard · Button · 动态 | \(index + 1). \(stop.title) | 执行：onTapStop(stop) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:384` · P1 |
| IC-3da364a248 · ChatRouteProposalCard · Button · 动态 | 保存并查看路线 / 双击保存并打开这条路线 | 执行：do { let store = RouteStore(context: modelContext) if store.get(route.id) == nil { try store.savePersisted(route) } onAdopt() } catch { saveError = true } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:411` · P1 |
| IC-ca53d270d8 · ChatRouteProposalCard · Button · 动态 | 已收藏 / 收藏 | 执行：do { let store = RouteStore(context: modelContext) if store.get(route.id) == nil { try store.savePersisted(route) } _ = preferences.toggleRouteFavorite(route.id.rawValue) Haptic | disabled(saved) | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:429` · P1 |
| IC-29ea216185 · ChatWebSourceCard · Button  | 来源 %1$d：%2$@，来自 %3$@ | 执行：{ | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:531` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-51633b8592 · ChatHistoryListView · Button · 动态 | 完成 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:44` · P1 |
| IC-80f5b8997c · ChatHistoryListView · confirmationDialog · 动态 | 删除选中的对话？此操作无法撤销。 / 删除 / 取消 / 未能删除对话，记录仍保留在历史中，请重试。 / 好的 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("chat.history.delete.confirm", comment: "Delete selected conversations?"), isPresented: Binding(get: | binding: Binding(get: { !pendingDeletionIds.isEmpty }, set: { if !$0 { pendingDeletionIds = [] } }),; destructive; cancel | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:50` · P1 |
| IC-76c2ee772c · ChatHistoryListView · Button · 动态 | 删除 | 执行：let ids = pendingDeletionIds pendingDeletionIds = [] do { for id in ids { try store.deletePersisted(sessionId: id) } Haptics.impact(.soft) } catch { deleteFailed = true } reload | destructive | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:55` · P1 |
| IC-829493939f · ChatHistoryListView · Button · 动态 | 取消 | 执行：pendingDeletionIds = [] | cancel | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:66` · P1 |
| IC-998d7296d6 · ChatHistoryListView · alert · 动态 | 未能删除对话，记录仍保留在历史中，请重试。 / 好的 | 呈现/导航声明：.alert(NSLocalizedString("chat.history.delete.failed", comment: "Conversation could not be deleted. Try again."), isPresented: $deleteFailed) | binding: $deleteFailed) {; cancel | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:68` · P1 |
| IC-43cb729fdb · ChatHistoryListView · Button · 动态 | 好的 | 执行： | cancel | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:69` · P1 |
| IC-d0cc6edd32 · ChatHistoryListView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：let restored = store.messages(sessionId: session.id) onSelect(session.id, restored, session.scopedExperienceId) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:76` · P1 |
| IC-bd6f70956d · ChatHistoryListView · onDelete · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onDelete(perform: deleteRows) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:84` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-57b615cb88 · ChatInputBar · confirmationDialog · 动态 | 添加附件 / 相册 / 相机 / 文件 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("chat.attachment.add.title", comment: "Add attachment"), isPresented: $showAttachmentDialog, titleVisibility: .visible ) | binding: $showAttachmentDialog,; cancel | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:186` · P1 |
| IC-cda5fab513 · ChatInputBar · Button · 动态 | 相册 | 执行：showPhotosPicker = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:191` · P1 |
| IC-d8e99d4cf5 · ChatInputBar · Button · 动态 | 相机 | 执行：showCamera = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:195` · P1 |
| IC-c649811d53 · ChatInputBar · Button · 动态 | 文件 | 执行：showFileImporter = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:199` · P1 |
| IC-51b80a4ba5 · ChatInputBar · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:202` · P1 |
| IC-0a2b8eeac9 · ChatInputBar · photosPicker · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.photosPicker( isPresented: $showPhotosPicker, selection: $photoSelections, maxSelectionCount: 5, matching: .images ) .onChange(of: photoSelections) | binding: $showPhotosPicker,; binding: $photoSelections,; binding: $showCamera) {; binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:204` · P1 |
| IC-843f49f586 · ChatInputBar · fullScreenCover · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fullScreenCover(isPresented: $showCamera) | binding: $showCamera) {; binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:213` · P1 |
| IC-fb6104969f · ChatInputBar · fileImporter · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fileImporter( isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true ) | binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:219` · P1 |
| IC-02aa48fbdf · ChatInputBar · Button · 动态 | 松开发送 / 录音中 — 已 %@ / 停止录音并发送语音消息。 | 执行：onMicToggle(false) | reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:295` · P1 |
| IC-ebad26339e · ChatInputBar · Button · 动态 | 添加附件 | 执行：showAttachmentDialog = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:411` · P1 |
| IC-8e57ef6061 · ChatInputBar · TextField · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$draftText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:444` · P1 |
| IC-3aa9bdfaf6 · ChatInputBar · onSubmit · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onSubmit(submitDraft) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:471` · P1 |
| IC-d2eb5b2db2 · ChatInputBar · Button · 动态 | 发送 | 执行：submitDraft | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:508` · P1 |
| IC-a36fa23573 · ChatInputBar · gesture · 动态 | 语音 / 点击开始/停止语音，长按推按说话 | 源码动作需沿调用方确认：.gesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:572` · P1 |
| IC-9d60af7813 · ChatInputBar · accessibilityAction · 动态 | 语音 / 点击开始/停止语音，长按推按说话 | 执行：onMicToggle(micState != .listening) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:612` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4ab615e6c3 · ChatSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showHistory) | binding: $showHistory) { | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:260` · P1 |
| IC-1231b48198 · ChatSheet · Button · 动态 | 打开聊天历史 | 执行：showHistory = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:428` · P1 |
| IC-16550633ca · ChatSheet · Button · 动态 | 收起对话，回到地图 | 执行：{ | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:444` · P1 |
| IC-b0b9583d2b · ChatSheet · Button · 动态 | 关闭 | 执行：closeSheet | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:460` · P1 |
| IC-08da51efa6 · ChatSheet · simultaneousGesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:671` · P1 |
| IC-8056787fe7 · ChatSheet · Button · 动态 | 最新 / 有新回复，跳到最新消息 | 执行：#if canImport(UIKit) Haptics.selection() #endif workspace.beginFollowing() scrollToBottom(proxy: proxy) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:793` · P1 |
| IC-d1ac37aff9 · ChatSheet · VoiceMicButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onPress: { handleMicPress(true) },; onRelease: { handleMicPress(false) } | isListening | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:859` · P1 |
| IC-8497f6e704 · ChatSheet · Button · 动态 | 点击改为文字输入 | 执行：switchToTextMode | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:867` · P1 |
| IC-8d2c8c01d0 · ChatSheet · Button · 动态 | 先选一个城市 | 执行：#if canImport(UIKit) Haptics.selection() #endif onChooseCity() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:962` · P1 |
| IC-61ccce05df · ChatSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) _ = handleSend(NSLocalizedString(intent.promptKey, comment: "Place opener")) | reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:1290` · P1 |
| IC-44ac0b6a24 · ChatSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) _ = handleSend(prompt) | reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:1331` · P1 |
| IC-e5c8fb0bef · VoiceMicButton · onLongPressGesture · 动态 | 长按与 Solo Compass 说话 / 双击并长按以说话 | 源码动作需沿调用方确认：.onLongPressGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:2231` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-a80fe42e97 · ConversationPanel · onTapGesture · 动态 | 对话面板 / 上下拖动，调整对话与地图的比例 | 执行：toggleDetent() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift:141` · P1 |
| IC-c4a75c5426 · ConversationPanel · gesture · 动态 | 对话面板 / 上下拖动，调整对话与地图的比例 | 源码动作需沿调用方确认：.gesture(grabberDrag) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift:142` · P1 |
| IC-1604dfe3dd · ConversationPanel · accessibilityAction · 动态 | 动态 label/无显式名称：需复核 | 执行：toggleDetent() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift:157` · P1 |

### `apps/ios/SoloCompass/Views/Chat/HalfExpandedEmptyState.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-f8b0424e52 · HalfExpandedEmptyState · Button · 动态 | arrow.up.right | 执行：Haptics.impact(.light) onSendPrompt(suggestion.fullPrompt) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/HalfExpandedEmptyState.swift:122` · P1 |
| IC-3e9a12772a · HalfExpandedEmptyState · onLongPressGesture  | 按住对 Solo 说话 | 源码动作需沿调用方确认：.onLongPressGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/HalfExpandedEmptyState.swift:196` · P1 |

### `apps/ios/SoloCompass/Views/Chat/InlineBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-38c9c9ce4a · InlineBanner · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：onCTA | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/InlineBanner.swift:92` · P1 |
| IC-ee03e1b8cc · InlineBanner · Button · 动态 | 关闭 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/InlineBanner.swift:107` · P1 |

### `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-1ea14287a3 · MessageBubble · Button  | 展开完整消息 | 执行：withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { isExpanded = true } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift:108` · P1 |
| IC-8b33962c8d · MessageBubble · accessibilityAction · 动态 | 复制 | 执行：copyText() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift:154` · P1 |
| IC-e9df0ecb9b · MessageBubble · contextMenu · 动态 | 复制 | 呈现/导航声明：.contextMenu | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift:157` · P1 |
| IC-e2297068f2 · MessageBubble · Button · 动态 | 复制 | 执行：copyText() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift:159` · P1 |
| IC-de575546cb · MessageBubble · Button · 动态 | 收起消息 | 执行：withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { isExpanded = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift:171` · P1 |
| IC-5f565f9892 · MessageBubble · contextMenu · 动态 | 复制 | 呈现/导航声明：.contextMenu | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift:234` · P1 |
| IC-718909f116 · MessageBubble · Button · 动态 | 复制 | 执行：copyText() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift:236` · P1 |

### `apps/ios/SoloCompass/Views/Chat/SoloAgentBubbleQueue.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-bae4353a1d · SoloAgentBubbleView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：onTapCTA(bubble) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/SoloAgentBubbleQueue.swift:119` · P1 |
| IC-f142996736 · SoloAgentBubbleView · Button  | 关掉 | 执行：withAnimation(.easeOut(duration: 0.2)) { queue.dismiss(id: bubble.id) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/SoloAgentBubbleQueue.swift:144` · P1 |

### `apps/ios/SoloCompass/Views/Chat/UndoPill.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-14e7090eba · UndoPill · Button · 动态 | 撤回 · %ds / 撤回这张卡片，%d 秒后确认 / 双击可在卡片落定前撤回 | 执行：{ | reduceMotion | `apps/ios/SoloCompass/Views/Chat/UndoPill.swift:26` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/BaseCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-59518b1371 · BaseCard · Button  | %@ · 基地 / 进入基地 | 执行：Haptics.impact(.light) onOpen() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/BaseCard.swift:34` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-a76f9f7f96 · BasePanelSheet · Button  | 完成 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift:85` · P1 |
| IC-0f9eeee821 · SectionCard · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：trailing.1() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift:452` · P1 |
| IC-ffa75b1c21 · PanelRow · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift:498` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/ComplianceBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3a91bea5b2 · ComplianceBanner · Button  | 处理 | 执行：onHandle | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/ComplianceBanner.swift:26` · P1 |
| IC-9b13cad4d4 · ComplianceBanner · Button  | 关闭 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/ComplianceBanner.swift:38` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/EventMarkerView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-da24287a17 · EventMarkerView · Button  | 动态 label/无显式名称：需复核 | 执行：onTap | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/EventMarkerView.swift:44` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-fbe9eff82d · KitSheet · Button · 动态 | 完成 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:85` · P1 |
| IC-a486b9da8f · KitRowCard · Button · 动态 | 已备，点按取消 / 标记已备 | 执行：Haptics.impact(.light) onToggleTick() | isSelected | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:199` · P1 |
| IC-d2a839d97b · KitRowCard · Button · 动态 | 打开 %@ | 执行：Haptics.impact(.light) onOpenLink(url, label) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:266` · P1 |
| IC-37ca27b002 · KitRowCard · Link · 动态 | 拨打 %1$@ %2$@ | 执行：HStack(spacing: 8) { Image(systemName: "phone.fill") .font(.system(size: 12, weight: .semibold)) Text(entry.label) .ctBody(13, .medium) Spacer(minLength: 0) Text(entry.number) . | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:296` · P1 |
| IC-3f1c24e3db · VisaComplianceControl · Button · 动态 | 填入境日 / 修改倒计时 | 执行：showsSetup = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:352` · P1 |
| IC-4149cd4a59 · VisaComplianceControl · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showsSetup) | binding: $showsSetup) { | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:372` · P1 |
| IC-075bcd55e3 · VisaComplianceControl · Toggle  | 到期提醒 | 编辑/选择绑定：$preferences.visaReminderEnabled | binding: $preferences.visaReminderEnabled) { | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:391` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/LiveSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-fa24e5fd5d · LiveSheet · Button · 动态 | 完成 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/LiveSheet.swift:50` · P1 |
| IC-951ac4d23d · LiveEventCard · Button · 动态 | 在地图上看 / 在地图上查看 %@ | 执行：Haptics.impact(.light) onShowOnMap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/LiveSheet.swift:188` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-30a0727ed3 · VerifySheet · Button  | 关闭 | 执行：Haptics.selection() onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift:94` · P1 |
| IC-70cad5c399 · VerifySheet · Button · 动态 | 已选择 | 执行：action | isSelected | `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift:132` · P1 |
| IC-450816edc9 · VerifySheet · Button  | 未能保存，你的答案仍在这里，请重试。 / 提交印证 | 执行：saveError = nil do { try onSubmit(answers) Haptics.notify(.success) onDismiss() } catch { saveError = NSLocalizedString("notes.save.failed", value: "Couldn’t save. Your answers  | disabled(!answers.isComplete) | `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift:158` · P1 |

### `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-71706785e9 · AddToItinerarySheet · Button · 动态 | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:92` · P1 |
| IC-ab097aa0af · AddToItinerarySheet · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(isPresented: isCreating) | binding: isCreating) { | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:95` · P1 |
| IC-f80a4980c4 · AddToItinerarySheet · alert · 动态 | 无法加入行程 / 重试 / 好 | 呈现/导航声明：.alert( NSLocalizedString("itinerary.addTo.error.title", comment: "Error alert title when pinning fails"), isPresented: Binding( get: | binding: Binding(; errorMessage; cancel | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:113` · P1 |
| IC-1e3a74eb0c · AddToItinerarySheet · Button · 动态 | 重试 | 执行：let message = saveErrorMessage ?? model.errorMessage saveErrorMessage = nil model.clearError() if message != nil, let target = model.itineraries.first(where: { $0.id == lastAtte | errorMessage | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:120` · P1 |
| IC-0a15d6aaca · AddToItinerarySheet · Button · 动态 | 好 | 执行：saveErrorMessage = nil model.clearError() | cancel | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:128` · P1 |
| IC-33e4e0ca0f · AddToItinerarySheet · Button · 动态 | 已在该行程中 / 添加到《%@》 | 执行：guard !alreadyAdded, !isSaving else { return } addExisting(itin) | disabled(alreadyAdded \|\| isSaving); isSaving | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:157` · P1 |
| IC-a15cb0ec0e · AddToItinerarySheet · Button · 动态 | 新建行程 | 执行：model.beginCreation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:199` · P1 |
| IC-31e8565a20 · AddToItinerarySheet · Button  | 先创建一个行程 | 执行：model.beginCreation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:230` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-1dcb69e336 · ApprovalQueueView · Button · 动态 | 本机添加好友 / 在本机将好友添加到此路线 | 执行：Haptics.impact(.light) showInviteFriends = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:68` · P1 |
| IC-5a9ebeb400 · ApprovalQueueView · sheet · 动态 | 申请未更新 / 重试 / 好 | 呈现/导航声明：.sheet(isPresented: $showInviteFriends, onDismiss: reloadRoute) | binding: $showInviteFriends, onDismiss: reloadRoute) {; binding: Binding(; cancel | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:83` · P1 |
| IC-45189a0e5d · ApprovalQueueView · alert · 动态 | 申请未更新 / 重试 / 好 | 呈现/导航声明：.alert( NSLocalizedString("approval.queue.error.title", comment: "Accept/decline failure alert title"), isPresented: Binding( get: | binding: Binding(; cancel | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:91` · P1 |
| IC-e3aa2a8128 · ApprovalQueueView · Button · 动态 | 重试 | 执行：let request = failedRequest let isAccept = failedActionIsAccept actionErrorText = nil failedRequest = nil guard let request else { return } if isAccept { accept(request) } else  | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:98` · P1 |
| IC-331c1c0ca4 · ApprovalQueueView · Button · 动态 | 好 | 执行：actionErrorText = nil failedRequest = nil | cancel | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:110` · P1 |
| IC-92d0dba5e4 · ApprovalQueueView · Button · 动态 | 拒绝 | 执行：decline(request) | disabled(processingRequestId != nil) | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:188` · P1 |
| IC-69a1295736 · ApprovalQueueView · Button · 动态 | 接受 | 执行：accept(request) | disabled(processingRequestId != nil) | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:198` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ChatView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-70e9202740 · ChatView · Menu · 动态 | 举报或屏蔽 | 执行：AddFriendButton( recipientId: otherId, source: .companionChat, style: .inline ) Button(role: .destructive) { showingReportSheet = true } label: { Label( NSLocalizedString("compa | destructive | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:71` · P1 |
| IC-ad9f001be0 · ChatView · AddFriendButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：AddFriendButton( recipientId: otherId, source: .companionChat, style: .inline ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:75` · P1 |
| IC-990908b030 · ChatView · Button · 动态 | 举报或屏蔽 | 执行：showingReportSheet = true | destructive | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:80` · P1 |
| IC-36b53560aa · ChatView · sheet · 动态 | 聊天 / 消息发送失败 / 好的 | 呈现/导航声明：.sheet(isPresented: $showingReportSheet) | binding: $showingReportSheet) { | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:95` · P1 |
| IC-31ab0cd5c2 · ChatView · alert · 动态 | 消息发送失败 / 好的 | 呈现/导航声明：.alert( NSLocalizedString("companion.chat.error.title", comment: "Chat error title"), isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:117` · P1 |
| IC-a97ef24eb8 · ChatView · Button · 动态 | 好的 | 执行：service.lastError = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:124` · P1 |
| IC-23b0ff30ac · ChatView · NavigationLink · 动态 | 已置顶路线 | 执行：RouteDetailView(route: route) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:136` · P1 |
| IC-636e94deee · ChatMessageRow · AddFriendButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：AddFriendButton( recipientId: message.senderId, source: .routeGroup, style: .compact ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:263` · P1 |

### `apps/ios/SoloCompass/Views/Companion/CompanionMapLayer.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-941dfa1593 · CompanionLayerToggle · Button · 动态 | 同伴已开 / 同伴已关 / 同伴图层已开启 / 同伴图层已关闭 / 请先开启在线状态才能使用同伴图层 | 执行：guard !isDisabled else { return } isLayerOn.toggle() | disabled(isDisabled) | `apps/ios/SoloCompass/Views/Companion/CompanionMapLayer.swift:44` · P1 |

### `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-9f0034952d · MyProfileEditView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(isPresented: $showAllWalked) | binding: $showAllWalked) { | `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift:74` · P1 |
| IC-7d188f2288 · MyProfileEditView · Button  | 更换表情符号头像 | 执行：showingEmojiPicker.toggle() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift:98` · P1 |
| IC-588dcf53d7 · MyProfileEditView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：preferences.companionAvatarEmoji = emoji showingEmojiPicker = false | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift:116` · P1 |
| IC-bd2b714c05 · MyProfileEditView · TextField · 动态 | 别人看到的名字（如 wanderer） | 编辑/选择绑定：$handleDraft | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift:170` · P1 |
| IC-616135426d · MyProfileEditView · TextField · 动态 | 简单介绍你的独行旅行风格… | 编辑/选择绑定：prefs.companionBio | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift:204` · P1 |
| IC-7990303615 · MyProfileEditView · Button · 动态 | checkmark | 执行：if currentCodes.contains(lang.code) { preferences.companionLanguages.removeAll { $0 == lang.code } } else { preferences.companionLanguages.append(lang.code) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift:230` · P1 |
| IC-4c2124205d · MyProfileEditView · Button · 动态 | 查看全部 → | 执行：showAllWalked = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift:275` · P1 |
| IC-74e40f01ed · MyProfileEditView · Button · 动态 | checkmark.circle.fill | 执行：preferences.companionVisibility = option | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift:306` · P1 |

### `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-08d82c03c0 · CompanionSafetyConsentSheet · Button  | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift:44` · P1 |
| IC-20073966c0 · CompanionSafetyConsentSheet · Toggle  | 我已年满 18 岁 | 编辑/选择绑定：$ageConfirmed | binding: $ageConfirmed) { | `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift:150` · P1 |
| IC-edbfbac8d2 · CompanionSafetyConsentSheet · Toggle  | 我已了解并会遵守以上规则 | 编辑/选择绑定：$safetyConfirmed | binding: $safetyConfirmed) { | `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift:156` · P1 |
| IC-9ae1d9432b · CompanionSafetyConsentSheet · Button  | 接受并继续 | 执行：preferences.acceptCompanionConsent() onAccepted() dismiss() | disabled(!ageConfirmed \|\| !safetyConfirmed) | `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift:172` · P1 |
| IC-d4b52d88f5 · CheckmarkToggleStyle · Button  | 动态 label/无显式名称：需复核 | 执行：configuration.isOn.toggle() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift:191` · P1 |

### `apps/ios/SoloCompass/Views/Companion/CompletionMoment.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-d8454840bf · CompletionMoment · Button  | 标记完成 | 执行：Task { await flow.confirmCompletion() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompletionMoment.swift:121` · P1 |
| IC-0c9dea93ce · CompletionMoment · Button  | 重试 | 执行：Task { await flow.confirmCompletion() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompletionMoment.swift:172` · P1 |
| IC-1e429eaf10 · CompletionMoment · Button  | 关闭 | 执行：dismiss() onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompletionMoment.swift:275` · P1 |

### `apps/ios/SoloCompass/Views/Companion/Components/AvatarStack.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-2556403b0e · AvatarStack · Button  | 显示全部成员 | 执行：Haptics.selection() showAll = true | binding: $showAll) { | `apps/ios/SoloCompass/Views/Companion/Components/AvatarStack.swift:137` · P1 |
| IC-bffb766dc4 · AvatarStack · popover  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.popover(isPresented: $showAll) | binding: $showAll) { | `apps/ios/SoloCompass/Views/Companion/Components/AvatarStack.swift:145` · P1 |

### `apps/ios/SoloCompass/Views/Companion/Components/RecruitingModule.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-e50f4db880 · RecruitingModule · Button  | 动态 label/无显式名称：需复核 | 执行：config.action | disabled(config.isDisabled) | `apps/ios/SoloCompass/Views/Companion/Components/RecruitingModule.swift:225` · P1 |

### `apps/ios/SoloCompass/Views/Companion/Components/StopsList.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4cc258b573 · StopsList · Button · 动态 | 打开这一站的详情 | 执行：onTapStop(experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/Components/StopsList.swift:33` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-f27912e748 · ConversationListView · Button · 动态 | 重试 | 执行：self.loadError = nil Task { await reload() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift:63` · P1 |
| IC-3779d20808 · ConversationListView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：ChatView( conversation: summary.conversation, currentUserId: currentUserId ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift:88` · P1 |
| IC-22697d4a59 · ConversationListView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(item: $autoOpenConversation) | binding: $autoOpenConversation) { conversation in; isLoading | `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift:103` · P1 |
| IC-b784fe1752 · ConversationListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await reload() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift:123` · P1 |

### `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-81754684f9 · CreateRouteEntryCard · Button  | 创建你自己的路线 / 串联几个地点 · 可选择招募同伴一起走 | 执行：onTap | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:18` · P1 |
| IC-9d06185151 · CreateRouteView · Button · 动态 | 取消 | 执行：generationTask?.cancel() generationGuard.cancelAttempt() dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:160` · P1 |
| IC-e98b497e8a · CreateRouteView · Button  | 保存 | 执行：save() | disabled(!canSave) | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:167` · P1 |
| IC-d2c9cba293 · CreateRouteView · Button · 动态 | ✨ 让 AI 帮我串成路线 | 执行：startGeneration() | disabled(isGenerating \|\| candidates.count < 2) | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:181` · P1 |
| IC-73e25ac7fb · CreateRouteView · Button · 动态 | 重试保存 | 执行：self.saveErrorText = nil save() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:241` · P1 |
| IC-0a1e635e64 · CreateRouteView · Button · 动态 | 使用建议 | 执行：if let pendingSuggestion { apply(pendingSuggestion) } pendingSuggestion = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:271` · P1 |
| IC-1f52f89249 · CreateRouteView · Button · 动态 | 保留我的编辑 | 执行：pendingSuggestion = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:283` · P1 |
| IC-0b38f8db4e · CreateRouteView · Button · 动态 | 重试 AI | 执行：startGeneration() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:323` · P1 |
| IC-9afb141cd5 · CreateRouteView · TextField  | 例如：湄公河日落散步 | 编辑/选择绑定：$title | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:350` · P1 |
| IC-1a9d58581a · CreateRouteView · Picker · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$pace | binding: $pace) { | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:366` · P1 |
| IC-f52b8228ec · CreateRouteView · Button · 动态 | Solo %.1f | 执行：toggle(exp.id) | isSelected | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:412` · P1 |

### `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-fd25c055c3 · DiscoverListView · Button · 动态 | 刷新发现列表 | 执行：Task { await loadPosts() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:45` · P1 |
| IC-f1e83f6750 · DiscoverListView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $selectedPost) | binding: $selectedPost) { post in; binding: $showPostSheet) {; binding: $reportTarget) { post in | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:90` · P1 |
| IC-4dbbdd246f · DiscoverListView · SendRequestSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onSendAsync: { note in | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:91` · P1 |
| IC-c51a0c17d2 · DiscoverListView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showPostSheet) | binding: $showPostSheet) {; binding: $reportTarget) { post in; binding: $addFriendTarget) { post in | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:95` · P1 |
| IC-c3021f6c4d · DiscoverListView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $reportTarget) | binding: $reportTarget) { post in; binding: $addFriendTarget) { post in | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:98` · P1 |
| IC-26d485a39b · DiscoverListView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $addFriendTarget) | binding: $addFriendTarget) { post in | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:107` · P1 |
| IC-6a9fb3a1d2 · DiscoverListView · Button  | 重试 / 重新加载同伴列表 | 执行：Haptics.impact(.light) Task { await loadPosts() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:129` · P1 |
| IC-564c657f13 · DiscoverListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await loadPosts() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:161` · P1 |
| IC-7315a0a441 · EmptyCompanionState · Button  | 抢先发布 — 分享你的行程 / 打开表单，发布你在这座城市的出行时间 | 执行：Haptics.impact(.light) onPostTapped() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:275` · P1 |
| IC-c028d810be · DiscoverPostRow · contextMenu · 动态 | 添加好友 / 举报或屏蔽 | 呈现/导航声明：.contextMenu | destructive | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:356` · P1 |
| IC-89a77bacfb · DiscoverPostRow · Button · 动态 | 添加好友 | 执行：onAddFriend() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:357` · P1 |
| IC-b4691d9386 · DiscoverPostRow · Button · 动态 | 举报或屏蔽 | 执行：onReport() | destructive | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:365` · P1 |
| IC-0cb269758f · DiscoverPostRow · Button · 动态 | 请求已发送 / 发送请求 | 执行：Haptics.selection() onSendRequest() | disabled(hasSentRequest) | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:394` · P1 |
| IC-414a9e5566 · DiscoverPostRow · Button  | 添加好友 | 执行：Haptics.selection() onAddFriend() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:420` · P1 |

### `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-8fc810ad41 · DiscoverPostDetailView · Button · 动态 | 完成 | 执行：dismiss() | disabled(isSending) | `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift:58` · P1 |
| IC-b73b8e0b43 · DiscoverPostDetailView · TextField · 动态 | 打个招呼吧 —— 是什么让你想认识 TA？ | 编辑/选择绑定：$note | disabled(!canAdd) | `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift:104` · P1 |
| IC-852a95cc47 · DiscoverPostDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：send | disabled(!canAdd) | `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift:133` · P1 |

### `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-ece4783e86 · DiscoverRecruitingRoutesView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingCreateRoute, onDismiss: | binding: $showingCreateRoute, onDismiss: { | `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift:53` · P1 |
| IC-65c10abed1 · DiscoverRecruitingRoutesView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift:79` · P1 |
| IC-6b8645293e · DiscoverRecruitingRoutesView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：RouteDetailView(route: route) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift:136` · P1 |
| IC-d3b1aa2315 · DiscoverRecruitingRoutesView · Button · 动态 | 开一个你自己的路线 | 执行：showingCreateRoute = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift:168` · P1 |
| IC-a9405fce7b · DiscoverRecruitingRoutesView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：RouteNavigationRequest.requestCitySelection() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift:184` · P1 |

### `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3d817b205f · InviteFriendsSheet · Button · 动态 | 取消 | 执行：dismiss() | disabled(isSending) | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:84` · P1 |
| IC-7cfff701ad · InviteFriendsSheet · Button · 动态 | 添加 | 执行：Task { await invite() } | disabled(selected.isEmpty \|\| isSending) | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:92` · P1 |
| IC-48f4fb35b5 · InviteFriendsSheet · alert · 动态 | 成员未保存 / 重试 / 取消 | 呈现/导航声明：.alert( NSLocalizedString("invite.friends.error.title", comment: "Invite failed alert title"), isPresented: Binding( get: | binding: Binding(; cancel | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:100` · P1 |
| IC-124524ff77 · InviteFriendsSheet · Button · 动态 | 重试 | 执行：inviteErrorMessage = nil Task { await invite() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:107` · P1 |
| IC-a7b7697b43 · InviteFriendsSheet · Button · 动态 | 取消 | 执行：inviteErrorMessage = nil | cancel | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:111` · P1 |
| IC-0de37e39ae · InviteFriendsSheet · Button  | 动态 label/无显式名称：需复核 | 执行：toggle(friendId) | disabled(!isEnabled); isSelected | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:152` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-16df20ec3a · ItineraryDetailView · onMove · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onMove(perform: moveExperience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:131` · P1 |
| IC-c27ea93524 · ItineraryDetailView · Button · 动态 | 从收藏导入 | 执行：showingImportConfirm = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:141` · P1 |
| IC-0306f8f78f · ItineraryDetailView · confirmationDialog · 动态 | 导入收藏？ / 导入 / 取消 / 已收藏的体验将被添加到这个行程中。已存在的不会重复添加。 / 同伴档案已隐藏 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("itinerary.detail.importFavorites.confirm.title", comment: "Import favorites confirm title"), isPresented: $showingImportConfirm, tit | binding: $showingImportConfirm,; cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:157` · P1 |
| IC-d9924fcd31 · ItineraryDetailView · Button  | 导入 | 执行：importFavorites() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:162` · P1 |
| IC-d2acff6a7a · ItineraryDetailView · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:165` · P1 |
| IC-29bf71346c · ItineraryDetailView · alert · 动态 | 同伴档案已隐藏 / 打开档案设置 / 取消 / 请先在同伴档案中开启可见性，再将此行程对同伴开放。 / 完成 | 呈现/导航声明：.alert( NSLocalizedString("companion.post.visibilityOff.title", comment: "Visibility off alert title"), isPresented: $showingVisibilityOffAlert ) | binding: $showingVisibilityOffAlert; cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:172` · P1 |
| IC-ac5f684ccd · ItineraryDetailView · Button  | 打开档案设置 | 执行：pendingCompanionPostIntent = true DispatchQueue.main.async { showingProfileSettings = true } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:176` · P1 |
| IC-c65be076e8 · ItineraryDetailView · Button  | 取消 | 执行：pendingCompanionPostIntent = false | cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:184` · P1 |
| IC-688225de61 · ItineraryDetailView · sheet · 动态 | 完成 | 呈现/导航声明：.sheet(isPresented: $showingProfileSettings, onDismiss: resumeBlockedFlow) | binding: $showingProfileSettings, onDismiss: resumeBlockedFlow) { | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:190` · P1 |
| IC-93b3576044 · ItineraryDetailView · Button  | 完成 | 执行：showingProfileSettings = false | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:199` · P1 |
| IC-5213d5c79b · ItineraryDetailView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingCompanionPostSheet) | binding: $showingCompanionPostSheet) {; binding: $showingOpenForCompanionsSheet) { | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:206` · P1 |
| IC-71bff8a794 · ItineraryDetailView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingOpenForCompanionsSheet) | binding: $showingOpenForCompanionsSheet) { | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:211` · P1 |
| IC-54373dcb60 · ItineraryDetailView · Button · 动态 | 重试 | 执行：let retry = retryAction saveErrorMessage = nil retryAction = nil retry?() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:240` · P1 |
| IC-a449ee58c0 · ItineraryDetailView · Button · 动态 | 好 | 执行：withAnimation { saveErrorMessage = nil retryAction = nil } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:250` · P1 |
| IC-2b2e1f6f51 · ItineraryDetailView · Toggle  | 欢迎同伴加入 | 编辑/选择绑定：openToCompanionsBinding | binding: openToCompanionsBinding | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:321` · P1 |
| IC-2c316c8367 · ItineraryDetailView · Button · 动态 | 开为招募路线 -> | 执行：showingOpenForCompanionsSheet = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:343` · P1 |
| IC-871c7dcac2 · CompanionPostCreationSheet · TextField · 动态 | 描述你的风格或你在寻找什么… | 编辑/选择绑定：$blurb | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:616` · P1 |
| IC-af59eb161c · CompanionPostCreationSheet · Button · 动态 | checkmark | 执行：if selectedCategories.contains(cat) { selectedCategories.remove(cat) } else { selectedCategories.insert(cat) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:631` · P1 |
| IC-8c70bee9c3 · CompanionPostCreationSheet · Button · 动态 | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:659` · P1 |
| IC-77fa3e9e08 · CompanionPostCreationSheet · Button  | 保存 | 执行：confirm() | disabled(!isValid) | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:664` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-d32c249a59 · ItineraryFormView · Button · 动态 | 取消 | 执行：model.wrappedValue.cancel() if let onCancel { onCancel() } else { dismiss() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:148` · P1 |
| IC-4229327e84 · ItineraryFormView · Button · 动态 | 保存 | 执行：save() | disabled(!model.wrappedValue.isValid) | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:154` · P1 |
| IC-6d38b9a891 · ItineraryFormView · navigationDestination · 动态 | 无法保存行程 / 好 | 呈现/导航声明：.navigationDestination(isPresented: $showingCityPicker) | binding: $showingCityPicker) { | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:161` · P1 |
| IC-5d8c7904ac · ItineraryFormView · alert · 动态 | 无法保存行程 / 好 | 呈现/导航声明：.alert( NSLocalizedString("itinerary.form.save.error.title", comment: "Save failure alert title"), isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:173` · P1 |
| IC-fd230e9740 · ItineraryFormView · Button · 动态 | 好 | 执行：model.wrappedValue.clearSaveError() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:180` · P1 |
| IC-009d2e92d4 · ItineraryFormView · TextField · 动态 | 例如：东京春游 | 编辑/选择绑定：model.draft.title | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:197` · P1 |
| IC-cf16201b38 · ItineraryFormView · Button · 动态 | 城市 | 执行：showingCityPicker = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:204` · P1 |
| IC-a4794a0b1f · ItineraryFormView · DatePicker · 动态 | 开始日期 | 编辑/选择绑定：model.draft.startDate | binding: model.draft.startDate, | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:223` · P1 |
| IC-fb50f502de · ItineraryFormView · DatePicker · 动态 | 结束日期 | 编辑/选择绑定：model.draft.endDate | binding: model.draft.endDate, | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:234` · P1 |
| IC-6f369a3daf · ItineraryFormView · Toggle · 动态 | 欢迎同伴加入 | 编辑/选择绑定：model.draft.openToCompanions | binding: model.draft.openToCompanions | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:246` · P1 |
| IC-97d1e59699 · ItineraryFormView · TextField  | 可选的旅行备注… | 编辑/选择绑定：model.draft.note | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:256` · P1 |
| IC-150c99f112 · ItineraryCityPickerView · Button · 动态 | checkmark | 执行：selectedCode = city.code onSelect() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:308` · P1 |
| IC-64328c4e8b · ItineraryCityPickerView · searchable · 动态 | 搜索城市 / 选择城市 | 编辑/选择绑定：$searchText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift:328` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-d5fe934a73 · ItineraryListView · NavigationLink · 动态 | 删除 | 执行：ItineraryRow(itinerary: itinerary) | disabled(lastDeleted != nil); destructive | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:42` · P1 |
| IC-391dd1f4b6 · ItineraryListView · swipeActions · 动态 | 删除 | 呈现/导航声明：.swipeActions(edge: .trailing, allowsFullSwipe: true) | disabled(lastDeleted != nil); destructive | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:47` · P1 |
| IC-e40c8345d7 · ItineraryListView · Button · 动态 | 删除 | 执行：delete(itinerary) | disabled(lastDeleted != nil); destructive | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:48` · P1 |
| IC-57e0c52655 · ItineraryListView · refreshable  | 动态 label/无显式名称：需复核 | 执行：await MainActor.run { loadItineraries() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:61` · P1 |
| IC-4c2e4178e4 · ItineraryListView · Button · 动态 | 完成 | 执行：onClose | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:70` · P1 |
| IC-7946225c17 · ItineraryListView · Button · 动态 | 新建行程 | 执行：showingCreateForm = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:74` · P1 |
| IC-9f7490840c · ItineraryListView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingCreateForm, onDismiss: loadItineraries) | binding: $showingCreateForm, onDismiss: loadItineraries) { | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:82` · P1 |
| IC-95b28e3aef · ItineraryListView · alert · 动态 | 未能保存这次修改，原有状态仍保留，请重试。 / 重试 / 取消 | 呈现/导航声明：.alert(NSLocalizedString("itinerary.mutation.failed", comment: "Changes could not be saved. Your previous state is kept."), isPresented: $mutationFailed) | binding: $mutationFailed) {; cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:102` · P1 |
| IC-4483ac9606 · ItineraryListView · Button · 动态 | 重试 | 执行：if let failedDeletion { delete(failedDeletion) } else { performUndo() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:103` · P1 |
| IC-ad3db86cca · ItineraryListView · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:106` · P1 |
| IC-3dc6bcd8b2 · ItineraryListView · Button · 动态 | 已移除\"%@\" / 撤销 | 执行：performUndo() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:173` · P1 |
| IC-bf81514938 · ItineraryListView · accessibilityAction · 动态 | 撤销 | 执行：performUndo() | reduceMotion | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:231` · P1 |

### `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-d96b8289aa · JoinRouteRequestSheet · Button  | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:125` · P1 |
| IC-af45f78120 · JoinRouteRequestSheet · Picker · 动态 | 配速匹配 / 请选择 | 编辑/选择绑定：$selectedPace | binding: $selectedPace | `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:169` · P1 |
| IC-3114d64659 · JoinRouteRequestSheet · TextEditor · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$message | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:195` · P1 |
| IC-337104cdaf · JoinRouteRequestSheet · Button · 动态 | 提交申请 | 执行：submit | disabled(!isSubmitEnabled) | `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:234` · P1 |

### `apps/ios/SoloCompass/Views/Companion/MyHostedRoutesListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-9b67938c9f · MyHostedRoutesListView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：ApprovalQueueView(route: route, contextProvider: contextProvider) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/MyHostedRoutesListView.swift:60` · P1 |
| IC-4c4726f370 · HostedRoutesEmptyState · Button · 动态 | 创建路线 | 执行：Haptics.selection() onCreateRoute() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/MyHostedRoutesListView.swift:137` · P1 |

### `apps/ios/SoloCompass/Views/Companion/MyRequestsListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-02778283fc · MyRequestsListView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(isPresented: $showDiscover) | binding: $showDiscover) { | `apps/ios/SoloCompass/Views/Companion/MyRequestsListView.swift:64` · P1 |
| IC-af6917b601 · MyRequestsListView · swipeActions · 动态 | 撤回申请 | 呈现/导航声明：.swipeActions(edge: .trailing, allowsFullSwipe: true) | destructive | `apps/ios/SoloCompass/Views/Companion/MyRequestsListView.swift:81` · P1 |
| IC-aeee32dc1b · MyRequestsListView · Button · 动态 | 撤回申请 | 执行：withdraw(request: request, from: route) | destructive | `apps/ios/SoloCompass/Views/Companion/MyRequestsListView.swift:83` · P1 |
| IC-fec4fbfbf9 · MyRequestsListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await refresh() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/MyRequestsListView.swift:100` · P1 |
| IC-9e1a5dc765 · MyRequestsListView · NavigationLink  | 动态 label/无显式名称：需复核 | 执行：RouteDetailView(route: route) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/MyRequestsListView.swift:137` · P1 |

### `apps/ios/SoloCompass/Views/Companion/MyWalkedRoutesListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-2143112617 · MyWalkedRoutesListView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：RouteDetailView(route: route) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/MyWalkedRoutesListView.swift:24` · P1 |
| IC-c40493d9a6 · WalkedRoutesEmptyState · Button · 动态 | 发现路线 | 执行：Haptics.selection() onExplore() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/MyWalkedRoutesListView.swift:86` · P1 |

### `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-ac806fc841 · OpenForCompanionsSheet · Button  | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:73` · P1 |
| IC-834b693dc4 · OpenForCompanionsSheet · Button  | 创建路线 | 执行：submit() | disabled(isSubmitting); isSubmitting | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:78` · P1 |
| IC-7191320d67 · OpenForCompanionsSheet · Button · 动态 | 重试 | 执行：self.submitErrorText = nil submit() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:113` · P1 |
| IC-c3b87573d8 · OpenForCompanionsSheet · DatePicker · 动态 | 从 | 编辑/选择绑定：$departureFrom | binding: $departureFrom, | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:129` · P1 |
| IC-6dabdc6c06 · OpenForCompanionsSheet · DatePicker · 动态 | 到 | 编辑/选择绑定：$departureTo | binding: $departureTo, | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:137` · P1 |
| IC-e3d510e2ac · OpenForCompanionsSheet · DatePicker · 动态 | 时间 | 编辑/选择绑定：$departureTime | binding: $departureTime, | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:143` · P1 |
| IC-6a8154e62e · OpenForCompanionsSheet · Picker · 动态 | 行程节奏 | 编辑/选择绑定：$pace | binding: $pace | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:155` · P1 |
| IC-d4aac87a0c · OpenForCompanionsSheet · Stepper · 动态 | %d 人 | 编辑/选择绑定：$maxMembers | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:171` · P1 |
| IC-1fcf73add1 · OpenForCompanionsSheet · Picker · 动态 | 可见性 / 公开 / 仅限链接 | 编辑/选择绑定：$visibility | binding: $visibility | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:186` · P1 |
| IC-5871acf6d7 · OpenForCompanionsSheet · TextField · 动态 | 告诉想同行的旅人可以期待什么… | 编辑/选择绑定：$hostMessage | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:203` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-9f7d2a9754 · ReportBlockSheet · Button  | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:64` · P1 |
| IC-0d485876b9 · ReportBlockSheet · alert · 动态 | 感谢你的反馈 / 好的 / 我们会尽快审核。该用户的内容已对你隐藏。 / 提交失败 | 呈现/导航声明：.alert( NSLocalizedString("companion.report.success.title", comment: "Report success title"), isPresented: $showSuccess ) | binding: $showSuccess; binding: Binding(get: { errorMessage != nil }, set: { if !$0; errorMessage | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:71` · P1 |
| IC-ca9604f830 · ReportBlockSheet · Button  | 好的 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:75` · P1 |
| IC-f6be11da79 · ReportBlockSheet · alert · 动态 | 提交失败 / 好的 / 确认屏蔽？ / 屏蔽 / 取消 | 呈现/导航声明：.alert( NSLocalizedString("companion.report.error.title", comment: "Report error title"), isPresented: Binding(get: | binding: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }); binding: $showBlockConfirm,; errorMessage; destructive; cancel | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:79` · P1 |
| IC-3537482035 · ReportBlockSheet · Button · 动态 | 好的 | 执行：errorMessage = nil | errorMessage | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:83` · P1 |
| IC-d489396faf · ReportBlockSheet · confirmationDialog · 动态 | 确认屏蔽？ / 屏蔽 / 取消 / 屏蔽后你将不会再看到对方的任何内容，对方也无法联系你。 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("companion.block.confirm.title", comment: "Block confirm title"), isPresented: $showBlockConfirm, titleVisibility: .visible ) | binding: $showBlockConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:87` · P1 |
| IC-5ecc85ce52 · ReportBlockSheet · Button · 动态 | 屏蔽 | 执行：Task { await confirmBlock() } | destructive | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:92` · P1 |
| IC-bc8b94df1f · ReportBlockSheet · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:98` · P1 |
| IC-a583d69b0c · ReportBlockSheet · Button · 动态 | 已选择 | 执行：selectedReason = reason | isSelected | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:113` · P1 |
| IC-e04f095f7e · ReportBlockSheet · TextField · 动态 | 请提供更多信息，帮助我们处理... | 编辑/选择绑定：$details | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:139` · P1 |
| IC-0cb15950ea · ReportBlockSheet · Button · 动态 | 提交中... / 提交举报 | 执行：Task { await submitReport() } | disabled(isSubmitting); isSubmitting | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:150` · P1 |
| IC-b378c6cf7b · ReportBlockSheet · Button · 动态 | 屏蔽用户 | 执行：showBlockConfirm = true | destructive | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:173` · P1 |

### `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-0ba9e4ca5b · RequestInboxView · Button · 动态 | 刷新收件箱 | 执行：Task { await service.fetchInbox() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:81` · P1 |
| IC-ebca54591c · RequestInboxView · alert · 动态 | 已接受 / 打开对话 / 好的 / 你们的对话已建立，可以开始聊聊行程啦。 | 呈现/导航声明：.alert( NSLocalizedString("companion.inbox.accepted.title", comment: "Request accepted alert title"), isPresented: $showingAcceptedConfirm ) | binding: $showingAcceptedConfirm; errorMessage; reduceMotion; cancel | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:90` · P1 |
| IC-7ffc9142d5 · RequestInboxView · Button · 动态 | 打开对话 | 执行：let conversation = acceptedConversation acceptedConversation = nil DispatchQueue.main.async { conversationToOpen = conversation } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:94` · P1 |
| IC-a67705a884 · RequestInboxView · Button  | 好的 | 执行：acceptedConversation = nil | cancel | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:104` · P1 |
| IC-68ca90f589 · RequestInboxView · navigationDestination · 动态 | exclamationmark.triangle | 呈现/导航声明：.navigationDestination(item: $conversationToOpen) | binding: $conversationToOpen) { conversation in; errorMessage; reduceMotion | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:110` · P1 |
| IC-76160be746 · RequestInboxView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $reportTarget) | binding: $reportTarget) { request in | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:144` · P1 |
| IC-45386ff725 · RequestInboxView · Button  | 重试 / 重新加载收件箱 | 执行：Haptics.impact(.light) Task { await service.fetchInbox() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:165` · P1 |
| IC-20c8a19221 · RequestInboxView · refreshable  | 动态 label/无显式名称：需复核 | 执行：await service.fetchInbox() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:195` · P1 |
| IC-104d3b4b31 · RequestInboxView · Button · 动态 | 撤销 | 执行：performUndo() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:273` · P1 |
| IC-450c53b5c5 · RequestInboxView · accessibilityAction  | 撤销 | 执行：performUndo() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:286` · P1 |
| IC-81c2378f06 · RequestRow · Button · 动态 | 拒绝 | 执行：onDecline() | destructive | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:374` · P1 |
| IC-fbeddedbe6 · RequestRow · Button · 动态 | 接受 | 执行：onAccept() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:382` · P1 |
| IC-b83de9850d · RequestRow · contextMenu  | 举报或屏蔽 | 呈现/导航声明：.contextMenu | destructive | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:393` · P1 |
| IC-8ba79bc7de · RequestRow · Button  | 举报或屏蔽 | 执行：onReport() | destructive | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:394` · P1 |

### `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-8fb6fa184d · RouteDetailView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $activeSheet) | binding: $activeSheet) { sheet in; binding: $showCompletionMoment) {; binding: $showApprovalQueue) { | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:140` · P1 |
| IC-ccda99484f · RouteDetailView · fullScreenCover · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fullScreenCover(isPresented: $showCompletionMoment) | binding: $showCompletionMoment) {; binding: $showApprovalQueue) {; binding: $stopDetailExperience) { exp in | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:148` · P1 |
| IC-46a3393701 · RouteDetailView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(isPresented: $showApprovalQueue) | binding: $showApprovalQueue) {; binding: $stopDetailExperience) { exp in | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:151` · P1 |
| IC-db277c5a6d · RouteDetailView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(item: $stopDetailExperience) | binding: $stopDetailExperience) { exp in | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:157` · P1 |
| IC-cac9b83a33 · RouteDetailView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(item: $routeChatConversation) | binding: $routeChatConversation) { conversation in; binding: $showingAddToItinerary) { | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:170` · P1 |
| IC-01cd5c61dc · RouteDetailView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingAddToItinerary) | binding: $showingAddToItinerary) { | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:176` · P1 |
| IC-4742814421 · RouteDetailView · AddToItinerarySheet  | 动态 label/无显式名称：需复核 | 复用组件调用：onSuccess: { itinerary in | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:179` · P1 |
| IC-5dbb9c8f6f · RouteDetailView · Button · 动态 | 回顾完成时刻 | 执行：showCompletionMoment = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:642` · P1 |
| IC-98e17a3270 · RouteDetailView · Button · 动态 | 加入收藏 / 已收藏 / 未收藏 | 执行：let nowFavorited = preferences.toggleRouteFavorite(liveRoute.id.rawValue) withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { if nowFavorited { heartBurstTrigger += 1  | isFavorited | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:703` · P1 |
| IC-f7ff8ce711 · RouteDetailView · Button  | 保存到我的行程 / 已保存到 %@ | 执行：showingAddToItinerary = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:733` · P1 |
| IC-5c8aa383ab · RouteDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：cta.action | disabled(cta.isDisabled) | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:753` · P1 |
| IC-b6fd1b9191 · RouteDetailView · Button  | 分享路线 | 执行：activeSheet = .share | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:787` · P1 |

### `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-824746f083 · RouteShareSheet · Button · 动态 | 关闭 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:48` · P2 |
| IC-b5ef43f18e · RouteShareSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:52` · P2 |
| IC-cdbb26dc3d · RouteShareSheet · Button · 动态 | 已选择 | 执行：selectedStyle = style statusMessage = nil | isSelected | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:68` · P2 |
| IC-e987a234cf · RouteShareSheet · Button · 动态 | 分享… | 执行：Task { await shareCard() } | disabled(isRendering) | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:180` · P2 |
| IC-85e9d5c5a2 · RouteShareSheet · Button · 动态 | 复制图片 | 执行：copyImage() | disabled(previewImage == nil) | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:192` · P2 |
| IC-e240789ba2 · RouteShareSheet · Button  | 已复制到剪贴板 / 复制 Markdown | 执行：UIPasteboard.general.string = payload.shareText flashStatus(NSLocalizedString("share.copied", comment: "Copied"), error: false) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:213` · P2 |
| IC-bae85f0761 · RouteShareSheet · Button  | 分享… | 执行：activityItems = [payload.shareText] | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:225` · P2 |

### `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-e3ee653b34 · SendRequestSheet · TextField · 动态 | 简单介绍一下自己，或说说你为什么想约一起... | 编辑/选择绑定：$note | disabled(isSending) | `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift:106` · P1 |
| IC-d0fcdec741 · SendRequestSheet · Button · 动态 | 取消 | 执行：dismiss() | disabled(isSending) | `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift:132` · P1 |
| IC-9fba58f748 · SendRequestSheet · Button · 动态 | 发送 | 执行：guard !isSending else { return } let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines) let value = trimmed.isEmpty ? nil : trimmed if let onSendAsync { isSending =  | disabled(isSending) | `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift:138` · P1 |

### `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-6961ae4e4e · CreateExperienceSheet · Button  | 取消 | 执行：onCancel() dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:99` · P1 |
| IC-1537ef3b04 · CreateExperienceSheet · Button  | 保存 | 执行：submit() | disabled(!canSave) | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:105` · P1 |
| IC-3468a9d517 · CreateExperienceSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingCamera) | binding: $isShowingCamera) { | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:111` · P1 |
| IC-91ae2a1c8b · CreateExperienceSheet · TextField  | 动态 label/无显式名称：需复核 | 编辑/选择绑定：text | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:181` · P1 |
| IC-0bcd03f245 · CreateExperienceSheet · Picker · 动态 | 类别 | 编辑/选择绑定：$category | binding: $category | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:189` · P1 |
| IC-085d7d6a7e · CreateExperienceSheet · TextField · 动态 | 一个人在这里是什么感受？ | 编辑/选择绑定：$description | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:202` · P1 |
| IC-03913828b6 · CreateExperienceSheet · Button · 动态 | 移除第 %1$d 张照片，共 %2$d 张 | 执行：images.remove(at: idx) draftBatch.removeImage(at: idx) invalidatePendingReceipt() | disabled(photoSaveFailureCount > 0 \|\| isLoadingPhotos) | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:237` · P1 |
| IC-3b3b63318c · CreateExperienceSheet · PhotosPicker  | 从相册选择 | 编辑/选择绑定：$pickerItems | disabled(photoSaveFailureCount > 0 \|\| isLoadingPhotos); binding: $pickerItems, | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:271` · P1 |
| IC-985a94f507 · CreateExperienceSheet · Button  | 拍照 | 执行：isShowingCamera = true | disabled(photoSaveFailureCount > 0 \|\| isLoadingPhotos) | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:282` · P1 |
| IC-b7b5458866 · CreateExperienceSheet · Button  | 重试保存 | 执行：photoSaveFailureCount = 0 submit() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:321` · P1 |
| IC-7f56fde52e · CreateExperienceSheet · Button  | 不带失败照片保存 | 执行：submitOmittingFailedPhotos() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:331` · P1 |
| IC-2904cd1045 · CreateExperienceSheet · Button  | 返回编辑照片 | 执行：returnToPhotoEditing() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:343` · P1 |
| IC-2e48e4e783 · CreateExperienceSheet · Button  | 改用语音描述 | 执行：onUseVoice() dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:359` · P1 |
| IC-148f532aee · CreateExperienceSheet · Button · 动态 | 跳过无法读取的照片 | 执行：photoLoadFailureCount = 0 | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:385` · P1 |

### `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-f59f8dac05 · ExperienceCardView · Button · 动态 | 已加入收藏 / 已取消收藏 / 取消收藏 / 加入收藏 | 执行：let wasFavorited = preferences.isFavorited(experience.id) withAnimation(.spring(response: 0.3)) { preferences.toggleFavorite(experience.id) } if !wasFavorited { Haptics.notify(. | isFavorited; reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:274` · P1 |
| IC-f73f0f2458 · ExperienceCardView · Button · 动态 | 查看详情 → | 执行：onExpand | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:377` · P1 |
| IC-dff82c642f · ExperienceCardView · Button  | 关闭卡片 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:410` · P1 |
| IC-d46594a2b5 · ExperienceCardView · gesture · 动态 | 独行评分 %@ / 10 / 你已到达 / 提示：%d 条注意事项 / 最佳时段：%@ / 导航 | 源码动作需沿调用方确认：.gesture( | isFavorited; reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:436` · P1 |
| IC-93a9a502c6 · ExperienceCardView · onTapGesture · 动态 | 独行评分 %@ / 10 / 你已到达 / 提示：%d 条注意事项 / 最佳时段：%@ / 导航 | 执行：onExpand() | isFavorited; reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:462` · P1 |
| IC-96b624a93f · ExperienceCardView · accessibilityAction · 动态 | 取消收藏 / 添加到收藏 / 已加入收藏 / 已取消收藏 / 导航 | 执行：let wasFavorited = isFavorited preferences.toggleFavorite(experience.id) if !wasFavorited { Haptics.notify(.success) UIAccessibility.post( notification: .announcement, argument: | isFavorited | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:504` · P1 |
| IC-48f7206949 · ExperienceCardView · accessibilityAction · 动态 | 导航 | 执行：guard let coord = experience.coordinate, let app = availableNavigationApps.first else { return } NavigationLauncher.open(app: app, coordinate: coord, name: experience.title) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:525` · P1 |
| IC-853964b336 · ExperienceCardView · Button · 动态 | 双击以地图居中至此处 | 执行：Haptics.impact(.light) recenter(coord) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:659` · P1 |
| IC-5ecfe24014 · ExperienceCardView · accessibilityAction · 动态 | 双击以地图居中至此处 | 执行：Haptics.impact(.light) recenter(coord) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:668` · P1 |
| IC-b1f3b2c0ab · ExperienceCardView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) NavigationLauncher.open(app: app, coordinate: coordinate, name: name) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:726` · P1 |
| IC-779d916f8b · ExperienceCardView · Menu · 动态 | 动态 label/无显式名称：需复核 | 执行：ForEach(apps) { app in Button(app.displayName) { Haptics.impact(.light) NavigationLauncher.open(app: app, coordinate: coordinate, name: name) } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:735` · P1 |
| IC-ab6416ead5 · ExperienceCardView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) NavigationLauncher.open(app: app, coordinate: coordinate, name: name) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:737` · P1 |
| IC-17f0b95a0a · ExperienceCardView · Menu · 动态 | 深度交叉编译 / 跨多个来源深度交叉编译这个地点 | 执行：Button { Haptics.impact(.light) onRecompile() } label: { Label( NSLocalizedString("recompile.action", comment: "Deep cross-compile menu item"), systemImage: "sparkle.magnifyingg | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:765` · P1 |
| IC-2f6c517365 · ExperienceCardView · Button · 动态 | 深度交叉编译 | 执行：Haptics.impact(.light) onRecompile() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift:766` · P1 |

### `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-adbe6c8bc7 · ExperienceDetailView · onLongPressGesture  | 动态 label/无显式名称：需复核 | 执行：isShowingCapsuleCompose = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:122` · P1 |
| IC-4b22fcd9ce · ExperienceDetailView · Button  | 关闭 | 执行：onClose | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:209` · P1 |
| IC-00e82eab2a · ExperienceDetailView · Menu · 动态 | 深度交叉编译 / 导出笔记 / 反馈问题 / 更多选项 | 执行：if let onRecompile, viewModel.experience.coordinate != nil { Button { Haptics.impact(.light) onRecompile() } label: { Label( NSLocalizedString("recompile.action", comment: "Deep | destructive | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:215` · P1 |
| IC-39337e7416 · ExperienceDetailView · Button · 动态 | 深度交叉编译 | 执行：Haptics.impact(.light) onRecompile() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:221` · P1 |
| IC-de539ea71c · ExperienceDetailView · Button · 动态 | 导出笔记 | 执行：exportMarkdown = MarkdownExporter.export(viewModel.experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:232` · P1 |
| IC-32efeedfc4 · ExperienceDetailView · Button · 动态 | 反馈问题 | 执行：isShowingReport = true | destructive | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:240` · P1 |
| IC-c0078b2ecb · ExperienceDetailView · sheet · 动态 | 关闭 / 已埋下——%d 个月后开启 / 好 | 呈现/导航声明：.sheet(isPresented: $isShowingReport) | binding: $isShowingReport) {; binding: Binding( | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:262` · P1 |
| IC-ad1fa747d0 · ExperienceDetailView · ReportIssueSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onFinished: { isShowingReport = false },; onCancel: { isShowingReport = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:265` · P1 |
| IC-577b9e444d · ExperienceDetailView · sheet · 动态 | 关闭 / 已埋下——%d 个月后开启 / 好 | 呈现/导航声明：.sheet(item: Binding( get: | binding: Binding(; binding: $isShowingAddToItinerary) { | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:271` · P1 |
| IC-a7b13663cf · ExperienceDetailView · sheet · 动态 | 关闭 / 已埋下——%d 个月后开启 / 好 | 呈现/导航声明：.sheet(isPresented: $isShowingAddToItinerary) | binding: $isShowingAddToItinerary) {; binding: $itineraryToNavigate) { itin in | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:281` · P1 |
| IC-c0d310336c · ExperienceDetailView · AddToItinerarySheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onSuccess: { itinerary in | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:282` · P1 |
| IC-30588f88bc · ExperienceDetailView · sheet · 动态 | 关闭 / 已埋下——%d 个月后开启 / 好 | 呈现/导航声明：.sheet(item: $itineraryToNavigate) | binding: $itineraryToNavigate) { itin in | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:291` · P1 |
| IC-a2b7b0a1d7 · ExperienceDetailView · Button · 动态 | 关闭 | 执行：itineraryToNavigate = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:296` · P1 |
| IC-0a51fd88a5 · ExperienceDetailView · sheet · 动态 | 已埋下——%d 个月后开启 / 好 | 呈现/导航声明：.sheet(isPresented: $isShowingPaywall) | binding: $isShowingPaywall) {; binding: $isShowingCapsuleCompose) { | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:307` · P1 |
| IC-a4835e96a2 · ExperienceDetailView · sheet · 动态 | 已埋下——%d 个月后开启 / 好 | 呈现/导航声明：.sheet(isPresented: $isShowingCapsuleCompose) | binding: $isShowingCapsuleCompose) { | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:317` · P1 |
| IC-649b57ba0e · ExperienceDetailView · alert · 动态 | 好 | 呈现/导航声明：.alert( capsuleBuryToast ?? "", isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:348` · P1 |
| IC-f0fc8a5856 · ExperienceDetailView · Button · 动态 | 好 | 执行：capsuleBuryToast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:355` · P1 |
| IC-fec0c0b139 · ExperienceDetailView · Button · 动态 | 导航 / 导航 | 执行：Haptics.impact(.light) if let only = NavigationLauncher.soleApp() { NavigationLauncher.open(app: only, coordinate: coord, name: name) } else { isShowingNavPicker = true } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:945` · P1 |
| IC-19a8a6b84c · ExperienceDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.selection() if let proxy = scrollProxy { withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo("bestTimesTimeline", anchor: .center) } } | reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1065` · P1 |
| IC-30c200eedf · ExperienceDetailView · Button · 动态 | 收起 / 全部 %d 项 / 展开或收起六维评分详情 | 执行：Haptics.selection() withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { showingRadarTooltip.toggle() } | reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1284` · P1 |
| IC-5859f58fd4 · ExperienceDetailView · Link · 动态 | 打开原始来源 | 执行：sourceRowContent(label: label, iconName: iconName, date: source.verifiedAt, isLink: true) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1492` · P1 |
| IC-c24a491772 · ExperienceDetailView · simultaneousGesture · 动态 | 打开原始来源 | 源码动作需沿调用方确认：.simultaneousGesture(TapGesture().onEnded { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1495` · P1 |
| IC-fe0113575a · NearbyCard · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) onSelect(exp) | reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1596` · P1 |
| IC-b3547afd58 · ExperienceDetailView · Button · 动态 | 查看行程 | 执行：toastDismissTask?.cancel() withAnimation { addedItineraryToast = nil } itineraryToNavigate = itin | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1645` · P1 |
| IC-abf4b8e99d · ExperienceDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | isSelected | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1674` · P1 |
| IC-ed7343c4e3 · ExperienceDetailView · dockIconButton · 动态 | 取消收藏 / 添加到收藏 / 已收藏 / 收藏 | 复用组件调用：dockIconButton( systemName: viewModel.isFavorited ? "heart.fill" : "heart", isOn: viewModel.isFavorited, accessibilityLabel: viewModel.isFavorited ? NSLocalizedString("actio | binding: viewModel.isFavorited,; isFavorited | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1701` · P1 |
| IC-cbd7ac31d1 · ExperienceDetailView · dockIconButton · 动态 | 向 Solo 提问 / 问问 | 复用组件调用：dockIconButton( systemName: "bubble.left.and.text.bubble.right", accessibilityLabel: NSLocalizedString("experience.askSolo.cta", comment: "Ask Solo"), visibleLabel: NSLocali | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1725` · P1 |
| IC-fb5c78cb7d · ExperienceDetailView · dockIconButton · 动态 | 去过 / 已完成 / 标记完成 | 复用组件调用：dockIconButton( systemName: viewModel.isCompleted ? "checkmark.circle.fill" : "checkmark.circle", isOn: viewModel.isCompleted, accessibilityLabel: NSLocalizedString(viewMode | binding: viewModel.isCompleted,; isCompleted | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1739` · P1 |
| IC-85194c02f0 · ExperienceDetailView · Button · 动态 | 加入行程 | 执行：Haptics.impact(.light) isShowingAddToItinerary = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1757` · P1 |
| IC-5eea502fb4 · ExperienceDetailView · confirmationDialog · 动态 | 导航 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("location.navigate", comment: ""), isPresented: $isShowingNavPicker, titleVisibility: .visible ) | binding: $isShowingNavPicker,; cancel | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1791` · P1 |
| IC-6e4ad53732 · ExperienceDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：NavigationLauncher.open(app: app, coordinate: coord, name: name) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1801` · P1 |
| IC-d169be4d68 · ExperienceDetailView · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1806` · P1 |

### `apps/ios/SoloCompass/Views/Experience/LocationCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-ca33afbf54 · LocationCard · Button · 动态 | 导航 / 选择地图应用以获取步行路线 / 在地图中打开步行路线 | 执行：navigateTapped() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:141` · P1 |
| IC-0d2696b24c · LocationCard · Button  | 动态 label/无显式名称：需复核 | 执行：performCopy() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:171` · P1 |
| IC-1e87e659bd · LocationCard · confirmationDialog · 动态 | 导航 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("location.navigate", comment: ""), isPresented: $isShowingPicker, titleVisibility: .visible ) | binding: $isShowingPicker,; cancel | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:200` · P1 |
| IC-9d4894e3ed · LocationCard · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：NavigationLauncher.open(app: app, coordinate: coordinate, name: displayName) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:206` · P1 |
| IC-0030ac8543 · LocationCard · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:210` · P1 |

### `apps/ios/SoloCompass/Views/Experience/MarkdownShareSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-ce37603d78 · MarkdownShareSheet · Button  | 复制 Markdown | 执行：UIPasteboard.general.string = markdown Haptics.notify(.success) dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/MarkdownShareSheet.swift:39` · P2 |
| IC-f30f96e900 · MarkdownShareSheet · Link · 动态 | 在 Notion 中打开 | 执行：Label( NSLocalizedString("export.notion", comment: "Open in Notion"), systemImage: "arrow.up.right.square" ) .frame(maxWidth: .infinity) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/MarkdownShareSheet.swift:53` · P2 |
| IC-ec41b78c5d · MarkdownShareSheet · Button · 动态 | 分享… | 执行：showActivityVC = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/MarkdownShareSheet.swift:63` · P2 |
| IC-ae5d417d53 · MarkdownShareSheet · Button  | 关闭 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/MarkdownShareSheet.swift:80` · P2 |
| IC-301756d6f7 · MarkdownShareSheet · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showActivityVC) | binding: $showActivityVC) { | `apps/ios/SoloCompass/Views/Experience/MarkdownShareSheet.swift:84` · P2 |

### `apps/ios/SoloCompass/Views/Experience/MicroSurveySheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3d51046fc6 · MicroSurveySheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：recommend = option Haptics.impact(.light) | isSelected | `apps/ios/SoloCompass/Views/Experience/MicroSurveySheet.swift:136` · P1 |
| IC-4480913b88 · MicroSurveySheet · Button  | 发送反馈 | 执行：Haptics.notify(.success) onSubmit(comfort, staffPressure, recommend) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/MicroSurveySheet.swift:162` · P1 |
| IC-7f82db62ad · MicroSurveySheet · Button  | 跳过 | 执行：onSkip() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/MicroSurveySheet.swift:174` · P1 |
| IC-35dee46ce2 · StarRatingRow · Button · 动态 | 颗星 | 执行：setStar(star) | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Experience/MicroSurveySheet.swift:216` · P1 |
| IC-670c960c01 · StarRatingRow · gesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.gesture( | reduceMotion | `apps/ios/SoloCompass/Views/Experience/MicroSurveySheet.swift:234` · P1 |

### `apps/ios/SoloCompass/Views/Experience/RecompileFeedSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-b9175aefb5 · RecompileFeedSheet · Button · 动态 | 隐藏 / 完成 | 执行：onClose | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/RecompileFeedSheet.swift:52` · P1 |

### `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-8c31a98521 · ReportIssueSheet · Button · 动态 | 取消 | 执行：onCancel | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:94` · P1 |
| IC-64a2603472 · ReportIssueSheet · Button · 动态 | 保存报告 | 执行：saveDraft() | disabled(selectedReason == nil) | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:97` · P1 |
| IC-d1c6dde3e3 · ReportIssueSheet · Button · 动态 | 完成 | 执行：onFinished | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:105` · P1 |
| IC-7fdedaca70 · ReportIssueSheet · Button · 动态 | 发送邮件给支持邮箱 | 执行：retainNotice = false isShowingMailComposer = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:162` · P1 |
| IC-8cc198ef6f · ReportIssueSheet · Link · 动态 | 发送邮件给支持邮箱 | 执行：Label( NSLocalizedString("report.delivery.email", comment: "Email support"), systemImage: "envelope" ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:176` · P1 |
| IC-ff4114a44b · ReportIssueSheet · ShareLink · 动态 | 来自 Solo Compass 的地点报告 / 分享副本 | 执行：Label( NSLocalizedString("report.delivery.share", comment: "Share a copy"), systemImage: "square.and.arrow.up" ) | binding: composedBody, | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:184` · P1 |
| IC-fbf289dafb · ReportIssueSheet · Button · 动态 | 编辑草稿 | 执行：withAnimation { step = .compose } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:216` · P1 |
| IC-8baff7208b · ReportIssueSheet · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingMailComposer) | binding: $isShowingMailComposer) { | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:222` · P1 |
| IC-8ccb0ded99 · ReportIssueSheet · Button · 动态 | 已选择 / 选择此原因并显示可选的详情字段。 | 执行：selectedReason = reason UIImpactFeedbackGenerator(style: .light).impactOccurred() | isSelected | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:322` · P1 |
| IC-c01e674d53 · ReportIssueSheet · TextEditor · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$detail | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:368` · P1 |

### `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4ed6fe3ba9 · ShareSheet · Button · 动态 | 关闭 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:82` · P2 |
| IC-cd29c61d8d · ShareSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:86` · P2 |
| IC-1bba70be88 · ShareSheet · Button · 动态 | 已选择 | 执行：if mode != selectedMode { previewImage = nil } selectedMode = mode statusMessage = nil | isSelected | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:102` · P2 |
| IC-a89a24270a · ShareSheet · Button · 动态 | 重试预览 | 执行：previewFailed = false previewImage = nil Task { await renderPreview(for: style) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:165` · P2 |
| IC-dd1202d453 · ShareSheet · Button · 动态 | 分享… | 执行：shareCard(style: style) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:229` · P2 |
| IC-70fa29f4e8 · ShareSheet · Button · 动态 | 复制图片 | 执行：copyImage(style: style) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:240` · P2 |
| IC-5d5223280f · ShareSheet · Button  | 已复制到剪贴板 / 复制 Markdown | 执行：UIPasteboard.general.string = markdown flashStatus(NSLocalizedString("share.copied", comment: "Copied"), error: false) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:260` · P2 |
| IC-ee30ca067a · ShareSheet · Link · 动态 | 在 Notion 中打开 | 执行：Label( NSLocalizedString("export.notion", comment: "Open in Notion"), systemImage: "arrow.up.right.square" ) .frame(maxWidth: .infinity) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:273` · P2 |
| IC-4d0311123d · ShareSheet · Button · 动态 | 分享… | 执行：activityItems = [markdown] | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:283` · P2 |

### `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-da72add178 · TravelerNotesSection · Button · 动态 | 已在本机记录你对“%@”的判断。 / 确认 | 执行：guard travelerNoteStore?.acceptCorrection(id: c.id) == true else { noteActionFailed = true return } noteActionFailed = false Haptics.notify(.success) registerContribution(String | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:97` · P1 |
| IC-bbc838a5f5 · TravelerNotesSection · Button · 动态 | 不准确 | 执行：guard travelerNoteStore?.dismissCorrection(id: c.id) == true else { noteActionFailed = true return } noteActionFailed = false Haptics.impact(.light) reloadCoBuild() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:121` · P1 |
| IC-00fd4318ca · TravelerNotesSection · Button · 动态 | 收起 / 展开全部 %d 条 → | 执行：withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { notesExpanded.toggle() } | reduceMotion | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:172` · P1 |
| IC-7b28f57019 · TravelerNotesSection · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.selection() notesFilter = filter | isSelected | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:217` · P1 |
| IC-af72b849e0 · TravelerNotesSection · Button · 动态 | 已保存在本机。 / 已确认 / 我也确认 | 执行：guard !confirmed else { return } guard travelerNoteStore?.confirmNote(id: note.id) == true else { noteActionFailed = true return } noteActionFailed = false confirmedNoteIds.inse | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:294` · P1 |
| IC-2082160ac7 · TravelerNotesSection · Button · 动态 | 已选择 | 执行：Haptics.selection() noteSubmitError = false if picked { pickedMoods.remove(mood) } else { pickedMoods.insert(mood) } | isSelected | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:380` · P1 |
| IC-79a13021f6 · TravelerNotesSection · TextField · 动态 | 比如：周二下午很安静… / 加一句话（可选）… | 编辑/选择绑定：$noteDraft | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:413` · P1 |
| IC-7192864ada · TravelerNotesSection · onSubmit · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onSubmit(submitNote) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:422` · P1 |
| IC-1c76716a7f · TravelerNotesSection · Button · 动态 | 发送笔记 | 执行：submitNote() | disabled(!canSubmitNote) | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:424` · P1 |

### `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-c7519dd2fc · FilterBarView · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：isMapPanning = false | reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:286` · P1 |
| IC-cfe1590375 · FilterBarView · Button · 动态 | 双击清除此筛选 | 执行：handleTap(isSelected: isSelected, select: action) | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:364` · P1 |
| IC-ed7403c3c2 · FilterBarView · Button · 动态 | \(resultCount) results | 执行：handleTap(isSelected: isSelected, select: action) | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:404` · P1 |
| IC-72ffe6f1e2 · FilterBarView · Button · 动态 | \(resultCount) results | 执行：Haptics.selection() action() | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:451` · P1 |
| IC-782aeea7dd · FilterBarView · Button · 动态 | 让 Solo 给一个附近的建议 | 执行：#if canImport(UIKit) Haptics.impact(.light) #endif action() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:504` · P1 |
| IC-ddbaa2f83c · FilterBarView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：#if canImport(UIKit) Haptics.selection() #endif action() | isSelected | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:533` · P1 |
| IC-1212f7dbcf · FilterBarView · Button · 动态 | 双击清除此筛选 | 执行：handleTap(isSelected: isSelected, select: action) | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:563` · P1 |
| IC-7e3edd8efc · FilterBarView · Button · 动态 | 双击清除此筛选 | 执行：handleTap(isSelected: isSelected, select: action) | isSelected | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:620` · P1 |

### `apps/ios/SoloCompass/Views/Friends/AddFriendButton.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-b849909d68 · AddFriendButton · Button  | 发送中… | 执行：send | disabled(!isActionable) | `apps/ios/SoloCompass/Views/Friends/AddFriendButton.swift:64` · P1 |

### `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-5a1c1b2a05 · AddFriendSheet · Picker  | 我的码 / 添加好友 | 编辑/选择绑定：$mode | binding: $mode) { | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:73` · P1 |
| IC-e0f2585cdf · AddFriendSheet · Button · 动态 | 完成 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:94` · P1 |
| IC-e72db00046 · AddFriendSheet · contextMenu  | 复制好友码 | 呈现/导航声明：.contextMenu | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:159` · P1 |
| IC-66e1ef0b01 · AddFriendSheet · Button  | 复制好友码 | 执行：copy(code) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:160` · P1 |
| IC-22ca362289 · AddFriendSheet · ShareLink  | 分享好友码 | 执行：Label( NSLocalizedString("friends.add.share", comment: "Share code"), systemImage: "square.and.arrow.up" ) .frame(maxWidth: .infinity) | binding: shareText) { | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:183` · P1 |
| IC-070a07ef04 · AddFriendSheet · Button · 动态 | 更换好友码 | 执行：Task { await rotate() } | disabled(isRotating) | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:192` · P1 |
| IC-296745956d · AddFriendSheet · Button  | 重试 | 执行：Task { await load() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:223` · P1 |
| IC-27d4660b89 · AddFriendSheet · Button  | 扫描二维码 | 执行：isScanning = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:243` · P1 |
| IC-8ecc1774fe · AddFriendSheet · TextField · 动态 | SOLO-XXXX-XXXX | 编辑/选择绑定：$typedCode | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:261` · P1 |
| IC-3bef4ecdd3 · AddFriendSheet · onSubmit · 动态 | 动态 label/无显式名称：需复核 | 执行：if canRedeem { Task { await redeem() } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:274` · P1 |
| IC-30130c2150 · AddFriendSheet · Button · 动态 | 查找 | 执行：Task { await redeem() } | disabled(!canRedeem) | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:276` · P1 |
| IC-441bbeb96f · AddFriendSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isScanning) | binding: $isScanning) { scannerSheet }; binding: $resolvedProfile) { profile in | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:302` · P1 |
| IC-f008f9e718 · AddFriendSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $resolvedProfile) | binding: $resolvedProfile) { profile in | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:303` · P1 |
| IC-a9b96a8aba · AddFriendSheet · Button  | 取消 | 执行：isScanning = false | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:327` · P1 |
| IC-94a1fc60eb · AddFriendSheet · Button  | 取消 | 执行：resolvedProfile = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift:346` · P1 |

### `apps/ios/SoloCompass/Views/Friends/FriendProfileView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3851873b2c · FriendProfileView · dockButton · 动态 | 发消息 | 复用组件调用：action: onMessage | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendProfileView.swift:218` · P1 |
| IC-a07cfb8379 · FriendProfileView · dockButton · 动态 | 起草邀请 | 复用组件调用：action: onInvite | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendProfileView.swift:224` · P1 |
| IC-df8403f271 · FriendProfileView · dockButton · 动态 | 请求已发送 / 添加好友 | 复用组件调用：action: onAddFriend | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendProfileView.swift:232` · P1 |
| IC-3a20d98cf5 · FriendProfileView · Button  | 动态 label/无显式名称：需复核 | 执行：action | disabled(!enabled) | `apps/ios/SoloCompass/Views/Friends/FriendProfileView.swift:263` · P1 |

### `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3eb604a889 · FriendsHubView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isScanning) | binding: $isScanning) { scannerSheet }; binding: $resolvedProfile) { profile in previewSheet(profile: profile) } | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:72` · P1 |
| IC-7ed2deebe8 · FriendsHubView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $resolvedProfile) | binding: $resolvedProfile) { profile in previewSheet(profile: profile) } | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:73` · P1 |
| IC-9d874c979b · FriendsHubView · TextField · 动态 | 输入好友码 SOLO-XXXX-XXXX | 编辑/选择绑定：$typedCode | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:93` · P1 |
| IC-4dd9b73bd6 · FriendsHubView · onSubmit · 动态 | 动态 label/无显式名称：需复核 | 执行：if canRedeem { Task { await redeem() } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:106` · P1 |
| IC-7bb9bce08b · FriendsHubView · Button · 动态 | 查找好友 | 执行：Task { await redeem() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:111` · P1 |
| IC-d90fea8a83 · FriendsHubView · Button · 动态 | 扫描好友二维码 | 执行：Haptics.impact(.light) isScanning = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:133` · P1 |
| IC-2d5e891456 · FriendsHubView · Button · 动态 | 收起我的好友码 / 我的好友码 | 执行：Haptics.selection() showMyCode.toggle() if showMyCode, myCode == nil { Task { await loadMyCode() } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:165` · P1 |
| IC-a87842ce23 · FriendsHubView · ShareLink  | 分享好友码 | 执行：Label( NSLocalizedString("friends.add.share", comment: "Share"), systemImage: "square.and.arrow.up" ) .font(.subheadline.weight(.medium)) .frame(maxWidth: .infinity) | binding: myCode.rawValue) { | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:250` · P1 |
| IC-f840db8804 · FriendsHubView · Button  | 复制好友码 | 执行：copy(myCode) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:261` · P1 |
| IC-a82087bb3c · FriendsHubView · Button  | 取消 | 执行：isScanning = false | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:374` · P1 |
| IC-3735ee96d8 · FriendsHubView · Button  | 取消 | 执行：resolvedProfile = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift:391` · P1 |

### `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-9e6e8c2688 · FriendsListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await service.refresh() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:57` · P1 |
| IC-ed13f3137a · FriendsListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await service.refresh() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:63` · P1 |
| IC-cd9a777705 · FriendsListView · Button  | 显示我的好友码 | 执行：Haptics.impact(.light) showAddFriend = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:89` · P1 |
| IC-0dba739803 · FriendsListView · Button  | 刷新好友和请求 | 执行：Task { await service.refresh() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:98` · P1 |
| IC-66fe8d6bb1 · FriendsListView · sheet · 动态 | 重试 | 呈现/导航声明：.sheet(isPresented: $showAddFriend) | binding: $showAddFriend) {; errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:116` · P1 |
| IC-50151ec243 · FriendsListView · Button · 动态 | 重试 | 执行：let friendship = failedRemoval self.failedRemoval = nil errorMessage = nil Task { await removeFriend(friendship) } | errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:127` · P1 |
| IC-a4e64181a4 · FriendsListView · Button  | 重试 | 执行：Haptics.impact(.light) Task { await service.refresh() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:191` · P1 |
| IC-537f81ce1f · FriendsListView · NavigationLink · 动态 | 移除 | 执行：FriendProfileContainer( friendship: friendship, profile: profileData(for: otherId), service: service ) | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:235` · P1 |
| IC-650d3c27dc · FriendsListView · swipeActions · 动态 | 移除 | 呈现/导航声明：.swipeActions(edge: .trailing, allowsFullSwipe: false) | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:244` · P1 |
| IC-340972c2a8 · FriendsListView · Button · 动态 | 移除 | 执行：Haptics.impact(.light) friendToRemove = friendship | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:245` · P1 |
| IC-2b5f451d97 · FriendsListView · confirmationDialog · 动态 | 移除 %@？ / 移除好友 / 取消 | 呈现/导航声明：.confirmationDialog( String(format: NSLocalizedString("friends.list.remove.confirm.title", comment: "Remove friend confirmation title — %@ is the friend's id"), friendToRem | binding: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),; destructive; cancel | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:256` · P1 |
| IC-8d65800840 · FriendsListView · Button · 动态 | 移除好友 | 执行：guard let friendship = friendToRemove else { return } friendToRemove = nil Task { await removeFriend(friendship) } | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:261` · P1 |
| IC-3349faf210 · FriendsListView · Button · 动态 | 取消 | 执行：friendToRemove = nil | cancel | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:266` · P1 |
| IC-07ea82668d · FriendsListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await service.refresh() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:276` · P1 |
| IC-637239f4d6 · FriendsListView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：FriendProfileContainer( friendship: friendship, profile: profileData(for: otherId), service: service ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:286` · P1 |
| IC-d05c487063 · FriendsListView · simultaneousGesture  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture(TapGesture().onEnded { Haptics.selection() }) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:306` · P1 |
| IC-71163d1e3c · FriendProfileContainer · sheet · 动态 | 无法加载好友 / 好的 | 呈现/导航声明：.sheet(isPresented: $showInvite, onDismiss: | binding: $showInvite, onDismiss: {; errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:406` · P1 |
| IC-148d22740b · FriendProfileContainer · navigationDestination · 动态 | 无法加载好友 / 好的 | 呈现/导航声明：.navigationDestination(item: $conversation) | binding: $conversation) { conv in; errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:432` · P1 |
| IC-0b1305a1d4 · FriendProfileContainer · alert · 动态 | 无法加载好友 / 好的 | 呈现/导航声明：.alert( NSLocalizedString("friends.list.error.title", comment: "Friends error title"), isPresented: Binding(get: | binding: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }); errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:446` · P1 |
| IC-af0d179149 · FriendProfileContainer · Button · 动态 | 好的 | 执行：errorMessage = nil | errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:450` · P1 |
| IC-729dc3c865 · FriendInviteDraftComposer · TextEditor  | 邀请草稿 | 编辑/选择绑定：$draft | disabled(isOpening) | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:544` · P1 |
| IC-de8af74351 · FriendInviteDraftComposer · Button · 动态 | 打开邀请草稿 / 先检查这条消息，再在聊天中打开。只有你在聊天中发送后才会发出。 | 执行：onOpenDraft(trimmed) | disabled(isOpening \|\| trimmed.isEmpty) | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:575` · P1 |
| IC-c0d1927cd9 · FriendInviteDraftComposer · Button  | 取消 | 执行：onCancel | disabled(isOpening) | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:613` · P1 |
| IC-ebd4809ce2 · IncomingRequestRow · Button · 动态 | 拒绝 | 执行：onDecline() | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:724` · P1 |
| IC-f8305ca613 · IncomingRequestRow · Button · 动态 | 接受 | 执行：onAccept() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:732` · P1 |

### `apps/ios/SoloCompass/Views/Insight/InsightCardView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-60defe3585 · InsightCardView · Button  | square.and.arrow.up | 执行：onShare | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Insight/InsightCardView.swift:23` · P2 |

### `apps/ios/SoloCompass/Views/Map/ActiveRouteOverlay.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-c177ea24af · ActiveRouteBanner · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ActiveRouteOverlay.swift:121` · P1 |

### `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-eac0335dcb · BottomInfoSheet · simultaneousGesture  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift:508` · P1 |
| IC-3dc1386f4f · BottomInfoSheet · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：currentDetent = .mid #if canImport(UIKit) Haptics.selection() #endif | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift:647` · P1 |
| IC-3350117ee1 · BottomInfoSheet · gesture · 动态 | 面板把手，上下滑动可调整高度 / 点击展开，拖动调整 | 源码动作需沿调用方确认：.gesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift:815` · P1 |
| IC-73aa914a75 · BottomInfoSheet · simultaneousGesture · 动态 | 面板把手，上下滑动可调整高度 / 点击展开，拖动调整 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift:856` · P1 |
| IC-7b0df48880 · SortCountToolbar · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showSortSheet) | binding: $showSortSheet) {; reduceMotion | `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift:972` · P1 |
| IC-7711cb6ea9 · SortCountToolbar · Button · 动态 | 排序 | 执行：showSortSheet = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift:990` · P1 |
| IC-ad949dc75d · SortModeSheet · Button · 动态 | checkmark | 执行：withAnimation(reduceMotion ? nil : Motion.momentumPop) { sortMode = mode } dismiss() | reduceMotion | `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift:1060` · P1 |

### `apps/ios/SoloCompass/Views/Map/CityPickerSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-0593156b78 · CityPickerSheet · Button · 动态 | 全部城市 | 执行：selectCity(nil) | reduceMotion | `apps/ios/SoloCompass/Views/Map/CityPickerSheet.swift:61` · P1 |
| IC-c29e33ae35 · CityPickerSheet · Button · 动态 | %d 处体验 / 距离 %@ | 执行：selectCity(city.code) | reduceMotion | `apps/ios/SoloCompass/Views/Map/CityPickerSheet.swift:85` · P1 |
| IC-40c118a418 · CityPickerSheet · searchable · 动态 | 搜索城市 / 选择城市 / 取消 | 编辑/选择绑定：$citySearchText；viewModel.availableCities.isEmpty | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CityPickerSheet.swift:140` · P1 |
| IC-73b2b1b007 · CityPickerSheet · Button  | 取消 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CityPickerSheet.swift:150` · P1 |
| IC-9c2094eb3e · CityPickerHeader · Button · 动态 | 最近城市 %@，距离 %@，%d 个体验。点击选择。 / 选择最近发现的城市 | 执行：onTap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CityPickerSheet.swift:298` · P1 |

### `apps/ios/SoloCompass/Views/Map/ClusterAnnotationView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-2677a63aea · ClusterAnnotationView · Button  | 此区域有 %d 个体验 | 执行：onTap | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ClusterAnnotationView.swift:10` · P1 |

### `apps/ios/SoloCompass/Views/Map/CompassMapView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-0bba7830e1 · CompassMapContentView · sheet  | 在此处添加一个地点？ / 取消 / 添加 | 呈现/导航声明：.sheet(item: $surveyExperience) | binding: $surveyExperience) { exp in surveySheetContent(exp: exp) }; binding: addExperienceAlertBinding; cancel | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1368` · P1 |
| IC-7429066c6d · CompassMapContentView · alert · 动态 | 在此处添加一个地点？ / 取消 / 添加 / 填写几项信息，或用语音描述它。 | 呈现/导航声明：.alert( NSLocalizedString("addExperience.confirm.title", comment: "Add an experience here?"), isPresented: addExperienceAlertBinding ) | binding: addExperienceAlertBinding; cancel | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1369` · P1 |
| IC-2e8434256c · CompassMapContentView · Button  | 取消 | 执行：viewModel.cancelAddExperience() | cancel | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1373` · P1 |
| IC-e89830390f · CompassMapContentView · Button  | 添加 | 执行：viewModel.confirmAddExperienceWithForm() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1376` · P1 |
| IC-9a2c8afcba · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: createFormSheetBinding) | binding: createFormSheetBinding) { createFormSheetContent }; binding: recordExperienceSheetBinding) { recordExperienceSheetContent }; binding: detailSheetBinding) { detailSheetContent }; binding: $isS | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1382` · P1 |
| IC-c302bef274 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: recordExperienceSheetBinding) | binding: recordExperienceSheetBinding) { recordExperienceSheetContent }; binding: detailSheetBinding) { detailSheetContent }; binding: $isShowingCityPicker) { cityPickerSheetContent }; binding: $isSho | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1383` · P1 |
| IC-9b76e54a2a · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: detailSheetBinding) | binding: detailSheetBinding) { detailSheetContent }; binding: $isShowingCityPicker) { cityPickerSheetContent }; binding: $isShowingKitSheet, onDismiss: { kitSheetFocus = nil }) { kitSheetContent }; bi | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1384` · P1 |
| IC-e5b514b60e · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingCityPicker) | binding: $isShowingCityPicker) { cityPickerSheetContent }; binding: $isShowingKitSheet, onDismiss: { kitSheetFocus = nil }) { kitSheetContent }; binding: $isShowingLiveSheet) { liveSheetContent }; bin | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1385` · P1 |
| IC-892d23dd35 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingKitSheet, onDismiss: | binding: $isShowingKitSheet, onDismiss: { kitSheetFocus = nil }) { kitSheetContent }; binding: $isShowingLiveSheet) { liveSheetContent }; binding: $isShowingBaseSheet, onDismiss: handleBaseFollowUp) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1390` · P1 |
| IC-c375f59b42 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingLiveSheet) | binding: $isShowingLiveSheet) { liveSheetContent }; binding: $isShowingBaseSheet, onDismiss: handleBaseFollowUp) { baseSheetContent }; binding: $verifyTarget) { experience in; binding: $isShowingFavor | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1391` · P1 |
| IC-e0838f4a26 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingBaseSheet, onDismiss: handleBaseFollowUp) | binding: $isShowingBaseSheet, onDismiss: handleBaseFollowUp) { baseSheetContent }; binding: $verifyTarget) { experience in; binding: $isShowingFavorites, onDismiss: { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1392` · P1 |
| IC-313a6d6e6f · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $verifyTarget) | binding: $verifyTarget) { experience in; binding: $isShowingFavorites, onDismiss: { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1393` · P1 |
| IC-28663602ca · CompassMapContentView · VerifySheet  | 动态 label/无显式名称：需复核 | 复用组件调用：onSubmit: { answers in try submitVerification(answers, for: experience) },; onDismiss: { verifyTarget = nil } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1394` · P1 |
| IC-3ac6b0068b · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingFavorites, onDismiss: | binding: $isShowingFavorites, onDismiss: {; binding: $isShowingItineraries) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1400` · P1 |
| IC-6c954cabe4 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingItineraries) | binding: $isShowingItineraries) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1410` · P1 |
| IC-6da83b705e · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: paywallSheetBinding, onDismiss: | binding: paywallSheetBinding, onDismiss: { viewModel.onPaywallUnlocked = nil }) { paywallSheetContent }; binding: settingsSheetBinding, onDismiss: consumePendingCitySelection) { settingsSheetContent } | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1428` · P1 |
| IC-8cac94d79f · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: settingsSheetBinding, onDismiss: consumePendingCitySelection) | binding: settingsSheetBinding, onDismiss: consumePendingCitySelection) { settingsSheetContent }; binding: recompileFeedSheetBinding) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1432` · P1 |
| IC-647783bc1d · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: recompileFeedSheetBinding) | binding: recompileFeedSheetBinding) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1436` · P1 |
| IC-cef2c3d728 · CompassMapContentView · RecompileFeedSheet  | 动态 label/无显式名称：需复核 | 复用组件调用：onClose: { viewModel.isShowingRecompileFeed = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1437` · P1 |
| IC-ad3df425e1 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $routeSheet, onDismiss: consumePendingCitySelection) | binding: $routeSheet, onDismiss: consumePendingCitySelection) { sheet in routeSheetContent(sheet) }; binding: $isShowingMe, onDismiss: consumePendingCitySelection) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1447` · P1 |
| IC-a8b21ab854 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingMe, onDismiss: consumePendingCitySelection) | binding: $isShowingMe, onDismiss: consumePendingCitySelection) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1449` · P1 |
| IC-6291acef9c · CompassMapContentView · MicroSurveySheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onSubmit: { comfort, pressure, recommend in; onSkip: { surveyExperience = nil } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2087` · P1 |
| IC-3181ae09e1 · CompassMapContentView · CreateExperienceSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onSave: { input in viewModel.createUserExperience(from: input) },; onUseVoice: { viewModel.confirmAddExperience() },; onCancel: { viewModel.cancelAddExperience() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2108` · P1 |
| IC-7f697f34d8 · CompassMapContentView · VoiceButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：VoiceButton(voiceService: voiceService) { transcript in Task { await viewModel.handleNewExperienceTranscript(transcript) } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2126` · P1 |
| IC-c4502c8ebc · CompassMapContentView · KitSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onToggleTodo: { kind in; onDismiss: { isShowingKitSheet = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2225` · P1 |
| IC-84a5f8cfe6 · CompassMapContentView · LiveSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onShowOnMap: { event in; onDismiss: { isShowingLiveSheet = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2245` · P1 |
| IC-5aba6c2024 · CompassMapContentView · BasePanelSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onOpenKit: { kind in; onOpenLive: {; onSelectExperience: { spot in; onVerifyNext: {; onDismiss: { isShowingBaseSheet = false },; onAskSolo: { prompt in | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2259` · P1 |
| IC-a94466d8d9 · CompassMapContentView · ChatSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onDismiss: {; onSelectExperience: { exp in; onAdoptRoute: { proposal in; onShowEventOnMap: { event in; onCollapse: {; onChooseCity: { isShowingCityPicker = true },; onOpenSe | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2971` · P1 |
| IC-25241937a8 · CompassMapContentView · Map · 动态 | 显示快速预览 / 候选体验：%@ / 此地图模式的位置尚未核实，可切换标准地图或查看地点列表。 / 切换标准地图 | 执行：float the quick preview card" | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3057` · P1 |
| IC-85a73658a5 · CompassMapContentView · Button · 动态 | 显示快速预览 | 执行：float the quick preview card" | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3098` · P1 |
| IC-35faaa19c5 · CompassMapContentView · accessibilityAction  | 显示快速预览 | 执行：float the quick preview card" | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3146` · P1 |
| IC-61f50b5932 · CompassMapContentView · MapCompass · 动态 | 动态 label/无显式名称：需复核 | MapKit内建地图控制：方向恢复/视角/定位；系统可见性和accessible name需运行时核实 | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3319` · P1 |
| IC-0c60a09572 · CompassMapContentView · simultaneousGesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3363` · P1 |
| IC-ee728dd421 · CompassMapContentView · simultaneousGesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3381` · P1 |
| IC-6cae447cab · MapOverlayView · accessibilityAction  | 显示快速预览 | 执行：float the quick preview card" | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3899` · P1 |
| IC-1304743670 · MapOverlayView · accessibilityAction  | 显示快速预览 | 执行：float the quick preview card" | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3904` · P1 |
| IC-f958d1b90d · MapOverlayView · onTapGesture  | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) viewModel.openExperienceDetail(tickedNext.experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3907` · P1 |
| IC-a14519d393 · MapOverlayView · onLongPressGesture  | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.medium) viewModel.selectExperience(tickedNext.experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3911` · P1 |
| IC-80268f7be7 · MapOverlayView · Button  | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) viewModel.clearFilters() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3937` · P1 |
| IC-3ba84a2893 · MapOverlayView · accessibilityAction · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) viewModel.clearFilters() | reduceMotion | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3955` · P1 |
| IC-226a0dccaa · MapOverlayView · Button · 动态 | 选择城市 | 执行：isShowingCityPicker = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4033` · P1 |
| IC-5ddf309035 · MapOverlayView · Menu · 动态 | 我的收藏 / 我的行程 / 地图样式 / 地图选项与资料库 | 执行：onOpenFavorites | binding: $mapStyleChoice) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4079` · P1 |
| IC-22e7f69a46 · MapOverlayView · Button  | 我的收藏 | 执行：onOpenFavorites | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4080` · P1 |
| IC-e16eefcdf0 · MapOverlayView · Button  | 我的行程 | 执行：onOpenItineraries | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4084` · P1 |
| IC-5d6ee3d1f3 · MapOverlayView · Picker · 动态 | 地图样式 | 编辑/选择绑定：$mapStyleChoice | binding: $mapStyleChoice) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4088` · P1 |
| IC-f462de6a08 · MapOverlayView · RecenterButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onTap: { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4107` · P1 |
| IC-637f9c8d02 · RecenterButton · Button · 动态 | 回到我的位置 | 执行：Haptics.impact(.light) onTap() guard !reduceMotion else { return } pulse = false iconPop = false withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { iconPop = true }  | disabled(!located); reduceMotion | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4141` · P1 |
| IC-566f5889f0 · EmptyFilterBanner · Button · 动态 | 显示全部 / 显示全部体验 | 执行：Haptics.selection() onShowAll() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4216` · P1 |
| IC-3bf38714ad · DismissibleBanner · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：onAction | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4272` · P1 |
| IC-6e5401bf64 · DismissibleBanner · Button · 动态 | 关闭 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4281` · P1 |
| IC-103cffe40c · MapControlBar · Button  | 偏好 | 执行：viewModel.isShowingSettings = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4324` · P1 |
| IC-633aaf2370 · MapControlBar · Button · 动态 | 探索（Pro) | 执行：let anchor = viewModel.exploreAnchorCoordinate Task { await viewModel.exploreNearby(at: anchor) } | disabled(viewModel.isExploring \|\| viewModel.isExploringFreeMode) | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4338` · P1 |
| IC-c050a0adf9 · MapControlBar · PlusActionButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onShortTap: {; onLongPress: { onOpenChat(.voice) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4368` · P1 |
| IC-a495bc721d · PlusActionButton · Button · 动态 | 和 Solo 聊天 / 点击文字输入，长按语音说话 | 执行：if longPressFired { longPressFired = false } else { onShortTap() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4427` · P1 |
| IC-8e31510fd2 · PlusActionButton · simultaneousGesture · 动态 | 和 Solo 聊天 / 点击文字输入，长按语音说话 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4441` · P1 |
| IC-035e374f3f · EmptyStateOverlay · stageButton · 动态 | 扩展到 25 公里 | 复用组件调用：action: { viewModel.emptyStateActionTryExpand() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4555` · P1 |
| IC-9caea4aae4 · EmptyStateOverlay · stageButton · 动态 | 搜索更远范围 | 复用组件调用：action: { viewModel.emptyStateActionTryExplore() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4560` · P1 |
| IC-522d253b11 · EmptyStateOverlay · stageButton · 动态 | 浏览 %@ | 复用组件调用：action: { viewModel.emptyStateActionBrowseCity() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4565` · P1 |
| IC-f97043e80b · EmptyStateOverlay · Button  | 清除筛选 | 执行：viewModel.clearFilters() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4574` · P1 |
| IC-408a011e67 · EmptyStateOverlay · Button  | 动态 label/无显式名称：需复核 | 执行：Haptics.selection() action() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4616` · P1 |
| IC-3ba6f8fbcf · FilteredEmptyOverlay · Button  | 清除筛选 | 执行：Haptics.selection() viewModel.clearFilters() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4683` · P1 |
| IC-9d2efbfb42 · NowEmptyOverlay · Button · 动态 | 接下来最佳 / 接下来最佳：%1$@，%2$@。点击查看。 | 执行：Haptics.impact(.light) viewModel.openExperienceDetail(soonest.experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4830` · P1 |
| IC-62cfd0b855 · NowEmptyOverlay · Button · 动态 | 浏览附近全部 | 执行：Haptics.selection() viewModel.clearFilters() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4896` · P1 |

### `apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3c5e56041c · DiscoverWorkspaceView · Button · 动态 | 我的收藏 | 执行：onOpenFavorites | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift:57` · P1 |
| IC-1f6dc69ed2 · DiscoverWorkspaceView · Button · 动态 | 我的行程 | 执行：onOpenItineraries | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift:63` · P1 |
| IC-00b7824d72 · DiscoverWorkspaceView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await MainActor.run { onRefresh() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift:148` · P1 |
| IC-96bc617c66 · DiscoverWorkspaceView · Menu · 动态 | 排序 | 执行：ForEach(SortMode.allCases) { mode in Button { #if canImport(UIKit) Haptics.selection() #endif sortMode = mode } label: { Label(mode.localizedTitle, systemImage: mode.symbol) } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift:185` · P1 |
| IC-a3bb775219 · DiscoverWorkspaceView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：#if canImport(UIKit) Haptics.selection() #endif sortMode = mode | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift:187` · P1 |

### `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-83deb09b7c · ExploreConsentSheet · Button  | 了解了 — 开始探索 | 执行：onAccept | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:72` · P1 |
| IC-b85cab37fe · ExploreConsentSheet · Button  | 暂不 | 执行：onCancel | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:87` · P1 |
| IC-ebcc1da12a · ExploreConsentSheetModifier · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:130` · P1 |
| IC-638a8ca883 · ExploreConsentSheetModifier · ExploreConsentSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onAccept: {; onCancel: { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:136` · P1 |

### `apps/ios/SoloCompass/Views/Map/ExploreHandoffCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3457eacf2b · ExploreHandoffCard · Button  | 关闭 | 执行：{ | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreHandoffCard.swift:94` · P1 |
| IC-01b1d6b01a · ExploreHandoffCard · Button  | 清除这批 | 执行：{ | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreHandoffCard.swift:153` · P1 |
| IC-8bb765b500 · ExploreHandoffCard · Button  | 动态 label/无显式名称：需复核 | 执行：action | disabled(!enabled) | `apps/ios/SoloCompass/Views/Map/ExploreHandoffCard.swift:178` · P1 |

### `apps/ios/SoloCompass/Views/Map/ExploreModeOverlay.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-e65ff8a737 · ExploreModeOverlay · Button  | 取消 | 执行：onCancel | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreModeOverlay.swift:144` · P1 |

### `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4e594e8909 · LocationPickerSheet · Picker · 动态 | 位置类型 | 编辑/选择绑定：$bs.selectedTab | binding: $bs.selectedTab | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:40` · P1 |
| IC-9a5b908f89 · LocationPickerSheet · Button · 动态 | 添加自定义城市 | 执行：state.selectedTab = .search | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:65` · P1 |
| IC-6ed65e8ad3 · LocationPickerSheet · Button · 动态 | 取消 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:74` · P1 |
| IC-e06ac132e3 · LocationPickerSheet · alert  | 保存为自定义城市 / 城市名称 / 保存 / 取消 / 该城市将出现在您的已保存位置列表中。 | 呈现/导航声明：.alert( NSLocalizedString("locationPicker.search.saveCity.title", comment: "Save as custom city"), isPresented: $bs.isShowingSaveSearchAlert ) | binding: $bs.isShowingSaveSearchAlert; cancel | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:90` · P1 |
| IC-e27ba683c8 · LocationPickerSheet · TextField  | 城市名称 | 编辑/选择绑定：$bs.saveNameText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:94` · P1 |
| IC-c3d384b489 · LocationPickerSheet · Button  | 保存 | 执行：confirmSaveSearchResult() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:98` · P1 |
| IC-7a8f44facf · LocationPickerSheet · Button  | 取消 | 执行：state.pendingSaveItem = nil | cancel | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:101` · P1 |
| IC-49f5fb075c · LocationPickerSheet · alert  | 命名此位置 / 位置名称 / 保存并设置 / 取消 / 已保存的位置将出现在您的城市列表中，方便快速访问。 | 呈现/导航声明：.alert( NSLocalizedString("locationPicker.map.saveCity.title", comment: "Name this location"), isPresented: $bs.isShowingSaveMapAlert ) | binding: $bs.isShowingSaveMapAlert; cancel | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:108` · P1 |
| IC-74e62b2b80 · LocationPickerSheet · TextField  | 位置名称 | 编辑/选择绑定：$bs.mapSaveNameText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:112` · P1 |
| IC-5a9a1a080b · LocationPickerSheet · Button  | 保存并设置 | 执行：confirmSaveMapLocation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:116` · P1 |
| IC-3e91d4ebb9 · LocationPickerSheet · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:119` · P1 |
| IC-c462572102 · LocationPickerSheet · Button · 动态 | 全部城市 | 执行：commitHaptic() viewModel.selectCity(nil) onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:139` · P1 |
| IC-cfcbf8fe37 · LocationPickerSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：commitHaptic() viewModel.selectCity(city.code) onDismiss() | isSelected | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:162` · P1 |
| IC-6ba3c779f8 · LocationPickerSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：commitHaptic() viewModel.selectCustomLocation( coordinate: saved.coordinate, label: saved.name, cityCode: saved.id ) onDismiss() | isSelected | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:184` · P1 |
| IC-76c8410482 · LocationPickerSheet · onDelete · 动态 | 动态 label/无显式名称：需复核 | 执行：offsets in let idsToDelete = offsets.map { custom[$0].id } for id in idsToDelete { customCityStore.remove(id: id) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:202` · P1 |
| IC-4b19352eec · LocationPickerSheet · searchable  | 搜索城市 | 编辑/选择绑定：bs.citySearchQuery；customCityStore.cities.count | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:210` · P1 |
| IC-562d7c8708 · LocationPickerSheet · TextField · 动态 | 城市、地点或地址 | 编辑/选择绑定：bs.searchQuery | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:254` · P1 |
| IC-c007a5f0b3 · LocationPickerSheet · onSubmit · 动态 | 动态 label/无显式名称：需复核 | 执行：triggerSearch() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:261` · P1 |
| IC-d845005799 · LocationPickerSheet · Button · 动态 | xmark.circle.fill | 执行：state.searchQuery = "" state.searchResults = [] state.searchError = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:267` · P1 |
| IC-b178a633b6 · LocationPickerSheet · Button · 动态 | 苹果地图 / 保存城市 | 执行：selectSearchResult(item) | binding: item) | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:312` · P1 |
| IC-3458f6cada · LocationPickerSheet · contextMenu · 动态 | 苹果地图 / 保存城市 | 呈现/导航声明：.contextMenu | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:317` · P1 |
| IC-74d3c5e399 · LocationPickerSheet · Button · 动态 | 苹果地图 | 执行：item.openInMaps() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:318` · P1 |
| IC-5c0c454335 · LocationPickerSheet · swipeActions · 动态 | 保存城市 | 呈现/导航声明：.swipeActions(edge: .trailing) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:322` · P1 |
| IC-ffcbf9c60f · LocationPickerSheet · Button · 动态 | 保存城市 | 执行：promptSaveSearchResult(item) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:323` · P1 |
| IC-4dbb02a830 · LocationPickerSheet · Button  | 将图钉移到这些坐标 | 执行：applyCoordinateFields() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:376` · P1 |
| IC-57ccb7e2dd · LocationPickerSheet · Button · 动态 | 保存并设置位置 | 执行：promptSaveMapLocation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:437` · P1 |
| IC-f3d5c87c80 · LocationPickerSheet · Button  | 不保存直接使用 | 执行：commitMapLocation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:453` · P1 |
| IC-8784cd0183 · CoordinateField · TextField · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$text | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:777` · P1 |
| IC-2ffaa16468 · CoordinateField · Picker  | 动态 label/无显式名称：需复核 | 编辑/选择绑定：signBinding | binding: signBinding) { | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:787` · P1 |

### `apps/ios/SoloCompass/Views/Map/MapCoordinatePresentation.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-cf98865b3b · MapCoordinateStatus · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：retry | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/MapCoordinatePresentation.swift:107` · P1 |

### `apps/ios/SoloCompass/Views/Map/MapPinPickerView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-037925740c · MapPinPickerView · Map · 动态 | 选定位置 | 执行：if let mapCoordinate = coordinateSpace.mapCoordinate(coordinate) { Annotation( NSLocalizedString("locationPicker.map.pin", comment: "Location pin"), coordinate: mapCoordinate )  | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/MapPinPickerView.swift:31` · P1 |
| IC-b3100402a9 · MapPinPickerView · MapCompass · 动态 | 动态 label/无显式名称：需复核 | MapKit内建地图控制：方向恢复/视角/定位；系统可见性和accessible name需运行时核实 | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/MapPinPickerView.swift:54` · P1 |
| IC-c9c1d7bfaf · MapPinPickerView · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：screenPoint in guard let raw = proxy.convert(screenPoint, from: .local), let coord = coordinateSpace.canonicalMapCoordinate(raw) else { return } onCoordinateChanged(coord) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/MapPinPickerView.swift:57` · P1 |

### `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-20749ab359 · NearbyExperienceRow · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：#if canImport(UIKit) Haptics.selection() if !reduceMotion { withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pressed = true } DispatchQueue.main.asyncAfter(deadlin | reduceMotion | `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift:123` · P1 |
| IC-543df8b61d · NearbyExperienceRow · contextMenu  | 双击查看详情 / 显示快速预览 | 呈现/导航声明：.contextMenu | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift:165` · P1 |
| IC-fbee38cd9d · NearbyExperienceRow · accessibilityAction  | 显示快速预览 | 执行：float the quick preview card" | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift:177` · P1 |
| IC-4238bfb748 · NearbyExperienceRow · Button  | 查看详情 | 执行：onTap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift:187` · P1 |
| IC-b578ed8885 · NearbyExperienceRow · Button · 动态 | 在地图上显示 | 执行：onLongPress() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift:194` · P1 |
| IC-f8cb60196a · NearbyExperienceRow · Button · 动态 | 问 Solo | 执行：onAskSolo() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift:202` · P1 |
| IC-8818f2e22e · NearbyExperienceRow · Button · 动态 | 取消收藏 / 收藏 | 执行：Haptics.impact(.light) preferences.toggleFavorite(experience.id) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift:212` · P1 |
| IC-498baaa37a · NearbyExperienceRow · Button · 动态 | 导航前往 | 执行：NavigationLauncher.open(app: .appleMaps, coordinate: coord, name: experience.title) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbyExperienceRow.swift:225` · P1 |

### `apps/ios/SoloCompass/Views/Map/NearbySectionView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-b29c138874 · EmptySheetListView · Button · 动态 | 探索 %@ / 切换到有精选体验的 %@ | 执行：#if canImport(UIKit) Haptics.impact(.medium) #endif switchCity() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbySectionView.swift:523` · P1 |
| IC-495558945c · EmptySheetListView · Button · 动态 | 带我去热闹一点的地方 | 执行：#if canImport(UIKit) Haptics.selection() #endif explore() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbySectionView.swift:543` · P1 |
| IC-c115e89382 · ExperienceSearchBar · TextField · 动态 | 搜索体验 | 编辑/选择绑定：$text | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbySectionView.swift:598` · P1 |
| IC-1e041ea0de · ExperienceSearchBar · Button · 动态 | 清除搜索 | 执行：text = "" | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/NearbySectionView.swift:609` · P1 |
| IC-8b70f10091 · SearchEmptyView · Button · 动态 | 在地图上搜索\"%@\" | 执行：Haptics.impact(.light) onWebSearch() | disabled(isSearchingWeb) | `apps/ios/SoloCompass/Views/Map/NearbySectionView.swift:655` · P1 |

### `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-6199618fa5 · PeekSummaryCard · onTapGesture · 动态 | 导航 / 双击查看附近全部地点 / 带我去 / 换一个 | 执行：#if canImport(UIKit) Haptics.selection() if !reduceMotion { withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pressed = true } DispatchQueue.main.asyncAfter(deadlin | reduceMotion | `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift:103` · P1 |
| IC-02dfc2c425 · PeekSummaryCard · confirmationDialog · 动态 | 导航 / 双击查看附近全部地点 / 带我去 / 换一个 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("location.navigate", comment: "Navigate"), isPresented: $isShowingNavPicker, titleVisibility: .hidden ) | binding: $isShowingNavPicker, | `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift:116` · P1 |
| IC-c5648c3d31 · PeekSummaryCard · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：if let coord = experience.coordinate { NavigationLauncher.open(app: app, coordinate: coord, name: experience.shortName) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift:122` · P1 |
| IC-db38db982c · PeekSummaryCard · accessibilityAction · 动态 | 带我去 / 换一个 | 执行：launchNavigation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift:133` · P1 |
| IC-b146d60ce4 · PeekSummaryCard · accessibilityAction · 动态 | 换一个 | 执行：onShuffle?() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift:136` · P1 |
| IC-ad33ec3864 · PeekSummaryCard · Button · 动态 | 带我去 | 执行：launchNavigation() | disabled(experience.coordinate == nil) | `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift:260` · P1 |
| IC-d383dd3bd8 · PeekSummaryCard · Button · 动态 | 换一个 | 执行：#if canImport(UIKit) Haptics.selection() #endif onShuffle?() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/PeekSummaryCard.swift:282` · P1 |

### `apps/ios/SoloCompass/Views/Map/RoutesSectionView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-bdd7e6b39c · RoutesSection · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：onSelectRoute(route) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/RoutesSectionView.swift:44` · P1 |
| IC-5a767b1d3c · NowEmptyRoutePlaceholder · Button  | 今天的一条路线 · 让 Solo 为你拼一条 / 我从附近挑 3 个你会喜欢的点，串成一条 · 点这里开始 | 执行：{ onTap?( | disabled(onTap == nil) | `apps/ios/SoloCompass/Views/Map/RoutesSectionView.swift:89` · P1 |

### `apps/ios/SoloCompass/Views/Map/WorkspaceDock.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-0179befed0 · WorkspaceDock · surfaceItem  | 地图 | 复用组件调用：surfaceItem(.map, icon: "map", labelKey: "workspace.dock.map") | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/WorkspaceDock.swift:26` · P1 |
| IC-f2e9f6a6df · WorkspaceDock · surfaceItem  | 发现 | 复用组件调用：surfaceItem(.discover, icon: "binoculars", labelKey: "workspace.dock.discover") | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/WorkspaceDock.swift:30` · P1 |
| IC-1693aef3bd · WorkspaceDock · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：guard !selected else { return } #if canImport(UIKit) Haptics.selection() #endif onSelect(surface) | isSelected | `apps/ios/SoloCompass/Views/Map/WorkspaceDock.swift:51` · P1 |
| IC-fa9548859c · WorkspaceDock · PlusActionButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onShortTap: {; onLongPress: { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/WorkspaceDock.swift:87` · P1 |

### `apps/ios/SoloCompass/Views/Me/EntitlementBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-aeb6686312 · EntitlementBanner · NavigationLink  | 查看订阅详情 | 执行：PaywallView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/EntitlementBanner.swift:22` · P1 |

### `apps/ios/SoloCompass/Views/Me/MeSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-0b9d1d95f6 · MeSheet · Picker · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$topTab | binding: $topTab) { | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:63` · P1 |
| IC-91d8a5a4ac · MeSheet · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：MyProfileEditView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:82` · P1 |
| IC-beb24e5c91 · MeSheet · NavigationLink · 动态 | 好友 | 执行：FriendsHubView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:115` · P1 |
| IC-d64e48cc7e · MeSheet · NavigationLink · 动态 | 消息 | 执行：ConversationListView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:124` · P1 |
| IC-3a3a518ed0 · MeSheet · NavigationLink  | 旅伴 | 执行：CompanionProfileView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:134` · P1 |
| IC-630b20bd5c · MeSheet · NavigationLink · 动态 | 举报队列 | 执行：ModerationView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:149` · P1 |
| IC-069cf10390 · MeSheet · Button · 动态 | 设置 | 执行：showingSettings = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:162` · P1 |
| IC-f3afbe3070 · MeSheet · navigationDestination · 动态 | 完成 | 呈现/导航声明：.navigationDestination(for: MeDestination.self) | binding: $showingSettings) { | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:183` · P1 |
| IC-bd03df9803 · MeSheet · Button · 动态 | 完成 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:193` · P1 |
| IC-c4162c2554 · MeSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingSettings) | binding: $showingSettings) { | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:196` · P1 |
| IC-5053cfdf5e · MeEmptyStateCard · Button  | 探索地图 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:525` · P1 |
| IC-39fdfee00c · MapAvatarBubble · Button · 动态 | 打开个人中心 / 你有待处理的好友申请 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:562` · P1 |

### `apps/ios/SoloCompass/Views/Omen/OmenCardView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-a4d712af8a · OmenCardView · Button  | 标记完成 | 执行：flipped = true onMicroTaskDone() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Omen/OmenCardView.swift:56` · P2 |

### `apps/ios/SoloCompass/Views/Onboarding/OnboardingCityStep.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-00185fbea5 · OnboardingCityStep · Picker · 动态 | 城市 | 编辑/选择绑定：$selectedCode | binding: $selectedCode | `apps/ios/SoloCompass/Views/Onboarding/OnboardingCityStep.swift:70` · P1 |
| IC-3acbb61a77 · OnboardingCityStep · TextField · 动态 | 安静的院子，慢慢的咖啡，没有压力…… | 编辑/选择绑定：$afternoonText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingCityStep.swift:87` · P1 |
| IC-ab88c09bb7 · OnboardingCityStep · Button · 动态 | 继续 | 执行：commit() onContinue() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingCityStep.swift:98` · P1 |

### `apps/ios/SoloCompass/Views/Onboarding/OnboardingCohortStep.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-2f16afd13e · OnboardingCohortStep · Button · 动态 | \(cohort.localizedTitle), \(cohort.localizedDescription) | 执行：Haptics.selection() preferences.nomadCohort = cohort | isSelected | `apps/ios/SoloCompass/Views/Onboarding/OnboardingCohortStep.swift:68` · P1 |
| IC-e99ac32442 · OnboardingCohortStep · Button · 动态 | 就是我 | 执行：onContinue() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingCohortStep.swift:116` · P1 |
| IC-7308ad1487 · OnboardingCohortStep · Button  | 暂时跳过 | 执行：onContinue() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingCohortStep.swift:127` · P1 |

### `apps/ios/SoloCompass/Views/Onboarding/OnboardingVibeStep.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-8c619d5424 · OnboardingVibeStep · PhotosPicker · 动态 | plus.circle.fill | 编辑/选择绑定：$pickerItems | binding: $pickerItems, | `apps/ios/SoloCompass/Views/Onboarding/OnboardingVibeStep.swift:105` · P1 |
| IC-cd349d3c11 · OnboardingVibeStep · TextField · 动态 | 安静的咖啡馆，慢慢的早晨… | 编辑/选择绑定：$freeformVibe | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingVibeStep.swift:125` · P1 |
| IC-7b54e8aa6d · OnboardingVibeStep · Button  | 继续 | 执行：Task { await commit(skip: false) } | disabled(isWorking) | `apps/ios/SoloCompass/Views/Onboarding/OnboardingVibeStep.swift:135` · P1 |
| IC-05a476210f · OnboardingVibeStep · Button  | 暂时跳过 | 执行：Task { await commit(skip: true) } | disabled(isWorking) | `apps/ios/SoloCompass/Views/Onboarding/OnboardingVibeStep.swift:145` · P1 |

### `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-982d32b919 · OnboardingView · Button · 动态 | 跳过 | 执行：if step == 7 { UserDefaults.standard.set(true, forKey: Self.onboardingPaywallSeenKey) } preferences.completeOnboarding() onComplete() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:126` · P1 |
| IC-7c31e1bff3 · OnboardingView · Button  | 在地图上找到我 | 执行：locationService.requestPermission() step = 1 | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:194` · P1 |
| IC-bfebec1863 · OnboardingView · Button  | 先逛逛 | 执行：step = 1 | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:207` · P1 |
| IC-3366347c17 · OnboardingView · Button  | 了解了 | 执行：step = 2 | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:271` · P1 |
| IC-5e97a72969 · OnboardingView · Button  | 明白了 | 执行：step = 3 | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:337` · P1 |
| IC-4ff6a2d170 · OnboardingView · Button · 动态 | 开始探索 | 执行：withAnimation { step = 4 } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:419` · P1 |
| IC-37215553d1 · OnboardingView · Button  | 稍后决定 | 执行：withAnimation { step = 4 } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:435` · P1 |
| IC-42c0303983 · OnboardingView · Button  | 查看 Pro 方案 | 执行：showingSubscriptionPlans = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:573` · P1 |
| IC-9ad07213ee · OnboardingView · Button  | 继续免费使用 | 执行：finishOnboardingPaywall() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:600` · P1 |
| IC-bb0248c9c4 · OnboardingView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingSubscriptionPlans) | binding: $showingSubscriptionPlans) { | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:614` · P1 |
| IC-faaace8037 · OnboardingView · Button · 动态 | \(style.localizedTitle), \(style.localizedDescription) | 执行：Haptics.selection() preferences.soloTravelStyle = style | isSelected | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:660` · P1 |

### `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-f45ce71055 · LegalDocumentLinks · Link · 动态 | 隐私政策 | 执行：Text(NSLocalizedString("terms.links.privacy", comment: "Privacy policy")) .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) .contentShape(Rectangle()) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:15` · P1 |
| IC-0d71b9cb32 · LegalDocumentLinks · Link · 动态 | 用户协议 | 执行：Text(NSLocalizedString("terms.links.tos", comment: "Terms of service")) .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) .contentShape(Rectangle()) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:22` · P1 |
| IC-a664820d52 · TermsConsentSheet · LegalDocumentLinks  | 动态 label/无显式名称：需复核 | 复用组件调用：LegalDocumentLinks() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:111` · P1 |
| IC-e43fea2654 · TermsConsentSheet · Button  | 同意并继续 | 执行：UserDefaults.standard.set(true, forKey: Self.acceptedKey) onAccept() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:121` · P1 |
| IC-1a1a2dc25b · TermsConsentSheet · Button  | 暂不 | 执行：declined = true onDecline() | cancel | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:132` · P1 |
| IC-407f4d58b4 · TermsConsentSheet · Button  | 重新查看 | 执行：declined = false | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:162` · P1 |

### `apps/ios/SoloCompass/Views/Ost/OstShareCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4a5ef446e5 · OstShareCard · Button  | Share | 执行：onShare | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Ost/OstShareCard.swift:43` · P2 |
| IC-2fe45da0ab · OstShareCard · Button  | New style | 执行：onRegenerate | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Ost/OstShareCard.swift:53` · P2 |

### `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-fb8d4a29e9 · PaywallView · LegalDocumentLinks · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：LegalDocumentLinks() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:114` · P1 |
| IC-4d16fcd81a · PaywallView · Button · 动态 | 关闭 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:128` · P1 |
| IC-8c603e10b7 · PaywallView · alert · 动态 | 好 | 呈现/导航声明：.alert( NSLocalizedString(errorTitleKey, comment: "Contextual plan-loading or purchase error"), isPresented: .constant(purchaseError != nil), actions: | binding: .constant(purchaseError != nil), | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:151` · P1 |
| IC-64bb7bf885 · PaywallView · Button · 动态 | 好 | 执行：purchaseError = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:155` · P1 |
| IC-0bd8944966 · PaywallView · Button · 动态 | 优惠可用 / 最划算 / 已选择 | 执行：selectedProductID = product.id | isSelected | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:304` · P1 |
| IC-4872e07840 · PaywallView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Task { await runPurchase() } | disabled(isDisabled) | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:433` · P1 |
| IC-ddc402b15f · PaywallView · Button · 动态 | 继续免费使用 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:454` · P1 |
| IC-ae8cf7f9b3 · PaywallView · Button  | 恢复购买 / 恢复购买 | 执行：Task { await runRestore() } | disabled(isStoreBusy) | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:476` · P1 |
| IC-f0f90f59cc · PaywallView · Link  | 管理订阅 | 源码动作需沿调用方确认：Link( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:489` · P1 |

### `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-8537e0d1f9 · AIProviderSettingsView · Button · 动态 | 已选择 | 执行：preferences.aiProvider = provider | isSelected | `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:37` · P1 |
| IC-e3f709af2a · AIProviderSettingsView · SecureField  | 粘贴你的 API 密钥… | 编辑/选择绑定：$prefs.aiApiKey | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:79` · P1 |
| IC-b1298f1eeb · AIProviderSettingsView · TextField  | https://api.example.com/v1 | 编辑/选择绑定：$prefs.aiBaseURL | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:101` · P1 |
| IC-f6fc193b04 · AIProviderSettingsView · TextField  | 输入模型名称 | 编辑/选择绑定：$prefs.aiModelName | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:123` · P1 |

### `apps/ios/SoloCompass/Views/Settings/DataSourceSettingsView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-c9096e9625 · DataSourceSettingsView · Picker · 动态 | 编译使用 | 编辑/选择绑定：$policy | binding: $policy | `apps/ios/SoloCompass/Views/Settings/DataSourceSettingsView.swift:45` · P1 |
| IC-4fb6aa9ab4 · DataSourceSettingsView · Stepper · 动态 | 每个源的地点数 | 编辑/选择绑定：$fetchLimit | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DataSourceSettingsView.swift:70` · P1 |
| IC-95528a2f54 · DataSourceSettingsView · Button · 动态 | 测试 | 执行：runProbe(kind) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DataSourceSettingsView.swift:145` · P1 |

### `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-958893b9b5 · DeveloperOptionsView · alert · 动态 | 好 | 呈现/导航声明：.alert( toast ?? "", isPresented: Binding(get: | binding: Binding(get: { toast != nil }, set: { if !$0 { toast = nil } }) | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:48` · P1 |
| IC-40eab1c292 · DeveloperOptionsView · Button · 动态 | 好 | 执行：toast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:52` · P1 |
| IC-614b80cfc6 · DeveloperOptionsView · Button · 动态 | 清除性能样本 | 执行：interactionTracker.clearLatencySamples() Haptics.selection() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:70` · P1 |
| IC-796e4442ed · DeveloperOptionsView · NavigationLink  | AI 提供商 / 未设置 | 执行：AIProviderSettingsView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:115` · P1 |
| IC-43b9e73b0d · DeveloperOptionsView · NavigationLink  | 数据源 | 执行：DataSourceSettingsView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:149` · P1 |
| IC-ef2d602fa6 · DeveloperOptionsView · Picker · 动态 | 强制会员权益 | 编辑/选择绑定：$entitlementSelection | binding: $entitlementSelection | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:193` · P1 |
| IC-282ec7436d · DeveloperOptionsView · Button · 动态 | 下次启动将重新显示引导。 / 重置引导流程 | 执行：preferences.hasCompletedOnboarding = false Haptics.notify(.success) toast = NSLocalizedString("dev.tools.resetOnboarding.done", comment: "Onboarding reset toast") | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:206` · P1 |
| IC-87d695ae89 · DeveloperOptionsView · Button · 动态 | 重置所有覆盖 / 将所有功能开关的覆盖重置为默认值？ / 已清除所有覆盖。 / 取消 | 执行：showingResetConfirm = true | binding: $showingResetConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:217` · P1 |
| IC-d7c1e639d6 · DeveloperOptionsView · confirmationDialog  | 将所有功能开关的覆盖重置为默认值？ / 重置所有覆盖 / 已清除所有覆盖。 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("dev.tools.resetOverrides.confirm", comment: "Reset overrides confirm"), isPresented: $showingResetConfirm, titleVisibility: .visible | binding: $showingResetConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:224` · P1 |
| IC-62b93b7658 · DeveloperOptionsView · Button  | 重置所有覆盖 / 已清除所有覆盖。 | 执行：FeatureFlags.clearAllOverrides() DataSourceSettings.reset() flagsRevision += 1 Haptics.notify(.success) toast = NSLocalizedString("dev.tools.resetOverrides.done", comment: "Over | destructive | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:229` · P1 |
| IC-8ea58d9936 · DeveloperOptionsView · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:236` · P1 |
| IC-6070113095 · DeveloperOptionsView · Button  | 锁定开发者选项 | 执行：subscriptionService.lockDeveloperMode() Haptics.impact(.medium) dismiss() | destructive | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:247` · P1 |
| IC-cb8dbfc8a8 · APIKeyOverrideField · Button · 动态 | 清除覆盖 | 执行：value = "" UserDefaults.standard.removeObject(forKey: defaultsKey) Haptics.selection() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:395` · P1 |
| IC-4e35bb4544 · APIKeyOverrideField · SecureField · 动态 | 粘贴密钥以覆盖默认值 | 编辑/选择绑定：$value | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:406` · P1 |
| IC-de1424814f · FeatureFlagRow · Picker · 动态 | 开 / 关 | 编辑/选择绑定：$selection | binding: $selection) { | `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift:449` · P1 |

### `apps/ios/SoloCompass/Views/Settings/NotificationsSettingsView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-ff3b2577c8 · NotificationsSettingsView · Toggle  | Lonely-hour nudge (17–21) | 编辑/选择绑定：$lonelyOn | binding: $lonelyOn) | `apps/ios/SoloCompass/Views/Settings/NotificationsSettingsView.swift:16` · P1 |
| IC-9c0f561408 · NotificationsSettingsView · Toggle  | Morning city omen (7am) | 编辑/选择绑定：$omenOn | binding: $omenOn) | `apps/ios/SoloCompass/Views/Settings/NotificationsSettingsView.swift:20` · P1 |
| IC-5d5a1eef71 · NotificationsSettingsView · Toggle  | Capsule arrival | 编辑/选择绑定：$capsuleOn | binding: $capsuleOn) | `apps/ios/SoloCompass/Views/Settings/NotificationsSettingsView.swift:24` · P1 |

### `apps/ios/SoloCompass/Views/Settings/SettingsView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-74f8e1b7f7 · SettingsView · Button  | 完成 | 执行：onClose() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:101` · P1 |
| IC-6d0f466995 · SettingsView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingCompanionConsent) | binding: $showingCompanionConsent) { | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:117` · P1 |
| IC-02e82c0b4b · SettingsView · CompanionSafetyConsentSheet  | 动态 label/无显式名称：需复核 | 复用组件调用：onAccepted: { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:123` · P1 |
| IC-61a76c4f08 · SettingsView · NavigationLink  | 旅行风格 | 执行：TravelStyleSettingsView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:135` · P1 |
| IC-fe965dfe93 · SettingsView · NavigationLink  | 类别偏好 / %1$d 喜欢 · %2$d 隐藏 | 执行：CategoryPreferencesView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:146` · P1 |
| IC-2ee7a7c0e2 · SettingsView · NavigationLink  | 可见分类 | 执行：VisibleCategoriesView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:161` · P1 |
| IC-8d1fc281d4 · SettingsView · NavigationLink  | 自定义标签 | 执行：CustomTagsView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:172` · P1 |
| IC-c102a7f434 · SettingsView · Slider · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：Binding( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:207` · P1 |
| IC-aae2a1cf0f · SettingsView · Toggle · 动态 | 靠近时提醒我 | 编辑/选择绑定：Binding( | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:224` · P1 |
| IC-7492374d39 · SettingsView · Picker · 动态 | 主题 | 编辑/选择绑定：Binding( | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:249` · P1 |
| IC-abc33ab03f · SettingsView · Toggle · 动态 | 触觉反馈 / 开关触觉反馈 | 编辑/选择绑定：Binding( | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:259` · P1 |
| IC-e11afa30d3 · SettingsView · Picker · 动态 | 语言 | 编辑/选择绑定：Binding( | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:284` · P1 |
| IC-061a89b3ff · SettingsView · alert · 动态 | 需要重启 / 好的 / 请退出并重新打开 Solo Compass 以完成语言切换。 | 呈现/导航声明：.alert( NSLocalizedString("settings.language.restart.title", comment: "Restart required"), isPresented: $showingLanguageRestartAlert ) | binding: $showingLanguageRestartAlert | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:308` · P1 |
| IC-2c5eb318fb · SettingsView · Button · 动态 | 好的 | 执行： | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:312` · P1 |
| IC-8e43b4f795 · SettingsView · Toggle · 动态 | 启用同伴功能 | 编辑/选择绑定：Binding( | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:337` · P1 |
| IC-0685c10ba4 · SettingsView · NavigationLink · 动态 | 同行中心 | 执行：CompanionHubView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:355` · P1 |
| IC-65cea2e218 · SettingsView · Button · 动态 | 恢复购买 | 执行：Task { await runRestore() } | disabled(restoreInFlight) | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:392` · P1 |
| IC-8ece2b5a3e · SettingsView · Link · 动态 | 管理订阅 | 源码动作需沿调用方确认：Link( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:405` · P1 |
| IC-f290f9f5c8 · SettingsView · alert · 动态 | 好 | 呈现/导航声明：.alert( restoreToast ?? "", isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:412` · P1 |
| IC-2cd60e8334 · SettingsView · Button · 动态 | 好 | 执行：restoreToast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:421` · P1 |
| IC-2203b75969 · SettingsView · alert · 动态 | 好 | 呈现/导航声明：.alert( appleSignInToast ?? "", isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:426` · P1 |
| IC-f11f50364e · SettingsView · Button · 动态 | 好 | 执行：appleSignInToast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:433` · P1 |
| IC-c218aadd95 · SettingsView · Button · 动态 | 用 Apple 保存 | 执行：Task { await runAppleLink() } | disabled(appleSignInInFlight) | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:443` · P1 |
| IC-f1c27e133b · SettingsView · Toggle · 动态 | 导出时包含地图预览 | 编辑/选择绑定：Binding( | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:499` · P1 |
| IC-4c53a9d30e · SettingsView · Button · 动态 | 清除全部数据 / 清除全部数据？ / 清除一切 / 取消 | 执行：showingClearConfirm = true | binding: $showingClearConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:509` · P1 |
| IC-088223d7a8 · SettingsView · confirmationDialog  | 清除全部数据？ / 清除一切 / 取消 / 这会删除你的已完成体验、收藏与偏好。无法恢复。 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("settings.clearData.confirm.title", comment: "Clear all data confirm"), isPresented: $showingClearConfirm, titleVisibility: .visible  | binding: $showingClearConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:517` · P1 |
| IC-e7cf97437e · SettingsView · Button  | 清除一切 | 执行：preferences.completedExperiences = [] preferences.favoritedExperiences = [] preferences.favoritedAt = [:] preferences.visitHistory = [:] preferences.pendingCheckIns = [:] prefer | destructive | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:522` · P1 |
| IC-db4db2a7e4 · SettingsView · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:532` · P1 |
| IC-2100bf5ec7 · SettingsView · Button · 动态 | 暂无可导出的数据——开始使用后，你的到访、时空胶囊和笔记会在这里出现。 / 导出准备失败，请稍后再试。 / 导出我的数据 | 执行：let result = PersonalDataExporter.shared.exportEverything() if result.isEmpty { exportToast = NSLocalizedString( "settings.exportData.toast.empty", comment: "Export empty (nothi | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:540` · P1 |
| IC-82a7f913ed · SettingsView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingExportShare) | binding: $showingExportShare) { | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:564` · P1 |
| IC-16c7de6add · SettingsView · Button  | 忘记我 / 忘记你的口味和记忆？ / 忘记我 / 已清空——下次开聊时，Agent 会重新认识你。 / 暂时无法清空，请稍后再试。 | 执行：showingForgetMeConfirm = true | binding: $showingForgetMeConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:573` · P1 |
| IC-9361a80cd2 · SettingsView · confirmationDialog  | 忘记你的口味和记忆？ / 忘记我 / 已清空——下次开聊时，Agent 会重新认识你。 / 暂时无法清空，请稍后再试。 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("settings.forgetMe.confirm.title", comment: "Forget me confirm title"), isPresented: $showingForgetMeConfirm, titleVisibility: .visib | binding: $showingForgetMeConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:581` · P1 |
| IC-ceb50e2aa0 · SettingsView · Button  | 忘记我 / 已清空——下次开聊时，Agent 会重新认识你。 / 暂时无法清空，请稍后再试。 | 执行：let ok = MemoryDigestService.shared.forgetMe() forgetMeToast = ok ? NSLocalizedString("settings.forgetMe.toast.success", comment: "Forget me success") : NSLocalizedString("setti | destructive | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:586` · P1 |
| IC-f5521d7e02 · SettingsView · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:592` · P1 |
| IC-d40fcf2094 · SettingsView · LegalDocumentLinks  | 动态 label/无显式名称：需复核 | 复用组件调用：LegalDocumentLinks() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:597` · P1 |
| IC-59f3ca634f · SettingsView · onTapGesture  | 动态 label/无显式名称：需复核 | 执行：handleVersionTap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:612` · P1 |
| IC-668b1c6358 · SettingsView · alert · 动态 | 好 | 呈现/导航声明：.alert( forgetMeToast ?? "", isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:618` · P1 |
| IC-f9d2bc5aba · SettingsView · Button · 动态 | 好 | 执行：forgetMeToast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:625` · P1 |
| IC-d91d462fa4 · SettingsView · alert · 动态 | 好 | 呈现/导航声明：.alert( exportToast ?? "", isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:633` · P1 |
| IC-15e0a02fce · SettingsView · Button · 动态 | 好 | 执行：exportToast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:640` · P1 |
| IC-35b82c42ef · SettingsView · NavigationLink · 动态 | AI 提供商 | 执行：AIProviderSettingsView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:701` · P1 |
| IC-9329bca00b · SettingsView · Button  | 用测试邮箱解锁 | 执行：adminEmailInput = "" showingAdminUnlock = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:723` · P1 |
| IC-ab95348eab · SettingsView · NavigationLink · 动态 | 开发者选项 / API、功能开关与调试工具 | 执行：DeveloperOptionsView() .environment(preferences) .environment(subscriptionService) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:735` · P1 |
| IC-bbd19662ab · SettingsView · alert  | 测试者解锁 / you@example.com / 取消 / 解锁 / 输入你的测试邮箱以在本设备上解锁 Pro。 | 呈现/导航声明：.alert( NSLocalizedString("settings.adminUnlock.title", comment: "Admin unlock title"), isPresented: $showingAdminUnlock ) | binding: $showingAdminUnlock; cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:761` · P1 |
| IC-bb827c8850 · SettingsView · TextField  | you@example.com | 编辑/选择绑定：$adminEmailInput | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:765` · P1 |
| IC-7051287d39 · SettingsView · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:771` · P1 |
| IC-bc0079fb53 · SettingsView · Button  | 解锁 | 执行：runAdminUnlock() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:772` · P1 |
| IC-476ec0c3a6 · TravelStyleSettingsView · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.selection(); preferences.soloTravelStyle = style | isSelected | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:887` · P1 |
| IC-d8ad152856 · CategoryPreferencesView · Button · 动态 | 隐藏 | 执行：togglePreferred(category) | isSelected; destructive | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:934` · P1 |
| IC-69dab8830b · CategoryPreferencesView · swipeActions · 动态 | 隐藏 | 呈现/导航声明：.swipeActions(edge: .trailing) | destructive | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:957` · P1 |
| IC-41b82caa13 · CategoryPreferencesView · Button · 动态 | 隐藏 | 执行：toggleDisliked(category) | destructive | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:958` · P1 |
| IC-021778e019 · CategoryPreferencesView · Button · 动态 | 重新显示%@ | 执行：Haptics.selection() preferences.dislikedCategories.removeAll { $0 == category } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:978` · P1 |
| IC-ca28788079 · CompanionHubView · NavigationLink · 动态 | 同伴档案 | 执行：CompanionProfileView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1056` · P1 |
| IC-fecef7567e · CompanionHubView · NavigationLink · 动态 | 我的招募申请 | 执行：MyRequestsListView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1066` · P1 |
| IC-42b96723c9 · CompanionHubView · NavigationLink  | 已加入的群聊 | 执行：CompanionConversationsListView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1075` · P1 |
| IC-16c4a7a7a5 · CompanionHubView · NavigationLink  | 发现招募路线 | 执行：DiscoverRecruitingRoutesView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1085` · P1 |
| IC-393b674f3e · CompanionHubView · NavigationLink  | 我主理的路线 | 执行：MyHostedRoutesListView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1096` · P1 |
| IC-c6aca26623 · CompanionConversationsListView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：ChatView(conversation: conv, currentUserId: currentUserId) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1150` · P1 |
| IC-8a2870c928 · VisibleCategoriesView · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：toggle(category) | isSelected | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1256` · P1 |
| IC-cb2c041ef2 · CustomTagsView · TextField · 动态 | 新标签 | 编辑/选择绑定：$draft | errorMessage | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1311` · P1 |
| IC-5f863dfeaf · CustomTagsView · onSubmit  | 动态 label/无显式名称：需复核 | 执行：addDraft() | errorMessage | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1322` · P1 |
| IC-e4e6092905 · CustomTagsView · Button  | 添加 | 执行：addDraft() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1325` · P1 |
| IC-aea23f85a8 · CustomTagsView · onDelete · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onDelete(perform: deleteTags) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1366` · P1 |

### `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-2e9d55d60b · ConfidenceBadge · Button · 动态 | AI 估算 · 待验证 / 信号 / %@，第 %d 级，%d 个信号 / 双击查看信任信号 | 执行：Haptics.selection() if !reduceMotion { withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pressed = true } DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { w | reduceMotion | `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift:23` · P1 |
| IC-fbcd050620 · ConfidenceBadge · popover · 动态 | %@，第 %d 级，%d 个信号 / 双击查看信任信号 | 呈现/导航声明：.popover(isPresented: $showSignals) | binding: $showSignals) {; reduceMotion | `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift:76` · P1 |

### `apps/ios/SoloCompass/Views/Shared/DismissibleBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3d8242289a · DismissibleBannerModifier · gesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.gesture( | reduceMotion | `apps/ios/SoloCompass/Views/Shared/DismissibleBanner.swift:101` · P1 |

### `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-412817074c · FavoritesListView · Button · 动态 | 正显示未完成，点击显示全部 / 显示剩余体验 / 筛选出尚未完成的收藏 | 执行：Haptics.selection() withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { showRemainingOnly.toggle() } | reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:317` · P1 |
| IC-353db775d7 · FavoritesListView · Button · 动态 | 附近 %d 个 / 附近 %d 个收藏 / 按距离排序收藏 | 执行：Haptics.selection() withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { sortMode = .nearest } | reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:346` · P1 |
| IC-3342ec74ee · FavoritesListView · Button · 动态 | 步行至最近收藏 %@，约 %d 分钟 | 执行：Haptics.impact(.light) NavigationLauncher.open(app: app, coordinate: coord, name: nearest.title) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:375` · P1 |
| IC-0f4eb4ed7f · FavoritesListView · Button · 动态 | 出发 / 前往最近收藏 %@ 的路线 / 在地图中打开逐步导航 | 执行：Haptics.impact(.light) guard let coord = nearest.coordinate else { return } NavigationLauncher.open(app: app, coordinate: coord, name: nearest.title) | reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:393` · P1 |
| IC-49f4fea52f · FavoritesListView · Picker · 动态 | 排序 / 最新 / 最近 | 编辑/选择绑定：$sortMode.animation(reduceMotion ? nil : .easeInOut | binding: $sortMode.animation(reduceMotion ? nil : .easeInOut)) {; reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:427` · P1 |
| IC-fa5cb4e64e · FavoritesListView · Button · 动态 | 完成 | 执行：onClose() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:481` · P1 |
| IC-0047d9a45b · FavoritesListView · searchable · 动态 | 搜索收藏 | 编辑/选择绑定：$searchText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:485` · P1 |
| IC-5db3be5c0b · FavoritesJourneyHeader · Button · 动态 | %d 个收藏此刻很适合前往 / 把这些收藏排到列表顶部 | 执行：onTap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:610` · P1 |
| IC-d6a572a299 · FavoritesJourneyHeader · Button · 动态 | %d 个收藏在步行范围内 / 按距离排序收藏 | 执行：onTap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:647` · P1 |
| IC-1cbea2824a · FavoritesJourneyHeader · Button · 动态 | 按距离排序收藏 | 执行：onTap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:704` · P1 |
| IC-b0ef03a1b7 · EmptyFavoritesView · Button  | 双击查看下一条提示 | 执行：advanceTip() | reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1079` · P1 |
| IC-2adb0d573e · EmptyFavoritesView · Button · 动态 | 提示 %1$d / %2$d | 执行：selectTip(index) | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1097` · P1 |
| IC-4cacfd4a52 · EmptyFavoritesView · Button · 动态 | 去地图探索 | 执行：Haptics.selection() onExplore() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1114` · P1 |
| IC-5b128f1240 · AllRemainingDoneView · Button  | 显示全部收藏 | 执行：onShowAll() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1167` · P1 |
| IC-1224a09b5f · NoSearchResultsView · Button  | 清空搜索 / 清空搜索框并显示所有收藏 | 执行：Haptics.selection() withAnimation { onClear() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1213` · P1 |
| IC-6801cdb830 · NoSearchResultsView · Button · 动态 | %d 个此刻很适合 / %d 个收藏此刻很适合前往 / 把这些收藏排到列表顶部 | 执行：Haptics.selection() withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { onShowGoodNow() } | reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1223` · P1 |
| IC-e73cf3a98d · FavoritesListView · Button · 动态 | 已移除\"%@\" / 撤销 | 执行：performUndo() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1292` · P1 |
| IC-d7fbb834a5 · FavoritesListView · accessibilityAction · 动态 | 撤销 | 执行：performUndo() | reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1344` · P1 |
| IC-3f5ac3263e · FavoritesListView · Button · 动态 | 推荐时段 · 剩余 %d 分钟 / 此刻适合 / %@ 最佳 / 显示快速预览 / 已完成 | 执行：float the quick preview card" | reduceMotion; destructive | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1394` · P1 |
| IC-6c5b1f314b · FavoritesListView · accessibilityAction · 动态 | 显示快速预览 / 已完成 / 推荐时段将在 %d 分钟后结束 / 此刻适合前往 / 约 %@ 最佳 | 执行：float the quick preview card" | reduceMotion; destructive | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1503` · P1 |
| IC-c59c55400c · FavoritesListView · swipeActions · 动态 | 已移除 %@。可撤销。 / 取消收藏 / 已标记为未到访 / 已将 %@ 标记为到访 / 标记为未到访 | 呈现/导航声明：.swipeActions(edge: .trailing, allowsFullSwipe: true) | reduceMotion; destructive | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1531` · P1 |
| IC-d61c29935e · FavoritesListView · Button · 动态 | 已移除 %@。可撤销。 / 取消收藏 | 执行：Haptics.notify(.warning) let savedDate = preferences.favoritedAt[exp.id] ?? Date() let expId = exp.id let expTitle = exp.title undoProgress = 1 withAnimation(reduceMotion ? nil  | reduceMotion; destructive | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1532` · P1 |
| IC-34191a1be3 · FavoritesListView · swipeActions · 动态 | 已标记为未到访 / 已将 %@ 标记为到访 / 标记为未到访 / 标记为已到访 / 导航 | 呈现/导航声明：.swipeActions(edge: .leading, allowsFullSwipe: true) | reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1562` · P1 |
| IC-d1dc687459 · FavoritesListView · Button · 动态 | 已标记为未到访 / 已将 %@ 标记为到访 / 标记为未到访 / 标记为已到访 | 执行：if isDone { Haptics.selection() withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { preferences.completedExperiences.remove(exp.id) preferences. | reduceMotion | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1563` · P1 |
| IC-69dce0e8fb · FavoritesListView · accessibilityAction · 动态 | 标记为未到访 / 标记为已到访 / 已标记为未到访 / 已将 %@ 标记为到访 / 导航 | 执行：if isDone { Haptics.selection() preferences.completedExperiences.remove(exp.id) preferences.visitHistory.removeValue(forKey: exp.id) UIAccessibility.post( notification: .announc | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1605` · P1 |
| IC-82eb706aeb · FavoritesListView · accessibilityAction · 动态 | 导航 | 执行：guard let coord = exp.coordinate, let app = NavigationLauncher.availableApps().first else { return } Haptics.impact(.light) NavigationLauncher.open(app: app, coordinate: coord,  | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1636` · P1 |
| IC-6fb772b2ff · DirectionsSwipeModifier · swipeActions · 动态 | 导航 | 呈现/导航声明：.swipeActions(edge: .leading, allowsFullSwipe: true) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1738` · P1 |
| IC-3bf5aeef46 · DirectionsSwipeModifier · Button · 动态 | 导航 | 执行：Haptics.impact(.light) NavigationLauncher.open(app: app, coordinate: coord, name: exp.title) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/FavoritesListView.swift:1739` · P1 |

### `apps/ios/SoloCompass/Views/Shared/LongPressCardModifier.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-bec4601d9f · LongPressCardModifier · onLongPressGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：#if canImport(UIKit) Haptics.impact(.medium) #endif onLongPress() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/LongPressCardModifier.swift:27` · P1 |

### `apps/ios/SoloCompass/Views/Shared/OfflineBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-8fe5b12def · OfflineBanner · Button · 动态 | 双击重试连接 | 执行：guard !isRetrying else { return } Haptics.impact(.light) isRetrying = true bannerState = .retrying Task { await onRetry() let stillOffline = await MainActor.run { !NetworkMonito | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/OfflineBanner.swift:72` · P1 |

### `apps/ios/SoloCompass/Views/Shared/PendingCheckInBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-824c56ecee · PendingCheckInBanner · Button · 动态 | 已确认到访 / 来过！ | 执行：guard !confirmed else { return } confirmed = true autoDismissTask?.cancel() autoDismissTask = nil #if canImport(UIKit) Haptics.notify(.success) UIAccessibility.post( notificatio | disabled(confirmed); reduceMotion | `apps/ios/SoloCompass/Views/Shared/PendingCheckInBanner.swift:78` · P1 |
| IC-33be4a026d · PendingCheckInBanner · Button  | 关闭 | 执行：autoDismissTask?.cancel() autoDismissTask = nil onDismiss() | disabled(confirmed) | `apps/ios/SoloCompass/Views/Shared/PendingCheckInBanner.swift:115` · P1 |

### `apps/ios/SoloCompass/Views/Shared/SoloEmptyState.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-5cd1c7040e · SoloEmptyState · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/SoloEmptyState.swift:68` · P1 |

### `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-1c164acd0f · SoloScoreBadge · Button · 动态 | 独行 / 独行评分 %@ / 10 / 非常适合独行旅行者 / 对独行者可能略显暴露 / 双击查看评分明细 | 执行：showBreakdown.toggle() Haptics.impact(.light) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift:37` · P1 |
| IC-9c9af1d30d · SoloScoreBadge · popover  | 独行评分 %@ / 10 / 非常适合独行旅行者 / 对独行者可能略显暴露 / 双击查看评分明细 | 呈现/导航声明：.popover(isPresented: $showBreakdown) | binding: $showBreakdown) { | `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift:80` · P1 |
| IC-acd9e8fe62 · SoloScorePopoverContent · Button · 动态 | 点击查看该维度的通俗解释 | 执行：withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { expandedIndex = isExpanded ? nil : index } Haptics.selection() | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift:385` · P1 |

### `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-7d83fad87c · SoloScoreRadarChart · accessibilityAction · 动态 | 重播分数动画 | 执行：guard !reduceMotion else { return } replay() | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift:80` · P1 |
| IC-600f8bd1bb · SoloScoreRadarChart · accessibilityAction · 动态 | 重播分数动画 | 执行：guard !reduceMotion else { return } replay() | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift:154` · P1 |
| IC-a3a0e07bda · SoloScoreRadarChart · gesture  | 点击查看该维度的通俗解释 | 源码动作需沿调用方确认：.gesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift:244` · P1 |
| IC-2892156c27 · SoloScoreRadarChart · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：guard !reduceMotion, !isReplaying else { return } replay() | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift:259` · P1 |
| IC-711e2bcc5d · SoloScoreRadarChart · Button · 动态 | 点击查看该维度的通俗解释 | 执行：if fullyDrawn { tapAxis(strongestIndex) } | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift:367` · P1 |
| IC-7ffd881597 · SoloScoreRadarChart · Button · 动态 | 点击查看该维度的通俗解释 | 执行：if fullyDrawn { tapAxis(weakestIndex) } | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift:384` · P1 |
| IC-8cb25ad671 · SoloScoreRadarChart · accessibilityAction · 动态 | 重播分数动画 | 执行：guard !reduceMotion else { return } replay() | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift:411` · P1 |
| IC-4333da5db8 · SoloScoreRadarChart · gesture  | 点击查看该维度的通俗解释 | 源码动作需沿调用方确认：.gesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift:462` · P1 |

### `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-8fe856631b · VoiceButton · gesture · 动态 | 语音输入 / 长按说话，松开发送，上滑取消。或双击开始、再双击停止。 / 录音中 / 空闲 / 开始/停止语音输入 | 源码动作需沿调用方确认：.gesture( | isRecording; reduceMotion; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:107` · P1 |
| IC-8176ccac8e · VoiceButton · simultaneousGesture · 动态 | 语音输入 / 长按说话，松开发送，上滑取消。或双击开始、再双击停止。 / 录音中 / 空闲 / 开始/停止语音输入 | 源码动作需沿调用方确认：.simultaneousGesture( | isRecording; reduceMotion; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:111` · P1 |
| IC-66aaaf5905 · VoiceButton · accessibilityAction  | 开始/停止语音输入 / 需要麦克风权限 / 好 | 执行：apply(lifecycle.accessibilityToggle()) | binding: $showPermissionAlert) {; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:145` · P1 |
| IC-e856e8958a · VoiceButton · accessibilityAction  | 开始/停止语音输入 / 需要麦克风权限 / 好 | 执行：apply(lifecycle.accessibilityToggle()) | binding: $showPermissionAlert) {; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:148` · P1 |
| IC-7b4b261be1 · VoiceButton · alert · 动态 | 需要麦克风权限 / 好 / Solo Compass 需要麦克风和语音识别权限来接受语音输入。 / 语音识别错误 | 呈现/导航声明：.alert(NSLocalizedString("voice.permission.title", comment: ""), isPresented: $showPermissionAlert) | binding: $showPermissionAlert) {; binding: Binding(get: { recognitionError != nil }, set: { if !$0 { recognitionError = nil } })) {; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:151` · P1 |
| IC-623dd8a371 · VoiceButton · Button  | 好 | 执行： | cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:152` · P1 |
| IC-6b46ea8723 · VoiceButton · alert · 动态 | 语音识别错误 / 好 / 松开取消 / 剩余 %d 秒 / 我在听… | 呈现/导航声明：.alert(NSLocalizedString("voice.error.title", comment: "Voice recognition error"), isPresented: Binding(get: | binding: Binding(get: { recognitionError != nil }, set: { if !$0 { recognitionError = nil } })) {; isRecording; reduceMotion; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:156` · P1 |
| IC-625294c6e8 · VoiceButton · Button · 动态 | 好 | 执行：recognitionError = nil | cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:158` · P1 |

### `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-49a0bb9129 · TodayEntryDateSheet · DatePicker · 动态 | 入境日期 | 编辑/选择绑定：$entryDate | binding: $entryDate, in: ...Date(), displayedComponents: .date) | `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift:32` · P1 |
| IC-a8aced81ca · TodayEntryDateSheet · DatePicker · 动态 | 入境日期 | 编辑/选择绑定：$entryDate | binding: $entryDate, in: ...Date(), displayedComponents: .date) | `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift:37` · P1 |
| IC-0d482fd139 · TodayEntryDateSheet · TextField · 动态 | 例如 30 / 已确认的停留天数 | 编辑/选择绑定：$length | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift:41` · P1 |
| IC-8c999f4bc7 · TodayEntryDateSheet · Button  | 取消 | 执行：onDismiss | disabled(isSaving); isSaving | `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift:59` · P1 |
| IC-733b9a9ef9 · TodayEntryDateSheet · Button · 动态 | 保存 | 执行：guard let validLength, !isSaving else { return } isSaving = true preferences.visaLengthDays = validLength preferences.visaEntryDate = entryDate Task { await ComplianceService(pr | disabled(validLength == nil \|\| isSaving); isSaving | `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift:62` · P1 |
| IC-eba1419be4 · TodayCapsuleReceiptDetail · Button  | 完成 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayActionSheets.swift:107` · P1 |

### `apps/ios/SoloCompass/Views/Today/TodayContainer.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-d24117263c · TodayHomeScaffold · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $activeSheet) | binding: $activeSheet) { sheet in | `apps/ios/SoloCompass/Views/Today/TodayContainer.swift:148` · P1 |
| IC-f6d1404857 · TodayHomeScaffold · navigationDestination  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(for: NearbyDestination.self) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayContainer.swift:192` · P1 |
| IC-64f990c984 · TodayHomeScaffold · gesture  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.gesture(mapDragGesture(fullTravel: fullTravel)) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayContainer.swift:234` · P1 |
| IC-d1f5b02238 · TodayHomeScaffold · Button  | 返回 Today / 打开地图 | 执行：toggle() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayContainer.swift:238` · P1 |

### `apps/ios/SoloCompass/Views/Today/TodayNearbyRow.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-f88c2f2e71 · TodayNearbyRow · NavigationLink · 动态 | 这座城还没有游民 · 成为第一个 | 执行：rowShell { HStack(spacing: Space.md) { Image(systemName: "person.2.badge.plus") .font(.system(size: 20, weight: .semibold)) .foregroundStyle(CT.accent) Text(NSLocalizedString( " | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayNearbyRow.swift:40` · P1 |
| IC-ed06868415 · TodayNearbyRow · NavigationLink · 动态 | %d 位游民在附近 | 执行：rowShell { HStack(spacing: Space.md) { avatarStack(posts: posts) Text(String( format: NSLocalizedString( "today.nearby.count", comment: "%d nomads nearby in this city" ), posts. | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayNearbyRow.swift:59` · P1 |

### `apps/ios/SoloCompass/Views/Today/TodayNewHomeBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-352f583ca1 · TodayNewHomeBanner · Button  | 知道了 | 执行：dismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayNewHomeBanner.swift:59` · P1 |

### `apps/ios/SoloCompass/Views/Today/TodaySealReceipt.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-f2d660d0b1 · TodaySealReceipt · Button · 动态 | 昨天你封存了一个瞬间 | 执行：onOpen(capsule) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodaySealReceipt.swift:24` · P1 |

### `apps/ios/SoloCompass/Views/Today/TodayStatusHeader.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4984da1a29 · TodayStatusHeader · Button · 动态 | 填入境日 | 执行：onConfirmEntryDate | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayStatusHeader.swift:132` · P1 |

### `apps/web/src/app/(marketing)/download/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-1582e8655e · /download · ButtonLink · 动态 | {availability.action} | 导航：{dist.primaryHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/(marketing)/download/page.tsx:69` · P1 |
| WC-bc2fa7f89a · /download · ButtonLink · 动态 | Open the web map | 导航："/app" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/(marketing)/download/page.tsx:73` · P1 |

### `apps/web/src/app/(marketing)/privacy/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-8bad7b48cb · /privacy · a · 动态 | Read the full Privacy Policy | 导航：{LEGAL_URLS.privacy} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/(marketing)/privacy/page.tsx:119` · P2 |

### `apps/web/src/app/[city]/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-9c7a915707 · /[city] · TopBar · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:197` · P1 |
| WC-a2c1dba0c2 · /[city] · button · 动态 | {lang === "zh" ? "体验列表" : "Experiences"} | onClick={() => setMobileSurface("list")} | aria-pressed={mobileSurface === "list"} | `apps/web/src/app/[city]/page.tsx:210` · P1 |
| WC-8420e72266 · /[city] · button · 动态 | {lang === "zh" ? "示意地图" : "Illustrated map"} | onClick={() => setMobileSurface("map")} | aria-pressed={mobileSurface === "map"} | `apps/web/src/app/[city]/page.tsx:217` · P1 |
| WC-747a539d48 · /[city] · CommandPalette · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:262` · P1 |
| WC-a0ee2e253d · /[city] · Link · 动态 | {active && ( )} {label} | 导航：{`/${slug}${lang === "en" ? "?lang=en" : ""}`} | active | `apps/web/src/app/[city]/page.tsx:312` · P1 |
| WC-0fd2e917b2 · /[city] · button · 动态 | "Open command palette" | onClick={onOpenPalette} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:348` · P1 |
| WC-5da6926e5d · /[city] · button · 动态 | {l === "zh" ? "中" : "EN"} | onClick={() => setLang(l)} | active | `apps/web/src/app/[city]/page.tsx:406` · P1 |
| WC-6e290f1a94 · /[city] · Link · 动态 | Solo Compass | 导航："/" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:444` · P1 |
| WC-7d1468ff92 · /[city] · button · 动态 | {s.label} | onClick={() => p.setActiveSort(s.id)} | aria-pressed={a} | `apps/web/src/app/[city]/page.tsx:566` · P1 |
| WC-0119ef2f10 · /[city] · CatChip · 动态 | {p.T.allCats} | onClick={() => p.setActiveCat(null)} | active | `apps/web/src/app/[city]/page.tsx:593` · P1 |
| WC-d037409152 · /[city] · CatChip · 动态 | {p.lang === "zh" ? c.zh : c.en} | onClick={() => p.setActiveCat(p.activeCat === k ? null : k)} | active | `apps/web/src/app/[city]/page.tsx:602` · P1 |
| WC-d29562834f · /[city] · ListRow · 动态 | 动态/仅图形：需复核 | onClick={() => p.setFocusedId(e.id)} | focused; hover | `apps/web/src/app/[city]/page.tsx:616` · P1 |
| WC-47de254460 · /[city] · button · 动态 | {children} | onClick={onClick} | aria-pressed={active}; active | `apps/web/src/app/[city]/page.tsx:645` · P1 |
| WC-28aeddf98b · /[city] · button · 动态 | 动态/仅图形：需复核 | onClick={onClick} | aria-pressed={focused}; focused; hover | `apps/web/src/app/[city]/page.tsx:690` · P1 |
| WC-7b604ebb47 · /[city] · button · 动态 | {label} | onClick={onClick} | disabled={disabled} | `apps/web/src/app/[city]/page.tsx:859` · P1 |
| WC-53a854a730 · /[city] · WebLisbonMap · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:895` · P1 |
| WC-15aa1438fc · /[city] · MapControl · 动态 | 动态/仅图形：需复核 | onClick={() => p.setZoom(Math.min(2.5, p.zoom * 1.25))} | disabled={p.zoom >= 2.5} | `apps/web/src/app/[city]/page.tsx:920` · P1 |
| WC-dbae76a6e5 · /[city] · MapControl · 动态 | 动态/仅图形：需复核 | onClick={() => p.setZoom(Math.max(1, p.zoom / 1.25))} | disabled={p.zoom <= 1} | `apps/web/src/app/[city]/page.tsx:926` · P1 |
| WC-914ea69997 · /[city] · MapControl · 动态 | 动态/仅图形：需复核 | onClick={() => { p.setZoom(1); p.setCenterY(350); }} | disabled={p.zoom === 1 && p.centerY === 350} | `apps/web/src/app/[city]/page.tsx:932` · P1 |
| WC-109e663710 · /[city] · DetailDock · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | focused | `apps/web/src/app/[city]/page.tsx:1013` · P1 |
| WC-4583ee5b2f · /[city] · button · 动态 | "Close" | onClick={onClose} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:1056` · P1 |
| WC-576c40ecb8 · /[city] · Link · 动态 | {title} | 导航：{detailHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:1159` · P1 |
| WC-10a7d0d19c · /[city] · Link · 动态 | {T.liveMap} | 导航：{detailHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:1265` · P1 |

### `apps/web/src/app/app/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-3fe3dd84e3 · /app · MapView · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:136` · P1 |
| WC-755a4f8848 · /app · TodayBanner · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:144` · P1 |
| WC-cf2c98bdb8 · /app · VoiceIntent · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:146` · P1 |
| WC-37c4a9abf7 · /app · ExperienceSheet · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:159` · P1 |
| WC-71ee0dee93 · /app · button · 动态 | Back to the map | onClick={() => setSelection(null)} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:188` · P1 |
| WC-52b10cfb01 · /app · NearbySheet · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | loading | `apps/web/src/app/app/page.tsx:198` · P1 |

### `apps/web/src/app/experience/[id]/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-a686926997 · /experience/[id] · Link · 动态 | {T.backToCity} | 导航：{`/${city.slug}${lang === "en" ? "?lang=en" : ""}`} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/experience/[id]/page.tsx:213` · P1 |
| WC-a20a8e410b · /experience/[id] · Link · 动态 | {T.addToTrip} | 导航：{`/${city.slug}?experience=${encodeURIComponent(exp.id)}${lang === "en" ? "&lang=en" : ""}`} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/experience/[id]/page.tsx:466` · P1 |
| WC-12b29bc463 · /experience/[id] · Link · 动态 | ↗ {T.viewMap} | 导航：{`/${city.slug}${lang === "en" ? "?lang=en" : ""}`} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/experience/[id]/page.tsx:485` · P1 |
| WC-e431b81542 · /experience/[id] · Link · 动态 | {lang === "zh" ? ncat.zh : ncat.en} {ntitle} {nplace} · {it.walkMin} {T.mins} | 导航：{`/experience/${it.id}${lang === "en" ? "?lang=en" : ""}`} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/experience/[id]/page.tsx:548` · P1 |

### `apps/web/src/app/global-error.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-d7de59ad39 · GlobalError · button · 动态 | {zh ? "重试" : "Try again"} | onClick={reset} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/global-error.tsx:62` · P1 |
| WC-98a7b60483 · GlobalError · a · 动态 | {zh ? "回到地图" : "Back to map"} | 导航："/app" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/global-error.tsx:63` · P1 |

### `apps/web/src/app/layout.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-553e0cb4aa · RootLayout · a  | Skip to main content | 导航："#main" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/layout.tsx:38` · P1 |

### `apps/web/src/app/mobile-preview/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-21734ed65e · /mobile-preview · Link · 动态 | {T.back} | 导航：{`/lisbon${lang === "en" ? "?lang=en" : ""}`} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:142` · P2 |
| WC-10881d860a · /mobile-preview · PhoneFrame · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:171` · P2 |
| WC-03ef26ceb4 · /mobile-preview · CommandPalette · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:185` · P2 |
| WC-dc116c94b0 · /mobile-preview · button · 动态 | "Open command palette" | onClick={p.onOpenPalette} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:360` · P2 |
| WC-2191fbd85d · /mobile-preview · button · 动态 | {p.lang === "zh" ? "中文" : "EN"} | onClick={() => p.setLang(p.lang === "zh" ? "en" : "zh")} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:378` · P2 |
| WC-44f7ab9f28 · /mobile-preview · button · 动态 | { p.lang === "zh" ? p.sheetExpanded ? "收起体验列表" : "展开体验列表" : p.sheetExpanded ? "Collapse experiences" : "Expand experiences" } | onClick={p.toggleSheet} | aria-expanded={p.sheetExpanded} | `apps/web/src/app/mobile-preview/page.tsx:416` · P2 |
| WC-8876fb0d27 · /mobile-preview · a · 动态 | {distributionCopy(resolveDistribution().primaryKind, p.lang).action} | 导航：{resolveDistribution().primaryHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:524` · P2 |
| WC-2bd6d56d5a · /mobile-preview · button · 动态 | {p.T.maybeLater} | onClick={p.dismissHint} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:544` · P2 |
| WC-72d124fada · /mobile-preview · Link · 动态 | {title} {place} · {e.walkMin} {p.T.walkMin} | 导航：{`/experience/${e.id}${p.lang === "en" ? "?lang=en" : ""}`} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:592` · P2 |
| WC-f83a097b7c · /mobile-preview · button · 动态 | {checked ? `✓ ${p.T.checkedIn}` : p.T.checkIn} | onClick={() => p.toggleCheckin(e.id)} | aria-pressed={checked} | `apps/web/src/app/mobile-preview/page.tsx:636` · P2 |

### `apps/web/src/app/trip/[slug]/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-77c6e8372f · /trip/[slug] · Link · 动态 | { } {T.ctaButton} | 导航：{`/${trip.citySlug}${lang === "en" ? "?lang=en" : ""}`} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/trip/[slug]/page.tsx:459` · P1 |

### `apps/web/src/app/zh/privacy/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-42e7abfeff · /zh/privacy · a · 动态 | 阅读完整隐私政策 | 导航：{LEGAL_URLS.privacy} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/zh/privacy/page.tsx:109` · P2 |

### `apps/web/src/components/DesignNav.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-3b6f3c0fb0 · DesignNav · Link · 动态 | {it.label} | 导航：{it.href} | hover | `apps/web/src/components/DesignNav.tsx:35` · P1 |

### `apps/web/src/components/ExperienceSheet.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-c34001493b · handleCheckin · Drawer.Root · 动态 | { openerRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null; }} onCloseAutoFocus={(event) => { event | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/ExperienceSheet.tsx:58` · P1 |
| WC-db58118916 · handleCheckin · button · 动态 | "Close experience" | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | hover | `apps/web/src/components/ExperienceSheet.tsx:74` · P1 |
| WC-7a3152ea1f · handleCheckin · SheetBody · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/ExperienceSheet.tsx:87` · P1 |
| WC-0aaf426360 · SheetBody · a · 动态 | link | 导航：{s.url} | hover | `apps/web/src/components/ExperienceSheet.tsx:248` · P1 |
| WC-dfa8c66d84 · SheetBody · CheckinControl · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/ExperienceSheet.tsx:264` · P1 |
| WC-17c2395ba5 · CheckinControl · button · 动态 | {`Rate ${r} out of 5`} | onClick={() => onRate(r)} | disabled={busy}; aria-pressed={checkin.rating === r}; hover | `apps/web/src/components/ExperienceSheet.tsx:317` · P1 |
| WC-35cddd6078 · CheckinControl · button · 动态 | Retry | onClick={onRetry} | disabled={busy} | `apps/web/src/components/ExperienceSheet.tsx:342` · P1 |
| WC-e52504e519 · CheckinControl · button · 动态 | {busy ? "Saving…" : checkin.rating ? `I did this · ${checkin.rating}/5` : "I did this"} | onClick={onCheckin} | disabled={busy}; hover | `apps/web/src/components/ExperienceSheet.tsx:353` · P1 |

### `apps/web/src/components/MapView.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-cad636612a · MapView · button · 动态 | "Use my location" | onClick={handleLocate} | disabled={locateState === "locating"} | `apps/web/src/components/MapView.tsx:252` · P1 |
| WC-ab1da2a59e · MapUnavailableFallback · button · 动态 | Try loading the map again | onClick={onRetry} | hover | `apps/web/src/components/MapView.tsx:317` · P1 |
| WC-7e44fcc638 · MapView · NavigationControl · 动态 | 动态地图控件/标记：需运行时核实 accessible name | new mapboxgl.NavigationControl({ showCompass: false }), "top-right"); map.on("load", () => { setMapReady(true); const c = map.getCenter(); reportCenter([c.lng, c.lat]); }); map.on( | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/MapView.tsx:90` · P1 |
| WC-bdbf9b27f5 · MapView · click · 动态 | 动态地图控件/标记：需运行时核实 accessible name | .addEventListener("click", (event) => { event.stopPropagation(); onSelectRef.current(exp.id); }); const [lon, lat] = exp.location.coordinates; const marker = new mapboxgl.Marker({  | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/MapView.tsx:227` · P1 |
| WC-2fda5dddee · MapView · Marker · 动态 | 动态地图控件/标记：需运行时核实 accessible name | new mapboxgl.Marker({ element: el }).setLngLat([lon, lat]).addTo(map); markersRef.current.set(exp.id, marker); } }, [results, mapReady, selectedId]); useEffect(() => { const map =  | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/MapView.tsx:233` · P1 |
| WC-ace81d528a · MapView · click · 动态 | 动态地图控件/标记：需运行时核实 accessible name | .on("click", handler); return () => { map.off("click", handler); }; }, [mapReady]); return ( <div className="absolute inset-0 h-full w-full"> { } <button type="button" onClick={han | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/MapView.tsx:243` · P1 |

### `apps/web/src/components/NearbySheet.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-b4f3ba1d51 · setPanelLevel · button · 动态 | {isPeek ? "Expand nearby list" : "Collapse nearby list"} | onClick={() => { if (dragged.current) { dragged.current = false; return; } setPanelLevel(isPeek ? "half" : "peek"); }}；onPointerDown={(event) => { dragged.current = false; dragStar | aria-expanded={!isPeek} | `apps/web/src/components/NearbySheet.tsx:57` · P1 |
| WC-3ac02be1bb · setPanelLevel · TabButton · 动态 | Nearby {results.length > 0 ? `· ${results.length}` : ""} | onClick={() => setTab("nearby")} | active | `apps/web/src/components/NearbySheet.tsx:119` · P1 |
| WC-5311553f11 · setPanelLevel · TabButton · 动态 | My footprint | onClick={() => setTab("timeline")} | active | `apps/web/src/components/NearbySheet.tsx:122` · P1 |
| WC-2f4611d909 · setPanelLevel · button · 动态 | Try again | onClick={onRetry} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/NearbySheet.tsx:136` · P1 |
| WC-37cbb9919a · setPanelLevel · NearbyList · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | loading | `apps/web/src/components/NearbySheet.tsx:145` · P1 |
| WC-785002aa5b · setPanelLevel · TimelineList · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/NearbySheet.tsx:154` · P1 |
| WC-ddda58851a · PeekHeader · button · 动态 | {isPeek ? "Show the experience list" : "Experience list is open"} | onClick={onExpand} | aria-expanded={!isPeek} | `apps/web/src/components/NearbySheet.tsx:182` · P1 |
| WC-cf465a6eaf · TabButton · button · 动态 | {children} {active && ( )} | onClick={onClick} | aria-selected={active}; role="tab"; selected; active; hover | `apps/web/src/components/NearbySheet.tsx:220` · P1 |
| WC-917a8d7934 · NearbyList · NearbyCard · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | selected | `apps/web/src/components/NearbySheet.tsx:283` · P1 |
| WC-b8c16bf13e · NearbyCard · button · 动态 | {categoryEmoji[exp.category]} {exp.title} {exp.soloScore.overall.toFixed(1)} {exp.oneLiner} {categoryLabel[exp.category]} · {result.walkingM | onClick={() => onSelect(exp.id)} | selected; hover | `apps/web/src/components/NearbySheet.tsx:308` · P1 |

### `apps/web/src/components/ShareButton.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-337f03b17f · handleShare · button · 动态 | ↗ {labels.idle} | onClick={handleShare} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/ShareButton.tsx:52` · P1 |

### `apps/web/src/components/TimelineList.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-5d0bfe8f21 · TimelineList · button · 动态 | {isFetching ? "Trying again…" : "Try again"} | onClick={() => { void refetch(); }} | disabled={isFetching} | `apps/web/src/components/TimelineList.tsx:24` · P1 |
| WC-bae580f4f2 · TimelineList · TimelineCard · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/TimelineList.tsx:56` · P1 |
| WC-6abd810758 · TimelineCard · button · 动态 | {categoryEmoji[exp.category]} {exp.title} {entry.rating !== null && ( {"★".repeat(entry.rating)} {"★".repeat(5 - entry.rating)} )} {exp.oneL | onClick={() => onSelect?.(exp.id)} | hover | `apps/web/src/components/TimelineList.tsx:77` · P1 |

### `apps/web/src/components/TodayBanner.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-a10e3a46d1 · TodayBanner · button · 动态 | {categoryEmoji[p.experience.category]} {p.experience.title} {p.evidence} | onClick={() => onSelect(p.experience.id)} | hover | `apps/web/src/components/TodayBanner.tsx:42` · P1 |
| WC-45eea140f5 · TodayBanner · button · 动态 | "Dismiss today's picks" | onClick={handleDismiss} | hover | `apps/web/src/components/TodayBanner.tsx:55` · P1 |

### `apps/web/src/components/VoiceIntent.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-2ab2ca2664 · onPageHide · button · 动态 | {`Clear intent: ${intent}`} | onClick={() => onIntentChange(null)} | hover | `apps/web/src/components/VoiceIntent.tsx:209` · P1 |
| WC-0abafe6a00 · onPageHide · form · 动态 | setTextValue(e.target.value)} placeholder="What do you feel like?" aria-label="Type what you feel like doing" className="min-h-[44px] min-w- | onSubmit={handleTextSubmit} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/VoiceIntent.tsx:243` · P1 |
| WC-96d8c0212e · onPageHide · input · 动态 | "Type what you feel like doing" | onChange={(e) => setTextValue(e.target.value)} | value={textValue} | `apps/web/src/components/VoiceIntent.tsx:244` · P1 |
| WC-ec37bc100a · onPageHide · button · 动态 | {recording ? "Stop voice input" : "Start voice input"} | onClick={toggleRecording} | disabled={!micAvailable}; aria-pressed={recording}; recording | `apps/web/src/components/VoiceIntent.tsx:252` · P1 |
| WC-d98aedd017 · onPageHide · button · 动态 | Send | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | disabled={textValue.trim().length === 0}; hover | `apps/web/src/components/VoiceIntent.tsx:267` · P1 |

### `apps/web/src/components/lisbon/CommandPalette.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-bf48b87a7e · onKey · div · 动态 | "Command palette" | onKeyDown={trapTab}；onClick={() => onOpenChange(false)} | role="dialog" | `apps/web/src/components/lisbon/CommandPalette.tsx:249` · P1 |
| WC-d645a4ee19 · onKey · div · 动态 | setQuery(e.target.value)} aria-label={ lang === "zh" ? "搜索体验、城市与页面" : "Search experiences, cities and pages" } placeholder={ lang === "zh" ? | onClick={(e) => e.stopPropagation()} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/lisbon/CommandPalette.tsx:268` · P1 |
| WC-3d1bc1cc08 · onKey · input · 动态 | { lang === "zh" ? "搜索体验、城市与页面" : "Search experiences, cities and pages" } | onChange={(e) => setQuery(e.target.value)} | value={query} | `apps/web/src/components/lisbon/CommandPalette.tsx:295` · P1 |
| WC-1233ba7232 · onKey · button · 动态 | {it.title} {it.subtitle} {it.hint} | onClick={() => { onOpenChange(false); router.push(it.href); }} | active; hover | `apps/web/src/components/lisbon/CommandPalette.tsx:347` · P1 |
| WC-c6162a5ced · onKey · keydown · 动态 | 动态地图控件/标记：需运行时核实 accessible name | .addEventListener("keydown", onKey); return () => window.removeEventListener("keydown", onKey); }, [open, close, onOpenChange, filtered, activeIdx, router]); if (!open) return null | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/lisbon/CommandPalette.tsx:240` · P1 |

### `apps/web/src/components/lisbon/WebLisbonMap.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-d5de867d9a · WebLisbonMap · button · 动态 | {`${lang === "zh" ? p.titleZh : p.title} — ${lang === "zh" ? p.placeZh : p.place}, ${p.walkMin} ${lang === "zh" ? "分钟步行" : "min walk"}`} | onClick={() => onTap(p.id)} | aria-pressed={focusedId === p.id} | `apps/web/src/components/lisbon/WebLisbonMap.tsx:303` · P1 |

### `apps/web/src/components/marketing/MobileNav.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-2e469555f2 · onKeyDown · button · 动态 | {open ? closeLabel : menuLabel} | onClick={() => (open ? close(false) : setOpen(true))} | aria-expanded={open} | `apps/web/src/components/marketing/MobileNav.tsx:83` · P1 |
| WC-b9487b5be0 · onKeyDown · Link · 动态 | {it.label} | 导航：{it.href} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/MobileNav.tsx:104` · P1 |
| WC-3dba814499 · onKeyDown · Link · 动态 | {langLabel} | 导航：{langHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/MobileNav.tsx:115` · P1 |
| WC-fc09a6eef7 · onKeyDown · Link · 动态 | {ctaLabel} | 导航：{ctaHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/MobileNav.tsx:122` · P1 |
| WC-ea1f795888 · onKeyDown · keydown · 动态 | 动态地图控件/标记：需运行时核实 accessible name | .addEventListener("keydown", onKeyDown); return () => document.removeEventListener("keydown", onKeyDown); }, [open]); return ( <div className="md:hidden"> <button ref={triggerRef}  | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/marketing/MobileNav.tsx:77` · P1 |

### `apps/web/src/components/marketing/primitives.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-ea6cbe59bd · Button · button · 动态 | {busy && } {children} | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | disabled={disabled \|\| busy} | `apps/web/src/components/marketing/primitives.tsx:43` · P1 |
| WC-ed7fc11ae3 · ButtonLink · a · 动态 | {busy && } {children} | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | disabled={busy \|\| undefined} | `apps/web/src/components/marketing/primitives.tsx:63` · P1 |

### `apps/web/src/components/marketing/sections.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-366ad54439 · MarketingNav · Link · 动态 | Solo Compass | 导航：{homePath} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:53` · P1 |
| WC-a5143737e2 · MarketingNav · Link · 动态 | {it.label} | 导航：{it.href} | hover | `apps/web/src/components/marketing/sections.tsx:62` · P1 |
| WC-7e516de9d1 · MarketingNav · Link · 动态 | {copy.langSwitch} | 导航：{altPath} | hover | `apps/web/src/components/marketing/sections.tsx:76` · P1 |
| WC-c06a5b91f8 · MarketingNav · ButtonLink · 动态 | {ctaLabel} | 导航：{ctaHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:82` · P1 |
| WC-0cdf2041d3 · Hero · ButtonLink · 动态 | {ctaLabel} | 导航：{dist.primaryHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:151` · P1 |
| WC-f0c18af1d3 · Hero · a  | {copy.hero.ctaSecondary} → | 导航："#features" | hover | `apps/web/src/components/marketing/sections.tsx:154` · P1 |
| WC-f274292640 · Pricing · ButtonLink · 动态 | {planCta} | 导航：{planHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:467` · P1 |
| WC-0ee183ce91 · Pricing · ButtonLink · 动态 | {planCta} | 导航：{planHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:500` · P1 |
| WC-f4af8fa846 · Pricing · ButtonLink  | {copy.pricing.free} | 导航："/app" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:512` · P1 |
| WC-d916715a19 · Footer · Link · 动态 | {l.label} | 导航：{l.href} | hover | `apps/web/src/components/marketing/sections.tsx:566` · P1 |

## 未覆盖与验收要求

- 源码扫描不穷举所有运行时动态实例、地图引擎内建 UI、系统菜单和分享/权限面板。
- 候选 action/state/label 是局部提取的源码证据；复杂 label helper、条件局部变量和上层 callback 需沿调用链确认。
- 同一个可复用控件的 renderer 与调用点、以及父 sheet 与内容按钮会分别列出，不能直接相加为按钮数。
- 未用 Simulator、真实账号、StoreKit、摄像头或后端执行各个候选；评分不得据此宣称达到 96。
- Markdown 中所有行号属于 source_ref；并行修改后须 --working-tree 重跑并补运行时验收。

重复生成固定基线清单：

```bash
python3 docs/design/interaction-quality/generate_inventory.py
```

将交付中的工作区另存独立目录（保留固定基线）：

```bash
python3 docs/design/interaction-quality/generate_inventory.py --working-tree --output-dir docs/design/interaction-quality/current
```
