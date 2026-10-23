import XCTest

@MainActor
final class CompanionCharacterUITests: XCTestCase {
    private var app: XCUIApplication!
    private func b(_ id: String) -> XCUIElement { app.buttons.matching(identifier: id).firstMatch }
    private var field: XCUIElement { app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch }
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.solocompass.app")
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(b("companion.surface.now").waitForExistence(timeout: 25))
        b("companion.surface.now").tap()
    }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func tree(_ name: String = "actual-accessibility-tree") {
        let attachment = XCTAttachment(string: app.debugDescription); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    private func replace(_ text: String) {
        field.tap(); field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        field.typeText(text.isEmpty ? XCUIKeyboardKey.delete.rawValue : text)
        XCTAssertEqual(field.value as? String, text)
    }
    func test01RealResponseAndSemanticBubbles() {
        replace("今天有点累，想找个地方坐坐。先陪我聊两句，再轻轻给一个建议，最后留个小问题，每个意思单独一小段。")
        b("companion.send").tap()
        let working = app.descendants(matching: .any).matching(identifier: "companion.activity.working").firstMatch
        XCTAssertTrue(working.waitForExistence(timeout: 8))
        capture("c-character-real-request-working-a")
        let region = XCTAttachment(string: "Real working status frame: \(working.frame)")
        region.name = "motion-region"; region.lifetime = .keepAlways; add(region)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capture("c-character-real-request-working-b")
        tree("working-accessibility-tree")
        XCTAssertTrue(app.buttons["停止回应"].waitForNonExistence(timeout: 90))
        app.scrollViews["companion.stream"].swipeUp(velocity: .slow)
        let parts = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.message.part.'"))
        XCTAssertGreaterThanOrEqual(parts.count, 2, "Real model should provide the requested three semantic paragraphs")
        XCTAssertFalse(working.exists)
        capture("c-character-real-semantic-reply"); tree()
        app.terminate(); app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        XCTAssertFalse(working.exists)
        capture("c-character-restored-static-reply")
    }
    func test02WholeReplyQuoteAndCancel() {
        let replies = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.reply-to.'"))
        let last = replies.allElementsBoundByIndex.last
        XCTAssertNotNil(last)
        let stream = app.scrollViews["companion.stream"]
        for _ in 0..<5 where !(last?.isHittable ?? false) { stream.swipeDown(velocity: .slow) }
        XCTAssertTrue(last?.isHittable ?? false)
        last?.press(forDuration: 1)
        XCTAssertTrue(app.buttons["引用回复"].waitForExistence(timeout: 6)); app.buttons["引用回复"].tap()
        XCTAssertTrue(app.buttons["取消引用"].waitForExistence(timeout: 6))
        capture("c-character-quote-whole-reply"); tree()
        app.buttons["取消引用"].tap()
        b("companion.media.add").tap()
        XCTAssertTrue(b("companion.media.photos").waitForExistence(timeout: 5))
        XCTAssertTrue(b("companion.media.files").exists)
        XCTAssertTrue(b("companion.media.place").exists)
        app.buttons["取消"].tap()
    }
    func test03AccessibilityAuditConversation() throws {
        continueAfterFailure = true
        capture("c-character-light-accessibility-baseline"); tree()
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion, .elementDetection, .sufficientElementDescription, .trait]) { issue in
            let detail = XCTAttachment(string: issue.compactDescription + "\n" + issue.detailedDescription + "\n" + (issue.element?.debugDescription ?? ""))
            detail.name = "actual-accessibility-issue"; detail.lifetime = .keepAlways; self.add(detail)
            return false
        }
    }
    func test04MaximumTypeKeyboardAndReplyTail() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        XCTAssertTrue(b("companion.surface.nearby").isHittable)
        XCTAssertTrue(b("companion.more").isHittable)
        capture("c-character-maximum-type")
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(field.frame.maxY, app.keyboards.firstMatch.frame.minY + 4)
        XCTAssertTrue(b("companion.media.add").isHittable)
        capture("c-character-maximum-type-keyboard")
        b("companion.surface.nearby").tap(); b("companion.surface.now").tap()
        app.scrollViews["companion.stream"].swipeUp(velocity: .slow)
        capture("c-character-maximum-type-reply-tail"); tree()
    }
    func test05CancelActualRequestStopsWorkingAndPreservesDraft() {
        replace("给我想几个安静休息的办法，不用查地点。")
        b("companion.send").tap()
        XCTAssertTrue(app.buttons["停止回应"].waitForExistence(timeout: 8))
        app.buttons["停止回应"].tap()
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "companion.activity.working").firstMatch.exists)
        XCTAssertTrue(b("companion.media.add").exists)
        let retries = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.retry.'"))
        XCTAssertTrue(retries.firstMatch.exists)
        capture("c-character-user-cancelled-static"); tree()
        retries.allElementsBoundByIndex.last?.tap()
        XCTAssertTrue(app.buttons["停止回应"].waitForNonExistence(timeout: 90))
        capture("c-character-same-message-retry-completed")
    }
    func test99RestoreOriginalDraftAndScreenshot() {
        replace(" ")
        b("companion.surface.nearby").tap(); b("companion.surface.now").tap()
        app.scrollViews["companion.stream"].swipeUp(velocity: .slow)
        capture("c-character-final-real-ios"); tree()
    }
    func test06ActualCitySwitchAndPeopleCancelKeepDraft() {
        let original = field.value as? String ?? " "
        replace("C角色验收：切换城市后保留这句草稿")
        b("companion.surface.nearby").tap(); b("companion.nearby.city").tap()
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.city.option.' AND identifier != 'companion.city.option.cmi'"))
        XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 8))
        let alternate = options.allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(alternate)
        let otherLabel = alternate?.label ?? ""
        alternate?.tap()
        XCTAssertTrue(b("companion.nearby.city").waitForExistence(timeout: 8))
        XCTAssertFalse(b("companion.nearby.city").label.contains("清迈"), otherLabel)
        capture("c-character-actual-other-city")
        b("companion.nearby.city").tap()
        XCTAssertTrue(b("companion.city.option.cmi").waitForExistence(timeout: 8))
        b("companion.city.option.cmi").tap()
        b("companion.surface.now").tap()
        XCTAssertEqual(field.value as? String, "C角色验收：切换城市后保留这句草稿")
        b("companion.more").tap()
        let people = app.buttons["选择这次的同行人"].firstMatch
        XCTAssertTrue(people.waitForExistence(timeout: 5)); people.tap()
        XCTAssertTrue(b("companion.people.cancel").waitForExistence(timeout: 6))
        capture("c-character-existing-people-menu")
        b("companion.people.cancel").tap()
        XCTAssertEqual(field.value as? String, "C角色验收：切换城市后保留这句草稿")
        replace(original)
    }
    func test08DeniedLocationWithCurrentComposerKeepsDraft() {
        let original = field.value as? String ?? " "
        let draft = "C角色验收：定位拒绝后仍保留草稿"
        replace(draft)
        b("companion.surface.nearby").tap()
        XCTAssertTrue(b("companion.nearby.locate").waitForExistence(timeout: 8))
        b("companion.nearby.locate").tap()
        let expand = b("companion.panel.expand")
        if expand.waitForExistence(timeout: 2) { expand.tap() }
        XCTAssertTrue(app.staticTexts["定位未开启，仍可移动地图查看。可在系统设置中更改权限。"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.maps.firstMatch.exists)
        capture("c-character-location-denied-map-usable")
        b("companion.surface.now").tap()
        XCTAssertEqual(field.value as? String, draft)
        XCTAssertTrue(b("companion.send").exists)
        replace(original)
    }
    private func motionSettings() -> XCUIApplication {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let root = settings.buttons["com.apple.settings.accessibility"].firstMatch
        for _ in 0..<6 where !root.exists {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            if back.exists { back.tap() }
        }
        XCTAssertTrue(root.waitForExistence(timeout: 6)); root.tap()
        let motion = settings.buttons["Motion"].firstMatch
        for _ in 0..<5 where !motion.isHittable { settings.swipeUp(velocity: .slow) }
        XCTAssertTrue(motion.waitForExistence(timeout: 6)); motion.tap()
        return settings
    }
    func test07ActualReduceMotionDuringRealRequest() {
        let settings = motionSettings()
        let toggle = settings.switches["Reduce Motion"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 6))
        let original = toggle.value as? String ?? "0"
        defer {
            let restored = motionSettings().switches["Reduce Motion"].firstMatch
            if restored.value as? String != original { restored.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
            XCTAssertEqual(restored.value as? String, original)
            app.activate()
        }
        if original != "1" { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        XCTAssertEqual(toggle.value as? String, "1")
        let proof = XCTAttachment(string: settings.debugDescription)
        proof.name = "actual-reduce-motion-on"; proof.lifetime = .keepAlways; add(proof)
        app.activate()
        replace("晚上想慢一点，帮我想一个简单的休息办法，不用查地点。")
        b("companion.send").tap()
        let working = app.descendants(matching: .any).matching(identifier: "companion.activity.working").firstMatch
        XCTAssertTrue(working.waitForExistence(timeout: 8))
        let region = XCTAttachment(string: "Real reduced-motion working frame: \(working.frame)")
        region.name = "reduced-motion-region"; region.lifetime = .keepAlways; add(region)
        capture("c-character-reduced-motion-working-a")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        capture("c-character-reduced-motion-working-b")
        XCTAssertTrue(app.buttons["停止回应"].waitForNonExistence(timeout: 90))
        capture("c-character-reduced-motion-real-reply")
    }
}
