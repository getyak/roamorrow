# 明天交给实现 Agent 的任务书

关联 GET-294。此文件是可执行的实现边界，不表示生产已实现。起点以执行当日最新 `origin/main` 为准，先重新核对现有服务与冻结契约。

## 直接复制给 AI

> 阅读 `docs/design/agent-map-layer-v1/{design,interaction}.md` 和 `demo/contract.mjs`。实现 Roamorrow Agent Map Layer v1：六个工具 create_map/search_places/plot_places/build_route/update_day/get_map_link、真实持久化和 `/m/{id}` + `/s/{token}` 编辑/分享页面。用户已选方向是外部 Agent 对话、Roamorrow 管地图。原型只作契约与交互参考，禁止复制它的 fixture adapter、手写 JSON Schema 校验器、demo session auth 或单进程 JSON 文件存储作为生产实现。
>
> 先读 AGENTS 和项目 skill，fetch origin，在最新主分支独立 worktree 开发。保持原 `/mcp` onboarding 的 2025-11-25 冻结契约；新增 `/mcp/maps` registry。Go 侧鉴权、授权、事务和 MCP 传输；TypeScript 侧复用并提取路由编排逻辑，Go 经内部 HTTP 调用，鉴别内部服务 audience，不开放无认证 solver。先完成 below acceptance gates，再交付独立 review、PR、适用 CI 与真实环境验收。未完成的证据层标 pending，不扩大测试结论。

## 建议代码归属

| 部件       | 建议 owning source                                       | 完成定义                                                                             |
| ---------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| 领域契约   | 新 `packages/map-layer`，零 UI 依赖                      | 品牌化 MapId/DayId/StopId；JSON Schema 独立可校验；与 Go DTO 一致                    |
| MCP / HTTP | 新 `apps/api/internal/maps`                              | `/mcp/maps`、snapshot/resource、401 metadata、Origin/输入限制；旧 harness 无回归     |
| 存储       | 新 maps migrations + repository                          | map/day/stop/leg/edit/share/idempotency 同租户约束；CAS、幂等 claim、同事务 response |
| POI        | 当前来源 adapter + 新 resolver 编排                      | 归一化 provider place ref、来源与时效、多义/无结果、不收任意 URL                     |
| 编排       | 新 TS server-only route service，复用 `packages/routing` | 动态公交从最早受影响处传播；unknown=null；真实预约绑定日期                           |
| Web        | 新 `apps/web/src/app/m/[id]`、`s/[token]`                | 读取同一 snapshot，日色/编号、拖动、菜单、冲突、回滚、撤销、访客 fork                |
| Agent 接入 | MCP connector 设置 + xAI API example                     | 明确 server URL、scope、allowed_tools、真实 trace、revocation；不宣传未经实测客户端  |

现有 solver 只覆盖步行/骑车/汽车。第一次落地可先用真实步行 provider 验证 Tokyo，再接 transit；但对外若宣传公共交通，必须完成对应真实 adapter 和时间依赖测试。缺配置时应返回可解释失败/未知草案，不把 demo_estimate 当 resolved。

## 顺序和验收

1. **契约与安全状态**：把原型的 28 个边界案例迁入维护中的测试栈；额外覆盖同 key 跨进程并发 create、提交后响应丢失、provider 外算后 CAS 失败、租户隔离、未知字段、经纬反转、日期无效、DST gap/重叠、7 天/40 stop 上限、单/空日。生产用维护的 schema validator，校验所有成功及失败输出。
2. **持久化事务**：两个 worker 的并发 CAS 必须只有一个提交；map 变更 + edit + 幂等最终结果同事务；可重试失败释放 lease。进程崩溃/重新部署后分享链接仍可读。给存储读写延迟和容量做实际预算。
3. **真实来源**：至少 9 个东京 POI 用实际 provider 返回，记录来源、CRS、更新时间；模糊/不存在不能硬编。真实步行/公交路线 geometry 与 duration 必须区分；营业日未知显示未知。固定预约改天必须拒绝。
4. **Web 用户路径**：创建 → 彩色三天 → 分享 → 新浏览器只读 → 复制编辑；所有者同链接可拖 pin；src/target 同版本更新；计算失败原位；键盘菜单完成同样意图；撤销受版本保护。390px 不横向溢出，touch targets ≥44px。Desktop Chrome 通过不等于 Safari/真机/读屏通过。
5. **公开分享投影**：显式 visible_stop_ids、默认新点不公开；隐藏点不进入 bounds/geometry/OG/fork；token hash、过期、撤销、分析脱敏；链接无 edit grant。首次分享说明谁能看、有效期和公开内容。
6. **真正 Grok E2E**：部署公网 HTTPS map MCP，map-only token 放服务端。拿真实 xAI key 用下方请求运行「规划东京 3 天」，审查 server trace 确认实际六工具调用和工具返回链接。把链接在新浏览器打开，执行一次 move + 刷新读回。记录 model ID、map revision、测试账号/隔离空间归属、时间和截图。只有 API 实测就写 Grok API，不能写 grok.com 已接入。
7. **发布**：独立 review 修完确认的 P0/P1，最新提交 CI 过，再按授权合并；部署、生产验收、App deep link、真机分别记录。原型的 GET-294 可作为设计完成；生产实现建后续 issue，不因设计 PR 合并就宣称功能上线。

## xAI Responses API 请求形状

截至 2026-10-29，见 [官方文档](https://docs.x.ai/developers/tools/remote-mcp)。模型 ID 由执行环境选用当前可用模型，不写入产品常量。不能把下面的 example origin 当成真实部署。

```json
{
  "model": "<available-grok-model>",
  "input": [
    {
      "role": "user",
      "content": "规划东京 3 天。按三个区域安排，先查地点，再建图，最后给我地图链接。未提供日期，不要假设营业日或伪造交通。"
    }
  ],
  "tools": [
    {
      "type": "mcp",
      "server_url": "https://<verified-public-host>/mcp/maps",
      "server_label": "roamorrow_maps",
      "authorization": "Bearer <scoped-token-from-secret-store>",
      "allowed_tools": [
        "create_map",
        "search_places",
        "plot_places",
        "build_route",
        "update_day",
        "get_map_link"
      ]
    }
  ]
}
```

请求发到 `POST https://api.x.ai/v1/responses`，xAI key 在 Authorization header。不要加文档声明不支持的 `require_approval` 或 `connector_id`。两层凭据分开：xAI key 只去 xAI，map token 只给 maps server。MCP server 不读取整段对话或 xAI key。确认 host 支持协商的 MCP wire revision，不匹配就失败，不硬凑字段。

需要的外部接入项：公网 HTTPS endpoint、xAI 凭据、可合法使用且适合东京交通模式的 POI/route provider、生产地图持久化与 map-only 授权。当前缺少这几项时，仍可完整评审设计与本地交互；不得写「Grok live 链路完成」。
