# 隐私与用户协议：当前源码数据处理事实审计

审计时间：2026-10-16 01:49 UTC。审计对象为本任务 integration worktree 的**当前工作树**，HEAD 为 `924f09a4ea7e3ed9b016ed9a956705a7e576cd5e`，包含尚未提交的功能与交互修订；不是该提交的纯净快照。行号对应审计时文件。

本报告仅核对实现事实，供中英隐私政策及用户协议准确表述使用。未访问生产后台、供应商控制台、真实用户数据、私密凭据或环境变量值；未运行网络请求或验收远端删除。源码存在不等于已在正式版本启用；注释、旧政策、产品页面、测试夹具不能代替实际实现或部署证据。`unknown` 表示本次源码审计无法证明，不能据此承诺具体期限、所在地、供应商训练设置或删除结果。

## 1. 发布前最关键的结论

1. **不能宣称全部位置、记忆、偏好或聊天只留在设备。** iOS `ContextManager.snapshot()` 将原始经纬度、视野范围和偏好序列化进上下文；聊天编排器把上下文及记忆摘要放进模型系统提示。Web/bot 推荐提示也含输入坐标及用户意图。四位小数的自然语言位置行不代表 JSON 中的位置经过同样量化。
2. **不能把“忘记我”“清除数据”“退出”写成云端注销或全部删除。** 当前“忘记我”只删除两个本地模型；“清除数据”删除另一组本地表。未发现面向用户的服务端账号删除入口或生产删除函数。数据库 `ON DELETE CASCADE` 只描述父记录真正删除后的行为，不能证明用户能触发它，也不能证明 Storage 文件、日志或备份已删。
3. **不能承诺统一 30/90 天、24 小时会话清除、固定换盐。** bot 内存会话没有 TTL；转录结果保留在 `lastIntent`；哈希盐没有自动轮换。PostHog、Sentry、数据库、Storage、平台日志及备份的服务端保留配置未检查。
4. **第三方清单须按真实请求补齐。** 除 Apple、Mapbox、Supabase、DeepSeek/OpenAI、Sentry、PostHog、Telegram，还存在 CARTO 瓦片、Overpass、高德、Foursquare、OpenWeather、Wikidata/Wikimedia、Tavily，以及用户选择的外部地图/分享目标。当前天气实现不是 Open-Meteo，逆地理实现不是 Nominatim。
5. **诊断和随机标识不能统一称为匿名数据。** iOS 有稳定 Keychain 设备 ID、Supabase 用户与会话；Web 有 `sc_anon` Cookie 和独立 PostHog 浏览器标识；bot 使用原始 Telegram ID 作内存键。iOS Sentry 没有通用 `beforeSend` 清除器；bot 入口没有接入另一个文件里的清除钩子。
6. **同行是 18+ 自我声明，非年龄核验。** 存在年龄勾选与同意时间，但未发现证件核验、出生日期核验或全应用统一年龄验证。

## 2. 启用条件与账号标识

| 范围 | 可证事实及实现边界 | 源码依据 |
| --- | --- | --- |
| 功能开关 | 发布用 plist 中 `FF_BACKEND_SYNC`、`FF_ROUTE_AI_THROUGH_EDGE`、`FF_COMPANION` 为 false，深度探索为 true；运行时有环境/开发覆盖入口。DEBUG 的 companion 默认 true。当前实际安装包及线上开关值未检查，不能据默认值写“从不上传”，也不能说所有远端功能默认运行。 | `apps/ios/SoloCompass/Resources/FeatureFlags.plist:5`；`Services/FeatureFlags.swift:93`、`:255`（本节 Swift Services 均在 `apps/ios/SoloCompass/` 下） |
| iOS 设备 | 第一次访问生成随机 UUID；保存于 Keychain，以后复用。Keychain 项使用 `AfterFirstUnlockThisDeviceOnly`；应用数据清除并未证明会删除此项。请求辅助方法可附加 `X-Device-ID`。 | `Services/DeviceIdentityService.swift:33`、`:95`、`:114` |
| iOS 后端账号 | 开启后端时可创建 Supabase anonymous auth 用户；Keychain 保存用户 ID 及包含 access/refresh token 的会话。匿名会话仍可关联稳定账号记录。 | `Services/DeviceIdentityService.swift:56`；`Services/SupabaseClient.swift:62`、`:73`、`:81`、`:122` |
| Apple 登录 | 请求 `requestedScopes = []`，此实现不主动请求姓名/邮箱；将 Apple identity token 和 nonce 交给 Supabase 关联身份。不能据此承诺后台不处理任何账号标识。 | `Services/AppleSignInService.swift:61`、`:82`；`Services/SupabaseClient.swift:229` |
| Web 完成记录身份 | `sc_anon` 为服务器生成 UUID Cookie，HttpOnly、SameSite=Lax、production Secure、Path=/、maxAge=365天。首次写入完成记录时使用；不是旧文档描述的 localStorage UUID。 | `apps/web/src/lib/anon-cookie.ts:10`、`:23`、`:31`；`src/app/api/experiences/[id]/checkin/route.ts` |
| Web 数据库身份 | 服务端用 Cookie 前12字符构成 `anon_…` handle，upsert `users`，再关联 `completions`；完成记录含体验、评分及数据库时间字段。清除 Cookie 不会调用数据库删除。 | `packages/data/src/completions-repo.ts:42`、`:55`、`:89` |
| Web 已实现认证 API | 工作会话和路线编排要求 Bearer token，并调用 Supabase `auth.getUser`。当前 Web 页面未找到这两个 API 的调用方，须标成“已实现后端路径”，不能把它们描述为当前所有访客必经流程。 | `apps/web/src/lib/repos.ts:80`；`src/app/api/work-sessions/route.ts:57`；`src/app/api/routes/compile/route.ts:123` |
| bot | Telegram 直接向 bot 发送 update；bot 用原始数值用户 ID 作为进程内 Map key，session 存位置、最近意图、推荐 ID。分析用 salted SHA256 截短哈希，属于可持续关联的标识，不能等同不可识别。 | `apps/bot/src/session.ts:5`、`:13`；`src/lib/anon-id.ts:10`；`src/index.ts:366` |
| 内部测试邮箱 | 高级设置存在邮箱输入，交给本地 allow-list 检查以解锁测试权益，成功保存解锁状态。未读取 allow-list 内容；此入口不足以写成普通用户邮箱注册，也说明“应用绝不处理邮箱输入”过度绝对。 | `Views/Settings/SettingsView.swift:763`；`Services/SubscriptionService.swift:348` |

