# 地图与餐饮准确性修复交付

日期：2026-10-15。分支：`codex/map-food-accuracy`。本报告接续[初次修复](map-food-accuracy.md)与[续测](map-food-accuracy-followup.md)，历史报告中的失败记录保留。

**当前状态：准确性修复已通过本机原生验收和独立审查；最终远程门禁以 [PR #667](https://github.com/getyak/solo-compass/pull/667) 最新提交的检查记录为准。** 不将坐标公式往返、公开 POI 数值差异或单次截图当作全城市实地定位准确的证明。

## 为什么此前仍不准确

1. **搜索、存储、底图不是同一个坐标边界。** 只把搜索归一为 WGS84，再直接交给当前底图，仍可能产生约 600 米的显示偏移。香港地点也可能返回 `CN`，国家码不足以判断 datum。台湾/港澳矩形还误包了福建与深圳部分陆地。
2. **旧内容不会因上游更新而刷新。** 可见列表提前丢弃同 ID，数据库只插入新 ID，服务只在插入时 reload。营业时间或评分即使已被上游纠正，用户仍看到旧卡片。
3. **多来源合并与未知字段具有独立错误。** 五分制误当十分制、相邻门店串资料、缺失评分补成固定值、模型坏字段进入缓存等，在前两轮修复；这些不能靠移动地图标记解决。

## 本次行为

### 坐标边界与实际地图

内部持久化、距离、地理围栏仍使用 WGS84 `[longitude, latitude]`，不批量加减偏移。新增 `MapKitCoordinateSpace`，分别识别搜索输出与原生注解输入：同一区域的两个不同公开锚点都与独立参考坐标一致，才启用对应能力；搜索与渲染允许采用不同 datum。

参考坐标来自外部公开数据，既不从 MapKit 返回值反推，也不从现有转换器生成。120 米阈值用于区分两种相差数百米的 datum，并容纳建筑范围及参考资料精度；它不是餐厅入口的精度承诺。原生注解仅证明地图 API 的显示契约，不能替代地理真值。

- 中国内地：东方明珠、广州塔；香港：天文台旧三角点、香港大会堂；澳门：仁慈堂、邮政总局。
- 使用 Natural Earth 的实际大陆、港澳台及邻国陆地几何，替代重叠矩形。离线海岸线以外的填海位置保持未知，国家信息仅选择校验区域；得到该区域的独立锚点结果后才转换。
- 标记、聚合、地点选择标记、当前位置、圈层、路线、相机与点击均经过同一显示边界。校验未知时保留最后实际显示的相机，不把内部 WGS84 当作底图输入回退。
- 校验限于会话，5 分钟失效；前台恢复和网络路径变化会失效重验。取消一个等待者不会取消其他调用者的共享校验或删除成功结果。高德来源的已归一坐标仅为概化海岸线以外的精确点补充大陆路由，仍需同样的独立 datum 校验，不把附近邻国点一起转换。
- 搜索列表保留原始 `MKMapItem`，可通过菜单在 Apple Maps 打开。没有核实坐标的结果不能写入自选地点或进入距离计算。
- 高德导航出口使用官方规定的 `dev=1` 接收 WGS84；地点名经独立 URL 参数编码，不能注入新的导航参数。

**兼容门禁：** 本次自定义标记的显示兼容验收范围为 iOS 26.5、公开 `MKMapItemAnnotation` 与平面 standard 样式。受影响区域在其他尚未验收的 runtime 保留地点列表、搜索及外部导航，隐藏未核实的自定义标记。卫星与混合样式尚未获得独立渲染完成证据，在这些区域提供切换标准地图的按钮，不重复发起无效重试。iOS 最低版本保持 17；iOS 17 缺少该原生注解 API 时，已核实的搜索能力仍独立可用。海外明确采用公共 WGS84 契约的区域继续正常显示。拓展 runtime 的显示支持需要重复本报告的实际原生验收，不能仅增加版本白名单。

### 已保存餐饮资料刷新

`mergeDiscovered` 只更新明确来自已有自动发现管道的同 ID 数据。新增和刷新共同拒绝非法 GeoJSON 坐标、非自动来源以及不明确来源。批内重复也应用相同的新旧与防降级策略，避免“最后一个旧值”获胜。

- 保留收藏等独立记录、用户状态、完成记录、标签、创建时间、照片、社区评分和人类置信信号。新结果缺少亮点时保留已有亮点，提供新亮点时更新。
- 人工创建、精选、实访、可信人工核实和来源不明的内容不自动覆盖。
- 拒绝较旧内容及把丰富 AI 内容降为离线 skeleton。完整的新合成以 `nil` / 空数组清理旧机器评分、营业时间、指引和时窗，不将旧值冒充新证据。
- 渐进探索、legacy 路径及免费探索统一刷新可见列表和已选详情。只有实际插入的新 ID 增加“新增地点”数量；仅刷新旧店也立即更新显示。

这不是历史数据的批量迁移。再次发现且符合策略的记录会更新；未重新发现或含人工证据的旧记录继续保留，避免破坏用户内容。

## 验证与复现

结果、源码绑定及失败试验记录保存在[正式证据目录](evidence/map-food-accuracy-delivery-20261015/acceptance.json)。确定性回归覆盖区域边界、coast 未知、两种接口不同 datum、iOS 17 搜索降级、共享调用取消、失效相机、同 ID 刷新、用户证据、完整未知事实、非法坐标、旧/降级重复项和 refresh-only 可见项。

实际原生验收为 `MapKitLiveAccuracyTests`，默认 CI 跳过，需要显式设置 `SOLO_MAP_LIVE_VERIFY=1`：分别加载两个独立锚点，再把实际 `MKMapItemAnnotation` 与生产边界生成的自定义注解放入同一个原生地图，比较真实注解中心。误差按 `UIScreen.scale` 换算为物理像素，要求不超过 1 像素；同时保留各地区标准底图截图和独立参考残差。另调用实际地点搜索服务搜索郝店镇人民政府。测试代码不请求 GPS 或业务账号，不使用付费模型。

本机验证结果：

| 验证                 | 结果与边界                                                                 |
| -------------------- | -------------------------------------------------------------------------- |
| 原生定向回归         | 107/107，0 跳过；随后一处相机待处理状态清理再经最终构建与 live 验证        |
| 最终实际 MapKit 验收 | iOS 26.5 / Primary iPhone，1/1；内地、香港、澳门标准底图全部加载并目视检查 |
| 原生/自定义注解中心  | 三地区均为 0 物理像素差；不是 GPS 或餐厅入口误差                           |
| 独立参考残差         | 东方明珠 52.72 m、香港天文台 27.05 m、澳门仁慈堂 15.61 m；用于 datum 分类  |
| 郝店镇搜索           | 实际生产搜索服务返回可核实的内部坐标                                       |
| Swift 宿主回归       | 38/38                                                                      |
| TypeScript workspace | 11 项 test task 成功；typecheck、parity、localization 通过                 |
| 大 diff lint 回归    | 3/3：超过 2 MB 的合法 diff 通过、违禁模式失败、明确 allow 通过             |

旧 head 的远程 CI 曾暴露两个问题：地理数据使 `git diff` 超过 Node 子进程默认缓冲区，已改为有界 32 MiB 并保留规则检查；原 marker 性能微基准单次为 39.1%，低于 40% 门槛，本机原测试 5 次中也有 1 次失败。被测热路径没有变化。测量调整保留 100 对交替样本、p95 比值、40% 门槛和结果一致性，仅增加每批工作量并完整暖机；调整后两项测试各重复 5 次，10/10 通过，提速 40.6%–46.9%；完整数值随目录保存。不能用旧提交绿灯代替最新提交的完整 CI。

早期卫星/混合截图、澳门身份校验失败和未加载瓦片的尝试均记录在 [trial-history.json](evidence/map-food-accuracy-delivery-20261015/trial-history.json)。`InvalidTransition` 曾包装本地校验异常，不能作为搜索对象生命周期故障的证据；相关实验性桥接代码没有进入最终实现。

本机所有原生操作通过共享 `dev-ios-session`，仅使用 Primary iPhone；一次构建后复用 `test-without-building`。宿主回归执行 `scripts/qa/map-accuracy-host.sh`；边界重建使用 `scripts/qa/generate-mapkit-routing-boundaries.py <冻结的 Natural Earth 文件> <输出目录>`，输入 SHA 不一致时拒绝重建。

## 交付范围与实际限制

远程 Git 合并不等于 Edge Function 已部署或 App 已发布。发布时仍需先部署兼容新旧 ID 的 Edge Function，再发布 Native；本次不手动触发 TestFlight、不部署 Edge 或迁移线上用户数据库。合并到 main 会触发仓库既有 TestFlight 自动流程；是否上传成功须查该 workflow，不能从 Git 合并状态推断。

上游缺少的真实营业状态、菜单、价格及图片身份仍应显示未知，模型文案不构成实访。独立锚点验收也不能证明每个门店、楼层和入口正确。真实设备 GPS 与步行入口核对、跨设备高德总 QPS、Foursquare API 迁移、OSM way/relation 召回及字段级证据模型仍属于独立后续工作。

## 公开来源

- [Apple CLLocationCoordinate2D](https://developer.apple.com/documentation/corelocation/cllocationcoordinate2d)、[MKMapItemAnnotation](https://developer.apple.com/documentation/mapkit/mkmapitemannotation)：公共 API 契约与可用性，不代表所有服务环境天然一致。
- [高德 iOS URI 路线参数](https://lbs.amap.com/api/amap-mobile/guide/ios/route)：`dev=1` 转换 WGS84，`dev=0` 表示已经偏移的输入。
- [Natural Earth 许可](https://www.naturalearthdata.com/about/terms-of-use/)、[冻结输入的上游文件](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_10m_admin_0_countries.geojson)：公有领域粗略地理资料，源 SHA 随资源保存，不作测绘或行政边界认定。
- [东方明珠 Q223207](https://www.wikidata.org/wiki/Q223207)、[广州塔 Q168400](https://www.wikidata.org/wiki/Q168400)、[香港天文台 WGS84 参考](https://www.hko.gov.hk/en/gts/astron2024/files/HKO_almanac_2024.pdf)、[香港大会堂 Q837115](https://www.wikidata.org/wiki/Q837115)、[仁慈堂 Q4310094](https://www.wikidata.org/wiki/Q4310094)、[澳门邮政总局 Q909429](https://www.wikidata.org/wiki/Q909429)：不同公开实体的外部坐标参考，资料与建筑范围有精度限制。
