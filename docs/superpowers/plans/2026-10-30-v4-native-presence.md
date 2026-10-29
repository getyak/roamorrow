# V4 Native Conversation and Map Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for scoped parallel work, then one integrated build and independent review.

**Goal:** Implement the approved conversation-first iOS V4 with Conversation / Map / Itinerary / Me, map-owned favorites, reliable draft/reading recovery, and grounded faster AI tools.

**Architecture:** Retain the existing root-owned MapViewModel, ConversationWorkspaceState and VoiceAgentOrchestrator. Map stays mounted while native content surfaces switch. Separate immutable message result IDs, map browsing, next-turn scope and confirmed itineraries; use the existing preferences/history stores as authorities.

**Tech Stack:** iOS17+, SwiftUI, Observation, MapKit, SwiftData, existing SPM dependencies.

**Spec:** docs/design/trip-presence-20261029/interaction-v4.md (explicitly approved by the user for implementation).

## Global Constraints

- Bottom destinations are 对话 / 地图 / 行程 / 我的; 对话 is the default; 收藏 belongs to 地图.
- Keep one map, one active orchestrator and existing persisted Experience/favorites identities.
- A map visit or place scope must not create a conversation, rewrite a past response, or edit an itinerary.
- Search uses known map/location provenance, visible pending quality, cancellable network and explicit errors. No guessed physical location or invented provider facts.
- Only user-confirmed itinerary adoption writes plans; navigation opens Maps without payment or ride execution.
- English and Simplified Chinese localization; Swift strict concurrency; unchanged dependency pins/checksums.
- One serialized native build/test through dev-ios-session; preserve borrowed devices and unrelated work.

## Review Focus

- An incoming reply while reading history must not jump to bottom after tab return.
- Conversation A/B drafts, attachments, next-turn scope and stable message anchors must not leak.
- Map camera settling must not replace the originating message candidate set; empty results stay empty.
- Removing the final favorite must clear stale selection; global favorites must not be restricted to the current viewport.
- Cancellation, slow requests, city changes and partial streamed output must not trigger stale writes or duplicate fallback requests.

## Shipping-root correction from source inspection

SoloCompassApp defaults continuousCompanion=true, so the active product uses CompanionHomeView, CompanionHomeStore and CompanionHomeAgent. Implement in that root, preserving its media, follow-ups, route and local snapshot. The Compass/VoiceOrchestrator references below identify legacy research, not the chosen shipping surface. Task ownership was adjusted accordingly: session worker owns CompanionHomeStore + CompanionHomeModels, root owns CompanionHome UI, AI worker owns AIService + CompanionHomeAgent (legacy catch only for shared transport safety). No legacy navigation migration is shipped.

## Task 1: Conversation state and next-turn scope

Owner: session worker. Modify Models/ConversationWorkspaceState.swift, Services/VoiceAgentOrchestrator.swift and focused Tests. Produce setNextTurnExperience(_:), clearNextTurnExperience(), nextTurnExperience; savePresentation(conversationId:), restorePresentation(conversationId:preferredAnchor:). Preserve IDs/history, consume scope only on accepted input. Record a typed ConversationMapSource using stable conversation/message IDs and reading anchor. Fix prompt origin/radius statements and include planner in total turn budget.

- [ ] Add regressions for accepted/rejected sends, scope set/clear, A/B presentation and reading recovery.
- [ ] Implement state/session changes using existing history authority; keep legacy scope APIs compatible for intentional new context flows.
- [ ] Verify cancellation/generation guards and provide exact root integration interfaces.

## Task 2: Native shell and chat integration

Owner: root. Modify Views/Map/CompassMapView.swift, WorkspaceDock.swift and Views/Chat/ChatSheet.swift; add focused native UI acceptance. Use full conversation surface and four-item dock; keep dock outside composer and hide it for software keyboard. Reuse ItineraryListView and personal hub. Pass source message and candidate IDs from chat to the same map. Scope display/clear uses next-turn APIs; history transitions stash/restore presentation, ordinary map return does not reseed.

- [ ] Pin the four navigation destinations/default and source round-trip behavior in tests.
- [ ] Wire map/source return and preserve draft/anchor without changing confirmed itinerary.
- [ ] Localize visible labels and accessibility identifiers; visually verify keyboard and safe-area behavior.

## Task 3: Map browsing and favorites

Owner: map worker. Modify ViewModels/MapViewModel.swift, add focused Models/Views map workspace components and Tests; MapKitPOIService cancellation fixes if justified. Produce explicit map browsing mode, message-result lock, current-city/all favorites, explicit search-area release and reconciliation APIs for root. Keep category/camera per mode and canonical Experience resolution.

- [ ] Add tests for camera refresh preserving message candidates, final unsave empty state, cross-city saved collection and no-fit tab revisits.
- [ ] Implement one authoritative favorites state and deterministic selection reconciliation.
- [ ] Provide a reusable nearby/saved/return-source control component; do not edit CompassMapView or localization files shared with root.

## Task 4: Faster AI transport and real scenario evaluation

Owners: AI transport worker (AIService.swift + new transport tests), independent Eval worker (new QA runner/receipts only). Cancel underlying SSE requests when consumers terminate; avoid blind non-stream retry after partial output or terminal HTTP failure; keep explicit bounded compatibility fallback. Evaluate real SDK/provider and bounded model calls where configured without exposing keys or personal data. Record TTFT/tool/total time separately and preserve failures.

- [ ] Add transport tests for cancellation, partial output and retry policy, then repair minimal production behavior.
- [ ] Execute selected real travel scenarios with bounded calls and source/ID assertions; no private mail/calendar or financial actions.
- [ ] Report latency measurements as measured samples, not general p95 claims.

## Task 5: Build, integration, CI and delivery

Owner: build worker for caches/build/test; root for integration and delivery. Recover official pinned Sentry artifacts with original checksum; never change manifests to fake a build. Run xcodegen when required; one primary simulator through helper. Run relevant XCTest/UI acceptance, host regressions, localization and parity checks; independent whole-diff review fixes confirmed P0/P1. Update PR685/GET324 around final implementation, push and verify current-head CI before eligible merge. Save screenshots/video, test results and recovery refs, clean only task-owned reconstructable artifacts.

- [ ] Resolve pinned binary artifacts and build the integrated source.
- [ ] Run native state/tool/UI scenarios and independent review, fix failures and repeat affected checks.
- [ ] Verify current-head CI, then deliver implementation/evidence and keep any unaccepted platform boundary explicit.

## Authorization and execution

The user explicitly approved V4 and requested direct native implementation with multiple subagents. Execute this plan without another design approval round. Workers share the checkout, own only the files/regions assigned, and must accommodate others without reverting their changes.
