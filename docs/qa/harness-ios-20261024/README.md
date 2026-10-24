# DeepSeek Harness 与邮箱用户故事验收

2026-10-24；分支 `codex/deepseek-onboarding-harness`。源码和后端运行时已完成一轮验收，完整用户故事仍有以下真实接入缺项，不能据此发布或认定 iOS 启动成功。

## 现在具备的流程

1. 原有条款步骤后进入邮箱页，支持邮箱验证码、已有账户密码登录和游客继续。地址本身不产生登录身份。
2. 验证身份后，可分别选择只读 Google Calendar、Gmail，或跳过 Google。
3. 用户确认姓名、常住城市和兴趣，另行选择是否允许 AI 读取账户上下文。邮箱不会被推断成姓名、城市或性格。
4. 资料建议通过服务端 DeepSeek 工具循环生成；建议留在当前页面，用户自行审核。不会写入设备共用的旧对话日志，也不会自动变成确认事实。
5. 设置页可管理资料、断开 Google 和退出。邮箱会话独立存入 Keychain，避免旧匿名同步覆盖身份或把旧设备数据迁入新账户。

服务端与 MCP 共用三个只读工具：`get_traveler_profile`、`list_calendar_events`、`search_travel_mail`。日历最多未来 14 天、20 项；邮件最多过去 30 天、10 项，只读选定 headers/snippets，无正文附件、发送或日历写入。Google 数据要求对应 scope 和单独的 AI 上下文同意。

## 实测结果

| 项目                       | 结果与证据                                                                                                                                                    |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Go 全包 / vet / race       | 通过；[包测试](go-test.log)、[race](go-race.log)                                                                                                              |
| 真实 PostgreSQL            | 迁移及重入通过，4 张表；[数据库记录](database.json)                                                                                                           |
| 真实 SQL 隔离和竞态        | 4 项通过：账户隔离、断开和 state、旧宽权限刷新拒绝、真实锁等待后的撤销；[日志](postgres-live.log)                                                             |
| 真实 DeepSeek provider     | 两轮 HTTP 200，工具调用和结果消费通过；只用合成资料；[记录](deepseek-provider.json)                                                                           |
| 真实 Go Harness → DeepSeek | 通过，一次资料工具调用及最终回答；身份/资料为测试夹具，模型是实际服务；[日志](deepseek-harness-live.log)                                                      |
| API 运行时                 | `127.0.0.1:4437`，9 项探针通过，无 token MCP 401，真实 Supabase 拒绝无效 bearer 401；[汇总](acceptance.json)                                                  |
| iOS 编译                   | 真正 `build-for-testing` 通过，应用及受影响测试 bundle 已编译；[记录](native-receipt.json)                                                                    |
| iOS 执行 / 页面启动        | 未通过验收：初次 XCTest 启动中断及 bootstatus 超时；后续已完成 boot/install，launch 返回 PID，但 4 秒截图仍为白屏。聚焦测试再次在启动阶段中断，不记为测试通过 |
| 独立 review                | 已修复并复核关闭确认的 P0/P1；[后端](review-backend.md)、[iOS](review-ios.md)。源码 review 与运行证据分别记录                                                 |

iOS 测试时观察到磁盘降至 12.32 GiB、swap 达 24.36 GiB；停止本任务测试后回落。启动超时的根因未确认，不把资源阈值当作已证明的根因。只使用 Primary iPhone，无新建、擦除或抢占其他设备。测试启动的设备已由共享会话关闭。

## 仍需接入的信息

- 默认测试账号 `test@cubxxw.com` 的私密凭据登录返回 `invalid_credentials`。没有改用其他账户，也没有发送 OTP。需要有效私密凭据，或用户选择邮箱验证并完成验证码步骤。Supabase 邮件模板是否包含 OTP 尚未实测。
- Google OAuth client/secret 尚未提供，`google=false`。未读取真实邮箱、日历或联系人；缺配置时 UI 可跳过。
- Tailscale proposed origin：`https://smile-m4-minimac-mini.tail25e61f.ts.net:18443`。专用端口空闲，dry-run 已通过，具体 Serve 命令仍待确认。没有变更现有入口。
- 未执行 TestFlight archive、上传、Release CI 或物理设备测试。

## 运行和复验

正式运行配置见 [backend guide](../../development/harness-backend.md)。真实运行环境文件 `deploy/harness.runtime-env` 已忽略且 mode `0600`；没有服务端密钥进入 Git。本次原生构建的 DeepSeek key 为空；Harness 使用后端的独立运行环境。

机器资源受限时可先在注册的测试产物目录生成 Linux arm64 静态二进制，再使用已缓存的镜像。`up-cached.sh` 清除 Docker build，通过 Docker API 复制二进制和迁移，无需扩大 Colima 的宿主机目录挂载。使用非 root 用户，API/DB 各限制 256 MiB、1 CPU，日志有界。普通 Dockerfile 镜像构建本次未运行。

```bash
# 在 apps/api，输出路径由 dev-storage-guard new-artifact 创建
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 GOMAXPROCS=2 go build -p 2 -o <artifact>/api-server .
# 在仓库根目录；只使用本项目的私密 env
DOCKER_CONTEXT=colima bash scripts/harness/up-cached.sh <artifact>/api-server
DOCKER_CONTEXT=colima bash scripts/harness/probe.sh
DOCKER_CONTEXT=colima bash scripts/harness/down.sh
```

