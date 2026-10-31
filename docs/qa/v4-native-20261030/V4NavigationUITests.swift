import XCTest

/// Exercises the shipping root. The second case requires explicitly marked CI
/// local history and real bundled IDs; neither case sends a model request.
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
    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let data = try! JSONSerialization.data(withJSONObject: ["scene": name, "epoch": Date().timeIntervalSince1970])
        let timing = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        timing.name = name + "-timing"
        timing.lifetime = .keepAlways
        add(timing)
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
            XCTAssertLessThanOrEqual(tab(name).frame.height, 50)
        }
        let marker = "V4 unsent draft stays with the conversation"
        try replaceDraft(marker)
        XCTAssertEqual(draft.value as? String, marker)
        dismissKeyboard()
        for name in ["nearby", "itinerary", "me", "nearby", "now"] {
            XCTAssertTrue(tab(name).waitForExistence(timeout: 5))
            tab(name).tap()
            XCTAssertTrue(tab(name).isSelected)
            capture("v4-destination-\(name)")
        }
        XCTAssertEqual(draft.value as? String, marker)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "v4-four-tabs-draft-restored"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testAgentNameAndStyleSurviveRestartAndCancelledEdits() throws {
        guard originalDraft == "V4 fixture draft" else {
            throw XCTSkip("Identity editing requires the isolated CI UI fixture")
        }
        let title = app.buttons["companion.keyboard.dismiss"].firstMatch
        let originalName = title.label
        app.buttons["companion.identity.open"].tap()
        let styles = ["moss", "pixel", "moon", "landscape"]
        let originalStyle = try XCTUnwrap(styles.first {
            app.buttons["companion.identity.style.\($0)"].isSelected
        })
        for style in styles {
            app.buttons["companion.identity.style.\(style)"].tap()
            capture("identity-style-\(style)")
        }
        func editName(_ value: String) {
            let field = app.textFields["companion.identity.name"].firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            let old = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + value)
        }
        editName("沿途小伴")
        app.buttons["companion.identity.style.pixel"].tap()
        capture("identity-pixel-editor")
        app.buttons["companion.identity.save"].tap()
        XCTAssertEqual(title.label, "沿途小伴")
        XCTAssertEqual(draft.value as? String, originalDraft)
        capture("identity-compact-header")

        app.terminate()
        app.launch()
        XCTAssertTrue(title.waitForExistence(timeout: 25))
        XCTAssertEqual(title.label, "沿途小伴")
        app.buttons["companion.identity.open"].tap()
        XCTAssertTrue(app.buttons["companion.identity.style.pixel"].isSelected)
        editName("取消这次")
        app.buttons["取消"].tap()
        XCTAssertEqual(title.label, "沿途小伴")

        app.buttons["companion.identity.open"].tap()
        editName(originalName)
        app.buttons["companion.identity.style.\(originalStyle)"].tap()
        app.buttons["companion.identity.save"].tap()
        XCTAssertEqual(title.label, originalName)
        XCTAssertEqual(draft.value as? String, originalDraft)

        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(title.waitForExistence(timeout: 25))
        XCTAssertTrue(app.buttons["companion.identity.open"].isHittable)
        capture("identity-large-type-header")
        app.buttons["companion.identity.open"].tap()
        XCTAssertTrue(app.textFields["companion.identity.name"].waitForExistence(timeout: 5))
        capture("identity-large-type-editor")
        app.buttons["取消"].tap()
    }

    func testSourceMapFavoriteScopeAndReadingReturn() throws {
        guard originalDraft == "V4 fixture draft" else {
            throw XCTSkip("Source round trip requires the explicitly seeded public CI UI fixture")
        }
        let placeID = "exp_cmi_bookstore_work"
        let sourceID = "40000000-0000-0000-0000-000000000005"
        let source = app.buttons["companion.message.map.\(sourceID).\(placeID)"]
        let stream = app.scrollViews["companion.stream"]
        for _ in 0..<8 {
            if source.exists && source.isHittable { break }
            stream.swipeDown()
        }
        XCTAssertTrue(source.isHittable, "The fixture source must be visibly readable before opening the map")
        capture("v4-source-reading")
        source.tap()
        XCTAssertTrue(tab("nearby").isSelected)
        let save = app.buttons["companion.panel.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        let wasSaved = save.isSelected
        capture("v4-source-on-native-map")
        if !wasSaved { save.tap() }
        XCTAssertTrue(save.isSelected)
        let savedMode = app.buttons["map.workspace.mode.saved"]
        savedMode.tap()
        XCTAssertTrue(savedMode.isSelected)
        let savedPlace = app.buttons["companion.nearby.place.\(placeID)"]
        XCTAssertTrue(savedPlace.waitForExistence(timeout: 5))
        capture("v4-saved-collection")
        savedPlace.tap()
        let ask = app.buttons["companion.map.askPlace"]
        XCTAssertTrue(ask.waitForExistence(timeout: 5))
        ask.tap()
        let scope = app.descendants(matching: .any).matching(identifier: "companion.scope.next").firstMatch
        XCTAssertTrue(scope.waitForExistence(timeout: 5))
        XCTAssertEqual(draft.value as? String, "V4 fixture draft")
        capture("v4-place-scope-with-preserved-draft")
        app.buttons["companion.scope.clear"].tap()
        XCTAssertFalse(scope.exists)
        dismissKeyboard()
        XCTAssertTrue(tab("now").isSelected)
        XCTAssertTrue(source.isHittable, "Returning from the map must restore the historical source rather than the newest message")
        capture("v4-original-reading-restored")

        // Restore only the favorite introduced by this case. The fixture never
        // authorizes changing an already-saved place in a developer profile.
        tab("nearby").tap()
        if !wasSaved {
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            XCTAssertTrue(save.isSelected)
            save.tap()
            XCTAssertFalse(savedPlace.exists)
            capture("v4-final-unsave-clears-selection")
        }
        let returnSource = app.buttons["map.workspace.source.return"]
        XCTAssertTrue(returnSource.waitForExistence(timeout: 5))
        returnSource.tap()
        XCTAssertTrue(source.isHittable)
        XCTAssertEqual(draft.value as? String, "V4 fixture draft")
        app.terminate()
        app.launch()
        XCTAssertTrue(tab("now").waitForExistence(timeout: 25))
        XCTAssertEqual(draft.value as? String, "V4 fixture draft")
        XCTAssertTrue(source.isHittable, "A native relaunch must restore the persisted historical reading position")
        capture("v4-native-relaunch-restored")
    }
}
