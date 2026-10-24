import XCTest
#if canImport(SudokulyCore)
@testable import SudokulyCore
#else
@testable import Sudokuly
#endif

final class GameRecordTests: XCTestCase {
    private func session(_ difficulty: Difficulty = .easy) -> GameSession {
        let solution = SudokuGenerator.generate(difficulty: difficulty, seed: 42).solution
        var givens = solution
        givens[0] = 0
        return GameSession(puzzle: SudokuPuzzle(givens: givens, solution: solution, difficulty: difficulty))
    }

    func testActiveAndAbandonedGamesHaveNoFinishedRecord() {
        var game = session()
        game.advance(by: 30)
        game.toggleNotes()
        game.enter(4)
        XCTAssertNil(GameRecord(id: UUID(), ownerID: "player", session: game, finishedAt: Date()))
    }

    func testWinCapturesSummaryAndStableIdentity() throws {
        var game = session(.hard)
        game.advance(by: 83.5)
        game.enter(game.puzzle.solution[0])
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let record = try XCTUnwrap(GameRecord(id: id, ownerID: "player", session: game, finishedAt: date))
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.ownerID, "player")
        XCTAssertEqual(record.finishedAt, date)
        XCTAssertEqual(record.difficulty, .hard)
        XCTAssertEqual(record.outcome, .won)
        XCTAssertEqual(record.duration, 83.5)
        XCTAssertEqual(record.mistakes, 0)
    }

    func testThreeMistakesCapturesActualDurationAndAttempts() throws {
        var game = session(.medium)
        let correct = game.puzzle.solution[0]
        let wrong = (1...9).filter { $0 != correct }
        game.advance(by: 127)
        for digit in wrong.prefix(3) { game.enter(digit) }
        let record = try XCTUnwrap(GameRecord(id: UUID(), ownerID: "player", session: game, finishedAt: Date()))
        XCTAssertEqual(record.outcome, .mistakes)
        XCTAssertEqual(record.mistakes, 3)
        XCTAssertEqual(record.duration, 127)
    }

    func testTimeoutRecordsClampedPlayTime() throws {
        var game = session(.expert)
        game.advance(by: 3000)
        let record = try XCTUnwrap(GameRecord(id: UUID(), ownerID: "player", session: game, finishedAt: Date()))
        XCTAssertEqual(record.outcome, .timedOut)
        XCTAssertEqual(record.duration, Difficulty.expert.timeLimit)
        XCTAssertEqual(record.mistakes, 0)
    }
}
