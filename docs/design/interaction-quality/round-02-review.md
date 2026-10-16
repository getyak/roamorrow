# 第二轮交互与设计独立审查 · 最终状态

**当前已审范围无剩余确认 P0/P1/P2。44 项主表发现（17 P1 / 27 P2）均已源码闭合；另 4 项服务草稿发现（1 P1 / 3 P2）已修并有宿主验证。共 48 个编号发现，不重复计入中间检查笔记。每项 >96 的目标尚未达到。**

当前清单为 **974 个静态候选（iOS 864 / Web 110）、220 个 UI 文件、44 个功能族（iOS 27 / Web 17）**。候选包含呈现关系与组件调用，不是 974 个独立按钮。固定基线 892 保留历史；当前候选没有因源码闭合或抽样操作自动获得运行认证。

独立哈希读回：最终原生构建源 **633/633**、本轮改动 **104/104**、当前 UI **220/220**、Web release **8/8** 全匹配。源码内容已保存为本地提交 `7e30bf17`；提交不改变既有内容哈希。最终 UI manifest：`e3e637fd843eeb38b19e679feff277e0fb58ef6921bb61dd2609fe43538d801a`。本报告仅修改审查文档；未启动构建、模拟器或新浏览器。

使用 frontend-design 评价真实声明功能：指南按指南入口、只读按阅读/关闭、本机添加按本机持久化评价。原未接通业务不冒称完成。96 是内部专家设计目标，不是用户满意度百分比；画面分和功能/隐私/恢复证据分别记录，未知不补满分。

## 当前功能族矩阵

画面分是已列出上下文的保守最小值，不是整族总分。没有当前渲染的族保持未知。旧 functionalQuality 低分和下方历史 open 表均已退为修前诊断，不能当作当前缺陷。

| 功能族 | 当前源码 | 已见画面分 /100 | 证据范围与剩余验收 |
| --- | --- | --- | --- |
| I01 地图主场景/城市 | 已报问题闭合 | 92（限定画面） | 完整地图/定位拒绝/城市chip与大字banner组合；筛选图已抽样，横滑与结果焦点未操作。 |
| I02 稳定导航/发现 | 已审范围无新增确认缺陷 | 未知 | 本轮地图/问问/发现切换保留、Dock大字与选中语义。 |
| I03 探索工作流 | 已审范围无新增确认缺陷 | 未知 | 本轮探索取消/阶段切换与网络降级、离开后任务停止。 |
| I04 保留对话/历史 | 已报问题闭合 | 未知 | 删除失败/持久恢复已有受影响逻辑测试；实际历史确认弹窗与长对话输入区操作未全测。 |
| I05 对话输入/附件 | 已审范围无新增确认缺陷 | 未知 | 本轮部分成功失败附件单独重试、晚到新附件/草稿保留与键盘布局。 |
| I06 语音 | 已报问题闭合 | 未知 | 生命周期相关逻辑已有受影响测试；真实权限晚回、录音松手/关闭/前后台、VoiceOver仍未操作。 |
| I07 AI 卡片/撤销/诊断 | 已报问题闭合 | 92（限定画面） | 真实AgentStatusLine与route卡已渲染；完整流式切换、Undo/pending VoiceOver时限、卡保存失败/重开未操作。 |
| I08 体验卡/预览 | 已审范围无新增确认缺陷 | 87（限定画面） | 已见卡片画面；长标题建议仍在，内部收藏/评分解释真实命中与读序未操作。 |
| I09 体验详情主动作 | 已报问题闭合 | 93（限定画面） | 已见详情与location组件；导航/来源/笔记操作、暗色及完整大字页面未全测。 |
| I10 体验新增/修正/反馈 | 已报问题闭合 | 93（限定画面） | 新Form及常驻label已见；真实PhotosPicker权限/慢解码/取消/明确skip、磁盘失败与Mail发送仍未操作。 |
| I11 体验分享/导出 | 已审范围无新增确认缺陷 | 未知 | 本轮图像/Markdown生成失败Retry、风格切换晚回与实际分享产物。 |
| I12 行程列表/创建 | 已报问题闭合 | 未知 | 创建保存与取消/名称城市日期大字。 |
| I13 行程详情 | 已报问题闭合 | 未知 | 存储删除/Undo失败恢复已有逻辑测试；发布/撤下/重排/导入收藏等整条UI未全测。 |
| I14 路线创建/详情 | 已报问题闭合 | 89（限定画面） | 路线创建、普通/AX3详情与hosting聊天route卡已见；真实导航启动/Completion/批量邀请失败重试及卡持久回读未全测。 |
| I15 路线招募/申请 | 已报问题闭合 | 未知 | CivilDay/容量与原子存储有受影响逻辑验证；同城空态→地图选城→返回的手递UI未操作。 |
| I16 同伴发现/安全 | 已审范围无新增确认缺陷 | 未知 | 新companion-post-action尚未部署，真实Supabase跨账号/RLS/屏蔽/重试集成未知；本轮原生申请/举报/封禁UI。 |
| I17 同伴资料/消息 | 已报问题闭合 | 未知 | 本轮已编辑身份读回、群聊可用门槛、Completion失败重试和只预填邀请草稿。 |
| I18 路线分享 | 已审范围无新增确认缺陷 | 未知 | 本轮各分享style生成/缓存切换与错误Retry、真实导出结果。 |
| I19 好友入口/邀请/扫码 | 已报问题闭合 | 未知 | 本机原子添加/非法状态/容量失败有逻辑测试；实际扫码授权与离开停止、邀请UI失败恢复未全测。 |
| I20 我的/权益 | 已报问题闭合 | 未知 | 本轮个人资料保存回读、未知trial进度隐藏、权益文案大字。 |
| I21 设置及子页 | 已审范围无新增确认缺陷 | 91（限定画面） | 设置画面已见；各子页分类selected/错误恢复和iOS政策全文Link实际点击未全测。 |
| I22 首次使用/条款 | 已报问题闭合 | 94（限定画面） | 实际step7→方案→空商品Retry失败→Close回step7已父代理抽样；其余引导/条款接受拒绝、真实购买成功未操作。 |
| I23 付费 | 已报问题闭合 | 95（限定画面） | 空catalog/加载失败/Close恢复已父代理抽样；真实商品价格优惠、购买/取消/恢复、并发操作未实际验收。 |
| I24 今日/城市工具 | 已报问题闭合 | 93（限定画面） | Kit普通/AX3、常驻天数字段空值/填值/AX5日历补图已见；保存回读、键盘与通知重排、VoiceOver仍未全测。 |
| I25 仪式/归档 | 已审范围无新增确认缺陷 | 未知 | 按当前只读记录/预览评价；本轮正文日期可读、Close及日期入口；原未接通仪式能力不冒称完成。 |
| I26 管理/共享反馈组件 | 已报问题闭合 | 未知 | 本轮多个CTA独立VoiceOver可达、Undo/提示操作中不消失与最大字号。 |
| I27 信任解释/独行评分 | 已报问题闭合 | 85（限定画面） | 8.7明色badge及compact全色域对比计算通过；popover/暗色/大字/ReduceMotion和解释入口实际操作未全测。 |
| W01 官网 EN/ZH 导航 | 已审范围无新增确认缺陷 | 未知 | 本轮320px中英菜单/语言/下载焦点抽样；上一轮操作证据保留历史。 |
| W02 官网 Hero/功能/信任/页脚 | 已审范围无新增确认缺陷 | 未知 | 本轮首页明暗/窄屏/减少动态渲染；Hero图案、功能示意与正文层级专家评价。 |
| W03 定价 EN/ZH | 已审范围无新增确认缺陷 | 未知 | 本轮方案按钮实际去向和窄屏表格；真实Store商品权益仍以运行商店数据为准。 |
| W04 宣言 EN/ZH | 已审范围无新增确认缺陷 | 未知 | 本轮中英文章行长/返回路径与当前声明抽样。 |
| W05 隐私 EN/ZH | 已审范围无新增确认缺陷 | 未知 | 公开Gist目的地已验证；本轮网页摘要到全文/联系的实际点击。 |
| W06 下载 | 已审范围无新增确认缺陷 | 未知 | 本轮当前环境真实Web/Store/TestFlight分发动作与说明抽样。 |
| W07 共享 Web 控件 | 已报问题闭合 | 未知 | 新global-error重试/回地图及URL语言优先实际故障注入；共享focus/busy状态抽样。 |
| W08 /app 地图 | 已审范围无新增确认缺陷 | 未知 | 本轮无token/引擎错误到列表、地理权限、地图重新建立生命周期抽样。 |
| W09 /app 附近和足迹 | 已审范围无新增确认缺陷 | 未知 | 本轮peek/half/full手柄键盘/拖动与选中详情后状态；整族未全量运行。 |
| W10 /app 今日 | 已审范围无新增确认缺陷 | 未知 | 本轮今日建议到对应真实详情/关闭后的地图遮挡抽样。 |
| W11 /app 语音/文本意图 | 已审范围无新增确认缺陷 | 未知 | 本轮录音授权晚回、隐藏/后台停止、文字草稿保留及44px清除动作抽样。 |
| W12 /app 体验详情 | 已审范围无新增确认缺陷 | 未知 | 本轮评分保存失败保留与Retry、关闭返回焦点和长文小屏抽样。 |
| W13 /[city] 城市工作台 | 已报问题闭合 | 未知 | 默认/zoom5pin可见44与中心/边缘命中、A Vida详情已父代理抽样；其余城市/键盘marker焦点及selected未全测。 |
| W14 城市命令面板 | 已审范围无新增确认缺陷 | 未知 | 本轮Tab后Enter作用域、选中结果/Esc恢复焦点抽样。 |
| W15 /mobile-preview | 已审范围无新增确认缺陷 | 未知 | 本轮演示说明、初始空打卡、刷新清空边界与示意marker语义抽样。 |
| W16 /experience/[id] 分享体验 | 已报问题闭合 | 未知 | 320/390中英无横溢、article44目标与英文View guide焦点已父代理抽样；200%缩放和其余附近/返回组合未测。 |
| W17 /trip/[slug] 分享行程 | 已报问题闭合 | 未知 | 320/390中英与metadata单品牌示例已抽样；Share结果/复制完成未观察，200%缩放未测。 |

## 最新画面判断

已逐图查看 26 张 accepted、9 张 correction、最后 1 张 badge，并核对真实加载失败弹窗。下表 25 个当前可评分画面为 **85–95**；测试专用 ReasoningTracePanel 不计入生产体验。旧路线 ScrollView 空白捕获已由真实 hosting 补图替代，不能当成产品站点消失。分数只评价可见品味、层级、可点击观感和边框注意力，不证明全部点击、触觉、权限或 VoiceOver。

