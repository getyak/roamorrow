# 交互质量独立审查

审查基线：`924f09a4ea7e3ed9b016ed9a956705a7e576cd5e`。范围：Web 官网、Web 体验与 iOS；重点为 iOS。审查者独立于生产代码实现，只维护本报告及 `scorecard.json`。

## 当前结论（法律入口增量）

**尚未认证每个按钮和功能体验超过96分。本轮已修改路径没有未解决的确认P0/P1；新增审核文档问题 `LEGAL-P1-02` 已经完整重写并复核关闭。L01 已转为 `source_fixed_public_destination_verified`：正式双语 Gist 已发布、匿名读回及各端入口源码已复核。新 iOS 入口实际点击、App Store Connect 线上元数据和新二进制发布仍未验证。**

05选定验证已全部通过：原生Debug构建、本地化、Web生产构建、Web与bot类型检查均exit0，5份正式日志解压SHA已核对。109份应用源码与6份法律/元数据文档指纹匹配；本轮公开Gist与源码接入交付完成。

上一冻结版 Web50/50、原生04b56/56文件SHA匹配；当时全源盘点218文件SHA匹配，44功能族、913候选（807 iOS/106 Web），0未归组。法律入口增量改变了部分源码/候选；此前哈希与盘点属于历史，不自动认证当前树，05正式清单109/109源码SHA已核对（清单SHA `f855ac12a781b9916759b5d7108ff119e646adb95b5e9b1e1a5c3acefb28d01c`）；法律增量后新盘点为918候选（iOS810/Web108），218源码SHA已独立全部核对，44组、0未归组。已确认的源码问题已处理；计划/仪式中部分动作采用诚实指南、预览或只读范围，未冒充原业务实现。

Web有特定菜单、面板、打卡失败、焦点、320指南/预览等E3；原生E3限03菜单/草稿，04b有效图仅暗色AXXXL与合成诊断E2。真实麦克风/相机/StoreKit、有效Mapbox与完整无障碍仍未验收，无E4用户任务证据。Web最后clear-intent补44px后的productionbuild已exit0；构建后typecheck及58逻辑通过，58例在唯一CSS补充前执行、受测逻辑未变，原生03的80例与04b的3例单独绑定版本。

**后文 open/partial 表及旧 URL pending 描述均是历史 checkpoint，不能当当前未修复清单。** 当前以本节、末尾法律入口增量及 scorecard.currentSourceAssessment 为准。892个基线ID/区间保留；913当前ID不自动继承评分或通过状态。功能区间与品味判断分开，不用平均数掩盖缺项。

## 评分口径

功能质量的 100 分分为以下七项；每项满分须有正面证据，缺证据不能按默认满分处理。

| 维度             | 权重 | 可复核的通过条件                                                            |
| ---------------- | ---: | --------------------------------------------------------------------------- |
| 可理解性         |   15 | 名称说明结果；图标有合适标签；动作与反馈用词一致                            |
| 层级与注意力     |   15 | 当前主动作明确；边框表达分组、焦点或状态；装饰不伪装成控件                  |
| 触控与键盘       |   20 | iOS 关键命中区至少 44pt；Web 主要触控动作采用 44px 目标；键盘能到达并执行   |
| 状态反馈         |   15 | 按下、忙碌、成功、失败与已选状态可区分；异步重复提交受控                    |
| 流程恢复与保留   |   15 | 取消、返回、重试可达；失败不丢输入；切换不丢对话和选择                      |
| 无障碍与动效     |   10 | 辅助操作可执行；信息不只依赖颜色；大字、暗色、减弱动态效果可用              |
| 产品一致性与信任 |   10 | 地图/对话工作空间连续；推荐保持证据边界；权限只在相关操作后请求且可及时停止 |

评分状态：`provisional` 表示只有部分源码/截图证据；`not_verified` 表示未审或证据不足；`verified` 必须带构建版本、具体状态、操作和结果。未测项目不得写成失败，也不得算通过。

96 分以上的交付条件：每个候选项关联功能及测试状态；最新源码没有未解决 P0/P1；关键路径在运行产品完成正向、拒绝、失败、返回与恢复验证；截图覆盖浅/暗与必要的大字状态。即使这些条件满足，仍只能报告“本轮审查分数”，不能据此声称真实用户满意度 96%。

审美单独记录相对判断，不与功能总分相加：相对于旧版，信息是否更清楚、是否更像独行旅行产品、是否减少无意义描边/装饰、是否保留独有记忆点。没有渲染截图时标为 `not_verified`，不写“品味 98 分”。

## 首轮已确认问题

以下定位以基线为准。P1 是会阻断核心目标或违反产品信任边界的问题；P2 是明确可用性/无障碍缺陷。修复状态将在冻结改动后更新。

