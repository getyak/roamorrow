# GET-338 verification

Branch: `codex/get-338-smooth-chat-and-me`.

## Host evidence

The optimized macOS executable compiles the shipping Store, timeline, snapshot writer/encoder, shared runtime models/policy and device memory. Only AI/Experience transport dependencies are controlled. It uses an isolated temporary directory; no real account, conversation or simulator is modified.

The same synthetic 5,000-message, 3,696,482-byte history showed a typing median of 47.2475 ms before the change and 0.172708 ms after it. Timing varies with shared-host load. This measures draft persistence, not native frame rate. A valid distinct tool-checkpoint benchmark improved from 23.853166 ms to 5.023625 ms median while retaining atomic receipt writes.

`companion-chat-host.sh` prints the current check count and produces metrics. It covers fresh-draft recovery, pending-send restart, double tap, storage failure/retry, cancellation, clearing, media references, unknown sidecars, receipt ordering, source restoration and scroll intent. Set `COMPANION_CHAT_TYPECHECK_TESTS=1` to also typecheck the added XCTest and data-management suite with complete concurrency checking.

Regression evidence includes two observed failures fixed by this change: restart during gated acceptance lost the original after newer input; an old encoder starting after clear repopulated the in-memory cache. Both have deterministic gated regression checks. Fixture writer: six Python tests passed, including rejecting real history, credentials and redirected staging paths.

## Native acceptance

`ChatAndMeUITests.swift` is compiled by the existing AccountAcceptance target. CI retains the full unit, onboarding and V4 navigation suites, then seeds only its own ephemeral app/device. It exercises a cold first swipe without the keyboard, 5,000 messages, rapid scrolling, sending from history, keyboard/new-draft retention, Me navigation, light/empty profile and a dark/populated profile at the largest accessibility size. XCTest records scrolling/deceleration, CPU and memory metrics without a fabricated FPS threshold. Each interval stops before explicitly returning to the tail, so samples start on the same rows. The cold control performs no warm-up gesture.

The send case also checks that composer line wrapping keeps the tail visible before scrolling into history. Debug builds emit constant-size phase/request booleans through the `com.solocompass.chat-scroll` OSLog subsystem; CI captures only that subsystem on its own device and closes its owned log stream at step exit. The trace contains no message text, identities, anchor IDs, credentials or travel data.

On iOS 18+, visible target IDs are passive observations, selected using cached row order rather than a two-way positioning binding. Programmatic restoration uses the cancellable proxy queue, including initial saved-history restoration; pending explicit sends retain priority until consumed. Empty visibility preserves the previous anchor. iOS 17 retains its compatible binding path and is not covered by modern-system simulator acceptance.

The first performance run exposed a real main-thread layout loop: a five-second spindump recorded 4.99 seconds of CPU in graph/lazy-layout updates. Reading checkpoints were still observable from the conversation initializer, subscribing the parent view to native scroll progress. A deterministic Observation regression reproduced that invalidation; checkpoints now remain durable without publishing display invalidations. Initial placement and short-content alignment are separate from content-size anchoring on iOS 18+. The failed native interval remains a gate; timeout and metric collection are retained.

The fixture helper refuses local execution and unmarked existing history. Simulator preference writes occur only while the exact CI-owned device is shut down. Native results, attachments and fixture receipts are uploaded as `chat-performance-and-me`; host metrics as `companion-chat-host`.

The linked PR records the latest native execution and visual-inspection evidence for its exact tested head. This host record alone does not establish native smoothness. Physical-device frame rate, live provider responses, production deployment and TestFlight are outside this evidence.
