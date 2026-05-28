import Foundation

final class UserDefaultsDailyStatsRepository: DailyStatsRepository {
    private let defaults: UserDefaults
    private let key = "dailyStats"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func loadStats(for date: Date) -> DailyStats {
        let dayKey = DailyStats.dayKey(for: date)
        return loadAll()[dayKey] ?? .empty(for: date)
    }

    func save(_ stats: DailyStats) {
        var allStats = loadAll()
        allStats[stats.dayKey] = stats
        UserDefaultsCoding.save(allStats, key: key, defaults: defaults)
    }

    func loadRecentStats(limit: Int) -> [DailyStats] {
        loadAll()
            .values
            .sorted { $0.dayKey > $1.dayKey }
            .prefix(limit)
            .map { $0 }
    }

    func loadAllStats() -> [DailyStats] {
        loadAll()
            .values
            .sorted { $0.dayKey > $1.dayKey }
    }

    private func loadAll() -> [String: DailyStats] {
        UserDefaultsCoding.load([String: DailyStats].self, key: key, defaults: defaults) ?? [:]
    }
}
