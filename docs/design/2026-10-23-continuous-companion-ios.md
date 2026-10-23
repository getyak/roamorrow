# Roamorrow：持续同行的原生入口

用户已经明确授权深度实现、重构以及在 roamorrow 项目创建不同 Session 并行开发。设计承接本对话最新已实现的网页方向：此刻持续 IM、附近地图、选择这次与谁同行；不以隐藏地图或同行功能追求极简。

## 产品与边界

顶部为此刻/附近、同行、更多。单一输入入口随两种视图存在，切换不丢文字、不重置地图。此刻连续保存本人原话、短回应、需要决定的小卡片和未完事项。附近复用现有 MapKit、Experience、地理与来源服务，地点详情采用原生抽屉，保留路线与来源，最多突出五个候选。同行为这次意向；人选、邀请、双方确认、位置授权是不同状态，不用示意数据冒充真实朋友与回执。

采用 iOS17+ SwiftUI、MapKit、Observation、async/await。优先系统滚动、sheet detents、键盘避让与原生导航，避免给地图/竖向滚动/返回手势增加全屏自定义 DragGesture。单个枚举管理互斥的主弹层。动态字号、44pt点击范围、VoiceOver、减少动态效果和暗色模式纳入实现。

现有 Studio 与用户数据保留；新根入口优先，开发开关可回到旧入口。复用旧数据服务，不引入第二套模型密钥，不硬编码场景，不将关键词匹配当 Agent。中断/断网/权限不足保留原话及重试入口，不声明已发送、付款或系统后台持续工作。

## 并行边界与共享契约

主协调负责 App 入口、CompanionHomeView.swift、CompanionHomeStyle.swift、CompanionComposer.swift、xcodegen/project.yml、资源文案、构建与统一验收。

Session A 负责 Views/CompanionHome/CompanionHomeModels.swift、Services/CompanionHomeStore.swift、Services/CompanionHomeAgent.swift 和对应新的单元测试。必须先给出可编译的接口，再细化实现；复用现有 AIService/Agent 工具与本机数据。

共享模型拟定：CompanionHomeEntry（id UUID、role user/companion、text String、createdAt Date、status queued/working/delivered/failed、sourceTitles [String]、placeID String?）、CompanionHomePerson（id String、name String、isExample Bool）、CompanionHomeInvite（id UUID、placeID String、placeName String、date Date、durationMinutes Int、people [CompanionHomePerson]、note String、始终区分draft与confirmed）。

@MainActor @Observable CompanionHomeStore：entries、composerDraft、isWorking、errorMessage、people、selectedPeopleIDs、invites 为可观察状态；init(url: URL? = nil)、configure(aiService: AIService, experienceService: ExperienceService)、send() async、send(text: String) async、retry(id: UUID) async、selectPeople(_ ids: Set<String>)、saveInvite(_ invite: CompanionHomeInvite) async、clearError()；选择应可撤回，保存与失败情况不能吞掉输入。若现有服务需要更合适的结构，先明确告知协调者而非悄悄改契约。

Session B 负责 Views/CompanionHome/CompanionNearbyView.swift、CompanionPeopleSheet.swift、CompanionPlaceSheet.swift；允许给旧 CompassMapView 增加小型可选嵌入配置，保留所有原地图行为与用户未提交改动。接口 CompanionNearbyView(store: CompanionHomeStore)、CompanionPeopleSheet(store: CompanionHomeStore)、CompanionPlaceSheet(experience: Experience, store: CompanionHomeStore)。主地图如需与旧入口复用不应复制整个4300行地图实现。

Session C 负责 docs/design/2026-10-23-ios-interaction-research.md、docs/qa/companion-ios-20261023/ 与新增测试/测试运行脚本；先审计平台测试环境和旧测试基线，再补连续状态、存储恢复、失败重试、单一sheet/键盘/导航/隐私的验收。只报告实际证据，不将静态源码检查冒充原生运行。

## 交付验收

