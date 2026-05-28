import Foundation

struct DailyStats: Identifiable, Codable, Equatable {
    var id: String { dayKey }
    let dayKey: String
    var totalFocusTime: TimeInterval
    var completedSessions: Int

    static func empty(for date: Date = Date(), calendar: Calendar = .current) -> DailyStats {
        DailyStats(
            dayKey: Self.dayKey(for: date, calendar: calendar),
            totalFocusTime: 0,
            completedSessions: 0
        )
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

