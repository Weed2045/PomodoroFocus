import SwiftUI

/// UI-only extension so the Domain layer stays free of SwiftUI dependencies.
extension PomodoroSessionType {
    /// Tint colour matching AppTheme for each session type.
    var tint: Color {
        switch self {
        case .focus:      AppTheme.blue
        case .shortBreak: AppTheme.sky
        case .longBreak:  AppTheme.teal
        }
    }
}
