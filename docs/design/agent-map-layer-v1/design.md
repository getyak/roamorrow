# Roamorrow：Agent 的 Map Layer v1

设计提案 / GET-294 / 2026-10-29。用户指定方向：外部 Agent 负责对话，Roamorrow 承接地图、行程编辑与分享。以下默认项由本设计提出，尚未代表用户逐条批准。此次交付设计与独立原型，生产 server 明天按任务书另行实现。

## 1. 结果先定义

用户在兼容客户端说「规划东京 3 天」。Agent 找到真实地点并安排三个区域，调用工具保存，给出地图链接。打开后第一屏就能看见三天的颜色、顺序、停留时间和交通证据；所有者拖动浅草寺到另一天，两天一起重新计算、一起保存，遇到冲突可撤销。换一个没有所有者身份的浏览器打开同一链接，可以看、可以复制自己的版本，不能改坏原图。

产品承诺是一张**持续可操作的旅行地图**。生成一个漂亮截图不够；分享链接必须指向持久化、带版本的真实地图。Agent 负责理解偏好与解释选择；服务负责地点解析、权限、约束、确定性计算和落盘。模型不能凭空写坐标、营业时间、交通耗时。

核心关系是：一个 map 是多天容器；一天是有顺序的 stops；stop 指向 POI，可选关联真实 Experience。POI 只是地理锚点，不能因被落点就升级成「已验证体验」。例如「浅草寺」是地点，「清晨绕开人群走雷门与寺院」是可选体验描述，来源未支持的形容词和最佳时间都不能伪造。

## 2. 狭窄入口与发散路线

首批用户：已经在 Grok / Muse / Dots 里用自然语言做城市短途计划、接着手工复制到地图的独行旅行者。付费或留存假设未被用户研究验证，不能当成已有需求数据。

| 方案                                 | 价值                                         | 代价 / 取舍                                      |
| ------------------------------------ | -------------------------------------------- | ------------------------------------------------ |
| A. 只收地点，返回只读地图            | 接入最快，适合清单展示                       | 用户仍得去别处安排天数；回流后没事做             |
| B. 有状态 Map Layer + 同一套编辑命令 | Agent 建图、人在图上接着改；跨天编辑有一致性 | 要做版本、约束、权限与可持久化分享；推荐 v1      |
| C. 自建完整旅行对话 Agent            | 所有体验自己控制                             | 重做 Grok 已有入口，模型成本与对话 UX 分散注意力 |

本提案选 B。先验证「生成后是否有人动第一下」而不是追求工具数量。v1 把 1–7 天、一个城市、最多 40 stops 做好；不做跨国长途、酒店/航班预订、实时协作光标、自动付款或全天实时导航。

下一步发散按同一地图模型生长：

1. 圈区规划：画多边形 → `search_places.area` 缩小候选 → 用户选后排进当天。区域是筛选条件，不代表圈内所有地方都可达。
2. 雨天替换：给室内候选，保留预约与固定时间，先预览差异再应用。
3. 时间轴联动：拖出发时间只改调度，不移动真实 POI；地图高亮受影响路段，保留已锁定预约。
4. 「就近插一个咖啡」：只重算插入处附近，呈现多花多少时间，不重排全部三天。
5. 返回原 Agent：「我改好了，继续问 Grok」携带 map ID / 版本，客户端支持资源读取时读最新状态；不自动向第三方发送新消息。
6. 旅行现场：导航、离线、附近候选留给 App 的既有体验能力。地图编辑完成本身就有用，不靠强制下载形成回流。

## 3. 现实能力与复用边界

基线：`origin/main` 的 `86c4b1e6`。源代码比旧说明优先。

