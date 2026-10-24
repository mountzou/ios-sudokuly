import Foundation

struct GameHistorySnapshot: Sendable {
    let records: [GameRecord]
    let isFromCache: Bool
    let hasMore: Bool
}

@MainActor
final class GameHistoryObservation {
    private var cancellation: (() -> Void)?
    init(cancel: @escaping () -> Void) { cancellation = cancel }
    func cancel() { cancellation?(); cancellation = nil }
}

@MainActor
protocol GameHistoryRepository: AnyObject {
    func observe(ownerID: String, receive: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) -> GameHistoryObservation
    func save(_ record: GameRecord, completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void)
    func loadMore(completion: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void)
}

/// Fetch a visible calendar range independently of the latest-history page.
@MainActor
protocol GameActivityRepository: AnyObject {
    func loadActivity(ownerID: String, interval: DateInterval,
                      receive: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) -> GameHistoryObservation
}

protocol GameHistoryPendingStorage {
    func load() throws -> [GameRecord]
    func replace(_ records: [GameRecord]) throws
}