> 上表及以下省略前缀的 `Services/`、`Views/`、`Persistence/`、`Models/` 路径均相对于 `apps/ios/SoloCompass/`。Web `src/` 相对于 `apps/web/`；bot `src/` 相对于 `apps/bot/`。

## 3. 位置、地图、搜索与实际网络接收者

| 接收者 / 路径 | 发送或处理的信息 | 条件与准确边界 | 源码依据 |
| --- | --- | --- | --- |
| Apple Core Location | 设备位置、方向、系统授权状态；地图、距离与地理围栏使用这些值。 | `WhenInUse` 获准后再次请求时存在 `Always` 升级；Always 路径允许后台位置更新。不能全局承诺“仅前台定位”。是否实际授予由用户系统权限决定。 | `Services/LocationService.swift:97`、`:111`、`:132`、`:138` |
| 本地到访检测 | 体验围栏进入/退出、停留时长、访问时间、可选当前坐标快照保存在 `VisitRecord`。 | 到访计时器在 app 进入后台时清空，区别于 LocationService 可以后台更新/围栏唤醒；本地记录无统一自动过期实现。 | `Services/VisitTrackingService.swift:146`、`:178`、`:186`；`Persistence/Models/VisitRecord.swift:22` |
| Apple MapKit / CLGeocoder | 地图视野/POI搜索中心与区域、地名自然语言查询、逆地理坐标；地图快照亦通过 MapKit。 | 这是平台地图/搜索功能，源码无法证明平台内部仅本地处理或保留多久。 | `Services/MapKitPOIService.swift:45`、`:104`；`Services/LocationSearchService.swift:18`；`Services/ReverseGeocodeService.swift:46`；`Services/MarkdownExporter.swift:113` |
| Overpass 公共实例 | `overpass-api.de/api/interpreter`，POST 中的 Overpass QL 带中心经纬度、半径和类别条件。 | 位置可以是用户位置或选中的探索中心；不是仅发送城市名。 | `Services/OverpassService.swift:62`、`:138`、`:150`、`:381` |
| 高德 / AutoNavi | `restapi.amap.com/v5/place/around`，发送转换后的 GCJ-02 中心坐标（请求格式6位小数）、半径、类别与分页。 | 中国区域/数据源策略及配置可影响是否启用；不能从返回 POI 缓存未保留高德原始字段推断请求未发送位置。 | `Services/AmapPOIService.swift:236`、`:362`、`:366` |
| Foursquare | `api.foursquare.com/v3/places/search`，query `ll=lat,lon`、radius、类别、limit；Authorization API key。 | 无 key 或数据源策略可阻止调用。密钥值未读取。 | `Services/FoursquareService.swift:47`、`:84`、`:102` |
| OpenWeather | `api.openweathermap.org/data/2.5/weather`，原坐标 lat/lon、单位、API key。 | 本地 cache key 四舍五入至2位不意味着实际网络坐标被量化；实际 URL 使用原始 `coord`。当前生产源未发现 Open-Meteo 请求。 | `Services/WeatherService.swift:196`、`:207` |
| Mapbox + CARTO（Web） | Mapbox GL 初始化及 glyph URL；CARTO `a/b/c.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png` 按视野取瓦片。 | 瓦片索引可反映地图浏览区域，服务方也接收连接元数据。地图 token 不可用时降级；不能只列 Mapbox 而漏掉实际瓦片 CDN。 | `apps/web/src/components/MapView.tsx:80`；`src/lib/map-style.ts:11`、`:16` |
| Web 原生定位 → 自有 API | 用户触发 `navigator.geolocation.getCurrentPosition`；地图中心经纬度、radius、intent、timeZone 放进 GET `/api/experiences/nearby?...`。 | 缓存键的 quantise 不会量化 `fetchNearby` 实际发送的 center；URL可能出现在服务器/平台日志中，其日志配置 unknown。 | `src/components/MapView.tsx:149`；`src/lib/use-nearby.ts:30`、`:45` |
| 自有附近 API → 数据库/AI | 经纬度查附近数据库；有意图时传给共享推荐模型；无意图走本地排序（相对于服务端进程，不代表浏览器离线）。也可能按搜索中心生成覆盖刷新任务。 | 未证明每次都调用 AI；缺配置/失败可降级。 | `src/app/api/experiences/nearby/route.ts:114`、`:141`、`:160`、`:169` |
| Tavily | iOS agent web search 把自然语言 query、topic、days 交给 Supabase `tavily-search`；函数转发 `api.tavily.com/search`。城市简报编译也使用 Tavily。 | 查询可能含用户请求中的地点/偏好；不是本地搜索。后端配置、授权及配额决定是否运行。 | `Services/WebSearchService.swift:75`、`:85`；`infra/supabase/functions/tavily-search/index.ts:29`、`:105`、`:124`；`functions/compile-city-brief/index.ts:50` |
| Wikidata / Wikimedia / 图片主机 | Wikidata QID JSON 查询；Commons FilePath 缩略图；OSM `image` tag 中通过校验的外部 HTTPS URL 可被显示。 | 这些不是用户相册上传，而是外部媒体请求；具体图片主机取决于 POI 数据。不能把显示远端图片描述成纯本地素材。 | `Services/ExperienceImageService.swift:39`、`:75`、`:108`、`:134`；`Views/Experience/ExperienceDetailView.swift:405` |
| 外部导航与分享目标 | 用户选择后交给 Apple Maps、Google Maps 或高德目的地经纬度/名称；Notion web clipper URL可带导出标题；系统分享可交给所选应用。 | 选择外部 app 后由该 app处理，不能承诺 Solo Compass 能撤回对方副本。 | `Services/NavigationLauncher.swift:64`、`:96`；`Services/MarkdownExporter.swift:124` |
| Valhalla（已实现 API） | 认证路线编排将出发点和候选体验坐标、交通模式、出发时间交给配置的 `VALHALLA_URL`；缓存结果与用户ID关联。 | 当前网页未发现调用方；运行部署及接收者运营方 unknown。不能称默认所有地图用户会使用它。 | `src/app/api/routes/compile/route.ts:214`、`:232` |
| traffic endpoint（已实现 API） | POST接收 experienceId、lng、lat；读取IP/UA并以 `SHA256(ip:ua:experienceId)`生成关联标识，表内存experienceId、hash、pinged_at。 | 当前 Web UI 未发现 `/api/traffic` 调用；不能说它已对所有访客运行。无secret salt；“绝不指纹化/不处理IP”不适合覆盖该路径。7天统计/60天新鲜度不是删除期限。 | `src/app/api/traffic/route.ts:26`、`:33`、`:62`、`:95`、`:121` |