| 现有代码                                          | 观察                                                                                        | 建议                                                                                         |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `apps/api/internal/harness/mcp.go`                | `/mcp` 固定 2025-11-25，支持 initialize/tools/list/tools/call；认证、Origin、输入上限已存在 | 不改冻结契约，新增 `/mcp/maps`；抽取可复用传输 helper 前先有回归覆盖                         |
| `apps/api/internal/harness/tools.go`              | 三个 onboarding 工具，身份来自验证后的 subject                                              | Map Layer 独立 registry；不让地图集成获得邮箱/日历权限                                       |
| `packages/routing/src/{types,solver,valhalla}.ts` | 约束求解、营业时间证据、未知矩阵拒绝已存在；交通模式仅步行/骑车/汽车                        | 复用约束和证据概念；东京公共交通另加提供商，不把 Valhalla 步行矩阵包装成地铁                 |
| `apps/web/src/app/api/routes/compile/route.ts`    | TS 路由编排边界                                                                             | 将求解编排提取为服务给 Web/API 复用；Go 通过内部 HTTP 调用 TS 编排，不能从 Go 直接 import TS |
| `apps/web/src/app/trip/[slug]/page.tsx`           | 静态 in-memory 示例回顾页                                                                   | 新建 `/m/[map_id]` 编辑页与 `/s/[opaque_token]` 分享入口；不把示例 URL 冒充动态地图          |
| `packages/core/src/route.ts` / Swift 镜像         | 现有 Route 多为单条体验路线                                                                 | 新 map-layer DTO 与现有 Route 适配；本轮不更改 Experience / Swift parity                     |

旧 `PRODUCT_BRIEF.md` 把多日规划列为 out of scope。用户此次请求是明确探索该扩展；提案作为附加 Agent 入口，保留独行、地图优先、来源透明原则，尚未把旧路线替换为生产多日规划。

### Grok 接入事实

