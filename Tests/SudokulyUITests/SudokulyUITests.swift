import XCTest

@MainActor
final class SudokulyUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(scenario: String = "play", fixture: Bool = true) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = fixture ? ["--game-testing", "--ui-testing", "--scenario=\(scenario)"] : ["--game-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["difficulty-easy"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func start(_ difficulty: String = "easy") {
        app.buttons["difficulty-\(difficulty)"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
    }

    private func finishAndCheckHome() {
        let finish = app.buttons["finish"]
        if !finish.isHittable { app.swipeUp() }
        finish.tap()
        XCTAssertTrue(app.buttons["difficulty-easy"].waitForExistence(timeout: 5))
        app.buttons["history"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["history-count"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.descendants(matching: .any)["history-count"].label, "1 game played")
        app.buttons["history-close"].tap()
    }

    func testWinAndReturnHome() {
        launch(scenario: "win"); start()
        app.buttons["cell-0"].tap(); app.buttons["digit-5"].tap()
        app.buttons["cell-1"].tap(); app.buttons["digit-3"].tap()
        app.buttons["cell-2"].tap(); app.buttons["digit-4"].tap()
        XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["result-title"].label, "Beautifully\nsolved.")
        capture("result-won")
        finishAndCheckHome()
        start("hard")
        XCTAssertTrue(app.buttons["cell-0"].exists)
    }

    func testThreeMistakesAndReturnHome() {
        launch(scenario: "mistakes"); start("medium")
        app.buttons["cell-0"].tap()
        app.buttons["digit-3"].tap(); app.buttons["digit-4"].tap(); app.buttons["digit-3"].tap()
        XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["result-title"].label, "A pause.\nA fresh start.")
        capture("result-mistakes")
        finishAndCheckHome()
    }

    func testWrongEntriesOnlyCountNewMistakesAndCanBeCorrected() {
        launch(); start()
        let cell = app.buttons["cell-0"]
        let mistakes = app.descendants(matching: .any)["mistakes"]
        cell.tap()
        app.buttons["digit-3"].tap()
        XCTAssertEqual(cell.value as? String, "3, incorrect")
        XCTAssertEqual(mistakes.value as? String, "1 of 3")
        capture("wrong-entry-feedback")
        app.buttons["digit-3"].tap()
        XCTAssertEqual(mistakes.value as? String, "1 of 3")
        app.buttons["digit-4"].tap()
        XCTAssertEqual(cell.value as? String, "4, incorrect")
        XCTAssertEqual(mistakes.value as? String, "2 of 3")
        app.buttons["digit-5"].tap()
        XCTAssertEqual(cell.value as? String, "5, correct")
        XCTAssertEqual(mistakes.value as? String, "2 of 3")
        XCTAssertFalse(app.staticTexts["result-title"].exists)
    }

    func testTimeoutAndReturnHome() {
        launch(scenario: "timeout"); start("expert")
        XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["result-title"].label, "Good things\ntake practice.")
        capture("result-timeout")
        finishAndCheckHome()
    }

    func testNotesToggleErasePauseAndAbandon() {
        launch(); start()
        XCTAssertFalse(app.buttons["undo"].exists)
        app.buttons["notes"].tap()
        app.buttons["digit-4"].tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "Notes: 4")
        app.buttons["digit-3"].tap()
        app.buttons["digit-4"].tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "Notes: 3")
        app.buttons["erase"].tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "Empty")
        app.buttons["digit-4"].tap()
        app.buttons["notes"].tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "Notes: 4")
        app.buttons["pause"].tap()
        XCTAssertTrue(app.staticTexts["pause-title"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Back to home"].exists)
        XCTAssertFalse(app.buttons["confirm-leave"].exists)
        capture("pause")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "pause-accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 2))
        app.buttons["resume"].tap()
        app.buttons["leave-game"].tap()
        XCTAssertTrue(app.staticTexts["leave-confirmation-title"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["pause-title"].exists)
        XCTAssertFalse(app.buttons["resume"].exists)
        XCTAssertEqual(app.alerts.count, 0)
        capture("leave-confirmation")
        app.buttons["keep-playing"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "Notes: 4")
        app.buttons["digit-5"].tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "5, correct")
        app.buttons["leave-game"].tap()
        app.buttons["confirm-leave"].tap()
        let finalConfirmation = app.alerts["Leave without saving?"]
        XCTAssertTrue(finalConfirmation.waitForExistence(timeout: 2))
        XCTAssertTrue(finalConfirmation.staticTexts["All progress in this puzzle will be lost. You won’t be able to resume it."].exists)
        capture("leave-final-confirmation")
        finalConfirmation.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["leave-confirmation-title"].exists)
        XCTAssertFalse(app.buttons["difficulty-easy"].exists)
        app.buttons["keep-playing"].tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "5, correct")
        app.buttons["leave-game"].tap()
        app.buttons["confirm-leave"].tap()
        XCTAssertTrue(finalConfirmation.waitForExistence(timeout: 2))
        finalConfirmation.buttons["Leave game"].tap()
        XCTAssertTrue(app.buttons["difficulty-easy"].waitForExistence(timeout: 3))
        app.buttons["history"].tap()
        XCTAssertTrue(app.staticTexts["history-empty"].waitForExistence(timeout: 3))
    }

    func testHintsFillSelectedCellAndStopAfterThreeUses() {
        launch(); start()
        let hint = app.buttons["hint"]
        XCTAssertTrue(hint.isHittable)
        XCTAssertEqual(hint.value as? String, "3 remaining")
        XCTAssertFalse(app.buttons["undo"].exists)
        capture("game-hint-available")

        app.buttons["cell-3"].tap()
        XCTAssertFalse(hint.isEnabled)
        XCTAssertEqual(hint.value as? String, "3 remaining")
        app.buttons["cell-0"].tap()
        app.buttons["notes"].tap()
        app.buttons["digit-4"].tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "Notes: 4")
        hint.tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "5, correct")
        XCTAssertEqual(app.buttons["notes"].value as? String, "On")
        XCTAssertEqual(hint.value as? String, "2 remaining")
        XCTAssertFalse(hint.isEnabled)
        capture("game-hint-used-once")

        app.buttons["cell-1"].tap()
        XCTAssertTrue(hint.isEnabled)
        hint.tap()
        XCTAssertEqual(app.buttons["cell-1"].value as? String, "3, correct")
        XCTAssertEqual(hint.value as? String, "1 remaining")
        app.buttons["cell-0"].tap()
        app.buttons["erase"].tap()
        hint.tap()
        XCTAssertEqual(app.buttons["cell-0"].value as? String, "5, correct")
        XCTAssertEqual(hint.value as? String, "0 remaining")
        app.buttons["cell-2"].tap()
        XCTAssertEqual(app.buttons["cell-2"].value as? String, "Empty")
        XCTAssertFalse(hint.isEnabled)
        XCTAssertFalse(app.staticTexts["result-title"].exists)
        capture("game-hints-exhausted")
    }

    func testHintCanFinishGameAndResetsForNextGame() {
        launch(); start()
        app.buttons["cell-0"].tap(); app.buttons["digit-5"].tap()
        app.buttons["cell-1"].tap(); app.buttons["digit-3"].tap()
        app.buttons["cell-2"].tap(); app.buttons["hint"].tap()
        XCTAssertTrue(app.staticTexts["result-title"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["result-title"].label, "Beautifully\nsolved.")
        finishAndCheckHome()
        start("hard")
        XCTAssertEqual(app.buttons["hint"].value as? String, "3 remaining")
        XCTAssertTrue(app.buttons["hint"].isEnabled)
    }

    func testRealGeneratedGameStartsAndGivensAreReadOnly() {
        launch(fixture: false)
        if !app.buttons["difficulty-expert"].isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["difficulty-expert"].isHittable)
        capture("home")
        start("hard")
        XCTAssertTrue(app.buttons["notes"].isHittable)
        XCTAssertTrue(app.buttons["hint"].isHittable)
        capture("game")
        let given = (0..<81).map { app.buttons["cell-\($0)"] }.first { ($0.value as? String)?.contains("given") == true }!
        let value = given.value as? String
        given.tap()
        XCTAssertFalse(app.buttons["digit-1"].isEnabled)
        XCTAssertFalse(app.buttons["hint"].isEnabled)
        XCTAssertEqual(given.value as? String, value)
    }
}