本次在生产应用服务、Web库及共享包中检索未发现 Nominatim 或 Open-Meteo 的实际请求实现。这里的“未发现”仅指审计范围源码，不能证明部署侧或第三方内部没有其他子处理者。

## 4. AI 与语音

| 路径 | 可证事实 | 不可外推的承诺 | 源码依据 |
| --- | --- | --- | --- |
| iOS 模型服务 | 原生支持 DeepSeek、OpenAI、自定义 base URL/model；AIService 将 messages、tool calls/tool results及工具定义等序列化，POST `/chat/completions`。 | 不能说所有请求都只到一种供应商；不能说XML包装实现匿名化。API key以Authorization认证请求，不等于可承诺任何配置下永不离开设备。 | `Models/AIProvider.swift:27`；`Services/AIService.swift:434`、`:566`、`:624`、`:840` |
| iOS 上下文 | `ContextManager` 将原始 `[lon,lat]`、viewportBBox、前20 POI ID、旅行风格、类别偏好、最大距离和当前时间写JSON。编排器把JSON、AgentMemorySnapshot摘要和近期聊天摘要插入模型提示。 | 不能写“只发四位小数粗定位”“记忆摘要从不上传”“所有偏好仅设备处理”。四位小数提示行之外仍有原始坐标JSON。 | `Services/Context/ContextManager.swift:115`、`:125`、`:138`、`:147`；`Services/VoiceAgentOrchestrator.swift:1204`、`:1220`、`:1248`、`:1465` |
| Pro 代理 | 当 routeAIThroughEdge && backendSync && Pro 且能构建已登录请求，走 Supabase `chat-proxy`；不能构建代理请求时回退直接供应商路径。 | 不能承诺“Pro内容不经过Supabase”或“所有Pro请求必经代理”。 | `Services/AIService.swift:812`、`:834` |
| chat-proxy 服务端 | 验证Supabase JWT、读订阅权限、接收messages、转发DeepSeek；写 `sc_function_calls` 的 user_id/function_name，called_at由表默认值产生。当前代码未显式把完整prompt写业务表。 | 未写业务表不等于平台/模型提供商无日志或零保留；调用记录无已证自动删除期限。 | `infra/supabase/functions/chat-proxy/index.ts:67`、`:83`、`:123`、`:137`；`infra/supabase/migrations/0001_init.sql:122` |
| Web/bot 推荐 | 共享 `rankExperiences` 明确把完整输入坐标、用户意图、当前当地小时和最近约20候选摘要写入prompt，默认使用DeepSeek兼容API；无key/失败可降级。 | 旧文档中的“bot→Claude”已不符合当前默认实现；不能只披露转录供应商OpenAI而漏掉推荐供应商。 | `packages/ai/src/prompts/rank-experiences.ts:117`、`:127`；`packages/ai/src/client.ts:19`、`:72` |
| iOS 语音 | 先请求Apple speech授权再请求麦克风；AVAudioEngine将buffer交给SFSpeechRecognizer，支持中间转录。未设置 `requiresOnDeviceRecognition=true`。 | 源码不能证明每次识别在云端，但也不能保证全程本机或不经Apple远程服务。提交后转录可作为聊天内容发模型，并写本地聊天历史。 | `Services/VoiceService.swift:21`、`:101`、`:124`、`:172`；`Persistence/ChatHistoryStore.swift` |
| Web 语音 | 浏览器 SpeechRecognition/webkitSpeechRecognition；识别结果作为意图交给Web查询。卸载/pagehide/取消会终止本页recognition。 | 浏览器服务的具体接收方、区域、原音频保留由浏览器实现/配置决定，源码unknown；停止识别不删除此前已发的内容。 | `src/components/VoiceIntent.tsx:35`、`:69`、`:197`；`src/lib/use-nearby.ts:35` |
| bot 语音 | 从Telegram取语音文件到进程buffer，用OpenAI `whisper-1`转录，无显式本地磁盘写入；finally将一个buffer变量设null。结果进入 `session.lastIntent` 并发推荐。 | 不能把一个变量置null描述为所有内存物理擦除；不能承诺Telegram/OpenAI不保留；“回复后转录立即清除”与session实现矛盾。 | `apps/bot/src/index.ts:132`、`:147`、`:153`、`:366`；`src/session.ts:13` |

