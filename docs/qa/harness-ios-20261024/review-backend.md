# DeepSeek/account harness 后端独立审查

审查日期：2026-10-24（Asia/Shanghai）。初审发现 **2 项 P1、7 项 P2**；以下以最新复核结论为准，初审条目保留作历史证据。

最新运行适配复核：见文末 **2026-10-24 03:20 CST** 追加记录；缓存模式现已取消 host bind mounts，并通过 Docker cp 安装 payload。没有剩余已确认 P0/P1，追加发现的 staging 残留 P2 已修复并读回关闭。

## 最终源码复核 — 2026-10-24 03:08 CST

**结论：独立源码审查通过；本次审查范围内没有剩余已确认 P0/P1，原 B01–B09 的核心代码问题及 R1–R5 已关闭。** 邮件查询边界和 cached override 的追加问题也已修正。此结论只表示代码发现已关闭，**不表示 Go 全包、race、真实 PostgreSQL、真实模型、发布或原生验收已执行/通过**。这些执行结果由父任务单独记录 receipt；本 reviewer 没有运行构建、测试、Compose 或服务，没有读取私密 env。

本轮被审源码已从 worker 集成到父工作区 `/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass`。以下位置均指父工作区的最终复核快照；此前章节的 worker 路径与行号仅保留为历史证据。

### 关闭证据

| 编号 | 最终代码结论 | 关键源码与回归测试设计 |
| --- | --- | --- |
| B01 / R1 | 已关闭 | [`oauth.go:143`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/apps/api/internal/harness/oauth.go:143) 按本次选择求 scope intersection；callback 在第 178 行使用 `ReplaceConnection`，不再使用 refresh commit。[`store_postgres.go:204`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/apps/api/internal/harness/store_postgres.go:204) 在 owner 锁内比较 state epoch、推进 epoch、保存新连接并取消其他 pending states；旧 refresh 在锁内比较其原 epoch 后只能 UPDATE 同一旧连接行，不能 INSERT 或覆盖新连接。`TestOldRefreshCannotOverwriteNewConnection` 包含旧宽 scopes/旧账户 refresh 期间完成新的 Calendar-only callback，并断言新账户与 scope 保留；`TestConcurrentOAuthCallbacksOneWinner` 覆盖旧 callback 拒绝。 |
| B02 / R2 / R3 | 已关闭 | [`store_postgres.go:125`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/apps/api/internal/harness/store_postgres.go:125) 的 `withOwnerLock` 显式 BeginTx、初始化 generation 行、`SELECT ... FOR UPDATE`，成功 Commit，错误 Rollback。CommitTokens、ReplaceConnection、Disconnect、CreateState 共用同一 owner 锁。Disconnect 使用事务内普通 UPDATE/DELETE/RowsAffected，原无 RETURNING CTE 已删除。无 token 的 owner 也会初始化并推进 epoch。 |
| B03 | 已关闭核心代码问题 | token 到期前刷新；无 refresh token/invalid_grant 明确 `reauthorization_required`；provider 未返回新 refresh token 时保留旧值；fresh scopes 与原应用允许范围求交集。[`tools.go:319`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/apps/api/internal/harness/tools.go:319) CAS 失败后拒绝服务 stale refresh，并区分 disconnected / connection_changed。expiry/rotation/rejected refresh/disconnect 测试已存在。 |
| B04 | 已关闭 | metadata 按尝试数限制 10；全部失败返回 provider error；部分失败标记 partial。相应真实 HTTP fake-client 与 tool-result 回归用例仍保留。 |
| B05 | 已关闭 | callback 先原子 ConsumeState，再处理 denial/missing code；denial 后同一 state 无法再成功使用。 |
| B06 | 已关闭 | REST 完整读取受限 body；REST、tool arguments、MCP 均二次 Decode 并严格要求 EOF。尾随 delimiter/第二个对象/垃圾/超限空白回归用例已添加。 |
| B07 / R4 | 已关闭 | [`auth.go:137`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/apps/api/internal/harness/auth.go:137) 在调用 Verify 前处理 true nil，返回 503；`TestAuthMiddlewareNilVerifierNoPanic` 使用真实 NewServer、无 recovery、未替换 verifier，检查 profile 与 MCP。Google/DeepSeek constructor true nil 回归测试保留。 |
| B08 | 已关闭示例配置问题 | 私有 Compose DSN 示例已明确 `sslmode=disable`；真实连接与迁移是否通过须读父任务 receipt。 |
| B09 | 已关闭原 owner/purpose 密文交换问题 | AES-GCM AAD 绑定 verified owner + Google 字段用途；访问/刷新/PKCE 用途不能互换，调用点均传预期 owner；对应 crypto tests 已保留。PKCE 尚未额外把 state 字符串加入 AAD，本轮关闭范围为原跨 owner/用途问题，不把该附加增强描述为已实现。 |
| R5 | 已关闭 | [`compose.harness.yml:28`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/deploy/compose.harness.yml:28) 的 db 不再使用全量 env_file，只显式映射 POSTGRES_USER/PASSWORD/DB 与 PGDATA；API env_file 不再进入数据库服务。 |

