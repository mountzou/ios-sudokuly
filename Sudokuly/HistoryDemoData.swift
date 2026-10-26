#if DEBUG && targetEnvironment(simulator)
import Foundation

enum HistoryDemoAction {
    case samples, empty, result(GameOutcome)
}

enum HistoryDemoData {
    static func solvedYearDays(today: Date, calendar: Calendar) -> Set<Date> {
        Set((0..<365).compactMap { offset -> Date? in
            // A repeatable visual fixture, isolated from the six demo history records.
            let rhythm = (offset * 37 + offset / 11 * 17) % 100
            let threshold = offset < 70 ? 76 : offset < 180 ? 54 : 34
            guard rhythm < threshold, !(110...122).contains(offset), !(260...274).contains(offset) else { return nil }
            return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: today))
        })
    }

    static func records(ownerID: String, now: Date = Date()) -> [GameRecord] {
        let samples: [(Difficulty, GameOutcome, TimeInterval, Int)] = [
            (.easy, .won, 342, 0),
            (.medium, .mistakes, 487, 3),
            (.hard, .won, 1043, 1),
            (.expert, .timedOut, 2400, 2),
            (.medium, .won, 659, 2),
            (.hard, .mistakes, 812, 3)
        ]
        return samples.enumerated().map { index, sample in
            let day = Calendar.current.date(byAdding: .day, value: -(index / 2), to: now)!
            let finishedAt = day.addingTimeInterval(-Double(index % 2 + 1) * 3600)
            return GameRecord(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!,
                              ownerID: ownerID, finishedAt: finishedAt, difficulty: sample.0,
                              outcome: sample.1, duration: sample.2, mistakes: sample.3)
        }
    }
}
#endif