完整路径：启动→持续对话→附近地图→地点→同行选择→具体邀约草稿→回到原对话。验证取消返回、切换保留输入/地图、失败重试、刷新/重启恢复、示意与真实来源、真实模型配置不足、权限拒绝。原生构建、纯模型测试与实际模拟器截图分别报告；不能用新建的独立预览代替正式App入口验收。

## 当前实现

首页保留「此刻／附近」两个视角，共用一段持续对话与底部输入框。暖白纸色、深绿、衬线标题与原话构成主视觉；操作使用系统字体，地点配图有明确来源。大字号时页头分两行，图标保持适当尺寸和44pt触达范围。空白首页先解释可以交托什么，示例只填入输入框，由用户决定发送。

对话、未完成事项和邀约是三个独立对象。回应到达只代表对话交付，不会把事项标成完成；事项以稳定ID保存，由用户或用户明确要求的工具操作更新。邀约在本次范围内始终是未发送草稿，选中同行人不会创建好友、发送消息或打开位置共享。本机姓名与已确认好友在选择界面区分。

地图沿用现有MapViewModel及地点、筛选、聚类和排序服务。首页切换不销毁地图，不重置镜头或草稿；隐去时停下定位与可见区域工作。定位由点击触发，只请求使用期间授权。地点抽屉内通过原生导航进入同行与邀约，保存后回到同一段对话。地图最多突出五个候选，来源与详细字段逐步展开。

模型复用生产AIService与现有配置。工具仅开放地点搜索、网页检索、地点详情及本机事项管理，不开放付款、预订或代发。搜索返回实际记录与出处；默认地图中心和用户GPS明确区分。网页工具区分真实空结果与服务关闭、认证失败、限额、坏响应等不可用状态。语音先转成可编辑文字；照片入口使用选定图片进行文字识别，不把它称为通用图片理解。

本机快照原子写入Application Support。工具计划先落盘，本机事项变化与工具执行回执在同一次写入中保存；恢复重试沿用原计划，避免模型换个标题再次创建。损坏文件和更高版本文件保留，失败写入不吞原话、不显示虚假的保存成功。历史快照不要求一次性迁移。

设置中的导出包含这段对话、未发送正文、事项、同行选择、邀约及工具回执的JSON快照；清空需在原生确认框中确认范围，取消正在返回的任务，并处理原文件及已知恢复文件。分享后的副本不在本机清空范围内。文件准备失败不会显示为完整导出，清空失败也会如实提示。

连续保存不等于持续后台执行。此版没有新增航班监控、自动催酒店、远程推送或真实双方邀约回执；这些需要各自的数据服务、授权和运行基础。后台检索默认开关也维持原有设置。真实模拟器、真实模型、隔离故障测试和未完成的专项边界，分别见[公开验收摘要](../qa/companion-ios-20261023/PUBLISHED_ACCEPTANCE.md)。完整原始记录留在本机。

## 第二轮：补旧能力与内容秩序

用户在验收聊天确认继续沿用简洁结构，并要求接回城市与收藏、统一中文展示、改进对话卡片和错误、移除可见品牌并补完整交互验收。本轮不改历史用户原话，不迁走旧Studio或重建已有收藏数据。

顶部只留此刻／附近、同行和更多；消息不重复署产品名或流标题。消息和邀约合成一个按真实创建时间排列的显示投影，约定见面时间仅显示在邀约内容里。旧草稿没有创建时间，固定放在历史区域并明确时间未记录。稍后重试才到达的回应保留原问题提示；上翻阅读时，新回应只显示新内容入口，不强制拉到底部。待办入口直接露出首件事项与数量。

附近复用原城市目录与收藏数据，支持搜索已收录城市和收藏筛选。城市切换退出本页GPS跟随；城市中心是搜索范围，不是用户所在地。每次模型回应现读已选择城市的公共中心，要求在搜索工具里显式使用该范围；对话指定其他城市时以明确请求为准，不把切城后无坐标请求静默当作清迈附近。

