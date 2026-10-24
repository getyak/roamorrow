# 冗余清理处置（2026-10-24）

基线：`6938c1e4781fc652242913a69f378796ea131828`。本次删除前复核生产入口、测试及序列化契约；静态无引用不自动等于可删除。原审计和原始清单保存在 `/Users/cubxxw/ops/reports/solo-compass-redundancy-20261024/`。

| 报告项 | 处置                                                                                                                                                  | 保留边界                                                                                                          |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| R01    | 删除无消费者的 HeroCanvas、DesignNav                                                                                                                  | 现有 Web 路由不变                                                                                                 |
| R02    | 移除 drei、fiber、three、@types/three、AI→db、wikivoyage→domhandler 六项直接依赖                                                                      | ReactDOM、db 包、工具链、安全补丁继续保留；domhandler 可继续作为传递依赖                                          |
| R03    | 删除 14 个没有当前生产入口的旧 SwiftUI 文件                                                                                                           | AvatarEmoji、BragCardTemplate 原定义移至 Models；测试迁至 FriendsHub 与当前评分卡                                 |
| R04    | 删除 8 个无调用 private 方法、23 个未使用状态/getter/logger，以及删除后进一步失去调用的 15 个 private 辅助成员；旧 ChatStateModifier 的残留随文件删除 | UIApplicationDelegateAdaptor、实际额度计量保留                                                                    |
| R05    | 保留未接入的 AI/数据服务并明确状态（下表）                                                                                                            | 本次不启用请求、数据收集或付费功能                                                                                |
| R06    | APNs 配置、签名、设备发送/410 清理及相同 JWT 认证抽至 Edge `_shared`                                                                                  | 各 handler 保留资源归属、接收人、额度、payload 和原 CORS/错误语义                                                 |
| R07    | GeohashUtils.encode 委托 Geohash，地图 decoder 委托 GeohashUtils                                                                                      | 保留校验入口、地图大写兼容、空串中心与非法字符行为                                                                |
| R08    | 删除旧好友链，两个输入框共用照片/文件/相机草稿处理                                                                                                    | 两种输入、录音和发送状态独立保留；耗时读写/解码仍在后台                                                           |
| R09    | 全部保留                                                                                                                                              | 多套数据库定义的差异需单独定义生产 schema 来源；本次不改 schema、迁移或实际数据库                                 |
| R10    | 删除未接入 workspace 的 apps/admin 两页骨架                                                                                                           | 历史说明和迁移保留                                                                                                |
| R11    | 保留 Google Places、Wikivoyage adapter 及其测试                                                                                                       | worker 目前仍只注册 OSM；不能把它们当作重复 OSM 功能                                                              |
| R12    | 全部保留                                                                                                                                              | Companion、Studio、Today/Map 仍是开关控制的可达入口                                                               |
| R13    | Lisbon SVG 配置抽成独立小模块                                                                                                                         | 组件不在运行时导入整份城市数据；121-byte Vitest 配置、框架 Sentry 入口和 Preview 夹具继续保留，避免增加工具链耦合 |
| R14    | 只删除已确认的无用成员                                                                                                                                | 不按文件行数重写或删除功能                                                                                        |

## 未接入服务的逐项判断

这些保留项不代表已交付功能。删除它们会超出“确认无用”的证据范围，或需要单独的产品/契约决定。

| 项目                                         | 保留原因与当前状态                                                 |
| -------------------------------------------- | ------------------------------------------------------------------ |
| AIModelRouter                                | 独立路由策略和测试契约；当前 AIService 没有生产接线                |
| DefaultContextManager                        | VoiceAgentOrchestrator 的可注入实现与测试；默认仍为 nil            |
| ChatDisplayType / ChatDisplayParams          | 结构化展示协议；目前未发现生产接线，未据此启用                     |
| MergedPOI / SourceEnrichment / FieldConflict | 与当前 POIMerger 不同的数据/冲突描述合同；需独立兼容审计再决定下线 |
| WebSearchEnrichmentSource                    | 可注入的数据源实现；本次不启用 feature flag 或外部查询             |
| TasteUpdateService                           | 涉及用户画像/持久化的未接入路径；不以静态调用数推断可删除数据合同  |
| SunsetSignal / WeatherSignal                 | 独立评分信号及测试；默认 NowScoreEngine 继续只用已注册信号         |
| LuluMockFulfillmentClient                    | 明确标记的打印合作方 spike 和协议测试；不提供真实下单验收          |

## 回归边界

新增测试直接加载生产 Edge handler 与本地共享模块，mock Supabase、APNs 网络及签名库接口；覆盖认证/越权、好友码防枚举、收件设备过滤、空设备、APNs 410/网络失败、payload 和截断。它们不代表真实 Supabase/APNs 部署验收。

原生测试覆盖 Geohash 兼容、当前好友入口、邀请代码、评分展开/VoiceOver、附件数据与顺序；XCTest 截图用于人工查看，不是像素基线比对。测试只在共享 primary iPhone 上串行执行，不请求真实模型或写入线上数据库。

所有历史迁移、SwiftData 模型/容器历史、seed 和安全补丁以清理前 SHA-256 清单核对。正式验证结果、命令和独立 review 结论见同一证据目录的 `VERIFICATION.md`。

## 依赖审计的现有告警

`pnpm audit --audit-level=low` 返回 21 条依赖版本告警（3 critical、5 high、9 moderate、4 low），因此漏洞审计门禁仍失败。它们涉及保留的 @sentry/nextjs、next、dompurify、vite、@vitest/mocker、fast-uri、undici 和 zod。锁文件结构对照确认：保留的 packages/snapshots 没有新增或改动节点，53 个删除节点都属于被移除依赖的闭包。本次没有引入这些依赖版本，也没有扩大范围升级依赖。实际产品可利用性未在这次冗余清理中测试。

安装的 release-age/供应链策略校验已通过 529 个锁定条目；上述漏洞审计结果单独记录，不能据此声称所有 CI 门禁通过。

后续安全修复已按独立提交更新上述八类依赖；最新冻结安装和审计通过，21 条未豁免告警归零。Zod 4 兼容适配及安全回归范围见[依赖安全门禁](dependency-security.md#2026-10-24-remediation)。清理提交及所有历史迁移继续保留；本地验证与远端 CI 结果分别记录。
