# V4 真实 tools / AI 场景验证

本报告与原生 UI 验收分开。默认产品入口是 `CompanionHomeView → CompanionHomeStore → CompanionHomeAgent → AIService / VoiceAgentToolRouter`。旧 `VoiceAgentOrchestrator` 的单测或独立 Agent Map Layer MCP 成功，均不能代替这条默认链路。

本轮 runner：`scripts/qa/v4-real-tools-eval.py`。它读取当前 `CompanionHomeAgent` 的实际 system prompt 模板、当前回合地图范围说明和生产 `search_places` schema，使用隔离公共东京输入调用现成官方模型配置。地点执行通过提取未改写的生产搜索 handler、MapKitPOIService、坐标边界、Experience、质量过滤和合并策略，在真实 macOS Apple SDK 运行。VM、持久化、HomeAgent journal 与 UI 是明确隔离的 QA 边界；**不是完整 iOS 原生链路或真机验收**。

## 预算与数据

- 本轮最多 4 个模型请求，每个最多 512 输出 token；最多 8 个工具调用、12 个显式公共 provider 查询。
- 查询串行、单请求有时限；不自动重试模型 401/429/5xx 或超时。
- Apple SDK 内部 HTTP 请求数不可观察；只把显式 `MKLocalSearch` 次数记入已知查询预算，不虚称能控制其内部传输数。
- 只发送公共东京场景及本轮公开地点返回，不读取私人邮件、日历、通讯录、位置历史或个人旅行数据，不执行导航、付款、出票或预订。
- 密钥由 runner 进程读取现有 `.env`，不进命令参数、子进程、源码、结果或日志。模型 endpoint 禁止带内嵌凭据，禁止重定向转发 Authorization。
- 每轮记录 git revision、生产文件 SHA-256、公开请求与响应、真实耗时及失败。四次采样不能代表 p95、平均生产速度或服务稳定性。

## 场景与必须观察的行为

| 场景                            | 观察点                                                                 | 证据层                                                                  |
| ------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| 拒绝定位，手选东京神保町找书店  | 使用公开地图范围；不称设备人在东京；不回清迈；实际 query 到达 provider | 实际模型 + 生产 handler / 真实 SDK；iOS UI 另验                         |
| 要求已核实评分至少 8 分         | 未知评分不按满足；不能把泛空集解释成附近无书店                         | 生产质量谓词；有实际候选才形成正向质量证据                              |
| 无意义 query                    | 保持空，不回填泛附近推荐                                               | 真实 SDK + handler                                                      |
| 查询期间切城市                  | 旧响应丢弃，不合并旧地点                                               | 真实 SDK await + 隔离 VM 状态变更                                       |
| 收藏最后一个地点再取消          | 共享 preferences 读回，地图清选择与空态，不改旧回答                    | iOS native tests / UI，由主任务执行                                     |
| 地图看另一点后回原对话          | 草稿、附件、阅读 anchor 保留；本次地点范围不串后续问题                 | shipping CompanionHomeStore / UI，由主任务执行                          |
| 路线提案与采用                  | 明确预览；确认前不写持久行程；未知营业状态不造事实                     | 当前 HomeAgent allowlist 不含 build_route，不能伪称对话已经执行路线工具 |
| provider 失败 / SSE 中断 / 取消 | 区分失败与空；不盲目重复请求或保留隐藏工作                             | 实际 provider 失败记录 + AI transport 回归；不是同一层证据              |

## 已取得的真实 SDK 结果

首次查询共 4 次显式 Apple SDK 调用：神保町 `本屋` 2km、同 query 加 `rating_min=8`、无意义 query、慢请求切城市。前三次经生产 service 返回空集；第四次因城市变更被生产 handler 拒绝，旧地点未合并。实测总耗时分别约 2111 / 169 / 276 / 294 ms（包含 QA CLI 进程启动；不是 iOS UI 响应速度）。

随后用一次明确公共地标 `東京駅`、东京站公共坐标、同生产 2km/POI/`regionPriority.required` 请求直接检查原始 SDK。在 `MKLocalSearch.start()` 处得到 `MKErrorDomain code=4`、`MKErrorGEOError=-8`，未取得 `response.mapItems`，因此这次不能归因于 POI 转换或半径过滤丢失。生产 service 的 `.placemarkNotFound` 分支把此类查询映射为 `[]`。未擅改产品空态语义，也没有为“找到书店”记通过。

这五次调用证明了真实查询尝试、空结果保留和一次区域失效保护，**没有证明东京书店能在当前服务环境返回候选**；评分过滤场景因没有候选而不具备正向质量证据。原始 receipt 保留每次实际值和源码摘要。

## 真实模型结果与耗时

