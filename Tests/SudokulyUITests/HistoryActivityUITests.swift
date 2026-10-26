import XCTest

@MainActor
final class HistoryActivityUITests: XCTestCase {
    private func launch(preview: Bool = false, registrationDaysAgo: Int = 800) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--game-testing", "--ui-testing", "--registration-days-ago=\(registrationDaysAgo)"]
        if preview { app.launchArguments += ["--history-demo", "--activity-year-demo"] }
        app.launch()
        XCTAssertTrue(app.buttons["account"].waitForExistence(timeout: 5))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }

    func testYearPreviewAppearsBelowStatsAndAccountKeepsItsFixedPrivacyLink() {
        let app = launch(preview: true)
        app.buttons["history"].tap()
        let summary = app.staticTexts["history-activity-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertNotEqual(summary.label, "0 days with a solved puzzle")
        XCTAssertTrue(app.staticTexts["Demo preview"].exists)
        let grid = app.descendants(matching: .any).matching(identifier: "history-activity-grid").firstMatch
        XCTAssertTrue(grid.exists)
        let played = app.descendants(matching: .any)["history-count"]
        XCTAssertTrue(played.exists)
        XCTAssertLessThan(played.frame.maxY, summary.frame.minY)
        XCTAssertFalse(app.staticTexts["Scroll to explore"].exists)
        capture(app, "progress-year-activity-preview")
        grid.swipeRight()
        capture(app, "progress-year-activity-earlier-months")
        app.buttons["history-close"].tap()
        app.buttons["account"].tap()
        XCTAssertTrue(app.staticTexts["account-email"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["history-activity"].exists)
        let privacy = app.descendants(matching: .any).matching(identifier: "account-privacy-policy").firstMatch
        XCTAssertTrue(privacy.isHittable)
        let originalY = privacy.frame.midY
        capture(app, "account-without-year-activity")
        app.swipeUp()
        XCTAssertTrue(privacy.isHittable)
        XCTAssertEqual(privacy.frame.midY, originalY, accuracy: 1)
        XCTAssertLessThan(app.frame.maxY - privacy.frame.maxY, 90)
    }

    func testNewAccountShowsAnEmptyYearWithoutDemoActivity() {
        let app = launch(registrationDaysAgo: 0)
        app.buttons["history"].tap()
        let summary = app.staticTexts["history-activity-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["history-empty"].exists)
        XCTAssertEqual(summary.label, "0 days with a solved puzzle")
        XCTAssertFalse(app.staticTexts["Demo preview"].exists)
        capture(app, "progress-year-activity-new-user")
    }

    func testCompletingAPuzzleUpdatesTheYearAndReturningHomeKeepsTodaysCheck() {
        let app = launch()
        app.buttons["difficulty-easy"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        app.buttons["digit-5"].tap()
        app.buttons["cell-1"].tap(); app.buttons["digit-3"].tap()
        app.buttons["cell-2"].tap(); app.buttons["digit-4"].tap()
        XCTAssertTrue(app.buttons["finish"].waitForExistence(timeout: 3))
        app.buttons["finish"].tap()
        app.buttons["history"].tap()
        let summary = app.staticTexts["history-activity-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        XCTAssertEqual(summary.label, "1 day with a solved puzzle")
        capture(app, "progress-year-activity-first-solve")
        app.buttons["history-close"].tap()
        XCTAssertEqual(app.buttons["activity-today"].value as? String, "At least one solved game")
    }
}
