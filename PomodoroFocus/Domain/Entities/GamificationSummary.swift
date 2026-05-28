import Foundation

enum Achievement: String, CaseIterable, Identifiable, Codable {
    case tenSessions
    case fiveHoursFocus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tenSessions:
            "10 Sessions"
        case .fiveHoursFocus:
            "5 Hours Focus"
        }
    }
}

struct GamificationSummary: Equatable {
    var streakDays: Int
    var unlockedAchievements: [Achievement]

    static let empty = GamificationSummary(streakDays: 0, unlockedAchievements: [])
}

