# 法律文档事实与双语独立复核

审查日期：2026-10-16；范围：隐私政策、用户协议、正式公开 Gist 与各端法律入口增量及其直接涉及的数据处理实现。审查只验证源码事实、文字边界和中英文一致性，不构成法律合规、法律充分性、App Store 审核或真实生产服务配置的保证。

**当前结论：两份正式 Gist 已公开发布，独立匿名 HTTP/API 读回均通过；本轮已修改法律生产入口和提交文档没有未解决的确认 P0/P1；新增文档问题 LEGAL-P1-02 已 source_resolved（见末尾）。L01 的源码入口和公开目的地已修复、验证。** 凭据存储 P2 与文档互链均已关闭；新 iOS 入口实际点击、App Store Connect 线上元数据和新二进制发布仍未验证，不作为已交付事实。

本 reviewer 只维护审查文档/评分文件；没有发布 Gist、修改生产文案、构建应用或读取私密凭据。Gist 发布由根代理完成；本文的匿名 HTTP/API GET 是独立只读复核。

## 文档边界与身份

| 文件 | 审查时 SHA-256 |
| --- | --- |
| `docs/legal/privacy-policy.md` | `fdaa47227d222a0f01694158b663cc813dcadf4cace8796ed7c2a40437729e47` |
| `docs/legal/terms-of-service.md` | `d192072979b29409a0e30d4abf3e7afe7bdaacc7ab655ab68f7ce0e470389e88` |

此哈希只绑定对应文件内容，后续文案变动需复核增量。两份文档均没有 `PENDING_OPERATOR`、`PENDING_CONTACT` 或其他 `PENDING` 残留；当前邮箱均为用户明确指定的 `cubxxw@gmail.com`。运营者表述是 Xinwei Xiong (cubxxw)、Solo Compass / Getyak 项目维护者，没有虚构注册公司或地址。公开身份与项目关联由根代理从当前 GitHub 公开资料和 cubxxw.com 核对；本次没有验证邮箱投递、运营响应流程或注册主体身份。

## 源码事实核对

以下是源码可证的实现边界，不代表服务已在生产启用、已抓包证明所有传输字段，或已完整验证第三方处理行为。已与同目录 `legal-data-audit.md` 交叉核对；该目录保留更细的数据流和未知项。后台定位能力与 `VisitTrackingService` 在后台清空本地停留计时器属于不同实现，草稿使用“可能支持”没有承诺全部到访逻辑持续后台运行。

| 主题 | 草稿与源码的对应关系 | 直接证据 |
| --- | --- | --- |
| 定位与后台 | 草稿有条件披露后台定位、到访检测和附近提示，没有“位置只留本机”承诺；探索坐标/半径可交给外部服务 | `apps/ios/SoloCompass/Services/LocationService.swift:111` 请求权限、`:138` 后台更新、`:155` 围栏；`Services/OverpassService.swift:62` 外部端点、`:383` 查询构造 |
| AI 服务商 | 原生 DeepSeek/OpenAI/custom 三种配置、默认 DeepSeek；草稿不声称所有请求到同一服务商，不承诺统一训练/保留规则 | `apps/ios/SoloCompass/Models/AIProvider.swift:4`；`Models/UserPreferences.swift:92`；`Views/Settings/AIProviderSettingsView.swift:13` |
| 语音 | 不保证完全离线；机器人音频确实交 OpenAI 转录 | `apps/ios/SoloCompass/Services/VoiceService.swift` 使用 Apple speech；`apps/bot/src/index.ts:147` 的转录请求；网页 `VoiceIntent.tsx` 使用浏览器 speech recognition |
| 附件与分享 | 主动提交、支持的功能范围、接收者可保留副本、URL 过期不等于文件删除；不将 AI 附件预览等同发送能力 | `apps/ios/SoloCompass/Services/ChatAttachmentService.swift:104` 上传、`:164` 签名 URL 有效期；存储上传与签名请求是不同操作 |
| 推送 | 条件披露设备/用户标识、token、发送者/对话/消息预览与锁屏影响 | `apps/ios/SoloCompass/Services/PushTokenService.swift:118`；`infra/supabase/functions/message-notify/index.ts:195` APNs payload |
| Telegram | 原始 Telegram ID 作为进程内 Map key、保存位置/最近 intent/推荐；分析哈希没有保证周期换盐；reset/重启和 optout 的进程边界明确 | `apps/bot/src/session.ts:13`；`apps/bot/src/index.ts:366`；`apps/bot/src/lib/anon-id.ts`；`apps/bot/src/lib/analytics.ts` 的内存 `Set` |
| 网页分析与 Cookie | `sc_anon` 的一年是具体 Cookie 配置寿命，草稿明确 Cookie 清除不删除服务器记录；PostHog 是配置启用、DNT/缺 key 跳过 | `apps/web/src/lib/anon-cookie.ts:10`、`:31`；`apps/web/src/lib/analytics.tsx:33`、`:43` |
| 诊断 | 有配置才启动 Sentry；没有把所有诊断/IP/请求上下文称作匿名 | `apps/ios/SoloCompass/Services/SentryService.swift:48`、`:69` |
| 重置与删除 | Forget me 是本地 memory snapshot/taste profile，不是删除云账号；Clear data 只按列出的本地数据处理；无统一 30/90 天删除承诺 | `apps/ios/SoloCompass/Services/MemoryDigestService.swift:130`；`Views/Settings/SettingsView.swift:522`、`:586` |
| 订阅与权益 | 不编造终身 SKU、无限 AI、固定价或必有试用；恢复购买按当前 Apple 账号和验证权益 | `apps/ios/SoloCompass/Services/SubscriptionService.swift:26` 月/年 SKU、`:328` 恢复购买 |
| 同行年龄 | 草稿说明 18+ 自述而非身份/年龄核验 | `apps/ios/SoloCompass/Views/Companion/CompanionSafetyConsentSheet.swift:148` 及对应 en/zh 资源 |
| 其他接收者 | 草稿列出当前路径使用的 OpenWeather、Amap/Foursquare、CARTO、Wikimedia/Wikidata、Tavily；均有“所用功能与配置”限定 | `Services/WeatherService.swift:208`；`Services/AmapPOIService.swift`；`Services/FoursquareService.swift`；`apps/web/src/lib/map-style.ts:16`；`Services/ExperienceImageService.swift:75`、`:134`；`infra/supabase/functions/tavily-search/index.ts` |

