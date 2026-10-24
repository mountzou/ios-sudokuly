import SwiftUI

/// One account's visible history. Cloud records and its durable pending queue survive the view.
@MainActor
final class GameHistoryStore: ObservableObject {
    let ownerID: String
    @Published private(set) var records: [GameRecord]
    @Published private(set) var isLoading: Bool
    @Published private(set) var isFromCache = false
    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var readError: String?
    @Published private(set) var saveError: String?
    @Published private(set) var pendingIDs = Set<UUID>()
    @Published private(set) var activityRecords: [GameRecord] = []
    @Published private(set) var isLoadingActivity = false
    @Published private(set) var isActivityFromCache = false
    @Published private(set) var activityError: String?
    private var activityObservation: GameHistoryObservation?
    private var activityGeneration = UUID()
    private var activityInterval: DateInterval?
    private var activityCache = ActivityRangeCache()
    private let activityNow: () -> Date
    private let repository: GameHistoryRepository?
    private let pendingStorage: GameHistoryPendingStorage?
    private var observation: GameHistoryObservation?
    private var localRecords: [UUID: GameRecord] = [:]
    private var inFlight = Set<UUID>()
    private var durableIDs = Set<UUID>()
    private var failedWrites = Set<UUID>()
    private var storageError: String?

    var isCloud: Bool { repository != nil }

    init(ownerID: String, records: [GameRecord] = [], repository: GameHistoryRepository? = nil,
         pendingStorage: GameHistoryPendingStorage? = nil, activityNow: @escaping () -> Date = Date.init) {
        self.ownerID = ownerID
        self.activityNow = activityNow
        self.repository = repository
        self.pendingStorage = pendingStorage
        isLoading = repository != nil
        self.records = Self.normalized(records, ownerID: ownerID)
        do {
            let pending = try pendingStorage?.load() ?? []
            for record in Self.normalized(pending, ownerID: ownerID) {
                localRecords[record.id] = record
                pendingIDs.insert(record.id)
                durableIDs.insert(record.id)
            }
            self.records = Self.normalized(self.records + Array(localRecords.values), ownerID: ownerID)
        } catch { storageError = "Some unsynced results could not be restored on this device."; updateSaveError() }
    }

    isolated deinit { observation?.cancel(); activityObservation?.cancel() }

    func loadActivityAfterIdle(interval: DateInterval) async {
        do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
        guard !Task.isCancelled else { return }
        loadActivity(interval: interval)
    }

    func cancelActivityLoad() {
        activityObservation?.cancel()
        activityObservation = nil
        activityGeneration = UUID()
        isLoadingActivity = false
    }

    /// On foreground/retry, keep known checks visible while refreshing their coverage.
    func invalidateActivityCache() {
        cancelActivityLoad()
        activityCache.invalidate()
    }

    func loadActivity(interval: DateInterval) {
        guard interval.duration > 0 else { return }
        if activityInterval == interval && isLoadingActivity { return }
        cancelActivityLoad()
        activityInterval = interval
        activityError = nil
        let cached = activityCache.lookup(interval, now: activityNow())
        activityRecords = Self.normalized(cached.records, ownerID: ownerID)
        isActivityFromCache = cached.isFromCache
        guard let repository = repository as? GameActivityRepository else {
            return
        }
        guard !cached.missing.isEmpty else { return }
        isLoadingActivity = true
        fetchActivity(cached.missing[...], visibleInterval: interval, generation: activityGeneration, repository: repository)
    }

    private func fetchActivity(_ missing: ArraySlice<DateInterval>, visibleInterval: DateInterval,
                               generation: UUID, repository: GameActivityRepository) {
        guard let interval = missing.first else {
            isLoadingActivity = false
            activityObservation = nil
            return
        }
        activityObservation = repository.loadActivity(ownerID: ownerID, interval: interval) { [weak self] result in
            guard let self, self.activityGeneration == generation else { return }
            switch result {
            case .success(let snapshot):
                self.activityCache.insert(Self.normalized(snapshot.records, ownerID: self.ownerID), interval: interval,
                                          isFromCache: snapshot.isFromCache, now: self.activityNow())
                let cached = self.activityCache.lookup(visibleInterval, now: self.activityNow())
                self.activityRecords = Self.normalized(cached.records, ownerID: self.ownerID)
                self.isActivityFromCache = cached.isFromCache
                self.fetchActivity(missing.dropFirst(), visibleInterval: visibleInterval,
                                   generation: generation, repository: repository)
            case .failure:
                self.isLoadingActivity = false
                self.activityObservation = nil
                self.activityError = "Your activity couldn’t be loaded."
            }
        }
    }

