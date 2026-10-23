import XCTest

/// Runs the installed app with native controls. No mailbox requests, fake account,
/// database erasure, or assumed provider success. Terms use the argument domain.
@MainActor
final class AccountOnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.solocompass.app")
        app.launchArguments = ["-forceOnboarding", "-SoloCompass.hasAcceptedTerms", "YES",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchEnvironment["FF_CONTINUOUS_COMPANION"] = "1"
        app.launch()
        XCTAssertTrue(app.textFields["account.email"].waitForExistence(timeout: 25))
    }

    override func tearDownWithError() throws { app?.terminate() }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func test01InvalidEmailKeepsTheRealEntryRecoverable() {
        capture("email-entry-zh")
        let field = app.textFields["account.email"]
        field.tap(); field.typeText("not-an-email")
        app.buttons["account.continue"].tap()
        XCTAssertTrue(app.staticTexts["account.notice"].waitForExistence(timeout: 5))
        XCTAssertTrue(field.exists)
        XCTAssertEqual(field.value as? String, "not-an-email")
        capture("email-invalid-recoverable")
    }

    func test02GuestCanStartWithoutGoogleOrEmail() {
        app.buttons["account.guest"].tap()
        let start = app.buttons["account.welcome.continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 6))
        capture("guest-welcome")
        start.tap()
        XCTAssertTrue(app.buttons["companion.surface.now"].waitForExistence(timeout: 20))
        capture("guest-companion-started")
    }

    func test03ExistingAccountPasswordIsSecureAndOptional() {
        app.buttons["已有账户？用密码登录"].tap()
        XCTAssertTrue(app.secureTextFields["account.password"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["account.guest"].exists)
        capture("existing-account-password-entry")
        app.buttons["改用邮箱验证码"].tap()
        XCTAssertFalse(app.secureTextFields["account.password"].exists)
        XCTAssertTrue(app.textFields["account.email"].exists)
    }
}
