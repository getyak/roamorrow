import Foundation

// MARK: - RouteGenerationGuard

/// Token guard for the create-route AI generation loop (R2-07).
///
/// A generation runs while the user keeps editing the draft. Without a guard,
/// a slow response lands minutes later and silently overwrites newer stop
/// picks / order / pace. The guard tracks:
///
///   - **draftVersion** — bumped on every user edit;
///   - **attempt** — bumped on every (re)generation; `cancelAttempt()` (save,
///     dismiss, re-generate) invalidates the in-flight attempt.
///
/// A result may only auto-apply when it is still the active attempt AND the
/// draft has not been edited since the attempt began. Anything else is stale:
/// the caller keeps it as an explicit, user-adoptable suggestion instead of
/// writing it into the draft. Pure logic — lifecycle regression tests drive it
/// without SwiftUI or network.
@MainActor
public final class RouteGenerationGuard {
    /// Bumped whenever the user edits the draft (stops, title, pace).
    public private(set) var draftVersion: Int = 0
    /// Identifier of the in-flight attempt; 0 when none is active.
    public private(set) var activeAttempt: Int = 0

    private var attemptCounter: Int = 0

    public init() {}

    /// Record a user edit. Any in-flight attempt is now stale.
    public func noteUserEdit() {
        draftVersion += 1
    }

    /// Begin a generation attempt, invalidating any previous one.
    /// Returns the new attempt id and the draft version it started from.
    public func beginAttempt() -> (attempt: Int, versionAtStart: Int) {
        attemptCounter += 1
        activeAttempt = attemptCounter
        return (attemptCounter, draftVersion)
    }

    /// Cancel the in-flight attempt (save, dismiss, replace with a new one).
    public func cancelAttempt() {
        activeAttempt = 0
    }

    /// True only when the result of `attempt` (started at `versionAtStart`)
    /// may auto-apply to the current draft. Stale when the attempt was
    /// cancelled/superseded or when the user edited the draft since.
    public func isApplicable(attempt: Int, versionAtStart: Int) -> Bool {
        attempt != 0 && attempt == activeAttempt && versionAtStart == draftVersion
    }

    /// Attempt IDENTITY only (review closure 1): true while `attempt` is still
    /// the in-flight attempt. Checked separately from `draftVersion` so a
    /// superseded attempt writes NOTHING back (neither apply nor adoption),
    /// while the CURRENT attempt whose draft moved on can still offer its
    /// result for explicit adoption.
    public func isCurrent(attempt: Int) -> Bool {
        attempt != 0 && attempt == activeAttempt
    }
}