## 5. 照片、聊天、同行与通知

| 功能 | 当前事实、范围和接收者 | 源码依据 |
| --- | --- | --- |
| Vibe onboarding照片 | 用户选图后读取图片Data并转JPEG；`generateTasteProfile`当前只用照片数量、风格、freeform vibe生成确定性embedding/描述，不调用图像模型或上传此步骤的原照片；保存的 sourceVibePhotosBlob 是重复的 `vibe_photo` 占位字符串，不是真正照片ID。此结论只覆盖此入口。 | `Views/Onboarding/OnboardingVibeStep.swift:161`、`:178`、`:209`；`Services/AIService.swift:2116` |
| 自建地点照片 | JPEG写Application Support/UserPlacePhotos，返回file URL供体验photoUrls使用；自建体验的同步payload会包含photo_urls字段。当前这条路径未发现将原图字节上传Storage的实现。 | `Services/PlacePhotoStore.swift:12`、`:33`；`Persistence/ExperienceRepository.swift:287`、`:311` |
| AI聊天附件 | 当前 agent pipeline 接受文本；存在暂存附件时显示不支持并阻止该次发送。不能把附件预览写成已支持图像模型处理。 | `Views/Chat/ChatSheet.swift:1626` 的 `workspace.attachments.isEmpty` 守卫 |
| 同行私信 | 功能启用且有session时，正文、senderId、conversationId、时间及附件metadata写Supabase `chat_messages`；Realtime接收后显示，可见对象为会话参与者/后端处理者。 | `Services/ChatService.swift:94`、`:148`、`:162`、`:268`；`infra/supabase/migrations/0003_companion.sql:216` |
| 同行附件文件 | `local.data`原始字节POST Supabase Storage `chat-media`；文件路径含conversationId/messageId/UUID/fileName。metadata含类型、文件名、MIME、字节数及图片尺寸。上传某项失败后清空消息metadata数组，并没有看到回滚删除此前已成功上传对象。 | `Services/ChatAttachmentService.swift:105`、`:116`、`:128`、`:137`；`Services/ChatService.swift:123`、`:137` |
| 附件访问控制 | migration将 `chat-media` bucket设为private并按conversation participant限制读写；客户端签名URL请求expiresIn=3600。 | `infra/supabase/migrations/0005_chat_attachments.sql:31`、`:43`；`Services/ChatAttachmentService.swift:152`、`:164` |
| 附件保留 | 签名URL一小时到期仅说明链接有效期，未发现对象自动一小时删除；私有bucket也不是端到端加密。服务商管理员/业务服务访问和备份策略unknown。 | 同上；本次检索Storage删除/定时清理未发现相应生产路径 |
| 同行资料 | profile编辑器把显示名、emoji、bio、languages等存UserPreferences；后端有companion_profiles并被发现/好友路径读取。该编辑器本身未找到提交远端profile的调用，不能笼统把其每次编辑都描述为已同步。 | `Views/Companion/CompanionProfileView.swift:157`、`:202`；`Models/UserPreferences.swift:387`；`Services/FriendService.swift:857`；`infra/supabase/migrations/0003_companion.sql:57` |
| 社交关系及安全处理 | 好友请求、好友关系、会话、同行请求、举报与屏蔽存在远端表/写入；内容可包括对方账号ID、关系状态、备注、原因和详情。旧政策“无好友邀请/无社交图谱”不再成立。 | `Services/FriendService.swift:159`、`:265`、`:341`、`:600`；`Services/CompanionService.swift:246`、`:394`、`:436` |
| Nearby presence | 显式enable后以约5分钟循环，将userId、geohash6、expires_at等写companion_posts，附近位置这条路径只传geohash6；disable/进后台停止并尝试删除远端post，失败可留行。 | `Services/PresenceService.swift:51`、`:87`、`:100`、`:123` |
| Presence到期 | expires_at设为当前时间+2小时，表查询/发现可按到期排除；客户端另有清理方法，但本次未找到对 `cleanupExpiredPosts/cleanupStaleRequests` 的生产调用。不能承诺“2小时必然硬删除”。 | `Services/PresenceService.swift:93`；`Services/CompanionService.swift:464`、`:485` |
| 推送注册 | 请求通知授权并登记APNs；后端开关开启且有userId时将deviceID、userId、token、platform、更新时间写Supabase device_push_tokens；存在invalidate删除尝试，部署状态未验。 | `Services/PushTokenService.swift:118`、`:122`、`:136` |
| 消息推送接收者 | message-notify从后端读取消息，取最多140字符预览（超长前139字符+省略号），将senderHandle、conversationId和preview发Apple APNs，锁屏可显示该内容。截断不是敏感数据清除。好友通知也发送请求者handle/emoji。 | `infra/supabase/functions/message-notify/index.ts:52`、`:160`、`:195`、`:213`；`functions/friend-request-notify/index.ts:113`、`:163` |
| 胶囊与分享副本 | TimeCapsule本地可存文字/语音/照片blob与context；开启只改opened=true并保留记录。系统导出/分享后外部app和接收者可留副本。 | `Persistence/Models/TimeCapsule.swift:26`；`Services/CapsuleStore.swift:167`；`Views/Settings/SettingsView.swift:549` |

