import Foundation

enum DailyActivity {
    static func dateBounds(registeredAt: Date?, today: Date, calendar: Calendar) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: today)
        // Without usable metadata, permit today until the real creation date is available.
        guard let registeredAt, registeredAt.timeIntervalSinceReferenceDate.isFinite else { return today...today }
        let firstDay = min(calendar.startOfDay(for: registeredAt), today)
        return firstDay...today
    }

    static func months(in bounds: ClosedRange<Date>, calendar: Calendar) -> [Date] {
        guard var month = calendar.dateInterval(of: .month, for: bounds.lowerBound)?.start else { return [] }
        var months: [Date] = []
        while month <= bounds.upperBound {
            months.append(month)
            guard let next = calendar.date(byAdding: .month, value: 1, to: month), next > month else { break }
            month = next
        }
        return months
    }

    static func monthBounds(containing day: Date, within bounds: ClosedRange<Date>,
                            calendar: Calendar) -> ClosedRange<Date>? {
        guard let month = calendar.dateInterval(of: .month, for: day),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end) else { return nil }
        let first = max(month.start, bounds.lowerBound), last = min(lastDay, bounds.upperBound)
        return first <= last ? first...last : nil
    }

    static func activityInterval(around day: Date, bounds: ClosedRange<Date>, calendar: Calendar) -> DateInterval? {
        guard let visibleWeek = interval(for: week(containing: day, calendar: calendar), calendar: calendar),
              let start = calendar.date(byAdding: .day, value: -7, to: visibleWeek.start),
              let end = calendar.date(byAdding: .day, value: 7, to: visibleWeek.end),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: bounds.upperBound) else { return nil }
        // Prefetch adjacent weeks only within this account's available calendar days.
        let lower = max(start, bounds.lowerBound), upper = min(end, tomorrow)
        guard lower < upper else { return nil }
        return DateInterval(start: lower, end: upper)
    }

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
