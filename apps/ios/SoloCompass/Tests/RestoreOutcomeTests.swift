import XCTest
@testable import SoloCompass

/// I08: paywall restore must surface an honest outcome and never fake an
/// unlock. `RestoreOutcome.resolve` is the exact branch `runRestore` runs
/// against the `SubscriptionService` result, so all three cases are pinned:
///  - confirmed success → `.unlocked` (the only case that may unlock),
///  - no error, nothing restored → `.noPurchases`,
///  - a real attempt error → `.failed(reason)`.
final class RestoreOutcomeTests: XCTestCase {

    func testConfirmedSuccessUnlocksEvenWithStaleLastError() {
        XCTAssertEqual(
            RestoreOutcome.resolve(success: true, lastError: "stale purchase error"),
            .unlocked,
            "A successful restore must unlock regardless of a stale earlier error"
        )
    }

    func testNoPurchasesIsReportedNotSilentlyDropped() {
        let outcome = RestoreOutcome.resolve(success: false, lastError: nil)
        XCTAssertEqual(outcome, .noPurchases)
        guard case .noPurchases = outcome else { return XCTFail("expected .noPurchases") }
        XCTAssertNotNil(outcome.message, "an empty restore must tell the user what happened")
    }

    func testAttemptErrorCarriesTheReason() {
        let outcome = RestoreOutcome.resolve(success: false, lastError: "network down")
        XCTAssertEqual(outcome, .failed("network down"))
        guard case .failed(let reason) = outcome else { return XCTFail("expected .failed") }
        XCTAssertTrue(reason.contains("network down"), "the failure message must include the reason")
    }

    /// The composer must be able to tell the states apart: only `.unlocked`
    /// has no message (the sheet dismisses), the other two must be readable.
    func testFailureStatesCarryDistinctReadableMessages() {
        let none = RestoreOutcome.noPurchases.message
        let failed = RestoreOutcome.failed("boom").message
        XCTAssertNotNil(none)
        XCTAssertNotNil(failed)
        XCTAssertNotEqual(none, failed)
        XCTAssertNil(RestoreOutcome.unlocked.message)
    }
}
