# CI Test Matrix — Phase 2 + Phase 3 (#290 / #390)

Owner: infra
Target CI: `.github/workflows/ios-ci.yml` (`macos-latest`) and
`.github/workflows/ci.yml` (`ubuntu-latest`).

## Simulator policy and dependency gates

Native long-history CI retains its existing pass/fail assertions. If XCTest
reports that the app event loop never became idle, a CI-only diagnostic helper
captures one bounded stack sample of the selected Simulator's application.
The helper checks the process path and records no message text or memory dump;
the step always stops its owned watcher when testing ends. This diagnostic does
not turn a timeout or failed UI assertion into a passing result.

The macOS host audio regression compiles the shipping `CompanionAudioSession`
controller with an inert audio-framework boundary. It checks that idle cleanup
never initializes system audio, recording and playback release only their own
successfully activated sessions, and failed activation/creation/cleanup preserve
the ownership rules. Apple's legacy `isBusy` deactivation result means the session
is already inactive, so only unknown failures retain retry ownership; the check
also distinguishes an unrelated error domain with the same code. See
[Apple's deactivation documentation](<https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)>).
The host check never requests microphone access or plays audio. The
existing complete-App long-history, keyboard, send and navigation UI gates remain
required separately.

The owned native-device trace also retains Debug-only audio lifecycle markers
with recording/playing/paused/ownership booleans. It never records attachment
identities, audio, transcripts, message text or location.

| Workflow/job                     | Required checks                                                                                                                                          |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ci.yml` / build (Linux)         | Portable `scripts/ios/test_local_policy.py` suite, explicit skips for macOS-only tests, and `bash -n` for all five simulator entrypoint/library scripts. |
| `ios-ci.yml` / SwiftLint (macOS) | Full fake-tool simulator policy suite; any skipped test fails this step.                                                                                 |
| `ci.yml` / build (Linux)         | `pnpm security:patch-check` against real Tailwind dependency paths before `pnpm audit --audit-level=low`.                                                |
| `ci.yml` / build (Linux)         | Dependency floors and Zod/fast-uri/Undici regressions, plus `security:browser` against the real DOMPurify dependency in Chromium.                        |

The policy suite uses fake subprocess tools and never runs a real Simulator.
It verifies script behavior, not app/UI acceptance. See
[local iOS testing](development/ios-testing.md) and
[dependency security gates](development/dependency-security.md).

## Suites CI must run

Every landed test file in `apps/ios/SoloCompass/Tests/` runs by
default under the SoloCompassTests target. This document freezes the
critical subset that MUST stay green — CI blocks a merge if any of
them regresses.

`EmailAccountServiceTests.swift` is included in that full target and in the
focused `AccountRegressionTests` target. Account onboarding UI tests live under
`docs/qa/harness-ios-20261024/` and require the additional `AccountAcceptance`
scheme. After the full `SoloCompass` unit suite, iOS CI runs just the
`AccountOnboardingUITests` class on the same selected device and uploads its
result bundle. Real account/provider acceptance remains separate from these
invalid-email, guest and password-entry UI checks and is recorded in the
[Harness acceptance record](qa/harness-ios-20261024/README.md).

### Phase 1 baseline (must stay 70+/70+)

- `V1_9SchemaRecordsTests` — SwiftData schema V1_9 CRUD + coord codec
- `VisitTrackingServiceTests` — 7 cases
- `TasteUpdateServiceTests` — 10 cases
- `GenerateTasteProfileTests` — 14 cases
- `ArchiveViewModelTests` — 8 cases
- `ArchiveSnapshotTests` — 2 cases
- `VisitedMarkerStateTests` — 6 cases
- `LiveActivityServiceTests` — 6 cases
- `MarkerStatePerformanceTest` — identical marker outputs and ≥40% lower cached
  p95 amortized per-pass latency, using 100 paired batches of 100 full
  100-marker passes for each path.

### Phase 2 P2.0 (must stay green)

- `MemoryDigestServiceTests` — 15 cases

### V-next skeleton (Phase 2/3 code-scope)

- `V_NEXT_ServiceSkeletonTests` — 10 cases covering:
  - Omen determinism per day + differs across days
  - Music playlist determinism
  - Brag counts + headline determinism
  - Monthly insight month bucketing
  - Book weekly chapter aggregation
  - Analytics buffer opt-out
  - Capsule bury / ripe / markOpened
  - Nudge daily budget limit

## Local pre-push check

Because Phase 2 was landed without a local `xcodebuild test` run,
the first CI cycle after this branch merges is expected to surface
any type/API drift. Playbook if red:

1. Read the CI log for the exact file:line diagnostic.
2. Fix the symbol reference. `SourceKit` "cannot find type" errors
   in the branch's editor context are index-freshness, not compile
   errors — but real compile errors from CI use a different message
   ("cannot find in scope of module").
3. Re-run `xcodegen` only if the fix required a file rename or
   move; simple edits do not need it.

## Coverage floor

Phase 2 + Phase 3 code-scope files should hit ≥ 60% line coverage
via the tests above. Below floor blocks the PR — file a coverage
follow-up before merging.

## Non-covered by design

- Real StoreKit purchase flow (unit tests can't hit
  `Product.purchase()`).
- Real MusicKit playlist creation.
- Real UNUserNotificationCenter delivery (only scheduling assertions).
- Live Activity `Activity.request()` — needs the widget extension
  entitlement, tested manually via `docs/BETA_TEST_CHECKLIST.md`.
