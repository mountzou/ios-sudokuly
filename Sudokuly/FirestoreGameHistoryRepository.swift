import Foundation
import FirebaseAuth
import FirebaseFirestore

enum HistoryCloudError: Error {
    case accountChanged, invalidRecord, noConnection
}

@MainActor
final class FirestoreGameHistoryRepository: GameHistoryRepository, GameActivityRepository {
    static let databaseID = "history"
    private let injectedDatabase: Firestore?
    private let injectedAuth: Auth?
    private lazy var database = injectedDatabase ?? Firestore.firestore(database: Self.databaseID)
    private var authentication: Auth { injectedAuth ?? Auth.auth() }
    private let pageSize: Int
    private var listener: ListenerRegistration?
    private var receiver: (@MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void)?
    private var ownerID: String?
    private var latestRecords: [GameRecord] = []
    private var olderRecords: [GameRecord] = []
    private var cursor: QueryDocumentSnapshot?
    private var hasLoadedOlder = false
    private var hasMore = false
    private var generation = UUID()

    init(database: Firestore? = nil, authentication: Auth? = nil, pageSize: Int = 100) {
        injectedDatabase = database
        injectedAuth = authentication
        self.pageSize = min(100, max(1, pageSize))
    }

    isolated deinit { listener?.remove() }