    func solvedDays(calendar: Calendar) -> Set<Date> {
        // Newly finished and offline-queued wins appear immediately, before cloud acknowledgement.
        DailyActivity.solvedDays(in: records + activityRecords, ownerID: ownerID, calendar: calendar)
    }

    func start() {
        guard let repository, observation == nil else { return }
        isLoading = true
        readError = nil
        observation = repository.observe(ownerID: ownerID) { [weak self] result in self?.receive(result) }
        retryWrites()
    }

    func retry() {
        if readError != nil || isFromCache {
            observation?.cancel()
            observation = nil
            start()
        }
        if !pendingIDs.isEmpty || storageError != nil { persistPending() }
        retryWrites()
    }

    func loadMore() {
        guard hasMore, !isLoadingMore, let repository else { return }
        isLoadingMore = true
        repository.loadMore { [weak self] result in
            self?.isLoadingMore = false
            self?.receive(result)
        }
    }

    func resultMessage(for id: UUID) -> String {
        if !isCloud { return "Added to your history" }
        if pendingIDs.contains(id) {
            if saveError != nil {
                return durableIDs.contains(id) ? "Kept on this device. Waiting to sync." : "Couldn’t confirm saving. Please retry."
            }
            return isFromCache ? "Saved on this device. Waiting to sync." : "Saving to your account…"
        }
        return "Saved to your account"
    }

    @discardableResult
    func record(id: UUID, session: GameSession, finishedAt: Date) -> GameRecord? {
        guard session.outcome != nil else { return nil }
        if let existing = records.first(where: { $0.id == id }) { return existing }
        guard let record = GameRecord(id: id, ownerID: ownerID, session: session, finishedAt: finishedAt) else { return nil }
        localRecords[id] = record
        records = Self.normalized(records + [record], ownerID: ownerID)
        if isCloud {
            pendingIDs.insert(id)
            persistPending()
            send(record)
        }
        return record
    }

    private func receive(_ result: Result<GameHistorySnapshot, Error>) {
        isLoading = false
        switch result {
        case .failure:
            readError = "Your history couldn’t be loaded. Please try again."
        case .success(let snapshot):
            records = Self.normalized(snapshot.records + Array(localRecords.values), ownerID: ownerID)
            isFromCache = snapshot.isFromCache
            hasMore = snapshot.hasMore
            readError = nil
        }
    }

    private func persistPending() {
        do {
            try pendingStorage?.replace(pendingIDs.compactMap { localRecords[$0] })
            if pendingStorage != nil { durableIDs = pendingIDs }
            storageError = nil
        }
        catch {
            storageError = pendingIDs.isEmpty ? "Your results are saved to your account. Local queue cleanup needs a retry."
                : "Your result couldn’t be kept on this device. Please retry saving."
        }
        updateSaveError()
    }

    private func retryWrites() {
        for id in pendingIDs {
            if let record = localRecords[id] { send(record) }
        }
    }

    private func send(_ record: GameRecord) {
        guard let repository, !inFlight.contains(record.id) else { return }
        inFlight.insert(record.id)
        repository.save(record) { [weak self] result in
            guard let self else { return }
            self.inFlight.remove(record.id)
            switch result {
            case .success:
                self.pendingIDs.remove(record.id)
                self.failedWrites.remove(record.id)
                self.persistPending()
            case .failure:
                self.failedWrites.insert(record.id)
                self.updateSaveError()
            }
        }
    }

    private func updateSaveError() {
        saveError = storageError ?? (failedWrites.isEmpty ? nil : "Your result hasn’t synced yet. It will retry when you return, or you can retry now.")
    }

    #if DEBUG && targetEnvironment(simulator)
    func replaceDemoRecords(_ records: [GameRecord]) {
        self.records = Self.normalized(records, ownerID: ownerID)
    }
    #endif

    private static func normalized(_ records: [GameRecord], ownerID: String) -> [GameRecord] {
        var seen = Set<UUID>()
        return records.filter { $0.ownerID == ownerID && seen.insert($0.id).inserted }
            .sorted {
                if $0.finishedAt == $1.finishedAt { return $0.id.uuidString > $1.id.uuidString }
                return $0.finishedAt > $1.finishedAt
            }
    }
}