### 邮件查询边界追加复核

[`google.go:417`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/apps/api/internal/harness/google.go:417) 已把 caller query 用 `strconv.Quote` 包成双引号字面 phrase；原 tool query 白名单仍拒绝双引号、反斜线、冒号、括号等可突破语法边界的字符。因此 `OR inbox` / `OR foo` 不能成为 server-owned after/travel group 外的顶层 OR。

新增 [`google_query_boundary_test.go:12`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/apps/api/internal/harness/google_query_boundary_test.go:12) 通过 HTTP fake endpoint 读取实际发送的 q，检查固定日期/服务端 group 前缀，以及 `) "OR inbox"` 后缀。本轮曾发现 expected terms 复制了另一版词表、会确定失败；父任务已改为边界前后缀断言，03:08 已读回该修复，**该 P2 已关闭**。未声称执行了此测试。

### 真实 PostgreSQL 测试设计复核

[`store_postgres_live_test.go:15`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/apps/api/internal/harness/store_postgres_live_test.go:15) 是显式 opt-in，用合成 owner 前缀与精确 owner 删除收尾；未配置 `HARNESS_INTEGRATION_DATABASE_URL` 会 Skip。父任务必须确认真实运行而不是把 Skip 算为通过。

- `profile_owner_isolation` 验证参数化恶意字符串 owner 与跨 owner 隔离。
- `state_one_use_and_real_disconnect` 真实执行 one-use state、ReplaceConnection、Disconnect、pending-state 取消与晚到 refresh 拒绝，能够发现旧版 CTE 语法错误。
- `new_connection_rejects_old_broad_refresh` 验证新账户/窄 scopes 不被旧 refresh 覆盖。
- `late_commit_waits_and_rechecks_revoked_epoch` 使用不同数据库连接、未提交的撤销与 `pg_stat_activity.wait_event_type=Lock` 确认实际锁等待，再提交撤销并要求旧 writer 返回 ErrStaleConnection；比仅检查 SQL 文本或 fake mutex 更能验证原 MVCC 窗口。

本 reviewer 只核对了上述测试源码和断言，**没有代写任何真实 PG 或真实 DeepSeek 的通过结果**。

### Compose 与资源边界复核

[`compose.harness.yml`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/deploy/compose.harness.yml) 保持 DB 无 host port、API `127.0.0.1:4437:8080`、服务 restart=no；DB/API 各 256 MiB memory 与 1 CPU，日志各最多 3×10 MiB。PostgreSQL command 禁用 statement logging，未新增 raw body/token/prompt 日志。

[`compose.harness.cached.yml:7`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/deploy/compose.harness.cached.yml:7) 保留 `build: !reset null`，避免继承 API build 并污染共用 PostgreSQL image tag；binary/migrations 均只读挂载，API 使用 postgres 非 root user。父任务将此模式限定为本地资源受限验收，使用 `--no-build --pull never`。此模式不能代替普通 Dockerfile 的构建验收结论。

### 最终范围限制

本轮没有新的必须修复代码发现，已确认的 P0/P1 为零。后续若父任务的真实执行出现失败，仍需按失败证据修复并复核；不能据本报告跳过 CI、实际数据库/模型验收或其他既定交付门禁。初审与第一轮复核保留如下，状态由本节覆盖。

