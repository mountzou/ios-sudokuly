#if canImport(UIKit)
import XCTest
@testable import Sudokuly

@MainActor
final class MVPViewModelTests: XCTestCase {
    private func almostSolved(_ level: Difficulty) -> SudokuPuzzle {
        var givens = PreviewPuzzle.solution; givens[0] = 0
        return SudokuPuzzle(givens: givens, solution: PreviewPuzzle.solution, difficulty: level)
    }

    func testInputAtDeadlineCannotTurnTimeoutIntoWinOrMistake() throws {
        for level in Difficulty.allCases {
            for digit in [5, 3] {
                var time: TimeInterval = 100
                let store = GameHistoryStore(ownerID: "deadline")
                let model = GameViewModel(history: store, uptime: { time })
                model.beginGame(puzzle: almostSolved(level))
                time += level.timeLimit
                model.enter(digit)
                XCTAssertEqual(model.session?.outcome, .timedOut)
                XCTAssertEqual(model.session?.board[0], 0)
                XCTAssertEqual(model.session?.mistakes, 0)
                XCTAssertEqual(store.records.count, 1)
                XCTAssertEqual(store.records.first?.duration, level.timeLimit)
                model.tick(); model.enter(digit); model.pause(); model.undo(); model.goHome()
                XCTAssertEqual(store.records.count, 1)
            }
        }
    }

    func testLastCorrectInputBeforeDeadlineWinsAndPausedTimeIsExcluded() {
        for level in Difficulty.allCases {
            var time: TimeInterval = 100
            let store = GameHistoryStore(ownerID: "pause")
            let model = GameViewModel(history: store, uptime: { time })
            model.beginGame(puzzle: almostSolved(level))
            time += 20; model.pause()
            time += 5000; model.tick(); model.enter(5)
            XCTAssertEqual(model.session?.elapsed, 20)
            XCTAssertNil(model.session?.outcome)
            model.resume()
            time += level.timeLimit - 20 - 0.001
            model.enter(5)
            XCTAssertEqual(model.session?.outcome, .won)
            XCTAssertEqual(store.records.count, 1)
            XCTAssertEqual(store.records.first?.duration ?? 0, level.timeLimit - 0.001, accuracy: 0.00001)
        }
    }

    func testTwoWinsThenOneLossRemainOrderedWithStableIDs() {
        let store = GameHistoryStore(ownerID: "mixed")
        var time: TimeInterval = 100
        var date = Date()
        let model = GameViewModel(history: store, uptime: { time }, now: { date })
        for level in [Difficulty.easy, .hard, .expert] {
            model.beginGame(puzzle: almostSolved(level))
            time += 10
            if level == .expert { model.enter(3); model.enter(4); model.enter(3) }
            else { model.enter(5) }
            model.goHome(); date = date.addingTimeInterval(1)
        }
        XCTAssertEqual(store.records.map(\.outcome), [.mistakes, .won, .won])
        XCTAssertEqual(store.records.map(\.difficulty), [.expert, .hard, .easy])
        XCTAssertEqual(Set(store.records.map(\.id)).count, 3)
    }

    func testHintAtDeadlineCannotWinOrSpendBudget() {
        for level in Difficulty.allCases {
            var time: TimeInterval = 100
            let store = GameHistoryStore(ownerID: "hint-deadline")
            let model = GameViewModel(history: store, uptime: { time })
            model.beginGame(puzzle: almostSolved(level))
            time += level.timeLimit
            model.useHint()
            XCTAssertEqual(model.session?.outcome, .timedOut)
            XCTAssertEqual(model.session?.board[0], 0)
            XCTAssertEqual(model.session?.hintsRemaining, 3)
            XCTAssertEqual(store.records.count, 1)
            XCTAssertEqual(store.records.first?.outcome, .timedOut)
        }
    }

    func testHintWinRecordsOnceAndClearsStaleMessage() {
        var time: TimeInterval = 100
        let store = GameHistoryStore(ownerID: "hint-win")
        let model = GameViewModel(history: store, uptime: { time })
        model.beginGame(puzzle: almostSolved(.easy))
        model.enter(3)
        XCTAssertFalse(model.message.isEmpty)
        time += 12
        model.useHint()
        XCTAssertEqual(model.session?.outcome, .won)
        XCTAssertEqual(model.session?.hintsRemaining, 2)
        XCTAssertEqual(model.message, "")
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.outcome, .won)
        XCTAssertEqual(store.records.first?.mistakes, 1)
        XCTAssertEqual(store.records.first?.duration, 12)
        XCTAssertEqual(model.completedGame?.id, store.records.first?.id)
        model.useHint(); model.tick()
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(model.session?.hintsRemaining, 2)
    }

    func testPausedHintsDoNothingAndEachNewGameGetsThree() {
        var time: TimeInterval = 100
        let store = GameHistoryStore(ownerID: "hint-pause")
        let model = GameViewModel(history: store, uptime: { time })
        model.beginGame(puzzle: PreviewPuzzle.testPuzzle(difficulty: .easy))
        time += 10
        model.pause()
        time += 1000
        model.useHint()
        XCTAssertEqual(model.session?.board[0], 0)
        XCTAssertEqual(model.session?.hintsRemaining, 3)
        XCTAssertEqual(model.session?.elapsed, 10)
        model.resume()
        model.useHint()
        XCTAssertEqual(model.session?.board[0], 5)
        XCTAssertEqual(model.session?.hintsRemaining, 2)
        XCTAssertEqual(model.session?.elapsed, 10)
        XCTAssertTrue(store.records.isEmpty)
        model.goHome()
        model.useHint()
        XCTAssertNil(model.session)
        model.beginGame(puzzle: PreviewPuzzle.testPuzzle(difficulty: .hard))
        XCTAssertEqual(model.session?.hintsRemaining, 3)
        XCTAssertEqual(model.session?.board[0], 0)
    }
}
#endif