## 中英文一致性

已逐段对应隐私政策 5 节与用户协议 7 节。以下重要限制两种语言都有，没有出现一边承诺、一边免责的差异：

- 后台定位、外部 AI/地图/探索接收者、远程语音、APNs 预览、bot 原始 ID/无 TTL、附件 URL 与文件保留区别。
- 匿名会话仍是标识；没有全部匿名、始终只在本地、清空所有服务器数据、统一固定保留期限的承诺。
- 本地 Forget me/Clear data 的有限范围，系统备份/导出/接收者副本及平台安全存储生命周期区别。
- 当前展示和实际可用功能决定权益；预览不构成已上线/付费功能；删除应用或本地数据不取消订阅。
- Apple 标准 EULA 是条件引用，没有声称已在 App Store Connect 设置 Custom EULA；强制性权利保留。

## 官方引用核对

2026-10-16 使用只读网络工具打开三条官方链接，均得到相应正文：

- [Apple 订阅取消](https://support.apple.com/118428)：支持在 Apple 账号/设备订阅设置管理，不将删应用解释为取消订阅。
- [Apple 退款请求](https://support.apple.com/118223)：退款资格按具体情况和地区，草稿没有保证退款，也保留适用消费者权利。
- [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)：标准或明确提供的自定义许可适用；草稿采用条件表达，不把发布服务条款当作配置 Custom EULA 的证据。

以上只是引用与草稿含义核对，不推断该 App Store listing 当前使用哪个许可配置，也不替 Apple 作审核判断。

## 发现与发布后验收

| ID | 级别 / 状态 | 具体意见 |
| --- | --- | --- |
| LEGAL-P2-01 | P2 / 源码表述已修复 | 隐私政策 §3 中英现明确区分：认证令牌/部分标识可用 Keychain，用户配置的 AI 凭据也可保存于本地应用设置，生命周期不同。与 `UserPreferences.swift:577` 的 aiApiKey snapshot、`:599–600` 写 UserDefaults，以及 `SupabaseClient.swift:74`/`DeviceIdentityService.swift` 的 Keychain 路径一致。原来容易被理解为全部 AI key 使用平台安全存储的概括已移除。 |
| LEGAL-P2-02 | P2 / 已修复且公开读回 | Terms §4 中英政策名称已链接到正式隐私 Gist；隐私 Gist 顶部链接到正式协议。匿名 HTML 和公开 API 均包含互链，与本地正文一致。 |
| LEGAL-LIVE-01 | 公开目的地已验证；原生点击/发布待验 | 两个 Gist 匿名 HTTP200，正确标题、中英正文、邮箱、互链存在；公开 API 的 public=true、owner=kubbot、完整正文哈希与本地相等。原生首次同意/设置/购买入口源码已接入，但实际点击、正式二进制及 App Store Connect 线上配置尚未做。 |
| LEGAL-P2-03 | P2 源定义建议 / 已修复，实际热区未测 | 共用 LegalDocumentLinks 的两处44pt frame和contentShape现均位于Link标签内部，解决外层布局44不充分证明命中区域的问题。未运行VoiceOver、AXXXL或空白处点击。 |

“不出售个人信息/不作广告定向”“按所列目的保留”“处理联系请求”等属于运营者政策承诺；源码未发现对应售卖/广告路径，不足以验证全部经营行为或运营执行能力，不把这些承诺写成代码自动保证。

未进行：法律适用与充分性评估、律师审阅、账号后台及第三方服务真实配置核验、邮箱响应流程演练、生产删除请求演练、App Store Connect 元数据或 Custom EULA 配置确认。不能将源码事实相符总结为这些项已通过。

## 正式发布与入口增量复核（2026-10-16）

正式页面为 [隐私政策](https://gist.github.com/kubbot/e177b6ab042c8d5bd79417300031a5c9) 和 [用户协议](https://gist.github.com/kubbot/08f720b1191b6f9c913699c16227581a)。根代理永久证据是 `legal-gist-api-readback.json` 与 `legal-gist-public-readback.json`；reviewer 使用不带 Authorization/Cookie 的独立 urllib GET 重复核对：两页面 HTTP200、owner kubbot/public true、完整正文 SHA 与上表一致、本地全文相等、中英/邮箱/互链存在。web 阅读工具对新 Gist 返回工具级不可达；独立 HTTP/API 已确认可达，未据工具错误推断网站故障。

入口增量已检查：

- `Views/Onboarding/TermsConsentSheet.swift` 的 LegalDocuments 共用两条正式 URL；LegalDocumentLinks 是实际 Link，各标签内定义 minHeight44/contentShape；首次同意前可读全文。接受和拒绝状态逻辑未被此增量替换。
- `Views/Settings/SettingsView.swift` 的数据/关于区域与 `Views/Paywall/PaywallView.swift` 的购买相关动作后复用该组件，正文可重读，购买前也可到达。源码没有新增自动购买/授权/后台网络副作用。
- en/zh-Hans 的 terms.intro、location/chat/noContacts/noTrackers 五段摘要准确收窄为可能发送坐标/相关历史、所选服务商/Pro代理、选择照片及配置诊断；不再作全本地、不处理照片或全部匿名承诺。
- `apps/web/src/lib/legal.ts` 统一两 URL/用户指定邮箱；营销中英页脚、两种语言的隐私实现说明页使用正式 Gist。实现说明页保留摘要定位，没有伪装成完整政策。旧页面仍可导航访问，但不再用营销域名替代正式公开目的地。
- `apps/bot/src/index.ts` 的 `/privacy` 删除“转录后不保留/所有Sentry内容已剥离”等未经实现支持的保证，链接正式双语政策并说明进程内optout边界；`docs/PRIVACY.md` 和 `docs/APP_STORE_METADATA.md` 更新文档指向，不把本地元数据文件等同 App Store Connect 已保存。

构建与版本：根代理报告本批 generic Simulator Debug 构建 helper exit0，`snapshot-05-legal-files.json` 109/109源码SHA已独立核对，正式日志已读回BUILD SUCCEEDED，checkpoint已明确绑定44pt标签修正后的exec97139。未启动 Simulator，也没有新链接实际点击证据。旧03/04b/最终Web构建及交互证据仍仅绑定各自历史哈希，不能自动给此次法律增量授予运行通过。


### LEGAL-P1-02：提交说明保留过期事实（source_resolved）

`docs/APP_STORE_METADATA.md:176–184` 的 App Review submission 说明仍有 Anthropic、No PII/只传OSM tags与城市、无账号/无第三方SDK等陈述，不能继续作为当前可复制审核说明。TestFlight 段落`:154–168`还有固定7天试用、旧失效域和旧反馈邮箱。已要求根代理修正文档；没有证据说这些文本已保存到线上 App Store Connect。本问题不改变正式Gist正文的事实/双语复核结论。


增量关闭：metadata现已完整重写，Description中英、Beta与Reviewer notes相互一致，旧服务商/无账号SDK/仅OSM tags无PII/固定7天试用/旧反馈邮箱等陈述均移除。文件SHA `8e30b9fb8d3484e5d0246990e373fe883065da3007c10139803e58d1cbebc173`。现明确文档只是准备稿、不能证明线上配置已更新，也没有声称自定义EULA、年龄评级或账号删除已完成；与本轮源码事实一致，LEGAL-P1-02关闭。

05构建日志独立读回成功、解压SHA `ad3a23ed0f0fa56826842e08437e7edaa616b1b9756c99b40359c35aa158c759`；`checkpoint-05-legal.md`明确在label44修正后构建exec97139结束，再保存日志/109文件SHA清单。109/109文件指纹匹配；当前盘点918候选与218源码SHA匹配。Web/bot宿主检查正式日志现已核对exit0，见最终补记。没有将编译成功写成新iOS入口点击、VoiceOver、正式发布或法律合规通过。


## 最终选定验证结果

`checkpoint-05-legal-validation.json` 中5项均exit0：iOS generic Simulator Debug构建、localization、Web productionbuild、Web tsc、bot tsc；reviewer已逐份解压并核对SHA，全部一致。05补丁解压SHA `b84add54d199b027b0ac6ab669ffca94c7921c6abea81e087023a6a697075592`；109源码指纹和6法律文档指纹均匹配。原生构建绑定44pt标签修正后的版本；没有重标旧58/80/3例为本批测试。

本轮公开Gist及源码接入交付可关闭：正式政策/协议已live，源码入口、双语摘要、互链、邮箱和元数据准备文档一致，没有未解决确认P0/P1。新原生入口点击/VoiceOver/真实热区、App Store Connect线上字段、应用/网站/bot重发未验证；不声称法律合规、审核保证或每个控件96以上，也不再将URL/联系人列为缺失。