| 当前画面 | 专家分 | 可见判断与建议 |
| --- | --- | --- |
| [kit-without-city-data.png](evidence/round02-visual-accepted-snapshots/kit-without-city-data.png) | 94 | 单卡与整行chevron明确打开表单；棕色重点和白色分组克制，留白符合无城市数据状态。 继续维持单一入口；完整Kit有城市数据/暗色尚无本批画面。 |
| [kit-without-city-data-large.png](evidence/round02-visual-accepted-snapshots/kit-without-city-data-large.png) | 93 | AX3字号保留，标题和整行入口完整，chevron没有挤压主文字。 后续在真实滚动与VoiceOver中确认整行读序；不压小用户字号。 |
| [personal-countdown-form.png](evidence/round02-visual-correction-snapshots/personal-countdown-form.png) | 94 | 入境日期→停留天数常驻label→解释顺序清楚，空值保存禁用可辨。 保持label/数值/单位分工；键盘及长错误反馈未由图证明。 |
| [personal-countdown-form-filled.png](evidence/round02-visual-correction-snapshots/personal-countdown-form-filled.png) | 94 | 输入30后仍保留停留天数与天单位；保存由禁用转可用，身份不会随placeholder消失。 真实保存回读和时区/通知结果独立验收。 |
| [personal-countdown-form-largest.png](evidence/round02-visual-correction-snapshots/personal-countdown-form-largest.png) | 93 | AX5改系统graphical日历与独立日期label，完整落在容器内；下方内容以纵向滚动承载。 保留纵向空间，后续确认焦点滚入和键盘交替，不以缩字号追紧凑。 |
| [create-experience.png](evidence/round02-visual-accepted-snapshots/create-experience.png) | 93 | 名称/当地名称/一句话均为常驻短label，必填和可选可区分；照片/语音为辅助入口。 可继续把类别“隐藏”的含义解释为体验类型，避免与私密可见性联想；不是新增阻塞缺陷。 |
| [experience-detail.png](evidence/round02-visual-accepted-snapshots/experience-detail.png) | 93 | 标题和一句话优先，精选转轻文字、0笔记不抢hero；来源信息跟随内容，主CTA可扫描。 在完整长文/小屏大字继续验证元数据的阅读节奏和按钮间距。 |
| [paywall.png](evidence/round02-visual-correction-snapshots/paywall.png) | 95 | 空商品说明真实，重试加载方案是单一主动作，关闭和继续免费可见；中性条款不虚构试用。 此分只覆盖空catalog；真实价格/优惠卡和购买恢复状态未见，不迁移满分。 |
| [onboarding.png](evidence/round02-visual-accepted-snapshots/onboarding.png) | 94 | 实际方案步骤说明中性，查看Pro方案与继续免费分工清楚，不以固定免费周期诱导。 其余引导步骤和拒绝/接受条款路径仍需独立验收。 |
| [location-card.png](evidence/round02-visual-accepted-snapshots/location-card.png) | 94 | 地点、地址、时间、导航顺序清楚，单一复制地址有label，导航保持主动作。 实际系统地图/复制反馈未操作；保持这一主次关系。 |
| [chat-actual-status.png](evidence/round02-visual-accepted-snapshots/chat-actual-status.png) | 93 | 真实挂载AgentStatusLine和SummaryChip的文本主次清楚，状态与可展开摘要有分工。 只渲染真实组件，未运行完整流式生命周期；后续验证阶段切换与VoiceOver播报。 |
| [chat-route-proposal.png](evidence/round02-visual-correction-snapshots/chat-route-proposal.png) | 94 | hosting补图显示三站点和连接关系，站点44目标与独行元数据不争位；保存并查看与收藏名称符合真实行为。 实际点击收藏/保存失败恢复与持久回读仍需操作；本图不证明这些分支。 |
| [chatcard_route_proposal.png](evidence/round02-visual-correction-snapshots/chatcard_route_proposal.png) | 94 | 旧测试切换真实hosting后站点均可见；主次动作与路线信息层级稳定。 该组件capture不代表完整聊天页面留白；勿把捕获空白当产品布局缺陷。 |
| [chatcard_compiled_workday.png](evidence/round02-visual-correction-snapshots/chatcard_compiled_workday.png) | 92 | 工作日路线站点、刷新提示与备选信息可见；长时间表摘要省略仍需进入详情阅读。 在完整聊天上下文复核长时间表的必要信息是否优先；未知点击不补分。 |
| [create-route-form.png](evidence/round02-visual-accepted-snapshots/create-route-form.png) | 89 | 输入和生成主动作清楚，系统Form收束操作；长体验名截断且重复装饰图形分散少量注意力。 优先给已选体验两行名称/地点身份，收敛重复sparkles，保持选中状态可扫描。 |
| [route-detail-dock.png](evidence/round02-visual-correction-snapshots/route-detail-dock.png) | 92 | 站点顺序和底部开始路线明确，正文与Dock不重叠；hero视觉权重较高。 可降低hero与零社区统计的竞争，优先让路线标题/站点和下一步动作形成阅读序。 |
| [route-detail-dock-large.png](evidence/round02-visual-correction-snapshots/route-detail-dock-large.png) | 91 | AX3圆盘与字号同步扩大，01保持一行；标题自然换行，开始路线Dock完整。 保留大字号真实尺寸；长站点列表滚动、导航启动仍未知。 |
| [settings.png](evidence/round02-visual-accepted-snapshots/settings.png) | 91 | 分组和值的层级稳定，chevron/开关/滑块形式一致，未见截字；多色图标比内容更抢眼。 同一偏好组统一暖棕图标底是可选品牌优化；不改变系统控件的可辨性。 |
| [solo-score-badge.png](evidence/round02-visual-badge-snapshots/solo-score-badge.png) | 94 | compact纯黑字/星对亮绿清楚，full8.7深棕色与白底区分明确；数字层级稳定。 仅此8.7明色frame与compact全色域计算；popover/暗色/大字点击及所有文本仍未实测。 |
| [solo-score-radar.png](evidence/round02-visual-accepted-snapshots/solo-score-radar.png) | 90 | 等待真实hosting后雷达维度与非零分值可读，强/弱项说明可扫描。 后续在完整详情中减少图表与数值重复注意力，验证可访问解释与展开动作。 |
| [confidence-badge.png](evidence/round02-visual-accepted-snapshots/confidence-badge.png) | 85 | 完整状态文本可读；紧凑绿点单独出现时解释入口较弱，需页面语境。 紧凑形态可保留来源/解释符号并结合语境；不由小绿点暗示超出证据的验证强度。 |
| [filter-now.png](evidence/round02-visual-accepted-snapshots/filter-now.png) | 93 | 修正capture后字形完整，当前选中pill清楚，细分隔与单层底色克制。 横滑下一项部分露出是滚动提示，非确认裁切缺陷；真实横滑/键盘未测。 |
| [filter-coffee.png](evidence/round02-visual-accepted-snapshots/filter-coffee.png) | 93 | 咖啡选中语义可见，浅底/棕字和其余分类有明确主次。 完整地图和位置banner同屏大字组合尚未由本图验证。 |
| [filter-saved.png](evidence/round02-visual-accepted-snapshots/filter-saved.png) | 92 | 收藏选中与普通分类层次稳定，按钮字形完整。 后续确认收藏空态/结果切换焦点与真实触控。 |
| [chat-experience-card.png](evidence/round02-visual-accepted-snapshots/chat-experience-card.png) | 87 | 类别、标题、评分与箭头紧凑；长标题一行省略使后半体验身份丢失。 允许标题两行或缩短真实显示标题，避免箭头/评分压缩关键地点名。 |

## 最后三个视觉缺陷的关闭证据

| ID | 级别 | 已确认问题 | 当前修复与证据 |
| --- | --- | --- | --- |
| R2-42 | P2 / 已闭合 | AX5 compact 日期控件横向裁切 | TodayActionSheets:29–38 使用独立 label + graphical 日历，correction 的最大字号图完整，保持真实字号与纵向滚动。 |
| R2-43 | P2 / 已闭合 | AX3 固定圆盘内编号 01 拆行 | StopsList:101,133–147 采用 ScaledMetric 圆盘与单行编号；correction AX3 图中 01 完整、Dock 无重叠。 |
| R2-44 | P2 / 已闭合 | 评分白字/亮绿与绿字/白底低对比 | compact 全文字/星纯黑，full/popover 数字用 adaptive action tint；最后 badge 新图清楚。compact 全分数采样最低 4.8277:1，计算只认证该配色，不认证全 UI。 |

Paywall 加载失败弹窗已实际显示“方案加载失败”，与只加载的 Retry 行为一致；旧“购买未完成”不再误导。父代理实际 step7 → 查看方案 → 空商品 Retry 失败 → Close 回 step7；未触发购买或免费通关。真实 StoreKit 价格/优惠/购买/恢复仍未知。

## 正式验证与局限

1. 原生最终 build-for-testing exit0，最终633源文件及104改动文件哈希匹配。较早85项通过保留其当时源码边界；后续分别实际运行33项、6项受影响复跑、最后badge1项，均0失败/0跳过。运行有交集，不相加为唯一40项或全部原生测试。渲染测试不等于按钮点击验收。
2. Web release tsc/build exit0，8/8源文件匹配；accepted的63项测试通过，之后metadata-only改动再跑tsc/build。父代理320/390中英experience/trip无横溢、article目标44、View guide键盘focus、示例metadata单次品牌及地图5pin默认/zoom可见44与边缘命中已抽样。reviewer无法绑定父任务IAB，未假称亲自操作；本轮Web画面专家分保持未知。
3. 服务草稿14项Node、Supabase SDK严格检查和真实PG18身份/RLS允许拒绝验证已读回。未部署新Edge/迁移；远端跨账号、屏蔽和网络重试到原生的完整链路仍未知。
4. 公开法律Gist与源码入口已接通；不再缺URL/联系信息。App Store Connect线上配置、新二进制发布以及本轮所有原生法律入口点击未完成，不把旧URL问题继续算当前阻塞，也不声称发布完成。

正式凭证：[round02-visual-tests-result.json](evidence/round02-visual-tests-result.json), [round02-visual-correction-tests-result.json](evidence/round02-visual-correction-tests-result.json), [round02-visual-badge-tests-result.json](evidence/round02-visual-badge-tests-result.json), [round02-visual-badge-build-source.json](evidence/round02-visual-badge-build-source.json), [round02-final-source.json](evidence/round02-final-source.json), [round02-web-release-results.json](evidence/round02-web-release-results.json), [round02-web-browser-checks.json](evidence/round02-web-browser-checks.json), [round02-score-badge-contrast.json](evidence/round02-score-badge-contrast.json)。所有当前评分/每族未验收项见 [scorecard-round-02.json](scorecard-round-02.json)。

**当前结论：源码确认问题已闭合，限定画面可继续按上述具体建议推进；没有证据支持“每个按钮/功能均超过96”。**

<details>
<summary>历史诊断与逐轮工作记录（旧 open、旧分数、待运行描述均为当时检查点，不代表当前状态）</summary>


**当前：41项源码发现已独立回读闭合；已审生产范围无剩余确认P0/P1/P2。** R2-34/35付款与表单视觉调整待最新原生构建/新图。Web release版已独立读回8/8源hash、tsc/build成功、HTTP200单次品牌Sample trip标题；63项accepted测试正式存档，后续metadata-only差异另重跑tsc/build0。 最终已读回构建exit0、85项通过/0失败/0跳过；包含此前失败的删除恢复与日期测试。638原生源文件和94项本轮差异hash在独立读回时全匹配；这些绿灯不自动覆盖随后付款/视觉补改。

973静态候选（iOS863/Web110）、220 UI文件、44功能族不是973个独立按钮。18张新PNG已全部看过：13张可给限定上下文专家分，5张因组件初始动画帧或测试裁切不宜评分。17个渲染测试只证明输出图片，不等于所有按钮点击通过。每项>96目标仍未达到；下面的数字仅是列出画面的专家判断，不等于整族总分或用户满意度。

