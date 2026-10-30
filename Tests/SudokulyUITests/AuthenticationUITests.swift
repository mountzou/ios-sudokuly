import XCTest

@MainActor
final class AuthenticationUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(error: Bool = false) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--auth-testing"] + (error ? ["--auth-scenario=error"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["sign-in-google"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["sign-in-apple"].exists)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testGoogleEntryAccountAndSignOut() {
        launch()
        capture("sign-in")
        app.buttons["sign-in-google"].tap()
        XCTAssertTrue(app.buttons["difficulty-easy"].waitForExistence(timeout: 5))
        app.buttons["account"].tap()
        XCTAssertTrue(app.staticTexts["account-email"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["account-email"].label, "player@example.test")
        XCTAssertEqual(app.sheets.count, 0)
        XCTAssertTrue(app.buttons["account-back"].exists)
        XCTAssertFalse(app.buttons["Done"].exists)
        capture("account")
        let privacyLink = app.descendants(matching: .any).matching(identifier: "account-privacy-policy").firstMatch
        XCTAssertTrue(privacyLink.isHittable)
        privacyLink.tap()
        let browser = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(browser.wait(for: .runningForeground, timeout: 10))
        let browserAttachment = XCTAttachment(screenshot: browser.screenshot())
        browserAttachment.name = "account-privacy-browser"
        browserAttachment.lifetime = .keepAlways
        add(browserAttachment)
        app.activate()
        XCTAssertTrue(app.staticTexts["account-email"].waitForExistence(timeout: 3))
        app.buttons["account-back"].tap()
        XCTAssertTrue(app.buttons["difficulty-easy"].waitForExistence(timeout: 3))
        app.buttons["history"].tap()
        XCTAssertTrue(app.staticTexts["history-empty"].waitForExistence(timeout: 3))
        app.buttons["history-close"].tap()
        XCTAssertTrue(app.buttons["account"].waitForExistence(timeout: 3))
        app.buttons["account"].tap()
        XCTAssertTrue(app.staticTexts["account-email"].waitForExistence(timeout: 3))
        app.buttons["sign-out"].tap()
        app.alerts.buttons["Sign out"].tap()
        XCTAssertTrue(app.buttons["sign-in-google"].waitForExistence(timeout: 5))
    }

    func testAppleEntryAndAccountDeletion() {
        launch()
        app.buttons["sign-in-apple"].tap()
        XCTAssertTrue(app.buttons["difficulty-easy"].waitForExistence(timeout: 5))
        app.buttons["account"].tap()
        XCTAssertTrue(app.staticTexts["account-email"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["account-email"].label, "player@example.test")
        app.buttons["delete-account"].tap()
        app.alerts.buttons["Delete account"].tap()
        XCTAssertTrue(app.buttons["sign-in-apple"].waitForExistence(timeout: 5))
    }

    func testFailedSignInStaysOnSignInScreen() {
        launch(error: true)
        app.buttons["sign-in-google"].tap()
        XCTAssertTrue(app.staticTexts["auth-error"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["difficulty-easy"].exists)
        XCTAssertTrue(app.buttons["sign-in-google"].isEnabled)
    }

    func testFailedAppleSignInStaysOnSignInScreen() {
        launch(error: true)
        app.buttons["sign-in-apple"].tap()
        XCTAssertTrue(app.staticTexts["auth-error"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["difficulty-easy"].exists)
        XCTAssertTrue(app.buttons["sign-in-google"].isEnabled)
        XCTAssertTrue(app.buttons["sign-in-apple"].isEnabled)
    }

    func testNormalLaunchShowsProviderButtons() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["sign-in-google"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["sign-in-apple"].exists)
        XCTAssertFalse(app.staticTexts["auth-error"].exists)
        let notice = app.descendants(matching: .any)["privacy-notice"]
        XCTAssertTrue(notice.exists)
        let version = app.staticTexts["appVersion"]
        XCTAssertTrue(version.exists)
        XCTAssertTrue(version.label.hasPrefix("Version "))
        XCTAssertNotEqual(version.label, "Version —")
        if !version.isHittable { app.swipeUp() }
        let screen = app.frame
        let bottomGap = screen.maxY - version.frame.maxY
        let brand = app.descendants(matching: .any)["sign-in-brand"]
        XCTAssertFalse(brand.exists)
        XCTAssertFalse(app.staticTexts["sudokuly"].exists)
        let headline = app.staticTexts["sign-in-headline"]
        let description = app.staticTexts["sign-in-description"]
        let apple = app.buttons["sign-in-apple"]
        let google = app.buttons["sign-in-google"]
        let privacyFrame = notice.frame.union(app.staticTexts["privacy-terms"].frame)
        let geometry = XCTAttachment(string: "screen=\(screen)\nheadline=\(headline.frame)\nsubtitle=\(description.frame)\napple=\(apple.frame)\ngoogle=\(google.frame)\nprivacy=\(privacyFrame)\nversion=\(version.frame)\nbottomGap=\(bottomGap)")
        geometry.name = "sign-in-layout"
        geometry.lifetime = .keepAlways
        add(geometry)
        capture("sign-in-production")
        XCTAssertEqual(bottomGap / screen.height, 0.05, accuracy: 0.005,
                       "Version should end 5% of the screen height above the physical bottom")
        XCTAssertEqual(description.frame.minY - headline.frame.maxY, 14, accuracy: 1)
        XCTAssertEqual(apple.frame.minY - description.frame.maxY, 28, accuracy: 1)
        XCTAssertEqual(google.frame.minY - apple.frame.maxY, 14, accuracy: 1)
        XCTAssertEqual(privacyFrame.minY - google.frame.maxY, 28, accuracy: 1)
        XCTAssertEqual(version.frame.minY - privacyFrame.maxY, 20, accuracy: 1)
        for button in [apple, google] {
            XCTAssertEqual(button.frame.height, 52, accuracy: 1)
            XCTAssertEqual(button.frame.width, min(420, screen.width - 56), accuracy: 1)
            XCTAssertEqual(button.frame.midX, screen.midX, accuracy: 1)
            XCTAssertTrue(button.isHittable)
        }
        let privacyLink = app.descendants(matching: .any).matching(identifier: "sign-in-privacy-policy").firstMatch
        XCTAssertTrue(privacyLink.isHittable)
        privacyLink.tap()
        let browser = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(browser.wait(for: .runningForeground, timeout: 10))
        app.activate()
        XCTAssertTrue(apple.waitForExistence(timeout: 3))
    }
}
