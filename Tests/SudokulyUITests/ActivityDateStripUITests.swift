import XCTest

@MainActor
final class ActivityDateStripUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--game-testing", "--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["activity-today"].waitForExistence(timeout: 5), app.debugDescription)
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }

    private func assertCenteredSelection(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let selected = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'activity-' AND isSelected == true"))
        XCTAssertEqual(selected.count, 1, file: file, line: line)
        let day = selected.element(boundBy: 0)
        let strip = app.otherElements["activity-picker"]
        XCTAssertEqual(strip.frame.width, min(app.frame.width, 480) - 48, accuracy: 1.5,
                       "The accessible swipe area must match the visible strip", file: file, line: line)
        XCTAssertTrue(day.isHittable, file: file, line: line)
        XCTAssertEqual(day.frame.midX, strip.frame.midX, accuracy: 1.5, file: file, line: line)
        return day
    }

    func testTodayIsSelectedAndEnglishDatesScrollWithoutArrows() {
        let app = launch(), today = app.buttons["activity-today"]
        XCTAssertTrue(today.isSelected)
        _ = assertCenteredSelection(app)
        XCTAssertEqual(today.value as? String, "No solved games")
        XCTAssertFalse(app.buttons["activity-previous-week"].exists)
        XCTAssertFalse(app.buttons["activity-next-week"].exists)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US"); formatter.dateFormat = "MMMM yyyy"
        XCTAssertEqual(app.staticTexts["activity-month"].label, formatter.string(from: Date()))
        XCTAssertTrue(today.label.hasPrefix("Today, "))
        XCTAssertTrue(today.label.range(of: "Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday", options: .regularExpression) != nil)
        XCTAssertFalse(app.staticTexts["One grid.\nA fresh start."].exists)
        capture(app, "home-date-strip-empty")
        let strip = app.otherElements["activity-picker"]
        XCTAssertTrue(strip.exists)
        strip.swipeRight()
        XCTAssertTrue(app.buttons["activity-reset-today"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["activity-reset-today"].label, "Back to Today")
        XCTAssertFalse(today.isSelected)
        let previous = assertCenteredSelection(app)
        XCTAssertNotEqual(previous.identifier, "activity-today")
        capture(app, "home-date-picker-selected-by-swipe")
        XCTAssertFalse(app.staticTexts["Loading activity…"].exists)
        app.buttons["activity-reset-today"].tap()
        XCTAssertTrue(today.waitForExistence(timeout: 3))
        XCTAssertTrue(today.isHittable)
        XCTAssertTrue(today.isSelected)
        _ = assertCenteredSelection(app)
    }

    func testSuccessiveSwipesSelectEveryNewCenterAndReturnWithoutTappingADay() {
        let app = launch(), strip = app.otherElements["activity-picker"]
        let today = app.buttons["activity-today"]
        for offset in 1...3 {
            strip.swipeRight()
            let selected = assertCenteredSelection(app)
            let expected = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US"); formatter.dateFormat = "MMMM d"
            XCTAssertTrue(selected.label.contains(formatter.string(from: expected)), selected.label)
            XCTAssertFalse(today.isSelected)
        }
        for _ in 1...3 { strip.swipeLeft(); _ = assertCenteredSelection(app) }
        XCTAssertTrue(today.isSelected)
        strip.swipeLeft()
        XCTAssertTrue(today.isSelected, "Future dates cannot become the selection")
        _ = assertCenteredSelection(app)
        capture(app, "home-date-picker-returned-today")
    }

    func testTappingANeighborMovesItToTheFixedCenter() {
        let app = launch(), strip = app.otherElements["activity-picker"]
        let center = assertCenteredSelection(app).frame
        strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: -(center.width + 4), dy: 0)).tap()
        let selected = assertCenteredSelection(app)
        XCTAssertNotEqual(selected.identifier, "activity-today")
    }

    func testRepeatedShortDragsFromTheSelectedDayDoNotBounceBackOnFirstAttempt() {
        let app = launch(), strip = app.otherElements["activity-picker"]
        for offset in 1...8 {
            let selected = assertCenteredSelection(app)
            let start = selected.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            // Drag from the number itself, with a small diagonal component, rather than the strip edge.
            let end = start.withOffset(CGVector(dx: selected.frame.width * 0.9, dy: offset.isMultiple(of: 2) ? 10 : -8))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
            let centered = assertCenteredSelection(app)
            let expected = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US"); formatter.dateFormat = "MMMM d"
            XCTAssertTrue(centered.label.contains(formatter.string(from: expected)), "First attempt failed: \(centered.label)")
        }
        capture(app, "date-ux-after-eight-short-drags")
        app.buttons["activity-reset-today"].tap()
        XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
        strip.swipeRight(velocity: .fast)
        strip.swipeLeft(velocity: .fast)
        XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
        capture(app, "date-ux-back-to-today")
    }

    func testVerticalDragOverTheStripScrollsHomeWithoutChangingTheDate() {
        let app = launch(), strip = app.otherElements["activity-picker"]
        let todayLabel = assertCenteredSelection(app).label
        let originalY = strip.frame.minY
        let viewport = app.scrollViews.firstMatch.frame
        let contentBottom = app.staticTexts["Just you and the puzzle."].frame.maxY + 12
        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 4, dy: -100)),
                    withVelocity: .slow, thenHoldForDuration: 0)
        XCTAssertEqual(app.buttons["activity-today"].label, todayLabel)
        XCTAssertTrue(app.buttons["activity-today"].isSelected)
        if contentBottom > viewport.maxY + 1 {
            XCTAssertLessThan(strip.frame.minY, originalY,
                              "The date strip must not trap vertical home scrolling; content bottom \(contentBottom), viewport \(viewport)")
        }
    }

    func testWinningGameMarksTodayAsSoonAsReturningHome() {
        let app = launch()
        app.buttons["difficulty-easy"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        app.buttons["digit-5"].tap()
        app.buttons["cell-1"].tap(); app.buttons["digit-3"].tap()
        app.buttons["cell-2"].tap(); app.buttons["digit-4"].tap()
        XCTAssertTrue(app.buttons["finish"].waitForExistence(timeout: 3))
        app.buttons["finish"].tap()
        let today = app.buttons["activity-today"]
        XCTAssertTrue(today.waitForExistence(timeout: 3))
        XCTAssertTrue(today.isSelected)
        XCTAssertEqual(today.value as? String, "At least one solved game")
        capture(app, "home-date-strip-solved")
    }

    func testThreeMistakesDoNotMarkTodayAsSolved() {
        let app = launch()
        app.buttons["difficulty-easy"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        for digit in [3, 4, 3] { app.buttons["digit-\(digit)"].tap() }
        XCTAssertTrue(app.buttons["finish"].waitForExistence(timeout: 3))
        app.buttons["finish"].tap()
        XCTAssertTrue(app.buttons["activity-today"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["activity-today"].value as? String, "No solved games")
    }
}