| 当前功能族 | 当前源码状态 | 可见画面专家分 /100 | 剩余验收 |
| --- | --- | --- | --- |
| I01 地图主场景/城市 | 已报问题源码闭合 | 未知/新图待到 | 本轮城市chip/筛选44目标、地图大字与定位拒绝恢复；旧04b图不作新版分数。 |
| I02 稳定导航/发现 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮地图/问问/发现切换保留、Dock大字与选中语义。 |
| I03 探索工作流 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮探索取消/阶段切换与网络降级、离开后任务停止。 |
| I04 保留对话/历史 | 已报问题源码闭合 | 未知/新图待到 | 聊天route收藏/主采用真实ack、44站点与保存并查看文案已source复核；新build/render和实际失败恢复/回读待验。；确认/失败保留与大字输入区渲染。 |
| I05 对话输入/附件 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮部分成功失败附件单独重试、晚到新附件/草稿保留与键盘布局。 |
| I06 语音 | 已报问题源码闭合 | 未知/新图待到 | 受影响Voice生命周期测试实际执行；授权晚回、松手、关闭、前后台与VoiceOver真实操作。 |
| I07 AI 卡片/撤销/诊断 | 已报问题源码闭合 | 未知/新图待到 | 聊天route收藏/主采用真实ack、44站点与保存并查看文案已source复核；新build/render和实际失败恢复/回读待验。；本轮诊断/撤销/pending状态大字与VoiceOver操作窗口。 |
| I08 体验卡/预览 | 已核对范围无新增确认缺陷 | 87（仅列出画面） | 本轮卡片与内部收藏/评分解释44目标互不竞争、长标题布局。 |
| I09 体验详情主动作 | 已报问题源码闭合 | 未知/新图待到 | 本轮导航/最佳时间44目标与大字；本机笔记文案和来源解释实际可读。 |
| I10 体验新增/修正/反馈 | 已报问题源码闭合 | 未知/新图待到 | 真实PhotosPicker慢解码/取消/失败skip及磁盘失败重试；笔记真实save失败保留。 |
| I11 体验分享/导出 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮图像/Markdown生成失败Retry、风格切换晚回与实际分享产物。 |
| I12 行程列表/创建 | 已报问题源码闭合 | 未知/新图待到 | 创建保存与取消/名称城市日期大字。 |
| I13 行程详情 | 已报问题源码闭合 | 未知/新图待到 | 发布/撤下/重排/导入收藏失败恢复与全部已加入入口隐藏。 |
| I14 路线创建/详情 | 已报问题源码闭合 | 未知/新图待到 | 聊天route收藏/主采用真实ack、44站点与保存并查看文案已source复核；新build/render和实际失败恢复/回读待验。；Completion/真实导航UI仍待操作；各入口导航、生成晚回、批量失败Retry与RouteDock大字；本机添加不宣称远端邀请。 |
| I15 路线招募/申请 | 已报问题源码闭合 | 未知/新图待到 | 负/正时区/DST日期往返、审批容量/原子存储与同城空态城市手递UI。 |
| I16 同伴发现/安全 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 新companion-post-action尚未部署，真实Supabase跨账号/RLS/屏蔽/重试集成未知；本轮原生申请/举报/封禁UI。 |
| I17 同伴资料/消息 | 已报问题源码闭合 | 未知/新图待到 | 本轮已编辑身份读回、群聊可用门槛、Completion失败重试和只预填邀请草稿。 |
| I18 路线分享 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮各分享style生成/缓存切换与错误Retry、真实导出结果。 |
| I19 好友入口/邀请/扫码 | 已报问题源码闭合 | 未知/新图待到 | 失效/满员/非法状态、现有group失败恢复、扫码权限与离开停止。 |
| I20 我的/权益 | 已报问题源码闭合 | 未知/新图待到 | 本轮个人资料保存回读、未知trial进度隐藏、权益文案大字。 |
| I21 设置及子页 | 已核对范围无新增确认缺陷 | 91（仅列出画面） | 本轮分类selected/错误恢复及实际隐私/条款链接打开；未挂载子页不作为当前已完成流程。 |
| I22 首次使用/条款 | 已报问题源码闭合 | 未知/新图待到 | R2-34/35新方案入口与真实优惠中性文案已source读回，待重新build及Paywall/Onboarding图和实际失败恢复。；公开政策Gist目的地已验证；新二进制接受/拒绝/重读、44pt全文链接实际点击及大字。 |
| I23 付费 | 已报问题源码闭合 | 未知/新图待到 | 最新空catalogLoading/disabled、Retry仅加载、free/close44、地图真实NavigationStack已源码读回；待新build/图及实际catalog错误恢复/真实StoreKit价格购买恢复。 |
| I24 今日/城市工具 | 已报问题源码闭合 | 未知/新图待到 | Kit整行44+chevron、表单常驻label和arrivalday=1说明已源码核对；待统一新图、真实填值保存回读/提醒重排与VoiceOver/键盘。 |
| I25 仪式/归档 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 按当前只读记录/预览评价；本轮正文日期可读、Close及日期入口；原未接通仪式能力不冒称完成。 |
| I26 管理/共享反馈组件 | 已报问题源码闭合 | 未知/新图待到 | 本轮多个CTA独立VoiceOver可达、Undo/提示操作中不消失与最大字号。 |
| I27 信任解释/独行评分 | 已报问题源码闭合 | 85（仅列出画面） | 本轮44评分badge、雷达维度语义/ReduceMotion与低样本来源文案实际可读。 |
| W01 官网 EN/ZH 导航 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮320px中英菜单/语言/下载焦点抽样；上一轮操作证据保留历史。 |
| W02 官网 Hero/功能/信任/页脚 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮首页明暗/窄屏/减少动态渲染；Hero图案、功能示意与正文层级专家评价。 |
| W03 定价 EN/ZH | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮方案按钮实际去向和窄屏表格；真实Store商品权益仍以运行商店数据为准。 |
| W04 宣言 EN/ZH | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮中英文章行长/返回路径与当前声明抽样。 |
| W05 隐私 EN/ZH | 已核对范围无新增确认缺陷 | 未知/新图待到 | 公开Gist目的地已验证；本轮网页摘要到全文/联系的实际点击。 |
| W06 下载 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮当前环境真实Web/Store/TestFlight分发动作与说明抽样。 |
| W07 共享 Web 控件 | 已报问题源码闭合 | 未知/新图待到 | 新global-error重试/回地图及URL语言优先实际故障注入；共享focus/busy状态抽样。 |
| W08 /app 地图 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮无token/引擎错误到列表、地理权限、地图重新建立生命周期抽样。 |
| W09 /app 附近和足迹 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮peek/half/full手柄键盘/拖动与选中详情后状态；整族未全量运行。 |
| W10 /app 今日 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮今日建议到对应真实详情/关闭后的地图遮挡抽样。 |
| W11 /app 语音/文本意图 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮录音授权晚回、隐藏/后台停止、文字草稿保留及44px清除动作抽样。 |
| W12 /app 体验详情 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮评分保存失败保留与Retry、关闭返回焦点和长文小屏抽样。 |
| W13 /[city] 城市工作台 | 已报问题源码闭合 | 未知/新图待到 | 320 default/zoom5pin intersection44和centre/edge命中及A Vida详情已父代理抽样；剩键盘marker focus/selected及其余城市/状态组合，不冒充全量通过。 |
| W14 城市命令面板 | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮Tab后Enter作用域、选中结果/Esc恢复焦点抽样。 |
| W15 /mobile-preview | 已核对范围无新增确认缺陷 | 未知/新图待到 | 本轮演示说明、初始空打卡、刷新清空边界与示意marker语义抽样。 |
| W16 /experience/[id] 分享体验 | 已报问题源码闭合 | 未知/新图待到 | 320/390中英无横溢、article44目标和英文View guide Tab/focus已父代理抽样；剩附近体验/返回组合和200%缩放。 |
| W17 /trip/[slug] 分享行程 | 已报问题源码闭合 | 未知/新图待到 | HTTP200单次品牌Sample trip title/示例description已正式读回；320/390中英无横溢和44目标父代理通过。实际Share未观察完成/复制结果，200%zoom未测。 |

## 本轮画面判断与可执行修正（付款/表单后续前）

| 可见画面 | 专家分 | 确认的观感与下一步 |
| --- | --- | --- |
| kit-without-city-data.png | 91 | 单卡入口清楚，棕色主动作与中性白卡层级稳定，无可见遮挡。 入口加chevron说明打开表单；不为填满空态增加无业务内容。 |
| kit-without-city-data-large.png | 89 | accessibility3标题和CTA均完整，保留了可读字大与容器适应。 整行入口与chevron适应换行；不压小用户字号换取紧凑。 |
| personal-countdown-form.png | 87 | 日期/输入/说明顺序清楚，保存禁用状态可辨；停留天数仅placeholder。 常驻label停留天数+数值prompt例如30+单位天，避免输入后丢失字段身份。 |
| experience-detail.png | 89 | 体验叙事与单一大CTA清楚；首屏精选pill、分类、本机0笔记、验证状态占据标题前层级。 精选改轻文字、0笔记不占hero；收藏/去过未选标签保持可点击而非disabled观感。 |
| create-experience.png | 86 | 系统Form分组与保存门槛清楚；三个placeholder承担字段身份，类别隐藏易混淆可见性。 名称/当地名称/一句话配常驻短label；hidden分类采用明确小众体验术语，照片与语音为辅助。 |
| settings.png | 91 | 分组、值、chevron/开关/滑块类型一致，未见截字/遮挡；多色icon较吸睛。 偏好同组可统一暖棕icon底以降低竞争；保持系统控件和持久值可扫描。 |
| paywall.png | 78 | 无价格/商品卡状态仍显示免费7天，源追踪确认为未核实承诺；本图为补修前。 先修真实offer和失败恢复，再渲染新图；商品未返回时解释可重试状态。 |
| onboarding.png | 88 | 地图符号、标题、主CTA统一，留白有明确阅读中心；跳过与先逛逛两个次级逃生动作竞争。 保留一处明确跳过语义或区分此步稍后与跳过全流程；次级动作提高可读度。 |
| chat-experience-card.png | 87 | 类别图标、标题、评分和箭头结构紧凑；长体验标题被截到失去后半动作地点。 允许标题两行或缩短真实显示标题；仅一层轻边界，来源/类别文字次于体验标题。 |
| chat-route-proposal.png | 88 | 路线名/站点/时长/主次CTA清楚；泛称打开与多层高亮/阴影增加解释成本。 打开改查看路线；黄色提示只保留浅底，去内shadow/额外描边；站点图标去光晕。 |
| chat-reasoning-trace.png | 82 | 状态行可读但省略号/gear/emoji放大镜/灯泡混用，金灰多层竞争；本卡不含主动作。 统一状态列；仅当前步骤用主色，完成/待开始用次级；别把样本分析文案当真实API已经完成。 |
| confidence-badge.png | 85 | 完整状态文本可读，compact仅绿点的点击含义弱；小字号与灰字需要上下文。 紧凑形态保留可理解来源符号/说明入口，保持真实44目标；不是凭绿点承诺验证强度。 |
| location-card.png | 89 | 地点/地址/步行时间/导航顺序清楚；地址内copy和导航旁copy重复注意力。 保留一处复制地址并明确label；导航仍唯一实心主CTA。 |

评分说明：点击项只评价画面中的可识别性与主次动作，不声称真实命中区/触感/键盘/VoiceOver已经操作；边框判断主要看是否有清楚分组与重复注意力。Kit大字未见遮挡，不为追分压小字号或填满留白。设置同组图标统一色只是品牌取向建议，不是功能失败。

不评分的5张：solo-score-badge、solo-score-radar来自ImageRenderer，初始animatedScore/drawProgress未等待onAppear，不把0当生产评分；三个filter固定crop截到字形下缘，不把测试裁切认定为真实页面裁切。这5张未贡献视觉通过数。

