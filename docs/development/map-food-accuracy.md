# 地图与餐饮准确性修复及验收

日期：2026-10-15。实现分支：`codex/map-food-accuracy`，基线 `f38528c1`。

**最终交付更新：** 本文保留当轮失败和限制；后续修复与最新证据见[交付报告](map-food-accuracy-delivery.md)。

**续测更新：整体准确性验收尚未通过。** [后续实测](map-food-accuracy-followup.md) 已修复真实平台身份合并及 Edge 异常字段遗漏，同时发现 iOS 地图渲染坐标契约和同 ID 存量资料刷新仍有缺口。下方测试结果对应本报告的上一轮提交，不能代表这些剩余问题已经解决。

本轮修复数据进入、合并、排序、缓存和显示的确定性错误。内部仍使用 WGS84 `[longitude, latitude]`，没有改动 Experience 存储结构，也没有对地图渲染器整体加偏移。

## 可复核的原因与改变

| 原因                                                                                          | 本轮行为                                                                                                     |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| 郝店镇同一公开 POI 的 MapKit 原始坐标与 Amap 一致，但只有 Amap 做归一化，两条路径相差约 602 m | 搜索入口按来源及国家信息归一到 WGS84；CoreLocation GPS 和已有 Experience 不重复转换                          |
| 大陆矩形包含首尔、加德满都、乌兰巴托                                                          | 使用离线国家几何；已解析的国家证据优先，覆盖沿海机场及填海区域，未知国家时保守退回离线边界                   |
| 约 11 m 坐标格把相邻店当同店，串用评分与营业时间                                              | 使用有界距离、规范名称、电话、地址及来源身份匹配，矛盾信息保留独立门店；同店跨格可以合并                     |
| Amap 五分制被当十分制显示，Foursquare 十分制又按五分阈值排序                                  | 显式保存 provider rating/scale/source，排序与展示统一用归一后的十分值；缺失或非法评分不补值                  |
| 餐饮召回排除快餐，并把低评分等同“不存在”                                                      | 广泛探索包含 `050000`；快餐与低评分真实门店可进入候选，评分参与排序，基础设施过滤保留                        |
| 业务限流中断分页后把不完整结果当完整缓存，缓存命中又丢掉已消费的信号                          | 进程内 1.1 秒请求调度、有限重试；保留成功页并提示不完整，不缓存失败分页；5 分钟会话缓存恢复关联信号          |
| “附近”实际扩到 100 km，提示词却描述 12 km                                                     | 统一渐进范围为 1.5 / 3 / 6 / 12 km，显示小数半径；归一后按距离复核 MapKit/Amap 返回值                        |
| 浏览远处城市时，部分查询重新围绕 GPS 或城市中心                                               | 保留最后地图中心和自选乡镇锚点，探索与附近列表使用相同查询起点                                               |
| 降级卡固定显示 7 分、9–21 点，并把建议时间结束称为关门                                        | 降级保留地点基本事实，评分显示“尚未评估”、建议时窗为空；相关文案明确是推荐时段，未知评分不压低真实问卷结果   |
| JavaScript 无法精确表示 64 位 provider ID                                                     | Native 发送十进制字符串，模型仅处理批内小编号；服务端恢复真实 ID 后落库、返回；城市读取兼容旧数字及新字符串  |
| 旧生成缓存只看 ID/客户端 key，地点事实更新后仍命中                                            | Native/Edge 对事实、语言、城市、模型及提示版本指纹化；Edge 和城市共享读取限制 7 天，城市读按时间确定最新内容 |
| Web 把 UTC 当目的地时间，生产无配置时返回示例地点                                             | 接收目的地 IANA 时区；未知时区不推断当前营业；生产返回错误，开发样例也必须符合半径；区域改变不保留旧 markers |
| 城市落地页 SVG 看起来像真实地理地图                                                           | 在图上直接标注“体验示意图”，说明位置与步行时间用于演示                                                       |

评分归一只修复尺度误读，不代表不同平台评分统计分布相同。匹配缺少可靠证据时可能保留重复候选；不承诺自动识别所有分店和楼层。

## 郝店镇研究证据

测试锚点为“湖北省广水市郝店镇人民政府”，公开 Amap GCJ-02 坐标为 `113.759462,31.787312`，行政代码 `421381`。这不是用户 GPS，也不是行政边界中心。

