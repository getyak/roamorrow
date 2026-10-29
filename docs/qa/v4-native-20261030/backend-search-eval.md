# V4 后端联网搜索验收边界

2026-10-30。此项只核对实际 Supabase Auth → `tavily-search` Edge 路径，没有改产品、默认开关、权限或账号绑定。

## 结果

**停在发送凭据之前，认证执行 0/1 次，Edge 查询执行 0/1 次。** 不能把配置中存在 API key 写成联网搜索已通过。

主仓库 `.env` 指向 `oknhlhpeuoqaaodalxyl.supabase.co`。配置里的匿名 JWT 声明 `role=anon`，其中 ref 与 URL 一致；没有使用、打印或复制实际 key。工作树没有另一个 `.env`。这只能证明本机配置内部一致。

通过已连接的 Supabase 插件核对项目归属时，当前账号列出的三个项目均不含该 ref；读取目标项目返回权限拒绝。仓库 tracked 文件和已知本地 CLI link 路径也没有找到该 ref 的第二份部署绑定。因此尚不能验证目标云项目归属或 `tavily-search` 的实际部署状态。按本轮明确的停止条件，没有把通用测试账号凭据发到未确认的项目，也没有换账号、注册账号或申请权限。

这个结果不证明配置错误、项目不属于用户、认证失败或 Edge 未部署；它说明这次连接无法完成所要求的归属核对。

## 当前原生路径

- `WebSearchService.searchOutcome` 先检查 backend 开关，再经 `SupabaseClient.invoke(function: "tavily-search")`；没有直接使用本机 Tavily key。
- 当前资源默认 `FF_BACKEND_SYNC=false`，因此正常 shipping 默认路径会报告 `backend_disabled`。此项没有改开关。
- `SupabaseClient` 从 `sc.supabase.session` 读取会话；`EmailAccountService` 使用另一份 `sc.harness.email.session`。邮箱登录成功不能自动证明联网搜索 client 已有同一会话；本轮没有桥接这些既有身份边界。
- 仓库中的 Edge 源码验证 JWT、按用户核算配额，再读取服务端 Tavily secret。这里只读了源文件，不能据此证明远端已部署同版代码。

## 证据与下一步

[脱敏机器记录](results/backend-search-status.json) 包含 URL/ref、插件核对结果、请求预算、源码 SHA 和明确的未验收项，不含凭据、匿名 key、令牌、用户 ID 或私人查询。

取得该 ref 的明确既有项目／部署归属证据后，可继续剩余预算：一次现有测试账号认证和一次公开“神保町书店官网来源”查询；确认返回的账户与预期一致后才调用 Edge。新会话仅在内存中使用，结束时必须显式用 `scope=local` 登出，避免影响其他会话。Supabase 官方说明默认登出范围可能是全局，参见[登出范围](https://supabase.com/docs/guides/auth/signout)。本次没有创建会话，因此没有执行登出。

即便上述 REST 验收成功，仍需要以实际 iOS client、backend-on 配置及其会话来源另行验证，不能借 REST 结果声称新原生链路或模型编排通过。
