#if canImport(UIKit)
import XCTest
@testable import Sudokuly

@MainActor
final class ControlledHistoryRepository: GameHistoryRepository {
    var receiver: (@MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void)?
    var completions: [UUID: @MainActor @Sendable (Result<Void, Error>) -> Void] = [:]
    var writes: [GameRecord] = []
    var cancellations = 0
    func observe(ownerID: String, receive: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) -> GameHistoryObservation {
        receiver = receive
        return GameHistoryObservation { [weak self] in self?.cancellations += 1; self?.receiver = nil }
    }
    func save(_ record: GameRecord, completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) {
        writes.append(record); completions[record.id] = completion
    }
    func loadMore(completion: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) {
        completion(.failure(HistoryCloudError.noConnection))
    }
}

@MainActor
final class GameHistorySyncTests: XCTestCase {
    private func completedSession() -> GameSession {
        var givens = PreviewPuzzle.solution; givens[0] = 0
        var session = GameSession(puzzle: SudokuPuzzle(givens: givens, solution: PreviewPuzzle.solution, difficulty: .easy))
        session.advance(by: 42.5); session.enter(5)
        return session
    }
    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testOutboxKeepsTheSameGameAcrossNewStoreAndAnotherUIDCannotLoadIt() throws {
        let directory = try tempDirectory()
        let outbox = GameHistoryOutbox(ownerID: "player-a", directory: directory)
        let repository = ControlledHistoryRepository()
        let id = UUID()
        var store: GameHistoryStore? = GameHistoryStore(ownerID: "player-a", repository: repository, pendingStorage: outbox)
        store?.start()
        let saved = try XCTUnwrap(store?.record(id: id, session: completedSession(), finishedAt: Date()))
        XCTAssertEqual(try outbox.load(), [saved])
        XCTAssertTrue(store!.pendingIDs.contains(id))
        XCTAssertNotEqual(store!.resultMessage(for: id), "Saved to your account")
        store = nil
        XCTAssertEqual(repository.cancellations, 1)
        XCTAssertTrue(try GameHistoryOutbox(ownerID: "player-b", directory: directory).load().isEmpty)
        let retryRepository = ControlledHistoryRepository()
        let restored = GameHistoryStore(ownerID: "player-a", repository: retryRepository, pendingStorage: outbox)
        restored.start()
        XCTAssertEqual(restored.records, [saved])
        XCTAssertEqual(retryRepository.writes, [saved])
        retryRepository.completions[id]?(.success(()))
        XCTAssertEqual(restored.resultMessage(for: id), "Saved to your account")
        XCTAssertTrue(try outbox.load().isEmpty)
    }

    func testFailedWriteStaysQueuedAndRetryUsesTheSameID() throws {
        let outbox = GameHistoryOutbox(ownerID: "player", directory: try tempDirectory())
        let repository = ControlledHistoryRepository()
        let store = GameHistoryStore(ownerID: "player", repository: repository, pendingStorage: outbox)
        store.start()
        let id = UUID()
        _ = store.record(id: id, session: completedSession(), finishedAt: Date())
        repository.completions[id]?(.failure(HistoryCloudError.noConnection))
        XCTAssertNotNil(store.saveError)
        XCTAssertEqual(try outbox.load().count, 1)
        store.retry()
        XCTAssertEqual(repository.writes.map(\.id), [id, id])
        repository.completions[id]?(.success(()))
        XCTAssertNil(store.saveError)
        XCTAssertTrue(store.pendingIDs.isEmpty)
    }

    func testSnapshotAndAcknowledgementRacesCannotDuplicateOrLoseTheResult() throws {
        let repository = ControlledHistoryRepository()
        let store = GameHistoryStore(ownerID: "player", repository: repository)
        store.start()
        let id = UUID()
        let saved = try XCTUnwrap(store.record(id: id, session: completedSession(), finishedAt: Date()))
        repository.receiver?(.success(GameHistorySnapshot(records: [], isFromCache: true, hasMore: false)))
        XCTAssertEqual(store.records, [saved])
        repository.completions[id]?(.success(()))
        repository.receiver?(.success(GameHistorySnapshot(records: [saved], isFromCache: false, hasMore: false)))
        XCTAssertEqual(store.records, [saved])
    }

