import XCTest
#if canImport(SudokulyCore)
@testable import SudokulyCore
#else
@testable import Sudokuly
#endif

final class MVPGameMatrixTests: XCTestCase {
    func test128RealPuzzlesHaveOneSolutionAndRespectEveryDifficulty() {
        var boards = Set<[Int]>()
        for level in Difficulty.allCases {
            for seed in 100..<132 {
                let puzzle = SudokuGenerator.generate(difficulty: level, seed: UInt64(seed))
                let context = "\(level.rawValue), seed \(seed)"
                XCTAssertTrue(SudokuGenerator.isValidSolution(puzzle.solution), context)
                XCTAssertEqual(SudokuGenerator.solutionCount(puzzle.givens), 1, context)
                let clues = puzzle.givens.filter { $0 != 0 }.count
                XCTAssertGreaterThanOrEqual(clues, level.clueCount, context)
                XCTAssertLessThanOrEqual(clues, level.clueCount + 3, context)
                XCTAssertTrue(boards.insert(puzzle.givens).inserted, context)
            }
        }
        XCTAssertEqual(boards.count, 128)
    }

    func testAllLevelsAndSevenTerminalVariantsFreezeAndCreateAccurateSummaries() throws {
        for level in Difficulty.allCases {
            for (outcome, mistakes) in [(GameOutcome.won, 0), (.won, 1), (.won, 2), (.mistakes, 3),
                                        (.timedOut, 0), (.timedOut, 1), (.timedOut, 2)] {
                let puzzle = SudokuGenerator.generate(difficulty: level, seed: UInt64(500 + level.rank * 10 + mistakes))
                var game = GameSession(puzzle: puzzle)
                let index = try XCTUnwrap(game.selected)
                for _ in 0..<mistakes {
                    game.enter(puzzle.solution[index] % 9 + 1)
                    if game.outcome == nil { game.erase() }
                }
                if outcome == .won {
                    game.advance(by: 37)
                    for cell in puzzle.givens.indices where puzzle.givens[cell] == 0 {
                        game.select(cell); game.enter(puzzle.solution[cell])
                    }
                } else if outcome == .timedOut { game.advance(by: level.timeLimit + 99) }
                let context = "\(level), \(outcome), \(mistakes) mistakes"
                XCTAssertEqual(game.outcome, outcome, context)
                XCTAssertEqual(game.mistakes, mistakes, context)
                let record = try XCTUnwrap(GameRecord(id: UUID(), ownerID: "matrix", session: game, finishedAt: Date()))
                XCTAssertEqual(record.outcome, outcome, context)
                XCTAssertEqual(record.difficulty, level, context)
                XCTAssertEqual(record.duration, outcome == .won ? 37 : outcome == .timedOut ? level.timeLimit : 0, context)
                let board = game.board, notes = game.notes, elapsed = game.elapsed
                game.enter(1); game.erase(); game.undo(); game.toggleNotes(); game.select(0); game.advance(by: 9999)
                XCTAssertEqual(game.board, board, context)
                XCTAssertEqual(game.notes, notes, context)
                XCTAssertEqual(game.elapsed, elapsed, context)
                XCTAssertEqual(game.outcome, outcome, context)
            }
        }
    }

    func test6400ReproducibleActionsMaintainSessionInvariants() {
        for level in Difficulty.allCases {
            for seed in 0..<8 {
                let puzzle = SudokuGenerator.generate(difficulty: level, seed: UInt64(seed + 700))
                var game = GameSession(puzzle: puzzle)
                var random = UInt64(seed + 1)
                for step in 0..<200 {
                    random = random &* 6364136223846793005 &+ 1442695040888963407
                    let previous = game
                    switch random % 6 {
                    case 0: game.select(Int((random >> 8) % 81))
                    case 1: game.enter(Int((random >> 12) % 9) + 1)
                    case 2: game.toggleNotes()
                    case 3: game.erase()
                    case 4: game.undo()
                    default: game.advance(by: Double((random >> 16) % 5))
                    }
                    let context = "\(level), seed \(seed), step \(step)"
                    XCTAssertTrue(puzzle.givens.indices.allSatisfy { puzzle.givens[$0] == 0 || game.board[$0] == puzzle.givens[$0] }, context)
                    XCTAssertTrue(game.board.allSatisfy { (0...9).contains($0) }, context)
                    XCTAssertTrue(game.notes.allSatisfy { $0.allSatisfy { (1...9).contains($0) } }, context)
                    XCTAssertTrue((0...3).contains(game.mistakes), context)
                    XCTAssertTrue((0...level.timeLimit).contains(game.elapsed), context)
                    XCTAssertTrue((0...1).contains(game.progress), context)
                    if previous.outcome != nil {
                        XCTAssertEqual(game.board, previous.board, context)
                        XCTAssertEqual(game.notes, previous.notes, context)
                        XCTAssertEqual(game.elapsed, previous.elapsed, context)
                        XCTAssertEqual(game.mistakes, previous.mistakes, context)
                        XCTAssertEqual(game.outcome, previous.outcome, context)
                    }
                }
            }
        }
    }
}
