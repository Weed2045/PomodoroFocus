import Foundation

protocol DailyStatsRepository {
    func loadStats(for date: Date) -> DailyStats
    func save(_ stats: DailyStats)
    func loadRecentStats(limit: Int) -> [DailyStats]
    func loadAllStats() -> [DailyStats]
}
