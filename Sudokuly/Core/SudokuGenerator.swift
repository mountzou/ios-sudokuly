import Foundation

struct SudokuPuzzle: Sendable {
    let givens: [Int]
    let solution: [Int]
    let difficulty: Difficulty

    init(givens: [Int], solution: [Int], difficulty: Difficulty) {
        precondition(givens.count == 81 && solution.count == 81)
        precondition(givens.indices.allSatisfy { givens[$0] == 0 || givens[$0] == solution[$0] })
        self.givens = givens
        self.solution = solution
        self.difficulty = difficulty
    }
}

/// A new randomized completed board, with clues removed only while its solution stays unique.
enum SudokuGenerator {
    static func generate(difficulty: Difficulty, seed: UInt64? = nil) -> SudokuPuzzle {
        var random = SeededRandom(seed: seed ?? UInt64.random(in: .min ... .max))
        var best: SudokuPuzzle?
        for _ in 0..<8 {
            var solution = [Int](repeating: 0, count: 81)
            _ = fill(&solution, random: &random)
            var givens = solution
            var clues = 81
            for index in Array(0..<81).shuffled(using: &random) {
                if clues == difficulty.clueCount { break }
                let previous = givens[index]
                givens[index] = 0
                if solutionCount(givens, limit: 2) == 1 {
                    clues -= 1
                } else {
                    givens[index] = previous
                }
            }
            let puzzle = SudokuPuzzle(givens: givens, solution: solution, difficulty: difficulty)
            if best == nil || clues < best!.givens.filter({ $0 != 0 }).count { best = puzzle }
            if clues == difficulty.clueCount { return puzzle }
        }
        // A rare removal dead end may retain a few extra clues; uniqueness always wins.
        return best!
    }

    static func solutionCount(_ board: [Int], limit: Int = 2) -> Int {
        guard board.count == 81, limit > 0, var search = Search(board) else { return 0 }
        return search.count(limit: limit)
    }

    static func isValidSolution(_ board: [Int]) -> Bool {
        guard board.count == 81, board.allSatisfy({ (1...9).contains($0) }) else { return false }
        return Search(board) != nil
    }

    private static func fill(_ board: inout [Int], random: inout SeededRandom) -> Bool {
        guard let index = board.firstIndex(of: 0) else { return true }
        for digit in Array(1...9).shuffled(using: &random) {
            if peers(of: index).allSatisfy({ board[$0] != digit }) {
                board[index] = digit
                if fill(&board, random: &random) { return true }
                board[index] = 0
            }
        }
        return false
    }

    static func peers(of index: Int) -> [Int] {
        let row = index / 9, column = index % 9
        return (0..<81).filter {
            $0 != index && ($0 / 9 == row || $0 % 9 == column ||
                ($0 / 27 == row / 3 && ($0 % 9) / 3 == column / 3))
        }
    }

    private struct Search {
        var board: [Int]
        var rows = [Int](repeating: 0, count: 9)
        var columns = [Int](repeating: 0, count: 9)
        var boxes = [Int](repeating: 0, count: 9)

        init?(_ board: [Int]) {
            self.board = board
            for index in board.indices where board[index] != 0 {
                let value = board[index]
                guard (1...9).contains(value) else { return nil }
                let row = index / 9, column = index % 9, box = (row / 3) * 3 + column / 3
                let bit = 1 << value
                guard (rows[row] | columns[column] | boxes[box]) & bit == 0 else { return nil }
                rows[row] |= bit; columns[column] |= bit; boxes[box] |= bit
            }
        }

        mutating func count(limit: Int) -> Int {
            var selected = -1, candidates = 0, minimum = 10
            for index in board.indices where board[index] == 0 {
                let row = index / 9, column = index % 9, box = (row / 3) * 3 + column / 3
                let available = 0x3FE & ~(rows[row] | columns[column] | boxes[box])
                let count = available.nonzeroBitCount
                if count == 0 { return 0 }
                if count < minimum {
                    selected = index; candidates = available; minimum = count
                    if count == 1 { break }
                }
            }
            if selected == -1 { return 1 }
            let row = selected / 9, column = selected % 9, box = (row / 3) * 3 + column / 3
            var total = 0
            for digit in 1...9 where candidates & (1 << digit) != 0 {
                let bit = 1 << digit
                board[selected] = digit
                rows[row] |= bit; columns[column] |= bit; boxes[box] |= bit
                total += count(limit: limit - total)
                board[selected] = 0
                rows[row] &= ~bit; columns[column] &= ~bit; boxes[box] &= ~bit
                if total >= limit { break }
            }
            return total
        }
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
