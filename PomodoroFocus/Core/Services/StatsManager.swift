import Combine
import Foundation

protocol StatsManaging {
    var todayStatsPublisher: AnyPublisher<DailyStats, Never> { get }
    var todayStats: DailyStats { get }
    func recordCompletedFocusSession(duration: TimeInterval, completedAt date: Date)
    func refreshToday()
}

final class StatsManager: StatsManaging {
    private let repository: DailyStatsRepository
    private let statsSubject: CurrentValueSubject<DailyStats, Never>

    var todayStatsPublisher: AnyPublisher<DailyStats, Never> {
        statsSubject.eraseToAnyPublisher()
    }

    var todayStats: DailyStats {
        statsSubject.value
    }

    init(repository: DailyStatsRepository) {
        self.repository = repository
        self.statsSubject = CurrentValueSubject(repository.loadStats(for: Date()))
    }

    func recordCompletedFocusSession(duration: TimeInterval, completedAt date: Date) {
        var stats = repository.loadStats(for: date)
        stats.totalFocusTime += duration
        stats.completedSessions += 1
        repository.save(stats)

        if Calendar.current.isDateInToday(date) {
            statsSubject.send(stats)
        }
    }

    func refreshToday() {
        statsSubject.send(repository.loadStats(for: Date()))
    }
}

