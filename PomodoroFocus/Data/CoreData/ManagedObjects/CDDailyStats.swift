import CoreData
import Foundation

@objc(CDDailyStats)
final class CDDailyStats: NSManagedObject {
    @NSManaged var dayKey: String
    @NSManaged var totalFocusTime: Double
    @NSManaged var completedSessions: Int32
}

extension CDDailyStats {
    func toDomain() -> DailyStats {
        DailyStats(
            dayKey: dayKey,
            totalFocusTime: totalFocusTime,
            completedSessions: Int(completedSessions)
        )
    }

    func update(from stats: DailyStats) {
        dayKey            = stats.dayKey
        totalFocusTime    = stats.totalFocusTime
        completedSessions = Int32(stats.completedSessions)
    }
}
