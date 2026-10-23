import XCTest

/// Exercises the shipping module and real persisted app data, without seeded UI responses.
@MainActor
final class CompanionMapPanelUITests: XCTestCase {
    private var app: XCUIApplication!
    private var originalDraft: String?
    private var originalFavorite: Bool?
    private let book = "exp_cmi_bookstore_work"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.solocompass.app")
        app.launchArguments = ["-devSkipOnboarding", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment = ["FF_CONTINUOUS_COMPANION": "1"]
        app.launch()
        XCTAssertTrue(button("companion.surface.nearby").waitForExistence(timeout: 25))
    }
    override func tearDownWithError() throws {
        capture("final-native-screen")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "actual-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
        if let originalDraft {
            button("companion.surface.now").tap()
            let input = app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch
            if input.waitForExistence(timeout: 4) { replace(input, text: originalDraft) }
        }
    }
    private func button(_ id: String) -> XCUIElement { app.buttons.matching(identifier: id).firstMatch }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
    private func tap(_ id: String) {
        let b = button(id)
        XCTAssertTrue(b.waitForExistence(timeout: 8), "Missing "+id)
        if !b.isHittable {
            let panel = app.scrollViews["companion.panel.content"].firstMatch
            for _ in 0..<5 where !b.isHittable {
                if panel.exists { panel.swipeUp(velocity: .slow) } else { app.swipeUp(velocity: .slow) }
            }
        }
        XCTAssertTrue(b.isHittable, "Offscreen "+id)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: b)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed, "Disabled "+id)
        b.tap()
    }
    private func expand() {
        if button("companion.panel.expand").exists { tap("companion.panel.expand") }
        let panel = app.scrollViews["companion.panel.content"].firstMatch
        let settled = NSPredicate { _, _ in panel.exists && panel.frame.height > 200 && self.button("companion.panel.collapse").isHittable }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 8), .completed)
        // A snapshot must show the resting layout, not the glass spring's crossfade.
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }
    private func nearby() { tap("companion.surface.nearby") }
    private func city() {
        nearby()
        tap("companion.nearby.city")
        let option = button("companion.city.option.cmi")
        XCTAssertTrue(option.waitForExistence(timeout: 6))
        tap("companion.city.option.cmi")
        XCTAssertTrue(button("companion.nearby.city").waitForExistence(timeout: 6))
        XCTAssertTrue(button("companion.nearby.city").label.contains("清迈"))
    }
    private func browse() {
        city()
        expand()
        // A persisted task intentionally opens its own panel after relaunch.
        // Return through the shipping filter control without ending that task.
        if !app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch.exists {
            tap("companion.panel.filters")
        }
        for category in ["coffee", "food", "nature"] {
            let id = "companion.nearby.filter."+category
            if button(id).isSelected { tap(id) }
        }
    }
    private func peek(placeID: String? = nil) {
        browse()
        tap("companion.nearby.place."+(placeID ?? book))
        XCTAssertTrue(button("companion.panel.detail").waitForExistence(timeout: 8))
    }
    private func detail(placeID: String? = nil) {
        peek(placeID: placeID)
        tap("companion.panel.detail")
        XCTAssertTrue(button("companion.place.close").waitForExistence(timeout: 8))
        let handle = app.buttons["表单控制柄"].firstMatch
        if handle.exists {
            handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.13)), withVelocity: .slow, thenHoldForDuration: 0.3)
        }
    }
    private func replace(_ field: XCUIElement, text: String) {
        field.tap()
        field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        field.typeText(text.isEmpty ? XCUIKeyboardKey.delete.rawValue : text)
        let value = field.value as? String ?? ""
        XCTAssertTrue(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (value.isEmpty || value == field.placeholderValue || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            : value == text, "Native replacement preserves the exact nonempty draft")
    }

    func test01CollapsedMapPanelIsAvailable() {
        nearby()
        XCTAssertTrue(button("companion.panel.expand").waitForExistence(timeout: 8))
        XCTAssertGreaterThanOrEqual(button("companion.panel.expand").frame.height, 44)
        XCTAssertGreaterThanOrEqual(button("companion.nearby.filter.coffee").frame.height, 44)
        capture("01-collapsed-glass-filters")
        tap("companion.nearby.filter.coffee")
        XCTAssertTrue(button("companion.nearby.filter.coffee").isSelected)
        capture("02-one-category-selected")
        tap("companion.nearby.filter.coffee")
        XCTAssertFalse(button("companion.nearby.filter.coffee").isSelected)
        expand()
        capture("03-panel-expanded")
        tap("companion.panel.collapse")
        XCTAssertTrue(button("companion.panel.expand").exists)
    }

    func test02DraftCityFavoriteAndTenSurfaceSwitches() {
        tap("companion.surface.now")
        let input = app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let old = input.value as? String ?? ""
        originalDraft = old == input.placeholderValue ? "" : old
        let marker = (originalDraft ?? "") + "QA B folding draft retained"
        replace(input, text: marker)
        XCTAssertEqual(input.value as? String, marker)
        city()
        tap("companion.nearby.city")
        tap("companion.city.cancel")
        XCTAssertTrue(button("companion.nearby.city").label.contains("清迈"))
        expand()
        let mapInput = app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch
        XCTAssertEqual(mapInput.value as? String, marker)
        tap("companion.nearby.place."+book)
        let save = button("companion.panel.save")
        originalFavorite = save.isSelected
        if !save.isSelected { save.tap() }
        XCTAssertTrue(save.isSelected)
        capture("04-place-peek-saved")
        tap("companion.panel.collapse")
        for _ in 0..<10 {
            tap("companion.surface.now")
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch.value as? String, marker)
            XCTAssertFalse(button("companion.nearby.city").exists, "Hidden map must leave the accessibility tree.")
            nearby()
            XCTAssertTrue(button("companion.nearby.city").label.contains("清迈"))
        }
        app.terminate(); app.launch()
        tap("companion.surface.now")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch.value as? String, marker)
        peek()
        XCTAssertTrue(button("companion.panel.save").isSelected)
        if originalFavorite == false { tap("companion.panel.save") }
        capture("05-restored-city-draft-favorite")
    }

    func test03RealRouteIslandRelaunchAndCompletion() {
        continueAfterFailure = true
        peek()
        tap("companion.route.start")
        let active = app.descendants(matching: .any).matching(identifier: "companion.route.active").firstMatch
        XCTAssertTrue(active.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["时间待更新 · 到达后请标记"].exists)
        capture("06-real-route-in-app")
        tap("companion.route.end")
        capture("06b-route-end-confirmation")
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["取消", "Cancel"])).firstMatch
        if cancel.waitForExistence(timeout: 2) { cancel.tap() }
        else {
            // iOS 26 presents this confirmation as a native anchored popover;
            // tapping outside is its system cancellation interaction.
            XCTAssertTrue(app.sheets["结束这次路线？"].waitForExistence(timeout: 5))
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.4)).tap()
        }
        XCTAssertTrue(button("companion.route.arrived").exists)
        tap("companion.panel.collapse")
        XCTAssertTrue(button("companion.panel.expand").exists)
        XCUIDevice.shared.press(.home)
        let board = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let compact = XCTAttachment(screenshot: board.screenshot())
        compact.name = "07-real-system-island-compact"
        compact.lifetime = .keepAlways; add(compact)
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.035)).press(forDuration: 1.2)
        let expanded = XCTAttachment(screenshot: board.screenshot())
        expanded.name = "08-real-system-island-long-press"
        expanded.lifetime = .keepAlways; add(expanded)
        let systemPlace = board.staticTexts["Backstreet Books"].firstMatch
        if systemPlace.exists { systemPlace.tap() }
        else { board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.07)).tap() }
        let islandReturned = app.wait(for: .runningForeground, timeout: 8)
        XCTAssertTrue(islandReturned, "The real expanded system island must open its route.")
        if !islandReturned { app.activate(); expand() }
        XCTAssertTrue(button("companion.route.arrived").waitForExistence(timeout: 8))
        app.terminate(); app.launch(); nearby()
        XCTAssertTrue(button("companion.panel.open").label.contains("Backstreet Books"),
                      "Ordinary relaunch must retain the next stop in the collapsed panel.")
        tap("companion.panel.open")
        XCTAssertTrue(button("companion.route.arrived").waitForExistence(timeout: 8))
        app.terminate()
        app.open(URL(string: "solocompass://companion/route")!)
        XCTAssertTrue(button("companion.route.arrived").waitForExistence(timeout: 20),
                      "Cold native URL launch must reopen the actual persisted route.")
        capture("09-route-deep-link-restored")
        tap("companion.route.arrived")
        XCTAssertTrue(button("companion.panel.expand").waitForExistence(timeout: 8))
        XCTAssertFalse(button("companion.route.arrived").exists)
        XCUIDevice.shared.press(.home)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let ended = XCTAttachment(screenshot: board.screenshot())
        ended.name = "10-system-island-after-real-arrival"
        ended.lifetime = .keepAlways; add(ended)
        board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.035)).press(forDuration: 1.2)
        XCTAssertFalse(board.staticTexts["Backstreet Books"].exists,
                       "Ended route must no longer expand in the real system island.")
        app.activate()
        capture("11-route-finished-map-restored")
    }

    func test04PlacePeopleCancelAndInviteDraftReturn() {
        // Use a place without a preexisting personal invitation; keep all older drafts.
        detail(placeID: "exp_cmi_khao_soi_1974")
        capture("12-real-place-detail")
        let invite = button("companion.place.invite")
        for _ in 0..<6 where !invite.isHittable { app.swipeUp(velocity: .slow) }
        invite.tap()
        tap("companion.place.people")
        XCTAssertTrue(button("companion.people.done").waitForExistence(timeout: 6))
        capture("13-people-local-selection")
        // Leave names and global intention unchanged, then return to the same place.
        button("companion.people.done").tap()
        XCTAssertTrue(button("companion.place.saveInvite").waitForExistence(timeout: 6))
        let note = app.descendants(matching: .any).matching(identifier: "companion.place.inviteNote").firstMatch
        if note.exists {
            replace(note, text: "QA native folding map invitation draft")
            capture("14-concrete-invite-draft")
        }
        let save = button("companion.place.saveInvite")
        for _ in 0..<7 where !save.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertTrue(save.isEnabled, "A newly chosen future time must be savable.")
        save.tap()
        XCTAssertTrue(button("companion.surface.now").waitForExistence(timeout: 8))
        XCTAssertTrue(button("companion.surface.now").isSelected)
        capture("15-invite-returned-to-conversation")
    }

    func test05SoftwareKeyboardAvoidanceAndInactiveInput() {
        browse()
        let field = app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 6))
        let old = field.value as? String ?? ""
        originalDraft = old == field.placeholderValue ? "" : old
        let expected = (originalDraft ?? "") + "QA keyboard and folding"
        field.tap(); field.typeText("QA keyboard and folding")
        XCTAssertEqual(field.value as? String, expected)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 8), "Must observe real software keyboard, not only hardware typing.")
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY + 2)
        capture("16-actual-software-keyboard")
        tap("companion.surface.now")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch.value as? String, expected)
        XCTAssertFalse(button("companion.nearby.city").exists)
        nearby()
        expand()
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch.value as? String, expected)
        capture("17-draft-after-hidden-map-input")
    }

    func test06MapPanelAccessibilityAudit() throws {
        continueAfterFailure = true
        city()
        capture("18-map-before-accessibility-audit")
        audit("collapsed-map")
        expand()
        if button("companion.route.arrived").exists { tap("companion.panel.filters") }
        capture("19-expanded-map-before-accessibility-audit")
        audit("expanded-map")
        tap("companion.nearby.place."+book)
        capture("20-place-peek-before-accessibility-audit")
        audit("place-peek")
    }

    private func audit(_ label: String) {
        do { try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription,
                                                .dynamicType, .textClipped, .trait]) { [self] issue in
            let details = XCTAttachment(string: issue.compactDescription+"\n"+issue.detailedDescription+"\n"+(issue.element?.debugDescription ?? ""))
            details.name = "accessibility-issue-"+label
            details.lifetime = .keepAlways; add(details)
            return false
        } } catch {
            let failure = XCTAttachment(string: String(describing: error))
            failure.name = "accessibility-audit-error-"+label
            failure.lifetime = .keepAlways; add(failure)
            XCTFail("Accessibility audit failed for "+label+": "+String(describing: error))
        }
    }

    func test07MaximumTypeMapRemainsOperable() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        nearby()
        XCTAssertTrue(button("companion.panel.expand").waitForExistence(timeout: 8))
        XCTAssertTrue(button("companion.nearby.city").isHittable)
        expand()
        XCTAssertTrue(button("companion.panel.collapse").waitForExistence(timeout: 8))
        XCTAssertTrue(button("companion.nearby.filter.coffee").isHittable)
        capture("21-maximum-accessibility-size")
        tap("companion.nearby.filter.coffee")
        XCTAssertTrue(button("companion.nearby.filter.coffee").isSelected)
        tap("companion.nearby.filter.coffee")
        tap("companion.panel.collapse")
    }

    func test08NativeDragAndMapPanKeepFilter() {
        browse()
        tap("companion.panel.collapse")
        let panel = app.descendants(matching: .any).matching(identifier: "companion.map.panel").firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        func dragGrip(_ dy: CGFloat) {
            let frame = panel.frame
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: frame.midX, dy: frame.minY + 12))
            start.press(forDuration: 0.12, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)), withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        dragGrip(-240)
        XCTAssertTrue(button("companion.panel.collapse").waitForExistence(timeout: 5))
        capture("22-native-swipe-expanded")
        dragGrip(240)
        XCTAssertTrue(button("companion.panel.expand").waitForExistence(timeout: 5))
        tap("companion.nearby.filter.coffee")
        XCTAssertTrue(button("companion.nearby.filter.coffee").isSelected)
        expand()
        let mapStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.32))
        mapStart.press(forDuration: 0.1, thenDragTo: mapStart.withOffset(CGVector(dx: 70, dy: 35)), withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(button("companion.panel.expand").waitForExistence(timeout: 6))
        XCTAssertTrue(button("companion.nearby.filter.coffee").isSelected)
        app.maps.firstMatch.pinch(withScale: 1.2, velocity: 1)
        let pin = button("companion.nearby.pin.exp_cmi_nimman_coffee")
        XCTAssertTrue(pin.waitForExistence(timeout: 6))
        let before = pin.frame
        for _ in 0..<3 { tap("companion.surface.now"); nearby() }
        let after = pin.frame
        XCTAssertEqual(after.midX, before.midX, accuracy: 1.5, "Panned/zoomed camera must survive native map remount.")
        XCTAssertEqual(after.midY, before.midY, accuracy: 1.5, "Panned/zoomed camera must survive native map remount.")
        XCTAssertTrue(button("companion.nearby.filter.coffee").isSelected)
        capture("23-map-pan-collapses-and-filter-returns")
        tap("companion.nearby.filter.coffee")
    }

    func test09SystemSettingsInventory() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let tree = XCTAttachment(string: settings.debugDescription)
        tree.name = "system-settings-inventory"; tree.lifetime = .keepAlways; add(tree)
        app.activate()
    }

    func test10DeniedLocationAndVoiceKeepMapAndDraft() {
        browse()
        tap("companion.nearby.locate")
        expand()
        XCTAssertTrue(app.staticTexts["定位未开启，仍可移动地图查看。可在系统设置中更改权限。"].waitForExistence(timeout: 6))
        capture("24-location-denied-map-usable")
        let voice = app.buttons["开始听写，完成后可修改"].firstMatch
        XCTAssertTrue(voice.waitForExistence(timeout: 5)); voice.tap()
        XCTAssertTrue(app.staticTexts["未开启语音权限，仍然可以打字。"].waitForExistence(timeout: 8))
        capture("25-speech-denied-draft-retained")
        tap("companion.nearby.city")
        tap("companion.city.cancel")
        tap("companion.surface.now")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch.exists)
    }

    private func settingsPage(_ labels: [String]) -> XCUIApplication {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let root = settings.buttons["com.apple.settings.accessibility"].firstMatch
        for _ in 0..<5 where !root.exists {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            if back.exists { back.tap() }
        }
        XCTAssertTrue(root.waitForExistence(timeout: 5)); root.tap()
        for label in labels {
            let candidate = settings.buttons[label].firstMatch.exists
                ? settings.buttons[label].firstMatch : settings.staticTexts[label].firstMatch
            for _ in 0..<6 where !candidate.isHittable { settings.swipeUp(velocity: .slow) }
            XCTAssertTrue(candidate.waitForExistence(timeout: 5)); candidate.tap()
        }
        return settings
    }

    func test11ActualReduceMotionSetting() {
        continueAfterFailure = true
        let settings = settingsPage(["Motion"])
        let toggle = settings.switches["Reduce Motion"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let original = toggle.value as? String
        let before = XCTAttachment(string: settings.debugDescription)
        before.name = "reduce-motion-before-toggle"; before.lifetime = .keepAlways; add(before)
        defer {
            let restored = settingsPage(["Motion"]).switches["Reduce Motion"].firstMatch
            XCTAssertTrue(restored.waitForExistence(timeout: 5))
            setSwitch(restored, to: original ?? "0")
            app.activate()
        }
        setSwitch(toggle, to: "1")
        guard toggle.value as? String == "1" else { return }
        let setting = XCTAttachment(string: settings.debugDescription)
        setting.name = "actual-reduce-motion-on"; setting.lifetime = .keepAlways; add(setting)
        app.activate(); city(); expand()
        capture("26-reduce-motion-native-panel")
        tap("companion.panel.collapse"); expand()
        XCTAssertTrue(button("companion.panel.collapse").isHittable)
    }

    func test12ActualReduceTransparencySetting() {
        continueAfterFailure = true
        let settings = settingsPage(["Display & Text Size"])
        let toggle = settings.switches["Reduce Transparency"].firstMatch
        for _ in 0..<5 where !toggle.isHittable { settings.swipeUp(velocity: .slow) }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let original = toggle.value as? String
        let before = XCTAttachment(string: settings.debugDescription)
        before.name = "reduce-transparency-before-toggle"; before.lifetime = .keepAlways; add(before)
        defer {
            let settingsAgain = settingsPage(["Display & Text Size"])
            let restored = settingsAgain.switches["Reduce Transparency"].firstMatch
            for _ in 0..<5 where !restored.isHittable { settingsAgain.swipeUp(velocity: .slow) }
            XCTAssertTrue(restored.waitForExistence(timeout: 5))
            setSwitch(restored, to: original ?? "0")
            app.activate()
        }
        setSwitch(toggle, to: "1")
        guard toggle.value as? String == "1" else { return }
        let setting = XCTAttachment(string: settings.debugDescription)
        setting.name = "actual-reduce-transparency-on"; setting.lifetime = .keepAlways; add(setting)
        app.activate(); city(); expand()
        capture("27-reduce-transparency-native-panel")
        tap("companion.panel.collapse")
        let filterReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            self.button("companion.nearby.filter.coffee").isHittable
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [filterReady], timeout: 5), .completed)
    }

    private func setSwitch(_ toggle: XCUIElement, to desired: String) {
        if toggle.value as? String != desired {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let state = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", desired), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [state], timeout: 5), .completed)
    }

    func test16RestoreTemporarySystemSettings() {
        // Earlier QA recorded both settings off. Restore only these QA toggles;
        // never replace the simulator preference file or clear app data.
        let motionSettings = settingsPage(["Motion"])
        let motion = motionSettings.switches["Reduce Motion"].firstMatch
        XCTAssertTrue(motion.waitForExistence(timeout: 5))
        setSwitch(motion, to: "0")
        let motionTree = XCTAttachment(string: motionSettings.debugDescription)
        motionTree.name = "final-system-reduce-motion-restored-off"
        motionTree.lifetime = .keepAlways; add(motionTree)
        let displaySettings = settingsPage(["Display & Text Size"])
        let transparency = displaySettings.switches["Reduce Transparency"].firstMatch
        for _ in 0..<5 where !transparency.isHittable { displaySettings.swipeUp(velocity: .slow) }
        XCTAssertTrue(transparency.waitForExistence(timeout: 5))
        setSwitch(transparency, to: "0")
        let displayTree = XCTAttachment(string: displaySettings.debugDescription)
        displayTree.name = "final-system-reduce-transparency-restored-off"
        displayTree.lifetime = .keepAlways; add(displayTree)
        app.activate()
    }

    func test13DefaultFormalEntryWithoutTestingFlags() {
        app.terminate()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(button("companion.surface.nearby").waitForExistence(timeout: 25))
        nearby(); expand()
        capture("28-default-formal-entry")
        tap("companion.surface.now")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch.exists)
        capture("29-default-formal-conversation")
    }

    func test14PlaceAndPeopleAccessibilityAudit() throws {
        continueAfterFailure = true
        detail()
        capture("30-place-accessibility-audit")
        audit("place-detail")
        tap("companion.place.invite")
        tap("companion.place.people")
        capture("31-people-accessibility-audit")
        audit("people")
        tap("companion.people.done")
        tap("companion.place.close")
    }

    func test15MaximumConversationTextReflowsAndTailIsReachable() {
        tap("companion.surface.now")
        let replies = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "companion.reply-to."))
        guard let initial = replies.allElementsBoundByIndex.last else {
            XCTFail("Expected a preserved real conversation reply"); return
        }
        let id = initial.identifier
        let fullText = initial.label
        let defaultHeight = initial.frame.height
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let reply = app.staticTexts[id].firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
        XCTAssertEqual(reply.label, fullText)
        XCTAssertGreaterThan(reply.frame.height, defaultHeight * 2)
        let stream = app.scrollViews["companion.stream"].firstMatch
        func alignReply(bottom: Bool) {
            for _ in 0..<30 {
                let viewport = stream.frame.intersection(app.frame)
                let frame = reply.frame
                let target = bottom ? viewport.maxY - 24 : viewport.minY + 16
                let delta = target - (bottom ? frame.maxY : frame.minY)
                if abs(delta) < 18 { break }
                let distance = min(abs(delta), viewport.height * 0.55) * (delta > 0 ? 1 : -1)
                let y = distance > 0 ? viewport.minY + viewport.height * 0.2 : viewport.maxY - viewport.height * 0.2
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: viewport.midX, dy: y))
                start.press(forDuration: 0.08, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                            withVelocity: .slow, thenHoldForDuration: 0.15)
            }
        }
        alignReply(bottom: false)
        XCTAssertGreaterThanOrEqual(reply.frame.minY, stream.frame.minY - 2)
        capture("32-maximum-conversation-text-start")
        alignReply(bottom: true)
        XCTAssertLessThanOrEqual(reply.frame.maxY, stream.frame.maxY + 2)
        XCTAssertGreaterThan(reply.frame.maxY, stream.frame.minY)
        XCTAssertEqual(reply.label, fullText)
        capture("33-maximum-conversation-text-tail")
    }
}
