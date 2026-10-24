#if canImport(UIKit)
import XCTest
@testable import Sudokuly

@MainActor
private final class ControlledActivityRepository: GameHistoryRepository, GameActivityRepository {
    var requests: [(DateInterval, @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void)] = []
    var cancellations = 0
    func observe(ownerID: String, receive: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) -> GameHistoryObservation {
        GameHistoryObservation { }
    }
    func save(_ record: GameRecord, completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) { }
    func loadMore(completion: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) { }
    func loadActivity(ownerID: String, interval: DateInterval,
                      receive: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) -> GameHistoryObservation {
        requests.append((interval, receive))
        return GameHistoryObservation { [weak self] in self?.cancellations += 1 }
    }
}

@MainActor
final class GameActivitySyncTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value
    }
    private func game(_ date: Date, owner: String = "player", outcome: GameOutcome = .won) -> GameRecord {
        GameRecord(ownerID: owner, finishedAt: date, difficulty: .easy, outcome: outcome,
                   duration: 42, mistakes: outcome == .mistakes ? 3 : 0)
    }

    private func reply(_ repo: ControlledActivityRepository, _ index: Int, records: [GameRecord] = [], offline: Bool = false) {
        repo.requests[index].1(.success(GameHistorySnapshot(records: records, isFromCache: offline, hasMore: false)))
    }

    func testRepeatedAndInFlightRequestsForTheSameRangeAreDeduplicatedIncludingEmptyHistory() {
        let repo = ControlledActivityRepository(), store = GameHistoryStore(ownerID: "player", repository: repo)
        let interval = DateInterval(start: Date(), duration: 7 * 86400)
        store.loadActivity(interval: interval)
        store.loadActivity(interval: interval)
        XCTAssertEqual(repo.requests.count, 1)
        XCTAssertEqual(repo.cancellations, 0)
        reply(repo, 0)
        for _ in 0..<10 { store.loadActivity(interval: interval) }
        XCTAssertEqual(repo.requests.count, 1, "A successfully loaded empty week is still cached")
        XCTAssertFalse(store.isLoadingActivity)
        XCTAssertNil(store.activityError)
    }

    func testNeighboringWeeksFetchOnlyTheUncoveredDaysAndReturnFromCache() {
        let repo = ControlledActivityRepository(), store = GameHistoryStore(ownerID: "player", repository: repo)
        let start = calendar.startOfDay(for: Date()), week = 7.0 * 86400
        let first = DateInterval(start: start, duration: 3 * week)
        let next = DateInterval(start: start.addingTimeInterval(-week), end: first.end.addingTimeInterval(-week))
        store.loadActivity(interval: first)
        let win = game(start.addingTimeInterval(3600))
        reply(repo, 0, records: [win])
        store.loadActivity(interval: next)
        XCTAssertEqual(repo.requests.count, 2)
        XCTAssertEqual(repo.requests[1].0, DateInterval(start: next.start, end: first.start))
        XCTAssertEqual(store.activityRecords, [win], "Overlapping checks remain visible while the missing week loads")
        reply(repo, 1)
        store.loadActivity(interval: first)
        store.loadActivity(interval: next)
        XCTAssertEqual(repo.requests.count, 2)
        XCTAssertEqual(store.activityRecords, [win])
    }

    func testCacheExpiresAndForegroundRefreshReplacesEmptyAndNonEmptyRanges() {
        var clock = Date()
        let repo = ControlledActivityRepository()
        let store = GameHistoryStore(ownerID: "player", repository: repo, activityNow: { clock })
        let interval = DateInterval(start: clock, duration: 86400), win = game(clock)
        store.loadActivity(interval: interval); reply(repo, 0, records: [win])
        clock = clock.addingTimeInterval(301)
        store.loadActivity(interval: interval)
        XCTAssertEqual(repo.requests.count, 2)
        XCTAssertEqual(store.activityRecords, [win], "Expired checks remain while refreshing")
        reply(repo, 1)
        XCTAssertTrue(store.activityRecords.isEmpty, "Fresh empty results replace stale checks")
        store.invalidateActivityCache()
        store.loadActivity(interval: interval)
        XCTAssertEqual(repo.requests.count, 3)
        reply(repo, 2, records: [win])
        XCTAssertEqual(store.activityRecords, [win])
    }

    func testOfflineEmptySnapshotIsRetriedQuicklyAfterConnectivityReturns() {
        var clock = Date()
        let repo = ControlledActivityRepository()
        let store = GameHistoryStore(ownerID: "player", repository: repo, activityNow: { clock })
        let interval = DateInterval(start: clock, duration: 86400)
        store.loadActivity(interval: interval); reply(repo, 0, offline: true)
        store.loadActivity(interval: interval)
        XCTAssertEqual(repo.requests.count, 1)
        XCTAssertTrue(store.isActivityFromCache)
        clock = clock.addingTimeInterval(16)
        store.loadActivity(interval: interval)
        XCTAssertEqual(repo.requests.count, 2)
        reply(repo, 1, records: [game(interval.start)])
        XCTAssertFalse(store.isActivityFromCache)
        XCTAssertEqual(store.activityRecords.count, 1)
    }

    func testCachedActivityDoesNotCrossAccountsOrSurviveAStoreRecreation() {
        let repo = ControlledActivityRepository(), first = GameHistoryStore(ownerID: "player", repository: repo)
        let interval = DateInterval(start: Date(), duration: 86400)
        first.loadActivity(interval: interval); reply(repo, 0, records: [game(interval.start)])
        let other = GameHistoryStore(ownerID: "other", repository: repo)
        other.loadActivity(interval: interval); reply(repo, 1, records: [game(interval.start)])
        XCTAssertTrue(other.solvedDays(calendar: calendar).isEmpty)
        let recreated = GameHistoryStore(ownerID: "player", repository: repo)
        recreated.loadActivity(interval: interval)
        XCTAssertEqual(repo.requests.count, 3)
        XCTAssertTrue(recreated.activityRecords.isEmpty)
    }

    func testSeveralQuickSelectionsOnlyRequestTheFinalRangeAfterIdle() async throws {
        let repo = ControlledActivityRepository(), store = GameHistoryStore(ownerID: "player", repository: repo)
        let first = DateInterval(start: Date(), duration: 86400)
        let last = DateInterval(start: first.start.addingTimeInterval(-86400), duration: 86400)
        var pending: Task<Void, Never>?
        for _ in 0..<4 {
            pending?.cancel()
            pending = Task { await store.loadActivityAfterIdle(interval: first) }
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTAssertTrue(repo.requests.isEmpty)
        pending?.cancel()
        let final = Task { await store.loadActivityAfterIdle(interval: last) }
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(repo.requests.isEmpty, "No query while the date is still settling")
        await final.value
        XCTAssertEqual(repo.requests.count, 1)
        XCTAssertEqual(repo.requests[0].0, last)
    }

    func testLeavingDuringDebounceDoesNotSendARequest() async throws {
        let repo = ControlledActivityRepository(), store = GameHistoryStore(ownerID: "player", repository: repo)
        let pending = Task { await store.loadActivityAfterIdle(interval: DateInterval(start: Date(), duration: 86400)) }
        try await Task.sleep(for: .milliseconds(30))
        pending.cancel()
        await pending.value
        XCTAssertTrue(repo.requests.isEmpty)
    }

    func testOlderWeekIsLoadedIndependentlyOfRecentHistoryAndExcludesNextMidnightAndOtherOwners() {
        let repo = ControlledActivityRepository(), now = Date()
        let recent = (0..<100).map { game(now.addingTimeInterval(-Double($0)), outcome: .mistakes) }
        let store = GameHistoryStore(ownerID: "player", records: recent, repository: repo)
        let start = calendar.startOfDay(for: now.addingTimeInterval(-40 * 86400))
        let interval = DateInterval(start: start, end: start.addingTimeInterval(7 * 86400))
        store.loadActivity(interval: interval)
        XCTAssertTrue(store.isLoadingActivity)
        let oldWin = game(start.addingTimeInterval(3600))
        repo.requests[0].1(.success(GameHistorySnapshot(records: [oldWin, game(interval.end), game(start, owner: "another")],
                                                       isFromCache: false, hasMore: false)))
        XCTAssertFalse(store.isLoadingActivity)
        XCTAssertEqual(store.records.count, 100, "Calendar loading must not replace the history page")
        XCTAssertEqual(store.activityRecords, [oldWin])
        XCTAssertEqual(store.solvedDays(calendar: calendar), [start])
    }

    func testRapidWeekChangesIgnoreOldRepliesAndRetryDistinguishesErrorsFromEmptyDays() {
        let repo = ControlledActivityRepository()
        let actualStore = GameHistoryStore(ownerID: "player", repository: repo)
        let start = calendar.startOfDay(for: Date())
        let older = DateInterval(start: start.addingTimeInterval(-7 * 86400), end: start)
        let current = DateInterval(start: start, end: start.addingTimeInterval(7 * 86400))
        actualStore.loadActivity(interval: older); actualStore.loadActivity(interval: current)
        XCTAssertEqual(repo.cancellations, 1)
        repo.requests[0].1(.success(GameHistorySnapshot(records: [game(older.start)], isFromCache: false, hasMore: false)))
        XCTAssertTrue(actualStore.isLoadingActivity)
        XCTAssertTrue(actualStore.activityRecords.isEmpty)
        repo.requests[1].1(.failure(HistoryCloudError.noConnection))
        XCTAssertNotNil(actualStore.activityError)
        actualStore.loadActivity(interval: current)
        repo.requests[2].1(.success(GameHistorySnapshot(records: [], isFromCache: true, hasMore: false)))
        XCTAssertNil(actualStore.activityError)
        XCTAssertTrue(actualStore.isActivityFromCache)
        XCTAssertTrue(actualStore.solvedDays(calendar: calendar).isEmpty)
    }

    func testPendingWinAppearsImmediatelyAndSurvivesAnEmptyCloudActivityReply() throws {
        let repo = ControlledActivityRepository(), store = GameHistoryStore(ownerID: "player", repository: repo)
        var board = PreviewPuzzle.solution; board[0] = 0
        var session = GameSession(puzzle: SudokuPuzzle(givens: board, solution: PreviewPuzzle.solution, difficulty: .easy))
        session.enter(5)
        let date = Date(), day = calendar.startOfDay(for: date)
        let win = try XCTUnwrap(store.record(id: UUID(), session: session, finishedAt: date))
        store.loadActivity(interval: DateInterval(start: day, end: day.addingTimeInterval(86400)))
        repo.requests[0].1(.success(GameHistorySnapshot(records: [], isFromCache: false, hasMore: false)))
        XCTAssertTrue(store.pendingIDs.contains(win.id))
        XCTAssertEqual(store.solvedDays(calendar: calendar), [day])
    }
}
#endif
