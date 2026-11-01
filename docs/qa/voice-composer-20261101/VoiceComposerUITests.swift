import XCTest

/// Run only against an owned Simulator app container. Audio uses the real
/// recorder; successful speech recognition remains a separate device check.
@MainActor
final class VoiceComposerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-devSkipOnboarding", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if name.contains("LargeType") {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment["FF_CONTINUOUS_COMPANION"] = "1"
        app.launch()
        XCTAssertTrue(button("companion.surface.now").waitForExistence(timeout: 30))
        // Previous cases leave only this owned suite's drafts.
        let removals = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.media.remove.'"))
        for _ in 0..<4 where removals.firstMatch.exists { removals.firstMatch.tap() }
        XCTAssertTrue(button("companion.audio.record").waitForExistence(timeout: 8))
    }

    override func tearDown() async throws {
        capture("final")
        app.terminate()
    }

    private func button(_ id: String) -> XCUIElement { app.buttons[id].firstMatch }
    private var composer: XCUIElement { app.descendants(matching: .any)["companion.composer"].firstMatch }
    private var draftMedia: XCUIElement { app.scrollViews["companion.draft.media"].firstMatch }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "voice-composer-" + name
        image.lifetime = .keepAlways
        add(image)
    }
    private func record() {
        button("companion.audio.record").tap()
        XCTAssertTrue(button("companion.audio.pause").waitForExistence(timeout: 10))
        XCTAssertTrue(button("companion.audio.send").isHittable)
        XCTAssertFalse(composer.exists, "Recording replaces the text input")
        XCTAssertGreaterThanOrEqual(button("companion.audio.pause").frame.width, 44)
        XCTAssertGreaterThanOrEqual(button("companion.audio.send").frame.width, 44)
        let duration = app.staticTexts["companion.audio.duration"].firstMatch
        XCTAssertTrue(duration.exists)
        let savedDuration = "([1-9][0-9]*:[0-5][0-9]|0:(0[1-9]|[1-5][0-9]))"
        expectation(for: NSPredicate(format: "value MATCHES %@", savedDuration), evaluatedWith: duration)
        waitForExpectations(timeout: 5)
        capture("recording")
    }

    func testSendImmediatelySubmitsTheActualRecording() {
        let voices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.audio.play.'"))
        let before = voices.count
        record()
        button("companion.audio.send").tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertFalse(button("companion.audio.pause").exists)
        XCTAssertFalse(draftMedia.exists, "Sending must not stop at an attachment preview")
        XCTAssertTrue(voices.element(boundBy: before).waitForExistence(timeout: 10), "A real audio message reaches the conversation")
        capture("sent")
    }

    func testPauseRetainsRecordingWhenSpeechPermissionIsDenied() {
        record()
        button("companion.audio.pause").tap()
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            let deny = alert.buttons.matching(NSPredicate(format: "label IN %@", ["不允许", "Don't Allow"])).firstMatch
            XCTAssertTrue(deny.exists, "Handle the expected speech permission alert explicitly")
            deny.tap()
        }
        XCTAssertTrue(composer.waitForExistence(timeout: 12))
        XCTAssertTrue(draftMedia.waitForExistence(timeout: 5))
        XCTAssertFalse(button("companion.audio.pause").exists)
        capture("paused-original-retained")
    }

    func testLargeTypeNavigationStopsCaptureAndRetainsOriginal() {
        record()
        button("companion.surface.nearby").tap()
        XCTAssertTrue(button("companion.surface.now").waitForExistence(timeout: 8))
        button("companion.surface.now").tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 8))
        XCTAssertFalse(button("companion.audio.pause").exists)
        XCTAssertTrue(draftMedia.waitForExistence(timeout: 5))
        capture("large-type-retained")
    }
}
