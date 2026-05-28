import Foundation

enum TimerStatus: String, Codable, Equatable {
    case idle
    case running
    case paused
    case completed
}

struct AppState: Codable, Equatable {
    var currentSession: PomodoroSession?
    var completedSessionsToday: Int
    var completedFocusSessionsInCycle: Int
    var status: TimerStatus
    var pausedRemaining: TimeInterval?
    var progressDate: Date
    var lastUpdated: Date
    var lastKnownUptime: TimeInterval?
    var selectedTaskID: UUID?

    static let initial = AppState(
        currentSession: nil,
        completedSessionsToday: 0,
        completedFocusSessionsInCycle: 0,
        status: .idle,
        pausedRemaining: nil,
        progressDate: Date(),
        lastUpdated: Date(),
        lastKnownUptime: ProcessInfo.processInfo.systemUptime,
        selectedTaskID: nil
    )

    func normalizedForToday(calendar: Calendar = .current) -> AppState {
        guard !calendar.isDateInToday(progressDate) else { return self }

        var state = self
        state.completedSessionsToday = 0
        state.completedFocusSessionsInCycle = 0
        state.progressDate = Date()
        return state
    }
}