34条内置地点简介采用审核过的中文展示，原专名、用户署名、地址与原始资料保留。未知英文资料只给查看原文的入口，不填造译文事实。距离标明来自地图中心或用户定位，只有直线距离时不编步行分钟。营业、价格、地址、来源和原文分层展开；现有种子没有的数据继续显示未收录，不把来源日期当成本次实时核验。

用户可见错误只说明失败原因和可行动下一步，安全的原错误类别保留在执行记录中。历史回应通过展示层转换内部代码，存储原文不改。真实UI自动化使用正式SoloCompass App新增CompanionAcceptanceUITests，与模型／存储回归分开执行；测试不删设备原资料、不向他人发送、不用假数据冒充模型成功。原始验收计划与地点资料方案保留在本机 `docs/qa/companion-ios-20261023/round2/acceptance-plan.md` 和 `place-information-design.md`，不随公开代码提交。

第二轮独立审查后补充：欢迎示例与“接着说”保留已有未发送文字，仅追加上下文；助手正文在展示层解析行内强调，原话与快照不变，依据仍从明确的来源入口查看。邀约编辑持有本地收件人与完整初始快照，不随顶部同行意向变化；只查看关闭不会保存。修改后下滑不直接关闭，完成时提供保存、放弃、取消；保存失败留在当前页并保留编辑。无可核实地点照片时只显示紧凑类别提示，避免大幅占位或错配氛围照片。

最终呈现状态由 `CompanionHomePresentation` 在首页统一持有。城市、地点、同行、行程、来源、设置共用一个原生 sheet 宿主；附近只提出地图任务，保留自己的镜头、筛选和定位生命周期，不再持有对话Store或创建第二个sheet。地点打开时携带距离参照快照，保存成功再由首页回到此刻。此调整用于减少地图刷新和启动状态变化时的呈现竞争，稳定性仍以新包实测为准。

邀约卡片使用独立无障碍容器，稳定ID属于整张卡片，内部地点、日期和分享按钮各自可读，避免同一ID传播到图标。听写只更新自己最近写入的草稿；欢迎示例或行程追加了新内容后，下一次识别结果结束本次听写并保留较新的草稿。这里是输入竞争保护，实际语音识别与读屏表现仍需相应设备验证。

实测还发现，历史回复中的城市可能覆盖模型对当前选择的理解。当前轮的地图范围因此作为单独的系统事实，放在历史之后、最新问题之前；两处事实使用同一次读取的快照。旧原话和错误回复都保留，未选择范围时明确缺失，不能从旧聊天猜回。所选目的地、地图搜索范围和设备定位仍各有含义。这是消息组织的修正，效果以包含原错误历史的真实请求复验为准。

传输继续沿用现有服务的消息角色与序列结构；[DeepSeek 官方接口](https://api-docs.deepseek.com/api/create-chat-completion/)定义了系统、用户、助手和工具消息，但接口结构本身不保证回复总会服从当前事实。Debug 诊断只记录实际发送序列中的公开城市名与本轮记录ID，不输出原话、完整提示、坐标或凭据；Release 不包含这项日志。

对话滚动使用 iOS 17 原生的稳定目标身份：在底部时跟随末尾哨兵，用户上翻后保留正在看的历史行，点击新内容再回到末尾。移除把内容增高误当作用户上翻的底部坐标判断。[Apple 接口说明](<https://developer.apple.com/documentation/swiftui/view/scrollposition(id:anchor:)>)描述了按目标身份跟踪与尽力保持可见的行为；本页仍需分别实测自动跟随与阅读历史两个分支。

最终正常重启读回发现，预先将滚动身份设为末尾哨兵，会让已有26条记录的首屏出现空白；资料并未丢失。初值改为nil，第一次布局只交给系统默认底部锚点，后续用户动作再明确写入滚动目标。同一份资料、同一构建配置的实际重启已显示最新15:58回复，保留左右24pt留白；无模型的重启与视图往返用例单独验证。此前上翻读历史的真实模型用例未能在回复完成前捕捉阅读锚点，因此仍未证明等待中的历史位置保持。
