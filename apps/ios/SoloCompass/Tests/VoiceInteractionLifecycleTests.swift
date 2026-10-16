import XCTest
@testable import SoloCompass

/// Lifecycle regression tests for the voice button's injectable decision logic
/// (contract 4). No microphone, no permission prompt — tests drive the
/// permission resolution token manually, exactly like the late-callback
/// scenarios the button must survive.
@MainActor
final class VoiceInteractionLifecycleTests: XCTestCase {

    // MARK: - Release before auth

    func testReleaseBeforePermissionNeverStartsLate() {
        let lifecycle = VoiceInteractionLifecycle()
        guard case .requestPermission(let token) = lifecycle.beginStart() else {
            return XCTFail("a press must start the permission pipeline")
        }

        // Finger lifts while the system prompt is still up.
        XCTAssertEqual(lifecycle.pressReleased(), .none)

        // The permission prompt resolves AFTER the release — recording must
        // not start; there is no press holding the button anymore.
        XCTAssertEqual(lifecycle.permissionResolved(token: token, granted: true), .none)
        XCTAssertFalse(lifecycle.isRecording)
    }

    // MARK: - Disappearance / background

    func testDisappearanceStopsRecordingWithoutSending() {
        let lifecycle = VoiceInteractionLifecycle()
        let token = startAndGrant(lifecycle)
        XCTAssertNotNil(token)
        XCTAssertTrue(lifecycle.isRecording)

        XCTAssertEqual(lifecycle.visibilityChanged(false), .stopWithoutSending)
        XCTAssertFalse(lifecycle.isRecording, "leaving the screen stops recording")
    }

    func testBackgroundingStopsRecordingWithoutSending() {
        let lifecycle = VoiceInteractionLifecycle()
        _ = startAndGrant(lifecycle)

        XCTAssertEqual(lifecycle.sceneActivityChanged(false), .stopWithoutSending)
        XCTAssertFalse(lifecycle.isRecording)
    }

    func testLatePermissionAfterBackgroundIsRejected() {
        let lifecycle = VoiceInteractionLifecycle()
        guard case .requestPermission(let token) = lifecycle.beginStart() else {
            return XCTFail("expected a permission request")
        }
        XCTAssertEqual(lifecycle.sceneActivityChanged(false), .none)
        XCTAssertEqual(
            lifecycle.permissionResolved(token: token, granted: true),
            .none,
            "a grant landing after backgrounding must not start recording"
        )
        XCTAssertFalse(lifecycle.isRecording)
    }

    func testHiddenViewNeverStarts() {
        let lifecycle = VoiceInteractionLifecycle()
        _ = lifecycle.visibilityChanged(false)
        XCTAssertEqual(lifecycle.beginStart(), .none)
        XCTAssertFalse(lifecycle.wantsRecording)
    }

    // MARK: - VoiceOver default activation

    func testAccessibilityToggleStartsAndStopsAsAdvertised() {
        let lifecycle = VoiceInteractionLifecycle()
        guard case .requestPermission(let token) = lifecycle.accessibilityToggle() else {
            return XCTFail("double-tap must start recording")
        }
        XCTAssertEqual(lifecycle.permissionResolved(token: token, granted: true), .startRecording(token: token))
        XCTAssertTrue(lifecycle.isRecording)

        // Second activation stops and delivers — the hint's promise.
        XCTAssertEqual(lifecycle.accessibilityToggle(), .stopAndSend)
        XCTAssertFalse(lifecycle.isRecording)
    }

    func testAccessibilityToggleCancelsAPendingStartOnSecondActivation() {
        let lifecycle = VoiceInteractionLifecycle()
        guard case .requestPermission(let token) = lifecycle.accessibilityToggle() else {
            return XCTFail("expected a permission request")
        }
        XCTAssertEqual(lifecycle.accessibilityToggle(), .none, "second activation cancels, not stacks")
        XCTAssertEqual(lifecycle.permissionResolved(token: token, granted: true), .none)
        XCTAssertFalse(lifecycle.isRecording)
    }

    // MARK: - Permission denial

