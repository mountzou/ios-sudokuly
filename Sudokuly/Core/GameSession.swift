import Foundation

enum GameOutcome: String, Codable, Sendable {
    case won, mistakes, timedOut
}

/// All state lives in memory and is discarded when the player returns home.
struct GameSession {
    let puzzle: SudokuPuzzle
    let timeLimit: TimeInterval
    private(set) var board: [Int]
    private(set) var notes = [Set<Int>](repeating: [], count: 81)
    private(set) var mistakes = 0
    private(set) var hintsRemaining = 3
    private(set) var elapsed: TimeInterval = 0
    private(set) var outcome: GameOutcome?
    private(set) var selected: Int?
    private(set) var isNotesMode = false
    private var history: [Snapshot] = []

    init(puzzle: SudokuPuzzle, timeLimit: TimeInterval? = nil) {
        self.puzzle = puzzle
        self.timeLimit = timeLimit ?? puzzle.difficulty.timeLimit
        board = puzzle.givens
        selected = puzzle.givens.firstIndex(of: 0)
    }

    var remaining: TimeInterval { max(0, timeLimit - elapsed) }
    var canUndo: Bool { !history.isEmpty && outcome == nil }
    var canEdit: Bool { selected.map { puzzle.givens[$0] == 0 } ?? false }
    var canUseHint: Bool {
        guard outcome == nil, hintsRemaining > 0, let index = selected, canEdit else { return false }
        return board[index] != puzzle.solution[index]
    }
    var filledCount: Int { board.indices.filter { puzzle.givens[$0] == 0 && board[$0] == puzzle.solution[$0] }.count }
    var emptyCount: Int { puzzle.givens.filter { $0 == 0 }.count }
    var progress: Double { emptyCount == 0 ? 1 : Double(filledCount) / Double(emptyCount) }

    mutating func select(_ index: Int) {
        guard outcome == nil, board.indices.contains(index) else { return }
        selected = index
    }

    mutating func toggleNotes() {
        guard outcome == nil else { return }
        isNotesMode.toggle()
    }

    mutating func enter(_ digit: Int) {
        guard outcome == nil, (1...9).contains(digit), let index = selected, canEdit else { return }
        if isNotesMode {
            guard board[index] == 0 else { return }
            saveSnapshot()
            if notes[index].contains(digit) { notes[index].remove(digit) } else { notes[index].insert(digit) }
            return
        }
        guard board[index] != digit else { return }
        placeDigit(digit, at: index)
    }

    @discardableResult
    mutating func useHint() -> Bool {
        guard canUseHint, let index = selected else { return false }
        hintsRemaining -= 1
        // Hints enter a final value even while Notes mode is enabled.
        placeDigit(puzzle.solution[index], at: index)
        return true
    }

    mutating func erase() {
        guard outcome == nil, let index = selected, canEdit,
              board[index] != 0 || !notes[index].isEmpty else { return }
        saveSnapshot()
        board[index] = 0
        notes[index] = []
    }

    mutating func undo() {
        guard outcome == nil, let previous = history.popLast() else { return }
        board = previous.board
        notes = previous.notes
        selected = previous.selected
        // Undo restores the board, never the mistake/hint budgets or the clock.
    }

    mutating func advance(by seconds: TimeInterval) {
        guard outcome == nil, seconds > 0, seconds.isFinite else { return }
        elapsed = min(timeLimit, elapsed + seconds)
        if remaining <= 0 { outcome = .timedOut }
    }

    private mutating func placeDigit(_ digit: Int, at index: Int) {
        saveSnapshot()
        board[index] = digit
        notes[index] = []
        if digit != puzzle.solution[index] {
            mistakes += 1
            if mistakes >= 3 { outcome = .mistakes }
        } else {
            for peer in SudokuGenerator.peers(of: index) { notes[peer].remove(digit) }
            if board == puzzle.solution { outcome = .won }
        }
    }

    private mutating func saveSnapshot() {
        history.append(Snapshot(board: board, notes: notes, selected: selected))
    }

    private struct Snapshot {
        let board: [Int]
        let notes: [Set<Int>]
        let selected: Int?
    }
}
