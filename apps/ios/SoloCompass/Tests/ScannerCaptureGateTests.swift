import XCTest
@testable import SoloCompass

final class ScannerCaptureGateTests: XCTestCase {
    func testLatePermissionAfterLeavingCannotStartQueuedCapture() {
        let gate = ScannerCaptureGate()
        gate.update(visible: true, foreground: true, authorized: false)
        XCTAssertFalse(gate.isAllowed)
        var starts = 0
        let queuedStart = { if gate.isAllowed { starts += 1 } }
        gate.update(visible: false, foreground: true, authorized: true)
        queuedStart()
        XCTAssertEqual(starts, 0)
    }

    func testQueuedStartRechecksBackgroundState() {
        let gate = ScannerCaptureGate()
        gate.update(visible: true, foreground: true, authorized: true)
        XCTAssertTrue(gate.isAllowed)
        gate.update(visible: true, foreground: false, authorized: true)
        XCTAssertFalse(gate.isAllowed)
        gate.update(visible: true, foreground: true, authorized: true)
        XCTAssertTrue(gate.isAllowed)
    }

    func testVisibilityDoesNotReplaceAuthorization() {
        let gate = ScannerCaptureGate()
        gate.update(visible: true, foreground: true, authorized: false)
        XCTAssertFalse(gate.isAllowed)
        gate.update(visible: false, foreground: true, authorized: true)
        XCTAssertFalse(gate.isAllowed)
    }
}
