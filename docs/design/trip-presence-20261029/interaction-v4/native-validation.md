# 原生工具修复：验证范围

2026-10-30 · GET-324。本轮实际修改原生搜索与来源链，四项导航仍是待实施的设计稿。

## 已通过

`scripts/qa/agent-place-search-host.py` 提取生产搜索 handler、搜索来源、骨架模型、合并策略与来源徽标判断，在隔离的 Swift stub 环境编译并执行，56/56通过。覆盖query逐圈传递、过滤后再判断是否扩圈、明确/隐式地图来源、坐标校验、错误与空结果区别、取消与搜索区域失效、Apple Maps来源不冒充OSM等。生产扩圈常量也从真实文件提取。

原生代码与宿主断言均经过独立审查，范围内无已确认遗留P0/P1/P2。宿主平台、存储、距离转换和网络是stub，不能当作真实MapKit或SwiftData验收。

## 本机平台构建未完成

使用 `dev-ios-session run --profile primary` 和现有Primary iPhone设备，在任务专用DerivedData与PackageCache中尝试 `build-for-testing`。没有抹除、关闭或重建设备。

11个包均已核对并checkout到项目锁定的真实版本与SHA；没有改Package.resolved或生产依赖。Sentry 8.58.2的manifest要求下载五个官方xcframework，合计约451MiB。SwiftPM的多个官方binary artifact请求超时，未进入源码编译。任务自己的helper子树已停止以释放共享锁；没有停止其他服务或修改共享依赖缓存。

因此，本地**没有取得原生build通过或定向Simulator测试通过的证据**。原计划的 `POISearchOutcomeTests`、`DiscoveryRefreshTests`、`TrustBadgeMappingTests`、`ToolRouterOutcomeTests` 尚未运行。构建与下载诊断原始记录保存在本机正式证据目录 `chat-map-v4-evidence/native/`。PR CI将另行验证；不能借用旧提交的绿色结果。

## 尚未覆盖

新的SwiftUI四项导航、原生对话scope/阅读位置迁移、真实MapKit网络、跨启动存储、模型自主tools编排、真机、系统键盘、Dynamic Type与VoiceOver。原型中的地点、地图位置和步行时间为演示数据；公共provider探测与原型是独立证据，见[Eval报告](evals/README.md)。
