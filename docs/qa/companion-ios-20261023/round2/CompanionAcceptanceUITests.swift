import XCTest

/// Black-box tests of the installed formal SoloCompass app. No transport stubs,
/// storage replacement, erasure, external sharing, or model success assumptions.
@MainActor
final class CompanionAcceptanceUITests: XCTestCase {
    private var app: XCUIApplication!
    private let book = "exp_cmi_bookstore_work"
    private let temple = "exp_cmi_suan_dok_sunset"
    private var originalDraftToRestore: String?
    private var originalFavoriteToRestore: (id: String, saved: Bool)?
    private var originalPeopleLabelsToRestore: [String]?

    override func setUpWithError() throws {
        continueAfterFailure = false
        originalDraftToRestore = nil
        originalFavoriteToRestore = nil
        originalPeopleLabelsToRestore = nil
        app = XCUIApplication(bundleIdentifier: "com.solocompass.app")
        configureLaunch()
        app.launch()
        XCTAssertTrue(element("companion.surface.now").waitForExistence(timeout: 20))
    }

    override func tearDownWithError() throws {
        if let app, app.state == .runningForeground {
            capture("final-screen")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "actual-accessibility-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        restoreTemporaryStateAfterFailure()
    }

    private func configureLaunch(extra: [String] = []) {
        app.launchArguments = ["-devSkipOnboarding", "-AppleLanguages", "(zh-Hans)",
                               "-AppleLocale", "zh_CN"] + extra
        app.launchEnvironment = ["FF_CONTINUOUS_COMPANION": "1"]
    }

    private func element(_ id: String) -> XCUIElement {
        // Native toolbars expose both an Other wrapper and the actual Button
        // with the same identifier. Operate/read the actionable Button first.
        let button = app.buttons.matching(identifier: id).firstMatch
        if button.exists { return button }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws -> XCUIElement {
        let target = element(id)
        XCTAssertTrue(target.waitForExistence(timeout: 10), "Missing visible control: \(id)", file: file, line: line)
        guard target.exists else { throw MissingControl.id(id) }
        if id == "companion.nearby.saved", !target.isHittable {
            let walkFilter = app.buttons["走走"].firstMatch
            if walkFilter.exists { walkFilter.swipeLeft() }
        }
        for _ in 0..<5 where !target.isHittable { app.swipeUp() }
        XCTAssertTrue(target.isHittable, "Control remained offscreen: \(id)", file: file, line: line)
        target.tap()
        if id == "companion.surface.now" || id == "companion.surface.nearby" {
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in target.isSelected }, object: target)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed,
                           "Surface did not become selected after the actual tap: \(id)", file: file, line: line)
        }
        return target
    }

    private enum MissingControl: Error { case id(String) }

    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }

    private func selectChiangMai(reselect: Bool = true) throws {
        try tap("companion.surface.nearby")
        if !reselect,
           element("companion.nearby.city").label.contains("清迈"),
           element("companion.nearby.place.\(book)").exists {
            capture("favorite-precondition-existing-chiang-mai")
            return
        }
        try tap("companion.nearby.city")
        let search = element("companion.city.search")
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("清迈")
        capture("city-search-chinese")
        try tap("companion.city.option.cmi")
        XCTAssertTrue(element("companion.nearby.city").waitForExistence(timeout: 5))
        XCTAssertTrue(element("companion.nearby.city").label.contains("清迈"))
    }

    private func openPlace(_ id: String) throws {
        let candidate = element("companion.nearby.place.\(id)")
        XCTAssertTrue(candidate.waitForExistence(timeout: 10))
        let strip = element("companion.nearby.candidates")
        revealCandidate(candidate, in: strip)
        XCTAssertTrue(candidateCenterIsVisible(candidate, in: strip), "Candidate did not scroll into view")
        candidate.tap()
        // The shipping folded map first opens a place peek. Continue through its
        // actual detail action before asserting controls belonging to the sheet.
        let detail = app.buttons["companion.panel.detail"].firstMatch
        if detail.waitForExistence(timeout: 2) { detail.tap() }
        XCTAssertTrue(element("companion.place.favorite").waitForExistence(timeout: 6))
    }

    // Querying isHittable on a fully offscreen SwiftUI card can itself throw an
    // XCTest activation-point error. Reveal it using actual AX frames first.
    private func candidateCenterIsVisible(_ card: XCUIElement, in strip: XCUIElement) -> Bool {
        guard card.exists, strip.exists else { return false }
        let viewport = strip.frame.intersection(app.frame).insetBy(dx: 8, dy: 0)
        let frame = card.frame
        return !viewport.isNull && !frame.isEmpty
            && viewport.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    private func revealCandidate(_ card: XCUIElement, in strip: XCUIElement) {
        for _ in 0..<6 {
            guard card.exists, strip.exists else { return }
            if candidateCenterIsVisible(card, in: strip) { return }
            let viewport = strip.frame.intersection(app.frame)
            let delta = card.frame.midX - viewport.midX
            let distance = min(abs(delta), viewport.width * 0.5)
            let direction: CGFloat = delta > 0 ? 1 : -1
            let y = min(max(card.frame.midY, viewport.minY + 10), viewport.maxY - 10)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX + direction * distance / 2, dy: y))
            let end = origin.withOffset(CGVector(dx: viewport.midX - direction * distance / 2, dy: y))
            // A fast swipe overshot the five-card strip and alternated ends.
            // Use a short, slow drag and hold before release to remove inertia.
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        }
    }

    private func expandPlaceSheetForAudit() throws {
        let handle = app.buttons["表单控制柄"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.midX, dy: 110))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            element("companion.place.favorite").frame.minY < 200
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed)
        let facts = app.staticTexts["地址与营业资料"].firstMatch
        XCTAssertTrue(facts.exists)
        XCTAssertLessThan(facts.frame.maxY, app.frame.maxY - 20,
                          "Audit must inspect the facts label inside the visible sheet, not its offscreen AX projection")
    }

    private func replaceText(_ field: XCUIElement, with text: String) {
        field.tap()
        let current = field.value as? String ?? ""
        // Placeholder is not editable content. An empty model field may expose it.
        let content = current == field.placeholderValue ? "" : current
        if !content.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: content.count))
        }
        if !text.isEmpty { field.typeText(text) }
    }

    func test01CitySearchAndCancelPreserveMainSurface() throws {
        try selectChiangMai()
        capture("nearby-city-selected")
        try tap("companion.nearby.city")
        try tap("companion.city.cancel")
        XCTAssertTrue(element("companion.nearby.city").label.contains("清迈"))
        try tap("companion.surface.now")
        XCTAssertFalse(element("companion.nearby.city").isHittable,
                       "Hidden map controls must not be interactive on the conversation")
        XCTAssertFalse(app.staticTexts["同路"].exists, "Visible brand/author label should be removed")
        capture("now-no-brand")
    }

    func test02FavoriteFilterSurvivesRelaunch() throws {
        try selectChiangMai(reselect: false)
        try openPlace(book)
        let favorite = element("companion.place.favorite")
        let wasSaved = favorite.label.contains("取消") || (favorite.value as? String) == "已收藏"
        originalFavoriteToRestore = (book, wasSaved)
        let originalState = XCTAttachment(string: "placeID=\(book); originallySaved=\(wasSaved)")
        originalState.name = "favorite-original-state-no-user-text"
        originalState.lifetime = .keepAlways
        add(originalState)
        if !wasSaved { favorite.tap() }
        XCTAssertTrue(waitForFavorite(saved: true))
        capture("place-saved-chinese-details")
        try tap("companion.place.close")
        app.terminate()
        app.launch()
        try selectChiangMai(reselect: false)
        try tap("companion.nearby.saved")
        try openPlace(book)
        XCTAssertTrue(waitForFavorite(saved: true))
        capture("saved-place-after-relaunch")
        // Restore the pre-test favorite selection; leave all unrelated saved data.
        if !wasSaved { try tap("companion.place.favorite") }
        XCTAssertTrue(waitForFavorite(saved: wasSaved))
        originalFavoriteToRestore = nil
        try tap("companion.place.close")
    }

    private func waitForFavorite(saved: Bool) -> Bool {
        let state = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            let favorite = element("companion.place.favorite")
            return (favorite.label.contains("取消") || (favorite.value as? String) == "已收藏") == saved
        }, object: app)
        return XCTWaiter.wait(for: [state], timeout: 5) == .completed
    }

    func test03PlacePeopleInviteReturnAndRecovery() throws {
        // Read-only fixture check before this run confirmed no Coffee draft.
        // The older Temple QA draft has expired and must not be auto-redated.
        let creationPlace = "exp_cmi_nimman_coffee"
        let placeName = "Nimman Roasters"
        let inviteQuery = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "companion.invite."))
        let oldIDs = Set(inviteQuery.allElementsBoundByIndex.map(\.identifier))
        try selectChiangMai()
        try openPlace(creationPlace)
        // In the observed medium detent this disclosure starts at y800 and
        // lies behind the fixed footer. Use the real grabber before tapping.
        try expandPlaceSheetForAudit()
        try tap("companion.place.invite")
        try tap("companion.place.people")
        let name = element("companion.people.name")
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        replaceText(name, with: "本轮同行验收")
        try tap("companion.people.add")
        capture("people-selected-local-only")
        try tap("companion.people.done")
        XCTAssertTrue(element("companion.place.saveInvite").waitForExistence(timeout: 5))
        // AX may call a scroll child hittable while its center lies behind the
        // fixed Done footer. Reveal the actual save button before one tap.
        let save = element("companion.place.saveInvite")
        let close = element("companion.place.close")
        for _ in 0..<4 where save.frame.maxY > close.frame.minY - 8 {
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: close.frame.minY - 100))
            let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: close.frame.minY - 300))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        }
        XCTAssertLessThan(save.frame.maxY, close.frame.minY - 8,
                          "Save must be fully visible above the fixed footer before tapping")
        capture("concrete-invite-before-save")
        try tap("companion.place.saveInvite")
        XCTAssertTrue(element("companion.surface.now").waitForExistence(timeout: 8))
        XCTAssertTrue(element("companion.surface.now").isSelected, "Saving must return to the conversation")
        var createdIdentifier: String?
        let newCard = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            for row in inviteQuery.allElementsBoundByIndex where !oldIDs.contains(row.identifier) {
                let content = ([row.label] + row.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: "\n")
                if content.contains(placeName) {
                    createdIdentifier = row.identifier
                    return true
                }
            }
            return false
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [newCard], timeout: 8), .completed,
                       "No newly created card for the actual Coffee place")
        let identifier = try XCTUnwrap(createdIdentifier)
        let invite = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        let identity = XCTAttachment(string: "createdInviteIdentifier=\(identifier); placeID=\(creationPlace)")
        identity.name = "new-invite-identity-no-user-text"
        identity.lifetime = .keepAlways
        add(identity)
        capture("invite-in-conversation")
        app.terminate()
        app.launch()
        XCTAssertTrue(invite.waitForExistence(timeout: 10))
        let restored = ([invite.label] + invite.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: "\n")
        XCTAssertTrue(restored.contains(placeName), "The same new card must restore with its place")
        capture("invite-restored-after-relaunch")
    }

    func test04SoftwareKeyboardAndDraftAcrossSurfaces() throws {
        let input = element("companion.composer")
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let original = input.value as? String ?? ""
        let originalText = original == input.placeholderValue ? "" : original
        originalDraftToRestore = originalText
        let marker = "QA keyboard draft preserved"
        replaceText(input, with: marker)
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5),
                      "Software keyboard did not appear; hardware typing does not prove avoidance")
        XCTAssertLessThanOrEqual(input.frame.maxY, keyboard.frame.minY + 2,
                                 "Composer overlaps the software keyboard")
        capture("software-keyboard-avoidance")
        try tap("companion.surface.nearby")
        XCTAssertEqual(element("companion.composer").value as? String, marker)
        try tap("companion.surface.now")
        XCTAssertEqual(element("companion.composer").value as? String, marker)
        replaceText(element("companion.composer"), with: originalText)
        originalDraftToRestore = nil
    }

    func test05AccessibilityAuditConversation() throws {
        capture("accessibility-conversation-before-audit")
        try auditAccessibility("conversation")
        let stream = element("companion.stream")
        stream.swipeDown(velocity: .slow)
        capture("accessibility-conversation-scrolled-before-audit")
        try auditAccessibility("conversation-scrolled")
    }

    func test06AccessibilityAuditPlaceAndPeople() throws {
        try selectChiangMai()
        try openPlace(temple)
        try expandPlaceSheetForAudit()
        capture("accessibility-place-before-audit")
        try auditAccessibility("place")
        try tap("companion.place.invite")
        try tap("companion.place.people")
        capture("accessibility-people-before-audit")
        try auditAccessibility("people")
        // Embedded people selection uses the standard native Back control.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("companion.place.saveInvite").waitForExistence(timeout: 5))
    }

    private func auditAccessibility(_ surface: String) throws {
        let previousContinueAfterFailure = continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = previousContinueAfterFailure }
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription,
                                                .dynamicType, .textClipped, .trait]) { [self] issue in
            let elementDescription = issue.element?.debugDescription ?? "unavailable"
            let details = XCTAttachment(string: "\(issue.compactDescription)\n\(issue.detailedDescription)\nElement:\n\(elementDescription)")
            details.name = "accessibility-issue-\(surface)"
            details.lifetime = .keepAlways
            add(details)
            if issue.auditType == .contrast, let target = issue.element {
                let frame = target.frame
                let viewport = app.frame
                let valid = [frame.minX, frame.minY, frame.width, frame.height,
                             viewport.minX, viewport.minY, viewport.width, viewport.height].allSatisfy(\.isFinite)
                    && !frame.isNull && !frame.isEmpty && !viewport.isNull && !viewport.isEmpty
                if valid && !frame.intersects(viewport) {
                    // Reviewed xcresult evidence: a prefetched LazyVStack row
                    // at y=-217 yielded a solid-black element screenshot.
                    // No rendered pixels exist for contrast measurement here.
                    let geometry = XCTAttachment(string: "Reviewed offscreen contrast artifact only. element=\(frame); viewport=\(viewport). Completely disjoint, finite, nonempty rectangles. Original issue retained above.")
                    geometry.name = "offscreen-contrast-artifact-\(surface)"
                    geometry.lifetime = .keepAlways
                    add(geometry)
                    return true
                }
                // Only stream descendants may be excluded for content clipped
                // behind fixed controls. Header/input controls themselves stay
                // audited, even though they lie outside the stream viewport.
                let ancestry = elementDescription.components(separatedBy: "Path to element:").last?
                    .components(separatedBy: "Query chain:").first ?? ""
                let isStreamNode = ancestry.split(separator: "\n").contains {
                    $0.contains("ScrollView,") && $0.contains("identifier: 'companion.stream'")
                }
                if valid && surface.hasPrefix("conversation") && isStreamNode {
                    let header = app.descendants(matching: .any).matching(identifier: "companion.header").firstMatch
                    let input = app.descendants(matching: .any).matching(identifier: "companion.input.area").firstMatch
                    if header.exists && input.exists {
                        let headerFrame = header.frame
                        let inputFrame = input.frame
                        let fixedFramesValid = [headerFrame.minX, headerFrame.minY, headerFrame.width, headerFrame.height,
                                                inputFrame.minX, inputFrame.minY, inputFrame.width, inputFrame.height].allSatisfy(\.isFinite)
                            && !headerFrame.isNull && !headerFrame.isEmpty && !inputFrame.isNull && !inputFrame.isEmpty
                            && headerFrame.width >= viewport.width * 0.7 && inputFrame.width >= viewport.width * 0.7
                            && headerFrame.intersects(viewport) && inputFrame.intersects(viewport)
                            && headerFrame.maxY < inputFrame.minY
                        if fixedFramesValid {
                            let visible = CGRect(x: viewport.minX, y: max(viewport.minY, headerFrame.maxY),
                                                 width: viewport.width, height: min(viewport.maxY, inputFrame.minY) - max(viewport.minY, headerFrame.maxY))
                            let boundaryOccluded = frame.intersects(headerFrame) || frame.intersects(inputFrame)
                            if headerFrame.maxY < min(viewport.maxY, inputFrame.minY)
                                && !visible.isEmpty && (boundaryOccluded || !frame.intersects(visible)) {
                                let geometry = XCTAttachment(string: "Reviewed conversation stream clipping artifact. element=\(frame); window=\(viewport); header=\(headerFrame); input=\(inputFrame); visibleContent=\(visible); intersectsFixedControl=\(boundaryOccluded). Runtime AX ancestry includes companion.stream. Original issue retained; this is not a full-node contrast measurement or an exemption for header/input controls.")
                                geometry.name = "stream-boundary-contrast-artifact-\(surface)"
                                geometry.lifetime = .keepAlways
                                add(geometry)
                                return true
                            }
                        }
                    }
                }
            }
            return false // Visible/partial/unknown frames and all other types fail.
        }
    }

    func test07StandalonePeopleCancelReturnsToConversation() throws {
        try tap("companion.people")
        XCTAssertTrue(element("companion.people.name").waitForExistence(timeout: 5))
        capture("standalone-people-before-cancel")
        try tap("companion.people.cancel")
        XCTAssertTrue(element("companion.composer").waitForExistence(timeout: 5))
        XCTAssertFalse(element("companion.people.name").exists)
    }

    func test08MaximumTypeControlsStayOnscreen() throws {
        app.terminate()
        configureLaunch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.launch()
        let now = element("companion.surface.now")
        XCTAssertTrue(now.waitForExistence(timeout: 10))
        let nearby = element("companion.surface.nearby")
        XCTAssertTrue(now.isHittable && nearby.isHittable)
        XCTAssertGreaterThanOrEqual(now.frame.height, 44)
        XCTAssertGreaterThanOrEqual(nearby.frame.height, 44)
        capture("maximum-type-header")
        try selectChiangMai()
        try openPlace(temple)
        capture("maximum-type-place")
        try tap("companion.place.close")
        app.terminate()
        configureLaunch()
        app.launch()
    }
    private func openSettings() throws {
        try tap("companion.more")
        let settings = app.buttons["偏好与设置"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["偏好"].waitForExistence(timeout: 5))
    }

    private func settingsButton(_ label: String) throws -> XCUIElement {
        let button = app.buttons[label].firstMatch
        for _ in 0..<12 {
            if button.exists && button.isHittable { return button }
            app.swipeUp()
        }
        capture("settings-control-not-reached")
        XCTFail("Could not reach settings control: \(label)")
        throw MissingControl.id(label)
    }

    func test09ClearScopeIsExplicitAndCancelKeepsApp() throws {
        try openSettings()
        try settingsButton("清除全部数据").tap()
        let destructive = app.buttons["清除一切"].firstMatch
        XCTAssertTrue(destructive.waitForExistence(timeout: 5))
        let visibleText = app.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        for scope in ["对话", "未发送文字", "待办", "同行", "邀约", "副本"] {
            XCTAssertTrue(visibleText.contains(scope), "Clear confirmation missing scope: \(scope)")
        }
        capture("clear-scope-confirmation-before-cancel")
        // Deliberately never tap the destructive action, even on failure.
        let cancel = app.buttons["取消"].firstMatch
        if cancel.waitForExistence(timeout: 2) { cancel.tap() }
        else {
            // iOS 26 presents this as an anchored popover without the cancel
            // row. Tapping the neutral navigation title dismisses it safely.
            let title = app.navigationBars["偏好"].staticTexts["偏好"].firstMatch
            XCTAssertTrue(title.exists)
            title.tap()
        }
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: destructive)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        capture("clear-cancelled-settings-retained")
    }

    func test10ExportPresentsShareWithoutSending() throws {
        try openSettings()
        let previousSheetCount = app.sheets.count
        try settingsButton("导出我的数据").tap()
        let sharePresented = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            app.otherElements["ActivityListView"].exists
                || app.buttons["AirDrop"].exists
                || app.buttons["Copy"].exists
                || app.buttons["拷贝"].exists
                || app.buttons["复制"].exists
                || app.sheets.count > previousSheetCount
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [sharePresented], timeout: 10), .completed,
                       "No actual system share interface appeared")
        capture("export-system-share-not-sent")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "export-share-tree-file-labels"
        tree.lifetime = .keepAlways
        add(tree)
        // File names may be grouped into a system item count. Host-side QA
        // verifies the actual generated companion JSON separately, if needed.
        // Terminate instead of selecting any person, application, or share target.
        app.terminate()
        app.launch()
        XCTAssertTrue(element("companion.surface.now").waitForExistence(timeout: 10))
    }

    func test11RealModelUsesSelectedSearchCityWithoutClaimingGPS() throws {
        try tap("companion.surface.nearby")
        try tap("companion.nearby.city")
        let search = element("companion.city.search")
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("万象")
        let choices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "companion.city.option."))
        let choice = choices.firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        XCTAssertTrue(choice.label.contains("万象"))
        choice.tap()
        try tap("companion.surface.now")
        let rowQuery = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "companion.message."))
        let oldIDs = Set(rowQuery.allElementsBoundByIndex.map(\.identifier))
        let input = element("companion.composer")
        let original = input.value as? String ?? ""
        let originalText = original == input.placeholderValue ? "" : original
        originalDraftToRestore = originalText
        // The message intentionally does not contain the selected city name.
        let request = "我刚切了地图城市。请只根据App提供的地图范围，说出当前选中的搜索城市，以及这能否证明我的实际位置。不要调用网页工具，不要创建待办。"
        replaceText(input, with: request)
        try tap("companion.send")
        var observedResponse: String?
        let realReply = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            for row in rowQuery.allElementsBoundByIndex where !oldIDs.contains(row.identifier) {
                let content = ([row.label] + row.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: "\n")
                if content.contains("万象") || content.localizedCaseInsensitiveContains("Vientiane") {
                    observedResponse = content
                    return true
                }
            }
            return false
        }, object: app)
        let outcome = XCTWaiter.wait(for: [realReply], timeout: 90)
        capture("real-model-selected-city-result")
        XCTAssertEqual(outcome, .completed,
                       "No verified real-model city reply; inspect actual service/credential/quota state, never substitute a stub")
        let response = try XCTUnwrap(observedResponse)
        XCTAssertTrue(response.contains("位置") || response.contains("定位"))
        XCTAssertTrue(["不能", "不代表", "不等于", "无法", "无关", "不能证明", "并不", "不意味着"].contains(where: response.contains),
                      "Selected map city must not be treated as proof of device GPS")
        replaceText(element("companion.composer"), with: originalText)
        originalDraftToRestore = nil
    }

    func test12NaturalModelTaskAndAppendPreserveExistingDraft() throws {
        try selectChiangMai()
        try tap("companion.surface.now")
        // Read the already persisted Coffee card after a fresh test launch.
        // The explicit contain semantics must expose one container, not leaves
        // inheriting the same identifier. No invitation is created here.
        let restored = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "companion.invite."))
            .allElementsBoundByIndex.filter {
                $0.staticTexts.matching(NSPredicate(format: "label == %@", "Nimman Roasters")).count > 0
            }
        XCTAssertEqual(restored.count, 1, "The restored Coffee draft must have one stable AX container")
        if let card = restored.first, !card.isHittable { app.swipeUp(velocity: .slow) }
        capture("restored-coffee-invite-stable-container")
        let input = element("companion.composer")
        let original = input.value as? String ?? ""
        let originalText = original == input.placeholderValue ? "" : original
        originalDraftToRestore = originalText
        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "companion.message."))
        let oldIDs = Set(rows.allElementsBoundByIndex.map(\.identifier))
        let request = "我明早想去素贴山，帮我先记下，别把一天排太满。"
        replaceText(input, with: request)
        try tap("companion.send")
        let reply = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard !self.app.buttons["停止回应"].exists else { return false }
            return rows.allElementsBoundByIndex.contains { row in
                guard !oldIDs.contains(row.identifier) else { return false }
                let text = ([row.label] + row.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: "\n")
                return text.contains("素贴山") && !text.contains(request)
            }
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [reply], timeout: 90), .completed,
                       "No completed real model reply; do not substitute generated fixtures")
        capture("natural-demo-real-model-reply")
        let marker = "我原本还想问，早上要带水吗？"
        replaceText(element("companion.composer"), with: marker)
        try openJourney()
        let task = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "标记完成", "素贴山")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 10), "Actual active task must exist in the formal UI")
        capture("natural-demo-actual-active-task")
        let prefix = "companion.commitment.complete."
        XCTAssertTrue(task.identifier.hasPrefix(prefix), "Read the real task identity before choosing its action")
        guard task.identifier.hasPrefix(prefix) else { throw MissingControl.id("actual-task-identity") }
        let taskID = String(task.identifier.dropFirst(prefix.count))
        let identity = XCTAttachment(string: "actualActiveTaskID=\(taskID)")
        identity.name = "natural-task-identity-no-user-text"
        identity.lifetime = .keepAlways
        add(identity)
        try tap("companion.commitment.discuss.\(taskID)")
        let appended = element("companion.composer")
        XCTAssertTrue(appended.waitForExistence(timeout: 5))
        let actual = appended.value as? String ?? ""
        XCTAssertTrue(actual.hasPrefix(marker) && actual.contains("素贴山") && actual.count > marker.count,
                      "Task context must append without replacing existing text")
        capture("existing-draft-plus-task-context")
        replaceText(appended, with: originalText)
        originalDraftToRestore = nil
    }

    private func openJourney() throws {
        try tap("companion.more")
        let journey = app.buttons["行程与约定"].firstMatch
        XCTAssertTrue(journey.waitForExistence(timeout: 5))
        journey.tap()
        XCTAssertTrue(app.navigationBars["行程与约定"].waitForExistence(timeout: 5))
    }

    private func localPeopleRows() -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "仅本机记名"))
    }

    private func expandPeopleSheet() throws {
        let handle = app.buttons["表单控制柄"].firstMatch
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: app.frame.midX, dy: 110)), withVelocity: .slow,
                   thenHoldForDuration: 0.4)
    }

    private func restoreOriginalPeopleSelection() throws {
        guard let labels = originalPeopleLabelsToRestore else { return }
        try tap("companion.people")
        try expandPeopleSheet()
        let solo = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "这次自己走")).firstMatch
        XCTAssertTrue(solo.waitForExistence(timeout: 5))
        solo.tap()
        for label in labels {
            // The checkmark image can change the combined button label. Match
            // the observed name Text instead of its selected decoration.
            let row = localPeopleRows().matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            XCTAssertTrue(row.exists)
            row.tap()
        }
        try tap("companion.people.done")
        originalPeopleLabelsToRestore = nil
    }

    func test13OldInvitePeopleAndDirtyCloseRemainIndependent() throws {
        try tap("companion.people")
        // The name row is lazily materialized below the medium detent. The
        // observed sheet handle is the correct precondition for expanding it.
        try expandPeopleSheet()
        XCTAssertTrue(element("companion.people.name").waitForExistence(timeout: 5))
        let selectedRows = localPeopleRows().allElementsBoundByIndex.filter(\.isSelected)
        let originalLabels = selectedRows.compactMap { row in
            row.staticTexts.allElementsBoundByIndex.first {
                !$0.label.isEmpty && !$0.label.contains("仅本机记名")
            }?.label
        }
        XCTAssertFalse(originalLabels.isEmpty, "Preserved baseline must be observed before changing selection")
        guard !originalLabels.isEmpty, originalLabels.count == selectedRows.count else {
            throw MissingControl.id("original-selected-person")
        }
        originalPeopleLabelsToRestore = originalLabels
        let solo = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "这次自己走")).firstMatch
        solo.tap()
        let other = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "本轮同行验收")).firstMatch
        XCTAssertTrue(other.exists, "Use the already retained QA person; do not add or delete people")
        other.tap()
        XCTAssertTrue(other.isSelected)
        capture("global-intention-B-only")
        try tap("companion.people.done")
        try selectChiangMai()
        try tap("companion.nearby.city")
        capture("all-city-names-chinese")
        try tap("companion.city.cancel")
        capture("nearby-compact-chinese-cards")
        try openPlace(book)
        try expandPlaceSheetForAudit()
        capture("place-chinese-honest-photo-and-distance")
        try tap("companion.place.invite")
        let oldPeople = element("companion.place.people").label
        XCTAssertTrue(oldPeople.contains("验收同行人"))
        XCTAssertFalse(oldPeople.contains("本轮同行验收"), "Viewing old invite A must not silently adopt global B")
        capture("old-invite-keeps-A-while-global-B")
        try tap("companion.place.close")
        try openPlace("exp_cmi_nimman_coffee")
        try expandPlaceSheetForAudit()
        try tap("companion.place.invite")
        let note = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "想一起做什么")).firstMatch
        XCTAssertTrue(note.exists)
        replaceText(note, with: "先坐一会儿，不赶行程。")
        let handle = app.buttons["表单控制柄"].firstMatch
        let origin = app.coordinate(withNormalizedOffset: .zero)
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: 760)))
        XCTAssertTrue(element("companion.place.close").exists, "Dirty draft must not disappear with a swipe")
        try tap("companion.place.close")
        let discard = app.buttons["放弃本次修改"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        capture("dirty-close-requires-explicit-choice")
        let cancel = app.buttons["取消"].firstMatch
        if cancel.exists && cancel.isHittable { cancel.tap() }
        else { app.navigationBars.staticTexts["Nimman Roasters"].firstMatch.tap() }
        XCTAssertEqual(note.value as? String, "先坐一会儿，不赶行程。")
        capture("dirty-close-cancel-keeps-input")
        try tap("companion.place.close")
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap() // Discard only the unsaved QA edit, never a saved record.
        try tap("companion.surface.now")
        try tap("companion.people")
        let stillB = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "本轮同行验收")).firstMatch
        XCTAssertTrue(stillB.isSelected, "Viewing and cancelling invitation edits must preserve global B")
        try tap("companion.people.cancel")
        try restoreOriginalPeopleSelection()
    }

    func test14CurrentSearchCityOverridesOldConversation() throws {
        try selectChiangMai()
        capture("current-map-city-before-model")
        try tap("companion.surface.now")
        let input = element("companion.composer")
        let original = input.value as? String ?? ""
        let originalText = original == input.placeholderValue ? "" : original
        originalDraftToRestore = originalText
        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "companion.message."))
        let oldIDs = Set(rows.allElementsBoundByIndex.map(\.identifier))
        // Deliberately omit city names, so the model must read the actual
        // app-provided current area rather than copy a city from the request.
        let request = "先别改地图，只确认此刻我选中的搜索城市，以及它是不是我的实际定位。不要创建或修改待办，也不要查询网页。"
        replaceText(input, with: request)
        try tap("companion.send")
        var response: String?
        var responseID: String?
        let completed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard !self.app.buttons["停止回应"].exists else { return false }
            for row in rows.allElementsBoundByIndex where !oldIDs.contains(row.identifier) {
                let content = ([row.label] + row.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: "\n")
                if content.contains("清迈") || content.localizedCaseInsensitiveContains("Chiang Mai") {
                    response = content
                    responseID = row.identifier
                    return true
                }
            }
            return false
        }, object: app)
        let outcome = XCTWaiter.wait(for: [completed], timeout: 90)
        let latest = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "有新内容")).firstMatch
        if latest.exists && latest.isHittable { latest.tap() }
        capture("actual-current-city-reply")
        XCTAssertEqual(outcome, .completed, "No completed real reply recognizing the actual selected city")
        let actual = try XCTUnwrap(response)
        XCTAssertFalse(["当前选中的地图城市是万象", "当前选中的搜索城市是万象", "当前搜索城市是万象"].contains(where: actual.contains))
        XCTAssertTrue(["不能", "不代表", "不等于", "并非", "不是", "无法"].contains(where: actual.contains),
                      "Selected city must not be presented as actual GPS presence")
        let identity = XCTAttachment(string: "actualResponseIdentifier=\(responseID ?? "unavailable"); selectedCityUI=清迈; userRequestContainsCityName=false")
        identity.name = "current-city-real-response-identity"
        identity.lifetime = .keepAlways
        add(identity)
        replaceText(element("companion.composer"), with: originalText)
        originalDraftToRestore = nil
    }

    func test15DirtyInviteCloseCancellation() throws {
        try selectChiangMai()
        try openPlace("exp_cmi_nimman_coffee")
        try expandPlaceSheetForAudit()
        try tap("companion.place.invite")
        // SwiftUI's multiline control is a modern VerticalTextView. Its
        // stable identifier avoids the legacy .textFields type assumption.
        let note = element("companion.place.inviteNote")
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        let marker = "先坐一会儿，不赶行程。"
        replaceText(note, with: marker)
        XCTAssertEqual(note.value as? String, marker)
        capture("dirty-invite-note-before-close")
        let handle = app.buttons["表单控制柄"].firstMatch
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: app.frame.midX, dy: 760)))
        XCTAssertTrue(element("companion.place.close").exists, "Dirty form must stay after a dismissal swipe")
        try tap("companion.place.close")
        let discard = app.buttons["放弃本次修改"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        capture("dirty-invite-explicit-close-choices")
        let cancel = app.buttons["取消"].firstMatch
        if cancel.exists && cancel.isHittable { cancel.tap() }
        else { app.navigationBars.staticTexts["Nimman Roasters"].firstMatch.tap() }
        XCTAssertEqual(note.value as? String, marker, "Cancelling close must retain the edited text")
        capture("dirty-invite-cancel-preserves-note")
        try tap("companion.place.close")
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap() // Only the unsaved QA edit, never the saved invitation.
        XCTAssertTrue(element("companion.nearby.city").waitForExistence(timeout: 5))
        try tap("companion.surface.now")
        capture("dirty-invite-discard-returns-to-original-stream")
    }

    func test16RealReplyFollowsBottomButPreservesReadingHistory() throws {
        try tap("companion.surface.now")
        let input = element("companion.composer")
        let original = input.value as? String ?? ""
        let originalText = original == input.placeholderValue ? "" : original
        originalDraftToRestore = originalText
        let rows = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "companion.message."))
        let stream = app.scrollViews["companion.stream"].firstMatch
        XCTAssertTrue(stream.waitForExistence(timeout: 5))
        let latest = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "有新内容")).firstMatch

        func body(_ row: XCUIElement, excluding request: String) -> XCUIElement? {
            guard !row.staticTexts["你"].exists else { return nil }
            return row.staticTexts.allElementsBoundByIndex.first {
                $0.label.count > 15 && !$0.label.contains(request)
            }
        }
        func waitForActualReply(oldIDs: Set<String>, request: String) throws -> XCUIElement {
            var resultID: String?
            let complete = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard !self.app.buttons["停止回应"].exists else { return false }
                for row in rows.allElementsBoundByIndex where !oldIDs.contains(row.identifier) {
                    if body(row, excluding: request) != nil {
                        resultID = row.identifier
                        return true
                    }
                }
                return false
            }, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 90), .completed,
                           "No completed actual reply; no transport fixture or artificial delay is permitted")
            return element(try XCTUnwrap(resultID))
        }
        func viewport() -> CGRect {
            let header = element("companion.header").frame
            let composer = element("companion.input.area").frame
            return CGRect(x: app.frame.minX, y: header.maxY,
                          width: app.frame.width, height: max(0, composer.minY - header.maxY))
        }
        func tailVisible(_ text: XCUIElement) -> Bool {
            let frame = text.frame
            let visible = viewport()
            return !frame.isEmpty && !visible.isEmpty && frame.maxY > visible.minY
                && frame.maxY <= visible.maxY + 2 && frame.minX < visible.maxX && frame.maxX > visible.minX
        }
        func record(_ name: String, _ values: [String: Any]) {
            let bytes = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(string: bytes.flatMap { String(data: $0, encoding: .utf8) } ?? "unavailable")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        let firstRequest = "明早去素贴山这件事，给我一个最轻松的安排建议，用一小段话回答。只讨论，不要新增或修改待办，不要查网页。"
        let beforeFirst = Set(rows.allElementsBoundByIndex.map(\.identifier))
        replaceText(input, with: firstRequest)
        try tap("companion.send")
        let firstReply = try waitForActualReply(oldIDs: beforeFirst, request: firstRequest)
        let firstBody = try XCTUnwrap(body(firstReply, excluding: firstRequest))
        let automaticTailVisible = tailVisible(firstBody)
        let automaticUnreadAbsent = !latest.exists
        capture("scroll-bottom-actual-completed-reply-before-any-recovery")
        record("scroll-bottom-actual-observation", [
            "responseIdentifier": firstReply.identifier,
            "replyTailVisibleAboveComposer": automaticTailVisible,
            "newContentButtonAbsent": automaticUnreadAbsent,
            "responseMaxY": firstBody.frame.maxY,
            "composerMinY": element("companion.input.area").frame.minY
        ])
        // This is only a precondition for branch two; it cannot change branch
        // one's recorded result. Never label a recovery tap automatic following.
        if latest.exists && latest.isHittable { latest.tap() }

        let secondRequest = "接着明早去素贴山这件事，按出发前、路上、到达后各写几句，帮我少赶路、多留休息。不要推测营业时间或具体路况。只讨论，不要新增、完成或修改待办，不要查网页。"
        let beforeSecond = Set(rows.allElementsBoundByIndex.map(\.identifier))
        replaceText(element("companion.composer"), with: secondRequest)
        try tap("companion.send")
        let workingBeforeSwipe = app.buttons["停止回应"].exists
        if workingBeforeSwipe { stream.swipeDown(velocity: .slow) }
        let workingAfterSwipe = app.buttons["停止回应"].exists
        let visible = viewport().insetBy(dx: 0, dy: 8)
        var anchorID: String?
        var anchorLabel: String?
        var anchorFrame: CGRect?
        if workingBeforeSwipe && workingAfterSwipe {
            for row in rows.allElementsBoundByIndex where beforeSecond.contains(row.identifier) {
                if let text = row.staticTexts.allElementsBoundByIndex.first(where: {
                    $0.label.count > 20 && visible.contains($0.frame) && !$0.frame.isEmpty
                }) {
                    anchorID = row.identifier
                    anchorLabel = text.label
                    anchorFrame = text.frame
                    break
                }
            }
        }
        capture("scroll-history-actual-waiting-anchor")
        let secondReply = try waitForActualReply(oldIDs: beforeSecond, request: secondRequest)
        var preservedHistory = false
        var drift: CGFloat?
        if let anchorID, let anchorLabel, let anchorFrame {
            let same = element(anchorID).staticTexts.matching(NSPredicate(format: "label == %@", anchorLabel)).firstMatch
            if same.exists {
                drift = abs(same.frame.minY - anchorFrame.minY)
                preservedHistory = visible.contains(same.frame) && (drift ?? .infinity) <= 12
            }
        }
        let newContentVisible = latest.exists && latest.isHittable
        capture("scroll-history-actual-reply-arrived-before-new-content-tap")
        record("scroll-history-actual-observation", [
            "responseIdentifier": secondReply.identifier,
            "workingBeforeActualSwipe": workingBeforeSwipe,
            "workingAfterActualSwipe": workingAfterSwipe,
            "anchorIdentifier": anchorID ?? "not-observed",
            "anchorStillVisibleAtSamePosition": preservedHistory,
            "anchorVerticalDrift": drift.map { Double($0) } ?? -1,
            "newContentVisible": newContentVisible,
            "boundary": "Without a visible historical anchor while still working, reading branch is unverified; no artificial response delay."
        ])
        if newContentVisible { latest.tap() }
        let secondBody = try XCTUnwrap(body(secondReply, excluding: secondRequest))
        let reachedLatest = newContentVisible && tailVisible(secondBody)
        capture("scroll-after-actual-new-content-tap")
        replaceText(element("companion.composer"), with: originalText)
        originalDraftToRestore = nil
        XCTAssertTrue(automaticTailVisible && automaticUnreadAbsent, "Bottom reply was not completely followed automatically")
        XCTAssertTrue(workingBeforeSwipe && workingAfterSwipe && anchorID != nil,
                      "Reading branch unverified: could not observe an actual historical anchor before the real response completed")
        XCTAssertTrue(preservedHistory && newContentVisible, "Actual reply moved the observed history or omitted the new-content control")
        XCTAssertTrue(reachedLatest, "Actual new-content tap did not reveal the latest reply tail above the composer")
    }

    func test17RealHistoryAnchorAndInsetAfterNewContent() throws {
        try tap("companion.surface.now")
        let input = element("companion.composer")
        let original = input.value as? String ?? ""
        let originalText = original == input.placeholderValue ? "" : original
        originalDraftToRestore = originalText
        let rows = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH %@", "companion.message."))
        let stream = app.scrollViews["companion.stream"].firstMatch
        XCTAssertTrue(stream.waitForExistence(timeout: 5))
        let latest = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "有新内容")).firstMatch
        if latest.exists && latest.isHittable { latest.tap() }
        func viewport() -> CGRect {
            let top = element("companion.header").frame.maxY
            let bottom = element("companion.input.area").frame.minY
            return CGRect(x: app.frame.minX, y: top, width: app.frame.width, height: max(0, bottom - top))
        }
        func record(_ name: String, _ values: [String: Any]) {
            let data = try? JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(string: data.flatMap { String(data: $0, encoding: .utf8) } ?? "unavailable")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let request = "明早去素贴山这件事，想再听一份稍详细、约250字的轻松安排建议。请按出发前、路上、到达后展开，重点讲怎样少赶路和留出休息，不推测当天营业时间或具体路况。只讨论，不要新增、完成或修改待办，不要查询网页。"
        replaceText(input, with: request)
        try tap("companion.send")
        let actualUserRow = rows.containing(NSPredicate(format: "label == %@", request)).firstMatch
        XCTAssertTrue(actualUserRow.waitForExistence(timeout: 5), "Observe the exact new user row before associating any reply")
        let userPrefix = "companion.message."
        let userIdentifier = actualUserRow.identifier
        XCTAssertTrue(userIdentifier.hasPrefix(userPrefix))
        guard userIdentifier.hasPrefix(userPrefix) else { throw MissingControl.id("actual-current-user-identity") }
        let userID = String(userIdentifier.dropFirst(userPrefix.count))
        let replyBodyID = "companion.reply-to.\(userID)"
        let workingBeforeDrag = app.buttons["停止回应"].exists
        let area = viewport().insetBy(dx: 14, dy: 12)
        if workingBeforeDrag && !area.isEmpty {
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: area.midX, dy: area.minY + area.height * 0.3))
            let end = origin.withOffset(CGVector(dx: area.midX, dy: area.minY + area.height * 0.78))
            // Real quick drag, then stop inertia; do not slow down or replace
            // the model response to make the waiting window artificially long.
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0.1)
        }
        let workingAfterDrag = app.buttons["停止回应"].exists
        let visible = viewport().insetBy(dx: 0, dy: 8)
        var anchorID: String?
        var anchorText: String?
        var anchorFrame: CGRect?
        if workingBeforeDrag && workingAfterDrag {
            for row in rows.allElementsBoundByIndex {
                if let text = row.staticTexts.allElementsBoundByIndex.first(where: {
                    $0.label.count > 20 && !$0.label.contains(request)
                        && !$0.frame.isEmpty && visible.contains($0.frame)
                }) {
                    anchorID = row.identifier
                    anchorText = text.label
                    anchorFrame = text.frame
                    break
                }
            }
        }
        // A response may finish while AX materializes the anchor. Require a
        // third real working observation after recording its position as well.
        let workingAtRecordedAnchor = anchorID != nil && app.buttons["停止回应"].exists
        capture("history17-actual-anchor-while-working")
        let complete = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !self.app.buttons["停止回应"].exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 90), .completed)
        var drift: CGFloat?
        var stayed = false
        if let anchorID, let anchorText, let anchorFrame {
            let same = element(anchorID).staticTexts.matching(NSPredicate(format: "label == %@", anchorText)).firstMatch
            if same.exists {
                drift = abs(same.frame.minY - anchorFrame.minY)
                stayed = viewport().insetBy(dx: 0, dy: 8).contains(same.frame) && (drift ?? .infinity) <= 12
            }
        }
        let newContentVisible = latest.exists && latest.isHittable
        record("history17-before-new-content-tap", [
            "workingBeforeActualDrag": workingBeforeDrag,
            "workingAfterActualDrag": workingAfterDrag,
            "workingAtRecordedAnchor": workingAtRecordedAnchor,
            "anchorIdentifier": anchorID ?? "not-observed",
            "anchorStillVisibleAtSamePosition": stayed,
            "anchorVerticalDrift": drift.map { Double($0) } ?? -1,
            "newContentVisible": newContentVisible,
            "boundary": "No observed anchor while actually working means reading branch remains unverified."
        ])
        capture("history17-arrival-before-user-taps-new-content")
        if newContentVisible { latest.tap() }
        let preciseReplyBody = element(replyBodyID)
        let materialized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            // Match the actual request identity, not the set of currently
            // materialized lazy rows. Host QA independently reads replyToID.
            guard preciseReplyBody.exists, !preciseReplyBody.frame.isEmpty else { return false }
            let v = viewport()
            return preciseReplyBody.frame.maxY > v.minY && preciseReplyBody.frame.maxY <= v.maxY + 2
        }, object: app)
        let materializedResult = XCTWaiter.wait(for: [materialized], timeout: 12)
        var leftInset: CGFloat?
        var rightInset: CGFloat?
        if preciseReplyBody.exists {
            leftInset = preciseReplyBody.frame.minX - app.frame.minX
            rightInset = app.frame.maxX - preciseReplyBody.frame.maxX
        }
        record("history17-after-new-content-materialization", [
            "actualUserIdentifier": userIdentifier,
            "preciseReplyBodyIdentifier": replyBodyID,
            "actualMaterializationWaitCompleted": materializedResult == .completed,
            "bodyLeftInset": leftInset.map { Double($0) } ?? -1,
            "bodyRightInset": rightInset.map { Double($0) } ?? -1,
            "hostMustCorrelateActualReplyToRequest": true
        ])
        capture("history17-final-inset-and-reply-tail")
        replaceText(element("companion.composer"), with: originalText)
        originalDraftToRestore = nil
        XCTAssertTrue(workingBeforeDrag && workingAfterDrag && workingAtRecordedAnchor,
                      "History branch unverified: no fixed visible anchor observed before real reply completed")
        XCTAssertTrue(stayed && newContentVisible, "Reply did not preserve the actual historical reading position and new-content control")
        XCTAssertEqual(materializedResult, .completed, "Latest body did not materialize above composer after the real new-content tap")
        XCTAssertGreaterThanOrEqual(leftInset ?? -1, 20, "Conversation lost its left horizontal margin")
        XCTAssertGreaterThanOrEqual(rightInset ?? -1, 20, "Conversation lost its right horizontal margin")
    }

    func test18RelaunchShowsStoredConversationAndMapWithoutModel() throws {
        // Existing persisted messages only. No request, draft edit, selected
        // city change, fixture, private host-data UUID, or record deletion.
        app.terminate()
        app.launch()
        XCTAssertTrue(element("companion.surface.now").waitForExistence(timeout: 20))
        let bodies = app.staticTexts.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
            "companion.reply-to.", "companion.message.body."))
        func visibleBodies() -> [XCUIElement] {
            let header = element("companion.header").frame
            let composer = element("companion.input.area").frame
            guard !header.isEmpty, !composer.isEmpty, composer.minY > header.maxY else { return [] }
            let visible = CGRect(x: app.frame.minX, y: header.maxY, width: app.frame.width,
                                 height: composer.minY - header.maxY)
            return bodies.allElementsBoundByIndex.filter {
                guard !$0.frame.isEmpty, $0.label.count > 3 else { return false }
                let overlap = $0.frame.intersection(visible)
                return !overlap.isNull && overlap.width >= 40 && overlap.height >= 18
            }
        }
        func recordFace(_ stage: String) {
            capture(stage)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = stage + "-actual-AX-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        func assertVisibleStoredBody(_ stage: String) {
            let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                !visibleBodies().isEmpty
            }, object: app)
            let outcome = XCTWaiter.wait(for: [visible], timeout: 10)
            recordFace(stage)
            let observed = visibleBodies().map {
                "\($0.identifier) frame=\($0.frame) characters=\($0.label.count)"
            }.joined(separator: "\n")
            let detail = XCTAttachment(string: "visibleStoredBodies=\(visibleBodies().count)\n" + observed)
            detail.name = stage + "-visible-body-geometry"
            detail.lifetime = .keepAlways
            add(detail)
            XCTAssertEqual(outcome, .completed,
                           "Stored conversation must actually occupy the header/composer viewport after relaunch, not merely exist offscreen")
        }
        assertVisibleStoredBody("relaunch18-stored-conversation-visible")
        try tap("companion.surface.nearby")
        let city = element("companion.nearby.city")
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        XCTAssertTrue(city.isHittable && !city.label.isEmpty)
        let nativeMap = app.maps.firstMatch
        XCTAssertTrue(nativeMap.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(nativeMap.frame.intersection(app.frame).height, 100)
        recordFace("relaunch18-nearby-map-and-city")
        try tap("companion.surface.now")
        assertVisibleStoredBody("relaunch18-back-to-stored-conversation")
    }

    /// XCTest calls tearDown even when continueAfterFailure aborts the method.
    /// Originals stay in runner memory, never in log attachments or the repo.
    /// This restores only the temporary composer/favorite changes; it never
    /// removes conversation entries, people, invitations, or unrelated favorites.
    private func restoreTemporaryStateAfterFailure() {
        guard originalDraftToRestore != nil || originalFavoriteToRestore != nil || originalPeopleLabelsToRestore != nil else { return }
        app.terminate()
        configureLaunch()
        app.launch()
        if originalPeopleLabelsToRestore != nil {
            try? restoreOriginalPeopleSelection()
        }
        var draftRestored = originalDraftToRestore == nil
        var favoriteRestored = originalFavoriteToRestore == nil
        if let draft = originalDraftToRestore {
            let input = element("companion.composer")
            if input.waitForExistence(timeout: 10), input.isHittable {
                replaceText(input, with: draft)
                draftRestored = (input.value as? String) == draft
                    || (draft.isEmpty && (input.value as? String) == input.placeholderValue)
            }
        }
        if let prior = originalFavoriteToRestore,
           recoveryTap("companion.surface.nearby"), recoveryTap("companion.nearby.city") {
            let search = element("companion.city.search")
            if search.waitForExistence(timeout: 5), search.isHittable {
                search.tap()
                search.typeText("cmi")
                if recoveryTap("companion.city.option.cmi") {
                    let card = element("companion.nearby.place.\(prior.id)")
                    let strip = element("companion.nearby.candidates")
                    revealCandidate(card, in: strip)
                    if card.waitForExistence(timeout: 5), candidateCenterIsVisible(card, in: strip) {
                        card.tap()
                        let favorite = element("companion.place.favorite")
                        if favorite.waitForExistence(timeout: 5), favorite.isHittable {
                            let isSaved = favorite.label.contains("取消") || (favorite.value as? String) == "已收藏"
                            if isSaved != prior.saved { favorite.tap() }
                            favoriteRestored = waitForFavorite(saved: prior.saved)
                        }
                    }
                }
            }
        }
        let outcome = XCTAttachment(string: "draftRestored=\(draftRestored); favoriteRestored=\(favoriteRestored)")
        outcome.name = "temporary-state-restoration-no-user-text"
        outcome.lifetime = .keepAlways
        add(outcome)
        originalDraftToRestore = nil
        originalFavoriteToRestore = nil
    }

    private func recoveryTap(_ id: String) -> Bool {
        let target = element(id)
        guard target.waitForExistence(timeout: 5), target.isHittable else { return false }
        target.tap()
        return true
    }

}
