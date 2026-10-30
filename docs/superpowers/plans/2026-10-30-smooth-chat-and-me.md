# Smooth chat and Me implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. User requested direct autonomous implementation; use one native implementer and the repository-required independent review before delivery.

**Goal:** 流畅处理长会话的输入、发送和滚动，并重设计「我」页。

**Architecture:** 缓存展示投影、纯滚动策略、轻量草稿和带顺序保护的快照写入；SwiftUI 页面沿用服务与导航边界。

**Tech Stack:** Swift 5.10 / Foundation / SwiftUI / XCTest / iOS 17+，不增加依赖。

**Spec:** `docs/design/smooth-chat-and-me.md`

## Global Constraints

- 独立 GET-338 分支从最新 origin/main 开发，保留 GET-336 恢复约束。
- 模型调用前接受记录必须落盘；最终保存成功后才写记忆。
- 旧快照可读；不得擦除真实会话或切换测试账号。
- 本机只使用 dev-ios-session 的 Primary iPhone；已占用时继续宿主工作并使用 CI 原生证据。
- 中英本地化、Dynamic Type、Reduce Motion、深色与 44pt 触点。

## Review Focus

- 旧异步保存不得覆盖新的工具收据或清空结果。
- 保存失败/取消时不得覆盖正在输入的新草稿。
- 滑动与惯性期间到达的回复不得抢读历史的位置。
- 多千条消息、大段文字和媒体不能把全量工作放回每帧/每个按键。
- 重设计后档案/深链接/权限控制/订阅事实仍正确。

## Task 1 — Persistence and long-history evidence

Files: `Services/CompanionHomeStore.swift`, new `Services/CompanionSnapshotWriter.swift`, `scripts/qa/companion-chat-host.{sh,swift}`, `Tests/CompanionChatPerformanceTests.swift`.

- [x] 用真实 Store 宿主复现输入必须保留历史快照不变的失败并保存基线。
- [x] 实现轻量草稿 revision、旧格式读取、精确清空与失败保护。
- [x] 实现 `CompanionSnapshotWriter.reserve/invalidate/write/writeAsync`，验证倒序完成、失效、写失败。
- [x] 接入发送/最终结果异步保存，保留 queued 原话及时呈现及 durable-before-model。
- [ ] 测试保存期间新输入、快速重复发送、取消、清空、失败后重开与旧 receipt；宿主绿、XCTest 绿。

## Task 2 — Projection and scrolling

Files: `CompanionTimeline.swift`, new `CompanionScrollIntent.swift`, `CompanionConversation.swift`, `CompanionMessageRow.swift`, `CompanionComposer.swift`, `CompanionHomeView.swift`.

- [ ] 测试批量/同时间/乱序/旧邀请/迟到回复的稳定投影及预计算引用/时间分隔。
- [x] 缓存投影与 ID 查找，滚动只处理小变化。
- [x] 测试并实现拖动、惯性、读历史、显式发送与回底部策略。
- [x] 单容器惰性行、合并定位请求、局部正文计算；发送保留键盘。
- [x] 比较 5,000 条消息基线与优化后的相同输入路径，保存边界证据。

## Task 3 — Me visual redesign

Files: `Views/Me/MeSheet.swift`, `MeProfileHeader.swift`, `MeHubRow.swift`, `EntitlementBanner.swift`, `CompanionHomeView.swift`, both `Localizable.strings`.

- [x] 实现左对齐身份、大标题、真实静态计数、档案主入口、同行与偏好分组。
- [x] 保留资料编辑、消息深链接、审核权限、订阅真实文案和设置路径。
- [ ] 空状态回地图通过可用回调；无数据/长姓名/大字号/深色均可用。
- [ ] 原生截图与点击验收；仅为行为与重要导航写回归，不为颜色/间距写镜像测试。

## Task 4 — Native acceptance and delivery

- [ ] XcodeGen、受影响 XCTest、长会话原生滚动/发送与「我」页浅/深色、大字号验收。
- [ ] 独立审查并修复确认的 P0/P1，完整适用最新提交 CI。
- [ ] GET-338 对应 PR；验收后合并，Linear Done 读回，保存证据并清理独占产物。