[xAI 官方 Remote MCP](https://docs.x.ai/developers/tools/remote-mcp) 确认 API 的远程 MCP，字段有 `server_url`、`server_label`、`allowed_tools`、`authorization`；不能据此声称 grok.com 消费聊天界面可自定义任意 MCP。Muse / Dots 的具体安装方式也未实测。

生产第一条可承诺链路：自己的集成演示页或 CLI → xAI Responses API → 公网 HTTPS `/mcp/maps` → map tools → Web 分享链接。消费客户端只有在确认提供外部 MCP 安装入口且实测后再列入支持名单。本次本机无 `XAI_API_KEY`，不能给 Grok 实际调用盖章。独立审查发现并修订了公开 stop 集合、时变公交、绑定日期预约、并发幂等和 unknown 可达性五项边界。

[MCP 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http) 已修改会话与元数据规则。v1 wire 明确冻结为 **2025-11-25 compatibility profile**，与当前 Go transport 一致；不是声称实现最新规范。支持范围由 initialize 协商结果决定。未来升级独立版本和兼容测试，不能把旧 initialize 与新版 headers 拼起来。

## 4. 六个工具与读状态

用户消息列出五个名称。本设计补第六个 `search_places`：先将地名变成可验证的 provider place reference，再允许落点。`get_map` 是授权的 REST / MCP resource 读取能力，避免为了补数让 Agent 直接编造坐标。

| tool            | 入参要点                                                                                                                              | 出参要点                                                         | 副作用                                   |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ---------------------------------------- |
| `create_map`    | title、city、day_count、可选 start_date、timezone、idempotency_key                                                                    | map_id、version、day_ids、owner edit URL、assumptions            | 建私有草稿，版本 1                       |
| `search_places` | map_id、queries[]、可选 area GeoJSON Polygon                                                                                          | 每个 query 的 candidates[]、provider/place_id/坐标/来源/解析状态 | 只读，不能保证有结果                     |
| `plot_places`   | map_id、expected_version、idempotency_key、items[{place_ref,day_id,duration_minutes,experience_id?,fixed_start_minute?,lock_to_day?}] | stop_ids、完整 map snapshot                                      | 原子新增落点，版本 +1                    |
| `build_route`   | map_id、expected_version、idempotency_key、transport_mode、day_plans[]                                                                | 调度、路段证据、warnings、完整 snapshot                          | 全部受影响天一起排好，版本 +1            |
| `update_day`    | map_id、expected_version、idempotency_key、dry_run、operation 联合类型                                                                | affected_day_ids、before/after、diff、edit_id、snapshot          | move/reorder/time/duration/undo 共用事务 |
| `get_map_link`  | map_id、expected_version、idempotency_key、expires_in_days、visible_stop_ids                                                          | 只读 share_url、owner edit_url、expires_at、map_version          | 建立/复用 view grant，不改 map version   |

schema 显式使用 JSON Schema draft-07（MCP 允许的兼容 profile），坐标 tuple 逐项限制经度/纬度；官方 SDK 默认校验器对未声明的 2020-12 prefixItems 兼容性不足，已在真实 SDK 联调中识别并改正。完整字段、必填、数值限制、枚举、联合类型和每个输出都在 [contract.mjs](demo/contract.mjs)。`node contract.mjs` 输出原生 `tools/list`，可直接喂 SDK 注册；生产适配器必须同时验证输入和输出，不只拷贝描述。

所有 object 默认 `additionalProperties: false`。客户端不得传 owner_id、用户 email、任意访问 URL、原始 coordinates。坐标仅来自 server 的 POI adapter；GeoJSON 统一 `[longitude, latitude]`，WGS84 / EPSG:4326。高德国内 GCJ-02 在 adapter 边界转换并保留原 CRS，不能在东京例子上掩盖国内偏移。

### 读状态为何不占一个工具

`resources/read` URI `roamorrow://maps/{map_id}` 返回同一 MapSnapshot；`GET /v1/maps/{map_id}` 支持 ETag。resource 要求 map:read + owner/grant，不能因为知道 ID 就读到别人的图。只支持 tools 的客户端可重复调用相同 key 的 `create_map` / `build_route` 得到原结果，但继续编辑前必须由 host 提供新 snapshot；不允许猜 expected_version。v1 接入检查要求客户端能用 REST/resource 刷新；不具备此能力时只承诺首轮创建和打开地图，连续 Agent 编辑为不支持能力。未来按真实客户端需要再增第七个只读工具。

### 输出信封

MCP `structuredContent` 和文本 JSON 内容一致。成功 `{ok:true,data:...,warnings:[]}`；业务失败 `{ok:false,error:{code,message,retryable,details:{...}}}` 且 `isError:true`。每个 tool 的 outputSchema 同时包含成功与失败分支。未知工具/非法 JSON-RPC 是协议错误；合法调用的校验、权限、冲突、不可排程是业务失败。不要把「暂缺交通」写成 0 分钟。

| 错误                                    | 行为                                                                         |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| `VALIDATION_ERROR` / `PLACE_UNRESOLVED` | 修参数或让用户消歧；无写入                                                   |
| `NOT_FOUND`                             | 跨租户和不存在统一结果，防枚举                                               |
| `VERSION_CONFLICT`                      | 返回 current_version + 有权限的最新 snapshot；用户选择后重放意图，不自动覆盖 |
| `IDEMPOTENCY_CONFLICT`                  | 同 key 不同 payload 拒绝；原结果仍可读                                       |
| `INFEASIBLE`                            | 固定预约、全天结束、交通限制冲突；完整 rollback，返回可行动原因              |
| `PROVIDER_UNAVAILABLE` / `RATE_LIMITED` | retryable + retry_after；保持旧图                                            |
| `UNDO_CONFLICT`                         | 后面有新编辑时不粗暴倒回历史；可手工重排                                     |

幂等作用域 `(verified_subject, client_id, tool_name, idempotency_key)`，canonical payload hash，TTL 至少 24h。先比较 key，再检查 expected_version，确保超时重试不会二次新增；同 key 同 payload 返回原 snapshot，不是最新 snapshot。不同 key 才表示新意图。幂等表唯一键必须在执行前以 INSERT/claim 原子抢占，同 key 并发请求等待首个结果或返回 retryable in-progress；create_map 尚无 map ID 也受此约束。claim 带 lease，崩溃后可接管；业务 map/edit 变更和最终成功响应写入必须同一 DB 事务。provider 超时等暂时失败释放 claim，不永久缓存失败。读回最新状态用资源。写锁在 map 粒度，provider 请求在锁外算草稿，提交时 CAS；不能长时间持 DB 事务等网络。

## 5. 最小数据模型与调度

### 持久化表

- `maps(id, owner_sub, client_id, title, city, timezone, start_date nullable, version, status, created_at, updated_at)`。
- `map_days(id, map_id, day_index, local_date nullable, color_token, transport_mode, allow_unknown_travel, start_minute, end_minute)`；固定颜色随 day_id，不随排序变化。
- `map_stops(id, map_id, day_id, position, provider, provider_place_id, lng, lat, place_snapshot, experience_id nullable, duration_minutes, fixed_start_minute nullable, source_snapshot)`。
- `map_legs(map_id, day_id, from_stop_id, to_stop_id, mode, duration_seconds nullable, distance_meters nullable, geometry nullable, evidence_status, provider, generated_at, expires_at)`。
- `map_edits(id, map_id, base_version, committed_version, affected_days, before, after, intent, actor_sub)`；不存完整对话。
- `map_share_grants(id, map_id, token_hash, scope=view, visible_stop_ids, expires_at, revoked_at)`。
- `map_idempotency(subject, client_id, tool, key, payload_hash, response, expires_at)`。

唯一约束：同图 stop 唯一，position 在 day 内唯一，day_index 在 map 内唯一。跨天 move 保留 stop_id、POI 坐标、duration、来源，只改 day_id/position 以及被计算的 schedule。源天和目标天连同新 legs 在一次 CAS commit 保存，版本只加一次。plot_places 可接收用户明确提供的 fixed_start_minute 与 lock_to_day，后者为 true 时必须有固定时刻；它们是计划约束，不声称服务验证了真实预约。真实预约用 `locked_day_id` 绑定原 day ID（实际日期不能跟着拖动改变），默认禁止跨天；普通 `fixed_start_minute` 是当天固定计划槽。v1 不接受直接改预约日期，改约另行设计。支持 1 个 stop 的天（无路段、交通 0）与空天（明确空，不伪装失败）。

### 调度规则

v1 并非全球最优 TSP。`build_route` 在用户给定的日分组内按固定时段/锁定点/距离成本求可行顺序；不擅自跨天。`update_day.move_stop` 按用户落点顺序保留相对关系；静态矩阵只需刷新两天相邻 legs，再传播全部到达时间；时变 transit 从最早受影响位置向后重新查询，直到出发时间与证据重新稳定，不能沿用旧班次。两种模式都在一个版本提交。自动重新优化顺序是显式 `reorder_stops` 或 build 的 `order_policy=optimize`，在 UI 中提供「优化这一天」；不能拖完突然把别的地点全换顺序。

每一天 `start_minute` 到 `end_minute` 是城市时区的本地计划墙钟分钟。跨午夜日程不支持，拒绝 `end<=start`；有日期时由 timezone 转成 UTC 瞬间用于存储，DST gap/重复时间必须显式选 offset 或拒绝，不能假设每天 1440 个真实分钟。东京 demo 使用无日期相对天，所有 minute 为计划值，不冒充准确到站。

请求没有日期/酒店/偏好：只追问会阻止安全规划的信息。东京例子默认无日期、Asia/Tokyo、每天 09:00–18:00、3 个区域、公共交通偏好；在回复中把这些写成假设。无日期无法验证营业日/预约/时刻表，显示 `opening_hours_unknown` / `transit_schedule_unknown`，提供「补日期后核查」；不能悄悄选明天，东京三天也不能生成成清迈。

交通模式 `walking | cycling | driving | transit`；一个调用使用一个主模式。transit 提供商缺失则 fail 或显式降级成 `unknown` legs（用户允许 unknown 的草案），不返回伪造地铁时间。v1 以用户明确允许的 `allow_unknown_travel` 决定是否可输出草案；若为 true，未知 leg 后的到达时间为 null、下一段除非有 fixed_start 也为 null，不穿透累积假时间。snapshot 分离 arrival_minute、计划 start_minute 与 stop/day feasibility_status；固定预约可恢复其后计划时刻，但未知到达仍为 null、可达性仍为 unknown。已知停留时长与已知交通的下界超过当天窗口时，即使其他路段未知也必须 INFEASIBLE。交通 mode 和 allow_unknown 按天存储，局部 build 不改变其他天后续编辑时的模式。草案 `ready_with_warnings` 仍可分享，不能称「已验证可走」。

## 6. 完整东京 demo flow

城市区域：Day 1 浅草—上野、Day 2 明治神宫—原宿—涩谷、Day 3 筑地—银座—东京站。每一天 3 stops，按同一区域组织，避免为了凑网红点绕城。具体 POI 坐标在 demo 数据里仅作可复现实验 fixture，未完成生产 provider 验证。

1. 用户：「规划东京 3 天」。Host 已完成 map-only OAuth / token 接入，凭据不进入自然语言 prompt。
2. Agent `create_map({title:"东京 3 天",city:"Tokyo, Japan",day_count:3,timezone:"Asia/Tokyo",idempotency_key:"..."})` → map 与三个稳定 day IDs，version 1。
3. `search_places` 批量查询 9 个地点；对多义名字让用户消歧，没有结果不凭空补点。结果带 place_ref、坐标、source status。
4. `plot_places` 9 个 points，附 day IDs 与停留时长 → version 2，9 个稳定 stop IDs。
5. `build_route` 指定三天 start/end、stop_ids、`order_policy:"preserve"`、`transport_mode:"transit"`。生产需真实矩阵；此原型返回 `demo_estimate`，version 3。
6. `get_map_link` → view-only share URL + owner edit URL，map_version 3。所有者凭现有会话打开分享页可编辑；访客点「复制并编辑」得到自己的图。
7. Agent 回复：「排成 3 天：浅草与上野 / 原宿与涩谷 / 筑地与银座。打开地图可调整。还没提供日期，营业日与交通时间需要核查。」只转述工具返回信息。
8. 用户点开链接：读取服务端最新 committed snapshot，不从聊天文本还原地图。三天有固定颜色、编号与文字图例。
9. 拖浅草寺到 Day 2 时间轴，先 preview diff，再提交 `update_day` move。源天与目标天在一个事务从 version 3 → 4。链接 URL 不变，读取的是最新 committed 版本。
10. 撤销：`update_day` operation undo(edit_id)，仅当当前版本正是该 edit 的 committed_version；新建补偿 edit + version 5，历史不删除。重复相同 undo key 返回原成功；不同 key 重复 undo 返回 UNDO_CONFLICT。

原型入口有逐条调用 trace，可展开完整入参/出参。`verify.mjs` 通过 HTTP 按上述工具执行，记录同 key 重试、bad key、过期版本、未知地点、超时/不可排程、undo、只读分享、持久化重启。没有调用模型不算 Grok live E2E。

## 7. 交互与权限的产品决定

详细一页稿见 [interaction.md](interaction.md)。最重要的分界：**拖 pin 换天不等于移动 POI 坐标**。长按后出现日期停靠带，拖到 Day 2 是改 day_id；自由拖到地图空白处 v1 不支持，也不能静默把浅草寺变成另一个经纬度。改目的地用显式「替换地点」。

用户落点的 preview 是本地反馈；真实 travel provider 结果回来前保留旧路线虚线，并写「正在计算」。完成后显示受影响两天、分钟差、预约冲突和警告。合理可行的 move 默认一次落下即提交；若有硬约束冲突回原位并告诉原因；未知交通允许则保留为草案并显著提示，不把不可行结果伪装成功。

访客直接打开 view link 必须先看到图；首次编辑才需身份/创建副本。所有者登录则直接编辑。`share_url` 绝不含 edit scope。App 未安装也能在 Web 完成任务；「在 Roamorrow 打开」是增强入口，不是挡住地图的下载页。

## 8. 安全、发布与成本边界

生产 map scopes：`maps:read maps:write maps:share`，只为被授权 map 或新建自有 map。身份绑定 OAuth subject / application grant，不接受 Agent 自报 email。以现有验证账号机制为基础；通用 MCP OAuth 需按 [MCP authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) 提供 protected resource metadata、资源 audience、PKCE 与正确 401 challenge；服务账号只允许自己的隔离租户，不能拿常驻 Supabase token 当所有用户的通票。

view token 为 CSPRNG ≥128 bits，DB 只存 hash，默认 7 天，可撤销，Referrer-Policy no-referrer，noindex；访问日志与分析移除 token。只分享用户明确选择的公开 stops，默认不含酒店、精确当前位置、邮箱、聊天记录；metadata/OG 不渲染私有 stops，分享生成前给摘要。真实酒店需新增 private-stop 标记及分享过滤，不能仅依赖展示层。

`get_map_link` 创建的授权保存显式 `visible_stop_ids`，新 stop 默认不加入既有授权；若要分享新增点，用户重新发布生成新授权。原 stop 改天仍可见。读取/OG/复制/边界框都用同一过滤投影，隐藏点连接的几何不能泄漏，过滤导致不连续时该段不提供路线与总耗时。授权稳定读取公开集合的最新 committed 版本（live link），页面显示更新于与版本；不会读到 pending 草稿。需要冻结给朋友的版本先留 v2，不假装当前具备。撤销 share 不影响 owner edit URL。

外部 POI 文本是数据，不执行其中指令。schema 验证拒绝陌生字段，不允许 server 任意 fetch 用户 URL。单租户创建与搜索限流、地图 40 stops / 7 days、provider 全链路 deadline 8s、并发配额。日志只含 request_id、tool、耗时、error code 与脱敏 map ID，不记地点坐标/凭据/完整对话。营业信息与路线缓存必须区分时区、日期、mode、provider/evidence TTL。

v1 默认同步有限工作量；超时不提交，只返回 retryable 错误。未来真需长任务才加 job 资源；不在六工具首版里塞一个模糊 job_id 后没人知道怎么取结果。

## 9. 验证指标与发布门槛

假设指标，不是已测结果：工具创建→打开地图转化率、首个有意义编辑率、首次打开到看懂分日的耗时、二次访问、复制自己的版本率。分享次数不等于回流；同一用户重复打开应去重；只采集得到同意的匿名聚合，不在 URL 放用户标识。

技术指标目标：无 provider 的首屏 shell <1s，地图 snapshot p95 <500ms，拖动可见反馈 <100ms，远端计算目标 <2s；这些是验收目标，须在部署环境采样，不能以本机 prototype 证明生产 SLA。

发布门槛分层：① schema/state HTTP cases；②桌面+手机 viewport 原型；③真实 POI 与路线提供商；④公网 HTTPS +真实 Grok trace；⑤生产持久化/权限/分享撤销；⑥原生 App deep link 与真机手势。通过某一层不替代其余层。Grok、Muse、Dots 分别接入验收，不写「MCP 标准所以全部支持」。

## 10. 本轮 boundary decision

问题：六个稳定工具 + 统一编辑命令，是否足以把 Agent 生成的地图交给人继续操作？备选：只读地图；或必须把每种编辑拆成更多工具。

改变判断的证据：不改坐标就能 move，受影响两天原子提交，重试不复制点，刷新/新窗口读到相同结果，坏输入/版本冲突不破坏旧图。最小失败：stop 同时出现在两天，地图与时间轴版本不同，分享链接丢数据，或重试新增重复地图。

模式选 boundary。时间盒：一个独立、零安装 Node 服务与 Web 原型，完成核心 cases 后停止扩建。不做生产认证、真实路网导航、模型服务、原生代码或部署。原型只回答状态与交互能否连起来，不验证用户需求、运营增长或真实东京出行可行性。
