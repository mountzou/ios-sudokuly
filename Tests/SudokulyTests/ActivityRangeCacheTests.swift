import XCTest
#if canImport(SudokulyCore)
@testable import SudokulyCore
#else
@testable import Sudokuly
#endif

final class ActivityRangeCacheTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func range(_ start: Double, _ end: Double) -> DateInterval {
        DateInterval(start: now.addingTimeInterval(start), end: now.addingTimeInterval(end))
    }
    private func win(_ offset: Double) -> GameRecord {
        GameRecord(ownerID: "player", finishedAt: now.addingTimeInterval(offset), difficulty: .easy,
                   outcome: .won, duration: 42, mistakes: 0)
    }

    func testDisjointEmptyRangesOnlyRequestTheGapAndUseHalfOpenBoundaries() {
        var cache = ActivityRangeCache()
        cache.insert([], interval: range(0, 10), isFromCache: false, now: now)
        cache.insert([], interval: range(20, 30), isFromCache: false, now: now)
        XCTAssertEqual(cache.lookup(range(0, 30), now: now).missing, [range(10, 20)])
        XCTAssertEqual(cache.lookup(range(30, 40), now: now).missing, [range(30, 40)])
        cache.insert([], interval: range(10, 20), isFromCache: false, now: now)
        XCTAssertTrue(cache.lookup(range(0, 30), now: now).missing.isEmpty)
    }

    func testRefreshingAnEmptyMiddleRangePreservesNeighborsAndRemovesOldChecks() {
        var cache = ActivityRangeCache()
        let before = win(9), atStart = win(10), inside = win(15), atEnd = win(20)
        cache.insert([before, atStart, inside, atEnd], interval: range(0, 30), isFromCache: false, now: now)
        cache.insert([], interval: range(10, 20), isFromCache: false, now: now)
        let result = cache.lookup(range(0, 30), now: now)
        XCTAssertEqual(Set(result.records), [before, atEnd])
        XCTAssertTrue(result.missing.isEmpty)
    }

    func testEvictedRangesBecomeUnknownAndRefreshInvalidationKeepsKnownChecks() {
        var cache = ActivityRangeCache()
        for index in 0..<40 {
            let offset = Double(index * 10)
            cache.insert([win(offset)], interval: range(offset, offset + 10), isFromCache: false, now: now)
        }
        XCTAssertEqual(cache.lookup(range(0, 10), now: now).missing, [range(0, 10)])
        let last = range(390, 400)
        XCTAssertTrue(cache.lookup(last, now: now).missing.isEmpty)
        cache.invalidate()
        XCTAssertEqual(cache.lookup(last, now: now).missing, [last])
        XCTAssertEqual(cache.lookup(last, now: now).records.count, 1)
    }
}
