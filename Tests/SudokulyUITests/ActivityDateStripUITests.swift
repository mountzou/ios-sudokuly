import XCTest

@MainActor
final class ActivityDateStripUITests: XCTestCase {
    private func launch(registrationDaysAgo: Int? = nil) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--game-testing", "--ui-testing"]
        if let registrationDaysAgo { app.launchArguments.append("--registration-days-ago=\(registrationDaysAgo)") }
        app.launch()
        XCTAssertTrue(app.buttons["activity-today"].waitForExistence(timeout: 5), app.debugDescription)
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }

    private func dateButton(_ app: XCUIApplication, daysFromToday: Int) -> XCUIElement {
        let day = Calendar.current.date(byAdding: .day, value: daysFromToday, to: Date())!
        let suffix = day.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "en_US")))
        return app.buttons["activity-day-\(suffix)"]
    }

    private func monthButton(_ app: XCUIApplication, for date: Date) -> XCUIElement {
        let identifier = String(format: "activity-month-%04d-%02d", Calendar.current.component(.year, from: date),
                                Calendar.current.component(.month, from: date))
        return app.buttons[identifier]
    }

    func testMonthSheetOffersOnlyAccountMonthsAndSelectingOneKeepsTheStripWithinIt() {
        let app = launch(registrationDaysAgo: 40)
        app.buttons["activity-month-picker"].tap()
        XCTAssertTrue(app.staticTexts["Choose month"].waitForExistence(timeout: 3))
        let cal = Calendar.current
        let registeredAt = cal.date(byAdding: .day, value: -40, to: Date())!
        let registrationMonth = cal.dateInterval(of: .month, for: registeredAt)!.start
        let priorMonth = cal.date(byAdding: .month, value: -1, to: registrationMonth)!
        let futureMonth = cal.date(byAdding: .month, value: 1, to: Date())!
        XCTAssertFalse(monthButton(app, for: priorMonth).exists)
        XCTAssertFalse(monthButton(app, for: futureMonth).exists)
        XCTAssertTrue(monthButton(app, for: Date()).isSelected)
        capture(app, "month-sheet-available-months")
        monthButton(app, for: registrationMonth).tap()
        XCTAssertFalse(app.staticTexts["Choose month"].exists)
        let expected = cal.startOfDay(for: registeredAt)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US"); formatter.dateFormat = "MMMM yyyy"
        XCTAssertEqual(app.staticTexts["activity-month"].label, formatter.string(from: expected))
        let first = assertCenteredSelection(app)
        let firstID = first.identifier
        XCTAssertTrue(first.label.contains(expected.formatted(.dateTime.month(.wide).day().locale(Locale(identifier: "en_US")))))
        app.otherElements["activity-picker"].swipeRight()
        XCTAssertEqual(assertCenteredSelection(app).identifier, firstID)
        for button in app.buttons.allElementsBoundByIndex where button.identifier.hasPrefix("activity-day-") {
            XCTAssertTrue(button.label.contains(expected.formatted(.dateTime.month(.wide).locale(Locale(identifier: "en_US")))))
        }
        capture(app, "month-strip-registration-month")
        app.buttons["activity-reset-today"].tap()
        XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
        XCTAssertEqual(app.staticTexts["activity-month"].label, formatter.string(from: Date()))
    }

    func testHistoricalMonthHidesAdjacentMonthsAndCannotSwipeAcrossTheFirstDay() {
        let app = launch()
        let cal = Calendar.current
        let previousMonth = cal.date(byAdding: .month, value: -1, to: cal.dateInterval(of: .month, for: Date())!.start)!
        app.buttons["activity-month-picker"].tap()
        let option = monthButton(app, for: previousMonth)
        XCTAssertTrue(option.waitForExistence(timeout: 3))
        option.tap()
        let first = assertCenteredSelection(app)
        let firstID = first.identifier
        let previousDay = cal.date(byAdding: .day, value: -1, to: previousMonth)!
        let previousSuffix = previousDay.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "en_US")))
        XCTAssertFalse(app.buttons["activity-day-\(previousSuffix)"].exists)
        let strip = app.otherElements["activity-picker"]
        strip.swipeRight(velocity: .fast)
        XCTAssertEqual(assertCenteredSelection(app).identifier, firstID)
        strip.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertEqual(assertCenteredSelection(app).identifier, firstID)
        capture(app, "month-strip-first-day")
        let lastDay = cal.range(of: .day, in: .month, for: previousMonth)!.count
        var selectedNumber = 1
        while selectedNumber < lastDay {
            let step = min(3, lastDay - selectedNumber)
            let selected = assertCenteredSelection(app)
            strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .withOffset(CGVector(dx: CGFloat(step) * (selected.frame.width + 4), dy: 0)).tap()
            selectedNumber += step
        }
        let last = assertCenteredSelection(app)
        let lastID = last.identifier
        let expectedLast = cal.date(byAdding: .day, value: lastDay - 1, to: previousMonth)!
        XCTAssertTrue(last.label.contains(expectedLast.formatted(.dateTime.month(.wide).day().locale(Locale(identifier: "en_US")))))
        let nextMonth = cal.date(byAdding: .month, value: 1, to: previousMonth)!
        let nextSuffix = nextMonth.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "en_US")))
        XCTAssertFalse(app.buttons["activity-day-\(nextSuffix)"].exists)
        strip.swipeLeft(velocity: .fast)
        XCTAssertEqual(assertCenteredSelection(app).identifier, lastID)
        capture(app, "month-strip-last-day")
        app.buttons["activity-month-picker"].tap()
        XCTAssertTrue(monthButton(app, for: previousMonth).isSelected)
        capture(app, "month-sheet-selected-history")
        app.buttons["activity-month-close"].tap()
        XCTAssertEqual(assertCenteredSelection(app).identifier, lastID)
        app.buttons["activity-month-picker"].tap()
        monthButton(app, for: Date()).tap()
        XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
    }

    func testMonthPickerCanSelectAnEarlierYear() {
        let app = launch(registrationDaysAgo: 800)
        let cal = Calendar.current
        let earlierYear = cal.date(byAdding: .year, value: -1, to: Date())!
        app.buttons["activity-month-picker"].tap()
        let option = monthButton(app, for: earlierYear)
        let options = app.scrollViews["activity-month-options"]
        for _ in 0..<5 {
            if option.exists && option.isHittable { break }
            options.swipeUp()
        }
        XCTAssertTrue(option.isHittable)
        capture(app, "month-sheet-earlier-year")
        option.tap()
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US"); formatter.dateFormat = "MMMM yyyy"
        XCTAssertEqual(app.staticTexts["activity-month"].label, formatter.string(from: earlierYear))
        _ = assertCenteredSelection(app)
        app.buttons["activity-reset-today"].tap()
        XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
    }

    func testAccountRegisteredThisMonthHasNoMonthPicker() {
        let app = launch(registrationDaysAgo: Calendar.current.component(.day, from: Date()) - 1)
        XCTAssertTrue(app.staticTexts["activity-month"].exists)
        XCTAssertFalse(app.buttons["activity-month-picker"].exists)
        capture(app, "month-strip-single-month")
    }

    func testRegistrationDayIsTheFirstEnabledDateAndStopsBackwardSwiping() {
        let daysAgo = min(2, Calendar.current.component(.day, from: Date()) - 1)
        let app = launch(registrationDaysAgo: daysAgo), strip = app.otherElements["activity-picker"]
        strip.swipeRight()
        strip.swipeRight()
        let registration = assertCenteredSelection(app)
        let registrationID = registration.identifier
        XCTAssertEqual(registrationID, daysAgo == 0 ? "activity-today" : dateButton(app, daysFromToday: -daysAgo).identifier)
        XCTAssertTrue(registration.isEnabled)
        let older = dateButton(app, daysFromToday: -daysAgo - 1)
        if Calendar.current.component(.day, from: Date()) > daysAgo + 1 {
            XCTAssertTrue(older.exists, "Earlier dates in the same month stay visible")
            XCTAssertFalse(older.isEnabled)
        } else {
            XCTAssertFalse(older.exists, "Dates outside the selected month are hidden")
        }
        for _ in 0..<3 {
            strip.swipeRight(velocity: .fast)
            XCTAssertEqual(assertCenteredSelection(app).identifier, registrationID)
        }
        let center = registration.frame
        strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: -(center.width + 4), dy: 0)).tap()
        XCTAssertEqual(assertCenteredSelection(app).identifier, registrationID,
                       "Tapping an earlier disabled date cannot select it")
        capture(app, "registration-lower-bound")
        strip.swipeLeft()
        let nextID = daysAgo > 1 ? dateButton(app, daysFromToday: -daysAgo + 1).identifier : "activity-today"
        XCTAssertEqual(assertCenteredSelection(app).identifier, nextID)
        if nextID != "activity-today" { app.buttons["activity-reset-today"].tap() }
        XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
    }

    func testNewAccountKeepsEarlierDatesVisibleButOnlyTodayEnabled() {
        let app = launch(registrationDaysAgo: 0), strip = app.otherElements["activity-picker"]
        XCTAssertFalse(app.buttons["activity-month-picker"].exists)
        if Calendar.current.component(.day, from: Date()) > 1 {
            XCTAssertTrue(dateButton(app, daysFromToday: -1).exists)
            XCTAssertFalse(dateButton(app, daysFromToday: -1).isEnabled)
        } else {
            XCTAssertFalse(dateButton(app, daysFromToday: -1).exists)
        }
        let tomorrow = dateButton(app, daysFromToday: 1)
        if tomorrow.exists { XCTAssertFalse(tomorrow.isEnabled) }
        for _ in 0..<2 {
            strip.swipeRight(velocity: .fast)
            XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
            strip.swipeLeft(velocity: .fast)
            XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
        }
        let center = assertCenteredSelection(app).frame
        strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: -(center.width + 4), dy: 0)).tap()
        XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
        capture(app, "registration-today-only")
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
        if Calendar.current.component(.day, from: Date()) == 1 {
            XCTAssertEqual(assertCenteredSelection(app).identifier, "activity-today")
            return
        }
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
        let steps = min(3, Calendar.current.component(.day, from: Date()) - 1)
        for index in 0..<steps {
            let offset = index + 1
            strip.swipeRight()
            let selected = assertCenteredSelection(app)
            let expected = Calendar.current.date(byAdding: .day, value: -offset, to: Date())!
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US"); formatter.dateFormat = "MMMM d"
            XCTAssertTrue(selected.label.contains(formatter.string(from: expected)), selected.label)
            XCTAssertFalse(today.isSelected)
        }
        for _ in 0..<steps { strip.swipeLeft(); _ = assertCenteredSelection(app) }
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
        if Calendar.current.component(.day, from: Date()) > 1 {
            XCTAssertNotEqual(selected.identifier, "activity-today")
        } else {
            XCTAssertEqual(selected.identifier, "activity-today")
        }
    }

    func testRepeatedShortDragsFromTheSelectedDayDoNotBounceBackOnFirstAttempt() {
        let app = launch(), strip = app.otherElements["activity-picker"]
        let steps = min(8, Calendar.current.component(.day, from: Date()) - 1)
        for index in 0..<steps {
            let offset = index + 1
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
        if steps > 0 { app.buttons["activity-reset-today"].tap() }
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
        let finalDifficulty = app.buttons["difficulty-expert"]
        XCTAssertTrue(finalDifficulty.exists)
        let contentBottom = finalDifficulty.frame.maxY + 12
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
