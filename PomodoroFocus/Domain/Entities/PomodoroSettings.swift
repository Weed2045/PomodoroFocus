import Foundation

struct PomodoroSettings: Codable, Equatable {
    var focusDuration: TimeInterval
    var shortBreakDuration: TimeInterval
    var longBreakDuration: TimeInterval
    var sessionsBeforeLongBreak: Int

    static let `default` = PomodoroSettings(
        focusDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        sessionsBeforeLongBreak: 4
    )

    func duration(for type: PomodoroSessionType) -> TimeInterval {
        switch type {
        case .focus:
            focusDuration
        case .shortBreak:
            shortBreakDuration
        case .longBreak:
            longBreakDuration
        }
    }
}
