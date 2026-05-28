import Combine
import Foundation

protocol SettingsManaging {
    var settingsPublisher: AnyPublisher<PomodoroSettings, Never> { get }
    var currentSettings: PomodoroSettings { get }
    func update(_ settings: PomodoroSettings)
}

final class SettingsManager: SettingsManaging {
    private let repository: PomodoroSettingsRepository
    private let settingsSubject: CurrentValueSubject<PomodoroSettings, Never>

    var settingsPublisher: AnyPublisher<PomodoroSettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }

    var currentSettings: PomodoroSettings {
        settingsSubject.value
    }

    init(repository: PomodoroSettingsRepository) {
        self.repository = repository
        self.settingsSubject = CurrentValueSubject(repository.load())
    }

    func update(_ settings: PomodoroSettings) {
        let sanitized = PomodoroSettings(
            focusDuration: Self.clampedMinutes(settings.focusDuration, minimum: 1, maximum: 180),
            shortBreakDuration: Self.clampedMinutes(settings.shortBreakDuration, minimum: 1, maximum: 60),
            longBreakDuration: Self.clampedMinutes(settings.longBreakDuration, minimum: 1, maximum: 120),
            sessionsBeforeLongBreak: min(max(settings.sessionsBeforeLongBreak, 1), 12)
        )
        repository.save(sanitized)
        settingsSubject.send(sanitized)
    }

    private static func clampedMinutes(_ duration: TimeInterval, minimum: Int, maximum: Int) -> TimeInterval {
        let minutes = Int(duration / 60)
        return TimeInterval(min(max(minutes, minimum), maximum) * 60)
    }
}

