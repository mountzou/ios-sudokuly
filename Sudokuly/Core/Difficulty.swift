import Foundation

enum Difficulty: String, CaseIterable, Identifiable, Codable, Sendable {
    case easy, medium, hard, expert

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var rank: Int { Self.allCases.firstIndex(of: self)! + 1 }
    var clueCount: Int {
        switch self {
        case .easy: 46
        case .medium: 38
        case .hard: 31
        case .expert: 26
        }
    }
    var timeLimit: TimeInterval {
        switch self {
        case .easy: 15 * 60
        case .medium: 20 * 60
        case .hard: 30 * 60
        case .expert: 40 * 60
        }
    }
    var detail: String {
        switch self {
        case .easy: "A gentle warm-up"
        case .medium: "Find your rhythm"
        case .hard: "Go a little deeper"
        case .expert: "For a sharper mind"
        }
    }
    var timeLabel: String { "\(Int(timeLimit / 60)) min" }
}
