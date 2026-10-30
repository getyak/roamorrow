# Roamorrow iOS：下一步，已经在这里

设计提案 · 2026-10-29 · GET-324

## 设计判断

Roamorrow 应当帮人带着一份可信行程出门，在需要时给出下一步，并把花钱的决定交还给人。首页的核心问题变为「现在做什么、最晚什么时候、依据是什么」。聊天承担输入意图、追问与解释；地图保留位置感；整个产品共享一个当前 Trip。

现有 `PRODUCT_BRIEF.md` 把 conversation + map 定义为主场景，现有原生页面还同时承载筛选、地图按钮、对话与发现入口。用户这次要求的是一次产品层面的重塑。因此本提案有意调整主信息层级，并引入按需展开的旅程侧栏。它是待评审的新方向，不能当作已经获得验收的 SwiftUI 实现。

Trip 是编排行程、票据、约束与决策的聚合层；Experience 继续承担有时间、情境、来源的体验单元，不把 Experience 重命名为 Place，也不把 Trip 塞进现有体验 schema。

## 与现有原生能力的衔接

代码中已经有 `LiveActivityService`、`SoloCompassActivityAttributes` 与 Widgets 扩展，覆盖 route、countdown 等场景。本提案应复用这些生命周期与共享 attributes 基础，把它们投影到同一 Trip 的 next action；实施时先盘点字段与迁移兼容性，而不是另建一套 Activity 管线。这里的 P1 指新的 Trip 在场体验，不表示仓库此前没有 Live Activities。

现有 `MemoryDigestService` 将近期对话收拢到单一 `AgentMemorySnapshot`，并提供 `forgetMe`。新的三桶记忆需要明确的迁移与写入规则：已有摘要保留来源身份，不能直接升级为用户确认的 Profile；新增来源、确认、TTL 和分范围删除后，才逐步替换直接注入摘要的路径。实施阶段应保留现有删除能力并验证迁移，避免旧摘要与新 Profile 同时成为两份权威记忆。

## 首页：让下一步先到手边

首页保留地图，默认只显示当前 Trip、一个主要下一步、一项必要的待核对提醒，以及一条轻输入栏。

下一步卡固定呈现四件事：动作、建议最晚开始时间、预计耗时、依据或数据状态。主要按钮只做该动作，例如「打开步行导航」。交通尚未预订时写「建议车次 · 待购票」，不会把研究结果渲染成已出票状态。地图上保留当前位置与下一站；更多推荐在任务展开后出现。

状态模型至少覆盖：尚无 Trip、规划中、出行中、临近截止、待核对、离线、位置不可用、旅程结束。未知登机口写「待机场核对」；刷新失败保留最后确认值与更新时间，并说明失败，不通过新动画制造“已经更新”的印象。

没有 Trip 时展示「导入确认信 / 手动建行程」；没有下一事件时展示可选的附近 Experience，不制造紧迫感。出行结束后提供回顾与归档。

## 功能侧栏：当前旅程的目录

iPhone 顶部保留 44 pt 明确入口。点击后从左侧展开 322 pt 的旅程目录，右侧留下地图上下文；点击遮罩、关闭按钮或 Escape 可退出。侧栏不是首页永久占用宽度的图标轨，也不是第二个聊天列表。它属于本次用户明确提出的新设计范围。

主目录维持四项：此刻、行程时间轴、票据与来源、预算与花销。旅行记忆放在分隔线下，明确区分当前旅程与跨趟偏好。顶部可以切换 Trip，底部可见离线包状态与权限入口。日常功能不再全部堆进地图表面。需要重新检查的事情才显示数量提示，不使用营销红点。

iPad 后续使用适应尺寸的系统侧栏与详情布局；本轮交付 iPhone 390×844 pt 概念，未宣称 iPad 或原生 Dynamic Type 已验收。侧栏沿用系统返回、焦点与可访问性语义，不依赖边缘手势作为唯一入口。

## 行程真相：新信息先成为候选

资料从分享、文件、粘贴确认号进入“提取预览”，再挂入当前 Trip。原始邮件/PDF/截图属于源记录；提取出的 booking 字段属于事实候选；确认的字段进入版本化行程。源记录不能冒充用户偏好。

冲突界面同时给出原记录、新值、来源、收到时间、影响和确认按钮。例如演示航班从 18:20 变为 19:05，界面解释机场缓冲增加 45 分钟，同时明确「只更新行程记录，不改签、不付款」。用户可稍后核对，也可回看原文。

