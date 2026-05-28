import Foundation

final class FocusFilterService {
    func suppressNotifications() {
        NotificationCenter.default.post(name: .pomodoroFocusModeActivated, object: nil)
    }

    func restoreNotifications() {
        NotificationCenter.default.post(name: .pomodoroFocusModeDeactivated, object: nil)
    }
}

extension Notification.Name {
    static let pomodoroFocusModeActivated = Notification.Name("pomodoroFocusModeActivated")
    static let pomodoroFocusModeDeactivated = Notification.Name("pomodoroFocusModeDeactivated")
    static let pomodoroFocusFilterActivated = Notification.Name("pomodoroFocusFilterActivated")
    static let pomodoroFocusFilterAutoStartRequested = Notification.Name("pomodoroFocusFilterAutoStartRequested")
}
