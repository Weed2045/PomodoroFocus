import Foundation

final class UserDefaultsPomodoroSettingsRepository: PomodoroSettingsRepository {
    private let defaults: UserDefaults
    private let key = "pomodoroSettings"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> PomodoroSettings {
        UserDefaultsCoding.load(PomodoroSettings.self, key: key, defaults: defaults) ?? .default
    }

    func save(_ settings: PomodoroSettings) {
        UserDefaultsCoding.save(settings, key: key, defaults: defaults)
    }
}

