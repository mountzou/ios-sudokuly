import XCTest
#if canImport(SudokulyCore)
@testable import SudokulyCore
#else
@testable import Sudokuly
#endif

final class YearlyActivityTests: XCTestCase {
    private func calendar(_ zone: String = "Europe/Athens", firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.firstWeekday = firstWeekday
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testYearContainsExactly365UniqueLocalDaysAcrossLeapDayAndDST() {
        let cal = calendar()
        for now in [date("2024-03-31T12:00:00Z"), date("2026-10-25T12:00:00Z")] {
            let year = YearlyActivity(today: now, registeredAt: .distantPast, calendar: cal)
            XCTAssertEqual(year.days.count, 365)
            XCTAssertEqual(Set(year.days).count, 365)
            XCTAssertEqual(year.days.last, cal.startOfDay(for: now))
            XCTAssertEqual(cal.dateComponents([.day], from: year.days.first!, to: year.days.last!).day, 364)
            XCTAssertTrue(year.days.allSatisfy { cal.component(.hour, from: $0) == 0 })
        }
    }

    func testWeekColumnsPreserveEveryDayAndRespectFirstWeekday() {
        for weekday in [1, 2, 7] {
            let cal = calendar(firstWeekday: weekday)
            let year = YearlyActivity(today: date("2026-10-25T12:00:00Z"), registeredAt: nil, calendar: cal)
            XCTAssertEqual(year.weeks.count, 53)
            XCTAssertTrue(year.weeks.allSatisfy { $0.count == 7 })
            XCTAssertEqual(year.weeks.flatMap { $0 }.compactMap { $0 }, year.days)
            for week in year.weeks {
                for (row, day) in week.enumerated() {
                    if let day { XCTAssertEqual(cal.component(.weekday, from: day), (weekday - 1 + row) % 7 + 1) }
                }
            }
        }
    }

    func testQueryAndSolvedCountsExcludeDaysBeforeRegistrationAndAfterToday() throws {
        let cal = calendar(), now = date("2026-10-25T12:00:00Z")
        let registeredAt = date("2026-10-24T22:30:00Z")
        let year = YearlyActivity(today: now, registeredAt: registeredAt, calendar: cal)
        let today = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        XCTAssertEqual(year.availableBounds, today...today)
        XCTAssertEqual(year.solvedDays(in: [yesterday, today, tomorrow]), [today])
        let interval = try XCTUnwrap(year.interval)
        XCTAssertEqual(interval.start, today)
        XCTAssertEqual(interval.end, tomorrow)
        XCTAssertEqual(interval.duration, 25 * 3600)
    }

    func testLongTimeAccountQueryStartsAtFirstDisplayedDayAndMissingMetadataOnlyAllowsToday() {
        let cal = calendar(), now = date("2026-10-25T12:00:00Z")
        let year = YearlyActivity(today: now, registeredAt: date("2020-01-01T12:00:00Z"), calendar: cal)
        XCTAssertEqual(year.interval?.start, year.days.first)
        XCTAssertEqual(year.solvedDays(in: Set(year.days)).count, 365)
        for registration in [nil, Optional(date("2027-01-01T12:00:00Z"))] {
            let limited = YearlyActivity(today: now, registeredAt: registration, calendar: cal)
            XCTAssertEqual(limited.solvedDays(in: Set(limited.days)), [cal.startOfDay(for: now)])
        }
    }
}
