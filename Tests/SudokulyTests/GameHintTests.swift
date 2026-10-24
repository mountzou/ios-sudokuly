import XCTest
#if canImport(SudokulyCore)
@testable import SudokulyCore
#else
@testable import Sudokuly
#endif

final class GameHintTests: XCTestCase {
    private func session(_ difficulty: Difficulty = .easy) -> GameSession {
        GameSession(puzzle: SudokuGenerator.generate(difficulty: difficulty, seed: 9))
    }

    func testExactlyThreeHintsFillOnlySelectedCellsAtEveryDifficulty() {
        for difficulty in Difficulty.allCases {
            var game = session(difficulty)
            let cells = game.board.indices.filter { game.board[$0] == 0 }
            XCTAssertEqual(game.hintsRemaining, 3)
            for (used, index) in cells.prefix(3).enumerated() {
                game.select(index)
                var expectedBoard = game.board
                expectedBoard[index] = game.puzzle.solution[index]
                XCTAssertTrue(game.canUseHint)
                XCTAssertTrue(game.useHint())
                XCTAssertEqual(game.board, expectedBoard)
                XCTAssertEqual(game.hintsRemaining, 2 - used)
                XCTAssertEqual(game.mistakes, 0)
                XCTAssertFalse(game.canUseHint)
            }
            game.select(cells[3])
            let board = game.board
            XCTAssertFalse(game.canUseHint)
            XCTAssertFalse(game.useHint())
            XCTAssertEqual(game.board, board)
            XCTAssertEqual(game.hintsRemaining, 0)
            XCTAssertNil(game.outcome)
        }
    }

    func testGivensCorrectCellsAndMissingSelectionDoNotSpendHints() throws {
        var game = session()
        let empty = try XCTUnwrap(game.selected)
        let given = try XCTUnwrap(game.puzzle.givens.firstIndex { $0 != 0 })
        game.select(given)
        let board = game.board
        XCTAssertFalse(game.canUseHint)
        XCTAssertFalse(game.useHint())
        XCTAssertEqual(game.board, board)
        game.select(empty)
        game.enter(game.puzzle.solution[empty])
        XCTAssertFalse(game.canUseHint)
        XCTAssertFalse(game.useHint())
        XCTAssertEqual(game.hintsRemaining, 3)

        var noSelection = GameSession(puzzle: SudokuPuzzle(givens: game.puzzle.solution,
                                                          solution: game.puzzle.solution, difficulty: .easy))
        XCTAssertNil(noSelection.selected)
        XCTAssertFalse(noSelection.useHint())
        XCTAssertEqual(noSelection.hintsRemaining, 3)
    }

    func testHintPlacesFinalValueInNotesModeAndOnlyClearsRelatedNotes() throws {
        var game = session()
        let index = try XCTUnwrap(game.selected)
        let peer = try XCTUnwrap(SudokuGenerator.peers(of: index).first { game.board[$0] == 0 })
        let digit = game.puzzle.solution[index]
        let other = digit % 9 + 1
        game.toggleNotes()
        game.enter(other)
        game.select(peer)
        game.enter(digit)
        game.enter(other)
        game.select(index)

        XCTAssertTrue(game.useHint())
        XCTAssertEqual(game.board[index], digit)
        XCTAssertTrue(game.notes[index].isEmpty)
        XCTAssertEqual(game.notes[peer], Set([other]))
        XCTAssertEqual(game.board[peer], 0)
        XCTAssertTrue(game.isNotesMode)
        XCTAssertEqual(game.hintsRemaining, 2)
        XCTAssertEqual(game.mistakes, 0)
    }

    func testHintCorrectsWrongValueWithoutAddingOrRefundingMistakesOrTime() throws {
        var game = session()
        let index = try XCTUnwrap(game.selected)
        game.enter(game.puzzle.solution[index] % 9 + 1)
        game.advance(by: 12)
        XCTAssertTrue(game.useHint())
        XCTAssertEqual(game.board[index], game.puzzle.solution[index])
        XCTAssertEqual(game.mistakes, 1)
        XCTAssertEqual(game.elapsed, 12)
        XCTAssertEqual(game.hintsRemaining, 2)
    }

    func testErasingOrUndoingHintDoesNotRestoreItsBudget() {
        var game = session()
        XCTAssertTrue(game.useHint())
        game.erase()
        XCTAssertEqual(game.hintsRemaining, 2)
        XCTAssertTrue(game.useHint())
        game.undo()
        XCTAssertEqual(game.hintsRemaining, 1)
        XCTAssertTrue(game.useHint())
        game.erase()
        XCTAssertEqual(game.hintsRemaining, 0)
        XCTAssertFalse(game.canUseHint)
        XCTAssertFalse(game.useHint())
    }

    func testHintOnLastEmptyCellWins() throws {
        var game = session()
        let lastCell = try XCTUnwrap(game.selected)
        for index in game.board.indices where game.puzzle.givens[index] == 0 && index != lastCell {
            game.select(index)
            game.enter(game.puzzle.solution[index])
        }
        game.select(lastCell)
        XCTAssertNil(game.outcome)
        XCTAssertTrue(game.useHint())
        XCTAssertEqual(game.outcome, .won)
        XCTAssertEqual(game.board, game.puzzle.solution)
        XCTAssertEqual(game.progress, 1)
        XCTAssertEqual(game.hintsRemaining, 2)
        XCTAssertFalse(game.useHint())
        XCTAssertEqual(game.hintsRemaining, 2)
    }

    func testHintsCannotChangeAnyTerminalOutcome() throws {
        for outcome in [GameOutcome.won, .mistakes, .timedOut] {
            var game = session()
            switch outcome {
            case .won:
                for index in game.board.indices where game.puzzle.givens[index] == 0 {
                    game.select(index)
                    game.enter(game.puzzle.solution[index])
                }
            case .mistakes:
                let index = try XCTUnwrap(game.selected)
                let wrong = game.puzzle.solution[index] % 9 + 1
                for _ in 0..<3 { game.enter(wrong); game.erase() }
            case .timedOut:
                game.advance(by: game.timeLimit)
            }
            let board = game.board
            XCTAssertEqual(game.outcome, outcome)
            XCTAssertFalse(game.canUseHint)
            XCTAssertFalse(game.useHint())
            XCTAssertEqual(game.board, board)
            XCTAssertEqual(game.outcome, outcome)
            XCTAssertEqual(game.hintsRemaining, 3)
        }
    }
}
