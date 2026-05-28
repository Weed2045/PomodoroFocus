import Foundation

protocol PomodoroSettingsRepository {
    func load() -> PomodoroSettings
    func save(_ settings: PomodoroSettings)
}