| ID  | 级别 | 功能及源码                                                                                                                                              | 观察事实、影响与验收建议                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | 状态                                              |
| --- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| W01 | P1   | 官网下载，`apps/web/src/components/marketing/sections.tsx:21`；`src/app/(marketing)/download/page.tsx:8`                                                | App Store 目的地使用 `id0000000000`；主导航、Hero、定价、下载页均继承占位链接。应统一可用目的地；未有商店链接时给真实 Web 试用入口并明确发布状态。逐个读回 href、点击后确认实际落点。                                                                                                                                                                                                                                                                                                         | source_fixed_runtime_partial                      |
| W02 | P1   | 今日推荐，`apps/web/src/components/TodayBanner.tsx:126`                                                                                                 | 排序只使用 soloScore、bestTimes、步行时间，文案却断言营业、无人群和夜间安全。应将文案限制为有依据的推荐，不把最佳时段当实时营业/安全证据。跨城/跨时区亦需核对。                                                                                                                                                                                                                                                                                                                               | source_fixed_runtime_pending                      |
| W03 | P2   | 官网导航，`apps/web/src/components/marketing/sections.tsx:53`                                                                                           | 移动断点隐藏 Features/Pricing/Manifesto/语言切换且无替代入口。补可展开导航、展开状态和焦点恢复；320–390px、键盘及菜单内链接实测。                                                                                                                                                                                                                                                                                                                                                             | source_fixed_runtime_partial                      |
| W04 | P2   | Web 语音，`apps/web/src/components/VoiceIntent.tsx:169`                                                                                                 | 正常支持语音时只显示 pointer 按住按钮，键盘用户无法开始/停止；用户也无法主动切回文字。提供始终可见文字路径与键盘操作；拒绝权限仍保留草稿。                                                                                                                                                                                                                                                                                                                                                    | source_fixed_runtime_partial                      |
| W05 | P2   | Web 签到，`apps/web/src/components/ExperienceSheet.tsx:48`                                                                                              | 保存失败只回 idle，没有错误或恢复指引。应展示失败、保留评分并提供重试；不显示成功；避免重复提交。                                                                                                                                                                                                                                                                                                                                                                                             | source_fixed_runtime_partial                      |
| W06 | P2   | Web 评分，`apps/web/src/components/ExperienceSheet.tsx:315`                                                                                             | 1–5 的评分目标为 28×28px，邻近排列，触控容易误选；且选择评分会直接提交签到，标签未解释副作用。应增加目标、明确评分即完成的含义或采用选择后统一提交。                                                                                                                                                                                                                                                                                                                                          | source_fixed_runtime_partial                      |
| W07 | P2   | Web 命令面板，`apps/web/src/components/lisbon/CommandPalette.tsx:174`                                                                                   | 使用 `aria-modal=true`，初次聚焦输入框，但没有 Tab 约束与关闭后的焦点恢复；输入框仅 placeholder。应保证模态内焦点循环、Esc 返回触发器和可访问名称。                                                                                                                                                                                                                                                                                                                                           | source_fixed_runtime_partial                      |
| W08 | P2   | Web 暗色交互色，`apps/web/src/app/globals.css:155`；`marketing/primitives.tsx:16`                                                                       | 暗色变量替换背景/前景，却保留深棕 accent；主按钮文字 `text-bg-warm` 同时变深，焦点环仍深棕。应拆出交互 accent 与固定 on-accent 文本并测实际对比度。                                                                                                                                                                                                                                                                                                                                           | source_fixed_runtime_partial                      |
| W09 | P2   | Web 附近抽屉，`apps/web/src/components/NearbySheet.tsx:78`                                                                                              | 抓手目标 24px 高，TabButton 未暴露选中状态，Peek 文案偏“pull up”。补44px与 expand/selected semantics；点击与键盘不依赖拖拽。                                                                                                                                                                                                                                                                                                                                                                  | source_fixed_runtime_partial                      |
| W10 | P2   | Web 当前推荐，`apps/web/src/components/TodayBanner.tsx:78`                                                                                              | 关闭目标为24×24px；推荐小 chip 也较窄。扩大点击面；关闭与展开体验不抢占同一目标，确认横向小屏不溢出。                                                                                                                                                                                                                                                                                                                                                                                         | source_fixed_runtime_pending                      |
| I01 | P2   | iOS 录音停止，`apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:319`                                                                                  | listening 状态替换原麦克风，录音条只 `onTapGesture` 且忽略子元素，没有 default accessibility action；原 mic 的 action 已不存在。为停止操作提供真实 Button 或等价 action；VoiceOver 从开始到停止实测。                                                                                                                                                                                                                                                                                         | source_fixed_runtime_pending                      |
| I02 | P2   | iOS 文本输入暗色，`apps/ios/SoloCompass/Views/Chat/ChatInputBar.swift:440`                                                                              | 输入聚焦时填充固定 `CT.surfaceWhite`，无暗色分支；需检查文字与光标在白底的实际颜色。使用适配表面并检查聚焦/失焦浅暗截图。                                                                                                                                                                                                                                                                                                                                                                     | source_fixed_runtime_pending                      |
| I03 | P2   | iOS 删除照片，`apps/ios/SoloCompass/Views/Experience/CreateExperienceSheet.swift:183`                                                                   | 删除按钮只有 xmark 图标，没有明确哪张照片的名称和最小目标。补44pt目标、索引/内容标签；验证删除后剩余照片状态。                                                                                                                                                                                                                                                                                                                                                                                | source_fixed_runtime_pending                      |
| I04 | P2   | iOS 发现排序，`apps/ios/SoloCompass/Views/Map/DiscoverWorkspaceView.swift:221`                                                                          | Menu 标题只有 caption 与上下8pt，未保证44pt。扩大透明命中区、维持轻视觉；选中排序需要可读回。                                                                                                                                                                                                                                                                                                                                                                                                 | source_fixed_runtime_pending                      |
| I05 | P1   | iOS 同行可见性恢复，`apps/ios/SoloCompass/Views/Companion/ItineraryDetailView.swift:144`                                                                | “打开个人设置”按钮的 action 仅注释；用户触发可见性阻断后无法按界面指示恢复。应连到真实设置并在返回后重新检查可见性。                                                                                                                                                                                                                                                                                                                                                                          | source_fixed_runtime_pending                      |
| I06 | P2   | iOS 类别偏好，`apps/ios/SoloCompass/Views/Settings/SettingsView.swift:945`                                                                              | 偏好行使用 tap gesture，没有 Button/选中语义；隐藏列表的移除图标也缺名称与目标。改为可执行并读回状态的控件，保留列表滑动行为。                                                                                                                                                                                                                                                                                                                                                                | source_fixed_runtime_pending                      |
| I07 | P2   | iOS 手动坐标，`apps/ios/SoloCompass/Views/Map/LocationPickerSheet.swift:719`                                                                            | 经纬度使用 decimalPad，没有负数入口，西经/南纬输入困难。提供有符号输入或方向选择；正负、越界和小数分隔符验证须不改变 GeoJSON 顺序。                                                                                                                                                                                                                                                                                                                                                           | source_fixed_runtime_pending                      |
| W11 | P2   | Web 城市排序，`apps/web/src/app/[city]/page.tsx:123`、`:127`、`:511`                                                                                    | `activeSort` 只用于选择样式；传入列表的 `filtered` 只按分类过滤，点“最近编辑/距离”不改变顺序。实现有真实数据依据的排序；字段缺失时不提供假排序。选项、实际顺序和 URL 状态须读回一致。                                                                                                                                                                                                                                                                                                         | source_fixed_runtime_partial                      |
| W12 | P2   | Web 城市列表，`apps/web/src/app/[city]/page.tsx:627`                                                                                                    | ListRow 为 `div onClick`，没有角色、tabIndex 和键盘处理。换成语义 Button 或完整等价控件；分类/排序暴露当前状态。Tab/Enter/Space 选择体验应与指针一致。                                                                                                                                                                                                                                                                                                                                        | source_fixed_runtime_partial                      |
| W13 | P2   | Web 足迹到详情，`apps/web/src/components/TimelineList.tsx:80`；`apps/web/src/app/app/page.tsx:31`                                                       | 足迹传出历史体验 ID，但父组件只在当前附近结果中解析详情；历史体验离开当前范围时点击无结果。按 ID 解析独立详情或走真实详情 URL；不存在/加载失败给出可恢复状态。                                                                                                                                                                                                                                                                                                                                | source_fixed_runtime_pending                      |
| W14 | P1   | Web 城市加入计划，`apps/web/src/app/[city]/page.tsx:1144`                                                                                               | 可见“加入计划”Button没有onClick或链接，点击无结果。连接真实保存/计划并反馈可读回；未有计划能力时换成准确的现有动作，不能只保留可点外观。                                                                                                                                                                                                                                                                                                                                                      | source_fixed_with_scope_reduction_runtime_partial |
| W15 | P2   | Web 行程分享，`apps/web/src/app/trip/[slug]/page.tsx:170`                                                                                               | “分享”Button没有onClick。提供系统分享与不支持时复制URL的真实结果/失败反馈，或在服务端页移除不可用动作；不发消息给任何联系人。                                                                                                                                                                                                                                                                                                                                                                 | source_fixed_runtime_pending                      |
| W16 | P2   | Web 体验加入行程，`apps/web/src/app/experience/[id]/page.tsx:467`                                                                                       | “加入行程”与“查看地图”都仅回城市首页；前者不保存，后者不携带当前体验，无法定位。动作名称应与真实结果一致；地图URL带上体验ID并正确恢复选择，保存若未实现不作虚假承诺。                                                                                                                                                                                                                                                                                                                         | source_fixed_with_scope_reduction_runtime_partial |
| W17 | P1   | Web 城市地图控件，`apps/web/src/app/[city]/page.tsx:273`、`:802`                                                                                        | “+ City”及地图+、−、⌖都是无handler的Button。当前WebLisbonMap为绘制地图，不能通过控件暗示真实缩放/定位。连接真实城市选择/地图操作；做不到时移除不可执行控件并将地图性质说明准确。不得首次加载就为了假定位动作索取权限。                                                                                                                                                                                                                                                                        | source_fixed_runtime_partial                      |
| W18 | P1   | 官网位置隐私承诺，`apps/web/src/components/marketing/copy.ts:207`、`:440`                                                                               | “Your location never leaves your phone/位置永远不离开手机”与明确源码路径矛盾：OverpassService.swift:139–149把坐标写入远程查询，AIService.swift:391、:904把位置写入发送给模型的prompt。修正为准确、带操作范围和同意边界的描述，并与现有隐私页/同意页一致；本任务不需要改采集范围或新增数据传输。                                                                                                                                                                                               | source_fixed_runtime_partial                      |
| W19 | P2   | 官网产品与示意图身份，`apps/web/src/components/marketing/copy.ts:187`、`:223`、`:420`、`:456`                                                           | “No onboarding/没有引导页”与OnboardingView.totalSteps=8矛盾；“每张卡真实App界面”实际由sections调用CapabilityMock，后者为live-DOM示意图。改为当前地图+对话工作空间和可跳过引导的准确描述；示意图明确标注，不伪装实机截图。                                                                                                                                                                                                                                                                     | source_fixed_runtime_pending                      |
| W20 | P1   | 官网权益/售卖承诺，`apps/web/src/components/marketing/copy.ts:305`–`:340`、`:538`起                                                                     | $29 Lifetime/Buy Once在当前客户端没有可购买SKU（SubscriptionService.allProductIDs只有monthly/yearly）；“无限AI”与AIService.swift:1449的Pro每日30次synthesis/60次explanation矛盾；iCloud跨设备同步缺当前CloudKit/iCloud entitlement与实现证据（SwiftData为本地存储；实际同步模块使用Supabase）。移除未经支持的权益与固定价格承诺，引导查看App内真实提供方案/当前限制；不能为修文案臆造新SKU、价格或后端。download/SEO/中英文需要同源纠正，不保留“免费每天3次”之类与当前Free配额0矛盾的旧说明。 | source_fixed_runtime_pending                      |
| I08 | P2   | iOS 购买恢复，`apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:468`                                                                                | runRestore 只处理成功；失败或无历史购买没有界面反馈。恢复按钮未被 purchaseInFlight 禁用，可重复发起且与购买并行。增加单一忙碌守卫、成功/无购买/错误反馈，拒绝或取消后可恢复；不得假装解锁。                                                                                                                                                                                                                                                                                                   | source_fixed_runtime_pending                      |
| I09 | P2   | iOS 付费方案语义，`apps/ios/SoloCompass/Views/Paywall/PaywallView.swift:296`                                                                            | 卡片显式 AX label 只保留产品名称，价格/周期/选中状态没有进入该标签；periodLabel 为硬编码英文。让价格、周期和选择被完整读出，中英一致；只有实际资格已知时才作对应试用承诺。                                                                                                                                                                                                                                                                                                                    | source_fixed_runtime_pending                      |
| I10 | P2   | iOS 举报原因，`apps/ios/SoloCompass/Views/Companion/ReportBlockSheet.swift:113`                                                                         | 原因行只用 onTapGesture，没有按钮或 selected 语义；VoiceOver 无可靠执行路径。使用 Button/Picker 并读出已选；提交成功、失败、取消与封禁确认保持现有真实服务闭环。                                                                                                                                                                                                                                                                                                                              | source_fixed_runtime_pending                      |
| I11 | P2   | iOS 分享模式/预览，`apps/ios/SoloCompass/Views/Experience/Share/ShareSheet.swift:105`、`:157`                                                           | 模式 chip 没有44pt保证和选中语义；renderPreview 用 try?，渲染失败后始终展示 spinner。补可执行目标/选中状态；失败显示解释与重试或 Markdown 可用路径；系统分享和复制要交付真实内容。                                                                                                                                                                                                                                                                                                            | source_fixed_runtime_pending                      |
| I12 | P2   | iOS 时光胶囊编辑，`apps/ios/SoloCompass/Views/Capsule/CapsuleComposeView.swift:44`                                                                      | 编辑器缺名称；仅text.isEmpty允许纯空格；取消/划走没有草稿保护；Surface in/months/title/Cancel硬编码英文。trim验证、本地化、明确编辑标签与脏状态保护；持久化失败须保留草稿并给重试。                                                                                                                                                                                                                                                                                                           | source_fixed_runtime_pending                      |
| I13 | P2   | iOS 仪式大字和动效，`apps/ios/SoloCompass/Views/Capsule/CapsuleOpenView.swift:44`；`Blindbox/BlindboxLaunchView.swift:44`；`Omen/OmenCardView.swift:33` | 胶囊/盲盒使用无滚动VStack，长正文/大字可能把操作挤出；胶囊展开和签文翻转不检查 Reduce Motion；多处操作硬编码英文。采用能滚动的内容与稳定操作区、本地化、减弱动态效果；必须用长文与大字运行截图验收。                                                                                                                                                                                                                                                                                          | source_fixed_runtime_pending                      |
| I14 | P1   | iOS 仪式假动作，`apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:175`–`:231`                                                                       | Release可达 ritualsHub 的盲盒启动、Brag分享/壁纸/视频、OST分享/重新生成、Insight分享、胶囊回复、Codex解锁只设 ritualsSheet=nil。用户点动作得到关闭而非承诺结果。必须连接现有真实业务能力；若业务尚未就绪，将整个目标明确呈为“预览”，移除假CTA并给真实可用路径。不要为消除审查问题发起未授权购买或发布。                                                                                                                                                                                       | source_fixed_with_scope_reduction_runtime_pending |
| I15 | P1   | iOS 仪式伪状态，`apps/ios/SoloCompass/Views/Archive/ArchiveView.swift:347`、`:369`                                                                      | CityCodex把同一今日签文放入不同日期并把首项标完成；无胶囊时生成“A note from you”与90天前日期，未标示演示。应只显示真实记录或清楚空态/演示；不可伪装个人历史或完成状态。无记录新用户必须实测。                                                                                                                                                                                                                                                                                                 | source_fixed_runtime_pending                      |
| I16 | P2   | iOS 胶囊保存失败，`apps/ios/SoloCompass/Views/Experience/ExperienceDetailView.swift:316`                                                                | CapsuleStore.bury 返回nil后仍关闭编辑器，没有提示或输入恢复。使成功结果驱动关闭；失败留在编辑器、保留内容并能重试；成功消息本地化。                                                                                                                                                                                                                                                                                                                                                           | source_fixed_runtime_pending                      |
| I17 | P2   | iOS AI配置选择，`apps/ios/SoloCompass/Views/Settings/AIProviderSettingsView.swift:49`                                                                   | provider 行只onTapGesture，缺执行与选中语义；状态仅看key非空就称configured。使用可执行选择控件；配置存在与连接已验证分开表达，不需为此把key打入日志或远程测试。                                                                                                                                                                                                                                                                                                                               | source_fixed_runtime_pending                      |
| I18 | P2   | iOS 核实问答，`apps/ios/SoloCompass/Views/CityOS/VerifySheet.swift:108`、`:155`                                                                         | 关闭按钮30pt；选项按13pt字+vertical9设计无44pt保证；只有medium detent且无滚动，Dynamic Type下正文和操作可能不可达。增加目标，允许large/滚动并保留已答状态；全回答前禁用提交逻辑应保持。                                                                                                                                                                                                                                                                                                       | source_fixed_runtime_pending                      |
| I19 | P1   | iOS 路线申请，`apps/ios/SoloCompass/Views/Companion/JoinRouteRequestSheet.swift:54`、`:251`                                                             | `canSubmit`以原始count>=10验证，10个空格可提交；NotImplementedError和其他失败都吞掉，随后震动并关闭。trim后验证；仅成功关闭，失败保留message/pace、解释失败并能重试；未接后端时明确不可用，不作成功表象。                                                                                                                                                                                                                                                                                     | source_fixed_runtime_pending                      |
| I20 | P2   | iOS 接受申请到对话，`apps/ios/SoloCompass/Views/Companion/RequestInboxView.swift:183`                                                                   | acceptedConversation赋值后没有被任何呈现或导航读取；接受后只显示OK，注释承诺的打开对话未发生。成功后提供真实对话目的地；错误留在当前请求、不可重复接受并保证无重复对话。                                                                                                                                                                                                                                                                                                                      | source_fixed_runtime_pending                      |
| I21 | P2   | iOS 路线分享切换，`apps/ios/SoloCompass/Views/Companion/RouteShareSheet.swift:119`                                                                      | await渲染之后使用可变selectedStyle写缓存，没有校验任务取消/请求样式；快速切换map→trace时旧结果可能写入新样式缓存和预览。冻结请求style作为渲染/缓存key，过时结果不提交；补44pt和选中语义，实际连点切换核对预览/导出一致。                                                                                                                                                                                                                                                                      | source_fixed_runtime_pending                      |
| I22 | P2   | iOS 探索同意，`apps/ios/SoloCompass/Views/Map/ExploreConsentSheet.swift:76`                                                                             | 同意按钮是白字配浅金CT.sunGold，与现有Paywall已修正的同类配色不一致；取消只有36pt；内容无滚动，大字在medium易挤出。采用清楚对比的on-accent配色、44pt取消目标及可滚动布局；明确何种数据将传给当前真实provider，不能仅更新视觉却保留过期数据用途承诺。                                                                                                                                                                                                                                          | source_fixed_runtime_pending                      |
| I23 | P2   | iOS 卡片撤销，`apps/ios/SoloCompass/Views/Chat/UndoPill.swift:27`                                                                                       | caption2+vertical4的撤销pill无44pt目标；时限内才出现，辅助技术在读完卡片前可能消失。补命中区；为VoiceOver延长或提供持续可达的撤销路径，避免只加hint却无法及时执行。                                                                                                                                                                                                                                                                                                                           | source_fixed_runtime_pending                      |
| I24 | P1   | iOS 消息发送失败丢草稿，`apps/ios/SoloCompass/Views/Chat/AttachmentInputBar.swift:190`；`Companion/ChatView.swift:196`；`Services/ChatService.swift:72` | 输入栏调用Void onSend后立即清空文字/附件，父层只是启动异步发送；鉴权、网络、纯附件上传失败后没有恢复草稿。使用明确异步结果/待发送草稿；仅实际发送的部分清除。尤其当前上传失败会继续发送纯文字，不能以lastError!=nil简单恢复并重发整条导致文字重复；分开表达textSentAttachmentsFailed。使用fake服务验证，不向真实联系人发验收消息。                                                                                                                                                            | source_fixed_runtime_pending                      |
| I25 | P1   | iOS 扫码权限生命周期，`apps/ios/SoloCompass/Views/Friends/QRScannerView.swift:108`                                                                      | 相机授权回调获准即configure+start，没有可见性/scenePhase/token守卫；viewWillDisappear虽停止session，晚到授权仍可能在被保留的隐藏控制器上重新启动。显式跟踪可见/前台、序列化start/stop并使过时授权失效；模拟迟到授权和离开/后台，session不可再启动。                                                                                                                                                                                                                                           | source_fixed_runtime_pending                      |
| I26 | P2   | iOS 添加好友失败反馈，`apps/ios/SoloCompass/Views/Friends/AddFriendButton.swift:145`                                                                    | send忽略服务Result；失败后仅取消isSending，原按钮恢复无失败原因/重试说明。提供错误并保留recipient，busy明确且防重复；成功状态由真实关系读回；紧凑样式亦需44pt命中区。                                                                                                                                                                                                                                                                                                                         | source_fixed_runtime_pending                      |

