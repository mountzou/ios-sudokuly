import Foundation

/// Session-only cache. Each GameHistoryStore owns a separate instance for its account.
struct ActivityRangeCache {
    struct Lookup {
        let records: [GameRecord]
        let missing: [DateInterval]
        let isFromCache: Bool
    }
    private struct Entry {
        let interval: DateInterval
        let records: [GameRecord]
        let fetchedAt: Date
        let isFromCache: Bool
    }
    private var entries: [Entry] = []
    private let lifetime: TimeInterval = 300
    private let offlineLifetime: TimeInterval = 15
    private let capacity = 32

    func lookup(_ interval: DateInterval, now: Date) -> Lookup {
        var missing = [interval]
        let overlapping = entries.filter { $0.interval.start < interval.end && $0.interval.end > interval.start }
        for entry in overlapping where now.timeIntervalSince(entry.fetchedAt) >= 0 &&
            now.timeIntervalSince(entry.fetchedAt) < (entry.isFromCache ? offlineLifetime : lifetime) {
            missing = missing.flatMap { Self.subtract(entry.interval, from: $0) }
        }
        return Lookup(records: overlapping.flatMap(\.records).filter {
            $0.finishedAt >= interval.start && $0.finishedAt < interval.end
        }, missing: missing, isFromCache: overlapping.contains { $0.isFromCache })
    }

    mutating func insert(_ records: [GameRecord], interval: DateInterval, isFromCache: Bool, now: Date) {
        // A refresh replaces its covered range, including a successful empty response.
        entries = entries.flatMap { entry in
            Self.subtract(interval, from: entry.interval).map { remainder in
                Entry(interval: remainder, records: entry.records.filter {
                    $0.finishedAt >= remainder.start && $0.finishedAt < remainder.end
                }, fetchedAt: entry.fetchedAt, isFromCache: entry.isFromCache)
            }
        }
        entries.append(Entry(interval: interval, records: records.filter {
            $0.finishedAt >= interval.start && $0.finishedAt < interval.end
        }, fetchedAt: now, isFromCache: isFromCache))
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
    }

    mutating func invalidate() {
        entries = entries.map { Entry(interval: $0.interval, records: $0.records,
                                      fetchedAt: .distantPast, isFromCache: $0.isFromCache) }
    }

    private static func subtract(_ covered: DateInterval, from interval: DateInterval) -> [DateInterval] {
        guard covered.start < interval.end, covered.end > interval.start else { return [interval] }
        var result: [DateInterval] = []
        if interval.start < covered.start { result.append(DateInterval(start: interval.start, end: covered.start)) }
        if covered.end < interval.end { result.append(DateInterval(start: covered.end, end: interval.end)) }
        return result
    }
}
