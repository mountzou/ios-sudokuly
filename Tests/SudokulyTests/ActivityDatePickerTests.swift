import XCTest
#if canImport(SudokulyCore)
@testable import SudokulyCore
#else
@testable import Sudokuly
#endif

final class ActivityDatePickerTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func day(_ number: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: number))!
    }
    private var bounds: ClosedRange<Date> { day(1)...day(11) }
    private func drag(_ picker: inout ActivityDatePicker, x: Double, y: Double = 0) {
        picker.drag(x: x, y: y, spacing: 50, calendar: calendar, bounds: bounds)
    }
    private func end(_ picker: inout ActivityDatePicker, x: Double, predicted: Double? = nil) {
        picker.endDrag(x: x, predicted: predicted ?? x, spacing: 50, calendar: calendar, bounds: bounds)
    }

    func testOctoberSevenToSixCommitsOnFirstSwipeBeforeAnyAnimation() {
        var picker = ActivityDatePicker(day: day(7))
        drag(&picker, x: 38)
        XCTAssertEqual(picker.day, day(7), "Dragging must not commit a date or its activity request")
        end(&picker, x: 38)
        XCTAssertEqual(picker.day, day(6))
        XCTAssertEqual(picker.offset, -12, "Rebasing preserves the position at lift-off")
        picker.settle()
        XCTAssertEqual(picker.day, day(6))
        XCTAssertEqual(picker.offset, 0)
    }

    func testNextSwipeCanStartBeforePreviousSnapFinishes() {
        var picker = ActivityDatePicker(day: day(7))
        drag(&picker, x: 35); end(&picker, x: 35)
        drag(&picker, x: 40); end(&picker, x: 40)
        XCTAssertEqual(picker.day, day(5))
        picker.settle()
        drag(&picker, x: -80); end(&picker, x: -80)
        XCTAssertEqual(picker.day, day(6))
    }

    func testNativePanWithZeroInitialTranslationStillMovesOnItsFirstAttempt() {
        var picker = ActivityDatePicker(day: day(7))
        picker.beginHorizontalDrag()
        drag(&picker, x: 0, y: 0)
        drag(&picker, x: 80)
        end(&picker, x: 80, predicted: 400)
        XCTAssertEqual(picker.day, day(6))
        XCTAssertFalse(picker.isDragging)
    }

    func testBackToTodayCannotBeOverwrittenByAnOldSnapOrCancelledGesture() {
        var picker = ActivityDatePicker(day: day(7))
        drag(&picker, x: 35); end(&picker, x: 35)
        picker.center(day(11), bounds: bounds)
        picker.settle()
        end(&picker, x: 35)
        XCTAssertEqual(picker.day, day(11))
        XCTAssertEqual(picker.offset, 0)
    }

    func testHorizontalGestureStaysHorizontalWhenFingerLiftsDiagonally() {
        var picker = ActivityDatePicker(day: day(7))
        drag(&picker, x: 15, y: 3)
        drag(&picker, x: 40, y: 55)
        end(&picker, x: 40)
        XCTAssertEqual(picker.day, day(6))
    }

    func testVerticalScrollAndCancelledDragDoNotChangeTheDate() {
        var picker = ActivityDatePicker(day: day(7))
        drag(&picker, x: 3, y: 15)
        drag(&picker, x: 80, y: 50)
        end(&picker, x: 80)
        XCTAssertEqual(picker.day, day(7))
        drag(&picker, x: 45)
        picker.cancelDrag()
        end(&picker, x: 45)
        XCTAssertEqual(picker.day, day(7))
        XCTAssertEqual(picker.offset, 0)
        XCTAssertFalse(picker.isDragging)
    }

    func testBoundsAndLongFastGesturesNeverSkipDays() {
        var picker = ActivityDatePicker(day: day(11))
        drag(&picker, x: -400); end(&picker, x: -400, predicted: -900)
        XCTAssertEqual(picker.day, day(11))
        drag(&picker, x: 400); end(&picker, x: 400, predicted: 900)
        XCTAssertEqual(picker.day, day(10))
        picker.center(day(1), bounds: bounds)
        drag(&picker, x: 400); end(&picker, x: 400)
        XCTAssertEqual(picker.day, day(1))
    }

    func testLiftOffVelocityCannotReverseADragOrTurnAJitterIntoASwipe() {
        XCTAssertEqual(DailyActivity.pickerStep(translation: 20, predicted: -70, spacing: 50), 0)
        XCTAssertEqual(DailyActivity.pickerStep(translation: 40, predicted: -70, spacing: 50), -1)
        XCTAssertEqual(DailyActivity.pickerStep(translation: 3, predicted: 70, spacing: 50), 0)
    }
}
