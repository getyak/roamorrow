# App Store Metadata — Roamorrow

Draft listing copy for the Roamorrow rebrand. These are intended submission
fields, not confirmation that App Store Connect or TestFlight has been updated.
Read provider settings back before marking publication complete.

## Build identity

| Field | Value |
| --- | --- |
| Public app name | `Roamorrow` |
| Bundle ID | `com.solocompass.app` — retained for existing installs |
| Marketing version | `1.1.0` in `apps/ios/project.yml`; release workflow may override |
| Build number | `2` in `apps/ios/project.yml`; release workflow may override |
| Minimum iOS | `17.0` |
| Primary language | English (U.S.) |
| Localizations | English, Simplified Chinese (`zh-Hans`) |
| Primary / secondary category | Travel / Lifestyle — confirm in App Store Connect |
| Encryption | `ITSAppUsesNonExemptEncryption = false` |
| Content rights / age rating | Reconfirm the current questionnaire and source licenses before submission |

Signing, bundle IDs, StoreKit product IDs, persistence, Keychain namespaces,
and the existing `solocompass://` links retain their technical identities.
The public name is Roamorrow in both languages.

## App name and subtitle

| Field | English | Simplified Chinese |
| --- | --- | --- |
| App name (30 characters) | `Roamorrow` | `Roamorrow` |
| Subtitle (30 characters) | `Find your way. Feel at home.` | `一个人出发，也能在远方过好日常` |

## Promotional text (170 characters)

> Find your way. Feel at home. Explore local experiences, save places you want to return to, and make a new city feel more familiar.

zh-Hans:

> 一个人出发，也能在远方过好日常。发现当地体验，收藏想再去的地方，慢慢熟悉一座新的城市。

## Description (4000 characters)

> Roamorrow is a personal companion for solo travel and life on the move.
>
> Start with a map of experiences: a quiet café, a walk by the water, a market worth taking your time in. Save what interests you and return to it when the moment feels right.
>
> Explore nearby
>
> Discover public places from OpenStreetMap and browse curated experiences. AI can help describe an experience from a solo traveler's perspective. Sources and confidence help you judge the information; opening hours, conditions, and suitability can change.
>
> Find your own pace
>
> Browse Solo Score dimensions, save favorites, record visits, and share an experience or a route. Use voice input when you would rather speak than type.
>
> Optional AI assistance
>
> Ask for suggestions in your own words. Available AI features depend on your subscription, configured services, and network access. Review the in-app disclosure before sending information to external services.
>
> Your travel, your choices
>
> Location, microphone, camera, and photo access are requested for the features that use them. Review the Privacy Policy for information about AI processing, optional sync, diagnostics, and data controls.

zh-Hans:

> Roamorrow 陪你一个人旅行，也陪你在流动中生活。
>
> 从地图上的体验开始：一家安静的咖啡馆，一段沿水边的散步，一个值得慢慢逛的市集。收藏感兴趣的地方，等合适的时候再去。
>
> 探索附近
>
> 浏览精选体验，发现来自 OpenStreetMap 的公开地点。AI 可以从独自旅行的角度补充体验描述。查看来源和置信度，再判断信息是否适合你；营业时间、现场条件和体验感受都可能变化。
>
> 找到自己的节奏
>
> 查看独行评分的各个维度，收藏地点、记录到访，分享体验或路线。不想打字时，也可以用语音表达。
>
> 按需使用 AI
>
> 用自己的话说出想法，获取建议。AI 功能的可用性取决于订阅、服务配置和网络连接。向外部服务发送信息前，请先阅读应用内的数据说明。
>
> 自己决定如何旅行
>
> 位置、麦克风、相机和照片权限会在相应功能需要时请求。有关 AI 处理、可选同步、诊断和数据管理的说明，请阅读《隐私政策》。

## Keywords (100 characters, comma-separated)

`solo,travel,map,nomad,cafe,quiet,explore,coworking,wellness,nearby`

## Public destinations

| Field | Intended value |
| --- | --- |
| Support URL | `https://roamorrow.com/support` |
| Marketing URL | `https://roamorrow.com` |
| Privacy URL | `https://roamorrow.com/privacy` |
| Terms URL | `https://roamorrow.com/terms` |
| Support email | `hello@roamorrow.com` |
| Privacy email | `privacy@roamorrow.com` |

Verify HTTPS pages and email forwarding before submission. No App Store or
TestFlight download URL is recorded until the destination is verified.

## In-app purchases

| Product ID — unchanged | Intended display name | Local StoreKit introductory offer |
| --- | --- | --- |
| `com.solocompass.pro.monthly` | Roamorrow Pro Monthly | 7 days |
| `com.solocompass.pro.yearly` | Roamorrow Pro Yearly | 7 days |

Intended subscription group display name: `Roamorrow Pro`. The group ID,
product IDs, and receipt compatibility are unchanged. The checked-in StoreKit
configuration supports local testing; confirm current prices, trial eligibility,
family sharing, and localized display names in App Store Connect before publishing.

## Screenshots

Capture the actual release build in English first, then Simplified Chinese.
Use the device sizes required by the current App Store Connect submission.

1. Welcome screen with the route and rising sun mark, Roamorrow name, and tagline.
2. Map with representative experiences and visible source information.
3. Experience detail with Solo Score and confidence.
4. An experience or route share card with `roamorrow.com`.
5. Voice input and its permission explanation.
6. Subscription screen with prices and offers from the current store environment.

## TestFlight beta description (draft)

> This build introduces the Roamorrow name and route-and-rising-sun identity. Existing app data, purchases, and legacy app links keep their technical identities.
>
> Please check the welcome screen, system permission prompts, English and Simplified Chinese text, shared cards, exported files, and the Privacy Policy and Terms links.
>
> Also check that saved experiences and settings survive an upgrade, previously purchased entitlements restore, and existing app links still open the correct experience or route.
>
> Send feedback through the in-app reporting flow or hello@roamorrow.com once support forwarding has been verified.

## Reviewer notes (draft)

> Roamorrow was previously named Roamorrow. This is a public rebrand of the existing app; the bundle ID and in-app purchase product IDs are unchanged.
>
> The app offers a free experience map and optional Pro features. AI and sync availability depend on the submitted build's service configuration. Please review the in-app data disclosure and the Privacy Policy for the processing used by this build.
>
> Provide any required review credentials and sandbox purchase instructions with the actual submission. The local Configuration.storekit file is a development fixture and does not establish App Store availability or an introductory offer for a reviewer account.

## Submission gates

- [ ] Native build and relevant tests pass on the release candidate.
- [ ] Real Simulator or device captures verify both languages and the home-screen display name.
- [ ] Upgrade preserves saved data, preferences, purchases, and legacy app links.
- [ ] Localized `InfoPlist.strings`, privacy manifest, and app-icon sizes are bundled.
- [ ] Public support, privacy, and terms pages are reachable over HTTPS.
- [ ] Support and privacy email forwarding are verified.
- [ ] StoreKit names, offers, prices, privacy labels, content rights, and age rating are reviewed in App Store Connect.
- [ ] App Store Connect and TestFlight branding are read back after provider changes.
- [ ] Submitted build, review status, and verified download URL are recorded separately from source changes.
