import XCTest
@testable import SoloCompass

/// I05: the visibility-off alert's "Open Profile Settings" path must recover
/// the interrupted companion-post intent, not dead-end the user.
///
/// `VisibilityOffRecovery.decide` is the branch the sheet's `onDismiss` runs
/// after the user edits (or ignores) their companion visibility. These tests
/// pin the three outcomes:
///  - no interrupted intent → nothing resumes (visiting settings casually
///    never opens the companion-post sheet);
///  - intent + visibility still off → the itinerary stays closed (no fake
///    success);
///  - intent + visibility now on → the interrupted flow resumes.
final class VisibilityOffRecoveryTests: XCTestCase {

    func testNoPendingIntentNeverResumes() {
        XCTAssertEqual(
            VisibilityOffRecovery.decide(visibility: .nearby_and_itinerary, hadPendingIntent: false),
            .none,
            "Opening the profile without an interrupted intent must not start the companion-post flow"
        )
        XCTAssertEqual(
            VisibilityOffRecovery.decide(visibility: .itinerary_only, hadPendingIntent: false),
            .none
        )
    }

    func testStillBlockedKeepsItineraryClosed() {
        XCTAssertEqual(
            VisibilityOffRecovery.decide(visibility: .off, hadPendingIntent: true),
            .stillBlocked,
            "If visibility is still off the flow must not pretend the post opened"
        )
    }

    func testVisibilityTurnedOnResumesInterruptedFlow() {
        XCTAssertEqual(
            VisibilityOffRecovery.decide(visibility: .itinerary_only, hadPendingIntent: true),
            .resumeCompanionPost
        )
        XCTAssertEqual(
            VisibilityOffRecovery.decide(visibility: .nearby_and_itinerary, hadPendingIntent: true),
            .resumeCompanionPost
        )
    }
}
