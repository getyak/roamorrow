# Web / iOS 全量源码交互清单

基线：`924f09a4ea7e3ed9b016ed9a956705a7e576cd5e`；盘点日期：2026-10-16。

扫描 **215 个 UI 源文件**，得到 **892 个源码交互候选**（Web 95、iOS 797），人工归并为 **44 个产品功能组**。这些数字都不是实际渲染按钮总数。

## 如何使用与审查边界

每个候选包含 route/screen、control、label、action、states、`source:line`、动态/条件标记、优先级与未验证状态。JSON 保存完整源码摘录和机器字段；下面保留逐文件覆盖和逐候选索引。

- `semantic_control`：Button / NavigationLink / Link 等语义控件。
- `input_control`：输入、选择、切换等控件，包含键盘提交。
- `gesture_or_semantic_control`：手势、可点击非语义容器与可访问性动作。
- `presentation_edge`：sheet / alert / menu 等导航和呈现关系，不应另计为一个按钮。
- `custom_component_call`：复用组件具体调用点，应与底层 renderer 联合核实，避免双算。
- `runtime_map_control` / `imperative_event_handler`：地图动态 marker、定位、缩放及手工事件。

已排除注释和 Swift `#Preview`。循环项目、菜单选项、条件可见性、SDK 控件随数据或环境变化；函数分组是能力目录，单组可包含多按钮，单控件也可能进入多个流程。所有运行时验收目前都标为 `not_verified`，不能将源码静态审查包装成每项 96 分。

## 设计判断口径

遵循 `frontend-design`：旅行的地图、真实体验和当前决策承担主体表达；色彩、边界和图案服务状态与信息层级。主动作只保留一个视觉重心；次级导航有稳定位置；触摸/键盘/VoiceOver 能到达相同动作；反馈说明动作结果；失败/空态有下一步；动效回应用户且尊重减少动态。

每组都需要核实默认、按下/焦点、选中、禁用原因、加载/取消、成功/撤销、失败/重试、空态/离线、键盘/VoiceOver、大字号/小屏、深色/减少动态、中英文本。局部源码出现状态变量仅表示已发现实现线索。

## 人工归并的产品功能目录

| ID | 平台 / route 或 screen | 控件与功能 | 优先级 | 源级候选 |
|---|---|---|---|---|
| W01 | web · 官网 EN/ZH 导航 | 品牌返回首页、功能锚点、定价、宣言、语言切换、获取 App | P1 | 4 |
| W02 | web · 官网 Hero/功能/信任/页脚 | 下载 CTA、探索功能、底部法律与支持链接；电话内 mock 中装饰形控件 | P1 | 5 |
| W03 | web · 定价 EN/ZH | 免费/Pro 方案 CTA、比较表、FAQ、页头与页脚 | P1 | 8 |
| W04 | web · 宣言 EN/ZH | 官网导航、末尾行动链接、页脚 | P2 | 5 |
| W05 | web · 隐私 EN/ZH | 隐私邮件、官网导航与页脚 | P2 | 7 |
| W06 | web · 下载 | App Store/候补联系方式、官网导航与页脚 | P1 | 7 |
| W07 | web · 共享 Web 控件 | 营销 Button/ButtonLink 的 hover/pressed/focus；跳到主内容；设计原型入口 | P1 | 4 |
| W08 | web · /app 地图 | 地图平移缩放、标记选择、定位/缩放/署名控件、体验浮层 | P1 | 9 |
| W09 | web · /app 附近和足迹 | 抽屉展开/收起、附近/时间线切换、体验行选择、空态与 loading | P1 | 11 |
| W10 | web · /app 今日 | 今日建议打开详情、关闭推荐横幅 | P1 | 2 |
| W11 | web · /app 语音/文本意图 | 按住说话、松手/离开停止、清除意图、权限/不支持时文本发送 | P1 | 5 |
| W12 | web · /app 体验详情 | 来源外链、关闭抽屉、我去过、可选 1–5 评分、saving/done | P1 | 6 |
| W13 | web · /[city] 城市工作台 | 城市入口、命令面板、语言、排序、分类切换、体验行与地图标记、详情与路线入口 | P1 | 21 |
| W14 | web · 城市命令面板 | 打开、搜索、方向键/回车、鼠标结果、Escape/遮罩关闭 | P1 | 5 |
| W15 | web · /mobile-preview | 语言、命令面板、抽屉、建议提示关闭、体验详情、签到 | P2 | 10 |
| W16 | web · /experience/[id] 分享体验 | 返回城市、地图导航、下载 App、来源、附近体验和页脚 | P1 | 4 |
| W17 | web · /trip/[slug] 分享行程 | 语言切换、体验/站点链接、地图、下载/返回城市 | P1 | 2 |
| I01 | ios · 地图主场景/城市 | 城市 pill、城市/地址/坐标选择、地图样式、回到定位、标记/聚类、筛选/排序、空态、快捷收藏与行程 | P1 | 109 |
| I02 | ios · 稳定导航/发现 | 地图/问问/发现三项 dock；问问长按语音；发现收藏与行程快捷入口、附近与路线、重试 | P1 | 31 |
| I03 | ios · 探索工作流 | 探索同意、进行中控制、取消/结束、handoff、进度与失败恢复 | P1 | 8 |
| I04 | ios · 保留对话/历史 | 展开/收起对话、历史选择/重命名/删除、新对话、建议问题、消息相关操作 | P1 | 27 |
| I05 | ios · 对话输入/附件 | 文本、多行输入、附件加号、照片/相机/文件、删除附件、发送/停止、地点上下文、错误清除 | P1 | 34 |
| I06 | ios · 语音 | 按住/切换录音、松手发送、上滑取消、倒计时、权限/识别错误、自动停止、录音条停止 | P1 | 7 |
| I07 | ios · AI 卡片/撤销/诊断 | 地点/路线卡打开、保存路线、provisional 校验、诊断同意/拒绝、banner action/关闭、撤销 | P1 | 13 |
| I08 | ios · 体验卡/预览 | 打开详情、收藏、长按菜单、上下文 Ask、收藏列表 | P1 | 43 |
| I09 | ios · 体验详情主动作 | 关闭、收藏、Ask Solo/付费门槛、完成/取消完成、加入行程、更多菜单、分享、导航应用选择、最佳时间跳转、雷达说明、附近体验 | P1 | 38 |
| I10 | ios · 体验新增/修正/反馈 | 创建标题/分类/位置等字段、保存/取消、微调查、报告类型与详情、旅行者笔记、重新编译 | P1 | 31 |
| I11 | ios · 体验分享/导出 | 分享卡样式、导出图片、系统分享、Markdown 复制/分享/Notion、关闭 | P2 | 13 |
| I12 | ios · 行程列表/创建 | 新建、类型/城市/日期/名称/备注、保存、取消、列表行与删除 | P1 | 29 |
| I13 | ios · 行程详情 | 编辑/删除/重排站点、导入收藏确认、添加体验、公开招募、关闭可见性提示、显示更多 | P1 | 16 |
| I14 | ios · 路线创建/详情 | 新建路线、选站、顺序、路线详情、开始/结束、加入/发布、分享、招募状态 | P1 | 20 |
| I15 | ios · 路线招募/申请 | 开放招募、步速/留言、发送申请、我的申请撤回、审批接受/拒绝、自己发起/走过路线 | P1 | 29 |
| I16 | ios · 同伴发现/安全 | 列表排序/刷新、招募详情、联系申请、收件箱、举报/屏蔽、同意安全条款 | P1 | 48 |
| I17 | ios · 同伴资料/消息 | 昵称/简介/偏好/可见性、保存、会话选择、发消息、邀请好友、完成瞬间 | P1 | 23 |
| I18 | ios · 路线分享 | 分享样式、系统分享、邀请、关闭 | P2 | 7 |
| I19 | ios · 好友入口/邀请/扫码 | 好友码、复制/分享、扫码、输入码、预览资料、发送/接受/拒绝/撤回请求、移除/屏蔽好友、重试 | P1 | 53 |
| I20 | ios · 我的/权益 | 个人/仪式切换、资料/收藏/行程/好友/消息入口、设置、付费入口、关闭 | P1 | 13 |
| I21 | ios · 设置及子页 | 旅行风格、偏爱/隐藏/可见分类、自定义标签、语言/主题、AI/数据源/通知、同伴 hub、导出、删除/重置、开发选项解锁 | P1 | 87 |
| I22 | ios · 首次使用/条款 | 跳过、前进/后退、城市与偏好、照片、接受/拒绝隐私条款、位置权限 | P1 | 27 |
| I23 | ios · 付费 | 月/年方案、购买、继续免费、恢复购买、关闭、错误确认 | P1 | 8 |
| I24 | ios · 今日/城市工具 | 入境日期、今日三件事、下一步/附近、提醒横幅关闭、回执、基地确认/切换、城市工具待办/导航、Visa 提醒/日期、活动去地图、核实问答 | P1 | 27 |
| I25 | ios · 仪式/归档 | 归档/城市手册、解锁、盲盒时长/开始/稍后/分享、时光胶囊输入/时间/埋藏/回复/关闭、今日签完成、分享卡/壁纸/视频解锁 | P2 | 27 |
| I26 | ios · 管理/共享反馈组件 | 管理审核、banner 关闭/重试、check-in 提示、空态 action、全局手势和通用按压样式 | P1 | 16 |
| I27 | ios · 信任解释/独行评分 | 置信度说明 popover、独行评分说明、雷达维度点击/拖动与 VoiceOver 调整、关闭解释 | P1 | 13 |

## 逐组设计分析

以下是基于功能、现有控件与源码状态的明确设计建议；观感、动效、触摸成功率仍需运行时复核。

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
| V02 · 手机mock：渐变图/信任chips/评分条/热力图 | 图案应说明真实体验结构，明确示例；装饰按钮不能制造操作承诺。 | 中英/深色/320px查看文字与图案；热力图减少动态时静止。 | `apps/web/src/components/marketing/DayPageMock.tsx:41` |
| V03 · 功能示意图：问问/盲盒/胶囊/预兆/BestNow/旅记 | 同一视觉材质可保留，六功能不必各自用新强色/边框。 | 核实示例标签、来源可信度和当前真实能力一致；不把示例AI理由写成可验证事实。 | `apps/web/src/components/marketing/CapabilityMocks.tsx:15` |
| V04 · Hero逐层reveal | 标题逐行、正文、CTA、手机多段延迟与氛围并存，注意力可能过多。 | 首次可用CTA不能依赖漫长入场；开启减少动态完全可见；仅通过实测决定压缩入场。 | `apps/web/src/components/marketing/sections.tsx:124` |
| V05 · 城市示意图选中/hover光环 | 2.4秒无限循环，基线没有对应prefers-reduced-motion停用分支。 | 减少动态时停用；选中用静态颜色/形状也能识别，避免常态脉冲争抢。 | `apps/web/src/app/globals.css:409` |
| V06 · 字体与中英排版 | 当前Space Grotesk/Inter/JetBrains Mono/Fraunces/中文fallback五角色需节制；数据标签uppercase不适合泛化每段。 | 只保留有信息作用的标签；正文行长、汉字字重和字体加载前后分别核实。 | `apps/web/src/app/globals.css:86` |
| V07 · 城市示意地图：纸纹/等高线/河流/街道/标签 | 与地图主题有关的图案比通用渐变更能表达旅行，但必须继续明确非地理导航示意。 | 低对比纹理不抢marker，选中点/列表关联清楚，键盘仍可选点。 | `apps/web/src/components/lisbon/WebLisbonMap.tsx:112` |
| V08 · 按钮层级/边框/阴影 | primary填色、secondary描边、ghost文字已有层级；不要再给每个普通交互增加强阴影。 | 按下/hover/focus均可辨，减少动态下不位移；dark on-accent见Q20。 | `apps/web/src/components/marketing/primitives.tsx:10` |
| V09 · iOS空间/圆角/材质/阴影 | 已存在4pt空间与语义材质，新增界面优先复用；不做单纯全局换半径。 | 在真正使用点检查token采用与大小层级，不能仅看token定义声称全局统一。 | `apps/ios/SoloCompass/Views/Shared/DesignTokens.swift:21` |
| V10 · iOS颜色与跨端token | 固定明色token和自适应dark token并存；调用方必须与实际背景匹配。 | 实际组合测正文/徽章/禁用态/焦点对比；用语义状态而非为不同卡随意添色。 | `apps/ios/SoloCompass/Views/Shared/CompareTokens.swift:7` |
| V11 · 来源徽章小字/描边 | compact9.5pt、uppercase/字距、fixedSize和独立边界可能降低可读性并增加边缘密度，此处仅为设计风险。 | 大字号、深色、小屏、长来源词实测；扩大内容可读性，不把静态说明变主CTA。 | `apps/ios/SoloCompass/Views/Shared/TrustBadge.swift:66` |
| V12 · 通用按压缩放与触觉 | 默认0.92缩放8%，haptic默认关闭并尊重减少动态；不能为了感觉有交互让所有导航都震动。 | 小标签与大主按钮分别实测按压幅度；提交才触觉确认，取消手势不假报成功。 | `apps/ios/SoloCompass/Views/Shared/PressableButtonStyle.swift:20` |

## 官网 EN / ZH 数据驱动链接展开

以下为 copy 数据与组件绑定产生的实际标签/落点表达；它们是上述候选的实例说明，不能另加到候选数。`APP_STORE_URL`在起始基线为占位 SKU，见 Q01。

| 实例 / 语言 | 位置 | label | target |
|---|---|---|---|
| MR-en-001 · en | nav.brand | Solo Compass | `/` |
| MR-en-002 · en | nav.features | Features | `/#features` |
| MR-en-003 · en | nav.pricing | Pricing | `/pricing` |
| MR-en-004 · en | nav.manifesto | Manifesto | `/manifesto` |
| MR-en-005 · en | nav.language | 中文 | `/zh` |
| MR-en-006 · en | nav.getApp | Get on App Store | `APP_STORE_URL` |
| MR-en-007 · en | hero.primary | Get on App Store | `APP_STORE_URL` |
| MR-en-008 · en | hero.secondary | See how it works | `#features` |
| MR-en-009 · en | pricing.lifetime | Buy Once | `APP_STORE_URL` |
| MR-en-010 · en | pricing.yearly | Start Yearly | `APP_STORE_URL` |
| MR-en-011 · en | pricing.free | Or try Free first — no card, no signup | `/pricing` |
| MR-en-012 · en | footer.Product | Features | `/#features` |
| MR-en-013 · en | footer.Product | Pricing | `/pricing` |
| MR-en-014 · en | footer.Product | Download | `/download` |
| MR-en-015 · en | footer.Company | Manifesto | `/manifesto` |
| MR-en-016 · en | footer.Company | Contact | `mailto:hello@solocompass.app` |
| MR-en-017 · en | footer.Legal | Privacy | `/privacy` |
| MR-zh-018 · zh | nav.brand | Solo Compass | `/zh` |
| MR-zh-019 · zh | nav.features | 功能 | `/zh/#features` |
| MR-zh-020 · zh | nav.pricing | 价格 | `/zh/pricing` |
| MR-zh-021 · zh | nav.manifesto | 宣言 | `/zh/manifesto` |
| MR-zh-022 · zh | nav.language | English | `/` |
| MR-zh-023 · zh | nav.getApp | App Store 下载 | `APP_STORE_URL` |
| MR-zh-024 · zh | hero.primary | App Store 下载 | `APP_STORE_URL` |
| MR-zh-025 · zh | hero.secondary | 看看它是什么样 | `#features` |
| MR-zh-026 · zh | pricing.lifetime | 一次买断 | `APP_STORE_URL` |
| MR-zh-027 · zh | pricing.yearly | 订阅年度 | `APP_STORE_URL` |
| MR-zh-028 · zh | pricing.free | 或先免费试用 —— 无需信用卡，无需注册 | `/zh/pricing` |
| MR-zh-029 · zh | footer.产品 | 功能 | `/zh/#features` |
| MR-zh-030 · zh | footer.产品 | 价格 | `/zh/pricing` |
| MR-zh-031 · zh | footer.产品 | 下载 | `/download` |
| MR-zh-032 · zh | footer.关于 | 宣言 | `/zh/manifesto` |
| MR-zh-033 · zh | footer.关于 | 联系 | `mailto:hello@solocompass.app` |
| MR-zh-034 · zh | footer.法律 | 隐私 | `/zh/privacy` |

## Web route 与组件组合

| route | 页面模块 | 组件集合（含本模块 helper） |
|---|---|---|
| `/download` | `apps/web/src/app/(marketing)/download/page.tsx` | MarketingNav, Section, Container, Eyebrow, ButtonLink, Footer |
| `/manifesto` | `apps/web/src/app/(marketing)/manifesto/page.tsx` | MarketingNav, Section, Container, Eyebrow, Footer |
| `/pricing` | `apps/web/src/app/(marketing)/pricing/page.tsx` | HomeJsonLd, MarketingNav, Section, Container, Eyebrow, Pricing, Footer |
| `/privacy` | `apps/web/src/app/(marketing)/privacy/page.tsx` | MarketingNav, Section, Container, Eyebrow, Footer |
| `/[city]` | `apps/web/src/app/[city]/page.tsx` | WebCategoryId, Sort, TopBar, ListColumn, RightSurface, StatusBar, CommandPalette, Logo, Link, CatChip, ListRow, WebLisbonMap, DetailDock, MetaRow |
| `/app` | `apps/web/src/app/app/page.tsx` | MapView, DesignNav, TodayBanner, VoiceIntent, ExperienceSheet, NearbySheet, Suspense, HomeInner |
| `/experience/[id]` | `apps/web/src/app/experience/[id]/page.tsx` | Record, Metadata, ExperienceView, Link |
| `/mobile-preview` | `apps/web/src/app/mobile-preview/page.tsx` | Set, Link, PhoneFrame, CommandPalette, Suspense, MobilePreviewInner, WebLisbonMap |
| `/` | `apps/web/src/app/page.tsx` | HomeJsonLd, MarketingNav, Hero, Problem, Pillars, Capabilities, Trust, Pricing, Footer |
| `/trip/[slug]` | `apps/web/src/app/trip/[slug]/page.tsx` | Record, Metadata, TripRecap, Link |
| `/zh/manifesto` | `apps/web/src/app/zh/manifesto/page.tsx` | MarketingNav, Section, Container, Eyebrow, Footer |
| `/zh` | `apps/web/src/app/zh/page.tsx` | HomeJsonLd, MarketingNav, Hero, Problem, Pillars, Capabilities, Trust, Pricing, Footer |
| `/zh/pricing` | `apps/web/src/app/zh/pricing/page.tsx` | HomeJsonLd, MarketingNav, Section, Container, Eyebrow, Pricing, Footer |
| `/zh/privacy` | `apps/web/src/app/zh/privacy/page.tsx` | MarketingNav, Section, Container, Eyebrow, Footer |