## 新付款入口缺陷（后续源码已闭合）

- **R2-34 / P1**：paywall.png在商品/资格未确定状态显示“免费7天”，源码默认fineprint分支确实读取此文案。主Paywall新修已改真实offer+资格guard和中性说明；但Onboarding实际step7仍调用1个月/30天旧键，不能因资源名称旧而当作未挂载。已同步实际Onboarding入口，CTA只打开统一方案sheet；真实offer存在+资格确证后仅称优惠可用，具体周期不再硬编码。
- **R2-35 / P1**：OnboardingView.runOnboardingPurchase无产品直接finish，purchase成功/取消/失败均finish。用户明确稍后可完成引导；订阅失败应留页给真实错误与Retry。最新源修已删除直接purchase/false finish：只有onUnlocked或明确免费/跳过才完成；主Paywall无商品转error，取消/失败保留页面。未做购买操作，关闭结论来自实际调用链，新build/图待到。

85项验证明确分为68项逻辑测试和17项直接渲染检查。删除恢复、CivilDay、Invite持久化、报告草稿、照片batch与生成guard的受影响测试已通过；实际PhotosPicker解码、Mail发送、付款、权限晚回与全部导航仍未由这85项证明。服务端14项Node/SDK严格检查和PG18身份/RLS允许拒绝证据保持有效，远端尚未部署。

付款/表单后续源已独立读回，35项已闭合；paywall/onboarding/倒计时旧图分数仅为修前定位，不作为当前已评分。当前JSON以每族currentSourceAssessment为准；旧functionalQuality数值与逐轮open均保留在以下历史记录，禁止当成修复后当前分。allItemsAboveTarget=false。

## 最新原生可用性小批源码确认

已回读Kit整行44+chevron、Today常驻天数字段与arrivalday=1说明（与diff+1计算一致）；Paywall初始Loading禁用CTA、空catalog Retry只加载后return、free/close44；地图真实sheet与UIAudit都包NavigationStack，保留同一环境与解锁resume。Invite持久成功后只有haptic/关闭，已移除host本机错收件人邀请通知。本批无新增确认P0/P1/P2。

filter裁切190及score改UIHosting+settle1.2是捕获方式修复，不能先当新PNG已稳定。原生全部视觉后续待统一build/source manifest和新图；不把旧85通过冒充新源码验收。

## Web accepted版证据边界

已独立读取宿主accepted-results与3份正式待复制日志：8源文件hash全匹配，tsc exit0，Vitest10文件63项通过，Next15.5.27完成编译/类型/20静态页/trace。父代理实际320/390中英experience/trip无横溢、article目标>=44，英文View guide经Tab滚入并显示2px focus；320默认/zoom的5个marker可见交集均44，centre及四边2px elementFromPoint均命中，A Vida打开正确详情。只按这些明确抽样记parent-observed E3。

子agent独立CUA不暴露父任务IAB（绑定tab7与browser3均不可用，inventory仅Chrome extension id1）；没有新开浏览器/切Chrome或假称亲自操作。后续可用父代理同状态截图独立评价品味；当前Web视觉专家分保持未知。

## Web地图与示例边界增量复核（两项P2后续源码已闭合）

projectIllustratedPin的数学投影与SVG的xMidYMid slice一致；observer有清理，装饰SVG隐藏于AX，交互改HTML按钮后原生键盘/选中语义保留。5个几何测试只读源码，未作为DOM点击证据。城市示例声明、指南提示、trip正文首屏示例作者/统计、experience时段+停留/中文crowd均与现有数据对应，未引入新动作断路。

- **R2-36 / P2**：44按钮仍以中心定位，父overflow:hidden在边缘把真实可点面积裁至小于44；BCR保持44不能证明可见命中面积。目标整框需约束容器内，保持pin落在目标内，并防焦点外环裁切。
- **R2-37 / P2**：trip正文已标示示例，generateMetadata却仍用trip.intro和trip.author生成真实署名感的分享预览。metadata也需同一示例边界。

R2-36最新修复已读回：去translate并将44目标整框clamp在容器，<44容器不渲染，focus内描边。R2-37最新修复以sampleTripIntro共用正文/metadata，title明确行程示例；两项源码闭合。Paywall另补空catalog说明与Retry，重试成功只显示加载的价格并return，下一次明确订阅才走purchase，失败真实error且DEBUG不伪解锁。

本批Web正式release8/8源hash、tsc/build0，accepted63tests已读回；HTTP200读到单次品牌Sample trip title/示例description。320/390实际zoom、edge intersection、elementFromPoint和focus由父代理抽样完成，详情与未测项见正式browser-checks.json，不把局部测试写为全量通过。只复核指定增量，不扩张其他审查。

## Pi视觉导入：四项真实聊天路线问题已由root源码闭合

Pi任务20261016-130229-edce92c4因时限退出，未声称验证通过。5UI与集成当前文件逐字一致后独立审查，未运行构建或测试：

| ID | 优先级 | 确认来源与必修契约 |
| --- | --- | --- |
| R2-38 | P2 | ChatCardViews:382站点label28×44；改44×44并为多站点给横滑/换行，不压缩热区。 |
| R2-39 | P1 | ChatCardViews:413–415收藏只有saved=true和成功触觉；接真实持久值/ack及错误恢复，不能重建即丢。 |
| R2-40 | P1 | ChatSheet:1757–1759先退出，CompassMap:2994非throw save失败仍开详情；真实savePersisted确认后才离开，失败保留卡和Retry。 |
| R2-41 | P2 | 主CTA查看路线实际持久化；明确保存并查看，或改真正不写入的预览，保持名称和行为一致。 |

四项最新root修复已回读：收藏由preferences持久值驱动，缺route先try savePersisted再收藏，失败留卡alert；主CTA同样durable ack之后才onAdopt/退出，地图host不再重复非throw save；中英明确保存并查看路线；各站点44×44横滑，metadata独行。生产当前无新增确认P0/P1。实际AgentStatusLine/summary已补reduceMotion、44与换行，并新增真实组件渲染fixture。

验证接线已源码关闭：旧ChatCardRenderVisualTest helper已补UserPreferences和内存modelContainer，输出改走UI_AUDIT_OUTPUT_DIR；尚未收到该类最终运行结果，不计通过。父代理将补增量build并仅跑受影响33项，之后提供26PNG；旧85结果不覆盖这批。

工具状态顺序有证据：Orchestrator:837–864串行append.tool→await execute→追加结果/下一工具；可证前一个工具已返回，不能证成功。末尾tool无insight也可能已返回。更关键ReasoningTracePanel仅测试调用，生产ChatSheet:626用AgentStatusLine；此前82分只对未挂载测试组件成立，现已从I07当前分撤出。新图应覆盖实际AgentStatusLine/ReasoningSummaryChip，不能把测试组件改好当线上状态改善。

创建字段常驻label、详情标题优先/零笔记不占hero、地点单一copy标签均是有源码依据的正向调整，照片busy/generation与写失败恢复保留；新大字布局和真实命中仍待新图/操作。

<details>
<summary>历史诊断与逐轮复核记录（旧open和数值不是当前评分）</summary>

> **当前：33项及最后3个P2后续已独立回读源码闭合；已审范围没有剩余确认P0/P1/P2。** 下文旧open与分数表为历史检查点，不作当前缺陷或最终评分。原生86项实际进入、出现7条失败，修复后复跑与最终增量构建结果仍待到；build5不能覆盖最新改动。未将源码闭合换算为视觉/动态96分。

基线提交：`efcb8fc523f59c8333b010c9bc710d8d5b2e4559`；snapshot-05-legal（109文件已验证，补丁SHA b84add54d199b027b0ac6ab669ffca94c7921c6abea81e087023a6a697075592）；当前盘点918候选、44功能族（iOS27/Web17）。本轮进行中；累计32项UI源码发现（12 P1/20 P2），服务草稿4项已源码修复。旧报告保留历史，当前活跃修改与05基线/旧测试分开，详见末节。

使用 frontend-design：旅行体验与地图是视觉主体，一屏保留清楚主动作；边框用于分组/焦点/状态，不用虚假CTA制造注意力；动效解释用户操作。功能按当前声明评价：View guide就按指南入口评分，诚实只读就按阅读/关闭评分；历史业务范围变化单独记录，不冒充未实现业务已完成。

96是内部专家设计目标，不是96%用户满意度，不需要凭空E4。功能可执行性、可访问性与流程恢复的证据和美感/品味的渲染判断分开。源码确认缺陷不是“因未测试扣分”；没有渲染的品味维度保持未知，而非默认满分。实施者负责源码和验证，reviewer只改本报告与scorecard-round-02.json，不构建或运行UI。

## 第一批：iOS路线与内容创建

| ID | 优先级/状态 | 功能族 | 精确来源（Swift视图相对Views/） | 确认问题与影响 | 实现/验收契约 |
| --- | --- | --- | --- | --- | --- |
| R2-01 | P1 / open | I14 | `RouteDetailView.swift:521–558` | 收藏和加入行程只切换@State，显示成功状态却不保存。再次进入状态丢失，“Save to my itinerary”没有选择/写入行程。 | 使用真实收藏/行程存储或呈现已有行程选择；写入失败保持原状态并说明；重开读回。 |
| R2-02 | P1 / open | I14,I17 | `RouteDetailView.swift:503–511` | closed/completed分支显示进入群聊，closed action为空；completed host播完成庆祝。可点击主动作无结果或结果与名称相反。 | 按真实conversationID打开对话；不存在时明确不可用与恢复动作；庆祝必须独立命名。 |
| R2-03 | P1 / open | I14,I15,I17 | `RouteDetailView.swift:40–48,462–472; ChatView.swift:129; MyWalkedRoutesListView.swift:25; MyRequestsListView.swift:138; DiscoverRecruitingRoutesView.swift:72` | 非地图入口采用默认空的stop/start回调，开始后还dismiss。同一按钮在地图能工作，在消息/申请/走过列表断路；站点点击无结果。 | 要求必填真实导航回调或在详情内部实现统一路由；缺能力时隐藏/说明，不能默认空action。各实际入口验收。 |
| R2-04 | P1 / open | I14,I15 | `DiscoverRecruitingRoutesView.swift:48–54,106–108` | 无招募路线时创建按钮打开candidates=[]且onSave为空的表单。空态唯一恢复路径的选站/AI/保存均不可完成。 | 传入真实同城候选及save handler，或转到真实地图选站；空候选时给可执行返回探索/选城市路径。 |
| R2-05 | P2 / open | I14 | `StopsList.swift:28–36` | 站点仅onTapGesture，没有Button或accessibilityAction。源码未提供按钮语义，站点发现/激活预期不一致；运行VoiceOver能否触发gesture未实测。 | 用Button标签承载编号、标题、路段信息和44pt目标；执行真实stop导航。 |
| R2-06 | P2 / open | I14,I23 | `RouteDetailView.swift:367–407; en.lproj/Localizable.strings:1647–1648` | 订阅Pro天气/人流/季节分析和Unlock→是Text，没有按钮且未判断权益。视觉制造付费入口，点击无结果；能力与真实实现未对应。 | 仅接实际可用分析/真实Paywall并按权益呈现；否则诚实描述暂不可用，移除假CTA/未经支持的功能承诺。 |
| R2-07 | P2 / open | I14 | `CreateRouteView.swift:105,135–136,276,330–344` | AI生成期间仍可选站和保存，晚结果无编辑版本校验直接覆盖selectedIds/pace。慢响应覆盖用户新选站/顺序；可在忙碌时保存旧草稿且AI请求继续。 | 生成任务有单一所有者/取消；结果只应用于同一草稿版本，或显式预览后采用；保存有明确忙碌策略。 |
| R2-08 | P2 / open | I13 | `ItineraryDetailView.swift:354–401` | 发布/撤下/重排先改变UI和preferences，再try?吞store错误。写入失败仍成功触感/新顺序，重进后恢复旧值；无可执行重试。 | 写入成功后提交UI，失败回滚并保留草稿/顺序、显示重试。 |
| R2-09 | P2 / open | I10 | `TravelerNotesSection.swift:351–387` | 笔记mood chip约24pt，发送明确30×30pt；mood无selected语义。小目标容易误触，读屏不能判断选中了哪些心情。 | 视觉尺寸可保留，标签内44pt命中区；selected/value/清楚提交反馈。 |
| R2-10 | P2 / open | I10 | `CreateExperienceSheet.swift:245–261; Services/PlacePhotoStore.swift:33–51` | 照片写入失败被compactMap丢弃，仍保存并dismiss。用户提交的部分/全部照片可能静默丢失，无法知道是哪张失败或重试。 | 返回每张写入结果；有失败保留表单和原图，明确重试/用户选择不带失败照片保存；成功后才dismiss。 |
| R2-11 | P2 / open | I14 | `Services/AIService.swift:306–340; CreateRouteView.swift:340–344,367` | AI调用失败返回本地fallback仍标aiGenerated，UI又据非空summary标coCreated，外层错误banner通常不触发。本地可用降级值得保留，但用户被误导为模型已完成生成。 | 显式返回/展示local fallback原因和来源；保留本地方案、给可执行重试，不将本地排序标AI成功。 |

