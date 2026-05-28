import AppIntents
import ActivityKit

@available(iOS 17.0, *)
struct ToggleTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Tạm dừng / Tiếp tục timer"
    static var description = IntentDescription("Toggle trạng thái Pomodoro timer")

    func perform() async throws -> some IntentResult {
        AppGroupBridge.shared.requestToggle()
        return .result()
    }
}

