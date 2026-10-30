# GET-338 verification

Branch: `codex/get-338-smooth-chat-and-me`.

## Host evidence

The optimized macOS executable compiles the shipping Store, timeline, snapshot writer/encoder, shared runtime models/policy and device memory. Only AI/Experience transport dependencies are controlled. It uses an isolated temporary directory; no real account, conversation or simulator is modified.

The same synthetic 5,000-message, 3,696,482-byte history showed a typing median of 47.2475 ms before the change and 0.172708 ms after it. Timing varies with shared-host load. This measures draft persistence, not native frame rate. A valid distinct tool-checkpoint benchmark improved from 23.853166 ms to 5.023625 ms median while retaining atomic receipt writes.

`companion-chat-host.sh`: 51 checks, zero failures. Includes fresh-draft recovery, pending-send restart, double tap, storage failure/retry, cancellation, clearing, media references, unknown sidecars, receipt ordering and scroll intent. A strict-concurrency module build also typechecks the added XCTest and data-management suite.

Regression evidence includes two observed failures fixed by this change: restart during gated acceptance lost the original after newer input; an old encoder starting after clear repopulated the in-memory cache. Both have deterministic gated regression checks. Fixture writer: six Python tests passed, including rejecting real history, credentials and redirected staging paths.

## Native acceptance

`ChatAndMeUITests.swift` is compiled by the existing AccountAcceptance target. CI retains the full unit, onboarding and V4 navigation suites, then seeds only its own ephemeral app/device. It exercises 5,000 messages, rapid scrolling, sending from history, keyboard/new-draft retention, Me navigation, light/empty profile and a dark/populated profile at the largest accessibility size. XCTest records scrolling/deceleration, CPU and memory metrics without a fabricated FPS threshold.

The fixture helper refuses local execution and unmarked existing history. Simulator preference writes occur only while the exact CI-owned device is shut down. Native results, attachments and fixture receipts are uploaded as `chat-performance-and-me`; host metrics as `companion-chat-host`.

Native execution and visual inspection are pending at this revision. Physical-device frame rate, live provider responses, production deployment and TestFlight are outside this evidence.
