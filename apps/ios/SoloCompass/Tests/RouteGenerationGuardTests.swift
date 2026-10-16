import XCTest
@testable import SoloCompass

/// Stale-generation guard for CreateRouteView (contract 2 / R2-07): a slow
/// response must never silently overwrite newer user edits; results become
/// explicit, user-adopted suggestions instead. Cancel and re-generation
/// invalidate in-flight attempts.
@MainActor
final class RouteGenerationGuardTests: XCTestCase {

    func testFreshResultAppliesWhenDraftUnchanged() {
        let guard_ = RouteGenerationGuard()
        let attempt = guard_.beginAttempt()
        XCTAssertEqual(attempt.attempt, 1)
        XCTAssertEqual(attempt.versionAtStart, 0)

        XCTAssertTrue(guard_.isApplicable(attempt: attempt.attempt, versionAtStart: attempt.versionAtStart))
    }

    func testUserEditDuringGenerationMakesResultStale() {
        let guard_ = RouteGenerationGuard()
        let attempt = guard_.beginAttempt()

        guard_.noteUserEdit() // the traveler picked stops while the model ran

        XCTAssertFalse(
            guard_.isApplicable(attempt: attempt.attempt, versionAtStart: attempt.versionAtStart),
            "A result after a user edit must be offered for explicit adoption, not applied"
        )
    }

    func testCancelInvalidatesInFlightAttempt() {
        let guard_ = RouteGenerationGuard()
        let attempt = guard_.beginAttempt()
        guard_.cancelAttempt()

        XCTAssertFalse(guard_.isApplicable(attempt: attempt.attempt, versionAtStart: attempt.versionAtStart))
    }

    func testNewAttemptSupersedesPrevious() {
        let guard_ = RouteGenerationGuard()
        let first = guard_.beginAttempt()
        let second = guard_.beginAttempt()

        XCTAssertNotEqual(first.attempt, second.attempt)
        XCTAssertFalse(guard_.isApplicable(attempt: first.attempt, versionAtStart: first.versionAtStart),
                       "A superseded attempt must not land later")
        XCTAssertTrue(guard_.isApplicable(attempt: second.attempt, versionAtStart: second.versionAtStart))
    }

    func testZeroAttemptIsNeverApplicable() {
        let guard_ = RouteGenerationGuard()
        XCTAssertFalse(guard_.isApplicable(attempt: 0, versionAtStart: 0))
    }

    func testEditAfterResultStillCountsAgainstNewAttempt() {
        let guard_ = RouteGenerationGuard()
        let first = guard_.beginAttempt()
        XCTAssertTrue(guard_.isApplicable(attempt: first.attempt, versionAtStart: first.versionAtStart))

        guard_.noteUserEdit()
        // A second generation snapshots the NEW version and applies cleanly.
        let second = guard_.beginAttempt()
        XCTAssertEqual(second.versionAtStart, 1)
        XCTAssertTrue(guard_.isApplicable(attempt: second.attempt, versionAtStart: second.versionAtStart))
    }
}
