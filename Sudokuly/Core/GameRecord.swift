import Foundation

/// A finished game's summary. No puzzle, solution or resumable progress is retained.
struct GameRecord: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let ownerID: String
    let finishedAt: Date
    let difficulty: Difficulty
    let outcome: GameOutcome
    let duration: TimeInterval
    let mistakes: Int

    init(id: UUID = UUID(), ownerID: String, finishedAt: Date, difficulty: Difficulty,
         outcome: GameOutcome, duration: TimeInterval, mistakes: Int) {
        self.id = id
        self.ownerID = ownerID
        self.finishedAt = finishedAt
        self.difficulty = difficulty
        self.outcome = outcome
        self.duration = duration
        self.mistakes = mistakes
    }

    init?(id: UUID, ownerID: String, session: GameSession, finishedAt: Date) {
        guard let outcome = session.outcome else { return nil }
        self.init(id: id, ownerID: ownerID, finishedAt: finishedAt,
                  difficulty: session.puzzle.difficulty, outcome: outcome,
                  duration: session.elapsed, mistakes: session.mistakes)
    }
}