研究时 3 km 全部餐饮查询返回 35 条，旧规则保留 22 条：排除了 3 条快餐、9 条低评分、1 条名称黑名单。35 条中只有 13 条带今日营业时间、15 条带消费信息。不能将这些数量解释成 35 家均已实地确认营业，也不能将全部排除项认定为误杀。

macOS MapKit 实测用于证明来源数值差异；它不替代 iOS 真机底图、导航和 GPS 的校准。固定回归同时覆盖郝店镇、首尔、加德满都、乌兰巴托、海南、香港、浦东机场、厦门机场及填海区域的国家证据覆盖。

## 验证

- Web：12 项测试通过；AI：122 项测试通过，包含两个不同批次的超大真实 ID 不串店、不丢精度。
- Web/AI TypeScript 类型检查通过。
- TS / Swift / DB / SwiftData 字段一致性通过。
- 英中本地化、硬编码字符串和中文标点检查通过。
- Web lint 未通过：仓库没有现成 ESLint 配置，`next lint` 进入初始化交互后退出；没有将此项计为通过。
- macOS host：26 / 26 通过，直接编译实际坐标、匹配及评分生产源文件。
- 独立审查：发现并修复 ID 共享读取、沿海地域判断、未知评分聚合、城市缓存时效、服务失败分类和半径格式问题；最终静态复核无未解决 P0/P1。
- iOS 完整 `build-for-testing` 通过；Primary iPhone（iOS 26.5）79 / 79 项受影响 XCTest 通过，无跳过；包含乡镇锚点保持、硬半径、超大 ID、缓存部分失败和未知评分 UI。
- [验收记录](evidence/map-food-accuracy-20261015/acceptance.json)、[原生测试结果](evidence/map-food-accuracy-20261015/native-test-summary.json)、[未知评分卡片截图](evidence/map-food-accuracy-20261015/unassessed-card.png)。截图使用合成 POI 夹具，不代表真实门店。

重跑 host：设置 `MAP_ACCURACY_ARTIFACT_DIR` 到已登记产物目录后执行 `scripts/qa/map-accuracy-host.sh`。原生验收复用一次 `build-for-testing`，再在共享 Primary iPhone 执行受影响的 `test-without-building`。所有本机 iOS 交互使用 `dev-ios-session`。

## 发布顺序与边界

1. 先部署并验证 `synthesize-experiences` Edge Function 的字符串 ID 兼容入口，再发布 Native。旧 Native 数字 ID 仍可读取，新缓存按新事实版本生成。本轮没有执行线上部署或 TestFlight 发布。
2. 本轮未改历史已保存地点的坐标，也未自动清除用户收藏或离线记录；旧种子数据和历史生成文案仍需要逐条核对真实门店来源。以前混入的错误地址、评分和时窗需基于来源与版本单独迁移，不能按距离批量修正。
3. 真实营业状态、菜单、价格与照片只能来自可核实且有授权的门店数据；模型文案不构成实地确认。乡镇缺乏上游字段时界面应显示未知。
4. 海岸及国际边界仍有离线概化误差；在线国家证据优先。真机需在同一地点核对 GPS、搜索、底图建筑、标记和导航目的地，才能确认端到端落点。跨设备的 Amap 账号总 QPS 仍需服务端调度。
5. Foursquare 旧 V3 接口迁移、OSM way/relation 召回、完整字段级证据模型及图片实体校验属于后续独立数据源改造；没有将它们描述为本轮已完成。

## 上游来源

- [高德坐标说明](https://lbs.amap.com/api/javascript-api-v2/guide/abc/basetype)
- [高德错误码](https://lbs.amap.com/api/webservice/guide/tools/info)
- [Apple 搜索区域优先级](https://developer.apple.com/documentation/mapkit/mklocalsearch/request/regionpriority)
- [Foursquare 评分定义](https://docs.foursquare.com/data-products/docs/places-pro-and-premium)
- [Natural Earth 公有领域许可](https://www.naturalearthdata.com/about/terms-of-use/)
- [Natural Earth 1:10m 国家数据](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_admin_0_countries.geojson)；完整上游 SHA-256 随 bundle GeoJSON properties 保存。本数据用于数据源路由，不用于测绘、导航或行政边界认定。
