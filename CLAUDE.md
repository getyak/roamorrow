# Solo Compass — Claude Code Project Guidelines

## Overview

Solo Compass: a map-first companion app for solo travelers. The core unit is `Experience` (not `Place`); the map is the home screen.

## Tech Stack

### Monorepo

| Layer           | Choice                                               | Notes                                                          |
| --------------- | ---------------------------------------------------- | -------------------------------------------------------------- |
| Package manager | **pnpm 11.24.0** workspaces + **turbo**              | `engines.node >=22.13`. iOS app is **not** a workspace member  |
| TypeScript      | `strict: true`, `noUncheckedIndexedAccess: true`     | `interface` for object shapes, `type` for unions               |
| IDs             | Branded types (`UserId`, `ExperienceId`)             |                                                                |
| Geo coords      | `[longitude, latitude]` (GeoJSON / Mapbox / PostGIS) | Google APIs use `[lat, lng]`                                   |
| Time            | ISO 8601 UTC at storage; local at display            | `bestTimes` uses 0–23 hour ints in the experience's local time |
| Commits         | Conventional Commits, lowercase scope                | See `CONTRIBUTING.md`                                          |

### Apps & Packages

```
apps/
  web/    Next.js (App Router)
  bot/    Telegraf (Telegram bot)
  ios/    SwiftUI + MapKit — Xcode-managed, NOT in pnpm workspaces
packages/
  core/   Schema (experience.ts, confidence.ts, solo-score.ts, geo.ts, user.ts) — no UI deps
  ai/     Recommendation + extraction prompts
  data/   Seed loaders, fixtures
```

### iOS App (`apps/ios/SoloCompass/`)

| Layer        | Choice                                                       | Notes                                                                                                                                                                                                                                                             |
| ------------ | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Platform     | **iOS 17.0+**, Swift 5.10                                    | Single Xcode target `SoloCompass.app`. SwiftPM deps kept minimal: `supabase-swift` (sync backend), `sentry-cocoa` (crash & error tracking)                                                                                                                        |
| Project gen  | **xcodegen** from `apps/ios/project.yml`                     | Regenerate after editing the yml                                                                                                                                                                                                                                  |
| UI           | SwiftUI + **MapKit**                                         | `CompassMapView` is the root — no tabs, no drawer                                                                                                                                                                                                                 |
| State        | `@Observable` + `@MainActor` services                        | `SWIFT_STRICT_CONCURRENCY: complete` is on                                                                                                                                                                                                                        |
| Architecture | MVVM                                                         | `Views/{Map,Experience,Filter,Shared}` / `Models/` / `Services/` / `ViewModels/`                                                                                                                                                                                  |
| Voice        | `SFSpeechRecognizer` + `AVAudioEngine`                       | `VoiceService.swift` streams partial transcripts via `AsyncThrowingStream`                                                                                                                                                                                        |
| Location     | `CLLocationManager` + `CLCircularRegion` (200m, ≤20 regions) | `LocationService.shared`                                                                                                                                                                                                                                          |
| AI           | DeepSeek OpenAI-compatible chat completions                  | `AIService.swift`, model `deepseek-flash` (V4.1 Flash, thinking disabled). Key from `Secrets.resolvedDeepSeekApiKey` (`DEEPSEEK_API_KEY`). Pro voice/synthesis routes through the `chat-proxy` Edge Function. Falls back to Solo-Score ranking when key is absent |
| Seed data    | `Resources/JSON/seed_experiences.json` (bundle)              | Falls back to `ExperienceService.hardcodedSeed` for previews/tests                                                                                                                                                                                                |
| Localization | `NSLocalizedString`                                          | User strings live in `Resources/en.lproj/Localizable.strings`                                                                                                                                                                                                     |
| Telemetry    | **sentry-cocoa** via SwiftPM                                 | `SentryService.bootstrap()` in `SoloCompassApp.init`; DSN from `Secrets.sentryDSN` (build-time inject); empty DSN → SDK never starts (no-op)                                                                                                                      |

## Project Structure