源码省略前缀均为 apps/ios/SoloCompass/，视图在Views/Companion或Views/Experience；同名文件以inventory对应路径为准。后续分族评分与渲染证据继续补充，不将初批清单声称为全量分支已验收。


## 第二批：权限生命周期、日期、付费前置及窄屏

| ID | 优先级/状态 | 功能族 | 精确来源 | 确认问题与影响 | 实现/验收契约 |
| --- | --- | --- | --- | --- | --- |
| R2-12 | P1 / open | I06,I10 | `Views/Shared/VoiceButton.swift:97–140,238–263; Views/Map/CompassMapView.swift:1382,2005–2009,2077–2092; ViewModels/MapViewModel.swift:2484–2487` | 权限Task无所有权/晚回守卫，松手时未recording就return；授权随后成功仍startListening；组件无消失/后台清理。首次授权/快速松手/下拉sheet后仍可能采集，违背当前按住说话的可见生命周期。 | 保存并取消权限/stream/timer任务；按压/可见/前台session token共同允许启动。离开/后台/取消停止且不自动提交，默认AX activation与提示一致。验证延迟授权、松手、关闭、后台及晚回。 |
| R2-13 | P1 / open | I15 | `Views/Companion/OpenForCompanionsSheet.swift:35–43,190–200,246–250` | 日期仅字符串按UTC午夜解析，DatePicker和提交格式化却用设备日历/时区。UTC负偏移设备不编辑也可把2026-10-16提交为15号，出发日期错误。 | date-only采用一致的年月日日历语义/既定行程时区；HH:mm与日期分开。测试UTC负偏移、正偏移、DST和往返不变，勿改geo/time跨端schema。 |
| R2-14 | P2 / open | I20,I23 | `Views/Me/EntitlementBanner.swift:45–51,109–118,166–175; Resources/en.lproj:865; zh-Hans.lproj:534` | free/expired直接显示免费1个月，没有读取该账号实际intro eligibility；试用进度固定30天。付费页已谨慎查询资格，但前置入口仍误承诺；非30天offer进度失真。 | 未知资格用查看Pro等中性文案，只有实际产品/资格确证才称试用；进度取已验证试用起止/实际周期，无数据不画假进度。 |
| R2-15 | P2 / open | I01,I09,I24,I26,I27 | `Views/Map/CityPickerSheet.swift:274–305; Experience/ExperienceDetailView.swift:942–954,1061–1075; CityOS/KitSheet.swift:186–211,249–267; CityOS/ComplianceBanner.swift:25–41; Shared/PendingCheckInBanner.swift:113–126; Shared/SoloScoreBadge.swift:78–85` | 若干真实独立控件仍无44pt标签命中面：最近城市chip/导航与最佳时间/待办26pt/工具链接/提示关闭28pt/评分badge。小目标与邻近点击竞争，整屏控件热区不一致。这里未把装饰图标或已扩展44的ChatSheet/Verify close错判。 | 保留小视觉，标签内minWidth/minHeight44+contentShape；不重叠邻项；布局自适应大字；逐控件真实AX frame与边缘点击。 |
| R2-16 | P2 / open | I24,I26 | `Views/Shared/PendingCheckInBanner.swift:204–208,217–220,251–267; Views/CityOS/ComplianceBanner.swift:25–55` | 确认/关闭或处理/关闭的多按钮容器用children.combine；Pending提示VO仍12秒自动消失，仅拖拽暂停。辅助操作的独立发现与恢复弱；听说明时提示可能消失。未声称已运行VoiceOver复现。 | 交互容器contain，说明组合但按钮分开；VoiceOver焦点/操作期间暂停或采用统一足够长且可重读的窗口，不只拖拽暂停。 |
| R2-17 | P2 / open | I17,I20 | `Views/Me/MeSheet.swift:248–253,270,307–323; Views/Companion/CompanionProfileView.swift:101,117,157–163` | 个人页头像/name仍取sample或固定Solo Traveler；编辑页保存preferences后头部不读这些值。用户修改资料再返回仍看到默认身份，反馈断裂。 | 头部读取同一已保存displayHandle/companionAvatarEmoji；空值才用默认，AX与可见名字一致；保存→返回→重开验证。 |
| R2-18 | P1 / source_fixed（Pi树未导入） | W16 | `apps/web/src/app/experience/[id]/page.tsx:160–183,308–311,474–512` | 320px下固定56px左右padding、1fr+240px列和36gap，外层overflow hidden；没有响应式覆盖。外层仅约272px，正文仅约160px，却要求240px侧栏和36px间距，必定挤出/裁切正文和CTA。 | 手机改单列并缩窄padding，宽屏保留文章+facts；所有导航/指南动作44px。验320/390中英、200%缩放、键盘焦点不被裁切。 |
| R2-19 | P2 / source_fixed（Pi树未导入） | W17 | `apps/web/src/app/trip/[slug]/page.tsx:138–188,299–327,414–465` | 固定56px内边距、60/1fr/80行、顶栏不换行；主CTA称想做自己的/compass.io但仅进城市指南。小屏挤压，标签不是所执行动作；这是当前CTA错配，不因指南未实现个人计划而扣指南设计分。 | 窄屏改堆叠/弹性网格、可折行、44目标；按钮直接叫查看城市指南并使用Solo Compass品牌，避免伪浏览器地址。 |
| R2-20 | P2 / source_fixed（root树） | W07 | `apps/web/src/app/global-error.tsx:7–22` | 全局错误边界只渲染NextError，不接reset或提供回地图动作。失败时没有产品内清楚恢复路径。 | 提供独立于应用失败依赖的轻量fallback、重试reset和回首页/地图；保留诊断但不向用户暴露实现栈。 |
| R2-21 | P2 / open | I04 | `Views/Chat/ChatHistoryListView.swift:52–62 and deleteRows` | 历史列表onDelete直接删除，没有确认或撤销路径。完整会话的破坏性动作缺恢复，滑动误触代价高。 | 全滑删除提供撤销或先确认，保留当前活跃会话/删除失败可恢复；不强加每条低风险编辑确认。 |

R2-05限定为源码按钮语义缺失，未运行VoiceOver，不预先声称双击必定失败。NotificationsSettingsView虽有初值true，但onAppear实际读取scheduler，故未误报开关重置；该页目前只见Preview调用，不把未挂载代码当用户当前按钮。Archive里disabled的空回调在“只读记录/预览”契约下不再按假完成动作报告；历史业务仍未接通另列。


## 全部44功能族的本轮可比评分与推进建议

数字是当前声明功能的源码质量区间，来自05证据的可复核维度并加入本轮确认缺陷；不是未观察即得满分。W13/W16的指南、I25的诚实预览/只读，已撤销上一轮因原业务缩减而加的罚分；历史原功能未完成仍在JSON单独保留，不声称实现完成。视觉专家分仅对已看的04b两张具体E2画面给出，不要求凭空用户实验，也不把功能区间当审美分。