## 6. 本地存储、同步、购买与分析诊断

| 类别 | 已证实现 | 期限与未知边界 |
| --- | --- | --- |
| iOS SwiftData | 持久ModelContainer磁盘store；体验、完成、收藏、聊天session/messages、路线、笔记、到访、味觉profile、记忆、胶囊、同步outbox等模型。`Persistence/SoloCompassModelContainer.swift:338`、`:348`。 | 无统一TTL。未核对设备备份配置、系统回收行为或磁盘加密/备份服务端副本；不能写“删除后所有备份不可恢复”。 |
| UserDefaults/Keychain/文件 | UserPreferences持久化偏好；Keychain存设备ID/登录session/权益等；文件目录保存自建地点照片。 | 删除本地数据库不自动覆盖UserDefaults、Keychain、照片目录、系统备份。 |
| 同步outbox | `SyncService.enqueue`将payload写PendingSyncRecord，flush/pull仅backendSync开启执行；约30秒前台循环。支持完成、收藏、自建体验、订阅、同行路线等表。`Services/SyncService.swift:99`、`:117`、`:159`、`:259`；`Persistence/ExperienceRepository.swift:293`、`:330`、`:385`。 | 关闭同步不意味着之前的服务器记录被删。已入队历史记录以后开启可能发送；失败超过10次的队列行会丢弃并发诊断，属于队列重试规则，不是个人数据保留天数。 |
| 订阅/购买 | StoreKit请求商品、购买/恢复及监听交易；Keychain缓存权益。backendSync开启时订阅事件带user_id、device_id、product_id、购买/到期时间、trial状态入队。`Services/SubscriptionService.swift:302`、`:429`。 | 无完整银行卡采集路径；Apple处理付款。应用数据删除不等于订阅取消。购买服务商/账务法定保留须按实际配置表述，源码unknown。 |
| Web浏览器状态 | React Query默认staleTime60秒、gcTime5分钟；内存查询缓存含查询意图等。Banner dismiss用sessionStorage；交互preview打卡为内存演示状态。`src/lib/query-client.tsx:12`；`src/lib/use-nearby.ts:48`。 | 缓存回收不是服务器日志/业务数据删除；preview演示不等于真实账号记录。 |
| iOS产品分析 | 当前AnalyticsService为本地内存+UserDefaults最多500事件，默认enabled=true；设为false清空buffer和持久key；此服务未实现远端uploader。`Services/AnalyticsService.swift:26`、`:31`、`:54`。 | `.string(String)`并不能在类型层证明永远无用户信息；不能据注释保证所有未来调用绝不含文本。该产品分析与Sentry诊断是不同路径。 |
| Web PostHog | 有项目key且未DNT时初始化；localStorage persistence、autocapture=false、disable_session_recording=true、respect_dnt=true。显式事件为pageview、marker/sheet、intent长度及voice/text来源、checkin体验ID/是否评分。`src/lib/analytics.tsx:33`、`:56`。 | SDK默认技术属性/服务商IP处理及控制台retention未验证。未找到旧政策 `solo_compass_optout=1` 开关读取或footer切换实现；不能承诺可用。 |
| bot PostHog | 原始Telegram ID经固定盐SHA256截短后作为distinct_id；开关关闭时可stdout记录事件字段；optOut set在进程内。`apps/bot/src/lib/anon-id.ts:10`；`src/lib/analytics.ts:33`、`:49`。 | 无自动30天轮换、90天删除。重启丢失optout set；`/start`没有移除set，旧提示“/start恢复”不能当已实现保证。 |
| iOS Sentry | 非空DSN才启动；sendDefaultPii=false；20% trace采样，启用性能、hang、网络breadcrumb及页面追踪；capture允许上下文字典。没有通用beforeSend过滤器。`Services/SentryService.swift:48`、`:61`、`:79`、`:103`。 | `sendDefaultPii=false`不是所有手工上下文、错误文字、URL和breadcrumb清除保证；30天保留、匿名及关闭界面均未证明。 |
| Web Sentry | 配置DSN才启动；10% trace采样、sendDefaultPii=false，接入scrubSentryEvent；过滤列出的user、request和extra字段。`apps/web/instrumentation-client.ts`、`sentry.server.config.ts`、`sentry.edge.config.ts`；`src/lib/sentry.ts:4`。 | 不是递归清除所有exception内容/breadcrumb/URL字段；不能写“任何文本/令牌绝不会进诊断”。 |
| bot Sentry | 入口直接init且无beforeSend；另一个lib/sentry定义的initSentry未被入口调用，手工capture还受其独立initialized标志约束。`apps/bot/src/index.ts:5`；`src/lib/sentry.ts:5`、`:52`。 | 旧文档“bot已统一beforeSend脱敏”无实际接线依据；不能因SDK缺少明确业务capture就推断自动捕获完全不运行。 |
| 平台日志 | GET query、错误对象、AI成本日志及连接元数据可能由宿主/供应商处理。shared AI成本日志包含模型/route/token/花费等，不见主动记录prompt正文。`packages/ai/src/cost-tracker.ts:64`。 | 平台、代理、CDN、Supabase、模型商的日志/备份/训练/地域/删除机制均需运营配置或合同证据，不能从代码未insert推断不存在。 |

