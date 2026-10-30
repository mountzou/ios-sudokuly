import XCTest

@MainActor
final class SignInLayoutUITests: XCTestCase {
    func testDefaultTextLayout() {
        verifyLayout(category: "UICTContentSizeCategoryL", name: "default")
    }

    func testLargestStandardTextLayout() {
        verifyLayout(category: "UICTContentSizeCategoryXXXL", name: "large-text")
    }

    func testLargestAccessibilityTextLayout() {
        verifyLayout(category: "UICTContentSizeCategoryAccessibilityXXXL", name: "accessibility")
    }

    private func verifyLayout(category: String, name: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--auth-testing", "-UIPreferredContentSizeCategoryName", category]
        app.launch()
        let apple = app.buttons["sign-in-apple"]
        let google = app.buttons["sign-in-google"]
        XCTAssertTrue(google.waitForExistence(timeout: 8))
        let headline = app.staticTexts["sign-in-headline"]
        let subtitle = app.staticTexts["sign-in-description"]
        let notice = app.staticTexts["privacy-notice"]
        let policy = app.descendants(matching: .any).matching(identifier: "sign-in-privacy-policy").firstMatch
        let terms = app.staticTexts["privacy-terms"]
        let version = app.staticTexts["appVersion"]
        let elements = [headline, subtitle, apple, google, notice, policy, terms, version]
        let screen = app.frame
        for element in elements {
            XCTAssertTrue(element.exists)
            XCTAssertGreaterThan(element.frame.width, 0)
            XCTAssertGreaterThan(element.frame.height, 0)
            XCTAssertGreaterThanOrEqual(element.frame.minX, 27)
            XCTAssertLessThanOrEqual(element.frame.maxX, screen.maxX - 27)
        }
        for (upper, lower) in zip([headline, subtitle, apple, google, notice], [subtitle, apple, google, notice, policy]) {
            XCTAssertLessThanOrEqual(upper.frame.maxY, lower.frame.minY, "Login elements must not overlap")
        }
        XCTAssertGreaterThanOrEqual(version.frame.minY - max(policy.frame.maxY, terms.frame.maxY), 19)
        XCTAssertEqual(apple.frame.midX, screen.midX, accuracy: 1)
        XCTAssertEqual(google.frame.midX, screen.midX, accuracy: 1)
        XCTAssertGreaterThanOrEqual(apple.frame.height, 44)
        XCTAssertGreaterThanOrEqual(google.frame.height, 44)
        if category == "UICTContentSizeCategoryAccessibilityXXXL" {
            XCTAssertGreaterThan(headline.frame.height, 100, "Accessibility text sizing must actually be active")
            XCTAssertGreaterThan(apple.frame.height, 52, "Accessibility labels need room to wrap without truncation")
            XCTAssertGreaterThan(google.frame.height, 52)
        }
        let geometry = XCTAttachment(string: "category=\(category)\nscreen=\(screen)\n" + elements.map { "\($0.identifier)=\($0.frame)" }.joined(separator: "\n"))
        geometry.name = "login-geometry-\(name)"
        geometry.lifetime = .keepAlways
        add(geometry)
        capture(app, "login-\(name)-top")
        if category == "UICTContentSizeCategoryL" {
            XCTAssertTrue(apple.isHittable)
            XCTAssertTrue(google.isHittable)
            XCTAssertTrue(version.isHittable, "Standard text should fit without scrolling on supported iPhones")
            XCTAssertEqual((screen.maxY - version.frame.maxY) / screen.height, 0.05, accuracy: 0.005)
        }
        for element in [apple, google, policy, version] {
            for _ in 0..<8 {
                if element.isHittable && element.frame.maxY <= screen.maxY - 20 { break }
                app.swipeUp()
            }
            XCTAssertTrue(element.isHittable, "Every login control and footer must remain reachable by scrolling")
            XCTAssertLessThanOrEqual(element.frame.maxY, screen.maxY - 19)
        }
        capture(app, "login-\(name)-footer")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
