import XCTest
@testable import SoloCompass

final class VoiceServiceGenerationTests: XCTestCase {
    func testLateTerminationCannotEndReplacementCapture() {
        var generation = VoiceCaptureGeneration()
        let cancelled = generation.begin()
        XCTAssertTrue(generation.finish(token: cancelled))
        let replacement = generation.begin()

        XCTAssertFalse(generation.finish(token: cancelled))
        XCTAssertFalse(generation.isCurrent(cancelled))
        XCTAssertTrue(generation.isCurrent(replacement))
    }

    func testLateResultsAreRejectedAfterStop() {
        var generation = VoiceCaptureGeneration()
        let capture = generation.begin()
        XCTAssertTrue(generation.isCurrent(capture))
        XCTAssertTrue(generation.finish(token: capture))

        XCTAssertFalse(generation.isCurrent(capture))
        XCTAssertFalse(generation.finish(token: capture))
        XCTAssertNil(generation.current)
    }

    func testStartingAgainInvalidatesOldResults() {
        var generation = VoiceCaptureGeneration()
        let old = generation.begin()
        let current = generation.begin()

        XCTAssertNotEqual(old, current)
        XCTAssertFalse(generation.isCurrent(old))
        XCTAssertTrue(generation.isCurrent(current))
    }

    @MainActor
    func testCancelledSpeechPromptDoesNotProceedToMicrophone() async {
        let counter = MicrophoneRequestCounter()
        let voice = VoiceService(permissions: PermissionRequester(
            requestSpeechAuthorization: {
                withUnsafeCurrentTask { $0?.cancel() }
                return true
            },
            requestMicrophonePermission: {
                counter.count += 1
                return true
            }
        ))

        let granted = await Task { await voice.requestPermission() }.value

        XCTAssertFalse(granted)
        XCTAssertEqual(counter.count, 0)
    }

    @MainActor
    func testCancelledMicrophonePromptDoesNotAuthorizeRecording() async {
        let voice = VoiceService(permissions: PermissionRequester(
            requestSpeechAuthorization: { true },
            requestMicrophonePermission: {
                withUnsafeCurrentTask { $0?.cancel() }
                return true
            }
        ))

        let granted = await Task { await voice.requestPermission() }.value

        XCTAssertFalse(granted)
    }
}

@MainActor
private final class MicrophoneRequestCounter {
    var count = 0
}
