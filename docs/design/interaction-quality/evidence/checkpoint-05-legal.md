# Checkpoint 05 — public Gist documents and legal entry points

2026-10-16, `codex/interaction-quality`. User authorized the two-public-Gist plan and explicitly supplied `cubxxw@gmail.com` for privacy/support contact. Operator identification is the public maintainer Xinwei Xiong (cubxxw), not an invented registered company.

## Published documents

- Privacy Policy: https://gist.github.com/kubbot/e177b6ab042c8d5bd79417300031a5c9
- Terms of Service: https://gist.github.com/kubbot/08f720b1191b6f9c913699c16227581a

Both are public, bilingual, cross-linked and owned by the authenticated `kubbot` GitHub account. `docs/legal/publication.json` records IDs, exact source filenames and content hashes. Both GitHub API contents match local Markdown byte-for-byte. Separate HTTP GET requests sent no Authorization or Cookie and returned status 200, the document title, English/Chinese bodies, user-specified email and the other document link. The independent reviewer repeated these checks. No private customer data or credentials were published.

Web tool cannot retrieve the new Gists. The CUA wrapper created a correctly titled tab but its initial AX read timed out twice; its tab was later closed through the browser API. The anonymous HTTP check verifies the server-rendered public reading page; it is not a claim of completed iOS UI clicks or a screenshot review.

## Source and compile binding

`snapshot-05-legal-files.json` contains 109 modified app-source files: 57 iOS, 51 Web and one bot source. The historic 03/04b tests and Web-final validations remain bound to their original snapshots; they are not relabeled as tests of 05.

The new `LegalDocumentLinks` uses a 44pt frame and Rectangle contentShape **inside each Link label**. This label correction was made before the final incremental native build (exec session 97139). That session exited 0 and its `** BUILD SUCCEEDED **` log was copied to `ios-legal-build.log.gz` only after completion. The file manifest was generated after that same build. Source hashes match the current working tree, including the corrected label. This is not the earlier build made before the reviewer suggestion.

Native command: `dev-ios-session run -- xcodebuild build -project apps/ios/SoloCompass.xcodeproj -scheme SoloCompass -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath <registered artifact>/DerivedData CODE_SIGNING_ALLOWED=NO`. This built the app for Simulator; it did not boot a device, run XCTest or click the new links. The shared helper owned the testing lock and released it.

`pnpm localization:check` exited 0, all 1738 referenced keys present in English. Both English/Chinese .strings passed plutil, and the three Swift UI source files passed syntax parsing. New consent summaries accurately disclose location/context, selected photos/speech, sync and diagnostics rather than saying everything stays local or that no third-party services exist.

## Integration scope

- First-use, Settings Data & About and paywall use the same two native semantic links.
- Web footers have full Privacy/Terms destinations and the user-supplied contact email. The existing local privacy pages remain implementation summaries with a prominent full-policy link.
- The bot `/privacy` summary uses the same public policy and accurate session/processing limits; its implementation was not redeployed.
- Legacy docs/PRIVACY.md points to current documents, and App Store metadata preparation has been rewritten to remove unsupported Anthropic/no-account/no-third-party-SDK/fixed-trial claims.

## Boundaries

The Gist documents are live. No iOS binary, website or bot release has been made; the source integrations require the next normal release. Remote App Store Connect fields, privacy questionnaires, account deletion implementation, StoreKit products or EULA configuration were not changed. The service Terms conditionally refer to Apple's Standard EULA, not a new custom EULA submission. This factual review is not a legal-compliance or App Review guarantee, and does not certify every control above 96.

## Final host validation

- Web Next15.5.27 productionbuild: exit0; compile, type validity, 20 static pages and traces completed.
- Web tsc --noEmit: exit0.
- Bot tsc --noEmit: exit0.
- No new mirrored URL-string unit tests or full unchanged regression suite were added/rerun; historic 58 Web/80 native/3 contrast results remain at their original boundaries.
- Final source manifest: 109/109 SHA matches; current UI inventory: 218 files, 918 candidates (810 iOS /108 Web), 44 groups, no unassigned/parse diagnostics.
- Independent reviewer closed L01 as source_fixed/public_destination_verified and LEGAL-P1-02 as source_resolved; no new confirmed P0/P1 in this increment. New native link taps/blank-area hits remain runtime not_verified.