## 第一轮修复复核 — 2026-10-24 02:50 CST

**结论：未通过；没有发现 P0，B01/B02 的 P1 尚未关闭，B07 仍有 P2 回归。** 本轮只读检查 Pi 同一 worker worktree 的第一轮修复源码及新增测试，未运行构建、Go 测试、数据库、Compose 或其他服务，未读取私密配置。父任务负责后续真实 PostgreSQL 验收与竞态测试。

### 逐项状态

| 初审编号 | 本轮结论 | 代码与测试证据 |
| --- | --- | --- |
| B01 | **P1 未关闭** | `oauth.go:143-150` 已按本次选择与 provider 授予 scopes 求交集，`TestGoogleCallbackCalendarOnlyStateNeverEnablesMail` 覆盖单流程；但旧连接刷新仍能覆盖新连接，见 R1。 |
| B02 | **P1 未关闭** | 新增 generation、pending state 取消及 fake-store 测试；真实 PostgreSQL `Disconnect` SQL 无效，且 compare-and-commit 没有串行化 owner 行，见 R2/R3。 |
| B03 | 基础过期/刷新问题代码已修；竞态归 B01/B02 | `tools.go:267-326` 处理刷新及 `reauthorization_required`，`google.go:200-215` 保留未轮换的 refresh token，刷新 scopes 与原允许范围求交集。新增 expiry/invalid_grant/rotation/fake disconnect 测试；真实并发持久化不能由 fake store 证明。 |
| B04 | 原问题代码已修 | `google.go:451-471` 按 metadata 尝试次数限制 10、全部失败返回错误、部分失败输出 partial；`TestGoogleClientMailAllFailedPropagatesError`、`TestGoogleClientMailMixedResultsAreLabelledPartial`、`TestGoogleClientMailAttemptsBounded`、`TestMailToolLabelsPartialResults` 覆盖相应分支。 |
| B05 | 原问题代码已修 | `oauth.go:120-127` 先消费有效 state 再处理 denial；现有 replay 测试已改成 denial 后不能再次成功使用。 |
| B06 | 原问题代码已修 | REST 先完整读取受限 body，再二次 Decode 要求 EOF；工具参数与 MCP 同样二次 Decode。新增 `TestStrictJSONTrailingDataRejected`、`TestMCPTrailingGarbageRejected`。GET/DELETE `/mcp` 也已加 Origin 验证。 |
| B07 | **P2 未关闭** | DeepSeek/Google 的 true nil 构造已修，真实 constructor 回归测试已添加；Supabase verifier 改成 true nil 后 AuthMiddleware 无 nil guard，见 R4。 |
| B08 | 示例配置代码已修 | `deploy/harness.runtime-env.example:15` 已明确 `?sslmode=disable`。本轮不声称真实数据库/迁移验收通过。 |
| B09 | owner/purpose 核心问题代码已修 | `SealToken/OpenToken` 使用 owner + provider/purpose AAD；所有 provider token 调用点均传 verified owner；`TestCipherAADBindsOwnerAndPurpose` 覆盖跨 owner 与 access/refresh/PKCE 用途交换。原报告附加要求的 PKCE state-specific AAD 尚未实现，本轮关闭范围仅为原跨 owner/用途密文交换问题。 |

### 本轮仍需修复的具体问题

**R1 / P1 / B01：旧 refresh 可覆盖新连接，恢复更宽 scopes 或旧 Google 账户。**

- 位置：[`tools.go:293`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/tools.go:293)、[`tools.go:319`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/tools.go:319)、[`oauth.go:176`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/oauth.go:176)、[`store_postgres.go:144`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/store_postgres.go:144)。
- 触发：旧连接含 Gmail，token refresh 在途；用户完成新的 Calendar-only callback；旧 refresh 随后返回。成功 callback 不推进 generation，旧 refresh 仍持有相同 generation，并按旧 token 的宽 scopes 求交集后写回。两个 commit 即使顺序执行也会发生，单纯加数据库行锁不足以修复。
- 后果：新选择被撤销，Gmail 重新可读；若用户切换 Google 账户，旧账户凭据可覆盖新账户。
- 修复：OAuth connection replacement 与 refresh 分成不同存储操作。成功 replacement 在锁定 owner 行后比较 state epoch、推进 connection epoch 并保存新 tokens；refresh 必须比较读取到的 connection epoch/revision，仅更新仍属于同一连接的 token。
- 必要测试：在 fake refreshFn 内完成新的 Calendar-only callback，再返回旧宽 scopes token；新连接必须保持 Calendar-only。补不同 Google 账户版本；真实 PostgreSQL 对该顺序和并发执行均需验收。

