# Agent Map Layer v1 · GET-294

2026-10-29。目标：对话里的旅行计划，打开就是一张可以接着改的地图。

- [产品与系统设计](design.md)：定位、取舍、数据模型、六个工具、权限与失败策略。
- [拖 pin 自动重算交互稿](interaction.md)：桌面/手机布局、手势、状态、撤销、无障碍。
- [明天给实现 Agent 的任务书](BUILD-SERVER.md)：落地顺序、代码归属和验收门槛。
- [真实请求与返回示例](examples.json)：六个工具的完整 JSON 输入/输出及串联顺序。
- [完整契约](demo/contract.mjs)：六个工具的独立 JSON Schema 入参/出参，可直接导出。
- [可运行原型](demo/)：零安装，真实本地 HTTP MCP、磁盘存储、地图链接和跨天编辑。
- [实测记录](verification.md)：观察到的事实、自动检查、未验证项分开记录。

```bash
node docs/design/agent-map-layer-v1/demo/server.mjs
# 打开终端输出的 loopback 地址，点击「规划东京 3 天」。
# 复跑契约和链路检查（自动起独占临时服务并关闭）：
node docs/design/agent-map-layer-v1/demo/verify.mjs
# 导出 tools/list 的六个完整定义：
node docs/design/agent-map-layer-v1/demo/contract.mjs > /tmp/roamorrow-map-tools.json
```

这是独立的 boundary demo，不接生产账号或数据库。Grok 对话是脚本化 Agent 回放；六个工具经过真实 HTTP 调用。POI 是明确标记的演示资料，路线交通时间是确定性估算、路线为示意连线，不代表实时导航。[国土地理院东京底图](https://maps.gsi.go.jp/development/)联网加载，失败仍能显示坐标与行程。数据目录默认在系统临时目录，演示服务重启后仍可打开原链接。