模型预算已用满：4 次官方 `deepseek-flash` 请求均 HTTP200，最多512输出token，实际完成输出共347token。前三次采用默认 HomeAgent 当前的非流式方式，模型自主先后选择 `书店`、`bookstore` 两个query，精确传入神保町公开中心、2000m、`progressive:false`。两个真实 SDK 调用都返回空。

模型最终明确说：两次无结果不代表附近没有书店，评分、安静程度、营业状态均无法确认，没有加入行程。第4次是同一公开上下文的独立 SSE transport 采样，模型同样拒绝确认“已核实评分至少8分且安静”的条件，没有再搜索或执行副作用。

| 采样                 | 实际耗时                              | 含义                                                              |
| -------------------- | ------------------------------------- | ----------------------------------------------------------------- |
| 非流式模型1/2/3      | 1219 / 859 / 1332ms                   | 完整API响应，不是首token                                          |
| 真实SDK搜索1/2       | handler 550 / 149ms；CLI总998 / 166ms | CLI启动与handler分别记录，不冒充iOS地图渲染                       |
| 模型及工具阶段耗时和 | 4574ms                                | 三次模型+两次工具CLI耗时之和，未含编译；不是生产平均或p95         |
| 单次SSE transport    | 首事件363ms、首文本729ms、总903ms     | 不同输出长度的一次采样，不是默认HomeAgent UI首token或前后提速对照 |

累计显式 Apple provider 查询7次，仍没有非空书店候选，所以搜索正常返地点、真实ID收藏与正向评分过滤没有记通过。运行期间 `CompanionHomeAgent`/Router/MapKit源码未变化，但整个 `MapViewModel.swift` 因并行实施发生变化，原始receipt保留了这一source drift；压缩的生成Swift快照和SHA绑定实际执行版本，不能借后来的当前文件SHA冒充统一原生验收。

另只读核对了 WebSearchService：它经认证 Supabase Edge `tavily-search`，不直接读取Tavily key。虽然现成.env有key，当前FeatureFlags.plist的`FF_BACKEND_SYNC=false`，需要后续明确的backend-on与测试登录验收；没有直连Tavily绕过生产边界，没有新增资源或调用私人账号。

- [结构化模型与耗时摘要](results/model-summary.json)
- [SDK结果摘要](results/sdk-summary.json)
- [原始资料与源码快照校验清单](results/manifest.json)
- 原始公开模型输入/响应、SDK receipt与实际生成Swift快照以`.gz`保留捕获字节，不由格式化器改写。

## 原生生产链路的最小验收入口

新 opt-in XCTest 可从现有测试 fixture 走生产 router：

1. 使用隔离 `UserDefaults` 与 `ExperienceService(seed: [])` 建立 MapViewModel，手动 `selectCustomLocation(coordinate: 东京公共点, label: "Tokyo QA map", cityCode: "custom_tokyo_eval")`。
2. 调用 `VoiceAgentToolRouter.execute`，传 `search_places`、`query: "本屋"`、`radius_meters: 2000`、`progressive: false`，不请求设备定位。
3. 分开记录 provider 成功返回候选 / empty / failed。只有真实返回非空 ID，才继续读回 `lastEffect`、provider 资料和来源；不要让空集断言成为找地点成功。
4. 取得真实返回 ID 后，执行 `save_to_favorites` 两次、读取同一个 preferences，并检查地图最后收藏空态。它是 toggle，不能盲目重试同一动作。
5. HomeAgent 的 `messageSender` 可重放本轮真实模型输出，验证生产 checkpoint/route；须标成“真实模型输出 + 原生重放”，不能冒充同一次原生自主调用。

可复用的原生目标：`MapKitSearchTests`（只测空 query）、`POISearchOutcomeTests`（VM failure/empty/cancel/city-change）、`ToolRouterOutcomeTests`（dispatcher 错误边界）及 `SoloCompassTests/testToolRouterSaveToFavoritesTogglesPersistence`。已有 `testToolRouterBuildRouteDoesNotAutoSave` 没有持久化 readback，不单凭其名字声称 durable itinerary 验收。

## 复跑

```bash
# 必须先注册任务 artifact；不会启动 simulator 或新服务
python3 scripts/qa/v4-real-tools-eval.py --out /path/to/artifact/native --native-only
python3 scripts/qa/v4-real-tools-eval.py --out /path/to/artifact/diagnostic --sdk-diagnostic

# 使用官方现有模型，每次验收最多4个请求；本轮4请求预算已用满，后续必须由主任务另定预算
python3 scripts/qa/v4-real-tools-eval.py --out /path/to/artifact/model \
  --env-file /path/to/private.env --live-model
```

默认模型探测使用 shipping HomeAgent 当前的非流式请求方式，只记完整响应耗时。显式 `--streaming-probe` 才记录 SSE 首事件/首文本/首工具 delta；它是 transport 采样，不能当作默认 UI 首 token。
