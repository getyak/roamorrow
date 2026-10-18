import Foundation
import Observation

// MARK: - CompletionMomentFlow

/// Decision and side-effect state for the completion moment (parent review,
/// round 2 follow-up).
///
/// Two honest modes:
///
///   - **replay** — the route is already `.completed`. Strictly READ-ONLY: the
///     flow starts in `.celebrating` and NEVER calls the remote. Viewing or
///     replaying must not start a completion write.
///   - **confirm** — the route is `.closed`. Nothing runs on appear. The user
///     presses an explicit confirmation first; only a successful
///     `markCompleted` acknowledgement (the remote's durable write) moves to
///     `.celebrating`. Failures — including a stub remote throwing
///     `NotImplementedError` — stay visible with a retry and claim NOTHING as
///     completed.
///
/// The flow is injectable (remote provider) so lifecycle tests can drive every
/// branch without a UI, network, or simulator.
@Observable
@MainActor
public final class CompletionMomentFlow {
    /// Why the completion attempt failed. Nothing was persisted in either case.
    public enum Failure: Equatable, Sendable {
        /// The remote is a stub / not implemented — the completion was NOT
        /// recorded anywhere and must not be claimed.
        case remoteUnavailable
        /// A real attempt failed (illegal state, persistence, network) — the
        /// route stays as it was.
        case saveFailed
    }

    public enum Phase: Equatable, Sendable {
        /// Waiting for the user's explicit confirmation (closed route).
        case awaitingConfirmation
        /// `markCompleted` in flight.
        case committing
        /// Completion acknowledged (or read-only replay of a completed route).
        case celebrating
        /// The attempt failed — visible, retryable, nothing claimed.
        case failed(Failure)
    }

    /// Current phase. Starts `.celebrating` ONLY for replay mode.
    public private(set) var phase: Phase
    /// True when this flow may write at all (false for replay).
    public let isReplay: Bool
    /// Duplicate-submit guard — one `markCompleted` attempt at a time.
    public private(set) var isCommitting: Bool = false

    private let routeId: RouteId
    private let remoteProvider: @MainActor () -> any RouteCompanionRemote

    /// - Parameters:
    ///   - routeStatus: the companion slot's CURRENT status (nil → treated as
    ///     not completed, so the safe path is confirmation, never a silent write).
    ///   - routeId: the route to complete.
    ///   - remoteProvider: injected remote — tests pass a fake; production
    ///     passes `makeRouteCompanionRemote`.
    public init(
        routeStatus: CompanionStatus?,
        routeId: RouteId,
        remoteProvider: @escaping @MainActor () -> any RouteCompanionRemote
    ) {
        self.routeId = routeId
        self.remoteProvider = remoteProvider
        self.isReplay = routeStatus == .completed
        self.phase = routeStatus == .completed ? .celebrating : .awaitingConfirmation
    }

    /// The user confirmed (or retried). Exactly one remote attempt at a time;
    /// replay mode never writes.
    public func confirmCompletion() async {
        guard !isReplay, !isCommitting else { return }
        isCommitting = true
        phase = .committing
        let remote = remoteProvider()
        do {
            try await remote.markCompleted(routeId: routeId)
            // Durable acknowledgement received — only now is completion real.
            phase = .celebrating
        } catch is NotImplementedError {
            // Stub remote: nothing was completed. Visible retry failure —
            // never a local claim of remote completion.
            phase = .failed(.remoteUnavailable)
        } catch {
            phase = .failed(.saveFailed)
        }
        isCommitting = false
    }

    /// Return from a failure to the confirmation step (the user may also just
    /// retry via `confirmCompletion()`).
    public func dismissFailure() {
        guard case .failed = phase else { return }
        phase = .awaitingConfirmation
    }
}