建议数据契约：`Trip(id, timezone, version, segments, bookings, constraints, openLoops)`；`SourceRecord(id, type, importedAt, contentHash, sensitivity)`；`Fact(id, fieldPath, value, sourceIds, observedAt, effectiveAt, confidence, status, supersedes)`。候选与已确认值分开存储。写入用 `expectedTripVersion` 防止覆盖另一台设备刚确认的变更；冲突时重新对比。

子 agent 只能提出基于同一 Trip 版本的 patch，通过真相层校验与应用。禁止私有 itinerary 副本成为第二份权威记录。事实值变更、路线建议和票务执行是不同事件，彼此不能隐式替代。

## 在场：系统表面接力

`context.now` 汇总当前 Trip、当地时间、允许读取的定位、下一事件与数据新鲜度。`next_action` 先由行程、硬约束和确定性时序规则计算；模型可解释或提出候选，不能凭空生成登机口、开门时间、价格或已确认预订。用户更改“今天想轻松一点”时，约束通过 Trip 层更新，不能只改聊天文案。

锁屏 Live Activity 展示一个正在发生的旅程阶段与下一步，默认隐藏证件号、确认号和完整订单信息。Dynamic Island 紧凑视图保留动作与倒计时。Siri / App Intents 的「下一站」「现在该干嘛」读取同一 next-action 结果与版本。不同系统入口不能各自产生不同的建议。

原生能力按阶段落地：

| 顺序 | 用户可见结果                                                        | 系统与降级                                                         |
| ---- | ------------------------------------------------------------------- | ------------------------------------------------------------------ |
| P0   | 单一 Trip、票据导入、来源对比、下一步卡、离线当日包、侧栏与消费确认 | 手动建 Trip、粘贴确认号始终可用；本轮仅做设计资料                  |
| P1   | 锁屏与灵动岛、Shortcuts/Siri、分享扩展、本地提醒                    | ActivityKit / WidgetKit / App Intents；不可用时回到 App 的同一行程 |
| P2   | 日历同步、航班/交通状态、低频位置触发                               | 逐项授权；支持撤销；后台失败可解释；保留手动刷新                   |
| P3   | 相机翻译、供应商票务与支付、兼容 Wallet 的票证                      | 本地提取优先；供应商和系统能力齐备后开放，不画成默认已接入         |

Live Activity 有系统生命周期与内容大小限制，不能代替全天后台运行；后台刷新由系统调度，不能承诺每分钟准时执行。登机口等高价值变化优先使用具备授权与真实来源的服务推送；没有来源时显示未知。

日历“添加事件”优先使用系统编辑界面或最小写入权限；双向同步另行说明为何需要读取。iOS 不提供任意读取系统 Mail 收件箱的通用权限，导入应通过分享/粘贴或明确连接邮件服务完成。Wallet 接受受支持、有效签发的 pass；不承诺任意酒店钥匙或交通卡都能写入。Apple Pay 也不是替任意第三方网站支付的通用能力。普通旅行提醒不默认申请 Critical Alerts。

地图离线包要区分应用自己缓存的路线/票据与系统地图区域下载；不能假设 App 可以替用户下载系统 Maps 的任意区域。Focus 只提供用户可选的系统集成，不替用户静默改变专注模式。

## 花钱边界：预览与执行之间有一道明确门

搜索、比价、路线研究默认可自动进行；可能产生费用或约束的占位需要先显示是否有押金、有效期与取消条件，不能因为工具名叫 hold 就默认无后果。

付款预览必须展示商户、具体项目、人数/日期、金额、币种、费用明细、取消与退款条款、汇率来源与时间（若换算）、预算影响。主按钮「核对并继续」不暗示已经出票。原生支付在可用的系统支付表面由用户再次授权；支付之外的改签、取消也必须明确确认。

确认绑定 `quoteId + exactAction + provider + total + currency + policyVersion + tripVersion + expiresAt`，服务端验证授权并使用幂等键。价格、币种、退款条款或行程对象变化后，旧确认失效，展示新差异并重新确认。聊天里一句含糊的“好”或被导入文档中的指令不能授权执行。

状态机：草案 → 已报价 → 等待明确确认 → 执行中 → 已确认 / 失败 / 结果未知。结果未知时先按幂等键查供应商状态；禁止直接重试扣款。执行成功要同时收到有效供应商结果和更新后的 Trip 记录；支付成功、出票成功与退款到账分别展示，不合并成一个“完成”。

本轮原型没有任何支付、票务、定位或个人数据接口。视频中的自绘系统确认区域明确标为设计示意，不声称复刻或调用真实 Apple Pay。

