import XCTest

/// Actual shipping-app interactions. Original records are never seeded/replaced.
@MainActor
final class CompanionTravelIMUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.solocompass.app")
        app.launchArguments = ["-devSkipOnboarding", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment = ["FF_CONTINUOUS_COMPANION": "1"]
        app.launch()
        XCTAssertTrue(b("companion.surface.now").waitForExistence(timeout: 25))
        b("companion.surface.now").tap()
    }
    override func tearDownWithError() throws { capture("final-screen"); tree() }
    private func b(_ id: String) -> XCUIElement { app.buttons.matching(identifier: id).firstMatch }
    private var field: XCUIElement { app.descendants(matching: .any).matching(identifier: "companion.composer").firstMatch }
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    private func tree() {
        let t = XCTAttachment(string: app.debugDescription); t.name = "actual-accessibility-tree"; t.lifetime = .keepAlways; add(t)
    }
    private func tap(_ id: String) { XCTAssertTrue(b(id).waitForExistence(timeout: 10), id); b(id).tap() }
    private func cancelSheet() {
        let cancel = app.buttons["取消"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8)); cancel.tap()
    }
    private func replace(_ input: XCUIElement, _ value: String) {
        input.tap()
        input.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        input.typeText(value)
        let actual = input.value as? String ?? ""
        XCTAssertTrue(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (actual.isEmpty || actual == input.placeholderValue || actual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            : actual == value, "Native select-paragraph replacement must not leave stale text")
    }
    func test01HeaderDraftMapAndAttachmentsCancel() {
        XCTAssertTrue(b("companion.surface.nearby").exists)
        XCTAssertTrue(b("companion.more").exists)
        let old = field.value as? String ?? " "
        replace(field, "IM验收：保留这份草稿")
        capture("im-keyboard-text-draft")
        tap("companion.media.add")
        XCTAssertTrue(b("companion.media.photos").waitForExistence(timeout: 8))
        XCTAssertTrue(b("companion.media.files").exists)
        XCTAssertTrue(b("companion.media.place").exists)
        capture("native-attachment-tray")
        cancelSheet()
        tap("companion.surface.nearby")
        capture("unchanged-map-navigation")
        tap("companion.surface.now")
        XCTAssertEqual(field.value as? String, "IM验收：保留这份草稿")
        app.terminate(); app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertEqual(field.value as? String, "IM验收：保留这份草稿")
        replace(field, old)
    }
    func test02SelectRealPlaceDraftAndKeepAcrossMapRestart() {
        tap("companion.media.add"); tap("companion.media.place")
        let choices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.media.pickPlace.'"))
        XCTAssertTrue(choices.firstMatch.waitForExistence(timeout: 10))
        capture("real-place-selection")
        choices.firstMatch.tap()
        let drafts = app.scrollViews["companion.draft.media"].firstMatch
        XCTAssertTrue(drafts.waitForExistence(timeout: 8))
        capture("real-place-card-draft")
        tap("companion.surface.nearby"); tap("companion.surface.now")
        XCTAssertTrue(drafts.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.scrollViews["companion.draft.media"].waitForExistence(timeout: 15))
        capture("place-draft-restored")
    }
    func test03PhotoPickerActualSelection() {
        tap("companion.media.add"); tap("companion.media.photos")
        let photos = app.otherElements["PhotoPicker"].firstMatch
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        capture("system-photo-picker")
        tree()
        let photo = app.images.matching(NSPredicate(format: "label CONTAINS '照片' OR label CONTAINS 'Photo'")).firstMatch
        let cell = app.cells.firstMatch
        let photoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS '照片，' OR label CONTAINS 'Photo,'")).firstMatch
        let ready = NSPredicate { _, _ in photo.exists || cell.exists || photoButton.exists }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 40), .completed,
                       "System Photos service did not provide a selectable asset")
        tree()
        if photo.exists {
            let frame = photo.frame
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        } else if photoButton.exists { photoButton.tap() } else { cell.tap() }
        XCTAssertTrue(app.scrollViews["companion.draft.media"].waitForExistence(timeout: 25))
        capture("photo-original-in-real-draft")
    }
    func test04RecordAndPlayActualAudio() {
        // A unique real recording is retained in the draft; no microphone fixture is injected.
        tap("companion.media.add"); tap("companion.media.voice")
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            if alert.buttons["允许"].exists { alert.buttons["允许"].tap() }
            else if alert.buttons["OK"].exists { alert.buttons["OK"].tap() }
        }
        XCTAssertTrue(b("companion.audio.finish").waitForExistence(timeout: 35))
        XCTAssertGreaterThanOrEqual(b("companion.audio.finish").frame.height, 44)
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        capture("actual-recording-in-progress")
        tap("companion.audio.finish")
        let play = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.audio.play.'")).firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 8))
        play.tap()
        XCTAssertTrue(play.label.contains("暂停"))
        capture("actual-recording-playback")
        play.tap()
    }
    func test04bPlayPersistedRealAudio() {
        let draft = app.scrollViews["companion.draft.media"].firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 10))
        draft.swipeLeft(velocity: .slow)
        let play = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.audio.play.'")).firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 8)); play.tap()
        XCTAssertTrue(play.label.contains("暂停"))
        capture("actual-recording-playback")
        play.tap()
        XCTAssertTrue(play.label.contains("播放"))
        play.tap()
        capture("actual-recording-resumed")
        play.tap()
    }

    func test05NativeFilePickerCancel() {
        tap("companion.media.add"); tap("companion.media.files")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        capture("system-file-picker"); tree()
        cancelSheet()
        if app.buttons["取消"].exists { cancelSheet() }
    }
    func test05bImportRealFileFromFiles() {
        tap("companion.media.add"); tap("companion.media.files")
        let browse = app.buttons["浏览"].firstMatch
        XCTAssertTrue(browse.waitForExistence(timeout: 8)); browse.tap()
        let local = app.descendants(matching: .any).matching(NSPredicate(format: "label == '在我的 iPhone 上' OR label == 'On My iPhone' OR label == '我的 iPhone' OR label == '我的iPhone' ")).firstMatch
        if local.waitForExistence(timeout: 5) { local.tap() }
        capture("files-local-locations"); tree()
        let downloads = app.cells.matching(NSPredicate(format: "identifier == '下载' OR identifier == 'Downloads'")).firstMatch
        XCTAssertTrue(downloads.waitForExistence(timeout: 8))
        let frame = downloads.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.minY + frame.height * 0.25)).tap()
        capture("files-inside-downloads"); tree()
        // The same filename also exists in older chat bubbles behind the picker.
        // Choose the actual Files cell rather than an unrelated underlying button.
        let file = app.cells.matching(NSPredicate(format: "label BEGINSWITH 'Roamorrow-IM-验收'")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 10), "Real file must be selected through Files")
        file.tap()
        XCTAssertTrue(app.scrollViews["companion.draft.media"].waitForExistence(timeout: 12))
        capture("real-file-retained-in-draft")
    }
    func test08MaximumTypeAndKeyboard() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(b("companion.surface.nearby").isHittable)
        capture("maximum-type-im")
        field.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY + 4)
        XCTAssertTrue(b("companion.media.add").isHittable)
        capture("maximum-type-keyboard-clearance")
        tap("companion.media.add"); capture("maximum-type-attachment-tray"); cancelSheet()
    }
    func test09ReadHistoryDuringActualResponse() {
        let input = field
        replace(input, "请用三段简短的话，帮我比较独自逛书店和坐咖啡馆的感受，不需要查地点，也不修改待办。")
        tap("companion.send")
        let stream = app.scrollViews["companion.stream"]
        stream.swipeDown(velocity: .slow)
        let visible = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.reply-to.' OR identifier BEGINSWITH 'companion.message.body.'")).allElementsBoundByIndex.first(where: { $0.isHittable })
        XCTAssertNotNil(visible)
        let id = visible?.identifier ?? ""
        let oldY = visible?.frame.minY ?? 0
        capture("history-position-while-working")
        XCTAssertTrue(app.buttons["停止回应"].waitForNonExistence(timeout: 40))
        let same = app.staticTexts[id].firstMatch
        XCTAssertTrue(same.exists)
        XCTAssertLessThanOrEqual(abs(same.frame.minY - oldY), 35, "A completed reply must not move the history being read")
        capture("history-position-after-reply")
        tree()
    }
    func test10PreviewFileSendAndOwnReaction() {
        let stream = app.scrollViews["companion.stream"]
        let file = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Roamorrow-IM-验收'")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 8))
        for _ in 0..<8 where !file.isHittable { stream.swipeDown(velocity: .slow) }
        XCTAssertTrue(file.isHittable); file.tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 8))
        capture("actual-file-quicklook-preview")
        app.buttons["完成"].tap()
        stream.swipeUp(velocity: .slow)
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'companion.message.'")).allElementsBoundByIndex
        let row = rows.last(where: { $0.isHittable })
        XCTAssertNotNil(row)
        row?.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).press(forDuration: 1)
        XCTAssertTrue(app.buttons["标记喜欢"].waitForExistence(timeout: 5)); app.buttons["标记喜欢"].tap()
        XCTAssertTrue(app.buttons["移除我标记的喜欢"].waitForExistence(timeout: 5))
        capture("actual-own-heart-reaction")
    }

    func test13BriefActualTravelConversation() {
        replace(field, "今天有点累，什么也不想安排。")
        tap("companion.send")
        XCTAssertTrue(app.buttons["停止回应"].waitForNonExistence(timeout: 45))
        let stream = app.scrollViews["companion.stream"]
        stream.swipeUp(velocity: .slow)
        let lastReply = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'companion.reply-to.'")).allElementsBoundByIndex.last
        XCTAssertNotNil(lastReply)
        XCTAssertFalse(lastReply?.label.contains("搜索区域") ?? true)
        XCTAssertFalse(lastReply?.label.contains("文件本体") ?? true)
        capture("final-real-travel-im-light")
        tree()
    }

    private func settingsPage(_ labels: [String]) -> XCUIApplication {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        let root = settings.buttons["com.apple.settings.accessibility"].firstMatch
        for _ in 0..<6 where !root.exists {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            if back.exists { back.tap() }
        }
        XCTAssertTrue(root.waitForExistence(timeout: 5)); root.tap()
        for label in labels {
            let item = settings.buttons[label].firstMatch.exists ? settings.buttons[label].firstMatch : settings.staticTexts[label].firstMatch
            for _ in 0..<6 where !item.isHittable { settings.swipeUp(velocity: .slow) }
            XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        }
        return settings
    }
    func test11ActualReduceMotionAndTransparency() {
        for (path, name) in [(["Motion"], "Reduce Motion"), (["Display & Text Size"], "Reduce Transparency")] {
            let settings = settingsPage(path)
            let toggle = settings.switches[name].firstMatch
            for _ in 0..<6 where !toggle.isHittable { settings.swipeUp(velocity: .slow) }
            XCTAssertTrue(toggle.waitForExistence(timeout: 6))
            let original = toggle.value as? String ?? "0"
            if original != "1" { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)], timeout: 5), .completed)
            let proof = XCTAttachment(string: settings.debugDescription); proof.name = "actual-setting-" + name; proof.lifetime = .keepAlways; add(proof)
            app.activate(); capture("native-im-" + name)
            tap("companion.media.add"); capture("attachment-tray-" + name); cancelSheet()
            let fresh = settingsPage(path)
            let restore = fresh.switches[name].firstMatch
            for _ in 0..<6 where !restore.isHittable { fresh.swipeUp(velocity: .slow) }
            if restore.value as? String != original { restore.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", original), object: restore)], timeout: 5), .completed)
            app.activate()
        }
    }
    func test12CameraAndMicrophoneDenied() {
        tap("companion.media.add"); tap("companion.media.camera")
        XCTAssertTrue(app.staticTexts["未开启相机权限，仍可从照片中选择。"].waitForExistence(timeout: 8))
        capture("camera-denied-preserves-draft")
        cancelSheet()
        tap("companion.media.add"); tap("companion.media.voice")
        XCTAssertTrue(app.staticTexts["未开启麦克风权限，仍可打字或选择已有音频。"].waitForExistence(timeout: 8))
        capture("microphone-denied-preserves-draft")
        XCTAssertTrue(field.exists)
    }
    func test14RealMediaAfterRestartAndAccessibilityOrder() throws {
        let stream = app.scrollViews["companion.stream"]
        let file = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Roamorrow-IM-验收'")).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 8))
        for _ in 0..<10 where !file.isHittable { stream.swipeDown(velocity: .slow) }
        XCTAssertTrue(file.isHittable)
        capture("sent-file-restored-after-restart")
        let header = app.descendants(matching: .any).matching(identifier: "companion.header").firstMatch
        XCTAssertLessThan(header.frame.maxY, field.frame.minY)
        tree()
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion, .elementDetection]) { issue in
            let details = XCTAttachment(string: issue.compactDescription + "\n" + issue.detailedDescription + "\n" + (issue.element?.debugDescription ?? ""))
            details.name = "actual-accessibility-issue"; details.lifetime = .keepAlways; self.add(details)
            return false
        }
    }

    func test97RestoreOnlyQAFavorite() {
        tap("companion.surface.nearby"); tap("companion.nearby.city"); tap("companion.city.option.cmi")
        tap("companion.panel.expand")
        if b("companion.panel.filters").exists { tap("companion.panel.filters") }
        let place = b("companion.nearby.place.exp_cmi_bookstore_work")
        XCTAssertTrue(place.waitForExistence(timeout: 8)); place.tap()
        let save = b("companion.panel.save")
        XCTAssertTrue(save.waitForExistence(timeout: 8))
        if save.isSelected { save.tap() }
        XCTAssertFalse(save.isSelected)
        tap("companion.surface.now")
    }
    func test98FormalEntryWithoutFeatureOverride() {
        app.terminate(); app.launchArguments = []; app.launchEnvironment = [:]; app.launch()
        XCTAssertTrue(b("companion.surface.now").waitForExistence(timeout: 25))
        tap("companion.surface.now"); capture("formal-entry-without-feature-flags")
    }

    func test99RestoreDraftAndCaptureNormalApp() throws {
        // Exactly the original one-space draft; only QA-written input is replaced.
        replace(field, " ")
        tap("companion.surface.nearby"); tap("companion.surface.now")
        app.scrollViews["companion.stream"].swipeUp(velocity: .slow)
        capture("final-normal-native-im")

    }

    func test06SendRealMediaAndQuote() {
        XCTAssertTrue(app.scrollViews["companion.draft.media"].exists)
        let old = field.value as? String ?? " "
        replace(field, "这是一轮附件验收，照片、录音和地点请按实际可读取的内容回应，不要据文件名猜测。")
        tap("companion.send")
        XCTAssertTrue(b("companion.media.add").exists)
        XCTAssertFalse(app.scrollViews["companion.draft.media"].exists)
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        capture("actual-media-message-submitted")
        let stream = app.scrollViews["companion.stream"]
        stream.swipeUp(velocity: .slow)
        let messages = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'companion.message.'")).allElementsBoundByIndex
        let target = messages.last(where: { $0.isHittable })
        XCTAssertNotNil(target)
        target?.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).press(forDuration: 1)
        XCTAssertTrue(app.buttons["引用回复"].waitForExistence(timeout: 5))
        app.buttons["引用回复"].tap()
        XCTAssertTrue(app.buttons["取消引用"].waitForExistence(timeout: 5))
        capture("native-quoted-reply-draft")
        app.buttons["取消引用"].tap()
        if !old.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { replace(field, old) }
    }
    func test07ActualAccessibilityAudit() throws {
        capture("native-im-accessibility-baseline")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion, .elementDetection]) { issue in
            let details = XCTAttachment(string: issue.compactDescription + "\n" + issue.detailedDescription + "\n" + (issue.element?.debugDescription ?? ""))
            details.name = "actual-accessibility-issue"; details.lifetime = .keepAlways; self.add(details)
            return false
        }
    }
}
