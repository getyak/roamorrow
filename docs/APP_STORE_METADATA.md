# App Store metadata — Roamorrow

Repository preparation only. These fields and notes must be checked against the submitted build and live App Store Connect configuration before submission. Editing this file does not change App Store Connect, publish an app, set an age rating or install a custom EULA.

The public name is Roamorrow in both languages. Signing and bundle IDs, StoreKit product IDs, persistence keys, Keychain namespaces and existing `solocompass://` links retain their technical identities. App Store Connect and TestFlight branding require separate provider updates and readback.

## Build identity

| Field                   | Repository value / submission action                                                                                                                                                                |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Bundle ID               | `com.solocompass.app`                                                                                                                                                                               |
| MARKETING_VERSION       | `1.1.0` in `apps/ios/project.yml`; release automation may override it                                                                                                                               |
| CURRENT_PROJECT_VERSION | `2` in `apps/ios/project.yml`; verify the uploaded build number                                                                                                                                     |
| Minimum iOS             | `17.0`                                                                                                                                                                                              |
| Localizations           | English (primary) and Simplified Chinese (`zh-Hans`)                                                                                                                                                |
| Category suggestions    | Travel / Lifestyle; confirm in App Store Connect                                                                                                                                                    |
| Encryption              | `ITSAppUsesNonExemptEncryption = false`; verify actual export-compliance answers for the submitted build                                                                                            |
| Content rights          | Uses third-party map/place/image data. Check attribution and applicable licenses; do not answer that it uses no third-party content.                                                                |
| Age rating              | Complete the current App Store Connect questionnaire for the submitted features. Companion access requires an 18+ self-declaration; this is not verified age or a preselected App Store age rating. |

## Name and subtitle

- English name: `Roamorrow`
- English subtitle: `Find your way. Feel at home.`
- 中文名称：`Roamorrow`
- 中文副标题：`一个人出发，也能在远方过好日常`

## Promotional text

English (within 170 characters):

> Find your way. Feel at home. Discover nearby experiences, review their sources, and save what matters. AI options depend on your settings and access.

中文：

> 一个人出发，也能在远方过好日常。发现附近体验，查看来源，收藏值得前往的地方。AI 功能取决于当前设置与访问权益。

## Description

### English

Roamorrow is a map-first personal companion for solo travel and life on the move. Explore nearby experiences, inspect their sources and confidence, and save or record the ones you choose.

Explore Here can use public place data to suggest experiences around a selected location. When enabled, AI adds draft descriptions and explanations. Sources, hours, estimated walking times and AI output can be incomplete or outdated; check current conditions before you go. Scores and confidence indicators are informational, not a safety or freshness guarantee.

Use supported text or voice input to describe what you want. Availability depends on the device, permissions, provider configuration and account/entitlement. Features explicitly labeled as previews or read-only are not complete paid capabilities.

Free and Pro access are those currently offered in the app. Monthly/yearly products, prices, billing periods and any introductory-offer eligibility are shown by Apple before purchase. No fixed free-trial duration, unlimited AI or lifetime entitlement is promised here. Manage or cancel subscriptions in Apple settings; deleting the app or local data does not cancel a subscription.

Location and selected context can be sent to exploration and AI services. Accounts, sync, companion messages, attachments and configured diagnostics involve the relevant backend or third-party service. The native default AI provider is DeepSeek; settings and the Pro proxy determine the actual request destination. Read the public Privacy Policy for recipients, retention limits and available controls.

Privacy Policy: https://roamorrow.com/privacy
Terms of Service: https://roamorrow.com/terms
Support and privacy requests: hello@roamorrow.com / privacy@roamorrow.com

### 中文

Roamorrow 是为独行者准备的地图伙伴。探索附近体验，查看来源与可信度，收藏或记录你自己选择的去处。

“在这里探索”可根据选定位置使用公开地点数据提供体验建议。启用 AI 时，它会补充描述草稿与解释。来源、营业信息、估算步行时间和 AI 输出可能不完整或过时，出发前请确认当前情况；评分与可信度提示不保证安全或实时准确。

你可通过支持的文字或语音输入表达需求；具体能力取决于设备、权限、服务商配置与账号/权益。标为预览或只读的界面，不代表相关付费能力已完整开放。

免费与 Pro 以应用当前实际提供的内容为准。Apple 会在购买前显示月度/年度商品、价格、计费周期和优惠资格。本文不承诺固定试用天数、无限 AI 或终身权益。订阅可在 Apple 设置管理或取消；删除应用或本地数据不会取消订阅。

位置和选定上下文可能发送至探索或 AI 服务。账号、同步、同行消息、附件和配置的诊断涉及相应后端或第三方服务。原生默认 AI 服务商为 DeepSeek，设置及 Pro 代理决定实际请求去向。数据接收方、保存限制与可管理选项请见完整隐私政策。

隐私政策：https://roamorrow.com/privacy
用户协议：https://roamorrow.com/terms
支持与隐私请求：hello@roamorrow.com / privacy@roamorrow.com

## Keywords

`solo,travel,map,nomad,cafe,quiet,explore,coworking,wellness,nearby`

