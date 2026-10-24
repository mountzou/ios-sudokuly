import XCTest

@MainActor
final class MVPScenarioUITests: XCTestCase {
    private var app: XCUIApplication!
    private let levels = ["easy", "medium", "hard", "expert"]

    private func launch(timeout: Bool = false) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--game-testing", "--ui-testing"] + (timeout ? ["--scenario=timeout"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["difficulty-easy"].waitForExistence(timeout: 5))
    }
    private func play(_ level: String, win: Bool) {
        app.buttons["difficulty-\(level)"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        if win {
            for (cell, digit) in [(0, 5), (1, 3), (2, 4)] {
                app.buttons["cell-\(cell)"].tap(); app.buttons["digit-\(digit)"].tap()
            }
        } else {
            app.buttons["cell-0"].tap()
            for digit in [3, 4, 3] { app.buttons["digit-\(digit)"].tap() }
        }
        XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["result-title"].label, win ? "Beautifully\nsolved." : "A pause.\nA fresh start.")
        XCTAssertTrue(app.staticTexts[level.capitalized].exists)
    }
    private func finishAndCheckHistory(_ count: Int) {
        if !app.buttons["finish"].isHittable { app.swipeUp() }
        app.buttons["finish"].tap()
        app.buttons["history"].tap()
        let value = app.descendants(matching: .any)["history-count"]
        XCTAssertTrue(value.waitForExistence(timeout: 3))
        XCTAssertEqual(value.label, "\(count) \(count == 1 ? "game" : "games") played")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-game-'")).firstMatch
        XCTAssertTrue(row.exists)
        row.tap()
        XCTAssertTrue(app.staticTexts["history-detail-title"].waitForExistence(timeout: 3))
        app.buttons["history-detail-back"].tap()
        app.buttons["history-close"].tap()
    }
    private func capture(_ name: String) {
        // Element existence can precede the result screen's fade-in.
        Thread.sleep(forTimeInterval: 0.5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testWinsAtEveryLevelAndRepeatedHistoryNavigation() {
        launch()
        for (index, level) in levels.enumerated() { play(level, win: true); finishAndCheckHistory(index + 1) }
    }
    func testThreeMistakesAtEveryLevelAndRepeatedHistoryNavigation() {
        launch()
        for (index, level) in levels.enumerated() { play(level, win: false); finishAndCheckHistory(index + 1) }
    }
    func testFastTimeoutsAtEveryLevelKeepValidSavedDurations() {
        launch(timeout: true)
        for (index, level) in levels.enumerated() {
            app.buttons["difficulty-\(level)"].tap()
            XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))
            XCTAssertEqual(app.staticTexts["result-title"].label, "Good things\ntake practice.")
            XCTAssertTrue(app.staticTexts[["15:00", "20:00", "30:00", "40:00"][index]].exists)
            capture("mvp-timeout-\(level)")
            finishAndCheckHistory(index + 1)
        }
    }
    func testTwoWinsAndOneLossHaveThreeAccurateRecaps() {
        launch()
        for (index, scenario) in [("easy", true), ("hard", true), ("expert", false)].enumerated() {
            play(scenario.0, win: scenario.1); finishAndCheckHistory(index + 1)
        }
        app.buttons["history"].tap()
        capture("mvp-two-wins-one-loss")
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history-game-'")).allElementsBoundByIndex
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows[0].label.contains("Expert, Three mistakes"))
        XCTAssertTrue(rows[1].label.contains("Hard, Solved"))
        XCTAssertTrue(rows[2].label.contains("Easy, Solved"))
        for (index, title) in ["A pause.\nA fresh start.", "Beautifully\nsolved.", "Beautifully\nsolved."].enumerated() {
            rows[index].tap()
            XCTAssertTrue(app.staticTexts["history-detail-title"].waitForExistence(timeout: 3))
            XCTAssertEqual(app.staticTexts["history-detail-title"].label, title)
            app.buttons["history-detail-back"].tap()
        }
    }
}
