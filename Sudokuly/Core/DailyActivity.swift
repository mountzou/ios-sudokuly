import Foundation

enum DailyActivity {
    static func pickerStep(translation: Double, predicted: Double, spacing: Double) -> Int {
        guard spacing > 0, spacing.isFinite, translation.isFinite, predicted.isFinite else { return 0 }
        // A flick can finish a short drag, but an opposite velocity at lift-off must not reverse it.
        let projected = abs(translation) >= 10 && translation * predicted > 0 ? predicted : 0
        let movement = abs(translation) >= spacing / 2 ? translation : projected
        guard abs(movement) >= spacing / 2 else { return 0 }
        return movement > 0 ? -1 : 1
    }

    static func week(containing date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func interval(for days: [Date], calendar: Calendar) -> DateInterval? {
        guard let first = days.first, let last = days.last,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
        return DateInterval(start: first, end: end)
    }

    static func solvedDays(in records: [GameRecord], ownerID: String, calendar: Calendar) -> Set<Date> {
        Set(records.filter { $0.ownerID == ownerID && $0.outcome == .won }
            .map { calendar.startOfDay(for: $0.finishedAt) })
    }
}
