import Foundation

struct FocusSession: Identifiable, Codable, Equatable {
    let id: UUID
    let taskID: UUID?
    let taskTitle: String?
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
    let targetDurationMinutes: Int
    let sessionType: SessionType
    let wasCompleted: Bool
    var isSyncedToHealthKit: Bool

    enum SessionType: String, Codable {
        case focus
        case shortBreak
        case longBreak
    }

    init(
        id: UUID = UUID(),
        taskID: UUID?,
        taskTitle: String?,
        startDate: Date,
        endDate: Date,
        durationMinutes: Int,
        targetDurationMinutes: Int,
        sessionType: SessionType,
        wasCompleted: Bool,
        isSyncedToHealthKit: Bool = false
    ) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.targetDurationMinutes = targetDurationMinutes
        self.sessionType = sessionType
        self.wasCompleted = wasCompleted
        self.isSyncedToHealthKit = isSyncedToHealthKit
    }
}

enum AnalyticsRange: String, CaseIterable, Identifiable {
    case week
    case month
    case threeMonths
    case year
    case allTime

    var id: Self { self }

    var displayName: String {
        switch self {
        case .week:
            L10n.Analytics.rangeWeek
        case .month:
            L10n.Analytics.rangeMonth
        case .threeMonths:
            L10n.Analytics.rangeThreeMonths
        case .year:
            L10n.Analytics.rangeYear
        case .allTime:
            L10n.Analytics.rangeAllTime
        }
    }

    var dayCount: Int {
        switch self {
        case .week:
            7
        case .month:
            30
        case .threeMonths:
            90
        case .year:
            365
        case .allTime:
            3650
        }
    }

    var dateInterval: DateInterval {
        let calendar = Calendar.current
        let end = Date()
        let startOfToday = calendar.startOfDay(for: end)
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: startOfToday) ?? startOfToday
        return DateInterval(start: start, end: end)
    }
}

struct AnalyticsData {
    let sessions: [FocusSession]
    let summary: Summary
    let heatmapMatrix: HeatmapMatrix
    let dailyFocusMinutes: [DailyValue]
    let dailySessions: [DailyValue]

    struct Summary {
        let totalSessions: Int
        let totalFocusMinutes: Int
        let averageDailyMinutes: Double
        let currentStreak: Int
        let longestStreak: Int
        let bestDay: (date: Date, minutes: Int)?
        let mostProductiveHour: Int?
    }

    struct DailyValue: Identifiable, Equatable {
        let id: Date
        let date: Date
        let value: Double
    }

    typealias HeatmapMatrix = [[Int]]
}

extension FocusSession.SessionType {
    init(_ type: PomodoroSessionType) {
        switch type {
        case .focus:
            self = .focus
        case .shortBreak:
            self = .shortBreak
        case .longBreak:
            self = .longBreak
        }
    }
}

