import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var session: GameSession?
    @Published private(set) var isGenerating = false
    @Published private(set) var isPaused = false
    @Published private(set) var message = ""
    @Published private(set) var completedGame: GameRecord?
    private let history: GameHistoryStore
    private let uptime: () -> TimeInterval
    private let now: () -> Date
    private var gameID: UUID?
    private var generation: Task<Void, Never>?
    private var lastTick: TimeInterval?
    private var isAppActive = true

    init(history: GameHistoryStore, uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         now: @escaping () -> Date = Date.init) {
        self.history = history
        self.uptime = uptime
        self.now = now
    }

    func start(_ difficulty: Difficulty) {
        guard !isGenerating, session == nil else { return }
        isGenerating = true
        generation = Task {
            let puzzle: SudokuPuzzle
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                puzzle = PreviewPuzzle.testPuzzle(difficulty: difficulty)
            } else {
                puzzle = await Task.detached(priority: .userInitiated) {
                    SudokuGenerator.generate(difficulty: difficulty)
                }.value
            }
            #else
            puzzle = await Task.detached(priority: .userInitiated) {
                SudokuGenerator.generate(difficulty: difficulty)
            }.value
            #endif
            guard !Task.isCancelled else { return }
            beginGame(puzzle: puzzle)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") &&
                ProcessInfo.processInfo.arguments.contains("--scenario=timeout") {
                // Expire quickly while preserving the real deadline in the saved summary.
                session?.advance(by: max(0, difficulty.timeLimit - 2))
            }
            #endif
        }
    }

    func beginGame(puzzle: SudokuPuzzle, timeLimit: TimeInterval? = nil) {
        gameID = UUID()
        completedGame = nil
        session = GameSession(puzzle: puzzle, timeLimit: timeLimit)
        message = ""
        isGenerating = false
        isPaused = !isAppActive
        lastTick = isPaused ? nil : uptime()
    }

    func tick() {
        guard session?.outcome == nil, session != nil, !isPaused, let lastTick else { return }
        let currentTick = uptime()
        session?.advance(by: currentTick - lastTick)
        self.lastTick = currentTick
        recordFinishedGame()
    }

    func select(_ index: Int) { tick(); session?.select(index) }

    func enter(_ digit: Int) {
        guard !isPaused else { return }
        tick()
        let mistakes = session?.mistakes ?? 0
        let previousBoard = session?.board
        session?.enter(digit)
        if (session?.mistakes ?? 0) > mistakes {
            message = "Not quite. Take another look."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else if previousBoard != session?.board {
            message = "A little closer. Keep going."
            UISelectionFeedbackGenerator().selectionChanged()
        }
        if session?.outcome == .won { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        recordFinishedGame()
    }

    func useHint() {
        guard !isPaused else { return }
        tick()
        guard session?.useHint() == true else { return }
        message = ""
        if session?.outcome == .won {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        recordFinishedGame()
    }

    func erase() { guard !isPaused else { return }; tick(); session?.erase() }
    func undo() { guard !isPaused else { return }; tick(); session?.undo(); message = "One step back. A fresh perspective." }
    func toggleNotes() {
        guard !isPaused else { return }
        tick()
        session?.toggleNotes()
        message = session?.isNotesMode == true ? "Pencil in possibilities. No mistakes counted." : ""
    }

    func pause() {
        tick()
        guard session?.outcome == nil, session != nil else { return }
        isPaused = true
        lastTick = nil
    }

    func resume() {
        guard isAppActive, session?.outcome == nil else { return }
        isPaused = false
        lastTick = uptime()
    }

    func setAppActive(_ active: Bool) {
        isAppActive = active
        if !active { pause() }
    }

    func goHome() {
        generation?.cancel()
        generation = nil
        session = nil
        gameID = nil
        completedGame = nil
        isGenerating = false
        isPaused = false
        lastTick = nil
    }

    private func recordFinishedGame() {
        guard completedGame == nil, let session, session.outcome != nil, let gameID else { return }
        completedGame = history.record(id: gameID, session: session, finishedAt: now())
        lastTick = nil
    }

    #if DEBUG && targetEnvironment(simulator)
    func previewResult(_ outcome: GameOutcome) {
        goHome()
        beginGame(puzzle: PreviewPuzzle.testPuzzle(difficulty: .medium))
        session?.advance(by: 267)
        switch outcome {
        case .won:
            for index in 0..<3 {
                session?.select(index)
                session?.enter(PreviewPuzzle.solution[index])
            }
        case .mistakes:
            session?.enter(3)
            session?.enter(4)
            session?.enter(3)
        case .timedOut:
            session?.advance(by: Difficulty.medium.timeLimit)
        }
        recordFinishedGame()
    }
    #endif
}

enum PreviewPuzzle {
    static let solution = [
        5,3,4,6,7,8,9,1,2,
        6,7,2,1,9,5,3,4,8,
        1,9,8,3,4,2,5,6,7,
        8,5,9,7,6,1,4,2,3,
        4,2,6,8,5,3,7,9,1,
        7,1,3,9,2,4,8,5,6,
        9,6,1,5,3,7,2,8,4,
        2,8,7,4,1,9,6,3,5,
        3,4,5,2,8,6,1,7,9
    ]
    // Decorative artwork only. Actual games use the generator.
    static let givens = solution.enumerated().map { index, value in
        [0,1,4,9,12,13,14,19,20,25,27,31,35,36,39,41,44,45,49,53,55,60,61,66,67,68,71,76,79,80].contains(index) ? value : 0
    }
    #if DEBUG
    static func testPuzzle(difficulty: Difficulty) -> SudokuPuzzle {
        var board = solution
        board[0] = 0
        board[1] = 0
        board[2] = 0
        return SudokuPuzzle(givens: board, solution: solution, difficulty: difficulty)
    }
    #endif
}
