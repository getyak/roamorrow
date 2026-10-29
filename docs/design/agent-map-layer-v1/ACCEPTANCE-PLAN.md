# Real Map Chain Acceptance Implementation Plan

> **For agentic workers:** use `superpowers:executing-plans` to execute task by task. Independent review covers scoring and integration boundaries.

**Goal:** 真实 Agent → MCP → 真实地点/步行路网 → 持久化链接 → 浏览器拖动链路，按固定七段评分迭代，只有全部关键门槛通过且总分严格大于 98 才达标。

**Architecture:** 独立 acceptance runner 读取同一套六工具契约；真实模型自己选择并生成工具调用，官方来源 adapter 提供坐标与步行路网。评分器从机器可核验的 receipts 计算，保留 fixture / 本地真实 / 公网 Grok 三种证据边界。生产 Go/PostgreSQL/OAuth 继续按 BUILD-SERVER 实现，验收 runtime 不冒充生产。

**Tech Stack:** Node 22、Python 3（标准库网络与受保护 env 读取）、MCP 2025-11-25、Wikidata API、FOSSGIS OSRM foot、DeepSeek tool calling；Grok API 依赖已有 xAI 凭据。

**Spec:** [design.md](design.md)、[interaction.md](interaction.md)、本次用户要求“真实全链路分段评分，最终超过 98，不断优化”。原生/真机/生产 SLA 不在此 Web 旅程验收分数的外推范围。

## Global Constraints

- 绝不输出凭据、默认账号密码或完整授权 header；不更换测试账号，不改变共享服务入口。
- 真实 provider 返回缺失时失败或 unknown，不回退 fixture 坐标/时间来获得分数。
- GeoJSON `[longitude, latitude]`；东京 `Asia/Tokyo`；未给日期不编营业日。
- 只做隔离验收地图；临时资源保存 receipts 后精确清理。
- 不放宽评分规则凑分；评分标准版本/hash、candidate digest、run ID、证据文件与 revision 绑定。
- Grok-public 的缺项不能由 DeepSeek-local、SDK 或 fixture 测试替代。

## Review Focus

1. pass receipt 缺文件/校验失败、fixture 冒充 live、旧 revision、不同路线模式，均不能获得当前目标分。
2. LLM 提前结束、伪造 URL 或 tool 参数、未解决地点歧义必须显示失败，不能由脚本自动补全假装模型成功。
3. 公共 provider 只有真实有限请求，缓存和速率限制，不能把公共试验节点变成无配额生产后端。
4. 并发 provider 请求在 commit 前仍需再次校验版本；保持两个日期原子更新与重试幂等。
5. 公网接入不得暴露根页面自动创建的 demo 身份、测试故障注入、调试 trace 或未授权付费请求。

### Task 1: 固定评分和证据协议

Files: `acceptance/criteria.mjs`, `acceptance/score.mjs`, `acceptance/score.test.mjs`。

- [ ] 写评分红灯测试：98 不达标、98.01 达标、关键项失败不达标、未验证不作通过、fixture/旧候选不计分、证据缺失报错。
- [ ] 实现 100 点七段规则与 machine-readable receipt schema，输出实际得点、未验证权重、失败权重与逐段缺口。
- [ ] `node --test .../score.test.mjs` 通过；规则文件 hash 固定，修改规则必须单独说明且重跑基线。

### Task 2: 真正来源与模型接线

Files: `acceptance/network.py`, `acceptance/providers.mjs`, `acceptance/agent.mjs`；原型只新增可注入 catalog/route cell 与 async preparation 接口。

- [ ] 真实 provider 预检：Wikidata 返回东京实体坐标，OSRM foot 返回道路 geometry/duration；记录响应与耗时。不可达节点记录实际错误。
- [ ] 来源身份/坐标/时效/歧义解析断言；路网按步行 profile，不能把 driving 模式当步行语义。
- [ ] 读取本机已有 DeepSeek 配置，以标准 function tool → MCP HTTP bridge 跑实际模型编排，保留每轮 token usage/tool call。它只证明 DeepSeek-local。
- [ ] xAI 凭据未提供时只生成连接配置和未验证记录，禁止替换成模拟 Grok。

### Task 3: 浏览器真实旅程

Files: acceptance runner + 原型 rendering adapter。

- [ ] 实际模型返回工具产出的 URL，浏览器读同一地图，所有 POI/legs 都能回溯 provider 响应。
- [ ] 拖动、顺路重排、失败回滚、undo、刷新、新身份只读与 fork 在同一 candidate 上复跑。
- [ ] 真路网 geometry 与计划时间联动；图中不出现 demo_estimate 或虚构实时公交标记。

### Task 4: 公网与 Grok 验收

- [ ] 先有 scoped token、受控 session、Origin/Host 校验与请求配额，才能开独占 HTTPS 验收入口；不更改共享 Tailscale Serve。
- [ ] 公网 HTTPS 链接与远程 MCP 从外部可达，未经授权不能建图或消耗 provider。
- [ ] 真实 Grok API 执行首轮创建与后续编辑；相同 candidate 至少 10 个完整场景全部通过关键关卡，报告样本量而不宣称生产可用性概率。
- [ ] 独立复核评分证据；满足 `score > 98`、所有关键项通过、未验证关键权重为 0 才完成。否则按最低分段继续优化，阻塞记录在 GET-294。
