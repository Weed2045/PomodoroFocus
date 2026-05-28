import Foundation

enum PomodoroSessionType: String, Codable, CaseIterable, Equatable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus:      L10n.Session.focus
        case .shortBreak: L10n.Session.shortBreak
        case .longBreak:  L10n.Session.longBreak
        }
    }

    var completionTitle: String {
        switch self {
        case .focus:               L10n.Session.focusCompletionTitle
        case .shortBreak, .longBreak: L10n.Session.breakCompletionTitle
        }
    }

    var completionMessage: String {
        switch self {
        case .focus:               L10n.Session.focusCompletionMessage
        case .shortBreak, .longBreak: L10n.Session.breakCompletionMessage
        }
    }
}

