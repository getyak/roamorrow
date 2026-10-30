import XCTest

/// Shipping views with an externally seeded, explicitly owned CI fixture.
/// Host tests cover incoming/IO races; these tests exercise native scroll/input.
@MainActor
final class ChatAndMeUITests: XCTestCase {
    private var app: XCUIApplication!
    private let lastID = "61000000-0000-0000-0000-000000001388"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.solocompass.app")
    }

    override func tearDownWithError() throws {
        capture("final-screen")
        app.terminate()
    }

    private func launch(large: Bool = false, dark: Bool = false) {
        app.launchArguments = ["-devSkipOnboarding", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-AppleInterfaceStyle", dark ? "Dark" : "Light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment["FF_CONTINUOUS_COMPANION"] = "1"
        app.launch()
        XCTAssertTrue(tab("now").waitForExistence(timeout: 30))
        let latest = app.buttons["companion.stream.latest"].firstMatch
        if latest.waitForExistence(timeout: 1) { latest.tap() }
    }

    private func tab(_ id: String) -> XCUIElement { app.buttons["companion.surface.\(id)"].firstMatch }
    private var stream: XCUIElement { app.scrollViews["companion.stream"].firstMatch }
    private var composer: XCUIElement { app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    private func capture(_ name: String) {
        guard app != nil else { return }
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "get338-" + name
        image.lifetime = .keepAlways
        add(image)
    }

    func testLongHistoryScrollAndSendRetainTheNewDraftAndKeyboard() throws {
        launch()
        let last = element("companion.message.\(lastID)")
        XCTAssertTrue(last.waitForExistence(timeout: 20))
        XCTAssertTrue(last.isHittable)
        let marker = "[native send] keep scrolling with 5000 messages"
        composer.tap()
        composer.typeText(marker)
        for _ in 0..<3 { stream.swipeDown(velocity: .fast) }
        XCTAssertEqual(composer.value as? String, marker)
        XCTAssertFalse(last.isHittable)
        capture("history-with-draft")
        // Interactive scrolling is allowed to dismiss the keyboard. Explicitly
        // resume composing before testing that send itself keeps it open.
        composer.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(last.isHittable)
        let started = Date()
        app.buttons["companion.send"].tap()
        let sent = app.staticTexts[marker].firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 5))
        XCTAssertTrue(sent.isHittable)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertNotEqual(composer.value as? String, marker)
        print("GET338 bridge-inclusive send-to-visible seconds: \(Date().timeIntervalSince(started))")
        composer.tap()
        composer.typeText("[native draft] next message")
        app.buttons["companion.keyboard.dismiss"].tap()
        tab("me").tap()
        tab("now").tap()
        XCTAssertEqual(composer.value as? String, "[native draft] next message")
        capture("sent-with-next-draft")
    }

    func testLongHistoryNativeScrollingMetrics() {
        launch()
        XCTAssertTrue(element("companion.message.\(lastID)").waitForExistence(timeout: 20))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric,
                          XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            stream.swipeDown(velocity: .fast)
            stream.swipeDown(velocity: .fast)
            stream.swipeUp(velocity: .fast)
        }
        capture("scroll-metrics")
    }

    func testMeEmptyHubAndWorkingExploreAction() {
        launch()
        tab("me").tap()
        XCTAssertTrue(element("me.profile.edit").waitForExistence(timeout: 8))
        XCTAssertTrue(element("me.archive").exists)
        capture("me-light-empty")
        let explore = app.buttons["me.explore"].firstMatch
        for _ in 0..<4 where !explore.isHittable { app.swipeUp() }
        XCTAssertTrue(explore.isHittable)
        explore.tap()
        XCTAssertTrue(tab("nearby").isSelected)
        tab("me").tap()
        let archive = element("me.archive")
        for _ in 0..<4 where !archive.isHittable { app.swipeDown() }
        archive.tap()
        XCTAssertTrue(app.navigationBars["旅行档案"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["me.settings.toolbar"].tap()
        XCTAssertTrue(app.navigationBars["偏好"].waitForExistence(timeout: 8))
    }

    /// Run separately after the populated/long-name fixture is installed.
    func testMeLongNameLargeTypeAndDarkAppearance() {
        launch(large: true, dark: true)
        tab("me").tap()
        XCTAssertTrue(element("me.profile.edit").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["一个带着很长昵称慢慢旅行的人 · 界面演示"].exists)
        let profile = element("me.profile.edit")
        XCTAssertGreaterThanOrEqual(profile.frame.width, 44)
        XCTAssertGreaterThan(profile.frame.height, 160)
        XCTAssertLessThanOrEqual(profile.frame.maxX, app.frame.maxX + 1)
        capture("me-dark-accessibility-long-name")
        let archive = element("me.archive")
        for _ in 0..<6 where !archive.isHittable { app.swipeUp() }
        XCTAssertTrue(archive.isHittable)
        XCTAssertGreaterThanOrEqual(archive.frame.height, 44)
        archive.tap()
        XCTAssertTrue(app.navigationBars["旅行档案"].waitForExistence(timeout: 8))
    }
}
