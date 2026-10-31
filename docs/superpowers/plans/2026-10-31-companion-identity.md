# Personalize the companion and simplify chat

**Goal:** Let travelers rename their Agent after onboarding, choose a built-in visual style, and read more conversation on screen.

**Architecture:** Keep the existing SwiftUI companion and shared sheet presenter. Store a small, backward-compatible identity in the existing local preferences snapshot. Reuse the native glass modifier, including its accessibility and iOS 17 fallbacks.

**Direction:** Default to 漫游搭子 (Roam in English); retain user names. A transparent three-part header has menu/name at left, a small circular glass portrait at center, and city at right. The portrait opens an explicit Save/Cancel editor. Four local styles: original moss character, sunny pixel face, moonlit planet, paper landscape. Bottom navigation is icon-only with 44-point targets; replies and progress have no avatar gutter.

**Alternatives:** A separate customization screen adds navigation; a large profile block consumes the requested reading space. Use a compact sheet from the existing header and menu. These are implementation choices under the user's instruction to proceed autonomously.

**Constraints:** No new dependencies, accounts, generated remote images, permissions, schema or backend changes. Preserve chat identity, persistence, manual reading positions, source actions and drafts. Names are trimmed, single-line, and limited to 16 graphemes; four characters is the default, not a forced limit. Unknown future style values fall back safely. Both English and Simplified Chinese strings are required.

**Review focus:** Legacy preference snapshots; unknown style values; blank/control-character/emoji names; cancelled edits; largest Dynamic Type and compact width; keyboard dismissal; draft/history continuity.

- [x] Add identity model and preference persistence, with decode/normalization/restart tests.
- [x] Add local portrait presets and Save/Cancel editor; connect header and menu.
- [x] Compress navigation, preserving labels, selected state and touch size.
- [x] Remove reply/progress avatars, preserving message/source actions.
- [ ] Run host/localization checks, native CI and visual acceptance; independent branch review; one linked PR and merge after applicable gates pass.

**Resources:** The shared Mac has a disk-related pause marker. Keep local work lightweight and use the existing CI native build/test lane until the marker clears. Do not remove retained test evidence or interrupt other projects.

**Native regression follow-up:** Full App CI exposed an empty message viewport after opening the keyboard from a restored 5,000-message history. Following intent and execution remained valid. Latest now uses the native bottom edge rather than a one-point lazy target, and inset-driven visible-size changes enter the existing guarded execution channel. History IDs, gesture ownership and iOS 17 behavior remain intact. The original failing native assertion stays mandatory; a screenshot is captured after it passes. Local controlled native keyboard/history/scroll checks pass, with complete App CI required before merge.