| 功能族 | 当前功能区间 /100 | 视觉专家分（仅指定画面） | 下一步具体改善 |
| --- | --- | --- | --- |
| W01 官网 EN/ZH 导航 | 85–100 | 待该族渲染 | 保留紧凑导航和真实分发去向；移动菜单打开后先呈现当前语言/页面，再是主CTA，减少页头描边与按钮竞争。 |
| W02 官网 Hero/功能/信任/页脚 | 85–100 | 待该族渲染 | 罗盘/路线路径是主题性记忆点；保留静态低对比底图，功能mock继续用清楚示意标签，不把每块都做成带边框卡片。 |
| W03 定价 EN/ZH | 72–100 | 待该族渲染 | 方案比较优先显示真实价格/周期/使用额度，次级FAQ减少长段营销话；按钮名称明确进入Web或查看实际商店方案。 |
| W04 宣言 EN/ZH | 72–100 | 待该族渲染 | 宣言保留可阅读文章节奏；绝对隐私/来源宣称需与实现一致，行动链接说明所到页面。中文摘要中“不追踪”的宽泛承诺应收窄到具体广告/分析边界。 |
| W05 隐私 EN/ZH | 72–100 | 待该族渲染 | 摘要页首屏完整政策链接、简洁处理清单与联系路径；长文行长控制，独立链接不堆多层边框。正式Gist已验证，不再作为缺口。 |
| W06 下载 | 72–100 | 待该族渲染 | 当前无iOS分发配置时以真实Web地图为唯一主动作；要求信息靠近CTA，不用占位商店logo暗示已上线。 |
| W07 共享 Web 控件 | 65–93 | 待该族渲染 | 通用控件统一focus/pressed/busy；全局错误给回到地图与retry，装饰Chip不伪装按钮。未挂载DesignNav不按当前用户动作评分。 |
| W08 /app 地图 | 64–100 | 待该族渲染 | 地图最大化内容区域，定位/缩放同一组工具；保留无token/引擎失败可用列表。真实token重建仍需行为验证，但不据未知判定失败。 |
| W09 /app 附近和足迹 | 72–100 | 待该族渲染 | 语义section与peek/half/full是正确结构；手柄聚焦时说明当前高度/切换结果，展开后让列表标题成为锚点，保持地图可操作。 |
| W10 /app 今日 | 64–100 | 待该族渲染 | 今日卡的主动作直接打开具体体验；score/distance只显示可证事实，关闭区域与整卡动作分离，内容不重复地图首条推荐。 |
| W11 /app 语音/文本意图 | 72–100 | 待该族渲染 | 保留始终可用文本，录音与提交的状态/结果各用一个清楚反馈；意图chip清除44px已实现，避免再加漂浮麦克风装饰。 |
| W12 /app 体验详情 | 64–100 | 待该族渲染 | 先选评分再提交、失败保留及Retry已改善；抽屉长文的来源区保持可扫描，与主签到动作分层。 |
| W13 /[city] 城市工作台 | 85–100 | 待该族渲染 | 当前按城市指南评分，实际选择/详情/分类组合清楚；不因没有个人计划创建扣指南自身。首屏优先标题/筛选/体验一条主轴。 |
| W14 城市命令面板 | 72–100 | 待该族渲染 | 模态内Tab/Esc/Enter作用域是已修基础；结果显示命中的城市/体验类型和选中位置，避免仅颜色体现active。 |
| W15 /mobile-preview | 85–100 | 待该族渲染 | 演示初始空记录/刷新清空边界合理；主动作和示意地图不能混淆，语言切换后说明仍可找到。 |
| W16 /experience/[id] 分享体验 | 54–90 | 待该族渲染 | 修手机文章/facts单列、padding和44px动作；按真实“城市指南”入口评价，不罚其没有个人计划功能。 |
| W17 /trip/[slug] 分享行程 | 57–93 | 待该族渲染 | 回顾文章窄屏用顺序阅读，站点网格改堆叠；去伪compass.io，CTA直接说查看城市指南，系统分享状态和文章分组分离。 |
| I01 地图主场景/城市 | 74–96 | 82 | 地图仍是视觉主体；城市身份在AXXXL/问问态可压为可换行紧凑一行，筛栏末端用弱渐隐说明可横滑；避免城市、筛选、诊断三层都争主注意力。 |
| I02 稳定导航/发现 | 77–100 | 84 | Dock当前选中项用形状和标签共同表达；吉祥物可保留品牌性，但不与输入麦克风抢主动作，选中底板随大字内容自适应。 |
| I03 探索工作流 | 72–100 | 待该族渲染 | 探索进度把当前阶段/取消置于稳定位置；计数和装饰动点作为次级，取消后明确回地图或保留已找到内容。 |
| I04 保留对话/历史 | 61–97 | 76 | AXXXL未配置卡把“设置”恢复动作放在说明之前/邻近标题，缩短重复技术长文；历史删除提供undo/确认，不给同一空态两层卡片边框。 |
| I05 对话输入/附件 | 85–100 | 83 | 输入、附件批次与单独失败重试各有明确所属；首屏保持输入不被提示挤出，当前暗色大字图已分离Dock但恢复CTA可见性仍弱。 |
| I06 语音 | 60–88 | 待该族渲染 | 按住录音必须严格跟随按压/可见前台生命周期；权限晚回不可启动旧会话；默认VoiceOver action与双击提示一致，纯状态动效遵守reduceMotion。 |
| I07 AI 卡片/撤销/诊断 | 85–100 | 待该族渲染 | 诊断说明/同意与撤销用独立真实动作；卡片边框只标状态/分组，pending/committed/failed避免多枚徽章同时抢注意。 |
| I08 体验卡/预览 | 64–100 | 待该族渲染 | 整张卡进入详情，内收藏/评分解释独立目标；一行主标题+一句体验说明优先于堆多个小badge，保持点击结果可预期。 |
| I09 体验详情主动作 | 57–92 | 待该族渲染 | 导航与最佳时间chip补44透明目标；主完成/加入行程/收藏围绕一条操作栏，体验正文与来源/独行评分分段，不把所有段落都做同权重卡片。 |
| I10 体验新增/修正/反馈 | 31–55 | 待该族渲染 | 照片落盘失败必须可恢复，mood选择/发送目标44且selected可读；字段只问必要内容，选择器加载完成前保存策略清楚。 |
| I11 体验分享/导出 | 72–100 | 待该族渲染 | 样式→预览→分享一条顺序；图像生成错误的Retry就地，复制/系统分享结果用短状态；Markdown预览不压缩到不可读。 |
| I12 行程列表/创建 | 57–93 | 待该族渲染 | 创建/编辑表单保持名称/城市/日期/备注层级；当前真实save后才回调值得保留；日期与取消的草稿策略一致。 |
| I13 行程详情 | 56–92 | 待该族渲染 | 行程发布/撤下/重排持久化失败要回滚/重试；重排是顺序概念，可用真实编号与连接线，移除仅装饰的拖动图案或给实际移动语义。 |
| I14 路线创建/详情 | 0–30 | 待该族渲染 | 路线详情先修所有假成功/空回调；站点是真实顺序而非装饰编号，创建页以已选路线预览+可调整顺序为主，AI作为辅助起点。 |
| I15 路线招募/申请 | 18–51 | 待该族渲染 | 招募日期采用稳定date-only语义，表单先解释何时/在哪/对谁可见；空态创建必须有候选和保存路径，申请与等待状态清晰。 |
| I16 同伴发现/安全 | 72–100 | 待该族渲染 | 发现详情显示状态/可行动作而非样本身份感；申请消息保留在失败原位，报告/封禁的结果和关系变化可读。 |
| I17 同伴资料/消息 | 29–65 | 待该族渲染 | 资料保存后头部立即读同一值；消息/路线/群聊路径一致；申请/邀请的“发送”与实际加入/待确认状态用词不能混。 |
| I18 路线分享 | 64–100 | 待该族渲染 | 分享样式选择44/selected与稳定task失效已修；预览大小/分享状态不过度抢内容，不用风格名替代实际产物名称。 |
| I19 好友入口/邀请/扫码 | 51–87 | 待该族渲染 | 输入码/扫码/复制保持一个明确主动作；错误就地带重试，扫码授权/隐藏停止规则保留；好友状态不要只靠小圆点。 |
| I20 我的/权益 | 54–90 | 待该族渲染 | 头部呈现已编辑身份、真实收藏/完成数；权益入口不再先承诺免费一个月，档案和仪式的阅读入口轻于主身份。 |
| I21 设置及子页 | 72–100 | 待该族渲染 | 危险删除按真实范围命名，分类选择按状态读回；AI设置只在用户配置时呈现技术名，别把开发选项当一般消费流程。未挂载通知页不计为当前入口。 |
| I22 首次使用/条款 | 64–100 | 待该族渲染 | 首次使用短摘要+可读全文+接受/拒绝/重读均能找到；已公开Gist不再扣缺URL分，后续只看实际点击/大字。 |
| I23 付费 | 60–88 | 待该族渲染 | 产品名称/价格/周期/已选语义已修；所有前置权益banner也须遵守真实资格，未知时显示中性查看，购买/恢复互斥保留。 |
| I24 今日/城市工具 | 54–82 | 待该族渲染 | 今日/基地/工具的主层级是当下下一步；待办与深链扩大目标，合规提示多按钮拆语义，少用固定小字胶囊层叠。 |
| I25 仪式/归档 | 72–100 | 待该族渲染 | 按“只读记录/预览”的真实声明评分，正文/日期/Close是有效任务；可将disabled分享/解锁动作改为静态说明以减少假操作注意力，不因原仪式没接通额外扣阅读入口。 |
| I26 管理/共享反馈组件 | 55–87 | 待该族渲染 | 反馈容器让各按钮独立可达；动态提示对VoiceOver/正在操作的人留够恢复时间，用户动作动效与背景永动分开。 |
| I27 信任解释/独行评分 | 14–92 | 待该族渲染 | 评分解释维持真实来源/低样本说明；compact badge仍是按钮须44，雷达用一处活动维度说明，避免每个badge都常驻闪动。 |


04b暗色AXXXL图中“设置”CTA只露出半行，这是可见的层级问题而非未测试；建议缩短未配置正文、将恢复动作放在标题之后优先可见、技术配置细节移入设置。明色地图图为合成诊断E2，只据画面评价层级，不假称运行中诊断流程已点击通过。

评分基线确认11项P1：R2-01/02/03/04/12/13/18/22/23/24/26；P2共17项，没有P0。实施中28项尚待冻结差异逐项关闭。44族已有数值与具体设计建议，918候选没有被冒充逐控件全状态运行通过；目标>96尚未认证。


## 附加服务端与原生接入草稿审查（尚未部署，不冒充05基线）

父代理新增companion-post-action以服务真实匿名帖子动作，并已在活跃树接入原生发现入口；尚未冻结、构建新原生或部署。下表保留首次发现与修复契约，当前源码关闭结论和证据边界见本节末。

| ID | 级别/状态 | 证据与问题 | 必要修复 |
| --- | --- | --- | --- |
| R2-S01 | P1 / source_fixed（active draft） | `infra/supabase/migrations/0003_companion.sql:167–176; companion-post-action/handler.ts:48–55; index.ts:33–51`：Edge检查真实post author、隐藏和双向block，但DB requester-insert仅检查auth.uid=requester_id，直接PostgREST可绕过recipient/post绑定与隐藏/block门槛，检查→写入也有TOCTOU。 若新Edge被视为隐私/屏蔽边界，恶意有JWT客户端可绕过该边界向已知目标直写请求。 | DB侧同等recipient=post.author、可接触性/双向屏蔽约束或窄RPC；用户RLS写保留，不增加泛service-role写。DB测试用真实auth UID证明直写绕过被拒、合法/accepted流正常。 |
| R2-S02 | P2 / source_fixed（active draft） | `infra/supabase/functions/companion-post-action/handler.ts:48–55; index.ts:38–48`：blocked/hidden/降权门槛先于已完成动作的幂等读回；第一次block写成功但响应丢失，重试被自己的block判404。 稳定actionID不能恢复已提交动作，用户看到失败却无法准确确认。 | 先安全确认caller-owned且同一post/目标的已完成动作，回包仅saved:true不泄漏隐藏身份；新动作仍走当前可接触性门槛。补丢回包后block/request重试、目标后来隐藏/被block等序列。 |
| R2-S03 | P2 / source_fixed（active draft） | `infra/supabase/functions/companion-post-action/index.ts:38–51`：查无existing→insert不是原子操作，同时相同ID重试第二个可唯一冲突并返回503，虽第一个已保存。 并发网络重试出现可避免的假失败；mock perform返回输入无法测试该实际路径。 | 唯一冲突时按RLS重读并校验owner/target/post及不可变操作语义，不能覆盖accepted/重复降权；增加实际adapter并发测试，DB层另验。 |

