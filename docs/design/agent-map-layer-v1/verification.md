# GET-294 验证记录

2026-10-29，Asia/Shanghai。本记录针对独立 boundary demo，不针对生产 server。

**判断：supported**——六个工具与一套 map 状态足以在本地把建图、分日排程、持久化链接和拖动编辑串起来。用户需求、真实东京出行可行性、第三方客户端接入仍未由这些测试证明。

## 已观察到的事实

| 层               | 结果                                                                       | 证据边界                                                                                                    |
| ---------------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 零安装本地 HTTP  | 29 个边界检查通过                                                          | Node 22.23.2；同一进程中的并发，不代表跨进程 DB 幂等                                                        |
| 官方 MCP SDK     | 1.32.1 实际调用全部 6 个工具通过                                           | 协商 2025-11-25；不是最新 2026-07-28 profile                                                                |
| 独立 JSON Schema | 官方 Tool schema + Ajv，12 份 draft-07 input/output 编译与实测输出校验通过 | 明确使用 draft-07，修复默认 SDK 对 prefixItems 的兼容问题                                                   |
| Desktop Chrome   | 1440×1000，指针拖动浅草寺到第 2 天                                         | 分组由 3/3/3 → 2/4/3，版本 +1；刷新仍保留                                                                   |
| 编辑与失败       | 菜单 move、undo、provider 失败通过                                         | 失败两天都不变；撤销新版本；不是真实 provider 网络故障测试                                                  |
| 新浏览器身份     | 分享只读、fork 后可编辑通过                                                | fork 是新 map ID，原图不变；demo 会话不是生产 OAuth                                                         |
| 手机宽度         | 390×844 无横向溢出，菜单跨天更新通过                                       | 桌面浏览器 viewport；不等于真机触控、读屏或原生体验                                                         |
| 地理底图         | 国土地理院淡色东京瓦片实际加载                                             | 实时联网仅用于底图；POI/交通仍是明确标记的 fixture/估算                                                     |
| 浏览器健康       | 无应用异常 / 框架 overlay                                                  | 原型无框架；最终回归无 console error；补了 favicon 204 和 resize 暂态零尺寸保护；外部瓦片失败不影响行程状态 |

初始 OSM 公共瓦片返回访问限制，已停止使用该服务。东京原型改用[国土地理院公开瓦片](https://maps.gsi.go.jp/development/)，界面保留来源链接。底图展示不等于 POI 和公交路线经过提供商验证。

## 29 个 HTTP cases

1. 协商与六工具发现、schema 根形状。
2. 相同参数、并发重试只建一张图。
3. 同 key 改参数拒绝。
4. owner 字段注入拒绝。
5. fixture 解析与不存在地点。
6. 未解析 place_ref 不落点。
7. 九点分三天排程。
8. 新身份打开持久化 view link。
9. view link 不给写或 owner read 权限。
10. preview 计算两天但不保存。
11. provider 失败保留两天，原 key 可重试。
12. move 原子更新、坐标不变、幂等重试。
13. 旧版本拒绝并返回当前 snapshot。
14. 结束时间不可行时回滚。
15. undo 作为新版本保存。
16. undo 不能覆盖后续版本。
17. 未知交通为 null，后续到达不伪造。
18. 未知路段仍检查已知时长下界。
19. 局部 build 保留其他天交通模式。
20. 分享 allowlist 过滤地点与几何。
21. resource 读取最新版本。
22. 服务重启保留地图与分享授权。
23. 非允许 Origin 拒绝。
24. fork 新地图与主键重映射。
25. 固定计划时刻与 unknown arrival 分开。
26. 预约锁日禁止跨天。
27. 新增地点不自动进入旧分享链接。
28. 160 字长标题 fork 后 schema 有效且仍可编辑。
29. 放到日期带后自动重排成顺路顺序，并保留当天首站。

## 复跑

```bash
node docs/design/agent-map-layer-v1/demo/verify.mjs
node docs/design/agent-map-layer-v1/demo/server.mjs
# 浏览器打开 http://127.0.0.1:4649
# 点击规划 → 拖浅草寺 → 刷新 → 撤销 → 失败情景 → 分享 → 新窗口复制
```

官方 SDK 与 Ajv 使用机器已缓存的维护版本单独验证，未写入项目依赖。浏览器插件缺少 Playwright 扩展，采用 bundled Playwright + 机器已有 Chrome headless，无需安装浏览器。代码仅在 docs/design 内；没有构建 iOS 或触碰共享模拟器。

## 实测中修正的问题

独立审查促成公开 stop 白名单、时变公交传播、固定预约锁日、并发幂等事务和 unknown 可达性细化。代码检查修复了 outputSchema 根 object、unknown 时间下界、按天交通模式、可表达固定时刻输入、长标题副本、fork 主键重映射和地图投影响应尺寸。官方 SDK 实调进一步发现 tuple schema 兼容问题。以上属于自动检查和审查证据，审美与产品方向仍由用户决定。

## 未验证项

- 真实 Grok API：无 xAI 凭据和公网 maps MCP；对话是脚本化回放。
- grok.com、Muse、Dots 的自定义连接入口与安装体验。
- 真实 POI provider、营业日、真实路网 geometry、公交班次和 ETA。
- 生产 OAuth / DB / 多进程并发 / 配额 / 备份 / 访问撤销与过期实际等待。
- 生产部署、iOS App deep link、真机拖动、Safari、VoiceOver / TalkBack。

这些项目是实现任务书的后续门槛，不能因设计 PR、原型检查或 CI 通过而自动标为完成。
