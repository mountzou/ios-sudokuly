import XCTest

@MainActor
final class AccountLayoutUITests: XCTestCase {
    func testDefaultAccountLayout() {
        verifyLayout(category: "UICTContentSizeCategoryL", name: "default")
    }

    func testAccessibilityAccountLayout() {
        verifyLayout(category: "UICTContentSizeCategoryAccessibilityXXXL", name: "accessibility")
    }

    private func verifyLayout(category: String, name: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--game-testing", "--ui-testing", "-UIPreferredContentSizeCategoryName", category]
        app.launch()
        XCTAssertTrue(app.buttons["account"].waitForExistence(timeout: 8))
        app.buttons["account"].tap()
        let accountName = app.staticTexts["account-name"]
        XCTAssertTrue(accountName.waitForExistence(timeout: 5))
        let viewport = app.scrollViews["account-content"]
        let back = app.buttons["account-back"]
        let privacy = app.descendants(matching: .any).matching(identifier: "account-privacy-policy").firstMatch
        let email = app.staticTexts["account-email"]
        let signOut = app.buttons["sign-out"]
        let delete = app.buttons["delete-account"]
        XCTAssertTrue(viewport.exists)
        XCTAssertGreaterThanOrEqual(viewport.frame.minY, back.frame.maxY - 1)
        XCTAssertLessThanOrEqual(viewport.frame.maxY, privacy.frame.minY + 1)
        XCTAssertEqual(accountName.frame.minY, viewport.frame.midY + 25, accuracy: 1)
        XCTAssertLessThanOrEqual(accountName.frame.maxY, email.frame.minY)
        XCTAssertLessThanOrEqual(email.frame.maxY, signOut.frame.minY)
        XCTAssertLessThanOrEqual(signOut.frame.maxY, delete.frame.minY)
        for element in [accountName, email, signOut, delete] {
            XCTAssertGreaterThanOrEqual(element.frame.minX, 27)
            XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX - 27)
        }
        XCTAssertEqual(signOut.frame.midX, app.frame.midX, accuracy: 1)
        let originalBackFrame = back.frame
        let originalPrivacyFrame = privacy.frame
        let geometry = XCTAttachment(string: "category=\(category)\nscreen=\(app.frame)\nviewport=\(viewport.frame)\nillustrationSize=\(viewport.frame.height * 0.3)\nname=\(accountName.frame)\nemail=\(email.frame)\nsignOut=\(signOut.frame)\ndelete=\(delete.frame)\nprivacy=\(privacy.frame)")
        geometry.name = "account-geometry-\(name)"
        geometry.lifetime = .keepAlways
        add(geometry)
        capture(app, "account-\(name)-top")
        for element in [signOut, delete] {
            for _ in 0..<6 {
                if element.isHittable && element.frame.maxY <= viewport.frame.maxY { break }
                viewport.swipeUp()
            }
            XCTAssertTrue(element.isHittable)
            XCTAssertLessThanOrEqual(element.frame.maxY, viewport.frame.maxY + 1)
        }
        capture(app, "account-\(name)-footer")
        XCTAssertTrue(back.isHittable)
        XCTAssertTrue(privacy.isHittable)
        XCTAssertEqual(back.frame.minY, originalBackFrame.minY, accuracy: 1)
        XCTAssertEqual(privacy.frame.minY, originalPrivacyFrame.minY, accuracy: 1)
        back.tap()
        XCTAssertTrue(app.buttons["account"].waitForExistence(timeout: 5))
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
