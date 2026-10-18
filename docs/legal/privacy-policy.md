# Roamorrow Privacy Policy / 隐私政策

Effective / 生效日期: 2026-10-16

Operator / 运营者: Xinwei Xiong (cubxxw), maintainer of Roamorrow / Getyak · Roamorrow / Getyak 项目维护者

Private privacy and deletion requests / 隐私及删除请求邮箱: privacy@roamorrow.com

This policy covers the Roamorrow iOS app, website and optional Telegram bot operated by the project. Availability and processing depend on the feature, build and services you choose. The Chinese version follows the English version below; neither version limits rights provided by applicable law.

Related / 相关文档: [Terms of Service / 用户协议](https://roamorrow.com/terms)

## English

### 1. Information and purposes

| Feature                           | Information processed and purpose                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Accounts and sync                 | Account identifiers, sign-in information and records you choose to sync are handled by the configured backend, including Supabase, to authenticate you, sync features and operate conversations. Apple sign-in is optional where offered. An anonymous session is still an identifier; it does not make every record anonymous.                                                                                                                                                                                                                                                                                                                      |
| Location, maps and discovery      | With permission, device location helps show nearby experiences. If background location permission is granted and a relevant feature is enabled, location may also support visit detection and nearby nudges while the app is not visible. Selecting a city, dropping a pin or confirming exploration can send the selected coordinates, radius or city context to our backend, map, weather, exploration or AI service. Confirmed Overpass exploration sends coordinates and radius to OpenStreetMap/Overpass. Selected coordinates and travel context can be included in model requests. We do not promise that location stays only on your device. |
| Preferences, visits and memories  | Favorites, completions, preferences, visit records, notes, capsules, routes and personalization summaries may be stored locally. Records supported by enabled sync, sharing or messaging features may also be stored on the backend or shared as you request. Personalization summaries and relevant history can form part of an AI prompt.                                                                                                                                                                                                                                                                                                          |
| AI requests                       | Questions, submitted transcripts, selected experiences, coordinates, preferences and relevant conversation/history context are processed to generate recommendations, explanations or plans. Native provider settings support DeepSeek, OpenAI and a custom endpoint; the default native provider is DeepSeek. Pro requests may use the configured proxy. A custom endpoint receives requests under the provider you select. Avoid submitting information that is unnecessary for your request.                                                                                                                                                      |
| Voice                             | iOS voice input uses Apple speech recognition; website voice input uses the browser's speech service. Processing can use remote platform services and is not guaranteed to be entirely on-device. If you use bot voice input, the audio is sent to OpenAI transcription before the resulting text is used for recommendations. A submitted transcript can be sent to the applicable AI provider.                                                                                                                                                                                                                                                     |
| Photos, attachments and camera    | A photo picker, camera capture or QR scanner processes the content needed for that feature after the applicable permission or selection. Photos or attachments you choose to submit in supported features can be uploaded to the backend, sent with a companion conversation or used in your requested feature; an attachment preview is not a guarantee that a particular AI chat can send it. Chat attachment access links can expire without deleting the stored file. Choosing a photo is different from granting unrestricted access to your whole photo library.                                                                               |
| Companion and sharing             | Profile, visibility, route, invitation, message and attachment information is processed to support the companion features you choose. Where push notifications are enabled, the backend registers device/user identifiers and a push token, and can send a sender name, conversation identifier and message preview to Apple Push Notification service. A lock-screen preview may expose message content; manage notification permissions and previews in system settings. Content you send or publish is visible to the intended recipients or audience. People receiving shared content may keep their own copies.                                 |
| Telegram bot                      | Telegram user ID is used as the key of an in-memory session that can include the shared location, recent request/transcript and recommendation choices. Analytics hashes that ID with a configured salt; the source does not implement a guaranteed salt-rotation or session-expiry schedule. `/reset` clears the bot session; otherwise memory can remain until process restart. Telegram separately handles the messages you send to the bot.                                                                                                                                                                                                      |
| Purchases                         | Apple processes App Store payment and subscription information. The app uses StoreKit product, transaction and entitlement information to provide purchased access and restore purchases. We do not receive your full payment-card details through StoreKit.                                                                                                                                                                                                                                                                                                                                                                                         |
| Website storage and analytics     | The website uses a first-party HttpOnly `sc_anon` cookie, with a configured maximum age of one year, to associate completion history. Clearing the cookie does not delete records already stored on a server. When configured, PostHog can process product events and its own browser identifier. Current web analytics respects Do Not Track and is skipped when its project key is absent.                                                                                                                                                                                                                                                         |
| Diagnostics and network operation | Builds configured with Sentry can send crash/error diagnostics and associated technical context. Servers and third-party services receive technical request data such as IP address and device/browser or request information needed to deliver their services. We do not describe all diagnostics or network data as anonymous.                                                                                                                                                                                                                                                                                                                     |

We use this information to deliver the requested features, maintain and secure the service, troubleshoot failures and, where enabled, understand product usage. This policy does not authorize unrelated new collection. Platform permissions and feature-specific confirmations are requested by the relevant feature.

### 2. Service providers and other recipients

Depending on your selected feature and configuration, recipients include Apple (maps, speech, sign-in and purchases), Mapbox (web maps), OpenStreetMap/Overpass (exploration), OpenWeather (weather requests), AutoNavi/Amap and Foursquare (available place lookup integrations), CARTO (web raster map tiles), Wikimedia/Wikidata (requested imagery or reference data), Tavily (requested web searches), Supabase (authentication, storage, sync and conversations), DeepSeek/OpenAI or your selected custom AI service, Sentry (diagnostics), PostHog (web analytics), and Telegram for bot interactions. The bot uses OpenAI for voice transcription. A Pro proxy may route the requested AI processing through the configured provider.

These services process the data sent to them under their applicable terms and privacy policies, and may process data outside your country. The recipient and configuration matter: this policy does not promise that every provider has the same storage location, retention or model-training settings. Review a provider before selecting a custom endpoint. API credentials you supply are used to authenticate requests to that provider; do not share them in messages or screenshots.

This policy is published on Roamorrow's website, hosted by Vercel. Viewing it also involves Vercel's website hosting and privacy practices. We may disclose information when legally required or to protect users and the service, subject to applicable law. We do not sell personal information or use it for advertising targeting.

### 3. Retention and deletion

Local records remain until the relevant in-app deletion/reset, browser storage removal or device/app data removal. Operating-system backups and exported copies are separate. Server-side account, message, attachment, sync and diagnostic records can outlive a local reset. We retain personal data only for the purposes described here, including necessary security, dispute and legal requirements; actual retention depends on the record, enabled service and provider. We do not make an unsupported universal 30-day or 90-day deletion promise.

Bot requests and the most recent typed or transcribed intent can remain in the running bot session until reset or process restart; the application does not implement a guaranteed inactivity expiry. Authentication tokens and some identifiers can be held in platform secure storage such as Keychain. User-configured AI credentials can also be saved in local app settings. Their lifecycles can differ from ordinary app records.

The iOS **Forget me** action resets the local AI memory snapshot and taste profile. It is not a cloud-account deletion action and does not erase every visit, capsule, conversation or recipient's copy. **Clear data** resets its listed local experience/preference data; it must not be interpreted as deleting all backend accounts or messages. Exported files and data already shared with someone else require separate handling.

To request access, correction or deletion of account/backend personal data, email the private contact above. Include enough information to identify the relevant account or feature, but never a password, API key or identity document in an initial request. We may need to verify that the request concerns your information. Applicable legal retention exceptions and third-party copies may limit deletion; we will explain the applicable outcome. Deleting app data does not cancel an App Store subscription.

### 4. Your choices and rights

You can manage location, microphone, camera, speech and photo access in system/browser settings; type instead of using voice; disable optional companion features; choose which content to send/share; manage available sync/AI settings; export supported local records; and clear browser storage. The bot's `/reset` clears its in-memory session and `/optout` disables its product analytics for that user in the running bot process. A bot process restart resets these in-memory preferences; use the private contact for requests concerning stored server records.

Depending on the law applicable to you, you may have rights to access, correct, delete, restrict or object to processing, withdraw consent, or receive a portable copy, and complain to an appropriate authority. Use the private contact above to exercise applicable rights. Withdrawing a device permission stops future access covered by that permission; it does not automatically delete data already submitted to a service. Features depending on that permission may no longer work.

### 5. Security, children and changes

We use safeguards appropriate to the service, such as platform permission controls, authenticated connections and access restrictions. No system is completely secure. Do not include unnecessary sensitive information in public content, AI prompts or conversations.

Roamorrow is not designed as a children's service. A minor should use it only where legally permitted and with any required parent/guardian authorization. Companion features require a self-declaration that you are at least 18; this is not an identity or age verification service. Contact us if a child's information requires investigation or deletion; we do not claim that the app verifies the age of every user or companion.

We will date policy revisions and make material changes available with an appropriate notice or renewed consent where required. A change to this document alone is not permission to collect unrelated information.

---

## 中文

### 1. 处理的信息与用途

| 功能             | 处理的信息与用途                                                                                                                                                                                                                                                                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 账号与同步       | 配置的后端（包括 Supabase）处理账号标识、登录信息以及你选择同步的记录，用于身份验证、同步与对话功能。提供 Apple 登录的场景可由你选择使用。匿名会话仍包含标识，不意味着所有记录均已匿名化。                                                                                                                                                                                |
| 位置、地图与探索 | 获得权限后，设备位置用于展示附近体验；若授予后台定位权限并启用相关功能，应用不可见时也可能使用位置进行到访检测与附近提示。选择城市、地图选点或确认探索，可能将选定坐标、半径或城市上下文发送至后端、地图、天气、探索或 AI 服务。确认 Overpass 探索后，坐标和半径会发送至 OpenStreetMap/Overpass；模型请求也可能包含选定坐标与旅行上下文。我们不承诺位置始终只留在设备上。 |
| 偏好、到访与记忆 | 收藏、完成记录、偏好、到访、笔记、胶囊、路线和个性化摘要可保存在本地。启用同步、分享或消息功能时，其支持的记录也可能保存在后端或按你的操作分享。个性化摘要和相关历史可能成为 AI 提示的一部分。                                                                                                                                                                            |
| AI 请求          | 问题、提交的转录文字、选定体验、坐标、偏好及相关对话/历史上下文，用于生成推荐、解释或计划。原生设置支持 DeepSeek、OpenAI 与自定义端点，默认原生服务商为 DeepSeek；Pro 请求可通过配置的代理处理。自定义端点按你选择的服务接收请求。请勿提交与当前请求无关的信息。                                                                                                          |
| 语音             | iOS 使用 Apple 语音识别，网页使用浏览器语音服务，处理可能涉及平台远程服务，并非保证完全在设备本地完成。机器人语音会先发送至 OpenAI 转录，再将结果用于推荐。提交的转录文字可能继续发送至相应 AI 服务商。                                                                                                                                                                   |
| 照片、附件与相机 | 照片选择器、拍摄或二维码扫描在相应授权或选择后处理该功能需要的内容。支持相关提交的功能可将你主动选择的照片或附件上传后端、发送至同行对话或用于所选功能；附件预览不表示每个 AI 对话都支持发送。聊天附件访问链接过期不等于存储文件已删除。选择一张照片并不等于向应用授予整个照片库的无限访问权。                                                                            |
| 同行与分享       | 个人资料、可见性、路线、邀请、消息与附件信息用于你选择的同行功能。启用推送通知时，后端登记设备/用户标识与推送令牌，并可能将发送者名称、对话标识与消息预览发送至 Apple 推送通知服务；锁屏预览可能展示消息内容，可在系统设置管理通知权限和预览。发送或发布的内容会向对应接收者或受众展示；接收者可能自行保留副本。                                                          |
| Telegram 机器人  | Telegram 用户 ID 用作内存会话的键，会话可包含分享的位置、最近的问题/转录文字和推荐选择。分析事件对该 ID 使用配置的盐值进行哈希；源码没有保证定期换盐或会话过期的机制。`/reset` 清除机器人会话，否则相关内存可保留至进程重启。发给机器人的消息还由 Telegram 单独处理。                                                                                                     |
| 购买             | Apple 处理 App Store 付款和订阅信息。应用通过 StoreKit 商品、交易与权益信息提供购买的访问权限和恢复购买；通过 StoreKit，我们不会收到完整银行卡信息。                                                                                                                                                                                                                      |
| 网页存储与分析   | 网页使用第一方 HttpOnly `sc_anon` Cookie 关联完成记录，配置的最长有效期为一年。清除 Cookie 不会删除服务器已保存的记录。配置启用时，PostHog 可处理产品事件并保存其浏览器标识；当前网页分析尊重 Do Not Track，缺少项目密钥时跳过分析。                                                                                                                                      |
| 诊断与网络运行   | 配置了 Sentry 的版本可发送崩溃、错误及相关技术上下文。服务器和第三方服务为提供服务会接收 IP 地址、设备/浏览器或请求信息等技术数据。我们不会将所有诊断或网络数据都称为匿名数据。                                                                                                                                                                                           |

这些信息用于提供你请求的功能、维护与保护服务、排查故障，以及在启用时了解产品使用情况。本政策并不授权无关的新采集；相关功能会请求平台权限或提供该功能的确认步骤。

### 2. 服务商及其他接收者

根据所用功能与配置，接收者包括 Apple（地图、语音、登录和购买）、Mapbox（网页地图）、OpenStreetMap/Overpass（探索）、OpenWeather（天气请求）、高德 AutoNavi/Amap 与 Foursquare（可用的地点查询集成）、CARTO（网页栅格地图瓦片）、Wikimedia/Wikidata（所请求的图片或参考数据）、Tavily（所请求的网页搜索）、Supabase（认证、存储、同步和对话）、DeepSeek/OpenAI 或你选择的自定义 AI 服务、Sentry（诊断）、PostHog（网页分析），以及机器人使用的 Telegram。机器人语音转录使用 OpenAI；Pro 代理可将请求交给配置的 AI 服务商。

这些服务按各自适用的条款与隐私政策处理收到的数据，处理地点可能位于你所在国家之外。具体服务商及配置会影响存储位置、保留期限与模型训练设置，我们不承诺各服务完全相同。使用自定义端点前应核对其服务规则。你提供的 API 凭据用于向相应服务认证请求，请勿通过消息或截图分享凭据。

本政策发布于 Roamorrow 官网，由 Vercel 提供网站托管；访问此页也涉及 Vercel 的托管服务及其隐私规则。在法律要求或保护用户及服务所需时，我们可能依法披露信息。我们不出售个人信息，也不将其用于广告定向。

### 3. 保存与删除

本地记录会保留至相关应用内删除/重置、浏览器存储清除或设备/应用数据移除；系统备份和导出的副本另行管理。服务器上的账号、消息、附件、同步和诊断记录可能在本地重置后继续存在。我们仅为本政策所列目的及必要的安全、争议处理和法律要求保留个人数据，具体取决于记录类型、启用的服务与服务商；我们不会作出无实现依据的统一“30 天”或“90 天”删除承诺。

机器人请求及最近的输入/转录意图可保留在运行中的机器人会话内，直至重置或进程重启；应用未实现保证闲置过期的机制。认证令牌和部分标识可保存在 Keychain 等平台安全存储；用户配置的 AI 凭据也可能保存在本地应用设置中，其生命周期可能不同于普通应用记录。

iOS 的**忘记我**操作会重置本地 AI 记忆快照与口味档案，不等于注销云端账号，也不会删除全部到访、胶囊、对话或接收者副本。**清除数据**只重置该功能列明的本地体验/偏好数据，不能理解为删除全部后端账号与消息。导出文件和已分享给他人的内容需单独处理。

如需访问、更正或删除账号/后端个人数据，请通过顶部私密联系邮箱提出请求。提供足以定位相关账号或功能的信息即可，初次请求不要附上密码、API 密钥或身份证件。我们可能需要核实请求是否涉及你的信息；法律保留要求与第三方副本可能限制删除，我们会说明适用结果。删除应用数据不会取消 App Store 订阅。

### 4. 选择与权利

你可以在系统/浏览器设置管理定位、麦克风、相机、语音和照片权限；使用文字代替语音；关闭可选同行功能；选择提交和分享的内容；管理可用的同步/AI 设置；导出支持的本地记录；清除浏览器存储。机器人的 `/reset` 清除进程内会话，`/optout` 关闭该用户在当前机器人进程中的产品分析。进程重启会重置这些内存偏好；涉及服务器存储记录的请求请使用顶部私密联系邮箱。

根据适用法律，你可能享有访问、更正、删除、限制或反对处理、撤回同意、获取可携带副本，以及向相关主管机构投诉等权利，可通过顶部邮箱提出。撤回设备权限可停止该权限覆盖的后续访问，不会自动删除此前已提交至服务的数据；依赖该权限的功能可能不可用。

### 5. 安全、未成年人及更新

我们使用与服务相适应的保护措施，包括平台权限、经认证的连接和访问限制；任何系统都无法保证绝对安全。请勿在公开内容、AI 问题或对话中提交不必要的敏感信息。

Roamorrow 并非面向儿童设计的服务。未成年人仅应在法律允许并取得必要监护授权时使用。同行功能要求自行声明已满 18 周岁，这不等于身份或年龄核验。如需调查或删除儿童信息，请联系我们；我们不声称应用会核验每位用户或同行者的年龄。

我们会标注政策修订日期，并在有要求时以适当方式提示重大变更或重新征求同意。仅修改本文并不构成采集无关信息的授权。
