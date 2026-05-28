import Foundation

final class AppGroupBridge {
    static let shared = AppGroupBridge()

    static let appGroupIdentifier = "group.com.codex.PomodoroFocus"
    static let toggleNotificationName = "com.codex.PomodoroFocus.toggle"

    private let defaults = UserDefaults(suiteName: AppGroupBridge.appGroupIdentifier)
    private let toggleKey = "bridge_toggle_requested"
    private let toggleTimestampKey = "bridge_toggle_timestamp"

    private init() {}

    func requestToggle() {
        defaults?.set(true, forKey: toggleKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: toggleTimestampKey)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(AppGroupBridge.toggleNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    func startObserving(handler: @escaping () -> Void) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                NotificationCenter.default.post(name: .pomodoroLiveActivityToggleRequested, object: nil)
            },
            AppGroupBridge.toggleNotificationName as CFString,
            nil,
            .deliverImmediately
        )

        NotificationCenter.default.addObserver(
            forName: .pomodoroLiveActivityToggleRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.defaults?.bool(forKey: self.toggleKey) == true else { return }
            self.defaults?.set(false, forKey: self.toggleKey)
            handler()
        }
    }
}

extension Notification.Name {
    static let pomodoroLiveActivityToggleRequested = Notification.Name("com.codex.PomodoroFocus.toggleRequested")
    static let navigateToFocus = Notification.Name("com.codex.PomodoroFocus.navigateToFocus")
}

