import XCTest

@MainActor
final class HistoryUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(demo: Bool = false, signedOut: Bool = false, greekLocale: Bool = false) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [signedOut ? "--auth-testing" : "--game-testing", "--ui-testing"] + (demo ? ["--history-demo"] : [])
        if greekLocale { app.launchArguments += ["-AppleLanguages", "(el)", "-AppleLocale", "el_GR"] }
        app.launch()
        if signedOut {
            XCTAssertTrue(app.buttons["sign-in-google"].waitForExistence(timeout: 5))
            app.buttons["sign-in-google"].tap()
        }
        XCTAssertTrue(app.buttons["history"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertCount(_ count: Int) {
        let value = app.descendants(matching: .any)["history-count"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        XCTAssertEqual(value.label, "\(count) \(count == 1 ? "game" : "games") played")
        assertProgressHeader()
    }

    private func assertProgressHeader() {
        let header = app.staticTexts["history-header"]
        XCTAssertEqual(header.label, "Your progress")
        XCTAssertEqual(header.frame.midX, app.frame.midX, accuracy: 1.5)
        XCTAssertFalse(app.staticTexts["One puzzle at a time."].exists)
    }

    private func chooseDemo(_ id: String) {
        let controls = app.buttons["demo-scenarios"]
        if !controls.isHittable { app.swipeUp() }
        controls.tap()
        let action = app.buttons[id]
        XCTAssertTrue(action.waitForExistence(timeout: 3))
        if !action.isHittable { app.swipeUp() }
        action.tap()
    }

    func testSixSamplesDetailsAndReturnNavigation() {
        launch(demo: true, greekLocale: true)
        app.buttons["history"].tap()
        assertCount(6)
        capture("history-samples")
        for (index, title) in [(1, "Beautifully\nsolved."), (2, "A pause.\nA fresh start."), (4, "Good things\ntake practice.")] {
            let id = String(format: "history-game-00000000-0000-0000-0000-%012d", index)
            let row = app.buttons[id]
            if !row.isHittable { app.swipeUp() }
            let outerMargin = (app.frame.width - min(app.frame.width, 480)) / 2 + 32
            XCTAssertGreaterThan(row.frame.minX, outerMargin + 4)
            XCTAssertLessThan(row.frame.maxX, app.frame.width - outerMargin - 4)
            XCTAssertNil(row.label.range(of: "[\\p{Greek}]", options: .regularExpression), row.label)
            row.tap()
            XCTAssertTrue(app.staticTexts["history-detail-title"].waitForExistence(timeout: 3))
            let header = app.staticTexts["history-detail-header"]
            XCTAssertEqual(header.label, "Game details")
            XCTAssertEqual(header.frame.midX, app.frame.midX, accuracy: 1.5)
            XCTAssertEqual(app.staticTexts["history-detail-title"].label, title)
            let date = app.staticTexts["history-detail-date"].label
            let time = app.staticTexts["history-detail-time"].label
            XCTAssertNotNil(date.range(of: "January|February|March|April|May|June|July|August|September|October|November|December", options: .regularExpression), date)
            XCTAssertNotNil(time.range(of: "^[0-9]{1,2}:[0-9]{2}\\s*[AP]M$", options: .regularExpression), time)
            XCTAssertFalse(app.staticTexts["Game recap"].exists)
            XCTAssertFalse(app.staticTexts["Every attempt is part of your story."].exists)
            capture("history-detail-\(index)")
            app.buttons["history-detail-back"].tap()
        }
        if !app.buttons["history-close"].isHittable { app.swipeDown() }
        app.buttons["history-close"].tap()
        XCTAssertTrue(app.buttons["difficulty-easy"].waitForExistence(timeout: 3))
    }

    func testFirstGameIsRecordedOnceAndRelaunchClearsIt() {
        launch()
        capture("home-progress-icon")
        app.buttons["history"].tap()
        XCTAssertTrue(app.staticTexts["history-empty"].waitForExistence(timeout: 3))
        assertProgressHeader()
        XCTAssertFalse(app.buttons["history-play"].exists)
        capture("history-empty")
        app.buttons["history-close"].tap()
        app.buttons["difficulty-easy"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        app.buttons["digit-5"].tap()
        app.buttons["cell-1"].tap(); app.buttons["digit-3"].tap()
        app.buttons["cell-2"].tap(); app.buttons["digit-4"].tap()
        XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 3))
        if !app.buttons["result-history"].isHittable { app.swipeUp() }
        app.buttons["result-history"].tap()
        assertCount(1)
        capture("history-one-game-progress")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-game-'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["history-detail-title"].waitForExistence(timeout: 3))
        app.buttons["history-detail-back"].tap()
        assertCount(1)
        app.buttons["history-close"].tap()
        if !app.buttons["finish"].isHittable { app.swipeUp() }
        app.buttons["finish"].tap()
        app.buttons["history"].tap()
        assertCount(1)
        app.terminate()
        app.launch()
        app.buttons["history"].tap()
        XCTAssertTrue(app.staticTexts["history-empty"].waitForExistence(timeout: 3))
    }

    func testDemoOutcomesAppendAndEmptySamplesCanBeReloaded() {
        launch(demo: true)
        for (offset, outcome) in ["won", "mistakes", "timedOut"].enumerated() {
            chooseDemo("demo-\(outcome)")
            XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 3))
            capture("history-result-\(outcome)")
            if !app.buttons["finish"].isHittable { app.swipeUp() }
            app.buttons["finish"].tap()
            app.buttons["history"].tap()
            assertCount(7 + offset)
            app.buttons["history-close"].tap()
        }
        chooseDemo("demo-empty")
        XCTAssertTrue(app.staticTexts["history-empty"].waitForExistence(timeout: 3))
        app.buttons["history-close"].tap()
        chooseDemo("demo-samples")
        assertCount(6)
    }

    func testSigningOutDiscardsThePreviousSessionHistory() {
        launch(signedOut: true)
        app.buttons["difficulty-easy"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        app.buttons["digit-5"].tap()
        app.buttons["cell-1"].tap(); app.buttons["digit-3"].tap()
        app.buttons["cell-2"].tap(); app.buttons["digit-4"].tap()
        XCTAssertTrue(app.buttons["finish"].waitForExistence(timeout: 3))
        if !app.buttons["finish"].isHittable { app.swipeUp() }
        app.buttons["finish"].tap()
        app.buttons["history"].tap()
        assertCount(1)
        app.buttons["history-close"].tap()
        app.buttons["account"].tap()
        app.buttons["sign-out"].tap()
        app.alerts.buttons["Sign out"].tap()
        XCTAssertTrue(app.buttons["sign-in-google"].waitForExistence(timeout: 3))
        app.buttons["sign-in-google"].tap()
        XCTAssertTrue(app.buttons["history"].waitForExistence(timeout: 3))
        app.buttons["history"].tap()
        XCTAssertTrue(app.staticTexts["history-empty"].waitForExistence(timeout: 3))
    }
}
