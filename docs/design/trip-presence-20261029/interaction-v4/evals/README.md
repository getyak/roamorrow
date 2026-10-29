# GET-324：用户场景与 Agent tools Eval

本轮把用户真实旅行任务转成可复跑的断言，同时把证据分层。跨城市收藏目前只用合成记录验证状态过滤，没有真实多城市账号或地点库验收。**宿主测试通过不代表真机、模型自主编排、真实账号或生产能力验收通过。**

## 本轮做了什么

- `scenarios.json`：16个用户任务，覆盖对话→地图→原对话、地图附近/收藏、手动区域、来源未知、计划确认、只打开导航和资料注入边界。
- `map-flow.test.mjs`：直接读取 V4 的 `assets/map-flow.js`，用隔离状态执行15个旅行场景。它验证原型状态契约，不是浏览器、SwiftUI或定位权限验收。
- `run-tools-eval.mjs`：复用已有 Agent Map Layer 的相机、schema、领域、受控边界、证据完整性与评分测试，并跑 provider 重定向安全测试。带 `--live` 时最多6个公共provider请求，不调用模型或个人邮件/日历。
- `verify-public-route.mjs`：将本轮记录的实际公共步行路线放入现有 map domain，再核对原有 `build_route` 输出 schema、时间与 geometry。没有新增网络请求，不冒充模型自己编排。
- `results/`：可检查的运行记录。公共 Wikidata 原响应压缩保存并记录 SHA-256；没有私有账号、密钥或个人旅行历史。

## 已观察到的结果

| 层次               | 实测 / 审查范围                                | 结论                                                                                                                         |
| ------------------ | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| V4 原型状态        | 15个纯状态场景                                 | 通过；浏览器手势和原生恢复仍需主任务另验                                                                                     |
| 既有地图领域与契约 | 35个Node测试，串行执行                         | 35通过，0失败，0跳过                                                                                                         |
| provider授权头边界 | 2个Python测试                                  | 跨域重定向与HTTPS降级均不转发授权头                                                                                          |
| Wikidata真实只读   | 4次HTTP请求                                    | 上野公园唯一实体；“浅草寺”返回寺庙与附近大草鞋两个候选，不能自动混为一处                                                     |
| OSRM真实只读       | 1次matrix请求 + 1次direct route请求            | matrix遇到URLError；direct foot route HTTP200，2280.1秒、2850.2米、211个geometry点。失败与成功分别记录                       |
| 真实路线→领域输出  | 把上述已获取的direct route注入独立domain       | 既有schema通过，按39分钟排期，保留真实geometry；不是生产runtime全链路                                                        |
| Go Harness         | 使用项目要求的官方Go1.27.3重跑限定只读工具测试 | 25个目标测试通过，0失败/跳过；首次本机Go1.26.6拒绝及官方模块代理unexpected EOF保留为环境记录，随后已用官方校验archive恢复    |
| iOS原生Agent       | 56项宿主检查及受保护的本机平台构建尝试         | 宿主56/56通过；本机平台构建在Sentry官方binary artifact下载阶段超时，未进入编译/定向测试；[详细记录](../native-validation.md) |

真实公共探测总量6个请求。继续路线测试时，QA脚本**明确指定**寺庙实体 `wikidata:Q615183`，没有把这次测试选择写成模型自主消歧。原始查询仍保留两个候选。正式产品应让用户选择或继续核对具体场所。

## 现有 tools 不能混为一套

