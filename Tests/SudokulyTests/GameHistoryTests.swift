#if canImport(UIKit)
import XCTest
@testable import Sudokuly

@MainActor
final class GameHistoryTests: XCTestCase {
    private func puzzle() -> SudokuPuzzle {
        var givens = PreviewPuzzle.solution
        givens[0] = 0
        return SudokuPuzzle(givens: givens, solution: PreviewPuzzle.solution, difficulty: .easy)
    }

    func testFinishedGameIsStoredOnceBeforeReturningHome() throws {
        let store = GameHistoryStore(ownerID: "player")
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var clock: TimeInterval = 100
        let model = GameViewModel(history: store, uptime: { clock }, now: { date })
        model.beginGame(puzzle: puzzle())
        clock += 42
        model.enter(5)
        let saved = try XCTUnwrap(store.records.first)
        XCTAssertEqual(saved.duration, 42)
        XCTAssertEqual(saved.finishedAt, date)
        XCTAssertEqual(saved.ownerID, "player")
        XCTAssertEqual(saved.outcome, .won)
        XCTAssertEqual(model.completedGame, saved)
        model.tick()
        model.enter(5)
        model.pause()
        _ = store.record(id: saved.id, session: try XCTUnwrap(model.session), finishedAt: date.addingTimeInterval(60))
        XCTAssertEqual(store.records, [saved])
        model.goHome()
        XCTAssertNil(model.session)
        XCTAssertEqual(store.records, [saved])
    }

    func testTimerExpiryIsRecordedWithoutAnEntryOrNavigation() {
        let store = GameHistoryStore(ownerID: "player")
        var clock: TimeInterval = 100
        let model = GameViewModel(history: store, uptime: { clock })
        model.beginGame(puzzle: puzzle(), timeLimit: 2)
        clock += 10
        model.tick()
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.outcome, .timedOut)
        XCTAssertEqual(store.records.first?.duration, 2)
        model.tick()
        XCTAssertEqual(store.records.count, 1)
    }

    func testThreeMistakesAreRecordedAndAnotherGameGetsANewIdentity() {
        let store = GameHistoryStore(ownerID: "player")
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        let model = GameViewModel(history: store, now: { date })
        model.beginGame(puzzle: puzzle())
        model.enter(3); model.enter(4); model.enter(3)
        XCTAssertEqual(store.records.first?.outcome, .mistakes)
        XCTAssertEqual(store.records.first?.mistakes, 3)
        let previousID = store.records.first?.id
        model.goHome()
        date = date.addingTimeInterval(60)
        model.beginGame(puzzle: puzzle())
        model.enter(5)
        XCTAssertEqual(store.records.count, 2)
        XCTAssertNotEqual(store.records.first?.id, previousID)
    }

    func testPauseAndAbandonDoNotCreateHistory() {
        let store = GameHistoryStore(ownerID: "player")
        let model = GameViewModel(history: store)
        model.beginGame(puzzle: puzzle())
        model.pause()
        model.goHome()
        XCTAssertTrue(store.records.isEmpty)
    }

    func testHistoriesRejectOtherOwnersAndSortNewestFirst() {
        let date = Date()
        let old = GameRecord(ownerID: "player", finishedAt: date, difficulty: .easy, outcome: .won, duration: 42, mistakes: 0)
        let recent = GameRecord(ownerID: "player", finishedAt: date.addingTimeInterval(60), difficulty: .hard, outcome: .mistakes, duration: 91, mistakes: 3)
        let other = GameRecord(ownerID: "other-player", finishedAt: date.addingTimeInterval(120), difficulty: .expert, outcome: .won, duration: 555, mistakes: 1)
        let store = GameHistoryStore(ownerID: "player", records: [old, other, recent, old])
        XCTAssertEqual(store.records, [recent, old])
        XCTAssertEqual(GameHistoryStore(ownerID: "other-player", records: store.records).records, [])
        XCTAssertTrue(GameHistoryStore(ownerID: "player").records.isEmpty)
    }

    #if DEBUG && targetEnvironment(simulator)
    func testDemoSamplesCoverAllLevelsAndOutcomesForOneOwner() {
        let records = HistoryDemoData.records(ownerID: "player")
        XCTAssertEqual(records.count, 6)
        XCTAssertEqual(Set(records.map(\.difficulty)), Set(Difficulty.allCases))
        XCTAssertEqual(Set(records.map(\.outcome)), Set([GameOutcome.won, .mistakes, .timedOut]))
        XCTAssertEqual(Set(records.map(\.ownerID)), ["player"])
    }
    #endif
}
#endif