## Public destinations

| App Store field    | Intended canonical destination  |
| ------------------ | ------------------------------- |
| Privacy Policy URL | `https://roamorrow.com/privacy` |
| Terms of Service   | `https://roamorrow.com/terms`   |
| Support URL        | `https://roamorrow.com/support` |
| Marketing URL      | `https://roamorrow.com`         |
| Support email      | `hello@roamorrow.com`           |
| Privacy email      | `privacy@roamorrow.com`         |

Verify all canonical pages over HTTPS and email forwarding before submission.
No App Store or TestFlight download URL is recorded until its destination is
verified. A source change does not establish a published listing.

The previously published bilingual documents remain provenance/fallback references:
[Privacy Policy](https://gist.github.com/kubbot/e177b6ab042c8d5bd79417300031a5c9)
and [Terms of Service](https://gist.github.com/kubbot/08f720b1191b6f9c913699c16227581a).
Keep public reading URLs instead of revision-pinned raw files. The old
`solo-compass.vercel.app` deployment and `solocompass.app` legal paths are not
valid substitutes for the canonical pages.

## In-app purchases

| Runtime product ID            | Meaning     | Live storefront verification                                                                                             |
| ----------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------ |
| `com.solocompass.pro.monthly` | Pro monthly | Price, region, period, trial eligibility and family sharing must be read from the actual App Store configuration/product |
| `com.solocompass.pro.yearly`  | Pro yearly  | Same verification required; do not infer a trial or price tier from a local StoreKit test file                           |

The local `Configuration.storekit` file supports development testing; it is not evidence that the same offer is active in App Store Connect. Standard Apple EULA applies where no different applicable app license has been provided. Publishing the service Terms Gist does not configure a custom EULA.

## TestFlight beta notes

Test the build's map, retained conversation, settings, localization and configured sync/Pro paths. Use supplied test access for protected features; do not treat an arbitrary client-side debug unlock as an App Review account or live purchase.

1. Explore the bundled experiences and inspect sources/confidence.
2. Read both documents from first use, Settings and the paywall; verify the canonical public destinations.
3. Exercise permitted/declined location and speech paths, keeping drafts on failure.
4. Check current StoreKit products and any offer actually returned; exercise restore, empty restore and failure.
5. Repeat affected flows in English and Simplified Chinese, including large text and dark appearance.

Feedback: `hello@roamorrow.com` (privacy requests: `privacy@roamorrow.com`), or an available in-app report action. Some rituals/archive/export screens remain preview or read-only; assess the functionality actually displayed by the submitted build. Availability of backend, AI, push and sync depends on that build's configuration.

## Reviewer notes for submission

Roamorrow was previously named Solo Compass; the app retains the existing bundle and purchase identities. Roamorrow provides a free map experience and, where configured, Pro subscription features. A reviewer must be given working backend/test access for any protected features included in the submission; none is supplied by this document alone.

Native AI defaults to DeepSeek and can use the selected OpenAI/custom endpoint or the configured Pro proxy. Requests can include submitted text, relevant conversation/history, preferences, coordinates and context. Exploration can send coordinates/radius to OpenStreetMap/Overpass; Apple MapKit and other configured map/place/weather services also participate. Do not describe requests as containing only OSM tags and a city slug or as containing no personal data.

The app includes Supabase account/sync/conversation integration and configured Sentry diagnostics. Optional companion messages/attachments and push notifications have the data uses explained in the published Privacy Policy. Do not submit claims of no accounts, no third-party SDKs, all data on-device or universally anonymous diagnostics.

The first-use summary links to the public documents; Settings and the paywall retain access. Device permission prompts and feature-specific confirmations remain separate. Local Forget me/Clear data actions do not delete a backend account, cancel a subscription or erase every recipient's copy. Verify account-deletion requirements and the actual operational process before App Review; a contact email by itself is not proof of full in-app account deletion.

Privacy Policy: https://roamorrow.com/privacy
Terms of Service: https://roamorrow.com/terms
Support/privacy contact: hello@roamorrow.com / privacy@roamorrow.com

## Before submission

- [ ] Verify the Roamorrow name, route-and-sun mark, permissions, shared cards and exports in both languages.
- [ ] Confirm an upgrade preserves data/preferences, purchases restore and legacy app links still route.
- [ ] Read back App Store Connect and TestFlight name, icon and localized metadata after provider updates.

- [ ] Verify the actual uploaded build/version and required device screenshot classes.
- [ ] Run release-required build/tests and affected permission, failure and recovery paths; do not treat the narrow legal-link build as full release acceptance.
- [ ] Check privacy manifests, App Store privacy answers, third-party SDK configuration, content rights and age questionnaire against actual behavior.
- [ ] Read back the current App Store products, prices, intro offers and entitlements.
- [ ] Verify all public legal/support links without a logged-in session.
- [ ] Update and read back the remote App Store Connect privacy URL, description/Terms link and support/contact fields. This step has not been performed by editing this document.
- [ ] Confirm reviewer access, account/data deletion and applicable user-rights handling for the submitted service.
