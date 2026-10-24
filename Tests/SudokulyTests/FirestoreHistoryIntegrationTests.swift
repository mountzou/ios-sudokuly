#if canImport(UIKit)
import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
@testable import Sudokuly

/// Real Firebase client SDKs against the local demo project's emulators.
@MainActor
final class FirestoreHistoryIntegrationTests: XCTestCase {
    private func requireEmulators() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SUDOKULY_FIREBASE_EMULATORS"] == "1",
                          "Run the Sudokuly Firebase Tests scheme with the local emulators running.")
    }
    private struct Client {
        let app: FirebaseApp
        let auth: Auth
        let database: Firestore
    }
    private func client() -> Client {
        let options = FirebaseOptions(googleAppID: "1:123456789012:ios:1234567890123456789012", gcmSenderID: "123456789012")
        options.apiKey = "AIzaSySudokulyEmulatorOnlyKey000000000000"
        options.projectID = "demo-sudokuly"
        let name = "history-tests-" + UUID().uuidString
        FirebaseApp.configure(name: name, options: options)
        let app = FirebaseApp.app(name: name)!
        let auth = Auth.auth(app: app)
        auth.useEmulator(withHost: "127.0.0.1", port: 9099)
        let database = Firestore.firestore(app: app)
        let settings = database.settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        database.settings = settings
        return Client(app: app, auth: auth, database: database)
    }
    private func signIn(_ uid: String, client: Client) async throws {
        func base64(_ value: [String: Any]) throws -> String {
            try JSONSerialization.data(withJSONObject: value).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let now = Int(Date().timeIntervalSince1970)
        let header = try base64(["alg": "none", "typ": "JWT"])
        let payload = try base64(["aud": "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit",
                                 "iss": "test@demo-sudokuly.iam.gserviceaccount.com", "sub": "test@demo-sudokuly.iam.gserviceaccount.com",
                                 "uid": uid, "iat": now, "exp": now + 3600])
        _ = try await client.auth.signIn(withCustomToken: header + "." + payload + ".")
    }
    private func close(_ client: Client) async throws {
        try client.auth.signOut()
        try await client.database.terminate()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            client.app.delete { _ in continuation.resume() }
        }
    }
    private func waitUntil(_ predicate: () -> Bool, timeout: TimeInterval = 10) async throws {
        let end = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < end { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(predicate(), "Emulator state did not arrive")
    }
    private func save(_ record: GameRecord, repository: FirestoreGameHistoryRepository) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            repository.save(record) { result in continuation.resume(with: result) }
        }
    }
    private func session() -> GameSession {
        var board = PreviewPuzzle.solution; board[0] = 0
        var game = GameSession(puzzle: SudokuPuzzle(givens: board, solution: PreviewPuzzle.solution, difficulty: .easy))
        game.advance(by: 32); game.enter(5)
        return game
    }

    func testCalendarRangeLoadsEveryPageBeyondRecentHistoryAndExcludesBoundaryDays() async throws {
        try requireEmulators()
        let uid = "sdk-calendar-" + UUID().uuidString, client = client()
        try await signIn(uid, client: client)
        let repository = FirestoreGameHistoryRepository(database: client.database, authentication: client.auth, pageSize: 2)
        let start = ISO8601DateFormatter().date(from: "2026-01-05T00:00:00Z")!
        let interval = DateInterval(start: start, end: start.addingTimeInterval(7 * 86400))
        for index in -1...5 {
            let date = index == 5 ? interval.end : start.addingTimeInterval(Double(index + 1) * 3600 - 1)
            try await save(GameRecord(ownerID: uid, finishedAt: date, difficulty: .easy, outcome: .won,
                                      duration: 42, mistakes: 0), repository: repository)
        }
        for offset in 1...2 {
            try await save(GameRecord(ownerID: uid, finishedAt: Date().addingTimeInterval(-Double(offset) * 60),
                                      difficulty: .easy, outcome: .mistakes, duration: 42, mistakes: 3), repository: repository)
        }
        let store = GameHistoryStore(ownerID: uid, repository: repository)
        store.start()
        try await waitUntil { store.records.count == 2 && !store.isFromCache }
        XCTAssertTrue(store.records.allSatisfy { $0.outcome == .mistakes })
        store.loadActivity(interval: interval)
        try await waitUntil { !store.isLoadingActivity }
        XCTAssertNil(store.activityError)
        XCTAssertFalse(store.isActivityFromCache)
        XCTAssertEqual(store.activityRecords.count, 5)
        XCTAssertTrue(store.activityRecords.allSatisfy { $0.finishedAt >= interval.start && $0.finishedAt < interval.end })
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(store.solvedDays(calendar: calendar), [start])
        try await close(client)
    }

    func testBackendHistorySurvivesSignOutAndAFreshClientAndRejectsAnotherOwner() async throws {
        try requireEmulators()
        let uid = "sdk-a-" + UUID().uuidString, other = "sdk-b-" + UUID().uuidString
        let first = client()
        try await signIn(uid, client: first)
        let repository = FirestoreGameHistoryRepository(database: first.database, authentication: first.auth)
        let game = GameRecord(ownerID: uid, finishedAt: Date(), difficulty: .easy, outcome: .won, duration: 42, mistakes: 0)
        try await save(game, repository: repository)
        try await save(game, repository: repository)
        try first.auth.signOut()
        try await signIn(other, client: first)
        do {
            _ = try await first.database.collection("users").document(uid).collection("games").document(game.id.uuidString).getDocument(source: .server)
            XCTFail("Another account read private history")
        } catch { XCTAssertEqual((error as NSError).code, FirestoreErrorCode.permissionDenied.rawValue) }
        let otherGames = try await first.database.collection("users").document(other).collection("games").limit(to: 100).getDocuments(source: .server)
        XCTAssertTrue(otherGames.isEmpty)
        try await close(first)
        let fresh = client()
        try await signIn(uid, client: fresh)
        let store = GameHistoryStore(ownerID: uid, repository: FirestoreGameHistoryRepository(database: fresh.database, authentication: fresh.auth))
        store.start()
        try await waitUntil { !store.isFromCache && store.records.count == 1 }
        XCTAssertEqual(store.records.first?.id, game.id)
        XCTAssertEqual(store.records.first?.duration, 42)
        try await close(fresh)
    }

    func testOfflineOutboxSurvivesARecreatedClientAndUploadsOnlyOneGame() async throws {
        try requireEmulators()
        let uid = "sdk-offline-" + UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let outbox = GameHistoryOutbox(ownerID: uid, directory: directory)
        let first = client()
        try await signIn(uid, client: first)
        try await first.database.disableNetwork()
        var store: GameHistoryStore? = GameHistoryStore(ownerID: uid,
            repository: FirestoreGameHistoryRepository(database: first.database, authentication: first.auth), pendingStorage: outbox)
        store?.start()
        let id = UUID()
        _ = store?.record(id: id, session: session(), finishedAt: Date())
        XCTAssertEqual(try outbox.load().map(\.id), [id])
        store = nil
        try await close(first)
        let fresh = client()
        try await signIn(uid, client: fresh)
        let restored = GameHistoryStore(ownerID: uid,
            repository: FirestoreGameHistoryRepository(database: fresh.database, authentication: fresh.auth), pendingStorage: outbox)
        restored.start()
        try await waitUntil { restored.pendingIDs.isEmpty && !restored.isFromCache && restored.records.count == 1 }
        XCTAssertTrue(try outbox.load().isEmpty)
        let page = try await fresh.database.collection("users").document(uid).collection("games").limit(to: 100).getDocuments(source: .server)
        XCTAssertEqual(page.documents.map(\.documentID), [id.uuidString])
        try await close(fresh)
    }

    func testCursorPaginationWithTiedDatesAndAccountHistoryErasure() async throws {
        try requireEmulators()
        let uid = "sdk-pages-" + UUID().uuidString
        let client = client()
        try await signIn(uid, client: client)
        let repository = FirestoreGameHistoryRepository(database: client.database, authentication: client.auth, pageSize: 2)
        let date = Date()
        for index in 1...5 {
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
            var data = FirestoreGameHistoryRepository.encode(GameRecord(id: id, ownerID: uid, finishedAt: date,
                difficulty: .easy, outcome: .won, duration: 42, mistakes: 0))
            // Deliberately finer than Date's precision: exact server cursors must retain every row.
            data["finishedAt"] = Timestamp(seconds: Int64(date.timeIntervalSince1970), nanoseconds: Int32((index + 1) / 2))
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                client.database.collection("users").document(uid).collection("games").document(id.uuidString).setData(data) { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        }
        let store = GameHistoryStore(ownerID: uid, repository: repository)
        store.start()
        try await waitUntil { !store.isFromCache && store.records.count == 2 }
        XCTAssertTrue(store.hasMore)
        store.loadMore()
        try await waitUntil { store.records.count == 4 }
        store.loadMore()
        try await waitUntil { store.records.count == 5 }
        XCTAssertFalse(store.hasMore)
        XCTAssertEqual(store.records.map(\.id.uuidString), store.records.map(\.id.uuidString).sorted(by: >))
        let newID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        try await save(GameRecord(id: newID, ownerID: uid, finishedAt: date, difficulty: .easy, outcome: .won, duration: 30, mistakes: 0), repository: repository)
        try await waitUntil { store.records.count == 6 }
        XCTAssertEqual(Set(store.records.map(\.id)).count, 6)
        try await repository.deleteAccountHistory(ownerID: uid)
        let empty = try await client.database.collection("users").document(uid).collection("games").limit(to: 400).getDocuments(source: .server)
        XCTAssertTrue(empty.isEmpty)
        try await close(client)
    }

    func test140GeneratedGamesThroughEngineAndBackendAcrossAllLevelsAndOutcomes() async throws {
        try requireEmulators()
        let uid = "sdk-matrix-" + UUID().uuidString
        let first = client()
        try await signIn(uid, client: first)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        var store: GameHistoryStore? = GameHistoryStore(ownerID: uid,
            repository: FirestoreGameHistoryRepository(database: first.database, authentication: first.auth),
            pendingStorage: GameHistoryOutbox(ownerID: uid, directory: directory))
        store!.start()
        var clock: TimeInterval = 100
        var model: GameViewModel? = GameViewModel(history: store!, uptime: { clock })
        var expected: [UUID: GameRecord] = [:]
        let variants: [(GameOutcome, Int)] = [(.won, 0), (.won, 1), (.won, 2), (.mistakes, 3),
                                               (.timedOut, 0), (.timedOut, 1), (.timedOut, 2)]
        for repetition in 0..<5 {
            for level in Difficulty.allCases {
                for (variant, mistakes) in variants {
                    let puzzle = SudokuGenerator.generate(difficulty: level,
                        seed: UInt64(1000 + repetition * 100 + level.rank * 10 + expected.count))
                    model!.beginGame(puzzle: puzzle)
                    clock += 45
                    let firstBlank = try XCTUnwrap(model!.session?.selected)
                    for _ in 0..<mistakes {
                        model!.enter(puzzle.solution[firstBlank] % 9 + 1); model!.erase()
                    }
                    if variant == .won {
                        for index in puzzle.givens.indices where puzzle.givens[index] == 0 {
                            model!.select(index); model!.enter(puzzle.solution[index])
                        }
                    } else if variant == .timedOut { clock += level.timeLimit - 45; model!.tick() }
                    let record = try XCTUnwrap(model!.completedGame)
                    XCTAssertEqual(record.outcome, variant)
                    XCTAssertEqual(record.difficulty, level)
                    XCTAssertEqual(record.mistakes, mistakes)
                    XCTAssertEqual(record.duration, variant == .timedOut ? level.timeLimit : 45)
                    expected[record.id] = record
                    model!.tick(); model!.enter(1); model!.goHome()
                }
            }
        }
        try await waitUntil({ store!.pendingIDs.isEmpty && store!.saveError == nil }, timeout: 30)
        XCTAssertEqual(store!.records.count, 140)
        let server = try await first.database.collection("users").document(uid).collection("games").limit(to: 400).getDocuments(source: .server)
        XCTAssertEqual(server.count, 140)
        for document in server.documents {
            let record = try FirestoreGameHistoryRepository.decode(document.documentID, data: document.data(), ownerID: uid)
            let wanted = try XCTUnwrap(expected[record.id])
            XCTAssertEqual(record.outcome, wanted.outcome)
            XCTAssertEqual(record.difficulty, wanted.difficulty)
            XCTAssertEqual(record.mistakes, wanted.mistakes)
            XCTAssertEqual(record.duration, wanted.duration)
            XCTAssertEqual(record.finishedAt.timeIntervalSince1970, wanted.finishedAt.timeIntervalSince1970, accuracy: 0.000001)
        }
        model = nil; store = nil
        try await close(first)
        let fresh = client()
        try await signIn(uid, client: fresh)
        let restored = GameHistoryStore(ownerID: uid,
            repository: FirestoreGameHistoryRepository(database: fresh.database, authentication: fresh.auth))
        restored.start()
        try await waitUntil { !restored.isFromCache && restored.records.count == 100 }
        restored.loadMore()
        try await waitUntil { restored.records.count == 140 && !restored.isLoadingMore }
        XCTAssertFalse(restored.hasMore)
        XCTAssertEqual(Set(restored.records.map(\.id)), Set(expected.keys))
        for level in Difficulty.allCases {
            let games = restored.records.filter { $0.difficulty == level }
            XCTAssertEqual(games.filter { $0.outcome == .won }.count, 15)
            XCTAssertEqual(games.filter { $0.outcome == .mistakes }.count, 5)
            XCTAssertEqual(games.filter { $0.outcome == .timedOut }.count, 15)
        }
        try await close(fresh)
    }

    func testTwoWinsAndOneLossQueuedOfflineSurviveSignOutAndAnotherUser() async throws {
        try requireEmulators()
        let uid = "sdk-three-" + UUID().uuidString, other = "sdk-three-other-" + UUID().uuidString
        let first = client()
        try await signIn(uid, client: first)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let outbox = GameHistoryOutbox(ownerID: uid, directory: directory)
        try await first.database.disableNetwork()
        var store: GameHistoryStore? = GameHistoryStore(ownerID: uid,
            repository: FirestoreGameHistoryRepository(database: first.database, authentication: first.auth), pendingStorage: outbox)
        store!.start()
        var model: GameViewModel? = GameViewModel(history: store!)
        for level in [Difficulty.easy, .hard, .expert] {
            var board = PreviewPuzzle.solution; board[0] = 0
            model!.beginGame(puzzle: SudokuPuzzle(givens: board, solution: PreviewPuzzle.solution, difficulty: level))
            if level == .expert { model!.enter(3); model!.enter(4); model!.enter(3) } else { model!.enter(5) }
            model!.goHome()
        }
        let expectedIDs = Set(store!.records.map(\.id))
        XCTAssertEqual(try outbox.load().count, 3)
        model = nil; store = nil
        try first.auth.signOut()
        try await signIn(other, client: first)
        XCTAssertTrue(try GameHistoryOutbox(ownerID: other, directory: directory).load().isEmpty)
        try await first.database.enableNetwork()
        let otherStore = GameHistoryStore(ownerID: other,
            repository: FirestoreGameHistoryRepository(database: first.database, authentication: first.auth))
        otherStore.start()
        try await waitUntil { !otherStore.isLoading && !otherStore.isFromCache }
        XCTAssertTrue(otherStore.records.isEmpty)
        try await close(first)
        let fresh = client()
        try await signIn(uid, client: fresh)
        let restored = GameHistoryStore(ownerID: uid,
            repository: FirestoreGameHistoryRepository(database: fresh.database, authentication: fresh.auth), pendingStorage: outbox)
        restored.start()
        try await waitUntil { restored.pendingIDs.isEmpty && restored.records.count == 3 && !restored.isFromCache }
        XCTAssertEqual(Set(restored.records.map(\.id)), expectedIDs)
        XCTAssertEqual(restored.records.filter { $0.outcome == .won }.count, 2)
        XCTAssertEqual(restored.records.filter { $0.outcome == .mistakes }.count, 1)
        XCTAssertTrue(try outbox.load().isEmpty)
        let server = try await fresh.database.collection("users").document(uid).collection("games").limit(to: 100).getDocuments(source: .server)
        XCTAssertEqual(server.count, 3)
        try await close(fresh)
    }

    func testCancellingAnOldObserverCannotStopTheNewUserFeed() async throws {
        try requireEmulators()
        let a = "sdk-observe-a-" + UUID().uuidString, b = "sdk-observe-b-" + UUID().uuidString
        let client = client()
        try await signIn(a, client: client)
        let repository = FirestoreGameHistoryRepository(database: client.database, authentication: client.auth)
        let old = repository.observe(ownerID: a) { _ in }
        try await signIn(b, client: client)
        var seen = Set<UUID>()
        let current = repository.observe(ownerID: b) { result in
            if case .success(let snapshot) = result { seen.formUnion(snapshot.records.map(\.id)) }
        }
        old.cancel()
        let record = GameRecord(ownerID: b, finishedAt: Date(), difficulty: .easy, outcome: .won, duration: 42, mistakes: 0)
        try await save(record, repository: repository)
        try await waitUntil { seen.contains(record.id) }
        current.cancel()
        try await close(client)
    }

    func testDeleting405GamesUsesMultipleBatchesAndPreservesAnotherUID() async throws {
        try requireEmulators()
        let a = "sdk-delete-a-" + UUID().uuidString, b = "sdk-delete-b-" + UUID().uuidString
        let client = client()
        try await signIn(b, client: client)
        let repository = FirestoreGameHistoryRepository(database: client.database, authentication: client.auth)
        let other = GameRecord(ownerID: b, finishedAt: Date(), difficulty: .easy, outcome: .won, duration: 10, mistakes: 0)
        try await save(other, repository: repository)
        try await signIn(a, client: client)
        for start in stride(from: 0, to: 405, by: 400) {
            let batch = client.database.batch()
            for _ in start..<min(start + 400, 405) {
                let record = GameRecord(ownerID: a, finishedAt: Date(), difficulty: .easy, outcome: .won, duration: 10, mistakes: 0)
                batch.setData(FirestoreGameHistoryRepository.encode(record), forDocument:
                    client.database.collection("users").document(a).collection("games").document(record.id.uuidString))
            }
            try await batch.commit()
        }
        try await repository.deleteAccountHistory(ownerID: a)
        let remaining = try await client.database.collection("users").document(a).collection("games").limit(to: 400).getDocuments(source: .server)
        XCTAssertTrue(remaining.isEmpty)
        try await signIn(b, client: client)
        let untouched = try await client.database.collection("users").document(b).collection("games").document(other.id.uuidString).getDocument(source: .server)
        XCTAssertTrue(untouched.exists)
        do { try await repository.deleteAccountHistory(ownerID: a); XCTFail("Deleted another UID's history") }
        catch { XCTAssertTrue(error is HistoryCloudError) }
        try await close(client)
    }
}
#endif