## 城市 / 分类 / 体验 / 行程动态实例

当前静态Web示例数据包含2个城市、7个分类、12个体验、1个回顾行程。地图点、列表行、命令结果复用同一数据，各实例仍须验证；/app后端数据和原生持久层数量由环境决定。

| 类别 / ID | 中文 / English | 结果 |
|---|---|---|
| 城市 · lisbon | 里斯本 / Lisbon | `/lisbon` |
| 城市 · porto | 波尔图 / Porto | `/porto` |
| 分类 · miradouro | 观景台 / Viewpoints | 切换该分类过滤；再次选择已激活分类清除 |
| 分类 · cafe | 咖啡 / Cafés | 切换该分类过滤；再次选择已激活分类清除 |
| 分类 · food | 吃饭 / Food | 切换该分类过滤；再次选择已激活分类清除 |
| 分类 · fado | 法多 / Fado | 切换该分类过滤；再次选择已激活分类清除 |
| 分类 · walk | 散步 / Walks | 切换该分类过滤；再次选择已激活分类清除 |
| 分类 · hidden | 冷门 / Hidden | 切换该分类过滤；再次选择已激活分类清除 |
| 分类 · bookshop | 书店 / Bookshops | 切换该分类过滤；再次选择已激活分类清除 |
| 体验 · miradouro-graca | 在倾斜的城市里等日落 / Watch the city tilt at sunset | 选中地图/列表；详情 `/experience/miradouro-graca` |
| 体验 · pasteis-de-belem | 在发明它的地方吃一只蛋挞 / Eat a pastel where they invented it | 选中地图/列表；详情 `/experience/pasteis-de-belem` |
| 体验 · a-vida-portuguesa | 在百年老店里把每一样东西摸一遍 / Touch every object in a hundred-year shop | 选中地图/列表；详情 `/experience/a-vida-portuguesa` |
| 体验 · tasca-do-chico | 站在一家小酒馆里让法多找到你 / Stand in a tasca and let fado find you | 选中地图/列表；详情 `/experience/tasca-do-chico` |
| 体验 · feira-da-ladra | 周二一早去逛贼市 / Walk the thieves' market on a Tuesday morning | 选中地图/列表；详情 `/experience/feira-da-ladra` |
| 体验 · livraria-bertrand | 在世界上最古老的书店楼上读一会儿 / Read upstairs at the world's oldest bookshop | 选中地图/列表；详情 `/experience/livraria-bertrand` |
| 体验 · tram-28 | 7 点骑 28 路电车，在游客醒之前 / Ride tram 28 at 7am before the tourists wake up | 选中地图/列表；详情 `/experience/tram-28` |
| 体验 · porto-livraria-lello | 在拍照人群到来之前爬上那道红楼梯 / Climb the red staircase before the photographers arrive | 选中地图/列表；详情 `/experience/porto-livraria-lello` |
| 体验 · porto-ribeira-walk | 在金色时分沿杜罗河走一程 / Walk the Douro at golden hour | 选中地图/列表；详情 `/experience/porto-ribeira-walk` |
| 体验 · porto-majestic-cafe | 像 1921 年那样点一份热三明治 / Order a tostada mista like it's 1921 | 选中地图/列表；详情 `/experience/porto-majestic-cafe` |
| 体验 · porto-azulejos | 在瓷砖上读完一个国家的历史 / Read the entire history of a country in tiles | 选中地图/列表；详情 `/experience/porto-azulejos` |
| 体验 · porto-vinho-do-porto | 过河喝一杯波特酒 / Cross the river for a port tasting | 选中地图/列表；详情 `/experience/porto-vinho-do-porto` |
| 行程 · sofia-lisbon-may-2025 | 四天 · 在里斯本 / Four days, in Lisbon | `/trip/sofia-lisbon-may-2025` |

## 逐文件覆盖

候选为零的文件仍列出：静态页面会通过公共导航/CTA 获得交互，纯视觉组件也属于图案与注意力审查范围。