    func observe(ownerID: String, receive: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) -> GameHistoryObservation {
        listener?.remove()
        let generation = UUID()
        self.generation = generation
        self.ownerID = ownerID
        receiver = receive
        latestRecords = []; olderRecords = []; cursor = nil; hasLoadedOlder = false; hasMore = false
        guard authentication.currentUser?.uid == ownerID else {
            receive(.failure(HistoryCloudError.accountChanged))
            return GameHistoryObservation(cancel: {})
        }
        let pageSize = self.pageSize
        listener = query(ownerID).limit(to: pageSize).addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            let result: Result<GameHistorySnapshot, Error>
            if let error { result = .failure(error) }
            else if let snapshot {
                do {
                    let records = try snapshot.documents.map { try Self.decode($0.documentID, data: $0.data(), ownerID: ownerID) }
                    result = .success(GameHistorySnapshot(records: records, isFromCache: snapshot.metadata.isFromCache,
                                                         hasMore: records.count == pageSize))
                } catch { result = .failure(error) }
            } else { result = .failure(HistoryCloudError.invalidRecord) }
            let nextCursor = snapshot?.documents.last
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation else { return }
                self.receivedLatest(result, cursor: nextCursor)
            }
        }
        let registration = listener
        return GameHistoryObservation { [weak self] in
            registration?.remove()
            guard self?.generation == generation else { return }
            self?.generation = UUID()
            self?.listener = nil
            self?.receiver = nil
        }
    }

    func save(_ record: GameRecord, completion: @escaping @MainActor @Sendable (Result<Void, Error>) -> Void) {
        guard authentication.currentUser?.uid == record.ownerID else {
            completion(.failure(HistoryCloudError.accountChanged)); return
        }
        // A deterministic document ID and identical-only update rules make retries idempotent.
        database.collection("users").document(record.ownerID).collection("games").document(record.id.uuidString)
            .setData(Self.encode(record)) { error in
                Task { @MainActor in
                    if let error { completion(.failure(error)) } else { completion(.success(())) }
                }
            }
    }

    func loadMore(completion: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) {
        guard let ownerID, authentication.currentUser?.uid == ownerID, let cursor else {
            completion(.failure(HistoryCloudError.accountChanged)); return
        }
        let generation = self.generation
        // Retain the exact server cursor, including nanosecond timestamp precision.
        query(ownerID).start(afterDocument: cursor).limit(to: pageSize)
            .getDocuments(source: .server) { [weak self] snapshot, error in
                let result: Result<[GameRecord], Error>
                if let error { result = .failure(error) }
                else if let snapshot {
                    result = Result { try snapshot.documents.map { try Self.decode($0.documentID, data: $0.data(), ownerID: ownerID) } }
                } else { result = .failure(HistoryCloudError.invalidRecord) }
                let nextCursor = snapshot?.documents.last
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.generation == generation else { completion(.failure(HistoryCloudError.accountChanged)); return }
                    switch result {
                    case .failure(let error): completion(.failure(error))
                    case .success(let records):
                        self.hasLoadedOlder = true
                        self.olderRecords += records
                        self.cursor = nextCursor ?? self.cursor
                        self.hasMore = records.count == self.pageSize
                        completion(.success(GameHistorySnapshot(records: self.latestRecords + self.olderRecords,
                                                               isFromCache: false, hasMore: self.hasMore)))
                    }
                }
            }
    }

    private func query(_ ownerID: String) -> Query {
        database.collection("users").document(ownerID).collection("games")
            .order(by: "finishedAt", descending: true).order(by: FieldPath.documentID(), descending: true)
    }

    @MainActor private final class ActivityRequest {
        var cancelled = false
        var records: [GameRecord] = []
        var isFromCache = false
    }

    func loadActivity(ownerID: String, interval: DateInterval,
                      receive: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) -> GameHistoryObservation {
        let request = ActivityRequest()
        let observation = GameHistoryObservation { request.cancelled = true }
        guard authentication.currentUser?.uid == ownerID else {
            receive(.failure(HistoryCloudError.accountChanged))
            return observation
        }
        // The existing finishedAt / document-ID index supports this bounded range and its cursors.
        let range = query(ownerID)
            .whereField("finishedAt", isGreaterThanOrEqualTo: Timestamp(date: interval.start))
            .whereField("finishedAt", isLessThan: Timestamp(date: interval.end))
        fetchActivityPage(range, ownerID: ownerID, request: request, receive: receive)
        return observation
    }

    private func fetchActivityPage(_ query: Query, ownerID: String, request: ActivityRequest,
                                   receive: @escaping @MainActor @Sendable (Result<GameHistorySnapshot, Error>) -> Void) {
        guard !request.cancelled else { return }
        guard authentication.currentUser?.uid == ownerID else {
            receive(.failure(HistoryCloudError.accountChanged)); return
        }
        let pageSize = self.pageSize
        query.limit(to: pageSize).getDocuments { [weak self] snapshot, error in
            let result: Result<[GameRecord], Error>
            if let error { result = .failure(error) }
            else if let snapshot {
                result = Result { try snapshot.documents.map { try Self.decode($0.documentID, data: $0.data(), ownerID: ownerID) } }
            } else { result = .failure(HistoryCloudError.invalidRecord) }
            let cursor = snapshot?.documents.last
            let fromCache = snapshot?.metadata.isFromCache ?? false
            Task { @MainActor [weak self] in
                guard let self, !request.cancelled else { return }
                guard self.authentication.currentUser?.uid == ownerID else {
                    receive(.failure(HistoryCloudError.accountChanged)); return
                }
                switch result {
                case .failure(let error): receive(.failure(error))
                case .success(let records):
                    request.records += records
                    request.isFromCache = request.isFromCache || fromCache
                    if records.count == pageSize, let cursor {
                        self.fetchActivityPage(query.start(afterDocument: cursor), ownerID: ownerID, request: request, receive: receive)
                    } else {
                        receive(.success(GameHistorySnapshot(records: request.records, isFromCache: request.isFromCache, hasMore: false)))
                    }
                }
            }
        }
    }

    private func receivedLatest(_ result: Result<GameHistorySnapshot, Error>, cursor: QueryDocumentSnapshot?) {
        switch result {
        case .failure(let error): receiver?(.failure(error))
        case .success(let snapshot):
            if hasLoadedOlder {
                // Keep items pushed off the first page by a newly completed game.
                let ids = Set(snapshot.records.map(\.id))
                if let last = snapshot.records.last {
                    olderRecords += latestRecords.filter { !ids.contains($0.id) && $0.finishedAt <= last.finishedAt }
                }
            } else {
                self.cursor = cursor
                hasMore = snapshot.hasMore
            }
            latestRecords = snapshot.records
            receiver?(.success(GameHistorySnapshot(records: latestRecords + olderRecords,
                                                  isFromCache: snapshot.isFromCache, hasMore: hasMore)))
        }
    }

    nonisolated static func encode(_ record: GameRecord) -> [String: Any] {
        ["schemaVersion": 1, "gameID": record.id.uuidString, "ownerID": record.ownerID,
         "finishedAt": Timestamp(date: record.finishedAt), "difficulty": record.difficulty.rawValue,
         "outcome": record.outcome.rawValue, "duration": record.duration, "mistakes": record.mistakes]
    }

    nonisolated static func decode(_ id: String, data: [String: Any], ownerID: String) throws -> GameRecord {
        guard let uuid = UUID(uuidString: id), data["gameID"] as? String == id, data["ownerID"] as? String == ownerID,
              data["schemaVersion"] as? Int == 1, let timestamp = data["finishedAt"] as? Timestamp,
              let level = data["difficulty"] as? String, let difficulty = Difficulty(rawValue: level),
              let result = data["outcome"] as? String, let outcome = GameOutcome(rawValue: result),
              let duration = data["duration"] as? Double, duration.isFinite, duration >= 0, duration <= difficulty.timeLimit,
              let mistakes = data["mistakes"] as? Int, (0...3).contains(mistakes),
              (outcome == .mistakes ? mistakes == 3 : mistakes < 3),
              outcome != .timedOut || duration == difficulty.timeLimit else { throw HistoryCloudError.invalidRecord }
        return GameRecord(id: uuid, ownerID: ownerID, finishedAt: timestamp.dateValue(), difficulty: difficulty,
                          outcome: outcome, duration: duration, mistakes: mistakes)
    }

    /// Called while the account is freshly reauthenticated, before deleting its Firebase identity.
    func deleteAccountHistory(ownerID: String) async throws {
        guard authentication.currentUser?.uid == ownerID else { throw HistoryCloudError.accountChanged }
        try await database.waitForPendingWrites()
        let games = database.collection("users").document(ownerID).collection("games")
        while true {
            guard authentication.currentUser?.uid == ownerID else { throw HistoryCloudError.accountChanged }
            let page = try await games.limit(to: 400).getDocuments(source: .server)
            if page.isEmpty { break }
            let batch = database.batch()
            for document in page.documents { batch.deleteDocument(document.reference) }
            try await batch.commit()
        }
    }
}
