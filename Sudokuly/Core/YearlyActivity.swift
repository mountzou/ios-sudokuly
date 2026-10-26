import Foundation

/// Exactly 365 local calendar days, arranged in weeks with empty edge cells.
struct YearlyActivity {
    let days: [Date]
    let weeks: [[Date?]]
    let availableBounds: ClosedRange<Date>
    let interval: DateInterval?

    init(today: Date, registeredAt: Date?, calendar: Calendar) {
        let today = calendar.startOfDay(for: today)
        days = (-364...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let accountBounds = DailyActivity.dateBounds(registeredAt: registeredAt, today: today, calendar: calendar)
        let first = max(days.first ?? today, accountBounds.lowerBound)
        availableBounds = first...today
        interval = calendar.date(byAdding: .day, value: 1, to: today).map { DateInterval(start: first, end: $0) }

        let padding = days.first.map { (calendar.component(.weekday, from: $0) - calendar.firstWeekday + 7) % 7 } ?? 0
        var cells = Array<Date?>(repeating: nil, count: padding) + days.map { Optional($0) }
        cells += Array(repeating: nil, count: (7 - cells.count % 7) % 7)
        weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    func solvedDays(in dates: Set<Date>) -> Set<Date> {
        dates.filter { availableBounds.contains($0) }
    }
}