## 7. 删除、导出与“保留期限”逐项边界

| 用户动作或机制 | 实际效果 | 没有证明的效果 | 源码依据 |
| --- | --- | --- | --- |
| iOS 忘记我 | 当前按钮调用MemoryDigestService.forgetMe，只删除AgentMemorySnapshot与TasteProfile并保存。 | 不删VisitRecord、TimeCapsule、聊天、收藏、远端账号/消息/附件/日志、导出副本。 | `Views/Settings/SettingsView.swift:587`；`Services/MemoryDigestService.swift:130` |
| 独立ForgetMeService | 存在删除VisitRecord、TasteProfile、TimeCapsule、AgentMemorySnapshot的服务。 | 当前Settings按钮未调用它；不能将它的注释当可用用户流程，不能承诺设置一次点击删除四表。 | `Services/ForgetMeService.swift:68`；上述实际按钮 |
| iOS 清除数据 | 清部分偏好数组，调用repo删除本地完成/收藏/微调查/待签到、好友请求关系、对话/聊天、笔记/纠错/路线/行程、outbox、AIUsage。 | 函数未列VisitRecord、TimeCapsule、TasteProfile、AgentMemorySnapshot、设备Keychain、照片文件；无远端delete或账号注销。方法名和“all”注释不代表覆盖所有表。 | `Views/Settings/SettingsView.swift:522`；`Persistence/ExperienceRepository.swift:709` |
| 单条AI历史删除 | ChatHistoryStore按sessionID删除本地ChatMessageRecord和ChatSessionRecord。 | 不会撤回已发供应商的prompt或诊断记录；同行服务器历史另属一套模型。 | `Persistence/ChatHistoryStore.swift:122` |
| 退出 | SupabaseClient.signOut只删本地session Keychain项。 | 不删除auth.users、不失效所有服务端token、不删云端业务记录；本次未找到用户可触发的远端account delete。 | `Services/SupabaseClient.swift:210` |
| 导出我的数据 | Settings调用PersonalDataExporter，导出VisitRecord、TimeCapsule、TravelerNote、TasteProfile为文件，交系统分享。 | 该按钮不导出每张本地表、全部聊天、服务器账号/附件/诊断；repo另一个export方法存在不意味着当前按钮调用。 | `Views/Settings/SettingsView.swift:540`；`Services/PersonalDataExporter.swift:102`、`:118` |
| Web清Cookie/站点数据 | 浏览器失去关联标识和本地缓存；下一次可能新建标识。 | 不删已保存users/completions、PostHog历史、平台日志。 | `src/lib/anon-cookie.ts`；`packages/data/src/completions-repo.ts:42` |
| bot /reset | Map中该用户值替换为idle，清location/lastIntent/lastRankedIds。 | 原始ID键仍在Map；不删Telegram服务器消息、已上传音频、模型请求、历史分析或日志。 | `apps/bot/src/session.ts:24`；`src/index.ts:177` |
| bot /optout | 先发opted_out事件再加入进程set，重置session，后续该进程中分析受抑制。 | 不删既有分析；非持久偏好；不会关闭其他渠道/SDK诊断或平台日志。 | `apps/bot/src/index.ts:199`；`src/lib/analytics.ts:33` |
| 附件签名链接3600秒 | 一条访问链接过期。 | 不等于Storage对象删除或数据库metadata删除。 | `Services/ChatAttachmentService.swift:164` |
| Presence expires_at+2h | 发现资格/显示有效期字段。停止时尝试delete，可能失败。 | 不等于所有副本2小时内硬删除或始终成功后台清理。 | `Services/PresenceService.swift:93`、`:134` |
| 好友请求7天/定时sweep | 好友request到期函数可把status改expired；pg_cron存在且可用时注册。 | status过期不是删除；是否已部署并成功定时执行unknown。同行另有stale清理方法，未找到调用方。 | `infra/supabase/migrations/0010_friends_hardening.sql:132`、`:148`；`Services/CompanionService.swift:485` |
| 胶囊打开 | 置opened=true，openedCapsules仍可查询。 | 不会因scheduledFor已到或打开而自动删除内容。 | `Services/CapsuleStore.swift:137`、`:167` |
| 缓存TTL/30天指数/最近7天 | 各种查询筛选、新鲜度、cache-hit资格或配额窗口。 | 不等于过期后立即物理删除。例如AI合成7天、weather12小时、route cache5分钟/10分钟/6小时均不能当普遍保留承诺。 | `Services/AIService.swift:1411`；`Services/WeatherService.swift:75`；`src/lib/route-compilation-cache.ts:18`；数据库索引/查询 |
| 账号父行级联 | 部分migration有auth.users FK ON DELETE CASCADE；有的字段ON DELETE SET NULL。 | 无对应生产用户删除入口、执行记录和Storage清理证明；不能承诺全部表/对象/备份联动清除。测试的auth.admin.deleteUser不是生产功能。 | `infra/supabase/migrations/0001_init.sql`、`0003_companion.sql`；`infra/supabase/test_rls.ts:85`仅测试 |

