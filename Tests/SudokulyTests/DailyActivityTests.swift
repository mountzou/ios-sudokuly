import XCTest
#if canImport(SudokulyCore)
@testable import SudokulyCore
#else
@testable import Sudokuly
#endif

final class DailyActivityTests: XCTestCase {
    func testPickerGesturesAdvanceOnlyOneDayWithoutInertia() {
        XCTAssertEqual(DailyActivity.pickerStep(translation: 160, predicted: 900, spacing: 50), -1)
        XCTAssertEqual(DailyActivity.pickerStep(translation: -160, predicted: -900, spacing: 50), 1)
        XCTAssertEqual(DailyActivity.pickerStep(translation: 5, predicted: 10, spacing: 50), 0)
    }

    func testShortFlickUsesDirectionAndInvalidGeometryDoesNotMove() {
        XCTAssertEqual(DailyActivity.pickerStep(translation: 10, predicted: 45, spacing: 50), -1)
        XCTAssertEqual(DailyActivity.pickerStep(translation: -10, predicted: -45, spacing: 50), 1)
        XCTAssertEqual(DailyActivity.pickerStep(translation: 50, predicted: 60, spacing: 0), 0)
    }

    private func calendar(_ zone: String = "Europe/Athens", firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func record(_ date: Date, outcome: GameOutcome = .won, owner: String = "player") -> GameRecord {
        GameRecord(ownerID: owner, finishedAt: date, difficulty: .easy, outcome: outcome,
                   duration: outcome == .timedOut ? 900 : 42, mistakes: outcome == .mistakes ? 3 : 0)
    }

    func testRegistrationBoundsIncludeTheWholeLocalSignupDay() {
        let registeredAt = date("2026-10-24T22:30:00Z"), now = date("2026-10-26T12:00:00Z")
        let athens = calendar(), utc = calendar("UTC")
        let local = DailyActivity.dateBounds(registeredAt: registeredAt, today: now, calendar: athens)
        let universal = DailyActivity.dateBounds(registeredAt: registeredAt, today: now, calendar: utc)
        XCTAssertEqual(athens.component(.day, from: local.lowerBound), 25)
        XCTAssertEqual(utc.component(.day, from: universal.lowerBound), 24)
        XCTAssertEqual(local.lowerBound, athens.startOfDay(for: registeredAt))
        XCTAssertEqual(local.upperBound, athens.startOfDay(for: now))
        XCTAssertTrue(local.contains(local.lowerBound))
        XCTAssertFalse(local.contains(athens.date(byAdding: .day, value: -1, to: local.lowerBound)!))
    }

    func testNewMissingAndFutureRegistrationDatesOnlyPermitToday() {
        let cal = calendar(), now = date("2026-10-25T12:00:00Z")
        let today = cal.startOfDay(for: now)
        let metadata: [Date?] = [now, nil, date("2026-10-27T12:00:00Z"), Date(timeIntervalSince1970: .infinity)]
        for registeredAt in metadata {
            XCTAssertEqual(DailyActivity.dateBounds(registeredAt: registeredAt, today: now, calendar: cal), today...today)
        }
    }

    func testActivityQueriesStopAtRegistrationAndTheEndOfToday() throws {
        let cal = calendar(), now = date("2026-10-25T12:00:00Z")
        let registeredAt = date("2026-10-24T12:00:00Z")
        let bounds = DailyActivity.dateBounds(registeredAt: registeredAt, today: now, calendar: cal)
        let interval = try XCTUnwrap(DailyActivity.activityInterval(around: now, bounds: bounds, calendar: cal))
        XCTAssertEqual(interval.start, bounds.lowerBound)
        XCTAssertEqual(interval.end, cal.date(byAdding: .day, value: 1, to: bounds.upperBound))
    }

    func testOlderActivitySelectionsRetainOnlyAvailablePrefetchDays() throws {
        let cal = calendar("UTC"), now = date("2026-10-25T12:00:00Z")
        let bounds = DailyActivity.dateBounds(registeredAt: date("2026-09-12T17:00:00Z"), today: now, calendar: cal)
        let interval = try XCTUnwrap(DailyActivity.activityInterval(around: date("2026-09-15T12:00:00Z"),
                                                                 bounds: bounds, calendar: cal))
        XCTAssertEqual(interval.start, date("2026-09-12T00:00:00Z"))
        XCTAssertEqual(interval.end, date("2026-09-28T00:00:00Z"))
        XCTAssertNil(DailyActivity.activityInterval(around: date("2026-01-01T00:00:00Z"), bounds: bounds, calendar: cal),
                     "A stale selection during metadata refresh must not create a reversed DateInterval")
    }

    func testRegistrationDayQueriesRespectDaylightSavingAndTimezoneChanges() throws {
        let registeredAt = date("2026-10-24T22:30:00Z"), now = date("2026-10-25T12:00:00Z")
        let athens = calendar(), losAngeles = calendar("America/Los_Angeles")
        let bounds = DailyActivity.dateBounds(registeredAt: registeredAt, today: now, calendar: athens)
        let interval = try XCTUnwrap(DailyActivity.activityInterval(around: now, bounds: bounds, calendar: athens))
        XCTAssertEqual(interval.start, date("2026-10-24T21:00:00Z"))
        XCTAssertEqual(interval.end, date("2026-10-25T22:00:00Z"))
        XCTAssertEqual(interval.duration, 25 * 3600)
        let shifted = DailyActivity.dateBounds(registeredAt: registeredAt, today: now, calendar: losAngeles)
        XCTAssertEqual(losAngeles.component(.day, from: shifted.lowerBound), 24)
        XCTAssertEqual(shifted.lowerBound, losAngeles.startOfDay(for: registeredAt))
    }

    func testOnlyWinsBelongingToTheUserMarkADayAndMultipleWinsMakeOneCheck() {
        let cal = calendar(), day = date("2026-10-10T12:00:00Z")
        let next = cal.date(byAdding: .day, value: 1, to: day)!
        let records = [record(day), record(day.addingTimeInterval(60)), record(next, outcome: .mistakes),
                       record(next, outcome: .timedOut), record(next, owner: "another-player")]
        XCTAssertEqual(DailyActivity.solvedDays(in: records, ownerID: "player", calendar: cal), [cal.startOfDay(for: day)])
        XCTAssertTrue(DailyActivity.solvedDays(in: [], ownerID: "player", calendar: cal).isEmpty)
    }

    func testCompletionIsAssignedToTheDevicesLocalDayAroundMidnight() {
        let instant = date("2026-10-10T21:30:00Z")
        let athens = calendar(), utc = calendar("UTC")
        let local = DailyActivity.solvedDays(in: [record(instant)], ownerID: "player", calendar: athens).first!
        let universal = DailyActivity.solvedDays(in: [record(instant)], ownerID: "player", calendar: utc).first!
        XCTAssertEqual(athens.component(.day, from: local), 11)
        XCTAssertEqual(utc.component(.day, from: universal), 10)
    }

    func testSpringAndAutumnWeeksUseCalendarDaysAcrossDST() throws {
        let cal = calendar()
        for (instant, expectedHours) in [("2026-03-29T12:00:00Z", 167), ("2026-10-25T12:00:00Z", 169)] {
            let days = DailyActivity.week(containing: date(instant), calendar: cal)
            let interval = try XCTUnwrap(DailyActivity.interval(for: days, calendar: cal))
            XCTAssertEqual(days.count, 7)
            XCTAssertEqual(Set(days).count, 7)
            XCTAssertTrue(days.allSatisfy { cal.component(.hour, from: $0) == 0 })
            XCTAssertEqual(interval.duration, Double(expectedHours) * 3600)
        }
    }

    func testWeekRespectsFirstWeekdayAndCrossesYearBoundary() throws {
        let cal = calendar("UTC", firstWeekday: 1)
        let days = DailyActivity.week(containing: date("2027-01-01T12:00:00Z"), calendar: cal)
        XCTAssertEqual(cal.component(.weekday, from: days[0]), 1)
        XCTAssertEqual(cal.component(.year, from: days[0]), 2026)
        XCTAssertEqual(cal.component(.year, from: days[6]), 2027)
        XCTAssertEqual(cal.component(.day, from: days[6]), 2)
        XCTAssertEqual(try XCTUnwrap(DailyActivity.interval(for: days, calendar: cal)).end, date("2027-01-03T00:00:00Z"))
    }
}
