import Foundation
import Combine
import UserNotifications

enum PomodoroNotificationAction {
    case startBreak
    case skip
}

protocol NotificationScheduling {
    func requestAuthorization()
    func scheduleSessionEndNotification(for session: PomodoroSession, at date: Date)
    func cancelSessionEndNotification()
}

protocol NotificationActionPublishing {
    var actionPublisher: AnyPublisher<PomodoroNotificationAction, Never> { get }
}

final class NotificationManager: NSObject, NotificationScheduling, NotificationActionPublishing, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let notificationIdentifier = "pomodoro.session.end"
    private let categoryIdentifier = "pomodoro.session.category"
    private let startBreakActionIdentifier = "pomodoro.action.startBreak"
    private let skipActionIdentifier = "pomodoro.action.skip"
    private let actionSubject = PassthroughSubject<PomodoroNotificationAction, Never>()
    private var suppressExternalNotifications = false

    var actionPublisher: AnyPublisher<PomodoroNotificationAction, Never> {
        actionSubject.eraseToAnyPublisher()
    }

    private override init() {
        super.init()
        configure()
        observeFocusMode()
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                AppLogger.notify.error("❌ requestAuthorization error: \(error.localizedDescription, privacy: .public)")
            } else {
                AppLogger.notify.info("🔔 requestAuthorization → granted=\(granted, privacy: .public)")
            }
        }
    }

    func scheduleSessionEndNotification(for session: PomodoroSession, at date: Date) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            let status = settings.authorizationStatus
            AppLogger.notify.info("🔔 scheduleSessionEnd — authStatus=\(status.rawValue, privacy: .public) type=\(session.type.rawValue, privacy: .public)")

            guard status == .authorized || status == .provisional else {
                AppLogger.notify.warning("🔔 notification skipped — not authorized (status=\(status.rawValue, privacy: .public))")
                return
            }

            self.cancelSessionEndNotification()

            let content = UNMutableNotificationContent()
            content.title = session.type.completionTitle
            content.body = session.type.completionMessage
            content.sound = .default
            content.categoryIdentifier = self.categoryIdentifier
            content.userInfo = [
                "sessionID": session.id.uuidString,
                "sessionType": session.type.rawValue,
                "endTime": date.timeIntervalSince1970
            ]

            let interval = max(date.timeIntervalSinceNow, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: self.notificationIdentifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    AppLogger.notify.error("❌ add notification failed: \(error.localizedDescription, privacy: .public)")
                } else {
                    AppLogger.notify.info("✅ notification scheduled in \(String(format: "%.1f", interval), privacy: .public)s")
                }
            }
        }
    }

    func cancelSessionEndNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        AppLogger.notify.debug("🗑 pending notification cancelled")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if suppressExternalNotifications {
            let identifier = notification.request.identifier
            let category = notification.request.content.categoryIdentifier
            let isInternal = identifier.hasPrefix("pomodoro") || category == categoryIdentifier
            return isInternal ? [.banner, .sound] : []
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action: PomodoroNotificationAction?
        switch response.actionIdentifier {
        case startBreakActionIdentifier:
            action = .startBreak
        case skipActionIdentifier:
            action = .skip
        default:
            action = nil
        }

        if let action {
            await MainActor.run {
                actionSubject.send(action)
            }
        }
    }

    private func configure() {
        let startBreakAction = UNNotificationAction(
            identifier: startBreakActionIdentifier,
            title: "Start Break",
            options: [.foreground]
        )
        let skipAction = UNNotificationAction(
            identifier: skipActionIdentifier,
            title: "Skip",
            options: [.foreground, .destructive]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [startBreakAction, skipAction],
            intentIdentifiers: [],
            options: []
        )

        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        center.delegate = self
    }

    private func observeFocusMode() {
        NotificationCenter.default.addObserver(
            forName: .pomodoroFocusModeActivated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.suppressExternalNotifications = true
        }

        NotificationCenter.default.addObserver(
            forName: .pomodoroFocusModeDeactivated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.suppressExternalNotifications = false
        }
    }
}