| 文件 | 行数 | 候选 | 类别 |
|---|---:|---:|---|
| `apps/ios/SoloCompass/App/SoloCompassApp.swift` | 386 | 2 | presentation_edge: 1, custom_component_call: 1 |
| `apps/ios/SoloCompass/Views/Admin/ModerationView.swift` | 189 | 4 | gesture_or_semantic_control: 1, presentation_edge: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Archive/ArchiveView.swift` | 597 | 9 | presentation_edge: 1, custom_component_call: 7, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Archive/CityCodexView.swift` | 112 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift` | 86 | 3 | input_control: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Blindbox/BlindboxRecapCard.swift` | 95 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Brag/BragCardTemplateBackground.swift` | 173 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Brag/BragCardView.swift` | 114 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift` | 96 | 4 | input_control: 2, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift` | 115 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Chat/AttachmentBubble.swift` | 321 | 6 | presentation_edge: 1, gesture_or_semantic_control: 3, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Chat/AttachmentDraftStrip.swift` | 148 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift` | 309 | 12 | presentation_edge: 4, semantic_control: 6, input_control: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/ChatCardStack.swift` | 485 | 2 | gesture_or_semantic_control: 1, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift` | 556 | 6 | semantic_control: 6 |
| `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift` | 141 | 3 | semantic_control: 2, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift` | 867 | 15 | presentation_edge: 4, semantic_control: 6, gesture_or_semantic_control: 4, input_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift` | 2338 | 12 | presentation_edge: 1, semantic_control: 8, gesture_or_semantic_control: 2, custom_component_call: 1 |
| `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift` | 282 | 3 | gesture_or_semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Chat/DiagnosticsRequestCard.swift` | 128 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/HalfExpandedEmptyState.swift` | 245 | 2 | semantic_control: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Chat/InlineBanner.swift` | 182 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Chat/LocalAttachment.swift` | 48 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/MarkdownMessageText.swift` | 201 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/MessageBubble.swift` | 527 | 7 | semantic_control: 4, gesture_or_semantic_control: 1, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Chat/SoloAgentBubbleQueue.swift` | 221 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Chat/SoloOrb.swift` | 91 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/ThinkingBorderShimmer.swift` | 56 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Chat/UndoPill.swift` | 79 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/CityOS/BaseCard.swift` | 279 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/CityOS/BaseFace.swift` | 73 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift` | 544 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/CityOS/CityOSComponents.swift` | 82 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/CityOS/ComplianceBanner.swift` | 102 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/CityOS/EventMarkerView.swift` | 127 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift` | 424 | 7 | semantic_control: 4, input_control: 3 |
| `apps/ios/SoloCompass/Views/CityOS/LiveSheet.swift` | 221 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift` | 165 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift` | 235 | 7 | semantic_control: 5, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift` | 591 | 4 | semantic_control: 3, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Companion/ChatView.swift` | 455 | 8 | semantic_control: 4, custom_component_call: 2, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Companion/CompanionMapLayer.swift` | 147 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/CompanionProfileView.swift` | 432 | 8 | presentation_edge: 1, semantic_control: 5, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift` | 214 | 5 | semantic_control: 3, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/CompletionMoment.swift` | 197 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/Components/AvatarStack.swift` | 195 | 2 | semantic_control: 1, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Companion/Components/RecruitingModule.swift` | 533 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/Components/RouteCard.swift` | 575 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Components/StopsList.swift` | 242 | 1 | gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/Components/VerifiedBadge.swift` | 234 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift` | 277 | 3 | semantic_control: 1, presentation_edge: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift` | 378 | 7 | semantic_control: 5, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift` | 480 | 13 | semantic_control: 7, presentation_edge: 5, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift` | 198 | 3 | semantic_control: 2, input_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift` | 296 | 3 | presentation_edge: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift` | 360 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift` | 600 | 16 | gesture_or_semantic_control: 1, semantic_control: 9, presentation_edge: 4, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/ItineraryFormView.swift` | 352 | 13 | semantic_control: 5, presentation_edge: 2, input_control: 6 |
| `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift` | 429 | 9 | semantic_control: 5, presentation_edge: 2, gesture_or_semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift` | 295 | 4 | semantic_control: 2, input_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/MyHostedRoutesListView.swift` | 212 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/MyRequestsListView.swift` | 358 | 5 | presentation_edge: 2, semantic_control: 2, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/MyWalkedRoutesListView.swift` | 143 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift` | 282 | 9 | semantic_control: 2, input_control: 7 |
| `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift` | 233 | 12 | semantic_control: 7, presentation_edge: 3, gesture_or_semantic_control: 1, input_control: 1 |
| `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift` | 434 | 12 | semantic_control: 7, presentation_edge: 3, gesture_or_semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift` | 741 | 7 | presentation_edge: 3, semantic_control: 4 |
| `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift` | 266 | 7 | semantic_control: 6, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift` | 143 | 3 | input_control: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteMapSnapshotter.swift` | 74 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RoutePolylineShape.swift` | 90 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteShareCardView.swift` | 360 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteSharePayload.swift` | 140 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteShareRenderer.swift` | 82 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Companion/Share/RouteShareStyle.swift` | 35 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift` | 310 | 12 | semantic_control: 5, presentation_edge: 1, input_control: 6 |
| `apps/ios/SoloCompass/Views/Experience/ExperienceCardView.swift` | 1146 | 14 | semantic_control: 9, gesture_or_semantic_control: 5 |
| `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift` | 1962 | 32 | gesture_or_semantic_control: 2, semantic_control: 17, presentation_edge: 8, custom_component_call: 5 |
| `apps/ios/SoloCompass/Views/Experience/LocationCard.swift` | 227 | 6 | semantic_control: 5, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Experience/MarkdownShareSheet.swift` | 107 | 5 | semantic_control: 4, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Experience/MicroSurveySheet.swift` | 281 | 5 | semantic_control: 4, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Experience/RecompileFeedSheet.swift` | 202 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift` | 174 | 4 | semantic_control: 2, gesture_or_semantic_control: 1, input_control: 1 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareCardComponents.swift` | 100 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareCardModel.swift` | 177 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareCardRenderer.swift` | 45 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareCardView.swift` | 350 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift` | 295 | 8 | semantic_control: 7, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift` | 562 | 9 | semantic_control: 7, input_control: 1, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift` | 907 | 8 | gesture_or_semantic_control: 1, semantic_control: 7 |
| `apps/ios/SoloCompass/Views/Friends/AddFriendButton.swift` | 161 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Friends/AddFriendSheet.swift` | 511 | 15 | input_control: 2, semantic_control: 9, presentation_edge: 3, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Friends/FriendProfileView.swift` | 448 | 4 | custom_component_call: 3, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Friends/FriendsHubView.swift` | 510 | 11 | presentation_edge: 2, input_control: 1, gesture_or_semantic_control: 1, semantic_control: 7 |
| `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift` | 671 | 22 | gesture_or_semantic_control: 4, semantic_control: 11, presentation_edge: 6, custom_component_call: 1 |
| `apps/ios/SoloCompass/Views/Friends/QRScannerView.swift` | 150 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Insight/InsightCardView.swift` | 91 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/ActiveRouteOverlay.swift` | 113 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/BottomInfoSheet.swift` | 1181 | 7 | gesture_or_semantic_control: 4, presentation_edge: 1, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Map/CityPickerSheet.swift` | 402 | 5 | semantic_control: 4, input_control: 1 |
| `apps/ios/SoloCompass/Views/Map/ClusterAnnotationView.swift` | 30 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/CompassMapView.swift` | 5061 | 63 | presentation_edge: 17, semantic_control: 19, custom_component_call: 16, gesture_or_semantic_control: 10, runtime_map_control: 1 |
| `apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift` | 240 | 5 | semantic_control: 4, gesture_or_semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift` | 160 | 4 | semantic_control: 2, presentation_edge: 1, custom_component_call: 1 |
| `apps/ios/SoloCompass/Views/Map/ExploreHandoffCard.swift` | 271 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Map/ExploreModeOverlay.swift` | 268 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Map/ExploreProgressBar.swift` | 67 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/ExploreSessionDimModifier.swift` | 34 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift` | 740 | 28 | input_control: 6, semantic_control: 16, presentation_edge: 4, gesture_or_semantic_control: 2 |
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
| `apps/ios/SoloCompass/Views/Me/EntitlementBanner.swift` | 205 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Me/MeSheet.swift` | 610 | 12 | input_control: 1, semantic_control: 9, presentation_edge: 2 |
| `apps/ios/SoloCompass/Views/Omen/OmenCardView.swift` | 100 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Onboarding/OnboardingCityStep.swift` | 133 | 3 | input_control: 2, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Onboarding/OnboardingCohortStep.swift` | 189 | 3 | semantic_control: 3 |
| `apps/ios/SoloCompass/Views/Onboarding/OnboardingVibeStep.swift` | 231 | 4 | input_control: 2, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift` | 747 | 10 | semantic_control: 10 |
| `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift` | 161 | 5 | semantic_control: 5 |
| `apps/ios/SoloCompass/Views/Ost/OstShareCard.swift` | 80 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift` | 464 | 8 | semantic_control: 7, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift` | 220 | 4 | gesture_or_semantic_control: 1, input_control: 3 |
| `apps/ios/SoloCompass/Views/Settings/DataSourceSettingsView.swift` | 197 | 3 | input_control: 2, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Settings/DeveloperOptionsView.swift` | 491 | 15 | presentation_edge: 2, semantic_control: 10, input_control: 3 |
| `apps/ios/SoloCompass/Views/Settings/NotificationsSettingsView.swift` | 46 | 3 | input_control: 3 |
| `apps/ios/SoloCompass/Views/Settings/SettingsView.swift` | 1395 | 62 | semantic_control: 35, presentation_edge: 11, custom_component_call: 1, input_control: 9, gesture_or_semantic_control: 6 |
| `apps/ios/SoloCompass/Views/Shared/BestNowChipState.swift` | 115 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/BilingualCityRow.swift` | 55 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/BottomInfoBar.swift` | 95 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/ChatStateModifier.swift` | 149 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/Color+Hex.swift` | 14 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/CompareTokens.swift` | 238 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/CompletionCelebrationView.swift` | 221 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift` | 384 | 2 | semantic_control: 1, presentation_edge: 1 |
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
| `apps/ios/SoloCompass/Views/Shared/PendingCheckInBanner.swift` | 314 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Shared/PressableButtonStyle.swift` | 61 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SkeletonBadgeView.swift` | 47 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SkeletonView.swift` | 206 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SoloCompassTips.swift` | 69 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SoloEmptyState.swift` | 103 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Shared/SoloMascotView.swift` | 319 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift` | 574 | 3 | semantic_control: 2, presentation_edge: 1 |
| `apps/ios/SoloCompass/Views/Shared/SoloScoreRadarChart.swift` | 642 | 8 | gesture_or_semantic_control: 6, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Shared/ToolRouterContractPreview.swift` | 168 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/TrustBadge.swift` | 155 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/UrgencyPulse.swift` | 36 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift` | 498 | 7 | gesture_or_semantic_control: 3, presentation_edge: 2, semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Shared/VoiceWaveformView.swift` | 94 | 0 | 无直接候选；检查调用组件 |
| `apps/ios/SoloCompass/Views/Today/TodayContainer.swift` | 260 | 3 | presentation_edge: 1, gesture_or_semantic_control: 1, semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Today/TodayNearbyRow.swift` | 128 | 2 | semantic_control: 2 |
| `apps/ios/SoloCompass/Views/Today/TodayNewHomeBanner.swift` | 93 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Today/TodaySealReceipt.swift` | 99 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Today/TodayStatusHeader.swift` | 165 | 1 | semantic_control: 1 |
| `apps/ios/SoloCompass/Views/Today/TodayThreeThings.swift` | 238 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/(marketing)/download/page.tsx` | 110 | 2 | semantic_control: 2 |
| `apps/web/src/app/(marketing)/manifesto/page.tsx` | 106 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/(marketing)/pricing/page.tsx` | 103 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/(marketing)/privacy/page.tsx` | 180 | 1 | semantic_control: 1 |
| `apps/web/src/app/[city]/page.tsx` | 1234 | 20 | custom_component_call: 7, semantic_control: 12, gesture_or_semantic_control: 1 |
| `apps/web/src/app/_seo.tsx` | 78 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/app/page.tsx` | 110 | 5 | custom_component_call: 5 |
| `apps/web/src/app/apple-icon.tsx` | 30 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/experience/[id]/opengraph-image.tsx` | 218 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/experience/[id]/page.tsx` | 663 | 4 | semantic_control: 4 |
| `apps/web/src/app/global-error.tsx` | 19 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/icon.tsx` | 28 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/layout.tsx` | 51 | 1 | semantic_control: 1 |
| `apps/web/src/app/mobile-preview/page.tsx` | 673 | 10 | semantic_control: 8, custom_component_call: 2 |
| `apps/web/src/app/opengraph-image.tsx` | 63 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/page.tsx` | 83 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/trip/[slug]/opengraph-image.tsx` | 197 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/trip/[slug]/page.tsx` | 485 | 2 | semantic_control: 2 |
| `apps/web/src/app/zh/manifesto/page.tsx` | 107 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/zh/opengraph-image.tsx` | 63 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/zh/page.tsx` | 81 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/zh/pricing/page.tsx` | 101 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/app/zh/privacy/page.tsx` | 177 | 1 | semantic_control: 1 |
| `apps/web/src/components/DesignNav.tsx` | 46 | 1 | semantic_control: 1 |
| `apps/web/src/components/ExperienceSheet.tsx` | 292 | 6 | custom_component_call: 3, semantic_control: 3 |
| `apps/web/src/components/MapView.tsx` | 182 | 4 | runtime_map_control: 2, imperative_event_handler: 2 |
| `apps/web/src/components/NearbySheet.tsx` | 304 | 9 | semantic_control: 6, custom_component_call: 3 |
| `apps/web/src/components/TimelineList.tsx` | 173 | 2 | custom_component_call: 1, semantic_control: 1 |
| `apps/web/src/components/TodayBanner.tsx` | 171 | 2 | semantic_control: 2 |
| `apps/web/src/components/VoiceIntent.tsx` | 199 | 5 | semantic_control: 3, gesture_or_semantic_control: 1, input_control: 1 |
| `apps/web/src/components/lisbon/CommandPalette.tsx` | 410 | 5 | gesture_or_semantic_control: 2, input_control: 1, semantic_control: 1, imperative_event_handler: 1 |
| `apps/web/src/components/lisbon/WebLisbonMap.tsx` | 288 | 1 | gesture_or_semantic_control: 1 |
| `apps/web/src/components/marketing/CapabilityMocks.tsx` | 396 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/components/marketing/Container.tsx` | 25 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/components/marketing/DayPageMock.tsx` | 149 | 2 | semantic_control: 2 |
| `apps/web/src/components/marketing/HeroCanvas.tsx` | 352 | 0 | 无直接候选；检查调用组件 |
| `apps/web/src/components/marketing/primitives.tsx` | 155 | 2 | semantic_control: 2 |
| `apps/web/src/components/marketing/sections.tsx` | 532 | 10 | semantic_control: 10 |
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

### `apps/ios/SoloCompass/Views/Archive/CityCodexView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-104adb62b4 · CityCodexView · Button  | Unlock | 执行：onUpsell | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Archive/CityCodexView.swift:89` · P2 |

### `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-62c2d576ac · BlindboxLaunchView · Picker · 动态 | Duration | 编辑/选择绑定：$selected | binding: $selected) { | `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift:53` · P2 |
| IC-dc8768344d · BlindboxLaunchView · Button · 动态 | 开启 | 执行：{ onLaunch(selected | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift:64` · P2 |
| IC-6074362215 · BlindboxLaunchView · Button · 动态 | Not now | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Blindbox/BlindboxLaunchView.swift:75` · P2 |

### `apps/ios/SoloCompass/Views/Blindbox/BlindboxRecapCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-32697bc98d · BlindboxRecapCard · Button · 动态 | Share | 执行：onShare | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Blindbox/BlindboxRecapCard.swift:66` · P2 |

### `apps/ios/SoloCompass/Views/Brag/BragCardView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-57f343dcca · BragCardView · Button · 动态 | Share | 执行：onShare | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Brag/BragCardView.swift:55` · P2 |
| IC-7779fbf033 · BragCardView · Button · 动态 | Wallpaper | 执行：onWallpaper | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Brag/BragCardView.swift:60` · P2 |
| IC-2a3f757b5e · BragCardView · Button · 动态 | video | 执行：onVideoUnlock | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Brag/BragCardView.swift:66` · P2 |

### `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-b154743cfc · CapsuleComposeView · TextEditor  | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$text | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:45` · P2 |
| IC-a3dfd1e790 · CapsuleComposeView · Picker · 动态 | Surface in / \(m) months | 编辑/选择绑定：$months | binding: $months) { | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:52` · P2 |
| IC-a3115f7589 · CapsuleComposeView · Button · 动态 | 埋下 | 执行：bury | disabled(text.isEmpty) | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:61` · P2 |
| IC-72d0d01810 · CapsuleComposeView · Button · 动态 | Cancel | 执行：onCancel | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:77` · P2 |

### `apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4bc907c5e4 · CapsuleOpenView · Button · 动态 | Reply to yourself | 执行：onReply | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift:81` · P2 |
| IC-a48a0e2498 · CapsuleOpenView · Button · 动态 | Close | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift:89` · P2 |

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
| IC-22bc4e4ac8 · AttachmentInputBar · confirmationDialog · 动态 | 添加附件 / 相册 / 相机 / 文件 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("chat.attachment.add.title", comment: "Add attachment"), isPresented: $showAttachmentDialog, titleVisibility: .visible ) | binding: $showAttachmentDialog,; cancel | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:83` · P1 |
| IC-7cf0ff5de9 · AttachmentInputBar · Button  | 相册 | 执行：showPhotosPicker = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:88` · P1 |
| IC-8b8b3ebfbb · AttachmentInputBar · Button · 动态 | 相机 | 执行：showCamera = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:92` · P1 |
| IC-e42a613d32 · AttachmentInputBar · Button · 动态 | 文件 | 执行：showFileImporter = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:96` · P1 |
| IC-f76e95802e · AttachmentInputBar · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:99` · P1 |
| IC-484ab0d0e0 · AttachmentInputBar · photosPicker · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.photosPicker( isPresented: $showPhotosPicker, selection: $photoSelections, maxSelectionCount: 5, matching: .images ) .onChange(of: photoSelections) | binding: $showPhotosPicker,; binding: $photoSelections,; binding: $showCamera) {; binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:101` · P1 |
| IC-cd84e51db4 · AttachmentInputBar · fullScreenCover · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fullScreenCover(isPresented: $showCamera) | binding: $showCamera) {; binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:110` · P1 |
| IC-bc635926a3 · AttachmentInputBar · fileImporter · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fileImporter( isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true ) | binding: $showFileImporter, | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:116` · P1 |
| IC-3f40842c1f · AttachmentInputBar · Button · 动态 | 添加附件 | 执行：showAttachmentDialog = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:137` · P1 |
| IC-f9a9ed6f9e · AttachmentInputBar · TextField  | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$draftText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:158` · P1 |
| IC-d0676b1204 · AttachmentInputBar · onSubmit  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onSubmit(submitDraft) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:172` · P1 |
| IC-c44324d71e · AttachmentInputBar · Button  | 发送 | 执行：submitDraft | disabled(!canSend) | `apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:180` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatCardStack.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-c8fdb4bcbb · ProvisionalCardRow · gesture  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.gesture(swipeGesture) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardStack.swift:161` · P1 |
| IC-3eda18dc57 · ReasoningSummaryChip · Button · 动态 | checkmark | 执行：guard summary.hasDetail else { return } Haptics.impact(.light) withAnimation(.easeInOut(duration: 0.22)) { expanded.toggle() } | disabled(!summary.hasDetail) | `apps/ios/SoloCompass/Views/Chat/ChatCardStack.swift:369` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-e72b8501ad · ChatExperienceCard · Button  | 在地图上打开 %@ | 执行：onTap | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:51` · P1 |
| IC-06401b098a · ChatExperienceCard · Button  | 展开这个地点的更多信息 | 执行：withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) { expanded.toggle() } Haptics.impact(.light) | reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:93` · P1 |
| IC-8414cf56e4 · ChatRouteProposalCard · Button · 动态 | \(index + 1). \(stop.title) | 执行：onTapStop(stop) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:370` · P1 |
| IC-e15e1caac4 · ChatRouteProposalCard · Button  | 打开 / 双击保存并打开这条路线 | 执行：onAdopt | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:393` · P1 |
| IC-e2afd6153c · ChatRouteProposalCard · Button  | 已收藏 / 收藏 | 执行：withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { saved = true } Haptics.notify(.success) | disabled(saved) | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:408` · P1 |
| IC-54c3031d7b · ChatWebSourceCard · Button  | 来源 %1$d：%2$@，来自 %3$@ | 执行：{ | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatCardViews.swift:496` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-871946978b · ChatHistoryListView · Button · 动态 | 完成 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:42` · P1 |
| IC-a1c51ef6a6 · ChatHistoryListView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：let restored = store.messages(sessionId: session.id) onSelect(session.id, restored, session.scopedExperienceId) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:53` · P1 |
| IC-7f150e62ba · ChatHistoryListView · onDelete · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onDelete(perform: deleteRows) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatHistoryListView.swift:61` · P1 |

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
| IC-0b3d420f34 · ChatInputBar · onTapGesture · 动态 | 录音中 — 已 %@ | 执行：onMicToggle(false) | reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:319` · P1 |
| IC-db796175dc · ChatInputBar · Button · 动态 | 添加附件 | 执行：showAttachmentDialog = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:395` · P1 |
| IC-30e9e14dc4 · ChatInputBar · TextField · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$draftText；fieldFocused；micState | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:428` · P1 |
| IC-35c5a9e82d · ChatInputBar · onSubmit · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onSubmit(submitDraft) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:453` · P1 |
| IC-0eea744636 · ChatInputBar · Button · 动态 | 发送 | 执行：submitDraft | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:490` · P1 |
| IC-eacc84f92c · ChatInputBar · gesture · 动态 | 语音 / 点击开始/停止语音，长按推按说话 | 源码动作需沿调用方确认：.gesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:554` · P1 |
| IC-0ae71b79ee · ChatInputBar · accessibilityAction · 动态 | 语音 / 点击开始/停止语音，长按推按说话 | 执行：onMicToggle(micState != .listening) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:594` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-153de5c985 · ChatSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showHistory) | binding: $showHistory) { | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:257` · P1 |
| IC-a5ab82653e · ChatSheet · Button · 动态 | 打开聊天历史 | 执行：showHistory = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:426` · P1 |
| IC-608465ea7f · ChatSheet · Button · 动态 | 收起对话，回到地图 | 执行：{ | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:442` · P1 |
| IC-1ad4b9a360 · ChatSheet · Button · 动态 | 关闭 | 执行：closeSheet | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:458` · P1 |
| IC-28f2b82987 · ChatSheet · simultaneousGesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:666` · P1 |
| IC-ffedd0be97 · ChatSheet · Button · 动态 | 最新 / 有新回复，跳到最新消息 | 执行：#if canImport(UIKit) Haptics.selection() #endif workspace.beginFollowing() scrollToBottom(proxy: proxy) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:788` · P1 |
| IC-c0c384c6e0 · ChatSheet · VoiceMicButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onPress: { handleMicPress(true) },; onRelease: { handleMicPress(false) } | isListening | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:854` · P1 |
| IC-55f0a94d54 · ChatSheet · Button · 动态 | 点击改为文字输入 | 执行：switchToTextMode | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:862` · P1 |
| IC-b769860e67 · ChatSheet · Button · 动态 | 先选一个城市 | 执行：#if canImport(UIKit) Haptics.selection() #endif onChooseCity() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:957` · P1 |
| IC-f28660f91f · ChatSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) _ = handleSend(NSLocalizedString(intent.promptKey, comment: "Place opener")) | reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:1285` · P1 |
| IC-8dcbcd64f0 · ChatSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) _ = handleSend(prompt) | reduceMotion | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:1326` · P1 |
| IC-60d7ad2d9b · VoiceMicButton · onLongPressGesture · 动态 | 长按与 Solo Compass 说话 / 双击并长按以说话 | 源码动作需沿调用方确认：.onLongPressGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ChatSheet.swift:2226` · P1 |

### `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-31af700553 · ConversationPanel · onTapGesture · 动态 | 对话面板 / 上下拖动，调整对话与地图的比例 | 执行：toggleDetent() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift:131` · P1 |
| IC-2b90237c1e · ConversationPanel · gesture · 动态 | 对话面板 / 上下拖动，调整对话与地图的比例 | 源码动作需沿调用方确认：.gesture(grabberDrag) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift:132` · P1 |
| IC-0a6a6b18df · ConversationPanel · accessibilityAction · 动态 | 动态 label/无显式名称：需复核 | 执行：toggleDetent() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/ConversationPanel.swift:147` · P1 |

### `apps/ios/SoloCompass/Views/Chat/HalfExpandedEmptyState.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-f8b0424e52 · HalfExpandedEmptyState · Button · 动态 | arrow.up.right | 执行：Haptics.impact(.light) onSendPrompt(suggestion.fullPrompt) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/HalfExpandedEmptyState.swift:122` · P1 |
| IC-3e9a12772a · HalfExpandedEmptyState · onLongPressGesture  | 按住对 Solo 说话 | 源码动作需沿调用方确认：.onLongPressGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/HalfExpandedEmptyState.swift:196` · P1 |

### `apps/ios/SoloCompass/Views/Chat/InlineBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-a8eef1eff5 · InlineBanner · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：onCTA | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/InlineBanner.swift:95` · P1 |
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
| IC-fd88279a1f · SoloAgentBubbleView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：onTapCTA(bubble) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/SoloAgentBubbleQueue.swift:136` · P1 |
| IC-3b912334a5 · SoloAgentBubbleView · Button · 动态 | 关掉 | 执行：withAnimation(.easeOut(duration: 0.2)) { queue.dismiss(id: bubble.id) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Chat/SoloAgentBubbleQueue.swift:160` · P1 |

### `apps/ios/SoloCompass/Views/Chat/UndoPill.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-9048fb118a · UndoPill · Button · 动态 | 撤回 · %ds / 撤回这张卡片，%d 秒后确认 / 双击可在卡片落定前撤回 | 执行：{ | reduceMotion | `apps/ios/SoloCompass/Views/Chat/UndoPill.swift:29` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/BaseCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-59518b1371 · BaseCard · Button  | %@ · 基地 / 进入基地 | 执行：Haptics.impact(.light) onOpen() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/BaseCard.swift:34` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-a76f9f7f96 · BasePanelSheet · Button  | 完成 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift:85` · P1 |
| IC-0f9eeee821 · SectionCard · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：trailing.1() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift:452` · P1 |
| IC-c510034851 · PanelRow · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/BasePanelSheet.swift:496` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/ComplianceBanner.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-7b66bf75f7 · ComplianceBanner · Button  | 处理 | 执行：onHandle | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/ComplianceBanner.swift:25` · P1 |
| IC-f4b2d45220 · ComplianceBanner · Button  | 关闭 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/ComplianceBanner.swift:35` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/EventMarkerView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-da24287a17 · EventMarkerView · Button  | 动态 label/无显式名称：需复核 | 执行：onTap | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/EventMarkerView.swift:44` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-52e5785065 · KitSheet · Button · 动态 | 完成 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:72` · P1 |
| IC-00cc1b56a6 · KitRowCard · Button · 动态 | 已备，点按取消 / 标记已备 | 执行：Haptics.impact(.light) onToggleTick() | isSelected | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:187` · P1 |
| IC-c9ba07802a · KitRowCard · Button · 动态 | 打开 %@ | 执行：Haptics.impact(.light) onOpenLink(url, label) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:252` · P1 |
| IC-f969c74e49 · KitRowCard · Link · 动态 | 拨打 %1$@ %2$@ | 执行：HStack(spacing: 8) { Image(systemName: "phone.fill") .font(.system(size: 12, weight: .semibold)) Text(entry.label) .ctBody(13, .medium) Spacer(minLength: 0) Text(entry.number) . | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:280` · P1 |
| IC-5e858b271c · VisaComplianceControl · Toggle · 动态 | 到期提醒 | 编辑/选择绑定：$preferences.visaReminderEnabled | binding: $preferences.visaReminderEnabled) { | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:352` · P1 |
| IC-9b1bc24443 · VisaComplianceControl · DatePicker  | 入境日期 | 编辑/选择绑定：entryDateBinding | binding: entryDateBinding, | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:382` · P1 |
| IC-9e23326d74 · VisaComplianceControl · Stepper  | 签证 %d 天 | 编辑/选择绑定：visaLengthBinding | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/KitSheet.swift:388` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/LiveSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-fa24e5fd5d · LiveSheet · Button · 动态 | 完成 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/LiveSheet.swift:50` · P1 |
| IC-951ac4d23d · LiveEventCard · Button · 动态 | 在地图上看 / 在地图上查看 %@ | 执行：Haptics.impact(.light) onShowOnMap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/LiveSheet.swift:188` · P1 |

### `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-961df5f165 · VerifySheet · Button  | 关闭 | 执行：Haptics.selection() onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift:85` · P1 |
| IC-0d80185505 · VerifySheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | isSelected | `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift:120` · P1 |
| IC-1d15947e15 · VerifySheet · Button  | 提交印证 | 执行：Haptics.notify(.success) onSubmit(answers) onDismiss() | disabled(!answers.isComplete) | `apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift:141` · P1 |

### `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-3d195ea302 · AddToItinerarySheet · Button · 动态 | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:65` · P1 |
| IC-1a03dd1e8a · AddToItinerarySheet · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(isPresented: isCreating) | binding: isCreating) { | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:68` · P1 |
| IC-4695c830c2 · AddToItinerarySheet · alert · 动态 | 无法加入行程 / 好 | 呈现/导航声明：.alert( NSLocalizedString("itinerary.addTo.error.title", comment: "Error alert title when pinning fails"), isPresented: Binding( get: | binding: Binding(; errorMessage | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:86` · P1 |
| IC-13c8ed795b · AddToItinerarySheet · Button · 动态 | 好 | 执行：model.clearError() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:93` · P1 |
| IC-4859ac505a · AddToItinerarySheet · Button · 动态 | 已在该行程中 / 添加到《%@》 | 执行：guard !alreadyAdded else { return } addExisting(itin) | disabled(alreadyAdded) | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:119` · P1 |
| IC-33e4e0ca0f · AddToItinerarySheet · Button · 动态 | 新建行程 | 执行：model.beginCreation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:157` · P1 |
| IC-5287510411 · AddToItinerarySheet · Button  | 先创建一个行程 | 执行：model.beginCreation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/AddToItinerarySheet.swift:188` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-86a7dac867 · ApprovalQueueView · Button · 动态 | 邀请好友 / 邀请好友加入此路线 | 执行：Haptics.impact(.light) showInviteFriends = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:60` · P1 |
| IC-dafd6688df · ApprovalQueueView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showInviteFriends, onDismiss: reloadRoute) | binding: $showInviteFriends, onDismiss: reloadRoute) { | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:75` · P1 |
| IC-6e87af5443 · ApprovalQueueView · Button · 动态 | 拒绝 | 执行：decline(request) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:154` · P1 |
| IC-b121f3379c · ApprovalQueueView · Button · 动态 | 接受 | 执行：accept(request) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ApprovalQueueView.swift:163` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ChatView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-d80158de56 · ChatView · Menu · 动态 | 举报或屏蔽 | 执行：AddFriendButton( recipientId: otherId, source: .companionChat, style: .inline ) Button(role: .destructive) { showingReportSheet = true } label: { Label( NSLocalizedString("compa | destructive | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:63` · P1 |
| IC-6a619051c0 · ChatView · AddFriendButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：AddFriendButton( recipientId: otherId, source: .companionChat, style: .inline ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:67` · P1 |
| IC-aaef297533 · ChatView · Button · 动态 | 举报或屏蔽 | 执行：showingReportSheet = true | destructive | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:72` · P1 |
| IC-8cab2e1e59 · ChatView · sheet · 动态 | 聊天 / 消息发送失败 / 好的 | 呈现/导航声明：.sheet(isPresented: $showingReportSheet) | binding: $showingReportSheet) { | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:87` · P1 |
| IC-121e7e10e0 · ChatView · alert · 动态 | 消息发送失败 / 好的 | 呈现/导航声明：.alert( NSLocalizedString("companion.chat.error.title", comment: "Chat error title"), isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:109` · P1 |
| IC-4a895f937b · ChatView · Button · 动态 | 好的 | 执行：service.lastError = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:116` · P1 |
| IC-f7717a1b66 · ChatView · NavigationLink · 动态 | 已置顶路线 | 执行：RouteDetailView(route: route) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:128` · P1 |
| IC-64dff2d1d4 · ChatMessageRow · AddFriendButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：AddFriendButton( recipientId: message.senderId, source: .routeGroup, style: .compact ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ChatView.swift:254` · P1 |

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
| IC-a887932f7b · CompletionMoment · Button  | xmark.circle.fill | 执行：dismiss() onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CompletionMoment.swift:142` · P1 |

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
| IC-993340a686 · StopsList · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：onTapStop(experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/Components/StopsList.swift:36` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-93960bd560 · ConversationListView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：ChatView( conversation: summary.conversation, currentUserId: currentUserId ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift:64` · P1 |
| IC-14f48ef301 · ConversationListView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(item: $autoOpenConversation) | binding: $autoOpenConversation) { conversation in; isLoading | `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift:79` · P1 |
| IC-048d5c6921 · ConversationListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await reload() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ConversationListView.swift:99` · P1 |

### `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-81754684f9 · CreateRouteEntryCard · Button  | 创建你自己的路线 / 串联几个地点 · 可选择招募同伴一起走 | 执行：onTap | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:18` · P1 |
| IC-bbdffc7866 · CreateRouteView · Button · 动态 | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:132` · P1 |
| IC-a62ad3b6bb · CreateRouteView · Button · 动态 | 保存 | 执行：save() | disabled(!canSave) | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:135` · P1 |
| IC-b422ef3d30 · CreateRouteView · Button · 动态 | ✨ 让 AI 帮我串成路线 | 执行：Task { await generate() } | disabled(isGenerating \|\| candidates.count < 2) | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:149` · P1 |
| IC-0609333e3e · CreateRouteView · TextField · 动态 | 例如：湄公河日落散步 | 编辑/选择绑定：$title | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:214` · P1 |
| IC-686a1df875 · CreateRouteView · Picker · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$pace | binding: $pace) { | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:230` · P1 |
| IC-c0b646c0d7 · CreateRouteView · Button · 动态 | Solo %.1f | 执行：toggle(exp.id) | isSelected | `apps/ios/SoloCompass/Views/Companion/CreateRouteView.swift:276` · P1 |

### `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-1e39096a47 · DiscoverListView · Button · 动态 | 刷新发现列表 | 执行：Task { await loadPosts() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:44` · P1 |
| IC-6cbcd4da99 · DiscoverListView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $selectedPost) | binding: $selectedPost) { post in; binding: $showPostSheet) {; binding: $reportTarget) { post in | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:89` · P1 |
| IC-c22d946154 · DiscoverListView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showPostSheet) | binding: $showPostSheet) {; binding: $reportTarget) { post in; binding: $addFriendTarget) { post in | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:94` · P1 |
| IC-b74890186c · DiscoverListView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $reportTarget) | binding: $reportTarget) { post in; binding: $addFriendTarget) { post in | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:97` · P1 |
| IC-da8be727f1 · DiscoverListView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $addFriendTarget) | binding: $addFriendTarget) { post in | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:106` · P1 |
| IC-99707d05e3 · DiscoverListView · Button  | 重试 / 重新加载同伴列表 | 执行：Haptics.impact(.light) Task { await loadPosts() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:128` · P1 |
| IC-91ca724e1c · DiscoverListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await loadPosts() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:160` · P1 |
| IC-d280d321a0 · EmptyCompanionState · Button  | 抢先发布 — 分享你的行程 / 打开表单，发布你在这座城市的出行时间 | 执行：Haptics.impact(.light) onPostTapped() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:281` · P1 |
| IC-b07bbb30b9 · DiscoverPostRow · contextMenu · 动态 | 添加好友 / 举报或屏蔽 | 呈现/导航声明：.contextMenu | destructive | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:362` · P1 |
| IC-807c705850 · DiscoverPostRow · Button · 动态 | 添加好友 | 执行：onAddFriend() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:363` · P1 |
| IC-997b73ac91 · DiscoverPostRow · Button · 动态 | 举报或屏蔽 | 执行：onReport() | destructive | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:371` · P1 |
| IC-54b2e17d9f · DiscoverPostRow · Button · 动态 | 请求已发送 / 发送请求 | 执行：Haptics.selection() onSendRequest() | disabled(hasSentRequest) | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:400` · P1 |
| IC-2b5aaaf718 · DiscoverPostRow · Button  | 添加好友 | 执行：Haptics.selection() onAddFriend() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverListView.swift:426` · P1 |

### `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-aa92b3d440 · DiscoverPostDetailView · Button · 动态 | 完成 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift:57` · P1 |
| IC-cb13ab1c2a · DiscoverPostDetailView · TextField · 动态 | 打个招呼吧 —— 是什么让你想认识 TA？ | 编辑/选择绑定：$note | disabled(!canAdd) | `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift:102` · P1 |
| IC-48237cc4a7 · DiscoverPostDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：send | disabled(!canAdd) | `apps/ios/SoloCompass/Views/Companion/DiscoverPostDetailView.swift:131` · P1 |

### `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-a236c7e8c0 · DiscoverRecruitingRoutesView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingCreateRoute) | binding: $showingCreateRoute) { | `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift:48` · P1 |
| IC-c027a2c816 · DiscoverRecruitingRoutesView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：RouteDetailView(route: route) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift:71` · P1 |
| IC-81e468de0f · DiscoverRecruitingRoutesView · Button  | 开一个你自己的路线 | 执行：showingCreateRoute = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/DiscoverRecruitingRoutesView.swift:106` · P1 |

### `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-b6bcd44fff · InviteFriendsSheet · Button · 动态 | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:81` · P1 |
| IC-8cb3bd93fa · InviteFriendsSheet · Button · 动态 | 邀请 | 执行：Task { await invite() } | disabled(selected.isEmpty \|\| isSending) | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:86` · P1 |
| IC-16a0504e4c · InviteFriendsSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：toggle(friendId) | disabled(!isEnabled); isSelected | `apps/ios/SoloCompass/Views/Companion/InviteFriendsSheet.swift:127` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-16429a2ccd · ItineraryDetailView · onMove · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onMove(perform: moveExperience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:99` · P1 |
| IC-0e0ec6f520 · ItineraryDetailView · Button · 动态 | 从收藏导入 | 执行：showingImportConfirm = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:109` · P1 |
| IC-e9ff000a56 · ItineraryDetailView · confirmationDialog · 动态 | 导入收藏？ / 导入 / 取消 / 已收藏的体验将被添加到这个行程中。已存在的不会重复添加。 / 同伴档案已隐藏 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("itinerary.detail.importFavorites.confirm.title", comment: "Import favorites confirm title"), isPresented: $showingImportConfirm, tit | binding: $showingImportConfirm,; cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:125` · P1 |
| IC-edd08b681c · ItineraryDetailView · Button · 动态 | 导入 | 执行：importFavorites() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:130` · P1 |
| IC-227b38e8a2 · ItineraryDetailView · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:133` · P1 |
| IC-c54854c3ad · ItineraryDetailView · alert · 动态 | 同伴档案已隐藏 / 打开档案设置 / 取消 / 请先在同伴档案中开启可见性，再将此行程对同伴开放。 | 呈现/导航声明：.alert( NSLocalizedString("companion.post.visibilityOff.title", comment: "Visibility off alert title"), isPresented: $showingVisibilityOffAlert ) | binding: $showingVisibilityOffAlert; cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:140` · P1 |
| IC-036a3986b9 · ItineraryDetailView · Button  | 打开档案设置 | 执行： | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:144` · P1 |
| IC-0696634951 · ItineraryDetailView · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:148` · P1 |
| IC-46ffc918e1 · ItineraryDetailView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingCompanionPostSheet) | binding: $showingCompanionPostSheet) {; binding: $showingOpenForCompanionsSheet) { | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:152` · P1 |
| IC-d98dee5f9f · ItineraryDetailView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingOpenForCompanionsSheet) | binding: $showingOpenForCompanionsSheet) { | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:157` · P1 |
| IC-e2bb3aa606 · ItineraryDetailView · Toggle  | 欢迎同伴加入 | 编辑/选择绑定：openToCompanionsBinding | binding: openToCompanionsBinding | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:220` · P1 |
| IC-ef88315030 · ItineraryDetailView · Button · 动态 | 开为招募路线 -> | 执行：showingOpenForCompanionsSheet = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:242` · P1 |
| IC-d22e1442b9 · CompanionPostCreationSheet · TextField · 动态 | 描述你的风格或你在寻找什么… | 编辑/选择绑定：$blurb | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:429` · P1 |
| IC-bb099ec1dd · CompanionPostCreationSheet · Button · 动态 | checkmark | 执行：if selectedCategories.contains(cat) { selectedCategories.remove(cat) } else { selectedCategories.insert(cat) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:444` · P1 |
| IC-545eb2fb34 · CompanionPostCreationSheet · Button · 动态 | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:472` · P1 |
| IC-fd4a22c472 · CompanionPostCreationSheet · Button  | 保存 | 执行：confirm() | disabled(!isValid) | `apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:477` · P1 |

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
| IC-74208f87ba · ItineraryListView · NavigationLink · 动态 | 删除 | 执行：ItineraryRow(itinerary: itinerary) | destructive | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:39` · P1 |
| IC-d6168f0f72 · ItineraryListView · swipeActions · 动态 | 删除 | 呈现/导航声明：.swipeActions(edge: .trailing, allowsFullSwipe: true) | destructive | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:44` · P1 |
| IC-315846779b · ItineraryListView · Button · 动态 | 删除 | 执行：delete(itinerary) | destructive | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:45` · P1 |
| IC-65507f5fa0 · ItineraryListView · refreshable  | 动态 label/无显式名称：需复核 | 执行：await MainActor.run { loadItineraries() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:57` · P1 |
| IC-c6b85c7770 · ItineraryListView · Button · 动态 | 完成 | 执行：onClose | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:66` · P1 |
| IC-4c2e4178e4 · ItineraryListView · Button · 动态 | 新建行程 | 执行：showingCreateForm = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:70` · P1 |
| IC-483b66e285 · ItineraryListView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $showingCreateForm, onDismiss: loadItineraries) | binding: $showingCreateForm, onDismiss: loadItineraries) { | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:78` · P1 |
| IC-aa8d217241 · ItineraryListView · Button · 动态 | 已移除\"%@\" / 撤销 | 执行：performUndo() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:146` · P1 |
| IC-0321515ea7 · ItineraryListView · accessibilityAction · 动态 | 撤销 | 执行：performUndo() | reduceMotion | `apps/ios/SoloCompass/Views/Companion/ItineraryListView.swift:204` · P1 |

### `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-0f7a8cc85f · JoinRouteRequestSheet · Button  | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:114` · P1 |
| IC-7191b7d357 · JoinRouteRequestSheet · Picker · 动态 | 配速匹配 / 请选择 | 编辑/选择绑定：$selectedPace | binding: $selectedPace | `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:151` · P1 |
| IC-c123551dbe · JoinRouteRequestSheet · TextEditor · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$message | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:177` · P1 |
| IC-049ed539d0 · JoinRouteRequestSheet · Button · 动态 | 提交申请 | 执行：submit | disabled(!isSubmitEnabled) | `apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:216` · P1 |

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
| IC-ee57b97444 · OpenForCompanionsSheet · Button  | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:64` · P1 |
| IC-680084c5c5 · OpenForCompanionsSheet · Button  | 创建路线 | 执行：submit() | disabled(submitted) | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:69` · P1 |
| IC-8a3085ec72 · OpenForCompanionsSheet · DatePicker · 动态 | 从 | 编辑/选择绑定：$departureFrom | binding: $departureFrom, | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:96` · P1 |
| IC-66fd463ea6 · OpenForCompanionsSheet · DatePicker · 动态 | 到 | 编辑/选择绑定：$departureTo | binding: $departureTo, | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:104` · P1 |
| IC-a406ae6b08 · OpenForCompanionsSheet · DatePicker · 动态 | 时间 | 编辑/选择绑定：$departureTime | binding: $departureTime, | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:110` · P1 |
| IC-a1bbb04306 · OpenForCompanionsSheet · Picker · 动态 | 行程节奏 | 编辑/选择绑定：$pace | binding: $pace | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:122` · P1 |
| IC-72a84d2b8f · OpenForCompanionsSheet · Stepper · 动态 | %d 人 | 编辑/选择绑定：$maxMembers | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:138` · P1 |
| IC-ef57e7516d · OpenForCompanionsSheet · Picker · 动态 | 可见性 / 公开 / 仅限链接 | 编辑/选择绑定：$visibility | binding: $visibility | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:153` · P1 |
| IC-45cd46e4dd · OpenForCompanionsSheet · TextField · 动态 | 告诉想同行的旅人可以期待什么… | 编辑/选择绑定：$hostMessage | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/OpenForCompanionsSheet.swift:170` · P1 |

### `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-5bdf65633a · ReportBlockSheet · Button  | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:52` · P1 |
| IC-65753ef726 · ReportBlockSheet · alert · 动态 | 感谢你的反馈 / 好的 / 我们会尽快审核。该用户的内容已对你隐藏。 / 提交失败 | 呈现/导航声明：.alert( NSLocalizedString("companion.report.success.title", comment: "Report success title"), isPresented: $showSuccess ) | binding: $showSuccess; binding: Binding(get: { errorMessage != nil }, set: { if !$0; errorMessage | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:58` · P1 |
| IC-d53d5734ab · ReportBlockSheet · Button  | 好的 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:62` · P1 |
| IC-d91e6a359e · ReportBlockSheet · alert · 动态 | 提交失败 / 好的 / 确认屏蔽？ / 屏蔽 / 取消 | 呈现/导航声明：.alert( NSLocalizedString("companion.report.error.title", comment: "Report error title"), isPresented: Binding(get: | binding: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }); binding: $showBlockConfirm,; errorMessage; destructive; cancel | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:66` · P1 |
| IC-93a0beabbb · ReportBlockSheet · Button · 动态 | 好的 | 执行：errorMessage = nil | errorMessage | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:70` · P1 |
| IC-a2a32e8576 · ReportBlockSheet · confirmationDialog · 动态 | 确认屏蔽？ / 屏蔽 / 取消 / 屏蔽后你将不会再看到对方的任何内容，对方也无法联系你。 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("companion.block.confirm.title", comment: "Block confirm title"), isPresented: $showBlockConfirm, titleVisibility: .visible ) | binding: $showBlockConfirm,; destructive; cancel | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:74` · P1 |
| IC-ad907f0a8e · ReportBlockSheet · Button · 动态 | 屏蔽 | 执行：Task { await confirmBlock() } | destructive | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:79` · P1 |
| IC-83a761a6e0 · ReportBlockSheet · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:85` · P1 |
| IC-f7789c3ebc · ReportBlockSheet · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：selectedReason = reason | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:106` · P1 |
| IC-76e53c1ca2 · ReportBlockSheet · TextField · 动态 | 请提供更多信息，帮助我们处理... | 编辑/选择绑定：$details | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:113` · P1 |
| IC-89a7aa1647 · ReportBlockSheet · Button · 动态 | 提交中... / 提交举报 | 执行：Task { await submitReport() } | disabled(isSubmitting); isSubmitting | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:124` · P1 |
| IC-d10d1e9d20 · ReportBlockSheet · Button · 动态 | 屏蔽用户 | 执行：showBlockConfirm = true | destructive | `apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:146` · P1 |

### `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-fd5269d860 · RequestInboxView · Button · 动态 | 刷新收件箱 | 执行：Task { await service.fetchInbox() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:76` · P1 |
| IC-8db5152d9b · RequestInboxView · alert · 动态 | 已接受 / 好的 / 你们的对话已建立，可以开始聊聊行程啦。 | 呈现/导航声明：.alert( NSLocalizedString("companion.inbox.accepted.title", comment: "Request accepted alert title"), isPresented: $showingAcceptedConfirm ) | binding: $showingAcceptedConfirm; errorMessage; reduceMotion | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:85` · P1 |
| IC-d651aa0285 · RequestInboxView · Button · 动态 | 好的 | 执行： | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:89` · P1 |
| IC-6f8af7e19c · RequestInboxView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $reportTarget) | binding: $reportTarget) { request in | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:121` · P1 |
| IC-7b47b89a8d · RequestInboxView · Button  | 重试 / 重新加载收件箱 | 执行：Haptics.impact(.light) Task { await service.fetchInbox() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:142` · P1 |
| IC-412d74d40b · RequestInboxView · refreshable  | 动态 label/无显式名称：需复核 | 执行：await service.fetchInbox() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:172` · P1 |
| IC-5f50869b62 · RequestInboxView · Button · 动态 | 撤销 | 执行：performUndo() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:244` · P1 |
| IC-1a87ea4b05 · RequestInboxView · accessibilityAction  | 撤销 | 执行：performUndo() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:257` · P1 |
| IC-6db0ede2b4 · RequestRow · Button · 动态 | 拒绝 | 执行：onDecline() | destructive | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:345` · P1 |
| IC-376857d311 · RequestRow · Button · 动态 | 接受 | 执行：onAccept() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:353` · P1 |
| IC-6771769343 · RequestRow · contextMenu  | 举报或屏蔽 | 呈现/导航声明：.contextMenu | destructive | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:364` · P1 |
| IC-8652f5c32e · RequestRow · Button  | 举报或屏蔽 | 执行：onReport() | destructive | `apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:365` · P1 |

### `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-d7f9a529a1 · RouteDetailView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $activeSheet) | binding: $activeSheet) { sheet in; binding: $showCompletionMoment) {; binding: $showApprovalQueue) { | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:100` · P1 |
| IC-217612552c · RouteDetailView · fullScreenCover · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.fullScreenCover(isPresented: $showCompletionMoment) | binding: $showCompletionMoment) {; binding: $showApprovalQueue) { | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:108` · P1 |
| IC-ee875f92a9 · RouteDetailView · navigationDestination · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(isPresented: $showApprovalQueue) | binding: $showApprovalQueue) { | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:111` · P1 |
| IC-d9c0cab40c · RouteDetailView · Button · 动态 | 加入收藏 / 已收藏 / 未收藏 | 执行：let willFavorite = !isFavorited withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isFavorited.toggle() } if willFavorite { heartBurstTrigger += 1 Haptics.notify(.suc | isFavorited | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:521` · P1 |
| IC-707727f131 · RouteDetailView · Button  | 保存到我的行程 | 执行：isSaved.toggle() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:549` · P1 |
| IC-3cb2567802 · RouteDetailView · Button  | 动态 label/无显式名称：需复核 | 执行：cta.action | disabled(cta.isDisabled) | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:561` · P1 |
| IC-66947da839 · RouteDetailView · Button  | 分享路线 | 执行：activeSheet = .share | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteDetailView.swift:589` · P1 |

### `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-d1ada29dd8 · RouteShareSheet · Button · 动态 | 关闭 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:45` · P2 |
| IC-d233e4eb9c · RouteShareSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:49` · P2 |
| IC-b64ed12607 · RouteShareSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：selectedStyle = style statusMessage = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:63` · P2 |
| IC-203c359eb5 · RouteShareSheet · Button · 动态 | 分享… | 执行：Task { await shareCard() } | disabled(isRendering) | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:157` · P2 |
| IC-eed7274b35 · RouteShareSheet · Button · 动态 | 复制图片 | 执行：copyImage() | disabled(previewImage == nil) | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:169` · P2 |
| IC-3f519d3190 · RouteShareSheet · Button  | 已复制到剪贴板 / 复制 Markdown | 执行：UIPasteboard.general.string = payload.shareText flashStatus(NSLocalizedString("share.copied", comment: "Copied"), error: false) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:190` · P2 |
| IC-61ed80c99c · RouteShareSheet · Button  | 分享… | 执行：activityItems = [payload.shareText] | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:202` · P2 |

### `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4677fdee19 · SendRequestSheet · TextField · 动态 | 简单介绍一下自己，或说说你为什么想约一起... | 编辑/选择绑定：$note | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift:80` · P1 |
| IC-bcf71c6e92 · SendRequestSheet · Button · 动态 | 取消 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift:105` · P1 |
| IC-3b68332c4f · SendRequestSheet · Button  | 发送 | 执行：onSend(note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note) dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Companion/SendRequestSheet.swift:110` · P1 |

### `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-53042e3d0b · CreateExperienceSheet · Button  | 取消 | 执行：onCancel() dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:78` · P1 |
| IC-5d74782d86 · CreateExperienceSheet · Button  | 保存 | 执行：submit() | disabled(!canSave) | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:84` · P1 |
| IC-f7c87db21e · CreateExperienceSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingCamera) | binding: $isShowingCamera) { | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:90` · P1 |
| IC-a77874ec8f · CreateExperienceSheet · TextField · 动态 | 地点名称，例如 Wat Suan Dok | 编辑/选择绑定：$placeName | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:107` · P1 |
| IC-e2dd443d03 · CreateExperienceSheet · TextField · 动态 | 当地语言名称（可选） | 编辑/选择绑定：$placeNameLocal | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:111` · P1 |
| IC-c2b86f16e5 · CreateExperienceSheet · TextField · 动态 | 一句话：它为何值得（可选） | 编辑/选择绑定：$oneLiner | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:115` · P1 |
| IC-c2566c5f66 · CreateExperienceSheet · Picker · 动态 | 类别 | 编辑/选择绑定：$category | binding: $category | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:126` · P1 |
| IC-9261c87f7a · CreateExperienceSheet · TextField · 动态 | 一个人在这里是什么感受？ | 编辑/选择绑定：$description | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:139` · P1 |
| IC-97b3005729 · CreateExperienceSheet · Button · 动态 | xmark.circle.fill | 执行：images.remove(at: idx) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:162` · P1 |
| IC-82ba5ab1e5 · CreateExperienceSheet · PhotosPicker · 动态 | 从相册选择 | 编辑/选择绑定：$pickerItems | binding: $pickerItems, | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:175` · P1 |
| IC-8d8bc36004 · CreateExperienceSheet · Button  | 拍照 | 执行：isShowingCamera = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:185` · P1 |
| IC-2d62366d62 · CreateExperienceSheet · Button  | 改用语音描述 | 执行：onUseVoice() dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:200` · P1 |

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
| IC-52877610e2 · ExperienceDetailView · onLongPressGesture  | 动态 label/无显式名称：需复核 | 执行：isShowingCapsuleCompose = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:119` · P1 |
| IC-f41cfb00cd · ExperienceDetailView · Button  | 关闭 | 执行：onClose | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:205` · P1 |
| IC-d41f3035b0 · ExperienceDetailView · Menu · 动态 | 深度交叉编译 / 导出笔记 / 反馈问题 / 更多选项 | 执行：if let onRecompile, viewModel.experience.coordinate != nil { Button { Haptics.impact(.light) onRecompile() } label: { Label( NSLocalizedString("recompile.action", comment: "Deep | destructive | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:211` · P1 |
| IC-6d3aed8006 · ExperienceDetailView · Button · 动态 | 深度交叉编译 | 执行：Haptics.impact(.light) onRecompile() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:217` · P1 |
| IC-5e8c92f07a · ExperienceDetailView · Button · 动态 | 导出笔记 | 执行：exportMarkdown = MarkdownExporter.export(viewModel.experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:228` · P1 |
| IC-a39cf7fc40 · ExperienceDetailView · Button · 动态 | 反馈问题 | 执行：isShowingReport = true | destructive | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:236` · P1 |
| IC-4679ee9f97 · ExperienceDetailView · sheet · 动态 | 关闭 / 好 | 呈现/导航声明：.sheet(isPresented: $isShowingReport) | binding: $isShowingReport) {; binding: Binding( | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:258` · P1 |
| IC-a508895d57 · ExperienceDetailView · ReportIssueSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onSubmit: { _, _ in isShowingReport = false },; onCancel: { isShowingReport = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:259` · P1 |
| IC-d843460594 · ExperienceDetailView · sheet · 动态 | 关闭 / 好 | 呈现/导航声明：.sheet(item: Binding( get: | binding: Binding(; binding: $isShowingAddToItinerary) { | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:265` · P1 |
| IC-b7bca4edd2 · ExperienceDetailView · sheet · 动态 | 关闭 / 好 | 呈现/导航声明：.sheet(isPresented: $isShowingAddToItinerary) | binding: $isShowingAddToItinerary) {; binding: $itineraryToNavigate) { itin in | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:275` · P1 |
| IC-91966026f5 · ExperienceDetailView · AddToItinerarySheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onSuccess: { itinerary in | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:276` · P1 |
| IC-2dd2ef1649 · ExperienceDetailView · sheet · 动态 | 关闭 / 好 | 呈现/导航声明：.sheet(item: $itineraryToNavigate) | binding: $itineraryToNavigate) { itin in | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:285` · P1 |
| IC-8f120dc0e1 · ExperienceDetailView · Button · 动态 | 关闭 | 执行：itineraryToNavigate = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:290` · P1 |
| IC-ac13c78c55 · ExperienceDetailView · sheet · 动态 | 好 | 呈现/导航声明：.sheet(isPresented: $isShowingPaywall) | binding: $isShowingPaywall) {; binding: $isShowingCapsuleCompose) { | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:301` · P1 |
| IC-dd677578f5 · ExperienceDetailView · sheet · 动态 | 好 | 呈现/导航声明：.sheet(isPresented: $isShowingCapsuleCompose) | binding: $isShowingCapsuleCompose) { | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:311` · P1 |
| IC-2052c5ffec · ExperienceDetailView · alert · 动态 | 好 | 呈现/导航声明：.alert( capsuleBuryToast ?? "", isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:335` · P1 |
| IC-5fbc038437 · ExperienceDetailView · Button · 动态 | 好 | 执行：capsuleBuryToast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:342` · P1 |
| IC-93091d4c54 · ExperienceDetailView · Button · 动态 | 导航 / 导航 | 执行：Haptics.impact(.light) if let only = NavigationLauncher.soleApp() { NavigationLauncher.open(app: only, coordinate: coord, name: name) } else { isShowingNavPicker = true } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:928` · P1 |
| IC-417bf659b2 · ExperienceDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.selection() if let proxy = scrollProxy { withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo("bestTimesTimeline", anchor: .center) } } | reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1046` · P1 |
| IC-a148169b8a · ExperienceDetailView · Button · 动态 | 收起 / 全部 %d 项 / 展开或收起六维评分详情 | 执行：Haptics.selection() withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { showingRadarTooltip.toggle() } | reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1263` · P1 |
| IC-c1cda964ab · ExperienceDetailView · Link · 动态 | 打开原始来源 | 执行：sourceRowContent(label: label, iconName: iconName, date: source.verifiedAt, isLink: true) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1470` · P1 |
| IC-b2ffa790ed · ExperienceDetailView · simultaneousGesture · 动态 | 打开原始来源 | 源码动作需沿调用方确认：.simultaneousGesture(TapGesture().onEnded { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1473` · P1 |
| IC-e1103a3dfa · NearbyCard · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) onSelect(exp) | reduceMotion | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1574` · P1 |
| IC-8e25dc2c9a · ExperienceDetailView · Button · 动态 | 查看行程 | 执行：toastDismissTask?.cancel() withAnimation { addedItineraryToast = nil } itineraryToNavigate = itin | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1623` · P1 |
| IC-d998d51535 · ExperienceDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | isSelected | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1649` · P1 |
| IC-46c304d147 · ExperienceDetailView · dockIconButton · 动态 | 取消收藏 / 添加到收藏 / 已收藏 / 收藏 | 复用组件调用：dockIconButton( systemName: viewModel.isFavorited ? "heart.fill" : "heart", isOn: viewModel.isFavorited, accessibilityLabel: viewModel.isFavorited ? NSLocalizedString("actio | binding: viewModel.isFavorited,; isFavorited | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1670` · P1 |
| IC-8e5c2b134a · ExperienceDetailView · dockIconButton · 动态 | 向 Solo 提问 / 问问 | 复用组件调用：dockIconButton( systemName: "bubble.left.and.text.bubble.right", accessibilityLabel: NSLocalizedString("experience.askSolo.cta", comment: "Ask Solo"), visibleLabel: NSLocali | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1694` · P1 |
| IC-3339e62f0e · ExperienceDetailView · dockIconButton · 动态 | 去过 / 已完成 / 标记完成 | 复用组件调用：dockIconButton( systemName: viewModel.isCompleted ? "checkmark.circle.fill" : "checkmark.circle", isOn: viewModel.isCompleted, accessibilityLabel: NSLocalizedString(viewMode | binding: viewModel.isCompleted,; isCompleted | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1708` · P1 |
| IC-efdde3a0eb · ExperienceDetailView · Button · 动态 | 加入行程 | 执行：Haptics.impact(.light) isShowingAddToItinerary = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1726` · P1 |
| IC-a991938388 · ExperienceDetailView · confirmationDialog · 动态 | 导航 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("location.navigate", comment: ""), isPresented: $isShowingNavPicker, titleVisibility: .visible ) | binding: $isShowingNavPicker,; cancel | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1760` · P1 |
| IC-2d81e9ae6d · ExperienceDetailView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：NavigationLauncher.open(app: app, coordinate: coord, name: name) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1770` · P1 |
| IC-c683b01ed3 · ExperienceDetailView · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:1775` · P1 |

### `apps/ios/SoloCompass/Views/Experience/LocationCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-6105ff9156 · LocationCard · Button · 动态 | 地址已复制到剪贴板 / 复制地址到剪贴板 | 执行：performCopy() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:90` · P1 |
| IC-3fc03a3754 · LocationCard · Button · 动态 | 导航 / 选择地图应用以获取步行路线 / 在地图中打开步行路线 | 执行：navigateTapped() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:137` · P1 |
| IC-bbf5108a1f · LocationCard · Button · 动态 | 地址已复制 / 已复制！ / 地址已复制到剪贴板 / 坐标已复制 / 复制坐标 | 执行：performCopy() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:163` · P1 |
| IC-7109c7cc51 · LocationCard · confirmationDialog · 动态 | 导航 / 取消 | 呈现/导航声明：.confirmationDialog( NSLocalizedString("location.navigate", comment: ""), isPresented: $isShowingPicker, titleVisibility: .visible ) | binding: $isShowingPicker,; cancel | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:191` · P1 |
| IC-8d57a42088 · LocationCard · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：NavigationLauncher.open(app: app, coordinate: coordinate, name: displayName) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:197` · P1 |
| IC-55a3abbb4f · LocationCard · Button · 动态 | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Experience/LocationCard.swift:201` · P1 |

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
| IC-c0c6befddd · ReportIssueSheet · Button · 动态 | 取消 | 执行：onCancel | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:63` · P1 |
| IC-07902982b2 · ReportIssueSheet · Button · 动态 | 提交 | 执行：guard let reason = selectedReason else { return } UINotificationFeedbackGenerator().notificationOccurred(.success) onSubmit(reason, detail.trimmingCharacters(in: .whitespacesAnd | disabled(selectedReason == nil) | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:66` · P1 |
| IC-cbcc6b45b1 · ReportIssueSheet · onTapGesture · 动态 | 选择此原因并显示可选的详情字段。 | 执行：selectedReason = reason UIImpactFeedbackGenerator(style: .light).impactOccurred() | isSelected | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:112` · P1 |
| IC-77f6748fc1 · ReportIssueSheet · TextEditor · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$detail | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/ReportIssueSheet.swift:138` · P1 |

### `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-484c111ee1 · ShareSheet · Button · 动态 | 关闭 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:79` · P2 |
| IC-e06ea91ccc · ShareSheet · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:83` · P2 |
| IC-e6edd36bdd · ShareSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：if mode != selectedMode { previewImage = nil } selectedMode = mode statusMessage = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:98` · P2 |
| IC-81075254f9 · ShareSheet · Button · 动态 | 分享… | 执行：shareCard(style: style) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:183` · P2 |
| IC-6197814d51 · ShareSheet · Button · 动态 | 复制图片 | 执行：copyImage(style: style) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:194` · P2 |
| IC-0c94e72dde · ShareSheet · Button  | 已复制到剪贴板 / 复制 Markdown | 执行：UIPasteboard.general.string = markdown flashStatus(NSLocalizedString("share.copied", comment: "Copied"), error: false) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:214` · P2 |
| IC-d8577cc057 · ShareSheet · Link · 动态 | 在 Notion 中打开 | 执行：Label( NSLocalizedString("export.notion", comment: "Open in Notion"), systemImage: "arrow.up.right.square" ) .frame(maxWidth: .infinity) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:227` · P2 |
| IC-0746823993 · ShareSheet · Button · 动态 | 分享… | 执行：activityItems = [markdown] | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:237` · P2 |

### `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-da72add178 · TravelerNotesSection · Button  | 已确认 ·「%@」已更新 / 确认 | 执行：Haptics.impact(.light) travelerNoteStore?.acceptCorrection(id: c.id) registerContribution(String( format: NSLocalizedString("correction.confirmed.toast", comment: "Confirmed toa | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:97` · P1 |
| IC-a238f148b8 · TravelerNotesSection · Button  | 不准确 | 执行：Haptics.impact(.light) travelerNoteStore?.dismissCorrection(id: c.id) reloadCoBuild() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:115` · P1 |
| IC-99edc892db · TravelerNotesSection · Button · 动态 | 收起 / 展开全部 %d 条 → | 执行：withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { notesExpanded.toggle() } | reduceMotion | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:160` · P1 |
| IC-cc082b40a0 · TravelerNotesSection · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.selection() notesFilter = filter | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:199` · P1 |
| IC-be1963cda5 · TravelerNotesSection · Button · 动态 | 谢谢 · 你的笔记将供 AI 交叉验证 / 已确认 / 我也确认 | 执行：guard !confirmed else { return } Haptics.impact(.light) confirmedNoteIds.insert(note.id) travelerNoteStore?.confirmNote(id: note.id) registerContribution(NSLocalizedString("note | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:273` · P1 |
| IC-cc8e454cbc · TravelerNotesSection · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.selection() if picked { pickedMoods.remove(mood) } else { pickedMoods.insert(mood) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:351` · P1 |
| IC-b340f179f8 · TravelerNotesSection · TextField · 动态 | 比如：周二下午很安静… / 加一句话（可选）… | 编辑/选择绑定：$noteDraft | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:366` · P1 |
| IC-9989f3aaa4 · TravelerNotesSection · onSubmit  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onSubmit(submitNote) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:375` · P1 |
| IC-2b7926fd2b · TravelerNotesSection · Button  | 发送笔记 | 执行：submitNote() | disabled(!canSubmitNote) | `apps/ios/SoloCompass/Views/Experience/TravelerNotesSection.swift:376` · P1 |

### `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-be588f0d52 · FilterBarView · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：isMapPanning = false | reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:313` · P1 |
| IC-c505d5c4d9 · FilterBarView · Button · 动态 | 双击清除此筛选 | 执行：handleTap(isSelected: isSelected, select: action) | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:391` · P1 |
| IC-f607d15538 · FilterBarView · Button · 动态 | \(resultCount) results | 执行：handleTap(isSelected: isSelected, select: action) | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:473` · P1 |
| IC-e81acf823c · FilterBarView · Button · 动态 | \(resultCount) results | 执行：if !isSelected && resultCount > 0 { if !didCelebrateSaved { #if canImport(UIKit) Haptics.notify(.success) #endif didCelebrateSaved = true if !reduceMotion { withAnimation(.sprin | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:521` · P1 |
| IC-66f2799452 · FilterBarView · Button · 动态 | 让 Solo 给一个附近的建议 | 执行：#if canImport(UIKit) Haptics.impact(.light) #endif action() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:607` · P1 |
| IC-ece89f4eb7 · FilterBarView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：#if canImport(UIKit) Haptics.selection() #endif action() | isSelected | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:637` · P1 |
| IC-96b743229a · FilterBarView · Button · 动态 | 双击清除此筛选 | 执行：handleTap(isSelected: isSelected, select: action) | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:669` · P1 |
| IC-d720f98f76 · FilterBarView · Button · 动态 | 双击清除此筛选 | 执行：handleTap(isSelected: isSelected, select: action) | isSelected | `apps/ios/SoloCompass/Views/Filter/FilterBarView.swift:727` · P1 |

### `apps/ios/SoloCompass/Views/Friends/AddFriendButton.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-10735bc384 · AddFriendButton · Button  | 动态 label/无显式名称：需复核 | 执行：send | disabled(!isActionable) | `apps/ios/SoloCompass/Views/Friends/AddFriendButton.swift:60` · P1 |

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
| IC-a07cfb8379 · FriendProfileView · dockButton · 动态 | 邀请见面 | 复用组件调用：action: onInvite | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendProfileView.swift:224` · P1 |
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
| IC-1151f22f29 · FriendsListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await service.refresh() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:52` · P1 |
| IC-afdbff25fe · FriendsListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await service.refresh() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:58` · P1 |
| IC-cb69467995 · FriendsListView · Button  | 显示我的好友码 | 执行：Haptics.impact(.light) showAddFriend = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:84` · P1 |
| IC-21c65dad0e · FriendsListView · Button  | 刷新好友和请求 | 执行：Task { await service.refresh() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:93` · P1 |
| IC-5b1c38283c · FriendsListView · sheet · 动态 | exclamationmark.triangle | 呈现/导航声明：.sheet(isPresented: $showAddFriend) | binding: $showAddFriend) {; errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:111` · P1 |
| IC-8a2cc13d26 · FriendsListView · Button  | 重试 | 执行：Haptics.impact(.light) Task { await service.refresh() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:145` · P1 |
| IC-e69eccef50 · FriendsListView · NavigationLink · 动态 | 移除 | 执行：FriendProfileContainer( friendship: friendship, profile: profileData(for: otherId), service: service ) | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:189` · P1 |
| IC-64a0c8a830 · FriendsListView · swipeActions · 动态 | 移除 | 呈现/导航声明：.swipeActions(edge: .trailing, allowsFullSwipe: false) | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:198` · P1 |
| IC-e515c01aa3 · FriendsListView · Button · 动态 | 移除 | 执行：Haptics.impact(.light) friendToRemove = friendship | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:199` · P1 |
| IC-5a440eb9fa · FriendsListView · confirmationDialog · 动态 | 移除 %@？ / 移除好友 / %@ 已从好友中移除 / 取消 | 呈现/导航声明：.confirmationDialog( String(format: NSLocalizedString("friends.list.remove.confirm.title", comment: "Remove friend confirmation title — %@ is the friend's id"), friendToRem | binding: Binding(get: { friendToRemove != nil }, set: { if !$0 { friendToRemove = nil } }),; destructive; cancel | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:210` · P1 |
| IC-c5e6a04c19 · FriendsListView · Button · 动态 | 移除好友 / %@ 已从好友中移除 | 执行：guard let friendship = friendToRemove else { return } friendToRemove = nil Task { await service.unfriend(friendship, block: false) Haptics.notify(.success) #if canImport(UIKit)  | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:215` · P1 |
| IC-f0fa73957a · FriendsListView · Button · 动态 | 取消 | 执行：friendToRemove = nil | cancel | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:229` · P1 |
| IC-759f224a86 · FriendsListView · refreshable · 动态 | 动态 label/无显式名称：需复核 | 执行：await service.refresh() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:239` · P1 |
| IC-6420be3e0c · FriendsListView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：FriendProfileContainer( friendship: friendship, profile: profileData(for: otherId), service: service ) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:249` · P1 |
| IC-fc567c3536 · FriendsListView · simultaneousGesture  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture(TapGesture().onEnded { Haptics.selection() }) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:269` · P1 |
| IC-36042b289f · FriendProfileContainer · sheet · 动态 | 无法加载好友 / 好的 | 呈现/导航声明：.sheet(isPresented: $showInvite) | binding: $showInvite) {; errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:360` · P1 |
| IC-8eeec131f4 · FriendProfileContainer · SendRequestSheet  | 动态 label/无显式名称：需复核 | 复用组件调用：onSend: { note in Task { await sendInvite(note: note) } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:361` · P1 |
| IC-8ff6140f0b · FriendProfileContainer · navigationDestination · 动态 | 无法加载好友 / 好的 | 呈现/导航声明：.navigationDestination(item: $conversation) | binding: $conversation) { conv in; binding: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }; errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:377` · P1 |
| IC-e50f50cc82 · FriendProfileContainer · alert · 动态 | 无法加载好友 / 好的 | 呈现/导航声明：.alert( NSLocalizedString("friends.list.error.title", comment: "Friends error title"), isPresented: Binding(get: | binding: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }); errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:387` · P1 |
| IC-a38bba1799 · FriendProfileContainer · Button · 动态 | 好的 | 执行：errorMessage = nil | errorMessage | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:391` · P1 |
| IC-fe8a406d84 · IncomingRequestRow · Button · 动态 | 拒绝 | 执行：onDecline() | destructive | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:535` · P1 |
| IC-e907318c6d · IncomingRequestRow · Button · 动态 | 接受 | 执行：onAccept() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Friends/FriendsListView.swift:543` · P1 |

### `apps/ios/SoloCompass/Views/Insight/InsightCardView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-60defe3585 · InsightCardView · Button  | square.and.arrow.up | 执行：onShare | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Insight/InsightCardView.swift:23` · P2 |

### `apps/ios/SoloCompass/Views/Map/ActiveRouteOverlay.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-083452313e · ActiveRouteBanner · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ActiveRouteOverlay.swift:97` · P1 |

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
| IC-dc8db4d438 · CompassMapContentView · sheet  | 在此处添加一个地点？ / 取消 / 添加 | 呈现/导航声明：.sheet(item: $surveyExperience) | binding: $surveyExperience) { exp in surveySheetContent(exp: exp) }; binding: addExperienceAlertBinding; cancel | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1360` · P1 |
| IC-8bf3f9d0e0 · CompassMapContentView · alert · 动态 | 在此处添加一个地点？ / 取消 / 添加 / 填写几项信息，或用语音描述它。 | 呈现/导航声明：.alert( NSLocalizedString("addExperience.confirm.title", comment: "Add an experience here?"), isPresented: addExperienceAlertBinding ) | binding: addExperienceAlertBinding; cancel | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1361` · P1 |
| IC-b05d3a2450 · CompassMapContentView · Button  | 取消 | 执行：viewModel.cancelAddExperience() | cancel | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1365` · P1 |
| IC-226b0b08d2 · CompassMapContentView · Button  | 添加 | 执行：viewModel.confirmAddExperienceWithForm() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1368` · P1 |
| IC-1a9dc208c2 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: createFormSheetBinding) | binding: createFormSheetBinding) { createFormSheetContent }; binding: recordExperienceSheetBinding) { recordExperienceSheetContent }; binding: detailSheetBinding) { detailSheetContent }; binding: $isS | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1374` · P1 |
| IC-022a82bf72 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: recordExperienceSheetBinding) | binding: recordExperienceSheetBinding) { recordExperienceSheetContent }; binding: detailSheetBinding) { detailSheetContent }; binding: $isShowingCityPicker) { cityPickerSheetContent }; binding: $isSho | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1375` · P1 |
| IC-5de1cc4ee6 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: detailSheetBinding) | binding: detailSheetBinding) { detailSheetContent }; binding: $isShowingCityPicker) { cityPickerSheetContent }; binding: $isShowingKitSheet, onDismiss: { kitSheetFocus = nil }) { kitSheetContent }; bi | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1376` · P1 |
| IC-e9ead6841b · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingCityPicker) | binding: $isShowingCityPicker) { cityPickerSheetContent }; binding: $isShowingKitSheet, onDismiss: { kitSheetFocus = nil }) { kitSheetContent }; binding: $isShowingLiveSheet) { liveSheetContent }; bin | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1377` · P1 |
| IC-9a2c8afcba · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingKitSheet, onDismiss: | binding: $isShowingKitSheet, onDismiss: { kitSheetFocus = nil }) { kitSheetContent }; binding: $isShowingLiveSheet) { liveSheetContent }; binding: $isShowingBaseSheet, onDismiss: handleBaseFollowUp) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1382` · P1 |
| IC-c302bef274 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingLiveSheet) | binding: $isShowingLiveSheet) { liveSheetContent }; binding: $isShowingBaseSheet, onDismiss: handleBaseFollowUp) { baseSheetContent }; binding: $verifyTarget) { experience in; binding: $isShowingFavor | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1383` · P1 |
| IC-9b76e54a2a · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingBaseSheet, onDismiss: handleBaseFollowUp) | binding: $isShowingBaseSheet, onDismiss: handleBaseFollowUp) { baseSheetContent }; binding: $verifyTarget) { experience in; binding: $isShowingFavorites, onDismiss: { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1384` · P1 |
| IC-e5b514b60e · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $verifyTarget) | binding: $verifyTarget) { experience in; binding: $isShowingFavorites, onDismiss: { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1385` · P1 |
| IC-1039a6596a · CompassMapContentView · VerifySheet  | 动态 label/无显式名称：需复核 | 复用组件调用：onSubmit: { answers in submitVerification(answers, for: experience) },; onDismiss: { verifyTarget = nil } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1386` · P1 |
| IC-e0838f4a26 · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingFavorites, onDismiss: | binding: $isShowingFavorites, onDismiss: {; binding: $isShowingItineraries) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1392` · P1 |
| IC-339dbc99bd · CompassMapContentView · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingItineraries) | binding: $isShowingItineraries) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1402` · P1 |
| IC-841187baa9 · CompassMapContentView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: paywallSheetBinding, onDismiss: | binding: paywallSheetBinding, onDismiss: { viewModel.onPaywallUnlocked = nil }) { paywallSheetContent }; binding: settingsSheetBinding) { settingsSheetContent } | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1420` · P1 |
| IC-23698fe858 · CompassMapContentView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: settingsSheetBinding) | binding: settingsSheetBinding) { settingsSheetContent }; binding: recompileFeedSheetBinding) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1424` · P1 |
| IC-6da83b705e · CompassMapContentView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: recompileFeedSheetBinding) | binding: recompileFeedSheetBinding) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1428` · P1 |
| IC-2fe47fac10 · CompassMapContentView · RecompileFeedSheet  | 动态 label/无显式名称：需复核 | 复用组件调用：onClose: { viewModel.isShowingRecompileFeed = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1429` · P1 |
| IC-42a6ffb775 · CompassMapContentView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(item: $routeSheet) | binding: $routeSheet) { sheet in routeSheetContent(sheet) }; binding: $isShowingMe) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1439` · P1 |
| IC-554f955c97 · CompassMapContentView · sheet  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: $isShowingMe) | binding: $isShowingMe) { | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:1441` · P1 |
| IC-cdaaa3f9c5 · CompassMapContentView · MicroSurveySheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onSubmit: { comfort, pressure, recommend in; onSkip: { surveyExperience = nil } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2037` · P1 |
| IC-9a244d86ac · CompassMapContentView · CreateExperienceSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onSave: { input in viewModel.createUserExperience(from: input) },; onUseVoice: { viewModel.confirmAddExperience() },; onCancel: { viewModel.cancelAddExperience() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2058` · P1 |
| IC-75d782107a · CompassMapContentView · VoiceButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：VoiceButton(voiceService: voiceService) { transcript in Task { await viewModel.handleNewExperienceTranscript(transcript) } } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2076` · P1 |
| IC-272930026a · CompassMapContentView · KitSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onToggleTodo: { kind in; onDismiss: { isShowingKitSheet = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2175` · P1 |
| IC-b620f79418 · CompassMapContentView · LiveSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onShowOnMap: { event in; onDismiss: { isShowingLiveSheet = false } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2195` · P1 |
| IC-4b70b75c41 · CompassMapContentView · BasePanelSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onOpenKit: { kind in; onOpenLive: {; onSelectExperience: { spot in; onVerifyNext: {; onDismiss: { isShowingBaseSheet = false },; onAskSolo: { prompt in | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2209` · P1 |
| IC-a6d2a92810 · CompassMapContentView · ChatSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onDismiss: {; onSelectExperience: { exp in; onAdoptRoute: { proposal in; onShowEventOnMap: { event in; onCollapse: {; onChooseCity: { isShowingCityPicker = true } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:2919` · P1 |
| IC-af8f9895e2 · CompassMapContentView · Map · 动态 | 显示快速预览 / 候选体验：%@ / 此地图模式的位置尚未核实，可切换标准地图或查看地点列表。 / 切换标准地图 | 执行：float the quick preview card" | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3004` · P1 |
| IC-dd4b06f1a5 · CompassMapContentView · Button · 动态 | 显示快速预览 | 执行：float the quick preview card" | isSelected; reduceMotion | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3045` · P1 |
| IC-12121c53a7 · CompassMapContentView · accessibilityAction  | 显示快速预览 | 执行：float the quick preview card" | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3093` · P1 |
| IC-a82e626378 · CompassMapContentView · MapCompass · 动态 | 动态 label/无显式名称：需复核 | MapKit内建地图控制：方向恢复/视角/定位；系统可见性和accessible name需运行时核实 | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3266` · P1 |
| IC-2179090be4 · CompassMapContentView · simultaneousGesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3310` · P1 |
| IC-e039345e4f · CompassMapContentView · simultaneousGesture · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3328` · P1 |
| IC-09ba9bd128 · MapOverlayView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3516` · P1 |
| IC-be621e4840 · MapOverlayView · libraryShortcut · 动态 | 我的收藏 | 复用组件调用：action: onOpenFavorites) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3602` · P1 |
| IC-c197e124eb · MapOverlayView · libraryShortcut · 动态 | 我的行程 | 复用组件调用：action: onOpenItineraries) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3603` · P1 |
| IC-b52ca1c174 · MapOverlayView · accessibilityAction  | 显示快速预览 | 执行：float the quick preview card" | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3865` · P1 |
| IC-2060c81480 · MapOverlayView · accessibilityAction  | 显示快速预览 | 执行：float the quick preview card" | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3870` · P1 |
| IC-222f24f596 · MapOverlayView · onTapGesture  | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) viewModel.openExperienceDetail(tickedNext.experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3873` · P1 |
| IC-fbef86c1ff · MapOverlayView · onLongPressGesture  | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.medium) viewModel.selectExperience(tickedNext.experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3877` · P1 |
| IC-e4ce33479f · MapOverlayView · Button  | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) viewModel.clearFilters() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3903` · P1 |
| IC-43c04d3574 · MapOverlayView · accessibilityAction · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) viewModel.clearFilters() | reduceMotion | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3921` · P1 |
| IC-eb9690e35c · MapOverlayView · Button · 动态 | 选择城市 | 执行：isShowingCityPicker = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:3999` · P1 |
| IC-c6f996235c · MapOverlayView · Button  | 动态 label/无显式名称：需复核 | 执行：Haptics.impact(.light) withAnimation(.easeInOut(duration: 0.2)) { mapStyleChoice.cycle() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4049` · P1 |
| IC-8dcdcddbcb · MapOverlayView · RecenterButton  | 动态 label/无显式名称：需复核 | 复用组件调用：onTap: { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4069` · P1 |
| IC-e0ef89274f · RecenterButton · Button · 动态 | 回到我的位置 | 执行：Haptics.impact(.light) onTap() guard !reduceMotion else { return } pulse = false iconPop = false withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { iconPop = true }  | disabled(!located); reduceMotion | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4103` · P1 |
| IC-4923c76767 · EmptyFilterBanner · Button · 动态 | 显示全部 / 显示全部体验 | 执行：Haptics.selection() onShowAll() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4178` · P1 |
| IC-7142031a23 · DismissibleBanner · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：onAction | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4234` · P1 |
| IC-e9ebcddc5d · DismissibleBanner · Button · 动态 | 关闭 | 执行：onDismiss | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4243` · P1 |
| IC-1cc63b9997 · MapControlBar · Button  | 偏好 | 执行：viewModel.isShowingSettings = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4286` · P1 |
| IC-888a5db03e · MapControlBar · Button · 动态 | 探索（Pro) | 执行：let anchor = viewModel.exploreAnchorCoordinate Task { await viewModel.exploreNearby(at: anchor) } | disabled(viewModel.isExploring \|\| viewModel.isExploringFreeMode) | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4300` · P1 |
| IC-93b9390ef4 · MapControlBar · PlusActionButton · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onShortTap: {; onLongPress: { onOpenChat(.voice) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4330` · P1 |
| IC-7c43c798c8 · PlusActionButton · Button · 动态 | 和 Solo 聊天 / 点击文字输入，长按语音说话 | 执行：if longPressFired { longPressFired = false } else { onShortTap() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4389` · P1 |
| IC-1d76086060 · PlusActionButton · simultaneousGesture · 动态 | 和 Solo 聊天 / 点击文字输入，长按语音说话 | 源码动作需沿调用方确认：.simultaneousGesture( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4403` · P1 |
| IC-0a3ae3a25f · EmptyStateOverlay · stageButton · 动态 | 扩展到 25 公里 | 复用组件调用：action: { viewModel.emptyStateActionTryExpand() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4517` · P1 |
| IC-c5f44b4652 · EmptyStateOverlay · stageButton · 动态 | 搜索更远范围 | 复用组件调用：action: { viewModel.emptyStateActionTryExplore() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4522` · P1 |
| IC-88def88594 · EmptyStateOverlay · stageButton · 动态 | 浏览 %@ | 复用组件调用：action: { viewModel.emptyStateActionBrowseCity() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4527` · P1 |
| IC-98c899f9c6 · EmptyStateOverlay · Button  | 清除筛选 | 执行：viewModel.clearFilters() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4536` · P1 |
| IC-9cf139a131 · EmptyStateOverlay · Button  | 动态 label/无显式名称：需复核 | 执行：Haptics.selection() action() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4578` · P1 |
| IC-b7f610e19f · FilteredEmptyOverlay · Button  | 清除筛选 | 执行：Haptics.selection() viewModel.clearFilters() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4645` · P1 |
| IC-15fa9f2f07 · NowEmptyOverlay · Button · 动态 | 接下来最佳 / 接下来最佳：%1$@，%2$@。点击查看。 | 执行：Haptics.impact(.light) viewModel.openExperienceDetail(soonest.experience) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4792` · P1 |
| IC-fb437ed7a1 · NowEmptyOverlay · Button · 动态 | 浏览附近全部 | 执行：Haptics.selection() viewModel.clearFilters() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/CompassMapView.swift:4858` · P1 |

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
| IC-67b744f6af · ExploreConsentSheet · Button  | 了解了 — 开始探索 | 执行：onAccept | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:69` · P1 |
| IC-fba9129f6b · ExploreConsentSheet · Button  | 暂不 | 执行：onCancel | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:82` · P1 |
| IC-c25aa122c0 · ExploreConsentSheetModifier · sheet · 动态 | 动态 label/无显式名称：需复核 | 呈现/导航声明：.sheet(isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:124` · P1 |
| IC-71d1b667b1 · ExploreConsentSheetModifier · ExploreConsentSheet · 动态 | 动态 label/无显式名称：需复核 | 复用组件调用：onAccept: {; onCancel: { | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:130` · P1 |

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
| IC-9de18d6156 · LocationPickerSheet · Picker · 动态 | 位置类型 | 编辑/选择绑定：$bs.selectedTab | binding: $bs.selectedTab | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:39` · P1 |
| IC-e52134c4fc · LocationPickerSheet · Button · 动态 | 添加自定义城市 | 执行：state.selectedTab = .search | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:64` · P1 |
| IC-6003c7762b · LocationPickerSheet · Button · 动态 | 取消 | 执行：onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:73` · P1 |
| IC-5212a07fe7 · LocationPickerSheet · alert  | 保存为自定义城市 / 城市名称 / 保存 / 取消 / 该城市将出现在您的已保存位置列表中。 | 呈现/导航声明：.alert( NSLocalizedString("locationPicker.search.saveCity.title", comment: "Save as custom city"), isPresented: $bs.isShowingSaveSearchAlert ) | binding: $bs.isShowingSaveSearchAlert; cancel | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:89` · P1 |
| IC-91264f512f · LocationPickerSheet · TextField  | 城市名称 | 编辑/选择绑定：$bs.saveNameText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:93` · P1 |
| IC-4d1e12a2e0 · LocationPickerSheet · Button  | 保存 | 执行：confirmSaveSearchResult() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:97` · P1 |
| IC-25b38ece6f · LocationPickerSheet · Button  | 取消 | 执行：state.pendingSaveItem = nil | cancel | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:100` · P1 |
| IC-01294e0269 · LocationPickerSheet · alert  | 命名此位置 / 位置名称 / 保存并设置 / 取消 / 已保存的位置将出现在您的城市列表中，方便快速访问。 | 呈现/导航声明：.alert( NSLocalizedString("locationPicker.map.saveCity.title", comment: "Name this location"), isPresented: $bs.isShowingSaveMapAlert ) | binding: $bs.isShowingSaveMapAlert; cancel | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:107` · P1 |
| IC-8bfd5c18f3 · LocationPickerSheet · TextField  | 位置名称 | 编辑/选择绑定：$bs.mapSaveNameText | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:111` · P1 |
| IC-9df44d8b10 · LocationPickerSheet · Button  | 保存并设置 | 执行：confirmSaveMapLocation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:115` · P1 |
| IC-14ede5b7f8 · LocationPickerSheet · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:118` · P1 |
| IC-002b439ea6 · LocationPickerSheet · Button · 动态 | 全部城市 | 执行：commitHaptic() viewModel.selectCity(nil) onDismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:138` · P1 |
| IC-cc7426f39d · LocationPickerSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：commitHaptic() viewModel.selectCity(city.code) onDismiss() | isSelected | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:161` · P1 |
| IC-4808e9c40f · LocationPickerSheet · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：commitHaptic() viewModel.selectCustomLocation( coordinate: saved.coordinate, label: saved.name, cityCode: saved.id ) onDismiss() | isSelected | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:183` · P1 |
| IC-46922cdf6b · LocationPickerSheet · onDelete · 动态 | 动态 label/无显式名称：需复核 | 执行：offsets in let idsToDelete = offsets.map { custom[$0].id } for id in idsToDelete { customCityStore.remove(id: id) } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:201` · P1 |
| IC-94f27c8700 · LocationPickerSheet · searchable  | 搜索城市 | 编辑/选择绑定：bs.citySearchQuery；customCityStore.cities.count | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:209` · P1 |
| IC-3143b49ed1 · LocationPickerSheet · TextField · 动态 | 城市、地点或地址 | 编辑/选择绑定：bs.searchQuery | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:253` · P1 |
| IC-9224d63c93 · LocationPickerSheet · onSubmit · 动态 | 动态 label/无显式名称：需复核 | 执行：triggerSearch() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:260` · P1 |
| IC-aed0d3b2f7 · LocationPickerSheet · Button · 动态 | xmark.circle.fill | 执行：state.searchQuery = "" state.searchResults = [] state.searchError = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:266` · P1 |
| IC-9817b1496a · LocationPickerSheet · Button · 动态 | 苹果地图 / 保存城市 | 执行：selectSearchResult(item) | binding: item) | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:311` · P1 |
| IC-c31c363f8a · LocationPickerSheet · contextMenu · 动态 | 苹果地图 / 保存城市 | 呈现/导航声明：.contextMenu | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:316` · P1 |
| IC-cbfdef1f60 · LocationPickerSheet · Button · 动态 | 苹果地图 | 执行：item.openInMaps() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:317` · P1 |
| IC-06d2b70377 · LocationPickerSheet · swipeActions · 动态 | 保存城市 | 呈现/导航声明：.swipeActions(edge: .trailing) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:321` · P1 |
| IC-425adb0124 · LocationPickerSheet · Button · 动态 | 保存城市 | 执行：promptSaveSearchResult(item) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:322` · P1 |
| IC-f0f0b9b16f · LocationPickerSheet · Button  | 将图钉移到这些坐标 | 执行：applyCoordinateFields() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:371` · P1 |
| IC-93c59bc69f · LocationPickerSheet · Button · 动态 | 保存并设置位置 | 执行：promptSaveMapLocation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:422` · P1 |
| IC-f1d51e7e78 · LocationPickerSheet · Button  | 不保存直接使用 | 执行：commitMapLocation() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:438` · P1 |
| IC-6b7270d6ee · CoordinateField · TextField · 动态 | 动态 label/无显式名称：需复核 | 编辑/选择绑定：$text | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:719` · P1 |

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
| IC-b70a85ee7c · EntitlementBanner · NavigationLink  | 查看订阅详情 | 执行：PaywallView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/EntitlementBanner.swift:20` · P1 |

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
| IC-c356a21400 · MeEmptyStateCard · Button  | 探索地图 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:521` · P1 |
| IC-9df0f36ca0 · MapAvatarBubble · Button · 动态 | 打开个人中心 / 你有待处理的好友申请 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Me/MeSheet.swift:558` · P1 |

### `apps/ios/SoloCompass/Views/Omen/OmenCardView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-12ec755ab9 · OmenCardView · Button  | Mark done | 执行：flipped = true onMicroTaskDone() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Omen/OmenCardView.swift:53` · P2 |

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
| IC-42c0303983 · OnboardingView · Button · 动态 | 开始 1 个月免费试用 | 执行：Task { await runOnboardingPurchase() } | disabled(paywallPurchaseInFlight) | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:573` · P1 |
| IC-3f8f65c74e · OnboardingView · Button  | 稍后再说 | 执行：finishOnboardingPaywall() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:608` · P1 |
| IC-d5573b8203 · OnboardingView · Button · 动态 | \(style.localizedTitle), \(style.localizedDescription) | 执行：Haptics.selection() preferences.soloTravelStyle = style | isSelected | `apps/ios/SoloCompass/Views/Onboarding/OnboardingView.swift:686` · P1 |

### `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-75fac3ac7a · TermsConsentSheet · Link  | 隐私政策 | 源码动作需沿调用方确认：Link(NSLocalizedString("terms.links.privacy", comment: "Privacy policy link"), | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:80` · P1 |
| IC-0992670485 · TermsConsentSheet · Link  | 用户协议 | 源码动作需沿调用方确认：Link(NSLocalizedString("terms.links.tos", comment: "Terms of service link"), | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:82` · P1 |
| IC-1bcdcaecc8 · TermsConsentSheet · Button  | 同意并继续 | 执行：UserDefaults.standard.set(true, forKey: Self.acceptedKey) onAccept() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:93` · P1 |
| IC-f3e0910386 · TermsConsentSheet · Button  | 暂不 | 执行：declined = true onDecline() | cancel | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:104` · P1 |
| IC-a3efaef3d8 · TermsConsentSheet · Button  | 重新查看 | 执行：declined = false | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Onboarding/TermsConsentSheet.swift:134` · P1 |

### `apps/ios/SoloCompass/Views/Ost/OstShareCard.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-4a5ef446e5 · OstShareCard · Button  | Share | 执行：onShare | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Ost/OstShareCard.swift:43` · P2 |
| IC-2fe45da0ab · OstShareCard · Button  | New style | 执行：onRegenerate | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Ost/OstShareCard.swift:53` · P2 |

### `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-34158305e8 · PaywallView · Button · 动态 | 关闭 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:63` · P1 |
| IC-f7b6b3ffdb · PaywallView · alert · 动态 | 购买未完成 / 好 | 呈现/导航声明：.alert( NSLocalizedString("paywall.error.title", comment: "Purchase error"), isPresented: .constant(purchaseError != nil), actions: | binding: .constant(purchaseError != nil), | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:87` · P1 |
| IC-2634565607 · PaywallView · Button · 动态 | 好 | 执行：purchaseError = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:91` · P1 |
| IC-c583770812 · PaywallView · Button · 动态 | 含 1 个月免费 / 最划算 | 执行：selectedProductID = product.id | isSelected | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:244` · P1 |
| IC-3de6ac97bb · PaywallView · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：Task { await runPurchase() } | disabled(isDisabled) | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:340` · P1 |
| IC-5703c3cc8e · PaywallView · Button · 动态 | 免费继续使用 | 执行：dismiss() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:361` · P1 |
| IC-0b416f07c7 · PaywallView · Button · 动态 | 恢复购买 | 执行：Task { await runRestore() } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:391` · P1 |
| IC-87860e739f · PaywallView · Link · 动态 | 管理订阅 | 源码动作需沿调用方确认：Link( | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:398` · P1 |

### `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-037265e81d · AIProviderSettingsView · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：preferences.aiProvider = provider | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:49` · P1 |
| IC-04cb6950f1 · AIProviderSettingsView · SecureField · 动态 | 粘贴你的 API 密钥… | 编辑/选择绑定：$prefs.aiApiKey | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:66` · P1 |
| IC-8afdce5e71 · AIProviderSettingsView · TextField  | https://api.example.com/v1 | 编辑/选择绑定：$prefs.aiBaseURL | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:88` · P1 |
| IC-281bda4634 · AIProviderSettingsView · TextField  | 输入模型名称 | 编辑/选择绑定：$prefs.aiModelName | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:110` · P1 |

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
| IC-422a25a7e3 · SettingsView · onTapGesture  | 动态 label/无显式名称：需复核 | 执行：handleVersionTap() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:610` · P1 |
| IC-5e3ce750f5 · SettingsView · alert · 动态 | 好 | 呈现/导航声明：.alert( forgetMeToast ?? "", isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:616` · P1 |
| IC-219b0944bd · SettingsView · Button · 动态 | 好 | 执行：forgetMeToast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:623` · P1 |
| IC-f36ed03a09 · SettingsView · alert · 动态 | 好 | 呈现/导航声明：.alert( exportToast ?? "", isPresented: Binding( get: | binding: Binding( | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:631` · P1 |
| IC-ceca9dd9ae · SettingsView · Button · 动态 | 好 | 执行：exportToast = nil | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:638` · P1 |
| IC-b4ccbbec29 · SettingsView · NavigationLink · 动态 | AI 提供商 | 执行：AIProviderSettingsView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:699` · P1 |
| IC-ff339c76c8 · SettingsView · Button  | 用测试邮箱解锁 | 执行：adminEmailInput = "" showingAdminUnlock = true | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:721` · P1 |
| IC-9f880ec0e4 · SettingsView · NavigationLink · 动态 | 开发者选项 / API、功能开关与调试工具 | 执行：DeveloperOptionsView() .environment(preferences) .environment(subscriptionService) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:733` · P1 |
| IC-ead9588bc9 · SettingsView · alert  | 测试者解锁 / you@example.com / 取消 / 解锁 / 输入你的测试邮箱以在本设备上解锁 Pro。 | 呈现/导航声明：.alert( NSLocalizedString("settings.adminUnlock.title", comment: "Admin unlock title"), isPresented: $showingAdminUnlock ) | binding: $showingAdminUnlock; cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:759` · P1 |
| IC-1ef0f60358 · SettingsView · TextField  | you@example.com | 编辑/选择绑定：$adminEmailInput | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:763` · P1 |
| IC-93fea1ed32 · SettingsView · Button  | 取消 | 执行： | cancel | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:769` · P1 |
| IC-449fc45fd5 · SettingsView · Button  | 解锁 | 执行：runAdminUnlock() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:770` · P1 |
| IC-f005e8c0d7 · TravelStyleSettingsView · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：Haptics.selection(); preferences.soloTravelStyle = style | isSelected | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:885` · P1 |
| IC-ece08d9860 · CategoryPreferencesView · onTapGesture · 动态 | 隐藏 | 执行：togglePreferred(category) | destructive | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:945` · P1 |
| IC-b579bf22cb · CategoryPreferencesView · swipeActions · 动态 | 隐藏 | 呈现/导航声明：.swipeActions(edge: .trailing) | destructive | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:946` · P1 |
| IC-493d63e392 · CategoryPreferencesView · Button · 动态 | 隐藏 | 执行：toggleDisliked(category) | destructive | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:947` · P1 |
| IC-c98333a1fa · CategoryPreferencesView · Button · 动态 | xmark.circle.fill | 执行：Haptics.selection() preferences.dislikedCategories.removeAll { $0 == category } | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:967` · P1 |
| IC-5dbf13bfd7 · CompanionHubView · NavigationLink · 动态 | 同伴档案 | 执行：CompanionProfileView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1017` · P1 |
| IC-64a59a097e · CompanionHubView · NavigationLink · 动态 | 我的招募申请 | 执行：MyRequestsListView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1027` · P1 |
| IC-6f0d85445e · CompanionHubView · NavigationLink  | 已加入的群聊 | 执行：CompanionConversationsListView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1036` · P1 |
| IC-5cdc0c02ac · CompanionHubView · NavigationLink  | 发现招募路线 | 执行：DiscoverRecruitingRoutesView() .environment(preferences) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1046` · P1 |
| IC-7dcaba6449 · CompanionHubView · NavigationLink  | 我主理的路线 | 执行：MyHostedRoutesListView() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1057` · P1 |
| IC-6ec53f0084 · CompanionConversationsListView · NavigationLink · 动态 | 动态 label/无显式名称：需复核 | 执行：ChatView(conversation: conv, currentUserId: currentUserId) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1111` · P1 |
| IC-b82ebf50b6 · VisibleCategoriesView · onTapGesture · 动态 | 动态 label/无显式名称：需复核 | 执行：toggle(category) | isSelected | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1217` · P1 |
| IC-d53fe4c3d1 · CustomTagsView · TextField · 动态 | 新标签 | 编辑/选择绑定：$draft | errorMessage | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1272` · P1 |
| IC-9170f75d09 · CustomTagsView · onSubmit  | 动态 label/无显式名称：需复核 | 执行：addDraft() | errorMessage | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1283` · P1 |
| IC-1eeaaefa33 · CustomTagsView · Button  | 添加 | 执行：addDraft() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1286` · P1 |
| IC-2c58b2ddd5 · CustomTagsView · onDelete · 动态 | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.onDelete(perform: deleteTags) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Settings/SettingsView.swift:1327` · P1 |

### `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-2e9d55d60b · ConfidenceBadge · Button · 动态 | AI 估算 · 待验证 / 信号 / %@，第 %d 级，%d 个信号 / 双击查看信任信号 | 执行：Haptics.selection() if !reduceMotion { withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pressed = true } DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { w | reduceMotion | `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift:23` · P1 |
| IC-10cc81254f · ConfidenceBadge · popover · 动态 | %@，第 %d 级，%d 个信号 / 双击查看信任信号 | 呈现/导航声明：.popover(isPresented: $showSignals) | binding: $showSignals) {; reduceMotion | `apps/ios/SoloCompass/Views/Shared/ConfidenceBadge.swift:71` · P1 |

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
| IC-6072576507 · PendingCheckInBanner · Button  | 关闭 | 执行：autoDismissTask?.cancel() autoDismissTask = nil onDismiss() | disabled(confirmed) | `apps/ios/SoloCompass/Views/Shared/PendingCheckInBanner.swift:113` · P1 |

### `apps/ios/SoloCompass/Views/Shared/SoloEmptyState.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-5cd1c7040e · SoloEmptyState · Button · 动态 | 动态 label/无显式名称：需复核 | 执行：action | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Shared/SoloEmptyState.swift:68` · P1 |

### `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-5b133bb9e9 · SoloScoreBadge · Button · 动态 | 独行 / 独行评分 %@ / 10 / 非常适合独行旅行者 / 对独行者可能略显暴露 / 双击查看评分明细 | 执行：showBreakdown.toggle() Haptics.impact(.light) | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift:39` · P1 |
| IC-b9642e1f53 · SoloScoreBadge · popover · 动态 | 独行评分 %@ / 10 / 非常适合独行旅行者 / 对独行者可能略显暴露 / 双击查看评分明细 | 呈现/导航声明：.popover(isPresented: $showBreakdown) | binding: $showBreakdown) {; reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift:86` · P1 |
| IC-cd2b6cf28f · SoloScorePopoverContent · Button · 动态 | 点击查看该维度的通俗解释 | 执行：withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { expandedIndex = isExpanded ? nil : index } Haptics.selection() | reduceMotion | `apps/ios/SoloCompass/Views/Shared/SoloScoreBadge.swift:415` · P1 |

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
| IC-7fa7a345c3 · VoiceButton · gesture · 动态 | 语音输入 / 长按说话，松开发送，上滑取消。或双击开始、再双击停止。 / 录音中 / 空闲 / 开始/停止语音输入 | 源码动作需沿调用方确认：.gesture( | isRecording; reduceMotion; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:97` · P1 |
| IC-529f0a9526 · VoiceButton · simultaneousGesture · 动态 | 语音输入 / 长按说话，松开发送，上滑取消。或双击开始、再双击停止。 / 录音中 / 空闲 / 开始/停止语音输入 | 源码动作需沿调用方确认：.simultaneousGesture( | isRecording; reduceMotion; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:101` · P1 |
| IC-b721ebfe61 · VoiceButton · accessibilityAction · 动态 | 开始/停止语音输入 / 需要麦克风权限 / 好 | 执行：if isRecording { stopRecording() } else { startRecording() } | binding: $showPermissionAlert) {; isRecording; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:139` · P1 |
| IC-362e8a8ae1 · VoiceButton · alert · 动态 | 需要麦克风权限 / 好 / Solo Compass 需要麦克风和语音识别权限来接受语音输入。 / 语音识别错误 | 呈现/导航声明：.alert(NSLocalizedString("voice.permission.title", comment: ""), isPresented: $showPermissionAlert) | binding: $showPermissionAlert) {; binding: Binding(get: { recognitionError != nil }, set: { if !$0 { recognitionError = nil } })) {; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:142` · P1 |
| IC-1d0ac2b55a · VoiceButton · Button · 动态 | 好 | 执行： | cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:143` · P1 |
| IC-418b917c12 · VoiceButton · alert · 动态 | 语音识别错误 / 好 / 松开取消 / 剩余 %d 秒 / 我在听… | 呈现/导航声明：.alert(NSLocalizedString("voice.error.title", comment: "Voice recognition error"), isPresented: Binding(get: | binding: Binding(get: { recognitionError != nil }, set: { if !$0 { recognitionError = nil } })) {; isRecording; reduceMotion; cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:147` · P1 |
| IC-7b8ded9bfd · VoiceButton · Button · 动态 | 好 | 执行：recognitionError = nil | cancel | `apps/ios/SoloCompass/Views/Shared/VoiceButton.swift:149` · P1 |

### `apps/ios/SoloCompass/Views/Today/TodayContainer.swift`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| IC-2a7a0d89bd · TodayHomeScaffold · navigationDestination  | 动态 label/无显式名称：需复核 | 呈现/导航声明：.navigationDestination(for: NearbyDestination.self) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayContainer.swift:172` · P1 |
| IC-7479896420 · TodayHomeScaffold · gesture  | 动态 label/无显式名称：需复核 | 源码动作需沿调用方确认：.gesture(mapDragGesture(fullTravel: fullTravel)) | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayContainer.swift:214` · P1 |
| IC-dac6b1ac6c · TodayHomeScaffold · Button  | 返回 Today / 打开地图 | 执行：toggle() | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayContainer.swift:218` · P1 |

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
| IC-f9df5c7170 · TodayStatusHeader · Button · 动态 | 填入境日 | 执行：onConfirmEntryDate | 未从本局部块提取显式状态；需结合所在 View 与调用方 | `apps/ios/SoloCompass/Views/Today/TodayStatusHeader.swift:129` · P1 |

### `apps/web/src/app/(marketing)/download/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-0c63635f63 · /download · ButtonLink · 动态 | Download on the App Store | 导航：{APP_STORE_URL} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/(marketing)/download/page.tsx:67` · P1 |
| WC-01726bad6f · /download · a  | hello@solocompass.app | 导航："mailto:hello@solocompass.app" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/(marketing)/download/page.tsx:98` · P1 |

### `apps/web/src/app/(marketing)/privacy/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-1fd0b732d8 · /privacy · a  | privacy@solocompass.app | 导航："mailto:privacy@solocompass.app" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/(marketing)/privacy/page.tsx:167` · P2 |

### `apps/web/src/app/[city]/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-dfa0f88324 · /[city] · TopBar · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:156` · P1 |
| WC-f76ebe6403 · /[city] · CommandPalette · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:190` · P1 |
| WC-95005bd6ff · /[city] · Link · 动态 | {active && ( )} {label} | 导航：{`/${slug} | active | `apps/web/src/app/[city]/page.tsx:239` · P1 |
| WC-0130137a65 · /[city] · button · 动态 | + City | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:273` · P1 |
| WC-c15243c034 · /[city] · button · 动态 | "Open command palette" | onClick={onOpenPalette} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:291` · P1 |
| WC-4bafd60f8e · /[city] · button · 动态 | {l === "zh" ? "中" : "EN"} | onClick={() => setLang(l)} | active | `apps/web/src/app/[city]/page.tsx:349` · P1 |
| WC-5183be327e · /[city] · Link · 动态 | Solo Compass | 导航："/" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:387` · P1 |
| WC-2486383512 · /[city] · button · 动态 | {s.label} | onClick={() => p.setActiveSort(s.id)} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:508` · P1 |
| WC-9eec4e1b70 · /[city] · CatChip · 动态 | {p.T.allCats} | onClick={() => p.setActiveCat(null)} | active | `apps/web/src/app/[city]/page.tsx:531` · P1 |
| WC-ec28eb543d · /[city] · CatChip · 动态 | {p.lang === "zh" ? c.zh : c.en} | onClick={() => p.setActiveCat(p.activeCat === k ? null : k)} | active | `apps/web/src/app/[city]/page.tsx:540` · P1 |
| WC-36171e32d5 · /[city] · ListRow · 动态 | 动态/仅图形：需复核 | onClick={() => p.setFocusedId(e.id)} | focused; hover | `apps/web/src/app/[city]/page.tsx:554` · P1 |
| WC-4392d8a7b3 · /[city] · button · 动态 | {children} | onClick={onClick} | active | `apps/web/src/app/[city]/page.tsx:583` · P1 |
| WC-1859cff188 · /[city] · div · 动态 | {String(index + 1).padStart(2, "0")} {cat.short} | onClick={onClick} | focused; hover | `apps/web/src/app/[city]/page.tsx:627` · P1 |
| WC-60fd80031b · /[city] · WebLisbonMap · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:780` · P1 |
| WC-3ff7b79dbc · /[city] · button · 动态 | {c} | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:803` · P1 |
| WC-aee2292042 · /[city] · DetailDock · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | focused | `apps/web/src/app/[city]/page.tsx:894` · P1 |
| WC-9feb457b44 · /[city] · button · 动态 | "Close" | onClick={onClose} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:937` · P1 |
| WC-7cb9c16805 · /[city] · Link · 动态 | {title} | 导航：{detailHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:1039` · P1 |
| WC-ac40cf725e · /[city] · button · 动态 | {T.addToPlan} | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:1145` · P1 |
| WC-d19c1e48a5 · /[city] · Link · 动态 | {lang === "zh" ? "详情" : "Details"} → | 导航：{detailHref} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/[city]/page.tsx:1162` · P1 |

### `apps/web/src/app/app/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-bbb905cab9 · /app · MapView · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:72` · P1 |
| WC-45369c1c02 · /app · TodayBanner · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:81` · P1 |
| WC-4ad36ea505 · /app · VoiceIntent · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:83` · P1 |
| WC-5bc60879ba · /app · ExperienceSheet · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/app/page.tsx:85` · P1 |
| WC-4fad76245f · /app · NearbySheet · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | loading | `apps/web/src/app/app/page.tsx:92` · P1 |

### `apps/web/src/app/experience/[id]/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-693096194f · /experience/[id] · Link · 动态 | {T.backToCity} | 导航：{`/${city.slug} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/experience/[id]/page.tsx:217` · P1 |
| WC-78314d7f23 · /experience/[id] · Link · 动态 | + {T.addToTrip} | 导航：{`/${city.slug} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/experience/[id]/page.tsx:467` · P1 |
| WC-12b29bc463 · /experience/[id] · Link · 动态 | ↗ {T.viewMap} | 导航：{`/${city.slug} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/experience/[id]/page.tsx:485` · P1 |
| WC-e431b81542 · /experience/[id] · Link · 动态 | {lang === "zh" ? ncat.zh : ncat.en} {ntitle} {nplace} · {it.walkMin} {T.mins} | 导航：{`/experience/${it.id} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/experience/[id]/page.tsx:548` · P1 |

### `apps/web/src/app/layout.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-553e0cb4aa · RootLayout · a  | Skip to main content | 导航："#main" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/layout.tsx:38` · P1 |

### `apps/web/src/app/mobile-preview/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-7ca3cd9019 · /mobile-preview · Link · 动态 | {T.back} | 导航：{`/lisbon${lang === "en" ? "?lang=en" : ""} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:140` · P2 |
| WC-35d33ef007 · /mobile-preview · PhoneFrame · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:169` · P2 |
| WC-2c630f403f · /mobile-preview · CommandPalette · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:183` · P2 |
| WC-942f94578c · /mobile-preview · button · 动态 | "Open command palette" | onClick={p.onOpenPalette} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:358` · P2 |
| WC-9a8c17db1d · /mobile-preview · button · 动态 | {p.lang === "zh" ? "中文" : "EN"} | onClick={() => p.setLang(p.lang === "zh" ? "en" : "zh")} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:376` · P2 |
| WC-3050ad8adb · /mobile-preview · button · 动态 | "Toggle sheet" | onClick={p.toggleSheet} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:414` · P2 |
| WC-3f3409be90 · /mobile-preview · button · 动态 | {p.T.getApp} | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:510` · P2 |
| WC-2eedc9ee31 · /mobile-preview · button · 动态 | {p.T.maybeLater} | onClick={p.dismissHint} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:526` · P2 |
| WC-675f172ebb · /mobile-preview · Link · 动态 | {title} {place} · {e.walkMin} {p.T.walkMin} | 导航：{`/experience/${e.id} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:574` · P2 |
| WC-4f75ac1e66 · /mobile-preview · button · 动态 | {checked ? `✓ ${p.T.checkedIn}` : p.T.checkIn} | onClick={() => p.toggleCheckin(e.id)} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/mobile-preview/page.tsx:618` · P2 |

### `apps/web/src/app/trip/[slug]/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-a2fda86668 · /trip/[slug] · button · 动态 | ↗ {T.share} | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/trip/[slug]/page.tsx:170` · P1 |
| WC-5c51b6a224 · /trip/[slug] · Link · 动态 | compass.io → | 导航：{`/${trip.citySlug} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/trip/[slug]/page.tsx:447` · P1 |

### `apps/web/src/app/zh/privacy/page.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-13b916b049 · /zh/privacy · a · 动态 | privacy@solocompass.app | 导航："mailto:privacy@solocompass.app" | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/app/zh/privacy/page.tsx:164` · P2 |

### `apps/web/src/components/DesignNav.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-3b6f3c0fb0 · DesignNav · Link · 动态 | {it.label} | 导航：{it.href} | hover | `apps/web/src/components/DesignNav.tsx:35` · P1 |

### `apps/web/src/components/ExperienceSheet.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-0fe56ac052 · handleCheckin · Drawer.Root · 动态 | {result ? ( ) : null} | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/ExperienceSheet.tsx:55` · P1 |
| WC-08b0887d3b · handleCheckin · SheetBody · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | checkinState | `apps/web/src/components/ExperienceSheet.tsx:67` · P1 |
| WC-0503980082 · SheetBody · a · 动态 | link | 导航：{s.url} | hover | `apps/web/src/components/ExperienceSheet.tsx:205` · P1 |
| WC-f71c1e00bd · SheetBody · CheckinControl · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | checkinState | `apps/web/src/components/ExperienceSheet.tsx:221` · P1 |
| WC-5bf3ca5363 · CheckinControl · button · 动态 | {checkinState === "saving" ? "Saving…" : "I did this"} | onClick={() => onCheckin()} | disabled={checkinState === "saving"}; checkinState; hover | `apps/web/src/components/ExperienceSheet.tsx:267` · P1 |
| WC-353e53bb51 · CheckinControl · button · 动态 | {`Rate ${r} out of 5`} | onClick={() => onCheckin(r)} | disabled={checkinState === "saving"}; checkinState; hover | `apps/web/src/components/ExperienceSheet.tsx:278` · P1 |

### `apps/web/src/components/MapView.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-5f3bafc79f · MapView · NavigationControl · 动态 | 动态地图控件/标记：需运行时核实 accessible name | new mapboxgl.NavigationControl({ showCompass: false }), "top-right"); map.on("load", () => { setMapReady(true); const c = map.getCenter(); reportCenter([c.lng, c.lat]); }); map.on( | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/MapView.tsx:64` · P1 |
| WC-55a4840da3 · MapView · click · 动态 | 动态地图控件/标记：需运行时核实 accessible name | .addEventListener("click", (event) => { event.stopPropagation(); onSelectRef.current(exp.id); }); const [lon, lat] = exp.location.coordinates; const marker = new mapboxgl.Marker({  | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/MapView.tsx:159` · P1 |
| WC-57612934db · MapView · Marker · 动态 | 动态地图控件/标记：需运行时核实 accessible name | new mapboxgl.Marker({ element: el }).setLngLat([lon, lat]).addTo(map); markersRef.current.set(exp.id, marker); } }, [results, mapReady, selectedId]); useEffect(() => { const map =  | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/MapView.tsx:165` · P1 |
| WC-1a3a281d79 · MapView · click · 动态 | 动态地图控件/标记：需运行时核实 accessible name | .on("click", handler); return () => { map.off("click", handler); }; }, [mapReady]); return <div ref={containerRef} className="absolute inset-0 h-full w-full" />; } | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/MapView.tsx:175` · P1 |

### `apps/web/src/components/NearbySheet.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-7ded2bf892 · NearbySheet · button · 动态 | {isPeek ? "Expand" : "Collapse"} | onClick={() => setSnap(snap === SNAP_POINTS[0] ? SNAP_POINTS[1] : SNAP_POINTS[0])} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/NearbySheet.tsx:54` · P1 |
| WC-a1d4b646d7 · NearbySheet · TabButton · 动态 | Nearby {results.length > 0 ? `· ${results.length}` : ""} | onClick={() => setTab("nearby")} | active | `apps/web/src/components/NearbySheet.tsx:74` · P1 |
| WC-3e6c8a4d93 · NearbySheet · TabButton · 动态 | My footprint | onClick={() => setTab("timeline")} | active | `apps/web/src/components/NearbySheet.tsx:77` · P1 |
| WC-42277d8c17 · NearbySheet · NearbyList · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | loading | `apps/web/src/components/NearbySheet.tsx:85` · P1 |
| WC-2965e24d79 · NearbySheet · TimelineList · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/NearbySheet.tsx:93` · P1 |
| WC-c0751c0370 · PeekHeader · button · 动态 | {isPeek ? "Pull up to browse experiences" : "Currently viewing experiences"} | onClick={onExpand} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/NearbySheet.tsx:120` · P1 |
| WC-d270247c10 · TabButton · button · 动态 | {children} {active && ( )} | onClick={onClick} | active; hover | `apps/web/src/components/NearbySheet.tsx:157` · P1 |
| WC-1dc2c8b2c6 · NearbyList · NearbyCard · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | selected | `apps/web/src/components/NearbySheet.tsx:214` · P1 |
| WC-d68a9a870c · NearbyCard · button · 动态 | {categoryEmoji[exp.category]} {exp.title} {exp.soloScore.overall.toFixed(1)} {exp.oneLiner} {categoryLabel[exp.category]} · {result.walkingM | onClick={() => onSelect(exp.id)} | selected; hover | `apps/web/src/components/NearbySheet.tsx:239` · P1 |

### `apps/web/src/components/TimelineList.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-ba20f40de8 · TimelineList · TimelineCard · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/TimelineList.tsx:42` · P1 |
| WC-b81a0595f5 · TimelineCard · button · 动态 | {categoryEmoji[exp.category]} {exp.title} {entry.rating !== null && ( {"★".repeat(entry.rating)} {"★".repeat(5 - entry.rating)} )} {exp.oneL | onClick={() => onSelect?.(exp.id)} | hover | `apps/web/src/components/TimelineList.tsx:63` · P1 |

### `apps/web/src/components/TodayBanner.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-db692e662a · TodayBanner · button · 动态 | {categoryEmoji[p.experience.category]} {p.experience.title} {p.experience.soloScore.overall.toFixed(1)} | onClick={() => onSelect(p.experience.id)} | hover | `apps/web/src/components/TodayBanner.tsx:41` · P1 |
| WC-fdde1aeaac · TodayBanner · button · 动态 | "Dismiss today's picks" | onClick={handleDismiss} | hover | `apps/web/src/components/TodayBanner.tsx:56` · P1 |

### `apps/web/src/components/VoiceIntent.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-ef20f093a6 · handleTextSubmit · button · 动态 | {`Clear intent: ${intent}`} | onClick={() => onIntentChange(null)} | hover | `apps/web/src/components/VoiceIntent.tsx:140` · P1 |
| WC-a26e5fb530 · handleTextSubmit · button · 动态 | {recording ? "Listening — release to send" : "Hold to speak"} | onPointerDown={handlePressStart}；onPointerUp={handlePressEnd}；onPointerLeave={recording ? handlePressEnd : undefined}；onPointerCancel={handlePressEnd} | aria-pressed={recording}; recording; hover | `apps/web/src/components/VoiceIntent.tsx:157` · P1 |
| WC-212a800b0d · handleTextSubmit · form · 动态 | setTextValue(e.target.value)} placeholder={ permissionDenied ? "Type instead — mic permission denied" : "What do you feel like?" } aria-labe | onSubmit={handleTextSubmit} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/VoiceIntent.tsx:175` · P1 |
| WC-728233709b · handleTextSubmit · input · 动态 | "Type what you feel like doing" | onChange={(e) => setTextValue(e.target.value)} | value={textValue} | `apps/web/src/components/VoiceIntent.tsx:179` · P1 |
| WC-7bcfa28196 · handleTextSubmit · button · 动态 | Send | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | hover | `apps/web/src/components/VoiceIntent.tsx:189` · P1 |

### `apps/web/src/components/lisbon/CommandPalette.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-016f509464 · onKey · div · 动态 | "Command palette" | onClick={() => onOpenChange(false)} | role="dialog" | `apps/web/src/components/lisbon/CommandPalette.tsx:215` · P1 |
| WC-7135a97c63 · onKey · div · 动态 | setQuery(e.target.value)} placeholder={ lang === "zh" ? "搜场景、体验、城市…" : "Search scenarios, experiences, cities…" } style={{ flex: 1, border:  | onClick={(e) => e.stopPropagation()} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/lisbon/CommandPalette.tsx:232` · P1 |
| WC-434d6aaaea · onKey · input · 动态 | 动态/仅图形：需复核 | onChange={(e) => setQuery(e.target.value)} | value={query} | `apps/web/src/components/lisbon/CommandPalette.tsx:259` · P1 |
| WC-a5c0833411 · onKey · button · 动态 | {it.title} {it.subtitle} {it.hint} | onClick={() => { onOpenChange(false); router.push(it.href); }} | active; hover | `apps/web/src/components/lisbon/CommandPalette.tsx:308` · P1 |
| WC-3b2585fc11 · onKey · keydown · 动态 | 动态地图控件/标记：需运行时核实 accessible name | .addEventListener("keydown", onKey); return () => window.removeEventListener("keydown", onKey); }, [open, onOpenChange, filtered, activeIdx, router]); if (!open) return null; const | 由地图引擎/数据决定；运行时未验证 | `apps/web/src/components/lisbon/CommandPalette.tsx:206` · P1 |

### `apps/web/src/components/lisbon/WebLisbonMap.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-d08ca2fd73 · WebLisbonMap · g · 动态 | {(isHover \|\| isFocus) && ( )} {isFocus && ( )} | onClick={() => onTap?.(p.id)} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/lisbon/WebLisbonMap.tsx:247` · P1 |

### `apps/web/src/components/marketing/DayPageMock.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-cd03986ead · DayPageMock · button  | ‹ | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/DayPageMock.tsx:25` · P1 |
| WC-ccac899750 · DayPageMock · button  | ♡ | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/DayPageMock.tsx:30` · P1 |

### `apps/web/src/components/marketing/primitives.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-08d0f2dd8f · Button · button · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/primitives.tsx:26` · P1 |
| WC-da0f494847 · ButtonLink · a · 动态 | 动态/仅图形：需复核 | 由调用方/浏览器默认语义决定；需核实是否仅装饰 | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/primitives.tsx:34` · P1 |

### `apps/web/src/components/marketing/sections.tsx`

| ID / screen / 控件 | label | action | states | source:line / 优先级 |
|---|---|---|---|---|
| WC-14600d3b27 · MarketingNav · Link · 动态 | Solo Compass | 导航：{homePath} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:45` · P1 |
| WC-824ea5cd0c · MarketingNav · Link · 动态 | {it.label} | 导航：{it.href} | hover | `apps/web/src/components/marketing/sections.tsx:54` · P1 |
| WC-98eb604de8 · MarketingNav · Link · 动态 | {copy.langSwitch} | 导航：{altPath} | hover | `apps/web/src/components/marketing/sections.tsx:68` · P1 |
| WC-6e04886b0c · MarketingNav · ButtonLink · 动态 | {copy.nav.getApp} | 导航：{APP_STORE_URL} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:74` · P1 |
| WC-7e6aabc591 · Hero · ButtonLink · 动态 | {copy.hero.ctaPrimary} | 导航：{APP_STORE_URL} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:126` · P1 |
| WC-2340057431 · Hero · a  | {copy.hero.ctaSecondary} → | 导航："#features" | hover | `apps/web/src/components/marketing/sections.tsx:130` · P1 |
| WC-8614bed109 · Pricing · ButtonLink · 动态 | {copy.pricing.lifetime.cta} | 导航：{APP_STORE_URL} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:418` · P1 |
| WC-3026c8e237 · Pricing · ButtonLink · 动态 | {copy.pricing.yearly.cta} | 导航：{APP_STORE_URL} | 依赖浏览器默认/调用方状态，运行时未验证 | `apps/web/src/components/marketing/sections.tsx:449` · P1 |
| WC-d901da552e · Pricing · Link · 动态 | {copy.pricing.free} → | 导航：{pricingPath} | hover | `apps/web/src/components/marketing/sections.tsx:457` · P1 |
| WC-14286da1e2 · Footer · Link · 动态 | {l.label} | 导航：{l.href} | hover | `apps/web/src/components/marketing/sections.tsx:514` · P1 |

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

按交付中的工作区重新定位：

```bash
python3 docs/design/interaction-quality/generate_inventory.py --working-tree
```