```
solo-compass/
  apps/
    ios/SoloCompass/
      App/         SoloCompassApp (entry)
      Views/       Map, Experience, Filter, Shared
      ViewModels/  MapViewModel, ExperienceDetailViewModel
      Models/      Experience, UserPreferences
      Services/    Experience, AI, Location, Voice
      Resources/   Info.plist, Assets, JSON, en.lproj
      Tests/       SoloCompassTests (XCTest)
    web/           Next.js
    bot/           Telegraf
  packages/        core, ai, data
  scripts/
    ralph/         Autonomous AI dev loop (prd.json, ralph.sh)
    check-swift-parity.ts   TS↔Swift schema parity guard
    seed-load.ts            Seed loader
  docs/            PRODUCT_BRIEF, PHASES
```

## Useful Commands

```bash
# TS workspace
pnpm install
pnpm typecheck
pnpm test
pnpm format
pnpm parity:check        # verify TS↔Swift schema parity

# iOS
cd apps/ios
xcodegen                 # regenerate SoloCompass.xcodeproj from project.yml
dev-storage-guard audit
dev-storage-guard resources
ARTIFACT_ROOT="$(dev-storage-guard new-artifact solo-compass-ios)"
export IOS_DERIVED_DATA_PATH="$ARTIFACT_ROOT/DerivedData"
dev-ios-session run -- bash -c 'xcodebuild build-for-testing \
  -project SoloCompass.xcodeproj -scheme SoloCompass \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$IOS_DERIVED_DATA_PATH"'
dev-ios-session run -- bash -c 'xcodebuild test-without-building \
  -project SoloCompass.xcodeproj -scheme SoloCompass \
  -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" \
  -derivedDataPath "$IOS_DERIVED_DATA_PATH" \
  -resultBundlePath "$IOS_DERIVED_DATA_PATH/../Tests.xcresult"'
# Preserve delivery evidence, then dev-storage-guard remove-artifact "$ARTIFACT_ROOT"

# Ralph autonomous dev
cd scripts/ralph && ./ralph.sh --tool claude 12
```

## CI

- `.github/workflows/ios-ci.yml` — schema parity → build → test on `macos-latest`; full fake-tool simulator policy suite with no skips in the SwiftLint job
- `.github/workflows/ci.yml` — dependency patch regression / audit, TS typecheck / test / build / format, portable simulator policy tests and shell syntax, Go test / vulnerability scan
- `.github/workflows/testflight.yml` — TestFlight upload on qualifying `main` pushes or manual dispatch; ignores docs, Markdown, Ralph scripts and `.gitignore`, and owns release version/tag creation
- `.github/workflows/update-changelog.yml` — auto changelog

## Testing

**iOS**: XCTest target `SoloCompassTests` (default sim: iPhone 17 Pro, iOS latest).

Local simulator policy — [docs/development/ios-testing.md](docs/development/ios-testing.md).
Daily runs use one `primary` affected device (iPhone 17 Pro) with the shared
`dev-ios-session` helper owning `/tmp/ios-automation.xcodebuild.lock`;
`compact`/`ipad` are secondary profiles and iPads are never auto-selected.
Booted SE/iPad devices are ignored. Web/backend changes need no simulator.
`scripts/qa/two-sim-friend-loop.sh` is the explicit manual two-device
exception: it takes the same machine-wide lock, fails busy, and is not a
daily gate.

**TS**: per-package `pnpm test` via turbo.

CI policy gates — [docs/CI_TEST_MATRIX.md](docs/CI_TEST_MATRIX.md).
Map and restaurant accuracy boundaries — [delivery and compatibility evidence](docs/development/map-food-accuracy-delivery.md).
Dependency patch and audit policy — [docs/development/dependency-security.md](docs/development/dependency-security.md).

## Skill Routing

Skills available for common tasks:

| Trigger                                                | Skill                              |
| ------------------------------------------------------ | ---------------------------------- |
| Product ideas, brainstorming, "is this worth building" | `office-hours`                     |
| Bugs, errors, "why is this broken"                     | `investigate`                      |
| Ship, deploy, push, create PR                          | `ship`                             |
| QA, find bugs, test the site                           | `qa`                               |
| Code review, check my diff                             | `review`                           |
| Update docs after shipping                             | `document-release`                 |
| Architecture review                                    | `plan-eng-review`                  |
| Visual audit, design polish                            | `design-review`                    |
| Save / resume progress                                 | `context-save` / `context-restore` |
| Code quality, health check                             | `health`                           |
