import XCTest

/// Exercises the shipping root and real local draft; no model response fixtures.
@MainActor
final class V4NavigationUITests: XCTestCase {
    private var app: XCUIApplication!
    private var originalDraft = ""
    private var editedDraft = false

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.solocompass.app")
        app.launchArguments = ["-devSkipOnboarding", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment["FF_CONTINUOUS_COMPANION"] = "1"
        app.launch()
        XCTAssertTrue(tab("now").waitForExistence(timeout: 25))
        originalDraft = draft.value as? String ?? ""
        if originalDraft == draft.placeholderValue { originalDraft = "" }
    }

    override func tearDownWithError() throws {
        if app != nil {
            dismissKeyboard()
            if editedDraft {
                tab("now").tap()
                try replaceDraft(originalDraft)
                editedDraft = false
                dismissKeyboard()
            }
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "v4-final-native-screen"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    private var draft: XCUIElement { app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch }
    private func tab(_ name: String) -> XCUIElement { app.buttons["companion.surface.\(name)"].firstMatch }
    private func dismissKeyboard() {
        let dismiss = app.buttons["companion.keyboard.dismiss"].firstMatch
        if dismiss.exists { dismiss.tap() }
    }
    private func replaceDraft(_ value: String) throws {
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        let current = draft.value as? String ?? ""
        draft.tap()
        if !current.isEmpty && current != draft.placeholderValue {
            draft.press(forDuration: 1)
            let candidates = [app.menuItems["全选"], app.buttons["全选"],
                              app.menuItems["Select All"], app.buttons["Select All"]]
            guard let selectAll = candidates.first(where: { $0.waitForExistence(timeout: 1) }) else {
                if editedDraft { XCTFail("Cannot safely select all to restore the original draft") }
                throw XCTSkip("Native Select All is unavailable; no further text was inserted")
            }
            selectAll.tap()
        }
        draft.typeText(value.isEmpty ? XCUIKeyboardKey.delete.rawValue : value)
        editedDraft = true
    }

    func testFourDestinationsPreserveTheUnsentDraft() throws {
        XCTAssertTrue(tab("now").isSelected)
        for name in ["now", "nearby", "itinerary", "me"] {
            XCTAssertTrue(tab(name).exists)
            XCTAssertGreaterThanOrEqual(tab(name).frame.height, 44)
        }
        let marker = "V4 unsent draft stays with the conversation"
        try replaceDraft(marker)
        XCTAssertEqual(draft.value as? String, marker)
        dismissKeyboard()
        for name in ["nearby", "itinerary", "me", "nearby", "now"] {
            XCTAssertTrue(tab(name).waitForExistence(timeout: 5))
            tab(name).tap()
            XCTAssertTrue(tab(name).isSelected)
        }
        XCTAssertEqual(draft.value as? String, marker)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "v4-four-tabs-draft-restored"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
