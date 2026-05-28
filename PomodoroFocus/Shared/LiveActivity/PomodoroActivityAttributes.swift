import ActivityKit
import Foundation

public struct PomodoroActivityAttributes: ActivityAttributes {
    public let sessionID: UUID
    public let taskTitle: String?
    public let targetDuration: Int

    public struct ContentState: Codable, Hashable {
        public var remainingSeconds: Int
        public var sessionType: SessionType
        public var isRunning: Bool
        public var completedToday: Int
        public var endDate: Date?

        public enum SessionType: String, Codable, Hashable {
            case focus
            case shortBreak
            case longBreak

            public var displayName: String {
                switch self {
                case .focus:
                    return L10n.LiveActivity.sessionFocus
                case .shortBreak:
                    return L10n.LiveActivity.sessionShortBreak
                case .longBreak:
                    return L10n.LiveActivity.sessionLongBreak
                }
            }

            public var emoji: String {
                switch self {
                case .focus:
                    return "🍅"
                case .shortBreak:
                    return "☕"
                case .longBreak:
                    return "🌙"
                }
            }

            public var accentColorHex: String {
                switch self {
                case .focus:
                    return "#E74C3C"
                case .shortBreak:
                    return "#27AE60"
                case .longBreak:
                    return "#2980B9"
                }
            }
        }
    }

    public init(sessionID: UUID, taskTitle: String?, targetDuration: Int) {
        self.sessionID = sessionID
        self.taskTitle = taskTitle
        self.targetDuration = targetDuration
    }
}

extension PomodoroActivityAttributes.ContentState {
    public func progress(targetDuration: Int) -> Double {
        guard targetDuration > 0 else { return 0 }
        let elapsed = targetDuration - remainingSeconds
        return min(max(Double(elapsed) / Double(targetDuration), 0), 1)
    }

    public var timeString: String {
        let minutes = max(remainingSeconds, 0) / 60
        let seconds = max(remainingSeconds, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

