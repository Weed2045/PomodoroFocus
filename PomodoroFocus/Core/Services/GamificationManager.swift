import Combine
import Foundation

protocol GamificationManaging {
    var summaryPublisher: AnyPublisher<GamificationSummary, Never> { get }
    var currentSummary: GamificationSummary { get }
    func refresh()
}

final class GamificationManager: GamificationManaging {
    private let repository: DailyStatsRepository
    private let summarySubject: CurrentValueSubject<GamificationSummary, Never>

    var summaryPublisher: AnyPublisher<GamificationSummary, Never> {
        summarySubject.eraseToAnyPublisher()
    }

    var currentSummary: GamificationSummary {
        summarySubject.value
    }

    init(repository: DailyStatsRepository) {
        self.repository = repository
        self.summarySubject = CurrentValueSubject(.empty)
        refresh()
    }

    func refresh() {
        let stats = repository.loadAllStats()
        let totalSessions = stats.reduce(0) { $0 + $1.completedSessions }
        let totalFocusTime = stats.reduce(0) { $0 + $1.totalFocusTime }
        AppLogger.gamify.debug("🎮 refresh — totalSessions=\(totalSessions, privacy: .public) totalFocusTime=\(String(format: "%.0f", totalFocusTime), privacy: .public)s")

        var achievements: [Achievement] = []
        if totalSessions >= 10 { achievements.append(.tenSessions) }
        if totalFocusTime >= 5 * 60 * 60 { achievements.append(.fiveHoursFocus) }

        let streak = calculateStreak(from: stats)
        AppLogger.gamify.info("🎮 streak=\(streak, privacy: .public) achievements=\(achievements.count, privacy: .public)")

        summarySubject.send(
            GamificationSummary(
                streakDays: streak,
                unlockedAchievements: achievements
            )
        )
    }

    private func calculateStreak(from stats: [DailyStats]) -> Int {
        let cal = Calendar.current
        let focusedDays = Set(stats.filter { $0.completedSessions > 0 }.map(\.dayKey))
        AppLogger.gamify.debug("🎮 calculateStreak — focusedDays=\(focusedDays.count, privacy: .public)")

        var date = Date()
        if !focusedDays.contains(DailyStats.dayKey(for: date)) {
            AppLogger.gamify.debug("🎮 today has no sessions — starting from yesterday")
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }

        var streak = 0
        while focusedDays.contains(DailyStats.dayKey(for: date)) {
            streak += 1
            guard let previousDay = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = previousDay
        }
        AppLogger.gamify.info("🎮 calculated streak=\(streak, privacy: .public)")
        return streak
    }
}