    func testReadErrorsAreDistinctFromAnEmptyHistoryAndRetryDoesNotDuplicateListeners() {
        let repository = ControlledHistoryRepository()
        let store = GameHistoryStore(ownerID: "player", repository: repository)
        XCTAssertTrue(store.isLoading)
        store.start(); store.start()
        repository.receiver?(.failure(HistoryCloudError.noConnection))
        XCTAssertFalse(store.isLoading)
        XCTAssertNotNil(store.readError)
        store.retry()
        XCTAssertEqual(repository.cancellations, 1)
        repository.receiver?(.success(GameHistorySnapshot(records: [], isFromCache: false, hasMore: false)))
        XCTAssertNil(store.readError)
        XCTAssertFalse(store.isFromCache)
    }

    func testCodecRejectsOtherOwnerAndInconsistentTerminalData() throws {
        let game = try XCTUnwrap(GameRecord(id: UUID(), ownerID: "player", session: completedSession(), finishedAt: Date()))
        let data = FirestoreGameHistoryRepository.encode(game)
        let decoded = try FirestoreGameHistoryRepository.decode(game.id.uuidString, data: data, ownerID: "player")
        XCTAssertEqual(decoded.id, game.id)
        XCTAssertEqual(decoded.duration, game.duration)
        XCTAssertThrowsError(try FirestoreGameHistoryRepository.decode(game.id.uuidString, data: data, ownerID: "another"))
        var invalid = data; invalid["outcome"] = "timedOut"
        XCTAssertThrowsError(try FirestoreGameHistoryRepository.decode(game.id.uuidString, data: invalid, ownerID: "player"))
    }

    func testAnotherWriteAcknowledgementCannotHideAFailedPendingGame() throws {
        let outbox = GameHistoryOutbox(ownerID: "multi", directory: try tempDirectory())
        let repository = ControlledHistoryRepository()
        let store = GameHistoryStore(ownerID: "multi", repository: repository, pendingStorage: outbox)
        store.start()
        let failed = UUID(), successful = UUID()
        _ = store.record(id: failed, session: completedSession(), finishedAt: Date())
        _ = store.record(id: successful, session: completedSession(), finishedAt: Date())
        repository.completions[failed]?(.failure(HistoryCloudError.noConnection))
        repository.completions[successful]?(.success(()))
        XCTAssertEqual(store.pendingIDs, [failed])
        XCTAssertNotNil(store.saveError, "An unrelated acknowledgement must not hide the pending failure")
        XCTAssertEqual(try outbox.load().map(\.id), [failed])
        store.retry()
        repository.completions[failed]?(.success(()))
        XCTAssertNil(store.saveError)
        XCTAssertTrue(try outbox.load().isEmpty)
    }

    func testOutboxFailureNeverClaimsAServerOrDeviceSaveAndCanRecover() throws {
        final class Storage: GameHistoryPendingStorage {
            var fails = true
            var records: [GameRecord] = []
            func load() throws -> [GameRecord] { records }
            func replace(_ records: [GameRecord]) throws {
                if fails { throw CocoaError(.fileWriteOutOfSpace) }
                self.records = records
            }
        }
        let storage = Storage(), repository = ControlledHistoryRepository()
        let store = GameHistoryStore(ownerID: "disk", repository: repository, pendingStorage: storage)
        store.start()
        let id = UUID()
        _ = store.record(id: id, session: completedSession(), finishedAt: Date())
        XCTAssertNotNil(store.saveError)
        XCTAssertEqual(store.resultMessage(for: id), "Couldn’t confirm saving. Please retry.")
        storage.fails = false
        store.retry()
        XCTAssertEqual(storage.records.map(\.id), [id])
        repository.completions[id]?(.success(()))
        XCTAssertEqual(store.resultMessage(for: id), "Saved to your account")
        XCTAssertTrue(storage.records.isEmpty)
    }

    func testAcknowledgedQueueCleanupFailureCanBeRetriedWithoutReuploading() throws {
        final class Storage: GameHistoryPendingStorage {
            var records: [GameRecord] = []
            var failsRemoval = true
            func load() throws -> [GameRecord] { records }
            func replace(_ records: [GameRecord]) throws {
                if records.isEmpty && failsRemoval { throw CocoaError(.fileWriteNoPermission) }
                self.records = records
            }
        }
        let storage = Storage(), repository = ControlledHistoryRepository()
        let store = GameHistoryStore(ownerID: "cleanup", repository: repository, pendingStorage: storage)
        store.start()
        let id = UUID()
        _ = store.record(id: id, session: completedSession(), finishedAt: Date())
        repository.completions[id]?(.success(()))
        XCTAssertTrue(store.pendingIDs.isEmpty)
        XCTAssertNotNil(store.saveError)
        storage.failsRemoval = false
        store.retry()
        XCTAssertTrue(storage.records.isEmpty)
        XCTAssertNil(store.saveError)
        XCTAssertEqual(repository.writes.count, 1)
    }
}
#endif