数据库不发布端口。DB 只接收 `POSTGRES_*`，没有 DeepSeek、Supabase 或令牌加密密钥。测试栈 `restart=no`，验收结束后执行 `down -v --remove-orphans`；不作为常驻服务。

后续 iOS 复验复用已编译产物，保持单设备共享会话。`scripts/ios/account-acceptance.sh` 显式设置宿主 wrapper 的 `IOS_XCODE_JOBS=2`。不要删除、擦除共享设备或把未运行的用例记为通过。

## 本轮收尾状态

实现及验证凭据已保存在本地提交 `492184de`，未推送、创建 PR 或发布。测试后已执行 `down -v --remove-orphans`，读回确认本任务的 API/DB 容器、网络和测试卷均不存在；Docker context 仍为 `colima`。上述健康状态和探针结果是运行时验收记录，当前没有常驻 Harness 服务。Tailscale 仅完成 dry-run，未应用入口。

原生启动尚未验收，因此保留 `/private/tmp/ai-test-roamorrow-deepseek-harness.Lk95UC` 的编译产物，以及 `/private/tmp/ai-test-roamorrow-harness-runtime.9NlvxH` 的已验证运行二进制用于复验。正式原生日志另存于 `/Users/cubxxw/ops/evidence/roamorrow-harness-20261024/`。这两个已登记目录仍属于未完成任务，后续验收完成再精确回收，不作为永久证据库。

仅回收已核对无活动引用的 npm/pnpm 下载元数据缓存，共 `391876608` bytes（0.36 GiB）；不计磁盘读数波动或 Docker VM 内卷空间。详细记录：`/Users/cubxxw/ops/reports/roamorrow-harness-cleanup-20261024.json`。原 main 同步前的修改仍保存在 stash `444fde3643358b3fdb11358fa83ad44a0ed8780c`，未应用或删除。

MCP 客户端需要本项目已验证邮箱会话的 access token。以下仅为当前 CLI 已核对的连接方式，没有修改全局 Codex 配置，也没有把任何 token 写入配置：

```bash
codex mcp add roamorrow-harness \
  --url https://smile-m4-minimac-mini.tail25e61f.ts.net:18443/mcp \
  --bearer-token-env-var ROAMORROW_HARNESS_ACCESS_TOKEN
```

`ROAMORROW_HARNESS_ACCESS_TOKEN` 由调用进程的私密环境提供，过期需通过真实登录刷新。MCP 没有加入产品外的写入、shell 或任意远程工具。

## 合并跟进 — 2026-10-24 10:24 CST

已创建本聊天的 `roamorrow-harness` heartbeat，每 15 分钟检查一次；状态不变时保持安静，满足必要验收、最新 head CI 和评审门禁后才合并。默认账户、精确 HTTPS 入口及原生 UI 验收仍缺证据，PR 应保持 Draft。

本次复用原生编译产物，没有重新构建。Primary 设备 boot/install 成功，App launch 返回 PID `76321`，截图是白屏，尚不能证明邮箱页可用。随后 `test-without-building` 在启动阶段停滞；观察到可用磁盘 24.11 GiB、swap 17.85 GiB，只向核验过的本任务 xcodebuild PID `76607` 发送 SIGINT，退出码 73。共享会话关闭本次启动的设备。正式日志和白屏截图保存在上述 ops evidence 目录，不以启动 PID 代替页面验收。

当前源码的 Go 全包、vet、race 已再次通过，新增 Markdown/JSON 已按仓库 pinned Prettier 复核。初始 head 的常规 CI 覆盖邮箱单元测试，但不执行独立 AccountOnboarding UI suite。TestFlight 当前也未注入三个账户配置值，自动上传不能证明该流程可用。

## PR 与 CI 修复

[Draft PR #674](https://github.com/getyak/roamorrow/pull/674) 已创建并加入本聊天监控。
初始 head `25997ac7` 的云端邮箱单元测试 12 项通过；完整原生目标执行 2013 项，
14 项跳过、2 项失败，因此不记为 CI 通过。两项失败是 main 原有的 Studio 文本本地化
和 WebSearchService 公开符号文档守卫，已修正，仍需新 head 复跑。

安全修复保留所有扫描门禁：可执行文件 SHA-256 误报仅添加历史精确指纹；Go 最低版本
和 Docker builder 升到 1.27.3；Node 的 21 项新审计告警通过目标版本更新处理，
`pnpm audit --audit-level=low` 与冻结 lockfile-only 校验通过，原 braces 缓解例外未扩大。
新增同设备账户 UI CI 步骤及路由 JSON 校验回归，执行结果仍待新 head CI。
详细界限和证据见 [CI security record](ci-security.md)。

额外宿主 XCTest 检查入口未兼容 Darwin runner，未执行用例；不将其作为通过证据。
本地原生全量测试仍不重跑。真实账户/profile/MCP、精确 HTTPS 和可用页面验收继续保持未完成。

## 账户 UI 标识符回归 — 2026-10-24 11:12 CST

head `6b847ca5` 的完整原生 unit 步骤已通过；新增 3 项账户 UI 测试全部失败。
CI 树中发送验证码、游客继续等按钮都继承了父 ScrollView 的 `account.setup` 标识符，
导致现有 `account.continue` / `account.guest` 查询失效。邮箱和密码输入控件可见，
这次失败与真实账号、OAuth 或后端连接无关。

候选修复只移除未被调用者使用的父容器标识符，保留所有子控件标识符及原来的 3 个
UI 测试，不改用 label 绕过、不跳过检查。Swift 语法检查通过；必须等待新 head
的同组真实 UI 测试重新验证后，才能关闭该回归。