## 8. 年龄、身份、联系方式及运营未知项

- CompanionSafetyConsentSheet有ageConfirmed和safetyConfirmed两项，未都勾选时按钮disabled；文案要求18+。接受后UserPreferences保存hasAcceptedCompanionConsent/时间。仅能表述“要求自行声明已满18”，不能表述年龄或身份经过核验。证据：`Views/Companion/CompanionSafetyConsentSheet.swift:19`、`:150`、`:171`；`Models/UserPreferences.swift:741`；`Resources/en.lproj/Localizable.strings:1543`；中文`:990`。
- 未在本次主应用数据模型/流程中找到通用生日、证件或全应用年龄验证；也不能保证用户不会在自由文本、照片或私信中主动提交这些信息。“不要求填写证件”与“绝不处理证件/人脸图片”是不同事实。
- 审计开始时旧`docs/PRIVACY.md:105`写`privacy@solo-compass.app`，当前营销copy`:382`/`:608`写`hello@solocompass.app`。源码只证明这些地址被展示，无法证明收件能力、所有权或删除申请处理能力。根代理另从公开个人站核验的联系方式不属本次私密数据审计；未读任何私密凭据。
- **unknown、不得自行补写：**运营主体法定名称/地址、适用法/控制者角色、最低通用使用年龄、正式版本实际开关、供应商账户与地区、子处理者完整名单、数据驻留、供应商模型训练开关、日志采样内容、后台保留/备份清理、删除请求SLA、账号删除执行方式、第三方合同条款及是否售卖数据的运营行为。未发现广告目标化代码不构成经营行为完整审计。
- 可以把法定权利/联系流程写成运营者的明确政策承诺，但不能说源码已经自动实现，亦不能用本报告替代法律适用判断或实际请求执行验收。

## 9. 旧 docs/PRIVACY.md 需要废止或重写的内容

| 旧文档位置 / 说法 | 当前事实及结论 |
| --- | --- |
| `:15` Telegram ID仅哈希、30天轮换 | 原始ID作内存Map键；分析哈希无轮换机制。仅可描述分析前进行盐哈希，不可笼统写原始ID从不处理。 |
| `:18` bot→Claude、转录回复后丢弃 | 当前推荐默认DeepSeek；lastIntent继续留内存。 |
| `:19` 坐标只内存、24h闲置清除 | bot没有TTL；Web位置经GET到服务端/数据库/AI，iOS另有持久坐标快照。 |
| `:20` iOS是future、位置与drop pin相同 | 现在有原生定位、后台授权升级、围栏、多个第三方位置查询和本地记录。 |
| `:21` Web UUID localStorage无指纹 | 完成记录使用HttpOnly Cookie；PostHog另有localStorage；traffic已实现IP+UA scoped hash路径，虽未发现当前UI调用。 |
| `:22-23` 90天分析、30天Sentry、无IP且统一脱敏 | 服务商retention未知；请求有技术元数据；iOS/bot过滤器与Web不一致。 |
| `:24-28` 四个模型永不上传、忘记我覆盖、胶囊打开删除 | 数据表本地持久化不等于摘要和上下文不出设备；按钮仅删二表；胶囊打开仍保留。 |
| `:31-35` 从不姓名/邮箱/社交图谱/人脸照片 | Apple此入口不请求姓名邮箱，但应用有显示名/自由文本/测试邮箱输入/好友关系及可选照片附件；不得对用户提交内容作绝对排除。 |
| `:40-49` 什么都不离设备、四表原子清除且不可恢复 | 与prompt上下文及实际按钮矛盾；无法证明物理不可恢复、第三方副本/备份已清。 |
| `:56-58` 无public profiles/社交相关功能 | 当前有同行资料、发现、好友、私信、APNs消息通知；旧产品禁令不反映源码。 |
| `:63-73` 两渠道beforeSend已统一、栈不含用户数据 | bot未调用过滤init；iOS无钩子；错误内容可能受运行时输入影响，不能绝对保证。 |
| `:77-91` bot/Web同事件taxonomy | Web当前是pageview/marker/sheet/intent_set/checkin；bot是另一组，iOS又是本地环。 |
| `:98-107` footer optout及monthly salt deletion | 未发现该Web开关；无月度换盐/立即换盐自动删除实现。换盐本身也不等于删除既有供应商记录。 |
| `:120` 所有iOS收集不关联身份 | Privacy Manifest声明本身不构成实现证明；deviceID、userID、session、聊天、同步和购买事件有明确关联。应另核对App Store填报，不据旧表断言匿名。 |