**R2 / P1 / B02：Disconnect 的 DELETE CTE 没有 RETURNING，却被外层 SELECT 引用。**

- 位置：[`store_postgres.go:173`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/store_postgres.go:173)、[`store_postgres.go:178`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/store_postgres.go:178)。
- 触发：任意真实 PostgreSQL `Disconnect` 调用；`del_tokens` / `del_states` 无 RETURNING，却用于 FROM/EXISTS/count。
- 后果：PostgreSQL 拒绝整条语句，disconnect 返回 503，token、本地访问和 pending states 均未可靠撤销。
- 修复：按下项共同 owner 锁设计改成明确事务，并正确读回删除结果；不要依靠无法引用的无 RETURNING CTE。
- 必要测试：真实 PostgreSQL 有/无 token、存在 pending state 的 Disconnect 均成功；读回 generation 已推进、tokens 已删除、pending state 不可使用。现有 `captureDriver` 接受任意 SQL，且测试忽略 store 返回值，不能证明语法可执行。
- 官方依据：[PostgreSQL 18 data-modifying WITH](https://www.postgresql.org/docs/18/queries-with.html#QUERIES-WITH-MODIFYING) 明确无 RETURNING 不形成可引用的临时表。

**R3 / P1 / B02：CommitTokens 的 generation SELECT 只有 MVCC 快照，没有 owner 行锁。**

- 位置：[`store_postgres.go:136`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/store_postgres.go:136)，关联 `store_postgres.go:165-178`。
- 触发：CommitTokens 语句在 disconnect 前取得旧 generation 快照；disconnect 随后推进 generation 并删 token；旧 INSERT 在其后继续完成。普通 SELECT 不锁 `user_generations`，ON CONFLICT 只涉及 token 行。
- 后果：修掉 R2 后，旧 callback/refresh 仍可在 disconnect 返回后重新插入旧 tokens。不存在 token、generation 尚未初始化的首次连接也有同类窗口。
- 修复：先初始化持久 owner generation 行，CommitTokens、connection replacement、Disconnect 都在明确事务中按同一 owner 行 `SELECT ... FOR UPDATE` 串行化；generation 必须在获取锁后重新读取并比较。CreateState 与取消状态也应保持对应 epoch 语义。
- 必要测试：真实 PostgreSQL 独立连接和可控 barrier 覆盖 disconnect 先提交/commit 先获得锁、无初始 token、旧 callback、旧 refresh；最终断开完成后必须无 tokens。不能以 fake memStore 的 mutex 或 SQL 关键字断言替代。
- 官方依据：[PostgreSQL 18 Read Committed](https://www.postgresql.org/docs/18/transaction-iso.html#XACT-READ-COMMITTED) 说明普通 SELECT 使用语句开始时快照，SELECT FOR UPDATE 才提供对应锁定与最新版本处理。

**R4 / P2 / B07：true nil verifier 造成未配置认证请求 panic。**

- 位置：[`auth.go:144`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/auth.go:144)，关联 `server.go:40-42`。
- 触发：通过 `NewServer(Config{}, store)` 建立实例，带非空 Bearer 请求 protected route。构造器现在保留 true nil interface，但 middleware 仍直接 `.Verify()`。
- 后果：nil-interface panic；有 recovery 时为 500，违反缺认证配置应返回 503 的合同。
- 修复：调用前显式判断 `s.verifier == nil` 并返回 503。
- 必要测试：使用真实 NewServer 缺 Supabase 配置的实例发 HTTP 请求，不手工替换 verifier；现有 `TestAuthMiddlewareMissingConfigIs503` 手工赋 typed nil，未覆盖此构造路径。

### 新增运行配置检查

**R5 / P2 / 待父任务修复：DB 容器获得不需要的 API secrets。** worker `deploy/compose.harness.yml:18-19` 给 db 使用整个 `harness.runtime-env`，因此 DeepSeek key、Google client secret 和 token encryption key 同时进入数据库容器环境。数据库进程/容器边界一旦被读取，这会把数据库密文和解密 key 暴露在同一边界。db 只应显式接收 POSTGRES_USER、POSTGRES_PASSWORD、POSTGRES_DB（以及必要 PGDATA）；父任务已认领该修复。本轮未读取真实 env 文件，也未运行会输出 secrets 的 compose config。修复后只检查合成配置或环境变量名称，不能打印真实值。

**cached override：原 build 继承问题已由父任务修复代码。** 最初 `deploy/compose.harness.cached.yml` 添加 `image: postgres:18-alpine` 但继承 base `api.build`，沿用 `--build` 可能把 API 镜像打到 PostgreSQL 共用 tag。02:50 读回父工作区已在第 7 行加入 `build: !reset null`；父任务限定本地验收使用 `--no-build --pull never`。只读 binary/migrations mount、postgres 非 root user、继承 loopback 端口和 restart=no 未发现新的必要问题。本轮未执行合并配置或启动；该 override 仅为本地验收手段，不代表生产 Dockerfile 构建验收通过。参考：[Compose merge/reset](https://docs.docker.com/reference/compose-file/merge/#reset-value)。

### 下一版复核门禁

父任务已决定采用 owner generation 行锁事务，以及分离 connection replacement / refresh 的存储架构。以上是已确认的修复方向，**不等同代码已修或真实 PostgreSQL 测试已通过**。下一版重点复核 R1–R5，并要求真实 PostgreSQL race/Disconnect 证据；在 R1/R2/R3 关闭前，不得认定无未解决 P1。

## 审查边界与证据

- 被审工作区：`/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree`。
- 基线：`b01c0b27`；本报告针对第一轮未提交实现快照。Pi 后续修复不能由本报告自动认定通过；下列行号属于被审快照。
- 合同：`docs/architecture/deepseek-onboarding-harness.md`。
- 范围：`apps/api/internal/harness/**`、`apps/api/migrations/harness/**`、`apps/api/main.go`、相关 Dockerfile、`deploy/*harness*`、`scripts/harness/**`。
- 方法：只读检查实现、测试、迁移、运行配置及必要官方文档。未运行 Go 测试、构建、服务、浏览器或 Simulator；未读取真实凭据、生产数据；未修改源代码。执行测试的任务归父任务所有。
- `Decoder.More()` 行为通过本机 Go 1.26.6 标准库 `src/encoding/json/stream.go:485-487` 验证；`lib/pq v1.12.3` SSL 默认值通过本机模块源码及官方文档验证。

## P1

### B01 — 本次未选择的 Google scopes 仍可能恢复并供模型使用

**位置**：[`oauth.go:139`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/oauth.go:139)，关联 `google.go:144`、`chat.go:92-100`。

**触发条件**：Google 账户曾授予 Gmail 权限，provider 端授权仍存在；本次 `/google/start` 只选择 Calendar。授权 URL 使用 `include_granted_scopes=true`，provider 可以返回历史 Gmail 与 Calendar 的合并权限；callback 忽略 state 中的 `WantCalendar` / `WantMail`，直接保存 `tok.Scopes`。

**后果**：本次未选择的 Gmail 工具被视为已授权；全局模型上下文同意为 true 时，`runChat` 会向 DeepSeek 提供邮件工具，扩大了本次选择的数据访问范围。

**修复要求**：区分 provider 实际授予范围与应用本次允许范围；只有 state 中明确选择且 provider 实际授予的能力可被启用。后续刷新不能重新扩大该允许范围。不要仅依赖 provider 返回的 scope union。

**必要测试**：Calendar-only state + 返回 Calendar/Gmail token，保存后的应用允许范围不含 Gmail；REST、MCP、chat 均不得读取或提供邮件工具；Mail-only 对称测试；provider 部分授予时只启用实际获准的选择项。

来源：[Google incremental authorization](https://developers.google.com/identity/protocols/oauth2/web-server#incrementalAuth) 说明合并授权 token 可访问历史授予范围。

### B02 — 断开连接后，待完成 OAuth callback 仍能重新保存 tokens

**位置**：[`oauth.go:176`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/oauth.go:176)，关联 `oauth.go:115-153`、`store.go:61-68`。

**触发条件**：先创建 Google OAuth state，随后调用 `DELETE /google`，再完成旧 callback；或者 callback 已 ConsumeState，仍在 exchange/userinfo 阶段时执行 disconnect。DELETE 仅删除现存 tokens，不取消该用户 pending states，也没有防止已启动 callback 在删除后写回的 generation 校验。

**后果**：DELETE 已返回 `disconnected:true` 后，旧流程仍可重新连接。若旧 token 与新流程对应不同 Google 账户，对旧 token 的 provider revocation 也不能撤销新账户访问。

**修复要求**：disconnect 必须取消该用户所有 pending states，包括当前没有 tokens 的情况；通过连接 generation 或等价事务性约束，拒绝在断开前启动、断开后完成的 callback 保存 tokens。仅删除未消费 states 不足以处理已进入 exchange 的 callback。

**必要测试**：start → disconnect → callback 被拒绝；不存在 tokens 时 disconnect 仍取消 state；用阻塞 fake exchange 安排 callback consume → disconnect 完成 → exchange 完成，最终不得存有 tokens；不同账户的旧/新 token 场景。

## P2

### B03 — 过期 Google token 无刷新或明确重新授权状态

**位置**：[`tools.go:253`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/tools.go:253)，关联 `google.go:166-205`、`server.go:154-157`。

**触发条件**：已保存的 access token 到达 `ExpiresAt`。工具解密后不检查 `Expiry`，Google client 没有 refresh-token grant。

**后果**：后续工具持续使用过期凭据，返回泛化的 `provider_unavailable`；profile 仍因 token 行存在而显示 connected。用户无法区分服务故障与需要重新授权。

**修复要求**：读取前处理到期状态：实现有界刷新并安全保存新凭据，或返回明确可恢复的 `reauthorization_required` / 等价状态。刷新后的应用允许范围不能扩大，缺少新 refresh token 时应保留仍有效的旧 refresh token。

**必要测试**：过期 token、有/无 refresh token、刷新成功、invalid_grant/撤销、超时、并发刷新以及 scope 保留；过期状态不能继续被表示为可正常读取。

### B04 — Gmail metadata 失败被吞掉并返回成功空结果

**位置**：[`google.go:393`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/google.go:393)，关联 `google.go:403-438`。

**触发条件**：messages list 成功返回 IDs，但 metadata 请求出现 401、5xx、超时或无效 JSON。`fetchMailMetadata` 只返回 bool，调用者跳过失败项，最后返回 `msgs, nil`。

**后果**：全部 metadata 失败时，工具产生 `status:ok` 与 `messages:[]`，模型可能声称没有相关邮件；部分失败也被隐藏。遍历还以成功结果数而非尝试数限制 10，provider 超额返回且读取失败时可能超过预定的请求数。

**修复要求**：保留 sanitized error 分类，明确失败或明确标记部分结果；任何失败不能被伪装为完整空结果。metadata 尝试次数必须独立限制为 10。

**必要测试**：list 有 IDs、metadata 全部 401/超时/坏 JSON；部分失败不能静默完整成功；超额 list + metadata 失败时，总 metadata 请求数不超过 10。

### B05 — Google 拒绝回调没有消耗一次性 state

**位置**：[`oauth.go:111`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/oauth.go:111)。

**触发条件**：回调携带有效 state 和 `error=access_denied`。代码在 ConsumeState 前返回；同一 state 在 TTL 内之后仍可用于 code callback。

**后果**：已经以拒绝结束的 OAuth 尝试仍可被重放完成连接，不符合本次流程的一次性终结语义。现有 `TestGoogleCallbackReplayExpiryAndBadState` 反而明确断言 denial 后同一 state 能成功连接，掩盖该问题。

**修复要求**：对有效 state 先进行原子消费，再处理 provider denial；未知、过期、重放状态继续 fail closed。有效的 terminal error callback 应结束该尝试。

**必要测试**：denial → 同 state code callback 被拒绝且无 exchange/save；重复 denial 也不能再次消费；修改上述现有测试断言。

### B06 — JSON 解码未验证 EOF，REST、工具和 MCP 接受尾随内容

**位置**：[`server.go:104`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/server.go:104)、[`tools.go:96`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/tools.go:96)、[`mcp.go:82`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/mcp.go:82)。

**触发条件**：合法对象后附 `]` / `}`，或 body 在对象后有超过限制的空白。`Decoder.More()` 在遇到 closing delimiter 或读取错误时返回 false；它只检查容器中是否还有元素，不是 EOF 校验。MCP 只 decode 首个对象，随后 `rawField` 的全量 Unmarshal 因尾随内容失败，使带 id 请求落入无 id 通知路径。

**后果**：REST/工具会执行非法 JSON；过量尾随空白可能绕过宣称的 body-size 拒绝。MCP 畸形请求可能返回 HTTP 202 而非 parse error，调用方收不到关联响应。

**修复要求**：每个入口首轮 decode 后再 decode 一次并严格要求 `io.EOF`；不能吞掉 MaxBytesError。MCP 必须先确认完整单个 JSON frame，再提取 id。不要使用 `More()` 代替尾随内容验证。

**必要测试**：合法对象 + `]`、`}`、第二个对象、垃圾字符、超限尾随空白，以及正常尾随空白；所有入口必须拒绝非法/超限帧且不执行工具或写库；MCP parse error 应正确关联 null id 并且不返回 202。

### B07 — optional client 的 typed nil 使配置缺失检查失效

**位置**：[`server.go:35`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/server.go:35)，关联 `chat.go:42`、`deepseek.go:63-76`、`tools.go:253-260`。

**触发条件**：NewServer 把构造函数返回的 nil `*deepseekClient` / `*googleAPI` 赋给 interface。接口不等于 nil。

**后果**：缺 DeepSeek key 时 `s.deepseek == nil` 检查不命中，实际得到 502 而非合同要求的 503。若数据库仍有历史 Google tokens、token key 保留但 Google client 配置被移除，工具可能调用 nil `*googleAPI` 并 panic，产生 500。

**修复要求**：只有具体 client 非 nil 时才赋接口；工具读取入口也应检查 provider 配置和 client 可用性并返回可恢复错误。

**必要测试**：通过真实 `NewServer(Config{}, store)` / 缺 key 配置建立实例并请求 chat；Google 配置缺失 + 历史 tokens 时调用工具必须稳定返回 not_configured。现有 `TestChatMissingConfigIs503` 手工把接口赋 nil，不覆盖生产构造路径。

### B08 — Compose 示例 DSN 与默认数据库 TLS 设置不兼容

**位置**：[`harness.runtime-env.example:13`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/deploy/harness.runtime-env.example:13)，关联 `deploy/compose.harness.yml:15-29`、`store_postgres.go:36`。

**触发条件**：照示例配置启动默认 Compose。HARNESS_DATABASE_URL 没有 sslmode，而 `postgres:18-alpine` 此配置未启 TLS。仓库使用的 `lib/pq v1.12.3` 默认要求 SSL。

**后果**：API Ping 得到 `pq: SSL is not enabled on the server`，store 保持 nil，数据库相关接口均返回 503；容器 `/healthz` 仍可能显示健康。

**修复要求**：为这个无主机端口的私有 Compose 网络 DSN 显式设置 `sslmode=disable`，或完整配置 PostgreSQL TLS。不能通过放宽其他环境连接规则来掩盖示例问题。

**必要测试**：从示例生成合成 runtime-env，真实启动私有数据库、应用迁移并验证 API database capability 与 authenticated profile round trip；不仅检查 pg_isready 或静态 SQL 关键字。

来源：[lib/pq Config](https://pkg.go.dev/github.com/lib/pq#Config) 记录默认 `sslmode=require`；本机 v1.12.3 `connector.go:304-309` 同样明确该默认值。

### B09 — provider/PKCE ciphertext 未绑定 owner 和字段用途

**位置**：[`crypto.go:47`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/crypto.go:47)、[`crypto.go:59`](/Users/cubxxw/.local/state/pi-delegate/tasks/20261024-014623-ad35883d/worktree/apps/api/internal/harness/crypto.go:59)，关联 `server.go:346-368`。

**触发条件**：数据库行发生密文误归属，或攻击者具备数据库写能力并能复制现有 ciphertext。Seal/Open 都使用 nil AAD，owner、provider、access/refresh/PKCE 用途没有参与认证。

**后果**：把 B 的 access/refresh ciphertext 放入 A 的 token 行仍能成功解密；应用随后可以 A 的身份使用 B 的 Google 凭据。该问题的前提是数据库误写或可写篡改；本审查没有发现普通客户端通过现有 HTTP API 直接交换行的路径。

**修复要求**：AAD 至少绑定 verified owner、provider、字段用途；PKCE verifier 还应绑定 state。解密必须由调用者提供预期上下文，不能只信任密文旁边的任意 metadata。若已有密文需兼容，显式设计版本/迁移，避免永久允许无 AAD fallback。

**必要测试**：同 owner/用途 round trip；不同 owner、access↔refresh、token↔PKCE、不同 state 交换时均解密失败；metadata 修改不能扩大已允许 scopes。

## 复核门禁

父任务应逐项核对 B01–B09 的修复与回归证据。B01/B02 未关闭前不得认定隐私边界通过。本报告没有声称真实 Google OAuth、DeepSeek、Supabase、数据库部署、Tailscale 或原生验收已完成。

## 运行适配追加复核 — 2026-10-24 03:20 CST

**结论：本组操作脚本、Compose、Dockerfile 的只读复核通过，无新增已确认 P0/P1。** 父任务通知 Go、真实 PostgreSQL 与真实 DeepSeek 已通过；执行结果仍以父任务 receipt 为证，本 reviewer 没有重跑测试、构建、服务或 probe，也未读取私密 env。

- [`up-cached.sh:21`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/scripts/harness/up-cached.sh:21) 所有 create/stop/rm/up/ps 操作固定为 `roamorrow-harness-local` 项目的 `api` / `db`；Docker cp 的容器 ID 来自该项目的 API。只重建 stateless API；不删除 DB 或其他项目的容器/卷，不更改 Docker context、Colima 共享目录或 Tailscale。API 删除时的 `--volumes` 仅作用于该 API 容器的匿名卷，DB 的项目命名卷继续保留。
- cached override 不再有 host bind mounts，保留 `build: !reset null`；启动显式 `--no-build --pull never`。payload 只含已提供的静态 binary 与源码 migrations，复制到停止的新 API 容器；没有 docker commit 或构建镜像步骤，不把 runtime-env 复制进 payload/镜像。DB 仍只接收 POSTGRES_* / PGDATA，不获得 DeepSeek/Google/token encryption secrets；merged config 仅在 pipe 内供名称/边界检查，未打印其值。
- payload 目录 755、迁移文件 644、binary 755 让非 root API 可读/执行；普通 Dockerfile 的 `chmod -R a+rX /app/migrations` 仅调整镜像中的迁移权限。PG18 数据卷改为 `/var/lib/postgresql`，PGDATA 为 `/var/lib/postgresql/18/docker`。API loopback、DB 无 host port、restart=no、CPU/memory/log 上限均保留；API readiness 等待上限 30 秒。
- [`down.sh:7`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/scripts/harness/down.sh:7) 与 [`migrate.sh:7`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/scripts/harness/migrate.sh:7) 已传入私有 env-file 供必要变量渲染，仍固定同一项目。down 的 `-v --remove-orphans` 仍是专用测试栈收尾，不应被解释为其他项目或业务数据库的清理授权；注册 artifact 与 payload 的最终回收由父任务按原资源流程执行。

**追加 P2（已关闭）：旧 payload / 容器迁移目录残留。** 本轮发现固定 `runtime-payload/app` 重用及向旧 `/app/migrations` 合并复制，会让已删除/重命名的 SQL 留存并再次执行。03:20 已读回修复：[`up-cached.sh:9`](/Users/cubxxw/.codex/worktrees/deepseek-onboarding-harness/solo-compass/scripts/harness/up-cached.sh:9) 校验 binary 的父目录已登记为测试 artifact；第 13 行每次创建唯一 staging；第 35–39 行停止并仅删除本项目 API 容器后重新 create，再复制 payload。因新 staging 与新 API 均不含上次 SQL，该残留路径已消除。真实重启及 probe 结果由父任务另记，不由本报告代认通过。
