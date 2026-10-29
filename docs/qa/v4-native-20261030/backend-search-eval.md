# V4 后端联网搜索验收

2026-10-30。按现有 App 配置，对 Supabase Auth → `tavily-search` Edge 做一次有界真实验收，没有改产品、默认开关、权限或账号绑定。

## 结果

**现有测试账号登录失败：HTTP 400，`invalid_credentials`，耗时 4,365 ms。认证已执行 1/1 次；Edge 查询执行 0/1 次。** 没有收到会话或令牌，因此没有调用搜索，也无需登出。

这次失败发生在 Auth 层。它不能判定具体是账号、密码还是该项目中的账号状态有问题，也不能据此判断 Edge 未部署、Tavily 故障或原生 iOS 链路通过。本轮没有重试、切换账号、注册账号、改默认 flag 或直连 Tavily。

## 实际使用的路径

主仓库 `.env` 指向 `oknhlhpeuoqaaodalxyl.supabase.co`。匿名 key 声明 `role=anon`，ref 与 URL 一致。凭据从既有 AGENTS 测试账号说明读取，只在请求进程内存使用；没有把任何凭据、key、令牌或用户 ID 写入产物、日志或 Keychain。

先前管理面检查中，已连接 Supabase 插件列出的三个项目不含此 ref，读取目标项目权限拒绝；这说明当前管理连接不能检查该项目，不能推导 App runtime 账号无权登录。后续任务明确授权直接验证现有配置的正常 runtime 登录。插件没有对应的用户密码登录与 App Edge 调用能力，因此使用 HTTPS REST 作为能力补充，没有更换插件账号或进行项目管理操作。

唯一一次请求为 `/auth/v1/token?grant_type=password`，目标严格限制为上述配置的官方 HTTPS host，并禁止跳转。服务返回 JSON 错误 `invalid_credentials`。没有收到会话，预定公开查询“神保町书店官网来源”没有发送至 Edge。

## 原生验收边界

- `WebSearchService.searchOutcome` 检查 backend 开关，经 `SupabaseClient.invoke(function: "tavily-search")` 调用，不直接使用 Tavily key。
- 当前资源默认 `FF_BACKEND_SYNC=false`，正常默认路径会报告 `backend_disabled`；本项没有改开关。
- `SupabaseClient` 从 `sc.supabase.session` 读取会话；`EmailAccountService` 使用 `sc.harness.email.session`。既有身份隔离没有被桥接，邮箱登录也不等于搜索 client 已取得会话。
- 仓库中的 Edge 源码验证 JWT、按用户核算配额，再读服务端 Tavily secret；本轮没有触达远端 Edge，部署版本和搜索结果均未验证。
- 若有新会话，本次实现的清理路径只会请求 `/auth/v1/logout?scope=local`。本次未创建会话，未发送登出请求。Supabase 说明 `local` 只结束当前会话，已有 access JWT 仍可能有效至到期，参见[官方登出范围说明](https://supabase.com/docs/guides/auth/signout)。

## 证据与剩余事项

[最新汇总](results/backend-search-status.json) 与 [本次 REST 记录](results/backend-search-runtime.json) 保存状态码、脱敏错误分类、请求预算、源码 SHA 和边界，不保存响应原文或任何凭据。

本轮认证预算已用完。后续需先解决此项目现有测试凭据的有效性，再另行验收 Auth → Edge，以及实际 iOS client 的 backend-on 配置、会话来源和模型编排；当前不能将联网搜索记为通过。