## 10. 审计完成度与验证边界

已检查：应用服务/关键视图和持久化调用、Web当前查询与认证API、bot session/转录/分析、共享AI prompt、相关Supabase migrations及Edge Functions；针对删除、期限、第三方域名、年龄和联系方式交叉检索。已将高影响事实即时交给根代理；正式中英文法律文案与Gist发布由根代理负责。

未做：生产功能开关读回、真实账号注册/删除、供应商后台设置、网络抓包、邮件收发、数据导出完整性实测、数据库/对象存储删除、供应商保留与备份验证。因此本报告是**源码事实目录及发布准确性边界**，不是“所有隐私合规或数据删除已验收通过”的结论。

## 附：关键证据文件 SHA-256

以下哈希固定本次读取的关键证据内容；后续生产代码改动后，按新行号重新核对，不把这些哈希当正式构建验收。

| 文件 | SHA-256 |
| --- | --- |
| `apps/ios/SoloCompass/Services/Context/ContextManager.swift` | `a25794b11faecc0f4ce39daf13337bc92cc9c60225eb01b2da220571a1ba4cdc` |
| `apps/ios/SoloCompass/Services/VoiceAgentOrchestrator.swift` | `87ce0c908e5b66b6df25b3dbb31fe7d1c1c75b795ad2892532eff11fd4f0e319` |
| `apps/ios/SoloCompass/Services/AIService.swift` | `7de2b1998b8cdd6f355657d1052a085c7b2dc404b08e893d1a4e467233ff2c17` |
| `apps/ios/SoloCompass/Services/LocationService.swift` | `c9ecc4c62691831ab931227a1c76a4df4229aec0c6fc721884994585af762fb1` |
| `apps/ios/SoloCompass/Services/WeatherService.swift` | `73dc8781c59dea712e8c18e051cd181bd5488fe93466aa15bd7d8628cea2a56a` |
| `apps/ios/SoloCompass/Views/Settings/SettingsView.swift` | `20cbafde84ed9b93d662103fc0bfdb2483a9aa87aa32dc06fd2988c73074e7ba` |
| `apps/ios/SoloCompass/Services/MemoryDigestService.swift` | `580b7112637944b8361f8b105507ed4b7c0a5fa20d1bc21bfc69303650bd49d1` |
| `apps/ios/SoloCompass/Persistence/ExperienceRepository.swift` | `80f6d7ccb9f5d08d4e17f8b2b45d77b6c65f444384b83e305beaf5df24f8c17a` |
| `apps/ios/SoloCompass/Services/ChatAttachmentService.swift` | `719c1dea56303041d44036df2a60ee90991a322a5dda8c09c3ef77542ad5ffed` |
| `apps/ios/SoloCompass/Services/SentryService.swift` | `10b54a8a4ce7642c35349b74acaaac289c3ad4407f2f667710b935d1c71714a6` |
| `apps/web/src/lib/analytics.tsx` | `e68b2097420bd1be0262f5de9b04f351c14d1a637e25e7018b8d8f9cae98c2f2` |
| `apps/web/src/lib/anon-cookie.ts` | `cb0e81a19190a134cb6ec73cf0cb79c41cdf788a7ae4bccf0d26cb15666bce6e` |
| `apps/web/src/lib/map-style.ts` | `3cfe3da0bcba4c31c35c92f3d08f39daa819b6fd8afc20e71ab5d12af9ff1aa2` |
| `packages/ai/src/prompts/rank-experiences.ts` | `1857b66432d8db40f00cfe5a50bafe65f6a0ea1e8226b90ff6d8cd991a3b26af` |
| `apps/bot/src/session.ts` | `a09852e19839467be55e52e26e60ee76a705a5049d00f06b702e08163fe3efff` |
| `apps/bot/src/index.ts` | `fd4b2c5d82b2f37a4ae741418e0d781c711e205b0fc26a6e32c73b5fd61c5dc9` |
| `apps/bot/src/lib/anon-id.ts` | `30829e5eee6caa04826b4a979025463afc56880926c658dcb3c7f189a2037379` |
| `infra/supabase/functions/chat-proxy/index.ts` | `5dcb8333b536e2f6c0c5f014be1a0117b48ebe20dfe5af352d2215aa767ada7e` |
| `infra/supabase/functions/message-notify/index.ts` | `d16f7626ede3bcbef2fea1072e1accd06cf11a251928e08b4d29d538a1cdc94f` |
| `docs/PRIVACY.md` | `fc7ef06912b4696af5c0e9a5774f20f0d9f0744f488e4b195101d16efb0b64c5` |