    func testDenialSurfacesOnceAndStaysIdle() {
        let lifecycle = VoiceInteractionLifecycle()
        guard case .requestPermission(let token) = lifecycle.beginStart() else {
            return XCTFail("expected a permission request")
        }
        XCTAssertEqual(lifecycle.permissionResolved(token: token, granted: false), .permissionDenied)
        XCTAssertFalse(lifecycle.isRecording)
        XCTAssertFalse(lifecycle.wantsRecording)
        // A stale (already-handled) resolution is inert.
        XCTAssertEqual(lifecycle.permissionResolved(token: token, granted: false), .none)
    }

    // MARK: - Send vs discard

    func testPointerReleaseSendsRecording() {
        let lifecycle = VoiceInteractionLifecycle()
        _ = startAndGrant(lifecycle)
        XCTAssertEqual(lifecycle.pressReleased(), .stopAndSend)
        XCTAssertFalse(lifecycle.isRecording)
    }

    func testSlideCancelDiscards() {
        let lifecycle = VoiceInteractionLifecycle()
        _ = startAndGrant(lifecycle)
        XCTAssertEqual(lifecycle.cancelRequested(), .stopWithoutSending)
    }

    func testAutoStopKeepsExistingSendBehavior() {
        let lifecycle = VoiceInteractionLifecycle()
        _ = startAndGrant(lifecycle)
        XCTAssertEqual(lifecycle.autoStopElapsed(), .stopAndSend)
    }

    func testAutoStopWhenIdleIsInert() {
        let lifecycle = VoiceInteractionLifecycle()
        XCTAssertEqual(lifecycle.autoStopElapsed(), .none)
    }

    // MARK: - Duplicate starts + stale tokens

    func testSecondStartWhileRecordingIsInert() {
        let lifecycle = VoiceInteractionLifecycle()
        _ = startAndGrant(lifecycle)
        XCTAssertEqual(lifecycle.beginStart(), .none, "no double pipeline while recording")
    }

    func testSupersededTokenCannotStart() {
        let lifecycle = VoiceInteractionLifecycle()
        guard case .requestPermission(let first) = lifecycle.beginStart() else {
            return XCTFail("expected a permission request")
        }
        guard case .requestPermission(let second) = lifecycle.beginStart() else {
            return XCTFail("expected a second permission request")
        }
        XCTAssertEqual(lifecycle.permissionResolved(token: first, granted: true), .none)
        XCTAssertEqual(lifecycle.permissionResolved(token: second, granted: true), .startRecording(token: second))
        XCTAssertTrue(lifecycle.isRecording)
    }

    func testRetainedViewCanStartAfterReappearing() {
        let lifecycle = VoiceInteractionLifecycle()
        _ = lifecycle.visibilityChanged(false)
        XCTAssertEqual(lifecycle.beginStart(), .none)
        _ = lifecycle.visibilityChanged(true)
        _ = lifecycle.sceneActivityChanged(true)
        XCTAssertNotNil(startAndGrant(lifecycle))
    }

    // MARK: - Helper

    @discardableResult
    private func startAndGrant(_ lifecycle: VoiceInteractionLifecycle) -> Int? {
        guard case .requestPermission(let token) = lifecycle.beginStart() else { return nil }
        XCTAssertEqual(lifecycle.permissionResolved(token: token, granted: true), .startRecording(token: token))
        return token
    }
}

@MainActor
final class VoiceCaptureGenerationTests: XCTestCase {
    func testOldTerminationCannotStopNewCapture() {
        var generation = VoiceCaptureGeneration()
        let old = generation.begin()
        let current = generation.begin()
        XCTAssertFalse(generation.isCurrent(old))
        XCTAssertFalse(generation.finish(token: old))
        XCTAssertTrue(generation.isCurrent(current))
        XCTAssertTrue(generation.finish(token: current))
        XCTAssertFalse(generation.isCurrent(current))
    }

    func testCanceledSpeechGrantDoesNotContinueToMicrophonePrompt() async {
        var speech: CheckedContinuation<Bool, Never>?
        var microphoneCalls = 0
        let permissions = PermissionRequester(
            requestSpeechAuthorization: {
                await withCheckedContinuation { speech = $0 }
            },
            requestMicrophonePermission: {
                microphoneCalls += 1
                return true
            }
        )
        let service = VoiceService(permissions: permissions)
        let request = Task { await service.requestPermission() }
        while speech == nil { await Task.yield() }
        request.cancel()
        speech?.resume(returning: true)
        let granted = await request.value
        XCTAssertFalse(granted)
        XCTAssertEqual(microphoneCalls, 0)
    }
}