### 法律目的地：实际落点不对应政策正文，正式URL待提供

`TermsConsentSheet.swift:90` 指向 `/privacy` 与 `/terms`。2026-10-16（Asia/Shanghai），根代理实际IAB只读渲染确认：[terms](https://solocompass.app/terms) 与 [privacy](https://solocompass.app/privacy) 均是营销落地页，H1为“Explore the world without sensory collapse.”、页脚ND3 Studio，没有对应条款/政策正文。[APP_STORE_METADATA引用的旧隐私地址](https://solo-compass.vercel.app/privacy) 显示Vercel 404 `DEPLOYMENT_NOT_FOUND`。

此前HTTP200/相同SPA壳只证明壳可返回，不能证明政策有效；现有实际渲染证据已补足。根代理已询问用户两条正式URL，当前标为`pending_authoritative_urls`。本轮不编造条款，也不把营销页当政策页；实际政策内容及其法律充分性未在此审查中评定。

## 应保留的基础

- `WorkspaceDock` 的地图/问问/发现有真实 Button、44pt 最小目标、选中语义；中间入口继续使用 Solo 品牌角色。
- `ConversationPanel` 将抓手、内容、Dock 分开，抓手44pt且提供 default/adjustable action；保留导航连续性，避免为美观重建地图或清空聊天。
- `ChatSheet` 已在隐藏、离开及后台时 hibernate voice，并在权限返回后检查工作空间及 scenePhase；本轮不得削弱这些守卫。
- `ItineraryFormView` 有存储失败提示、保留输入、脏状态防误划关闭及城市搜索；应按真实行为补证据。
- `DiscoverWorkspaceView` 从真实 Experience/Route 构建页面，有离线与重试入口；不能用装饰性假推荐填空。

## 视觉审查的具体方向

| 表面               | 更有品味的方向                                                | 应减少的噪声                                                   | 需要截图才能判断                                     |
| ------------------ | ------------------------------------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------- |
| iOS 地图与工作空间 | 地图提供位置关系，Dock 提供稳定导航，对话面板呈现当前任务     | 多套发光、状态条、重复地点标题争夺视线                         | 地图顶栏/底栏重叠、首屏有效地图面积、暗色玻璃可读性  |
| iOS 详情操作       | 保存/已到访用稳定状态；加入行程作为具体主动作；次动作名称可见 | 全部动作都用强调色、每按都庆祝或震动                           | 大字时四个动作是否仍能完整阅读；主操作是否压过内容   |
| iOS 输入           | 文字是稳定入口，语音可发现且可停止，发送明确确认              | “思考中”多处同时闪动、焦点描边过轻或过亮                       | 键盘上方间距、录音状态读屏、明暗对比、动态字体换行   |
| 官网               | 以真实旅行决定/地图场景作为记忆点，页面节奏支持阅读和试用     | 每节眉题、满屏 mono uppercase、无动作卡片 hover 上浮、重复边框 | 首屏是否像旅行产品；手机样机是否与在用的原生产品一致 |
| Web 研究页         | 列表与地图联动，筛选/选中状态清楚且能分享                     | 内部 Scenario A/B/C/D 标记、装饰数据、依赖 hover 才看见的行动  | 双栏密度、窄屏换行、详情关闭后焦点与滚动位置         |

“符合用户观感”需要从实际信息和状态判断：轻边框用于分区；明显边框保留给键盘焦点、当前选中或需修正的输入；不把每张静态卡片都做成会浮起的可点击暗示。所有纯装饰纹理/地图细线须不抢正文对比度，并对辅助技术隐藏。

### iOS 首屏基线实图观察

证据：`evidence/ios-before-map.png`、`evidence/ios-before-ask.png`，基线924f09a4，Primary iPhone、iOS26.5；根代理报告build-for-testing通过，并实际执行地图→问问→地图，AX和截图确认工作空间状态保留。这只验证该基线切换，不是新版通过，也不是全部功能验证。

1. **地图顶部需要合并层级。** 地图图中城市胶囊/三个图标、过滤条、“我的收藏/我的行程”两个大白块、中央诊断卡连续占据上方约四成；收藏在过滤条和大快捷卡重复，问Solo在过滤条、诊断卡和底部Dock重复。保留“城市+个人入口”与一条筛选，收藏/行程在发现的固定入口承担业务；避免再加一个浮层承诺。需要保留快捷方式时缩成一行轻入口，不能像两个主CTA压住地图。
2. **诊断反馈应给能执行的恢复。** 当前最大深色按钮是“问Solo怎么修”，卡片同时说AI未接上；问问页面又显示“聊天尚未配置”，没有就地设置动作。视觉注意力被吸走，恢复仍需用户自己找设置。把相关状态聚到输入区一处，提供准确的设置/登录目的地；地图保留轻状态与关闭，不让开发式诊断成为旅行主任务。
3. **底部Dock有清楚记忆点，应保留。** 地图/问问/发现的标签、Solo角色与选中底色清楚，触控间距充分。地图状态的抓手到Dock有一段空白面板，用户未看到可展开的内容；可收紧折叠高度并明确抓手展开结果，但不牺牲安全区或语音长按目标。不要把角色再叠上额外光环和徽章。
4. **问问空态只需一个内容焦点。** 三条建议完整可读且动作方向一致，是现有优点。顶部抓手和历史/收起行之间的空白较厚；保持地图作为空间线索后，可将历史与收起合到一条轻标题行，减少面板装饰带。未配置提示应成为可执行入口；不依靠说明文字要求用户绕到个人页再找。
5. **边框和强调色要承担状态。** 白色大快捷卡、输入框、过滤胶囊、Dock已形成多套边界。下一版应让填充/描边只区分当前选择、输入焦点和需要处理的错误，降低非活动卡片的边界；地图标记与正文对比优先。改动是否更安静、更清楚须用同尺寸A/B确认，不给绝对“品味分”。

截图未覆盖暗色、大字、键盘打开、详情操作、录音、网络失败、权限或其他功能族；这些维度继续unknown。具体功能评分范围与扣分记录见scorecard，不把两张首屏图扩展成全App视觉通过。

## 证据缺口与冻结复核

待根代理提供：冻结 head / 改动 diff、Web 移动/桌面截图、iOS Primary iPhone 核心路径截图、相关测试输出与实际点击记录。审查者不另行启动浏览器、构建或模拟器，避免抢占共享资源。

需要实测的最小 iOS 状态：地图初始与返回、Ask Solo 输入/发送/失败/重试、录音权限允许/拒绝/后台停止、附件删除、收藏/到访/加入行程、发现排序、城市切换、同行可见性恢复、偏好读回；增加暗色与必要大字状态。Web 需覆盖移动导航、下载落点、键盘命令面板、文字/语音切换、签到失败重试和抽屉关闭。

盘点已提供44个功能族（W01–W17、I01–I27）；逐源候选会随漏项补全更新。候选包含条件分支、呈现关系与数据驱动模板，不能把候选行数直接当真实按钮数量。scorecard将对齐这些稳定ID，保留每个候选的 `not_verified`，不以功能族平均分代替逐项通过。最终审查必须说明多少项已验证、多少项仅源码审查，以及仍不能诚实声称96分的原因。

## 基线功能评分区间（逐族，不取平均）

这些数值是对已抽样基线路径的功能观察区间，不是对全部按钮的最终评分。逐维扣分及finding ID记录在scorecard.json：已确认缺陷降低该维上界；源码抽样维度下界额外留2分（触控/键盘3分）不确定性；unknown维度按0到权重计。上界100或98仅是尚未排除的数学可能，不能当作通过。视觉品味只作A/B相对判断。

| ID  | 功能族                    | 基线暂定功能范围 | 有观察的维度权重 | unknown权重 |
| --- | ------------------------- | ---------------: | ---------------: | ----------: |
| W01 | 官网 EN/ZH 导航           |      19–45 / 100 |         85 / 100 |    15 / 100 |
| W02 | 官网 Hero/功能/信任/页脚  |      18–42 / 100 |         85 / 100 |    15 / 100 |
| W03 | 定价 EN/ZH                |      21–47 / 100 |         85 / 100 |    15 / 100 |
| W04 | 宣言 EN/ZH                |      47–73 / 100 |         85 / 100 |    15 / 100 |
| W05 | 隐私 EN/ZH                |      35–59 / 100 |         85 / 100 |    15 / 100 |
| W06 | 下载                      |      21–47 / 100 |         85 / 100 |    15 / 100 |
| W07 | 共享 Web 控件             |      58–86 / 100 |         85 / 100 |    15 / 100 |
| W08 | /app 地图                 |     64–100 / 100 |         75 / 100 |    25 / 100 |
| W09 | /app 附近和足迹           |      48–76 / 100 |         85 / 100 |    15 / 100 |
| W10 | /app 今日                 |      50–86 / 100 |         75 / 100 |    25 / 100 |
| W11 | /app 语音/文本意图        |      54–82 / 100 |         85 / 100 |    15 / 100 |
| W12 | /app 体验详情             |      37–73 / 100 |         75 / 100 |    25 / 100 |
| W13 | /[city] 城市工作台        |      20–46 / 100 |         85 / 100 |    15 / 100 |
| W14 | 城市命令面板              |      57–85 / 100 |         85 / 100 |    15 / 100 |
| W15 | /mobile-preview           |      0–100 / 100 |          0 / 100 |   100 / 100 |
| W16 | /experience/[id] 分享体验 |      52–88 / 100 |         75 / 100 |    25 / 100 |
| W17 | /trip/[slug] 分享行程     |      50–86 / 100 |         75 / 100 |    25 / 100 |
| I01 | 地图主场景/城市           |      63–86 / 100 |         90 / 100 |    10 / 100 |
| I02 | 稳定导航/发现             |      70–93 / 100 |         90 / 100 |    10 / 100 |
| I03 | 探索工作流                |      61–89 / 100 |         85 / 100 |    15 / 100 |
| I04 | 保留对话/历史             |      75–98 / 100 |         90 / 100 |    10 / 100 |
| I05 | 对话输入/附件             |      49–62 / 100 |        100 / 100 |     0 / 100 |
| I06 | 语音                      |      57–85 / 100 |         85 / 100 |    15 / 100 |
| I07 | AI 卡片/撤销/诊断         |      59–87 / 100 |         85 / 100 |    15 / 100 |
| I08 | 体验卡/预览               |     64–100 / 100 |         75 / 100 |    25 / 100 |
| I09 | 体验详情主动作            |      48–84 / 100 |         75 / 100 |    25 / 100 |
| I10 | 体验新增/修正/反馈        |      64–92 / 100 |         85 / 100 |    15 / 100 |
| I11 | 体验分享/导出             |      53–81 / 100 |         85 / 100 |    15 / 100 |
| I12 | 行程列表/创建             |     64–100 / 100 |         75 / 100 |    25 / 100 |
| I13 | 行程详情                  |      44–80 / 100 |         75 / 100 |    25 / 100 |
| I14 | 路线创建/详情             |      0–100 / 100 |          0 / 100 |   100 / 100 |
| I15 | 路线招募/申请             |      35–71 / 100 |         75 / 100 |    25 / 100 |
| I16 | 同伴发现/安全             |      48–76 / 100 |         85 / 100 |    15 / 100 |
| I17 | 同伴资料/消息             |      37–73 / 100 |         75 / 100 |    25 / 100 |
| I18 | 路线分享                  |      54–90 / 100 |         75 / 100 |    25 / 100 |
| I19 | 好友入口/邀请/扫码        |      40–75 / 100 |         75 / 100 |    25 / 100 |
| I20 | 我的/权益                 |     64–100 / 100 |         75 / 100 |    25 / 100 |
| I21 | 设置及子页                |      51–78 / 100 |         85 / 100 |    15 / 100 |
| I22 | 首次使用/条款             |     64–100 / 100 |         75 / 100 |    25 / 100 |
| I23 | 付费                      |      46–74 / 100 |         85 / 100 |    15 / 100 |
| I24 | 今日/城市工具             |      62–90 / 100 |         85 / 100 |    15 / 100 |
| I25 | 仪式/归档                 |      14–36 / 100 |         85 / 100 |    15 / 100 |
| I26 | 管理/共享反馈组件         |     64–100 / 100 |         75 / 100 |    25 / 100 |
| I27 | 信任解释/独行评分         |      0–100 / 100 |          0 / 100 |   100 / 100 |

盘点版本现有44功能族、892源候选；22个候选源码分支有精确缺陷证据，全部892个候选仍未获得新版运行通过证据。41个功能族的观察是局部或共享组件证据，不代表任何功能族已完整覆盖全部状态。

## 第一批冻结快照复核（snapshot-01）

**19/19文件SHA在复核开始及结束均匹配。** 基线924f09a4；补丁SHA-256：`0c71706b0dc6f0722894bf44ce87f3111a65515b69b1bdb5c09fd31b79b374cf`。清单为`/private/tmp/ai-test-interaction-quality.0Igzij/snapshot-01-files.json`，完整SHA记录在scorecard.partialReviews；只审integration worktree这19个冻结文件，不审Pi其后修改。

构建日志明确`TEST BUILD SUCCEEDED`。测试日志/xcresult实际只有VisibilityOffRecoveryTests三例通过（3 passed、0 failed，Primary/iOS26.5），验证纯恢复决策的无意图/仍关闭/已开启三个分支；**不等同实际导航回读通过**。Pressable过滤仍用了旧类名PressableButtonStyleHapticTest，文件内类已改为PressableButtonStyleFeedbackTests，未执行，不能称通过。新版截图、触控外沿、VoiceOver、购买恢复并发和故障注入均未验证。

| 基线问题         | 本批判断                     | 已确认的源码事实                                                                                   | 仍需证据                                                             |
| ---------------- | ---------------------------- | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| I01 录音停止     | source_fixed_runtime_pending | 录音条改为真实Button，执行onMicToggle(false)，44pt高度；没有削弱ChatSheet生命周期守卫              | VoiceOver启动→停止；允许/拒绝/后台；新hint资源C02                    |
| I02 暗色输入     | source_fixed_runtime_pending | 聚焦填充改CT.cardAdaptive                                                                          | 明暗聚焦截图及光标/文字对比                                          |
| I03 照片删除     | partial_source_fix           | 删除目标44pt、加入索引格式标签                                                                     | 新label key缺失（C02）；读屏删除哪张及删除后索引                     |
| I04 发现排序     | source_fixed_runtime_pending | Menu标签扩展44pt并在frame后设置shape                                                               | 外沿触控、实际选中排序/结果读回                                      |
| I05 个人设置恢复 | source_fixed_runtime_pending | 真实MyProfileEditView呈现；onDismiss按pending intent和当前visibility决定恢复；仅三例纯决策测试通过 | Alert→sheet→Done→继续创建的实际呈现；取消/保持关闭不发布             |
| I06 类别偏好     | partial_source_fix           | 真实Button；偏好状态value；隐藏恢复44pt                                                            | 新状态/恢复标签缺资源C02；读屏与持久化                               |
| I07 正负坐标     | source_fixed_runtime_pending | numbersAndPunctuation可输入负号；N/S/E/W切换镜像符号；逗号归一化；越界保留pin并设错误              | 方向/错误资源C02；真实正负、越界、小数与地图位置                     |
| I08 购买恢复     | partial_source_fix           | 恢复有busy guard和无购买/失败分支                                                                  | C01双向互斥、C03清旧错误、C02文案；不能只测RestoreOutcome纯映射      |
| I09 付费语义     | partial_source_fix           | 试用资格默认unknown；价格/周期AX格式与selected trait已接线                                         | 全套新价格/周期key缺失C02，当前AX仍不能读价格；StoreKit未知/已知资格 |
| I10 举报原因     | source_fixed_runtime_pending | 原因改Button，selected trait和值                                                                   | common.selected缺资源C02；真实读屏及提交不扩权                       |
| I11 分享预览     | partial_source_fix           | 44pt模式、选中trait；catch后失败UI和真实重试；提交渲染前检查style/cancel                           | 错误/重试key缺资源C02；注入渲染失败、快速切换与实际分享载荷          |
| I18 核实问答     | source_fixed_runtime_pending | ScrollView、medium/large、44pt关闭与选项、答案仍由State保存                                        | 大字滚动、选项读回、未答禁用/完整提交；common.selected资源C02        |

其他34个基线问题仍open。I21仍open：本批修改的是Experience/Share/ShareSheet，原问题位于Companion/RouteShareSheet，不能因注释提到I21就记修复。I24消息草稿丢失也仍open，本批AttachmentInputBar只改按压尺度。

共享按压样式默认0.97，明确移除isPressed下降沿haptic，因此代码不再将取消按压误当提交震动；动作级提交haptic保持由调用者管理。这是可确认的源码改进。未执行的Pressable测试只检查策略值/常量，即使后续运行通过，也不替代真实触摸取消验收。

| 新检查项 | 级别/状态      | 本批事实和必要修复                                                                                                                                                                                                                         |
| -------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| C01      | P2 open        | PaywallView:422购买CTA只看purchaseInFlight；runPurchase:501无restoreInFlight入口guard，恢复期间仍可购买。购买/恢复必须双向互斥，恢复忙碌状态须可辨认。                                                                                     |
| C02      | P2 open        | 本批新增27个NSLocalizedString key在en和zh-Hans均缺失且无value fallback。照片删除、坐标方向、已选、方案价格/周期、恢复和分享错误均会显示/读出原key；完整清单在scorecard.checkpointFindings。补资源及格式校验后才能关闭对应可理解性/AX问题。 |
| C03      | P2 open        | SubscriptionService.restorePurchases未清旧lastError；RestoreOutcome会把旧购买/网络失败误作本次无购买恢复失败。返回本次结构化结果或在操作开始隔离旧错误，验证先失败→再正常无购买。                                                          |
| C04      | P2 source risk | ConfidenceBadge contentShape位于44pt frame之前；新增透明区域未明确纳入shape。把shape放扩展frame后，实点外沿确认popover。尚未把“布局44pt”当触控已通过。                                                                                     |

本批无新P0/P1源码回归证据；上述P2与资源缺口需要下一批补齐。已修源码与未测交互分开记，不因构建或三例测试通过把全部功能上调96。

本批改变的功能族暂定区间（仍为源码抽样范围，不能充当达标结论）：

| ID  | 功能族             | 基线范围 | snapshot-01源码观察范围 |
| --- | ------------------ | -------: | ----------------------: |
| I01 | 地图主场景/城市    |    63–86 |                   74–89 |
| I02 | 稳定导航/发现      |    70–93 |                   74–97 |
| I05 | 对话输入/附件      |    49–62 |                   63–78 |
| I06 | 语音               |    57–85 |                  72–100 |
| I10 | 体验新增/修正/反馈 |    64–92 |                   69–97 |
| I11 | 体验分享/导出      |    53–81 |                   63–91 |
| I13 | 行程详情           |    44–80 |                  64–100 |
| I16 | 同伴发现/安全      |    48–76 |                   56–84 |
| I21 | 设置及子页         |    51–78 |                   59–87 |
| I23 | 付费               |    46–74 |                   53–81 |
| I24 | 今日/城市工具      |    62–90 |                   69–97 |
| I27 | 信任解释/独行评分  |    0–100 |                   0–100 |

## 原生完整冻结快照复核（snapshot-03）

**51/51文件SHA在复核开始及结束均匹配**；完整补丁SHA-256为`c962cf1135d3d3e7708dbd3f876ef1a302694c77e2a95bbc29fa8087fa1c843c`。清单：`/private/tmp/ai-test-interaction-quality.0Igzij/snapshot-03-files.json`。源码逐文件SHA已保存到scorecard.partialReviews。snapshot-02首次编译失败原因是越过`lastError private(set)`；02b通过是历史证据，不能套到03。**03构建及11类80项逻辑测试已通过（80 passed、0 failed、0 skipped）；新版渲染与交互仍待补证**；本报告未启动额外构建、模拟器或浏览器。

下表是26个原生基线问题的最新判断；均为源码修正，运行状态统一`not_verified`。I14消除假动作采用了诚实预览/只读范围，不代表启动/分享/回复/解锁能力已实现。基线评分表保留原值；新版源码范围另列，避免抹掉before和风险历史。

| 问题 | 冻结源码证据                                                                                   | 已修内容                                                                                                                                                 | 必要运行验收                                                                     |
| ---- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| I01  | `ChatInputBar.swift:294–322`                                                                   | 录音条为真实Button、44pt、明确停止名称/hint；可执行onMicToggle(false)。                                                                                  | VoiceOver开始→停止；拒绝、离开、后台停止。                                       |
| I02  | `ChatInputBar.swift:458`                                                                       | 聚焦填充改CT.cardAdaptive，附件输入亦用系统暗色表面。                                                                                                    | 明暗聚焦文字/光标/边框截图。                                                     |
| I03  | `CreateExperienceSheet.swift:164–185`                                                          | 照片删除44pt，带索引格式名称；en/zh-Hans资源均存在。                                                                                                     | 外沿点按、读出哪张照片、删除后索引。                                             |
| I04  | `DiscoverWorkspaceView.swift:184–212`                                                          | 排序Menu标签44pt，shape位于扩展frame后。                                                                                                                 | 外沿点按、排序选择与实际结果。                                                   |
| I05  | `ItineraryDetailView.swift:173–194,338–354`                                                    | 真实MyProfileEditView；保存/取消返回后依据pending intent及当前visibility恢复或保持阻断。                                                                 | Alert→设置→Done→创建实际呈现；取消/保持关闭。                                    |
| I06  | `SettingsView.swift:930–1000`                                                                  | 类别行改Button，偏好/隐藏语义完整；隐藏恢复44pt且有名称，资源已补。                                                                                      | VoiceOver操作与持久化、列表滑动。                                                |
| I07  | `LocationPickerSheet.swift:374–393,736–828`                                                    | 有符号键盘、N/S/E/W切换、逗号归一化与越界错误；无效坐标不提交pin。                                                                                       | 南纬/西经、越界、逗号小数、地图实际落点。                                        |
| I08  | `PaywallView.swift:88,427,484–490,505–575; SubscriptionService.swift:328–337`                  | 购买/恢复双向guard和disabled；本次恢复开始清旧lastError；成功/无权益/失败有明确结果。                                                                    | StoreKit真实无权益/失败/重复点按；先失败再正常无权益。                           |
| I09  | `PaywallView.swift:79,301–407`                                                                 | 资格默认unknown；价格/周期/selected进入AX；中英周期和价格格式资源齐全。                                                                                  | StoreKit资格未知/已知、完整价格读屏与不同币种。                                  |
| I10  | `ReportBlockSheet.swift:97–120`                                                                | 原因行改Button、selected trait/value，资源齐全。                                                                                                         | 读屏选择、取消、真实提交成功/失败。                                              |
| I11  | `Experience/Share/ShareSheet.swift:101–201`                                                    | 模式44pt/selected；渲染失败有解释和真实retry；过时style/cancel不提交。                                                                                   | 故障渲染、快速切换、系统分享与复制载荷。                                         |
| I12  | `CapsuleComposeView.swift:44–146`                                                              | trim校验、编辑器名称/本地化、取消确认/禁止脏稿划走；Bool保存结果控制关闭。                                                                               | 纯空格、编辑取消、键盘与大字、保存失败草稿。                                     |
| I13  | `CapsuleOpenView.swift:26,50–108; BlindboxLaunchView.swift:45; OmenCardView.swift:11–31`       | 胶囊/盲盒内容滚动、稳定44pt动作；胶囊/签文尊重Reduce Motion；操作本地化。                                                                                | 长正文/大字可达、减弱动态效果实际呈现。                                          |
| I14  | `ArchiveView.swift:157–168,205–279,684–746`                                                    | 未接通仪式动作禁用；整体明确预览且真实Close；真实胶囊/Codex改只读说明并保留AX文本。                                                                      | 预览身份是否足够清楚；真实记录读屏、滚动和关闭。                                 |
| I15  | `ArchiveView.swift:258–272; ArchiveCodexEntryBuilder`                                          | Codex仅从真实visit建条目、真实日期；无成熟胶囊显示空态，不再造90天前个人历史。                                                                           | 无记录新用户、真实多城市/日期、读屏正文。                                        |
| I16  | `ExperienceDetailView.swift:315–337`                                                           | bury失败return false并保留编辑器，成功才本地化提示/关闭。                                                                                                | 注入存储失败→重试、成功仅保存一次。                                              |
| I17  | `AIProviderSettingsView.swift:34–63,173–177`                                                   | provider改Button/selected；key保存与连接验证分开说明。                                                                                                   | 读屏切换、保存/清除、文案不泄露key。                                             |
| I18  | `VerifySheet.swift:30,63,100,134`                                                              | ScrollView、medium/large与44pt关闭/选项；答案仍保存在State。                                                                                             | 大字、滚动、已选读回、全答前后提交。                                             |
| I19  | `JoinRouteRequestSheet.swift:54–63,261–299`                                                    | trim后最小长度；同步busy guard；失败保留pace/message并解释，只有成功关闭。                                                                               | fake成功/NotImplemented/网络失败；重复提交。                                     |
| I20  | `RequestInboxView.swift:90–115,205–211`                                                        | 接受成功可打开真实conversation导航；acceptingRequestID同步守卫。                                                                                         | 接受→打开对话的真实导航；取消确认、错误与重复。                                  |
| I21  | `RouteShareSheet.swift:58,124–152`                                                             | 稳定父层task覆盖所有style；开始即失效token/clear busy，cached/text不遗留busy；缓存使用冻结style。                                                        | 已缓存trace→慢map→trace/text，最终预览/导出一致。                                |
| I22  | `ExploreConsentSheet.swift:26–110; en/zh-Hans explore.consent.bullet.*`                        | 滚动内容、44pt取消/52pt继续、深色文字配金底；实际资源准确说明选定坐标/半径→Overpass、公开地点/城市→配置AI。                                              | 大字/暗色、取消无请求/接受后请求，核对实际传输范围。                             |
| I23  | `UndoPill.swift:23–58; ProvisionalCardLedger.swift:85–105; VoiceAgentOrchestrator.swift:26–29` | 撤销44pt；真实ledger append时读取VoiceOver状态，60s或普通3s；1秒Timeline替代10Hz。                                                                       | VoiceOver朗读后可撤销、截止边界、实际提交/撤销无重复。                           |
| I24  | `AttachmentInputBar.swift:18–24,55–63,227,253–345; ChatService.swift:18–32,94–184`             | 明确SendOutcome；整条失败保留草稿，超长拒绝不截断；部分成功附件进入独立retryIDs批次；retry无text参数并强制空text，不读/清新草稿；仅清已发送ID/相等文字。 | 延迟/失败/鉴权/部分成功、晚到附件/外部草稿与重复点击；实际输入栏状态仍需UI验证。 |
| I25  | `QRScannerView.swift:72–90,136–202,238–262`                                                    | 授权/可见/前台共同gate；晚回调检查可见；排队start执行时再查gate；FIFO start/stop，dismantle关停。                                                        | 真实迟到授权、离开/后台、拒绝后恢复；gate单测不等同相机会话验证。                |
| I26  | `AddFriendButton.swift:60–100,160–183`                                                         | 处理Result并显示失败、忙碌状态；44pt目标，不再吞失败。                                                                                                   | 三种外观的失败/重试与关系读回，Menu中错误可见性。                                |

独立复核在snapshot-02发现两项P1回归，已要求返工并在03关闭源码问题：真实Archive内容被整树AX隐藏；部分成功后的附件重试可能重复已送达文字。另两项P2是路线分享缓存切换遗留busy，以及探索同意只改注释未改实际资源。关闭依据如下，**不是实测通过**。

| 检查项 | 最新状态                     | snapshot-03关闭依据                                                                                                |
| ------ | ---------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| C01 P2 | source_fixed_runtime_pending | Paywall isStoreBusy与runPurchase/runRestore双向guard；恢复期间购买亦禁用。                                         |
| C02 P2 | source_fixed_runtime_pending | en/zh-Hans新增key齐全；本批新增NSLocalizedString字面引用均存在、format占位符匹配。                                 |
| C03 P2 | source_fixed_runtime_pending | SubscriptionService.restorePurchases入口lastError=nil；View使用本次返回后的error，不比较历史字符串。               |
| C04 P2 | source_fixed_runtime_pending | ConfidenceBadge先扩展44pt frame再contentShape。                                                                    |
| C05 P1 | source_fixed_runtime_pending | snapshot-03取消AX隐藏；胶囊/Codex用只读记录说明，真实Close保持可用。                                               |
| C06 P1 | source_fixed_runtime_pending | snapshot-03 retryIDs隔离常规发送；AttachmentRetryBatch无text参数并强制空text；输入提交期禁编辑，按ID选择性清除。   |
| C07 P2 | source_fixed_runtime_pending | snapshot-03已按契约调整；cached/text不再遗留旧busy。                                                               |
| C08 P2 | source_fixed_runtime_pending | snapshot-03实际资源已说明坐标/半径→OSM/Overpass、公开地点/城市→configured AI（默认DeepSeek），范围限定为本次查询。 |

附件新增延迟fake测试会暂停真实`ChatService`上传流程，模拟文字成功/附件失败，再调用生产`AttachmentRetryBatch`重试，并断言写入正文为旧文字与空文字各一次。它比只判断enum不同更有用，但仍未覆盖SwiftUI输入栏的晚到附件、外部新草稿和实际操作；这些不因服务测试通过而记UI验收通过。相机测试使用生产`ScannerCaptureGate`，只能验证启动准入策略，不能替代真实权限回调/相机会话的生命周期验收。

地图/滤栏源码已把收藏与行程大行收为44pt Menu，保留Discover入口；滤栏44pt/单选语义、去持续脉冲和冗余边缘；诊断卡分离关闭与恢复动作，并自适应更大字。它们回应基线注意力问题，但无after渲染前只记`source_changed_visual_not_verified`，不声称品味或层级已达96。

当前原生逐功能族源码观察范围如下。81个相对baseline新引用的字面本地化key在中英资源均存在，未发现重复key或format不一致。上界只是未排除的数学可能；层级均因缺新版渲染而unknown。每项剩余运行证据和逐维扣分在scorecard中；预览能力仍按未完成原动作扣分，首次使用/付费族保留当前法律目的地缺口扣分。范围变宽也可能来自新版层级无截图而回到unknown，不等同功能回归。没有功能族可凭此区间认证大于96。

| ID  | 功能族             | baseline | snapshot-03源码范围 | 已观察维度权重 | unknown权重 |
| --- | ------------------ | -------: | ------------------: | -------------: | ----------: |
| I01 | 地图主场景/城市    |    63–86 |              64–100 |         75/100 |      25/100 |
| I02 | 稳定导航/发现      |    70–93 |              64–100 |         75/100 |      25/100 |
| I03 | 探索工作流         |    61–89 |              72–100 |         85/100 |      15/100 |
| I04 | 保留对话/历史      |    75–98 |              64–100 |         75/100 |      25/100 |
| I05 | 对话输入/附件      |    49–62 |              72–100 |         85/100 |      15/100 |
| I06 | 语音               |    57–85 |              72–100 |         85/100 |      15/100 |
| I07 | AI 卡片/撤销/诊断  |    59–87 |              72–100 |         85/100 |      15/100 |
| I08 | 体验卡/预览        |   64–100 |              64–100 |         75/100 |      25/100 |
| I09 | 体验详情主动作     |    48–84 |              64–100 |         75/100 |      25/100 |
| I10 | 体验新增/修正/反馈 |    64–92 |              72–100 |         85/100 |      15/100 |
| I11 | 体验分享/导出      |    53–81 |              72–100 |         85/100 |      15/100 |
| I12 | 行程列表/创建      |   64–100 |              64–100 |         75/100 |      25/100 |
| I13 | 行程详情           |    44–80 |              64–100 |         75/100 |      25/100 |
| I14 | 路线创建/详情      |    0–100 |               0–100 |          0/100 |     100/100 |
| I15 | 路线招募/申请      |    35–71 |              64–100 |         75/100 |      25/100 |
| I16 | 同伴发现/安全      |    48–76 |              72–100 |         85/100 |      15/100 |
| I17 | 同伴资料/消息      |    37–73 |              64–100 |         75/100 |      25/100 |
| I18 | 路线分享           |    54–90 |              64–100 |         75/100 |      25/100 |
| I19 | 好友入口/邀请/扫码 |    40–75 |              64–100 |         75/100 |      25/100 |
| I20 | 我的/权益          |   64–100 |              64–100 |         75/100 |      25/100 |
| I21 | 设置及子页         |    51–78 |              72–100 |         85/100 |      15/100 |
| I22 | 首次使用/条款      |   64–100 |               56–92 |         75/100 |      25/100 |
| I23 | 付费               |    46–74 |               64–92 |         85/100 |      15/100 |
| I24 | 今日/城市工具      |    62–90 |              72–100 |         85/100 |      15/100 |
| I25 | 仪式/归档          |    14–36 |               58–86 |         85/100 |      15/100 |
| I26 | 管理/共享反馈组件  |   64–100 |              64–100 |         75/100 |      25/100 |
| I27 | 信任解释/独行评分  |    0–100 |              17–100 |         20/100 |      80/100 |

本轮不以平均值补偿未完成项：892个候选仍未取得新版运行通过证据；Web20项实现尚未冻结复核；原生法律目的地待正式URL；VoiceOver、明暗、大字、拒绝/失败/返回路径仍需实测。功能分与视觉A/B判断保持分开。

### snapshot-03 实际构建及逻辑测试证据

冻结51文件再次与永久SHA清单匹配。完整`build-for-testing`日志第7346行明确`TEST BUILD SUCCEEDED`；随后`test-without-building`在Primary iPhone / iPhone 17 Pro / iOS26.5实际执行11类80项：**80通过、0失败、0跳过，约218秒**。reviewer只读xcresult逐类读回，确认不是空过滤。永久证据：[检查点说明](/Users/cubxxw/.codex/worktrees/interaction-quality/solo-compass/docs/design/interaction-quality/evidence/checkpoint-03.md)、[xcresult汇总](/Users/cubxxw/.codex/worktrees/interaction-quality/solo-compass/docs/design/interaction-quality/evidence/checkpoint-03-tests.json)、[文件SHA](/Users/cubxxw/.codex/worktrees/interaction-quality/solo-compass/docs/design/interaction-quality/evidence/snapshot-03-files.json)。原始xcresult位于本任务临时产物区；11类和80项case读回结果已保存scorecard，避免清理临时产物后丢失范围说明。

| 测试类                            | 实际通过数 | 可支持的结论与边界                                                                               |
| --------------------------------- | ---------: | ------------------------------------------------------------------------------------------------ |
| ArchiveCodexEntryTests            |          5 | 真实记录构造器逻辑；不覆盖Archive视图、VoiceOver正文可读或预览理解。                             |
| ChatAttachmentTests               |         11 | 附件模型/上传降级及服务逻辑；不覆盖真实照片选择器或输入栏交互。                                  |
| ChatSendOutcomeTests              |          9 | 真实ChatService经fake边界及生产AttachmentRetryBatch；不覆盖SwiftUI草稿绑定清理、晚到附件或手势。 |
| FilterBarViewTests                |         10 | 分类偏好、pill次序/计数/切换决策；不覆盖真实点击、单选读屏或布局。                               |
| JoinRequestValidationTest         |         12 | trim/长度/必填/提示纯验证；不覆盖远程申请成功/失败界面和关闭行为。                               |
| PressableButtonStyleFeedbackTests |          3 | 按压尺度/反馈策略值；不覆盖真实拖出取消触感。                                                    |
| ProvisionalCardLedgerTests        |         16 | 生产ledger截止时间/撤销状态；不覆盖真实VoiceOver朗读与操作时间。                                 |
| RestoreOutcomeTests               |          4 | 恢复结果纯映射/消息区别；不覆盖StoreKit、并发互斥或真实旧错误再恢复序列。                        |
| ScannerCaptureGateTests           |          3 | 生产gate可见/前台/授权策略；不覆盖AVCaptureSession真实迟到授权与后台会话。                       |
| TopOverlayLayoutTest              |          4 | MapOverlayMetrics常量矩形/44pt模型；不覆盖实际SwiftUI大字测量或渲染。                            |
| VisibilityOffRecoveryTests        |          3 | 恢复决策纯分支；不覆盖alert/sheet/Done实际导航。                                                 |

Pressable本轮真实执行的是`PressableButtonStyleFeedbackTests`三例；snapshot-01旧类名过滤未运行的历史记录保持不变。附件部分成功→独立重试的延迟fake测试已实际通过，确认生产重试批次向真实ChatService提交空文字，不重复旧正文；没有把这个服务断言外推为输入栏所有草稿状态已实测。恢复测试是`RestoreOutcome`映射，仍不能声称真实StoreKit错误/并发周期通过；布局测试使用常量模型，也不能代替大字实图。

本次只提升相应逻辑分支证据，不改变原生候选`runtimeStatus=not_verified`，不把VoiceOver、触感、明暗或全部交互记通过。功能区间与视觉状态保持原值，等待匹配此冻结版本的实际界面证据。

## snapshot-03之后：暗色/大字局部改动初审（尚未冻结）

根代理在03暗色AXXXL发现城市棕字不清、未配置banner挤占输入区、Dock固定76pt预留不足，随后提交局部修复供初审。此时尚无04 manifest/编译/截图；本节只绑定读取时8文件SHA（scorecard.inProgressReviews）。**snapshot-03的80项通过不覆盖此批新源码**；其他原生修正仍保留03历史结论。

设置恢复调用链已源码核实：`CompassMapView:1293–1298`仅在关闭设置且orchestrator为unconfigured时调用`start()`；`VoiceAgentOrchestrator:307–332`保存旧transcript后重建prompt，`VoiceAgentSession.beginListening:192–195`只改session state。ChatSheet的uiState监听只在processing/responding时扩展面板；真实`VoiceService.requestPermission/startListening`仍在显式`beginPushToTalk`路径。因此本恢复入口没有自动录音调用，也不清workspace草稿。这不是实际权限/返回操作验收。

未配置banner在空态/消息两条ScrollView中出现，输入栏不再承担该长提示；44pt设置CTA进入独立AX子树（contain）。Dock新增测量值并作为内容底部预留。这些是合理的源码方向，仍须大字、键盘和暗色实图读回。

| ID  | 级别/状态      | 本批发现及验收契约                                                                                                                                                                                                   |
| --- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C09 | P2 open        | ItineraryListView:294先把code小写；真实VTE变vte，而名称表仅有VTE、aliases无vte，仍显示代码。原code优先查表或大小写不敏感解析；验证VTE/CNX/SZX与未知code。                                                            |
| C10 | P2 open        | ChatSheet:1294与promptIconColor:1433把浅色actionTintAdaptive用于starterCardRow的gradient填充，而:1368仍白glyph；白/#E5C28F对比仅1.687:1。恢复深棕填充+白图标，或提供深图标+浅填充的配对；前景token不能机械替换填充。 |
| C11 | P2 source risk | dockReserve已动态，collapsedHeight仍136；若Dock实测>92，则44pt grabber和底部Dock可能重叠。先测04 AXXXL真实高度；必要时collapsed总高度也取grabber+Dock。当前不把条件风险当运行失败。                                  |

本批尚未给新功能分或视觉A/B结论；已观察源码的改善不替代编译与实际界面验证。

本批返工源码已再次读取：C09现在优先原code查名称→alias canonical→大小写不敏感字典fallback；C10两处starter图标填充恢复深棕CT.accent，保留白glyph；C11面板liveHeight增加grabber+实测Dock的下限并clamp到容器。三项均改记`source_fixed_runtime_pending`，还不以未冻结源码认证04b构建/大字体验。04首次构建通过由根代理报告，03之后这三项最新返工仍待04b完整清单、编译及实图。

## 原生snapshot-04b冻结复核

56/56文件SHA与完整patch一致（SHA-256 `7dccdb60e69e622a98ddef073ebfc04fc72815d0c0cbbae6f85df0716c01f3c6`）；相对03新增/变化9文件。04b完整`build-for-testing`明确`TEST BUILD SUCCEEDED`。`AdaptiveActionContrastTests`实际3例全通过、0失败/跳过：明暗trait下actionTintAdaptive在card/sheet上达4.5:1，以及固定深棕填充+白label仍达4.5:1。summary与case读回结果已保存scorecard.partialReviews；这只是颜色解析/亮度逻辑，不是截图验收。**03的80项没有在04b重跑，仍单独绑定03。**

C09城市名称、C10图标填充及C11大字Dock下限的源码修复已绑定04b。设置返回无自动录音调用/保留草稿的结论保持源码证据；04b最大字号、键盘、真实Dock边界与设置返回交互仍pending。未把新源码记为实际运行通过。

## Web活跃树初审（尚未冻结）

只读Pi的apps/web差异及新增helper；Pi仍编辑，本节不认证某个冻结head，不以测试源码作通过证据。功能分暂沿用基线，不给新版数值；没有浏览器通过证据。源码上能认可移动导航、签到明确提交/失败保留、44px评分与抽屉抓手、历史snapshot详情、真实列表排序/按钮和分享动作方向，但下列问题必须等修后复核才能关闭。

| ID  | 级别/状态                                 | 确认问题及修复契约                                                                                                                                                                                                                                                                                                          |
| --- | ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C12 | P1 active_tree_observation_pending_freeze | `MapView.tsx:117`：活跃树effect依赖引用mapEpoch但读取时全文件无声明；Pi正继续实现恢复路径，尚未冻结。 冻结前typecheck及源码重读；补齐retry状态或移除悬空引用，不将未完成编辑当最终版。                                                                                                                                      |
| C13 | P1 open                                   | `app/[city]/page.tsx:1213; app/experience/[id]/page.tsx:468; app/app/page.tsx:51–65`：新Open live map把独立示意WebExperience ID（miradouro-graca等）传/app；后者清迈起始且只解析附近core/足迹，未有真实ID/坐标映射，不能定位所点体验。 改走已支持?experience的城市指南并准确命名，或用真实映射接通；不伪造地理坐标/核心ID。 |
| C14 | P1 open                                   | `VoiceIntent.tsx:68–95,131–143`：只有unmount abort，无document隐藏/pagehide停止与晚回调失效；浏览器自行暂停不能作为应用生命周期保证。 隐藏/离开明确abort，清/失效回调与transcript，不自动重启或提交晚到结果；保留文字草稿。                                                                                                 |
| C15 | P2 open                                   | `lib/today-copy.ts:104–127`：now.getHours取查看者时区，却声称匹配地点bestTimes now；无法支持跨时区时段证据。 采用已知地点时区；缺时区时保持unknown，移除now匹配断言与对应加分。                                                                                                                                             |
| C16 | P2 open                                   | `app/app/page.tsx:39; api/experiences/nearby/route.ts:174–195`：degraded同时用于真实数据AI排名降级和开发fixture；当前sampleMode=degraded会把真实数据误标sample。 区分数据来源与AI排名状态；不凭AI失败推断数据是演示。                                                                                                       |
| C17 | P2 open                                   | `lisbon/CommandPalette.tsx:226–239,344–353`：全局Enter按activeIdx导航，而Tab焦点到其他结果Button不更新activeIdx；Enter可能执行旧高亮项。 输入框中才接管Enter；结果按钮用原生激活，或同步焦点并避免双执行。                                                                                                                  |
| C18 | P2 open                                   | `lib/distribution.ts; marketing/sections.tsx; (marketing)/download/page.tsx`：分发模型支持TestFlight，但UI只按iosAvailable显示App Store，状态/元数据/requirements又固定未公开，三种分发状态文案不一致。 按primaryKind区分AppStore/TestFlight/web并统一本地化/元数据/状态；URL语法验证不等于已验证真实上架。                 |
| C19 | P2 open                                   | `marketing/copy.ts:313–333,对应zh pricing`：Pro收益仍列完整Blindbox等仪式；当前原生Archive对应入口已降为预览/只读，不能把示意业务当已交付付费能力。 营销说明当前可用/预览范围，移除未实现的付费能力承诺，不新增SKU或后端。                                                                                                  |

W18仍有P1遗漏：英文privacy的NEVER_COLLECT仍称位置永不离机、从不索取contacts/calendar/photos，第三方仍写Anthropic/Claude且无位置；中文相同。已知Overpass/AI坐标路径与原生04b同意页均相反，照片选择/相机路径亦存在。首页trust改文案不等于政策页已修；应删除/纠正可证的事实错误，不凭空编条款，正式法律URL是否可用仍待用户提供。

W17示意图+／−／reset已接真实viewBox变化，+City已移除，消除原死动作；MapControl仍30×30，需要扩透明区域达到本轮44px触控目标后实测。下载配置校验只能证明https/Apple域名及ID格式，不能认证某个listing实际存在或本产品已上架；当前无经核实商店目的地时，真实Web入口可以使用但文案必须准确。

根代理已确认C13/C14及C15–C19需要修，承诺不算修复证据；以上全部保持open直至冻结源码复核。C12只是未完成活跃编辑的读取时观察，最终须以冻结typecheck/源码判断，不把它定为已交付回归。

## Web集成返工复核与局部实际操作

本轮读取integration的相关源码（逐文件指纹见scorecard.inProgressReviews），最终Web冻结清单仍待根代理提供。C12悬空mapEpoch已不存在；C13城市→详情→带ID指南真实路径、C14隐藏/离开abort与晚回调守卫、C15不推断查看者小时、C16数据source与AI降级分离、C17输入框Enter作用域、C19预览/只读范围和W18中英事实说明均可源码关闭，保持`source_fixed_runtime_pending`。外部正式法律URL继续pending，不由本地事实说明替代。

新增C20 P1：地图error重建时旧effect cleanup先清mapRef，后续early return跳过ready=false；重建load保持true导致同results时pins/click不重绑。已由root在error和cleanup都清ready，reviewer重读确认源码关闭；尚无该真实/模拟地图实例恢复运行证据。C18仍partial：mobile-preview按钮href使用分发配置，但文字固定Get the app/获取应用，需用三态action完整收口。

新增C21 P1（root实际浏览器发现）：常驻Vaul1.1.2 modal=false仍把main设aria-hidden=true。现改semantic section，peek不挂载列表；手柄44pt且pointer capture、pointercancel、ArrowUp/Down/Escape路径明确。VoiceIntent组件保留挂载，仅hidden时不渲染可见表单并abort；文字State保留。初审无额外确认P1，仍须实际拖拽、焦点与语音捕获场景验收。

根代理已提供如下E3实际步骤，仅对相应状态成立：

1. 320px菜单Tab可到Features；Escape关闭并还焦点到Open menu。
2. 中文路由可达；Hero CTA进入/app。
3. main读回aria-hidden=null；手柄ArrowUp展开407px、Voice表单隐藏；Escape折叠120px，原`Quiet cafe draft`与可见输入恢复，测试文字已清除。
4. 实际seed列表点选体验，已打开详情。

这些步骤不等于真实SpeechRecognition启动后隐藏/后台停止通过，不覆盖所有浏览器、Mapbox重建、拖拽或签到失败。Pi checkpoint的9文件59项逻辑通过仅属于turn284，不自动覆盖root后续修正。当前清单另存909候选（807 iOS/102 Web），全部仍未逐项认证；与固定892基线ID不自动迁移。

## 原生有效A/B实图与证据边界

独立查看before地图与04b合成诊断地图后，观察到：收藏/行程独立整行移入Menu；诊断成为滤栏下方较浅横卡；地图主体连续空间更多。滤栏减少套叠描边，深色填充编码当前选中；既有Dock角色保留。城市标题大小写/名称来自不同调试启动code，不当设计修复；合成定位被拒不是实际系统权限拒绝。

暗色AXXXL对比`ios-before-axxxl-fix.png`与`ios-after-ask-dark-axxxl.png`：城市名/加号的浅琥珀前景更清楚；输入与Dock不再相盖。配置说明进入独立滚动区；设置CTA在首屏下沿仍部分裁切，只能确认存在与源码可滚动，不能据此说滚动或点击已通过。没有给绝对品味分。

reviewer发现dark/light-final两张图片字节相同（SHA `7d2a2b1e5865580389f9196e430982000c4f42acc29e387d1e5df24e1aa6d7ea`），实际均暗色AXXXL。root已删除错误命名的正式证据并修正native-ui-checks：**04b默认large和明色均未验收**。复原命令返回0只表明命令执行，不代表画面模式已读回。

原生E3仅沿用snapshot-03的真实Menu→收藏/行程返回，以及真实键盘草稿切换/无配置发送保留；04b新设置CTA没有E3。有效04b图仅E2，contrast三例逻辑仍单独记录。所有候选的未验证状态不因少量E2/E3自动改变。

## 最终关闭复核与当前功能区间

Web最终补丁SHA-256：`dc3b4406e11b135bf0d2ffa0f3d96549083cc640adc82aaae103d893f7324d21`；50文件与原生04b56文件均匹配。城市响应式列表/示意图切换正确隐藏非活动栏，手机选择后聚焦实际Close；详情→指南携带体验ID和语言。mobile-preview静态marker不冒充按钮，初始演示记录为空Set、刷新清空、7个可见目标44px；分发文案同源。clear-intent最后补min-h44已源码复核。

C12–C22均已源码处理。C20地图error→retry重建仍待有效token运行；C21 main不再aria-hidden已有实际读回。没有沿用旧pricing临时语法错误，也没把Pi59例替代最终58例。最后min-h44补充后的productionbuild亦exit0，正式日志/validation已更新；58项逻辑在该唯一CSS补充前执行，未把这条边界隐去。

### 当前逐功能族评分建议

17个Web组currentSourceAssessment均更新snapshot-web-final，27个原生组为snapshot-04b。以下是当前源码及有限行为证据区间，上界不是已得分；unknown不默认满分。已完成抽样步骤从remainingEvidence移入partial_observed说明。913个当前候选仍未逐项认证。

| ID  | 功能族                    | 当前功能区间 | 已观察/unknown权重 | 行为状态         | 剩余验收（抽样）                                                                        |
| --- | ------------------------- | -----------: | -----------------: | ---------------- | --------------------------------------------------------------------------------------- |
| W01 | 官网 EN/ZH 导航           |  85–100 /100 |              100/0 | partial_observed | 320菜单/语言/主CTA已抽样通过；剩各营销子页完整键盘/读屏路径                             |
| W02 | 官网 Hero/功能/信任/页脚  |  85–100 /100 |              100/0 | partial_observed | 1280/390/320主CTA与无横溢已观察；剩长内容/200%缩放及全部页脚链接                        |
| W03 | 定价 EN/ZH                |  72–100 /100 |              85/15 | partial_observed | 定价→download已通过；剩真实价格/试用资格与完整中英缩放读屏                              |
| W04 | 宣言 EN/ZH                |  72–100 /100 |              85/15 | not_verified     | 宣言长文缩放/读屏和末尾CTA全路径                                                        |
| W05 | 隐私 EN/ZH                |  72–100 /100 |              85/15 | partial_observed | L01公开Gist/互链已匿名读回、入口源码已修；新增页面→Gist点击与缩放读屏仍待验             |
| W06 | 下载                      |  72–100 /100 |              85/15 | partial_observed | 无iOS链接→Web状态已抽样通过；剩真实商店/TestFlight配置后的外部跳转                      |
| W07 | 共享 Web 控件             |  72–100 /100 |              85/15 | partial_observed | dark/reduced-motion已抽样；剩全部共享控件focus/forced-colors/busy/disabled              |
| W08 | /app 地图                 |  64–100 /100 |              75/25 | partial_observed | 有效Mapbox下加载/标记/键盘、error→retry重绑及真实定位允许/拒绝                          |
| W09 | /app 附近和足迹           |  72–100 /100 |              85/15 | partial_observed | 箭头展开/折叠、草稿保留、main可访问已通过；剩手柄drag/cancel/页签读屏                   |
| W10 | /app 今日                 |  64–100 /100 |              75/25 | not_verified     | 源码已限定score/估算距离；剩关闭会话持久化、长标题与读屏                                |
| W11 | /app 语音/文本意图        |  72–100 /100 |              85/15 | partial_observed | 面板隐藏/恢复文字已通过；剩真实麦克风允许/拒绝/快速切换/晚回调                          |
| W12 | /app 体验详情             |  64–100 /100 |              75/25 | partial_observed | 4分→502保留、44pxRetry、Close焦点返回已通过；剩真实保存成功/超时/重复提交与最终成功重试 |
| W13 | /[city] 城市工作台        |   76–91 /100 |              100/0 | partial_observed | 320列表/示意图/详情、walk排序及1280双栏已通过；剩SVG缩放/键盘标记/分类/BackForward      |
| W14 | 城市命令面板              |  72–100 /100 |              85/15 | partial_observed | Tab按钮Enter正确导航已通过；剩Esc焦点恢复、无结果/箭头选择与读屏                        |
| W15 | /mobile-preview           |  85–100 /100 |              100/0 | partial_observed | 320预览44px/静态marker/演示打卡/刷新清空已通过；剩中英完整键盘/减少动效/其他视口        |
| W16 | /experience/[id] 分享体验 |   57–93 /100 |              75/25 | partial_observed | 带ID回指南已通过；剩全部语言返回/来源/附近体验链接                                      |
| W17 | /trip/[slug] 分享行程     |  64–100 /100 |              75/25 | not_verified     | 系统分享/取消/Clipboard失败与实际URL载荷、行程地图/返回语言读屏                         |
| I01 | 地图主场景/城市           |  77–100 /100 |              90/10 | partial_observed | 03切换保留已抽样；04b仅合成诊断/暗色AXXXL E2，剩真实定位拒绝与地图手势                  |
| I02 | 稳定导航/发现             |  77–100 /100 |              90/10 | partial_observed | 03菜单→收藏/行程返回已通过；剩发现排序/重试、键盘/04b大字触控                           |
| I03 | 探索工作流                |  72–100 /100 |              85/15 | not_verified     | 探索同意/取消                                                                           |
| I04 | 保留对话/历史             |  64–100 /100 |              75/25 | partial_observed | 03文字草稿切换/无配置发送保留已通过；剩历史scope/附件与04b新设置恢复实际操作            |
| I05 | 对话输入/附件             |  85–100 /100 |              100/0 | partial_observed | 04b暗色AXXXL输入/Dock分离仅E2；剩明色聚焦/键盘、附件导入/删除/故障草稿UI                |
| I06 | 语音                      |  72–100 /100 |              85/15 | not_verified     | VoiceOver开始/停止                                                                      |
| I07 | AI 卡片/撤销/诊断         |  85–100 /100 |              100/0 | not_verified     | 卡片展开/选择                                                                           |
| I08 | 体验卡/预览               |  64–100 /100 |              75/25 | not_verified     | 真实Experience内容                                                                      |
| I09 | 体验详情主动作            |  64–100 /100 |              75/25 | not_verified     | 收藏/到访切换读回                                                                       |
| I10 | 体验新增/修正/反馈        |  72–100 /100 |              85/15 | not_verified     | 新增保存/失败保留                                                                       |
| I11 | 体验分享/导出             |  72–100 /100 |              85/15 | not_verified     | 模式选中/44pt                                                                           |
| I12 | 行程列表/创建             |  64–100 /100 |              75/25 | partial_observed | 03行程列表打开/返回已通过；剩创建编辑取消、日期城市验证和保存失败                       |
| I13 | 行程详情                  |  64–100 /100 |              75/25 | not_verified     | 重排/删除保存                                                                           |
| I14 | 路线创建/详情             |   0–100 /100 |              0/100 | not_verified     | 手动/AI路线生成                                                                         |
| I15 | 路线招募/申请             |  64–100 /100 |              75/25 | not_verified     | 申请trim验证                                                                            |
| I16 | 同伴发现/安全             |  72–100 /100 |              85/15 | not_verified     | 安全同意拒绝                                                                            |
| I17 | 同伴资料/消息             |  64–100 /100 |              75/25 | not_verified     | 资料保存失败保留                                                                        |
| I18 | 路线分享                  |  64–100 /100 |              75/25 | not_verified     | 快速切换预览/导出一致                                                                   |
| I19 | 好友入口/邀请/扫码        |  64–100 /100 |              75/25 | not_verified     | 代码搜索/添加结果                                                                       |
| I20 | 我的/权益                 |  64–100 /100 |              75/25 | not_verified     | 个人/档案切换                                                                           |
| I21 | 设置及子页                |  72–100 /100 |              85/15 | not_verified     | 偏好选择可执行/读回                                                                     |
| I22 | 首次使用/条款             |  64–100 /100 |              75/25 | not_verified     | 正式URL/公开正文/入口源码已修；真实接受/拒绝/重读及两链接点击仍待验                     |
| I23 | 付费                      |  72–100 /100 |              85/15 | not_verified     | 法律目的地与入口源码已修；实际链接点击及真实StoreKit资格/读屏/互斥/取消仍待验           |
| I24 | 今日/城市工具             |  72–100 /100 |              85/15 | not_verified     | 日期/期限输入                                                                           |
| I25 | 仪式/归档                 |   58–86 /100 |              85/15 | not_verified     | 仪式hub未实现启动/分享/回复/解锁；当前预览/只读身份仍需用户理解验证                     |
| I26 | 管理/共享反馈组件         |  64–100 /100 |              75/25 | not_verified     | 通用反馈操作44pt                                                                        |
| I27 | 信任解释/独行评分         |  17–100 /100 |              20/80 | not_verified     | 信任解释打开/关闭                                                                       |

后续优先顺序：法律目的地已在05增量修复；补新 iOS 法律入口实际点击、VoiceOver/真实权限与StoreKit、附件故障输入栏、归档读屏，以及有效Mapbox重建/后端签到成功和系统分享失败。原生地图层级、暗色前景、AXXXL输入/Dock分离有相对改善；明色/默认large、新设置CTA点击不在已验范围。仪式预览/只读与城市指南替代个人计划的范围继续扣分，不用其他入口平均分补偿。全量96目标需要913候选状态矩阵与代表性用户任务证据；本轮不编每按钮运行分或绝对品味分。

最终验证补记：最后clear-intent的44px单一CSS补充后，Next生产构建再次exit0。reviewer已核对正式validation JSON与四份压缩日志解压SHA；源码50/56和当前218源文件哈希边界不变。17个Web currentSourceAssessment均为snapshot-web-final、remainingEvidence已改为当前缺口/抽样通过说明；已修基线扣分不再作为当前扣分显示。该历史快照当时的 P1 L01 已由后续05法律增量关闭源码/公开目的地缺口；全量96目标仍未关闭。

## 法律入口增量关闭复核：snapshot-05-legal

2026-10-16：两份正式双语文件已公开发布为 [隐私政策](https://gist.github.com/kubbot/e177b6ab042c8d5bd79417300031a5c9) 与 [用户协议](https://gist.github.com/kubbot/08f720b1191b6f9c913699c16227581a)。reviewer 独立使用不带 Authorization/Cookie 的 HTML/API GET：均 HTTP200、public=true、owner=kubbot，中英正文、`cubxxw@gmail.com`、互链存在，API完整正文与本地字节一致；隐私 SHA `fdaa47227d222a0f01694158b663cc813dcadf4cace8796ed7c2a40437729e47`，协议 SHA `d192072979b29409a0e30d4abf3e7afe7bdaacc7ab655ab68f7ce0e470389e88`。不再要求用户提供正式 URL。事实与双语审查见 `evidence/legal-document-review.md`，永久公开读回证据是 `legal-gist-api-readback.json` 和 `legal-gist-public-readback.json`。

本次源复核确认：TermsConsentSheet 共用 LegalDocuments/LegalDocumentLinks，首次同意、Settings 数据/关于、Paywall 购买相关动作后均可重读；两处链接的44pt frame/contentShape位于Link标签内。中英五段同意摘要已去除旧的全本地/不处理照片/统一匿名保证。Web lib/legal.ts、两种语言页脚/隐私摘要完整政策链接与邮箱同源；bot `/privacy` 摘要、PRIVACY 文档、App Store 元数据文档已更新。摘要与正式政策相符，未新增购买、授权、自动录音或清空草稿行为。没有新增确认 P0/P1。

| 项目                     | 当前状态                                                                                                                               | 尚未授予的结论                                                        |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| L01 正式目的地与入口源码 | source_fixed / public_destination_verified                                                                                             | 不代表新原生链接已实际点击、App Store Connect已保存或正式二进制已发布 |
| 凭据存储 P2              | source_fixed，区分 Keychain 与本地AI设置                                                                                               | 不声称全部凭据加密或全部数据随卸载删除                                |
| 双 Gist 互链             | 匿名正文/API读回一致                                                                                                                   | 不代表法律充分性或审核保证                                            |
| 原生44pt链接定义         | 标签内 frame/contentShape 已修                                                                                                         | 空白处点击、VoiceOver、大字仍未实测                                   |
| 本批构建/冻结            | generic Simulator Debug正式日志已读回BUILD SUCCEEDED；checkpoint明确构建在label44修正后，109/109源码SHA匹配；无Simulator点击或新XCTest | 不用旧03/04b或旧Web58例冒充本批运行通过                               |

W05/I22/I23 原有 L01 可理解性2、恢复2、信任4 的源码扣分已撤销；当前可能区间分别为72–100、64–100、72–100，上界仍包含未知维度，**不是已经得到100或超过96**。I21 新增重读入口与 W01 页脚法律指向已更新源码观察范围，旧版行为证据不自动覆盖新链接。法律增量已重新盘点为918候选（iOS810/Web108）、44组，218源码SHA独立核对全部匹配；当前ID已更新，未把892基线或旧913扫描的评分/运行通过状态直接迁移。

### 法律增量补充：审核文案事实矛盾

`LEGAL-P1-02`（当次P1，现已 source_resolved；下段为历史发现）：`docs/APP_STORE_METADATA.md:176–184` 的 Reviewer notes (App Review submission) 仍称 Anthropic、No PII only OSM tag dictionaries/city、No accounts/no tracking/no third-party SDKs，与现有实现及新政策冲突。`:154–168` 的 TestFlight 说明还保留固定7天试用、旧部署域名与旧反馈邮箱。已交实现者更正整个可复制段落；不推断这些旧描述已提交 App Store Connect，也不影响两个已发 Gist 正文。正式URL本身的L01仍为已修复/公开验证。

### snapshot-05-legal 收束补记

`LEGAL-P1-02` 已独立复核关闭：App Store metadata 全文重写，Description 中英、TestFlight 和 Reviewer notes 去掉 Anthropic、无账号/无第三方SDK、只发送OSM tags/city/无PII、固定试用/价格与旧邮箱等错误事实。月/年实际商品、许可/内容权利/年龄问卷和线上配置均以live读取为准；支持与营销临时目的地有真实内容和维护者来源，不称 App Store Connect 已更新。文件SHA `8e30b9fb8d3484e5d0246990e373fe883065da3007c10139803e58d1cbebc173`；基础版本/Bundle ID与project.yml相符。没有新增未解决确认P0/P1。

05原生构建的正式压缩日志已读回 `BUILD SUCCEEDED`，解压SHA `ad3a23ed0f0fa56826842e08437e7edaa616b1b9756c99b40359c35aa158c759`。checkpoint明确exec97139在44pt标签修正后结束，再复制日志并生成109文件清单；本轮绑定缺口关闭。没有启动Simulator、运行新XCTest或点击新增原生链接。Web生产构建、Web/bot类型检查及本地化的05正式日志均已读回exit0，5份压缩日志解压SHA与验证JSON全部相符；不沿用旧58例冒充05通过。

### 05正式验证关闭

已独立核对 `evidence/checkpoint-05-legal-validation.json` 与全部5份压缩日志：原生generic Simulator Debug构建、本地化、Next15.5.27生产构建、Web tsc、bot tsc均exit0，解压SHA全部匹配。Web构建完成编译/类型有效性/20静态页与traces；本地化1738英文引用齐全。没有运行新XCTest或重复旧58/80/3例。

05补丁解压SHA `b84add54d199b027b0ac6ab669ffca94c7921c6abea81e087023a6a697075592`，109源码清单不变；`legal-document-files.json` 的6份法律/元数据文件哈希也全部匹配。两Gist已live，本轮已授权的“公开Gist+源码接入及选定验证”完成，没有未解决确认P0/P1。新增原生链接真实点击/VoiceOver/空白处命中、ASC远端、应用/网站/bot发布均未执行；这些是后续证据/上线边界，不再要求用户提供URL或联系人。全量918候选超过96仍未认证。
