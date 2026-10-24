import XCTest

final class StudioFlowTests: XCTestCase {
    @MainActor func testCreateEditRestoreUndoAndExport() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let sample = app.buttons["Try a sample composition"]
        if sample.waitForExistence(timeout: 8) { sample.tap() }
        XCTAssertTrue(app.buttons["Sample coffee"].firstMatch.waitForExistence(timeout: 5))
        saveScreenshot("01-composition")

        app.buttons["Sample coffee"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Make it yours"].waitForExistence(timeout: 3))
        // Geometry editing exercises a real state mutation without keyboard dependencies.
        let scale = app.sliders["Size"]
        XCTAssertTrue(scale.exists)
        scale.adjust(toNormalizedSliderPosition: 0.7)
        saveScreenshot("02-editor")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Undo last change"].isEnabled)

        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Sample coffee"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Sample coffee"].firstMatch.tap()
        XCTAssertTrue(app.sliders["Size"].waitForExistence(timeout: 3))
        XCTAssertNotEqual(app.sliders["Size"].value as? String, "56%")
        app.swipeUp()
        let remove = app.buttons["Remove from this space"]
        if !remove.isHittable { app.swipeUp() }
        remove.tap()
        app.buttons["Undo last change"].tap()
        XCTAssertTrue(app.buttons["Sample coffee"].firstMatch.exists)

        app.buttons["Share composition"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].exists)
        saveScreenshot("03-share")
    }

    @MainActor private func saveScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