## 旅行记忆：三桶可看、可改、可删

长期偏好呈现 key/value、来源、置信状态、确认时间与过期规则；证件和常旅客号等敏感值进入 Keychain/受保护 vault，界面默认掩码，模型上下文只拿最小必要引用。Keychain 只是设备安全存储能力之一，跨设备服务还需要独立的加密、同步和访问控制设计。

这一趟保存决策理由、同伴、开放环、现场锚点与花销摘要；结束后生成回顾并可归档。今天的工作上下文带 TTL，可在结束当天、离开场景或用户主动清除时过期。不是删掉源票据来实现“忘记偏好”。

两趟中出现相似行为只能形成待确认建议。界面用「你似乎更喜欢安静的住宿，要记住吗？」发起确认；接受后记录“用户明确确认”为新来源。暂不接受不反复打扰。每晚整理可归并重复、提示待办过期、准备摘要与候选偏好，不能静默将推测变为长期事实，也不能自动关闭真实未完成事项。

删除支持明确范围：某条偏好、某趟记录、当天上下文；说明是否影响源记录、归档、设备副本与服务端同步，并提供可恢复窗口或明确的删除确认。共享设备和锁屏上不暴露敏感记忆。

## 视觉与动效规范

- 主色：墨色 `#1d2433`，行动紫 `#5548d9`，白色内容表面与 `#f5f6fa` 背景。语义状态使用绿色/琥珀色并附文字。当前棕金主题可作为后续品牌对照方案，本轮紫色是设计师建议。
- 原生落地使用系统字体，正文以 17 pt 为基线，次要信息 13–15 pt，来源元信息 11–12 pt；公开确认信息不能靠小字规避阅读。原型中的缩小辅助文字需在 SwiftUI 阶段重新按 Dynamic Type 验收。
- 地图不铺满图钉；状态、来源和主要动作的层级比玻璃效果更重要。主要阅读与付款条款使用不透明表面；支持 Increase Contrast / Reduce Transparency。
- 交互触区至少 44×44 pt。小文字动作扩展触区，不只按字形宽度点击。侧栏、弹窗管理焦点与返回位置，VoiceOver 有顺序和含义；地图另有列表等价入口。
- 侧栏展开 0.32–0.5 秒，内容轻微延后，主地图保留上下文。任务结果以同一对象的状态变化表达。Reduce Motion 下直接切换，不依赖位移动画理解信息。
- 示例图按 390×844 pt 设计。后续必须实测小屏、大号字体、横向/iPad、浅深色、VoiceOver 和硬件键盘；本轮浏览器概念预览不替代这些验收。

## Agent Tools 对应的界面责任

| 层         | UI 入口                  | 约束                                                           |
| ---------- | ------------------------ | -------------------------------------------------------------- |
| Trip truth | 行程、票据、差异确认     | 唯一 Trip；读写版本；来源不可丢                                |
| Presence   | 此刻、锁屏、Shortcuts    | 一个 next action；有截止时间与 freshness；离线只读最后可信结果 |
| Research   | 当前任务里的候选方案     | 选项有依据；研究结果默认不写成已确认预订                       |
| Spending   | 报价与确认面板、执行回执 | 每次 execute 绑定明确授权；未知结果先对账                      |
| Memory     | 旅行记忆                 | 区分源记录和偏好；promote 待确认；敏感值不进明文提示词         |

## 验收与交付边界

本次交付高清界面板、可点击浏览器设计原型、46 秒 HyperFrames UI 概念视频及可编辑源。原型采用演示数据，不连接真实个人行程、航班查询、供应商执行、支付、定位或模型。源代码交付以关联 PR 评审，任务不等于 native 功能已实现。

后续原生验收应检验：用户能在几秒内说出下一步与截止时间；能理解待购票与已出票不同；能回看来源并拒绝事实变更；任何执行前都能看到完整金额及退款影响；离线与拒绝权限时仍能找到当日行程；推测不会自动进入长期偏好。时间目标属于建议验收指标，需要用户试用测量，不是已测成果。

## 官方资料

- [Apple Sidebars HIG](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [ActivityKit](https://developer.apple.com/documentation/activitykit) 与 [Live Activities 生命周期](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [EventKit access](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui)
- [Background strategies](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)
- [Critical Alerts entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.critical-alerts)

- [App Intents](https://developer.apple.com/documentation/appintents)
- [Setting up Apple Pay](https://developer.apple.com/documentation/passkit/setting-up-apple-pay)
