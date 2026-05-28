import AppIntents
import Foundation

@available(iOS 16.0, *)
struct PomodoroFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "PomodoroFocus"
    static var description = IntentDescription("Tự động cấu hình PomodoroFocus khi iOS Focus bật.")
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "PomodoroFocus")
    }

    @Parameter(title: "Tự động bắt đầu timer")
    var autoStartTimer: Bool

    @Parameter(title: "Bật âm thanh môi trường")
    var enableAmbientSound: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Pomodoro Focus Mode") {
            \.$autoStartTimer
            \.$enableAmbientSound
        }
    }

    init() {
        autoStartTimer = false
        enableAmbientSound = true
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(autoStartTimer, forKey: "focus_filter_auto_start")
        UserDefaults.standard.set(enableAmbientSound, forKey: "focus_filter_ambient")
        UserDefaults.standard.set(true, forKey: "focus_filter_pending_activation")
        NotificationCenter.default.post(
            name: .pomodoroFocusFilterActivated,
            object: nil,
            userInfo: [
                "autoStart": autoStartTimer,
                "ambient": enableAmbientSound
            ]
        )
        return .result()
    }
}