正向确认：caller通过auth.getUser解析；客户端伪recipient/requester被忽略；service-role仅解析post/profile/block，caller JWT负责RLS写；hidden/deleted/self/低权重/block共用404，查询异常fail closed；所有动作回包现已收敛saved:true，不泄漏request整行。0003中reports/blocks实际有self-select，未误判insert.select必败。[Supabase官方RLS说明](https://supabase.com/docs/guides/database/postgres/row-level-security)支持以数据库WITH CHECK约束可直接调用的数据API写入，单个Edge门槛不能代替该边界。首次6例仅覆盖handler mock；后续增加persistence adapter及PG18测试。当前比已读结果又有新增守卫，具体边界以本报告末尾关闭复核为准。


## 盘点交叉后的独立补核

已阅读ios-functions.md对应定位并独立追踪调用方，不把盘点条目直接当运行失败。I16匿名post动作的旧postId/userId问题正在由父代理的新服务草稿处理，当前活跃树不先行认证；以冻结diff再关闭。

| ID | 级别/状态 | 功能族 | 来源与确认问题 | 修复/验收 |
| --- | --- | --- | --- | --- |
| R2-22 | P1 / open | I10 | `Views/Experience/ExperienceDetailView.swift:259–262; ReportIssueSheet.swift:66–69`：反馈表单提交reason/detail被父级忽略，只关闭表单且子视图播成功触觉。用户填写的报告从未保存/上报，按钮承诺直接落空。 | 接已有真实上报/本地待同步路径并得到持久确认；失败保留reason/detail并重试；未支持则诚实说明，不能假提交。 |
| R2-23 | P1 / open | I14,I17 | `Views/Companion/CompletionMoment.swift:56–69,156–165`：一出现就庆祝已完成，异步markCompleted的未实现和所有错误被吞。未真正完成路线却庆祝成功；回放会再次尝试写状态。 | 完成动作与只读回放分开；真实完成写入成功才庆祝，错误/未实现可恢复，已有完成回放不得重复状态变更。 |
| R2-24 | P1 / open | I19 | `Services/FriendService.swift:598–602; Views/Friends/FriendsListView.swift:219–224`：移除好友忽略远端delete结果，删除本地并无条件成功播报。网络失败仍显示关系已解除，重新加载可复现好友关系，用户无法判断真实结果。 | 返回明确结果；成功才提交本地移除/播报，失败保留或回滚并显示重试；封禁也不能与移除结果混为成功。 |
| R2-25 | P2 / open | I15 | `Views/Companion/ApprovalQueueView.swift:300–310,451–461`：审批接受/拒绝远端错误直接return，无按钮进行中互斥或错误恢复。慢网可重复审批，失败如同点击无响应；本轮按恢复/反馈P2，必修。 | 锁定当前请求/动作，成功更新真实状态，失败保留申请/决定与错误说明并可重试；不把NotImplemented本地分支冒充远端完成。 |
| R2-26 | P1 / open | I14,I15 | `Persistence/RouteStore.swift:60–77; Views/Map/CompassMapView.swift:1491–1496; Views/Companion/OpenForCompanionsSheet.swift:239–241`：RouteStore.save落盘失败只assert，随后仍发didChange；调用方创建详情/招募成功触觉和关闭。用户认为路线已保存或已招募，实际失败没有恢复；Release断言不作为用户反馈。 | save返回可处理结果；提交成功后更新UI/通知，失败保留草稿并重试，避免delete-old/insert-new中间状态损坏；针对故障注入验证。 |
| R2-27 | P2 / open | I24 | `Views/Today/TodayContainer.swift:151,164; TodayStatusHeader.swift:34,129; TodaySealReceipt.swift:17,24`：Today开关路径填入境日/昨日瞬间依赖默认空回调，容器未传。启用该分支后可点入口无结果；默认地图分支不受此问题影响。 | 接真实日期/胶囊阅读目的地；启用前不展示假动作。保留feature flag门槛，不擅自开启。 |
| R2-28 | P2 / open | I12 | `Views/Companion/ItineraryListView.swift:101–132`：删除与撤销写入都try?吞错，仍移除列表/清撤销状态。失败与成功状态混淆；撤销失败丢失当前恢复入口。 | 持久结果决定列表/undo提交；失败保留undo payload/行并提示重试，VoiceOver窗口与其他提示统一。 |

R2-15/16另合并ActiveRouteOverlay:89–105的30pt圆按钮与多按钮combine，不重复造分。服务端R2-S01同时包含participant-update可被requester用于自我接受/换recipient/post的绕过；数据库约束必须覆盖真实状态机和不可变关系字段，不能只修Edge或INSERT。

截至本轮补核，评分基线UI清单28项（11 P1、17 P2）；矩阵已与JSON同步至28项。root新增服务/原生发现接入的4项发现均已有源码修复，新增路径没有未解决的源码确认P0/P1；这不关闭Pi待交付的28项UI缺陷，也不代表新增原生构建/部署/运行通过。


## 同行草稿本次关闭复核（active tree，等待新冻结证据）

- **R2-S01源码修复**：0017守卫在数据库侧验证post→author、可接触性、双向屏蔽；关系字段不可改、发送者不能自接受、terminal不能复活。新增UPDATE守卫在屏蔽后拒绝note联系和接受，仍允许withdraw/decline。没有要求把所有历史记录或安全退出一律禁止。
- **R2-S02/03源码修复**：先用caller JWT安全确认receipt，再检查新动作资格；23505重读并校验owner/target/post，不upsert覆盖已接受状态。回包只有saved:true，空PostgREST响应不算成功。
- **R2-S04（P2，源码修复）**：首次草稿异步发送期间可编辑、晚重试可将旧receipt误当新文字确认。SendRequest现禁提交中编辑；服务端逐字段比对标准化note/reason/details，冲突409不写。原生明确说明前次已保存、新文字未发送并保留草稿；不通过偷偷换actionId重复举报。DiscoverPostDetail原本已有disabled(!canAdd)，未将其重复误报为可在发送中编辑。

独立核对的正向路径：原生只发postId/actionId/payload，不把postId作userId；后台getUser验证caller，service-role只读post/profile/block，写入使用调用者JWT/RLS。失败原位保留说明/草稿，只有saved:true才呈现成功。当前未发现新增确认P1。

**证据边界**：已读先前11例Node与PG18正式日志。当前源码比该日志/manifest又增加intent409与block后UPDATE序列，须重新绑定结果后再认测试通过。新增原生service/sheet尚未构建、点击，真实Supabase迁移/Edge也未部署。当前完整源码SHA仅用于追踪在scorecard的serverDraftReview.sourceHashes，不与旧snapshot05或旧测试混用。


## 本机笔记与Today新增路径复核（active tree）

| ID | 级别/状态 | 功能族 | 来源/确认问题 | 修复契约 |
| --- | --- | --- | --- | --- |
| R2-29 | P1 / open | I10 | TravelerNotesSection:407–426仍忽略addNote返回nil，清草稿/心情并成功反馈；273–278先标confirmed再忽略Bool；99/117修正也忽略ack。新store能回报失败，但UI没有消费。 | 提交失败保留文字/心情与重试，成功才清空/计数/触觉；确认/修正按Bool提交状态，失败仍可操作。确认/修正的生产新数据路径受限，不冒称运行出现。 |
| R2-30 | P2 / open | I09,I10,I27 | TravelerNotesSection:336–343,418–426与ExperienceDetail:377–387,561–570仍承诺AI交叉验证/信号+1/L1→L2；实际只写SwiftData、userContributed本页状态，未发AI/公共confidence。 | 标本机笔记/记录数、保存成功；移除无真实回执的AI/共享等级增长承诺和重复加一；真实confidence的来源保持独立。 |
| R2-31 | P2 / source_fixed（active draft） | I24,I26 | TodayActionSheets:40–45保存新日期/天数后不syncVisaReminder；唯一同步仍KitSheet:389开关变化。提醒已开时旧通知不会随新倒计时变化。 | 保存后以同一preferences同步/取消，异常如实，保留单次提交。 |

源码正向：TravelerNoteStore默认不再注入演示notes/corrections，正常read也过滤精确的历史fixture ID；真实用户记录保留，只有测试显式opt-in。**演示数据不应作为真实社区证据**，当前这部分已源码修复。新ack API失败只回滚自身insert/count/status，未用全context rollback丢其他编辑。Map验证先真实note保存再markVerified；VerifySheet失败保留答案，成功后才关闭，中英文准确说明本机记录、不直接改变公开信心分。

Today两个原空回调已改必填并接真实日期表单/封存回执。没有kit数据时仍可设置个人倒计时；保存前不再擅自假定30天。封存回执只读日期等元数据，不提前揭正文。CityOS/SoloScore/Today这批按钮扩到44，ComplianceBanner改contain分开动作、SoloScore去永动，源码方向合理；大字最终外观/命中区尚待统一UI验收。

已读round02-root-native-test-summary.json：exit143、testsEntered0，错误NSMachErrorDomain -308 launcher server died，**没有测试通过**。先前root-build exit0发生在最新store/Verify变化前，不能覆盖当前树。当前共31项UI发现（12 P1/19 P2），另4项服务草稿源码修复；不因此把原生新入口或全部候选视为已运行。


## 父代理增量复核更新：提醒与服务端证据已收拢

**本批未见新增确认P0/P1。** 已知R2-29（笔记UI未消费ack）及R2-30（本机笔记虚称AI/信号增长）仍保留open，等待父代理处理，未提前关闭。

R2-31现已源码修复：日期保存锁定重复提交，await同步后关闭；Compliance先清固定ID旧提醒，关闭或已过期时不重排，有效未来倒计时才尝试排程，不重新请求权限。最终系统待通知/拒绝授权结果尚未运行验证。ActiveRouteBanner使用44标签、contain独立按钮与水平不足时的垂直备选；大字实际选中哪一布局须等冻结画面，不由源码给96。

服务端7/7文件SHA现匹配round02-server-source.json。独立读新版handler/persistence/0017与测试：身份验证、只读服务角色、用户JWT写入、不可变关系/状态、屏蔽后拒绝新note/accept而允许decline、receipt内容匹配及23505重读都保留。父代理Node14项/SDK2.112.4 strict/PG18均exit0，PG正式日志已含pending→block→UPDATE序列。因此R2-S01–04可关闭为**source_fixed + 对应宿主逻辑验证**；真实Supabase部署/完整线上迁移/原生端到端仍未做。

最新原生store/Verify/Today/Compliance/Kit/ActiveRoute尚未最终编译，早期部分build不覆盖这些修改。首次XCTest0cases仍未通过。本报告评分矩阵继续保留完整冻结前诊断区间，局部正向修复在JSON parentNativeDraftReview独立记载；全量冻结后再统一解除对应扣分，不用旧快照评分认证当前活跃树。


## Web响应式稳定草稿复核（Pi树，尚未导入）

相对efcb8fc独立读Pi三文件diff：experience/[id]/page.tsx、trip/[slug]/page.tsx、globals.css；未读取Pi仍活动的Completion/Friends/Chat文件，也未构建/运行浏览器。SHA绑定JSON的webDraftReview。

**R2-18/19主要源码缺口已修。** 两页≤640px移除固定56px内边距，改18px阅读边距、单列内容/站点，标题clamp/断词、顶栏换行，主要返回/指南/分享动作44px。行程CTA名为真实“打开城市指南”，不再假域名或宣称创建个人行程。R2-18/19关闭为source_fixed_in_Pi_tree，待导入冻结/运行；评分按诚实指南入口，未实现原个人计划能力保留历史。

root的global-error也已接reset和回/app的独立恢复入口、自有样式、44px/focus，不显示错误栈，R2-20源码已修。**新P2 R2-32**：global-error:8–11只以/zh或navigator.language定语言，忽略?lang=en与分享页默认zh。URL选择与浏览器语言相反时恢复页会换语言。应以明确路由/查询/页面默认规则优先、浏览器为最后fallback，不依赖失败Provider。

小型样式遗漏：手机exp-body gap24被inline gap36覆盖；trip-stat手机上下padding8被inline padding shorthand覆盖。这不使主按钮断路，建议导入时统一属性所属后再看实际节奏。此次未见新增确认P0/P1。320/390中英、200%缩放、焦点边缘与生产错误恢复仍待统一验收，不能因CSS看起来正确就填96。累计32项UI发现，局部关闭状态以本节/JSON为准；前面的冻结前评分作为历史诊断区间。


## Pi导入后的逐项源码闭环（当前补修中）

| 原ID | 源码状态 | 当前结论 |
| --- | --- | --- |
| R2-01 | source_fixed，待最终验证 | 收藏改UserPreferences独立route命名空间；加入行程打开真实选择并原子写全部站点，重开读回已有行程。 |
| R2-02 | source_fixed，待最终验证 | 群聊按真实conversation+成员权限打开；无会话诚实disabled；完成/回放单独命名。 |
| R2-03 | source_fixed，待最终验证 | 可选stop callback缺省走真实详情；start缺省发RouteNavigationRequest，Map收起Me/Settings并切地图画路线。 |
| R2-04 | 部分修复，仍需补齐 | 真实候选+throwing保存+完成后打开详情已接；同城缺数据静默回退all仍需修。 |
| R2-05 | source_fixed，待最终验证 | StopsList改44pt Button，编号/体验/路段完整AX标签。 |
| R2-06 | source_fixed，待最终验证 | 未实现路线分析改诚实暂不可用说明，移除付费Unlock假动作。 |
| R2-07 | 部分修复，仍需补齐 | ownedTask+编辑版本+显式采用建议已接；旧task defer清新busy的所有权遗漏仍需修。 |
| R2-08 | 部分修复，仍需补齐 | 发布/撤下/重排按保存成功才改UI且失败重试；importFavorites非Optional绑定/失败rollback遗漏待修。 |
| R2-09 | source_fixed，待最终验证 | mood与发送44pt，选择值和selected traits已接，提交失败保留心情/文字。 |
| R2-10 | 部分修复，仍需补齐 | 逐图写结果、保留全部raw图和明确重试/省略已接；照片集合编辑后旧batch失效/残留文件仍待修。 |
| R2-11 | source_fixed，待最终验证 | GeneratedRoute明确model/localFallback、失败原因/重试、本地草稿不标coCreated。 |
| R2-12 | source_fixed，待最终验证 | 权限token+ownedTask、松手/隐藏/后台discard、default AX；补onAppear可见恢复和VoiceService capture generation隔离晚回/取消后不继续mic。 |
| R2-13 | source_fixed，待最终验证 | date-only改同一Gregorian+device-zone civil day，local noon抗DST，不改存储schema。 |
| R2-14 | source_fixed，待最终验证 | free/expired改中性查看方案；未掌握真实transaction试用起止时进度条隐藏，保留verified expiration/days。 |
| R2-15 | 部分修复，仍需补齐 | 城市/体验导航及时间/CityOS/评分/路线浮层多数标签44；RouteDetail固定44高度dock大字备选仍待修。 |
| R2-16 | source_fixed，待最终验证 | Compliance/Pending/ActiveRoute改contain独立按钮，VoiceOver待确认提示不再自动消失。 |
| R2-17 | source_fixed，待最终验证 | Me头像/displayHandle读取与编辑页同一preferences；空值才fallback。 |
| R2-18 | source_fixed，待最终验证 | 已导入≤640px18px边距/单列内容与nearby、clamp断词、44返回/CTA；未实测。 |
| R2-19 | source_fixed，待最终验证 | 已导入小屏单列day/统计换行、真实品牌/打开城市指南CTA与44；未实测。 |
| R2-20 | source_fixed，待最终验证 | 独立global-error CSS、reset、原生/app链接、44/focus，错误栈不呈现。 |
| R2-21 | source_fixed，待最终验证 | 删除历史先确认，deletePersisted失败恢复自身rows并错误提示，成功才反馈。 |
| R2-22 | 部分修复，仍需补齐 | reason/detail真实保存本机draft后由用户发邮件/分享，只有Mail.sent标sent；.saved仍notSent；重开读回仍待修。 |
| R2-23 | source_fixed，待最终验证 | Flow回放只读；closed需明确确认，ack后庆祝；LocalRemote最新改throwing单/双记录提交、missing明确throw与completed幂等。 |
| R2-24 | source_fixed，待最终验证 | unfriend远端成功才移本地，失败保留row/重试，不无条件成功播报。 |
| R2-25 | 部分修复，仍需补齐 | UI进行中互斥/错误/Retry和atomic route+conversation已接；LocalRemote实际路径现throwing，非法state/capacity被吞仍待修。 |
| R2-26 | source_fixed，待最终验证 | create/recruit throw savePersisted，失败保留草稿；默认LocalRemote也改savePersisted/saveRouteAndConversation而非仅fallback修复。 |
| R2-27 | source_fixed，待最终验证 | Today必填真实日期表单/封存metadata，空kit仍可编辑个人倒计时，不开feature flag。 |
| R2-28 | source_fixed，待最终验证 | 删除/undo成功才提交UI，错误保留恢复payload；store失败仅回滚自身row。 |
| R2-29 | source_fixed，待最终验证 | submit检查addNote nil失败保留draft/moods；confirm/correction按Bool成功才更新本地和反馈。 |
| R2-30 | source_fixed，待最终验证 | 本机笔记/本机count/本机确认文案，去硬编码L1→L2和AI将交叉验证保证；公共confidence单独来源。 |
| R2-31 | source_fixed，待最终验证 | 保存日期锁重复，await同preferences提醒同步；先清旧提醒，有效未来且enabled才尝试排程。 |
| R2-32 | source_fixed，待最终验证 | global-error明确URL路径/query优先，分享/指南默认zh，营销默认en，浏览器仅fallback。 |

本批发现并即时回报的新增阻塞已被父代理补修：Report邮件结果非法.default→.saved；邀请草稿提交期间编辑/Cancel禁用；回放测试预期改0；更关键的默认LocalRouteCompanionRemote吞落盘失败改throwing API（先前Pi只改了Approval的fallback，不能据fake remote通过认默认链路已修）。原生最新build/test尚未完成。

仍在补修的7项必须按实际源码关闭：跨城候选、生成Task所有权、行程导入收藏类型/回滚、照片失败batch失效、路线Dock大字、举报草稿重开、审批非法状态/容量。没有把这些当“待实测”掩盖已知源码问题；也没有把源修复当运行通过。


## 继续追踪真实生产默认路径

**新确认P1 R2-33：路线好友进组邀请假成功。** InviteFriendsSheet:180–209,216–302不是新friendDirect邀请草稿。RouteDetail仍挂载该入口；confirmFriends try? commitContext/非throw save后返回added，UI成功触觉/通知/关闭，失败没有保留选择/Retry。必须整批throwing route+conversation原子写、失败回滚自身行且不返回added；合法状态/容量必须真正限制。已独立读源码，并立即通知父代理，不因盘点发现或缺运行截图而降为未知。

正向续核：LocalRouteCompanionRemote默认链路已经改真实throwing单/双记录API、missing错误、完成幂等、pending/容量/合法transition。回放fake测试旧错断言已改0；旧force-unwrap五例应改明确错误但仍不突变，并列入受影响测试。Itinerary importFavorites类型错误已修，写入复用addExperiences的own-row rollback。原R2-08/25源码已闭合。

累计33项（13P1/20P2）；当前剩余：R2-33确认P1，加R2-04/07/10/15/22的已报P2补修。不把修复承诺当关闭，等待真实最终diff/hash。


## root补修独立复核结束，等待Pi六文件

已重读真实默认LocalRemote、VoiceService/VoiceButton、CivilDay、EntitlementBanner、ItineraryStore及其新增测试源码。root范围无新增确认P0/P1：所有本地路线变更真实throw/atomic、缺对象报错、完成幂等、非法审批状态与容量拒绝；Voice可见恢复、两层token/generation和取消授权检查已接生产；日期默认公历；未知试用进度隐藏；收藏导入复用自身行回滚。

测试源码确实走生产LocalRemote+故障commit，旧nil五例断言明确错误且无突变；这不是测试已运行。最新build/test仍待结果。另纯反馈P2：收藏全部已在行程时count0静默return，已建议原位说明或按差集disabled，无需镜像测试。

Pi第三次返工正在改InviteFriends、CreateRoute、同城候选、RouteDetail大字Dock、照片batch、Report草稿六文件；未把活动文件当冻结交付，R2-33继续open，其余对应部分修复继续保留。最终hash和实际证据到达后再统一重评。

IF28已读回源码关闭：ItineraryDetail:140按收藏减已入行程的差集显示导入入口，全部已加入时不再给无结果按钮。Int类型与自身行回滚修复保留；未加镜像测试，未冒称运行通过。


## 第三轮六UI导入复核：P1源码闭合，仍有三处P2

- R2-04已去同城/nil的跨城fallback；空态真实citySelection由root各sheet onDismiss消费pending后打开picker。创建保存→详情路径保留。
- R2-07 attempt-owned defer/error/result，旧任务不清新busy，不生成旧pendingSuggestion。R2-15 Dock横/纵备选及minHeight44解决原固定高度。
- R2-10磁盘写恢复已接稳定图ID、receipt失效、raw保留及仅清本draft未采用文件；仍有PhotosPicker异步解码期间可保存的不完整输入。
- R2-22最新unsent重开与同ID编辑已接，Mail.saved仍notSent；但sent后Edit再保存仍沿用sent状态。
- R2-33真实批量好友进组一次atomic、失败留选择/Retry且不通知/关闭，原持久P1源码已修；非法transition与missing旧route兜底仍需拒绝。

**当前3个确定P2**：InviteFriends:276,295–296非法状态/missing；Report:215/257配合store.updateDraft把sent后编辑内容仍当sent；CreateExperience:65/116/331–345的PhotosPicker解码无busy/owner，保存先于照片进入images。已即时通知父代理；没有把这些当运行未知忽略，也不以修复承诺关闭。

原生新证据边界：父代理报告build-repair-5 exit0和严格签名exit0，但发生在最新修改前。16类86项确实执行，7条失败（Chat/Itinerary恢复4、CivilDay3），不再是首次launcher的0cases。已独立读修复：删除前值快照并插入新model恢复；严格ISO分隔符/roundtrip，跨设备clock夹具按各时区构造。复跑未出结果，不能称这些测试已通过。


## 最后三个P2补修：重新回读后源码闭合

本节覆盖本批当前集成源码；上节“三处P2”是修复前历史。只读复核了三个实际生产分支及新测试源码，没有启动构建、Simulator或测试。

| 项目 | 当前源码与闭合依据 | 尚待实际证据 |
| --- | --- | --- |
| R2-33 邀请失效/非法状态 | InviteFriendsSheet:278–282重新读取route，缺route/companion或非open/forming立即throw；298状态迁移直接try，349拒绝缺失group。原子写失败仍不返回added、不触发成功通知/关闭。158/165两例新增测试分别断言失效route不复活、completed不突变。中英标题/页脚明确仅本机添加，不发送远端邀请。 | 新测试实际执行、失败重试与提交锁定的UI抽样。 |
| R2-22 已发送报告编辑 | ExperienceReportDraftStore:114–115创建新的savedLocally草稿，ReportIssueSheet:261接收返回对象；原sent记录保持不变，新记录sentAt为空。新增测试:121–131核对新ID、待发状态、原正文/receipt保留。 | 新测试执行，以及Mail.sent后编辑/重开流程。 |
| R2-10 照片异步解码 | CreateExperienceSheet:121–137持有Task/generation，启动即busy，离开cancel并使晚回失效；69–72/405–406保存双重gate。349–386显示进度与解码失败数量，必须重选或明确skip后才可保存。稳定图ID与磁盘写失败恢复仍保留。 | 真实PhotosPicker慢解码、取消/返回、失败skip与磁盘失败恢复抽样。 |

当前33项源码发现全部闭合，未发现本批新增确定P0/P1/P2；此结论限定已审差异与明确修复契约，不代表所有候选均已运行。当前文件hash记录在scorecard.integrationReview.latestThreeFollowups，后续以最终冻结manifest绑定验证。原生86项中的7条旧失败仍保留失败状态，直到收到修复后的实际复跑结果。暂停发现性扩展，等待最终build、受影响测试及渲染证据；allItemsAboveTarget仍为false。

当前冻结盘点证据已读回：973静态候选（iOS863/Web110）、220 UI源文件、44功能族（iOS27），0未归组/解析诊断；current/source-stability.json报告220/220 hash一致，UI manifest SHA256为`71c116372c07c9dc07042ec710061929150005f7380e2cd5c76e9fc99c274c3f`。该计数不等于973个独立按钮，不替代行为验收；旧892基线保持历史。

</details>


</details>
