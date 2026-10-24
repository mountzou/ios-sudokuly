import XCTest
#if canImport(SudokulyCore)
@testable import SudokulyCore
#else
@testable import Sudokuly
#endif

final class SudokuGeneratorTests: XCTestCase {
    func testEachDifficultyProducesUniqueValidVariedPuzzles() {
        var fingerprints = Set<[Int]>()
        for difficulty in Difficulty.allCases {
            for seed in 0..<8 {
                let puzzle = SudokuGenerator.generate(difficulty: difficulty, seed: UInt64(seed))
                XCTAssertTrue(SudokuGenerator.isValidSolution(puzzle.solution))
                XCTAssertEqual(SudokuGenerator.solutionCount(puzzle.givens), 1)
                let clues = puzzle.givens.filter { $0 != 0 }.count
                XCTAssertGreaterThanOrEqual(clues, difficulty.clueCount)
                XCTAssertLessThanOrEqual(clues, difficulty.clueCount + 3)
                XCTAssertTrue(puzzle.givens.indices.allSatisfy { puzzle.givens[$0] == 0 || puzzle.givens[$0] == puzzle.solution[$0] })
                XCTAssertTrue(fingerprints.insert(puzzle.givens).inserted)
            }
        }
        XCTAssertEqual(fingerprints.count, 32)
    }

    func testSolverRejectsInvalidBoardsAndDetectsMultipleSolutions() {
        XCTAssertEqual(SudokuGenerator.solutionCount([Int](repeating: 0, count: 80)), 0)
        var conflicting = [Int](repeating: 0, count: 81)
        conflicting[0] = 1; conflicting[1] = 1
        XCTAssertEqual(SudokuGenerator.solutionCount(conflicting), 0)
        conflicting[1] = 10
        XCTAssertEqual(SudokuGenerator.solutionCount(conflicting), 0)
        XCTAssertEqual(SudokuGenerator.solutionCount([Int](repeating: 0, count: 81)), 2)
    }

    func testSeedReproducesPuzzleForDiagnostics() {
        XCTAssertEqual(SudokuGenerator.generate(difficulty: .hard, seed: 42).givens,
                       SudokuGenerator.generate(difficulty: .hard, seed: 42).givens)
    }
}

final class GameSessionTests: XCTestCase {
    private func session(timeLimit: TimeInterval = 60) -> GameSession {
        let puzzle = SudokuGenerator.generate(difficulty: .easy, seed: 9)
        return GameSession(puzzle: puzzle, timeLimit: timeLimit)
    }

    func testCompletingPuzzleWinsAndTerminalStateIsFrozen() {
        var game = session()
        game.advance(by: 12)
        for index in game.board.indices where game.puzzle.givens[index] == 0 {
            game.select(index)
            game.enter(game.puzzle.solution[index])
        }
        XCTAssertEqual(game.outcome, .won)
        XCTAssertEqual(game.progress, 1)
        let finalBoard = game.board
        game.erase(); game.undo(); game.advance(by: 100)
        XCTAssertEqual(game.board, finalBoard)
        XCTAssertEqual(game.elapsed, 12)
        XCTAssertEqual(game.outcome, .won)
    }

    func testThirdMistakeLosesAndUndoDoesNotRefundMistakes() {
        var game = session()
        let index = game.selected!
        let wrong = game.puzzle.solution[index] % 9 + 1
        game.enter(wrong)
        game.enter(wrong) // Repeated taps of the unchanged value are not new attempts.
        XCTAssertEqual(game.mistakes, 1)
        game.undo()
        XCTAssertEqual(game.board[index], 0)
        XCTAssertEqual(game.mistakes, 1)
        game.enter(wrong); game.erase(); game.enter(wrong)
        XCTAssertEqual(game.mistakes, 3)
        XCTAssertEqual(game.outcome, .mistakes)
        game.undo()
        XCTAssertEqual(game.mistakes, 3)
    }

    func testDeadlineAndLateInput() {
        var game = session(timeLimit: 2)
        game.advance(by: 1.75)
        XCTAssertNil(game.outcome)
        game.advance(by: 0.25)
        XCTAssertEqual(game.remaining, 0)
        XCTAssertEqual(game.outcome, .timedOut)
        let board = game.board
        game.enter(game.puzzle.solution[game.selected!])
        XCTAssertEqual(game.board, board)
        game.advance(by: 500)
        XCTAssertEqual(game.elapsed, 2)
    }

    func testGivensCannotBeEditedOrErased() {
        var game = session()
        let index = game.puzzle.givens.firstIndex(where: { $0 != 0 })!
        game.select(index)
        let board = game.board
        game.enter(1); game.erase(); game.toggleNotes(); game.enter(2)
        XCTAssertEqual(game.board, board)
        XCTAssertTrue(game.notes[index].isEmpty)
        XCTAssertEqual(game.mistakes, 0)
    }

    func testNotesToggleEraseAndUndoWithoutPenalties() {
        var game = session()
        let index = game.selected!
        game.toggleNotes(); game.enter(2); game.enter(7)
        XCTAssertEqual(game.notes[index], Set([2, 7]))
        XCTAssertEqual(game.board[index], 0)
        XCTAssertEqual(game.mistakes, 0)
        game.enter(2)
        XCTAssertEqual(game.notes[index], Set([7]))
        game.erase()
        XCTAssertTrue(game.notes[index].isEmpty)
        game.undo()
        XCTAssertEqual(game.notes[index], Set([7]))
    }

    func testCorrectEntriesClearPeerNotesAndUndoRestoresThem() {
        var game = session()
        let index = game.selected!
        let peer = SudokuGenerator.peers(of: index).first { game.board[$0] == 0 }!
        let digit = game.puzzle.solution[index]
        game.select(peer); game.toggleNotes(); game.enter(digit)
        game.toggleNotes(); game.select(index); game.enter(digit)
        XCTAssertTrue(game.notes[peer].isEmpty)
        game.undo()
        XCTAssertEqual(game.notes[peer], Set([digit]))
        XCTAssertEqual(game.board[index], 0)
    }

    func testInvalidActionsAndTimeCannotCorruptSession() {
        var game = session()
        let board = game.board
        let selected = game.selected
        game.select(-1); game.select(81); game.enter(0); game.enter(10)
        game.advance(by: -.infinity); game.advance(by: .nan); game.advance(by: -5)
        XCTAssertEqual(game.board, board)
        XCTAssertEqual(game.selected, selected)
        XCTAssertEqual(game.elapsed, 0)
    }
}