| 能力层                          | 实际入口                                                                                       | 已有能力                                                                                                                                                     | 本轮证据                                                                                        |
| ------------------------------- | ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| 原生iOS Agent                   | `VoiceAgentToolRouter.allTools`                                                                | `explore_nearby`、`search_places`、类别/质量筛选、`show_details`、`save_to_favorites`、`navigate_to`、`build_route`、`compile_workday_route`、`web_search`等 | 源码修复 + source worker新鲜宿主56/56通过；平台、存储、网络边界为stub，原生SDK/真机仍未验收     |
| Go账号上下文Harness MCP         | `apps/api/internal/harness/tools.go` 的 `toolRegistry`                                         | 只有 `get_traveler_profile`、`list_calendar_events`、`search_travel_mail` 三个只读工具；有明确授权、范围和来源约束                                           | 限定宿主测试，provider/账号均隔离stub；不是个人Google账号验收                                   |
| Agent Map Layer v1验收runtime   | `docs/design/agent-map-layer-v1/demo/contract.mjs`                                             | `create_map`、`search_places`、`plot_places`、`build_route`、`update_day`、`get_map_link` 六个工具；版本、幂等、预览、撤销与来源契约                         | 35个既有宿主测试 + 有界真实provider probe；它仍是独立验收runtime，不等于已接入iOS生产工具注册表 |
| 本轮V4 HTML                     | `interaction-v4/assets/map-flow.js` 与 `app.js`                                                | 导航、附近/收藏、选点、明确搜索区域、带scope回聊与返回来源                                                                                                   | 演示数据；没有调用iOS原生tools                                                                  |
| 初始产品规划里的Trip/票务执行层 | `trip.get/upsert`、`booking.ingest`、`truth.diff`、`pay.preview`、`book/change/cancel.execute` | 未在上述生产注册表中发现这些命名工具；不由本轮UI补齐                                                                                                         | 仍是后续设计/实施边界，不能把一张确认卡称为真实出票或付款                                       |

`navigate_to` 当前只调用 NavigationLauncher 打开地图步行导航；不调用网约车或旅游支付。`build_route` 返回未保存的 proposal；`compile_workday_route` 不允许静默放宽硬约束。`save_to_favorites` 的现有原生契约是toggle，不能当作可盲目重试的幂等set操作。

## 本轮发现的真实工具缺陷

1. 原生 `executeSearchPlaces` 解析了query，却只调用通用附近探索，query只在返回JSON中回显。用户要求“拉面店”可能获得泛附近结果。
2. 原生 explore/search省略坐标时直接回退清迈 `MapViewModel.defaultCenter`，而非当前明确的地图搜索范围。对手动选东京、拒绝定位等场景会形成错误的“附近”。

以上已由主任务的 `agent_search_fix` 分工修复，并补了质量/类别过滤后的渐进扩圈、全部隐式来源的失效保护。最新宿主结果为56/56通过，已读回并保存到 `results/native-search-host.log`。这些检查提取生产搜索片段，但平台/存储/网络仍是stub；不能证明真实MapKit分类、SDK距离转换或真实await期间的原生重入。本机平台构建在锁定Sentry官方二进制下载阶段受阻，未进入编译；详见[原生验证记录](../native-validation.md)。本目录没有修改生产源码。

## 复跑

```bash
# 纯状态与契约，无付费服务、账号或新常驻进程
node --test --test-concurrency=1 docs/design/trip-presence-20261029/interaction-v4/evals/map-flow.test.mjs
node docs/design/trip-presence-20261029/interaction-v4/evals/run-tools-eval.mjs

# 可选：限定Go Harness测试；GET324_GO可指向项目隔离的官方Go1.27.3，不改全局版本
GET324_GO=/path/to/go1.27.3/bin/go node docs/design/trip-presence-20261029/interaction-v4/evals/run-tools-eval.mjs --go

# 显式进行有限公共provider探测（东京公共地标，最多6次请求）
node docs/design/trip-presence-20261029/interaction-v4/evals/run-tools-eval.mjs --live

# 只重放已经记录的实际路线，不再联网
node docs/design/trip-presence-20261029/interaction-v4/evals/verify-public-route.mjs
```

正式验收还缺：SwiftUI四项导航、实际键盘/中文输入法、VoiceOver、定位拒绝的系统行为、原生对话恢复、真实模型自主tools编排、真实账号来源、跨启动持久化以及部署/真机证据。不要将这些宿主测试、15个原型状态测试或一次公共provider成功解释为总体成功率或生产可用性。
