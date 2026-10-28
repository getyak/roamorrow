# 真实链路验收与固定评分

目标 profile 是 `grok-public`：真实 Grok API → HTTPS MCP → 真实地点/步行路网 → 持久化链接 → 地图操作。`deepseek-local` 是可自行推进的诊断 profile，不能冒充 Grok 公网通过。

规则在 `criteria.mjs`，七段权重为 12 / 20 / 20 / 14 / 16 / 12 / 6，总计 100。只有已验证点数严格大于 98 且所有关键项通过，才 accepted。unknown 不按质量零分解释，但也不给通过分。评分是此旅程验收点数，不是生产可用率、用户满意度或真机验收结果。

每份 receipt 绑定实际 runtime 启动时的 candidate digest、revision、runtime ID、同一 run ID、profile 和规则 hash。评分器读取真实证据文件、核对 SHA-256 和 JSON pointer 断言。旧进程不能借当前源码获得新版本成绩，缺证据、fixture、混合候选/规则/旅程不允许凑分。API、十场景和性能需要对应原始 trace；metadata 中写一个 passed 不等于实测。

## 本机复跑

Node 22+ / Python 标准库。调用模型会使用已配置账号配额；仅把通用东京测试需求发送给明确指定的模型 API，不发送用户历史旅行资料。环境文件由参数指定，只在 helper 内读取，不粘贴或打印凭据。

```bash
# 起一个隔离、必须带 scoped token 的真实来源验收 runtime：
node docs/design/agent-map-layer-v1/acceptance/live-server.mjs \
  --dir /path/to/registered-artifact/runtime \
  --env-file /path/to/private.env --port 4650

# 真实模型自主编排 → 本地 HTTP MCP（不是脚本代填工具调用）：
node docs/design/agent-map-layer-v1/acceptance/agent.mjs \
  --runtime /path/to/registered-artifact/runtime/runtime.private.json \
  --out /path/to/registered-artifact/run-001 --env-file /path/to/private.env

# 核验 provider 原始资料、坐标、路网、调度与明确插入：
node docs/design/agent-map-layer-v1/acceptance/collect.mjs \
  --runtime /path/to/registered-artifact/runtime/runtime.private.json \
  --out /path/to/registered-artifact/run-001

# 先用 load_workspace_dependencies 找到已安装 Playwright index.mjs，再设置模块位置：
MAP_CHAIN_PLAYWRIGHT=/absolute/path/to/playwright/index.mjs \
node docs/design/agent-map-layer-v1/acceptance/browser.mjs \
  --runtime /path/to/registered-artifact/runtime/runtime.private.json \
  --out /path/to/registered-artifact/run-001

node docs/design/agent-map-layer-v1/acceptance/security.mjs \
  --runtime /path/to/registered-artifact/runtime/runtime.private.json \
  --out /path/to/registered-artifact/run-001 --env-file /path/to/private.env

node docs/design/agent-map-layer-v1/acceptance/score.mjs \
  --profile deepseek-local --receipts /path/to/registered-artifact/run-001
```

先提交候选并重启 runtime，再执行整组命令。运行期间不改源码；digest 不匹配时必须重启/重跑，不能手工改 receipt。多轮历史分目录保存，不能把几个 run 的高分项拼起来。

网络验证当前只使用真实 Wikidata P625 坐标和 [FOSSGIS OSRM foot](https://routing.openstreetmap.de/about.html) 步行图。请求单线程、最少间隔 1.05 秒、12 小时缓存、每个 runtime 最多 45 个实际 provider 请求。显示 OpenStreetMap attribution 与 fix-map 链接。公共实例仅供本次有限隔离验收，生产须配置自有或合法商用 provider。没有接入公交，不能把 foot URL 中名为 driving 的 API profile 占位符当汽车；实际交通模式由 FOSSGIS 的 routed-foot 后端决定。

Wikidata 只证明知识库地点资料和坐标，不保证入口、营业日或当前开门。歧义保留候选；没有结果时不回退 fixture。每条路线保留原始道路 geometry 和获取时间。

`runtime.private.json` 含仅用于隔离测试的 scoped bearer，权限 0600，不能提交、展示或放进 URL。公网前必须使用 scoped 模式，禁止根页面自动发身份、公开故障注入与无配额 provider 请求；不能直接公开旧的 fixture server。此 runtime 仍用本地文件存储与测试会话，不是 BUILD-SERVER.md 里的生产 Go/PostgreSQL/OAuth 后端。

## 本地防虚分与安全检查

```bash
node --test docs/design/agent-map-layer-v1/acceptance/*.test.mjs
python3 -m unittest discover -s docs/design/agent-map-layer-v1/acceptance -p '*_test.py' -v
node docs/design/agent-map-layer-v1/demo/verify.mjs
```

真实 Grok、完整十场景、实际性能样本、链接撤销/过期和重启验证，缺任何关键证据都继续显示未验证。每轮先修失败项，再选未验证的最低分段推进；不因为本地一次正常路径通过就给 98+。
