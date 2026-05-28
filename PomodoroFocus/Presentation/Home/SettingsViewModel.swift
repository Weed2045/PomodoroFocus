import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var focusMinutes: Int
    @Published var shortBreakMinutes: Int
    @Published var longBreakMinutes: Int
    @Published var sessionsBeforeLongBreak: Int

    private let settingsManager: SettingsManaging
    private var cancellables = Set<AnyCancellable>()

    init(settingsManager: SettingsManaging) {
        self.settingsManager = settingsManager
        let settings = settingsManager.currentSettings
        self.focusMinutes = Int(settings.focusDuration / 60)
        self.shortBreakMinutes = Int(settings.shortBreakDuration / 60)
        self.longBreakMinutes = Int(settings.longBreakDuration / 60)
        self.sessionsBeforeLongBreak = settings.sessionsBeforeLongBreak

        settingsManager.settingsPublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.focusMinutes = Int(settings.focusDuration / 60)
                self?.shortBreakMinutes = Int(settings.shortBreakDuration / 60)
                self?.longBreakMinutes = Int(settings.longBreakDuration / 60)
                self?.sessionsBeforeLongBreak = settings.sessionsBeforeLongBreak
            }
            .store(in: &cancellables)
    }

    func save() {
        settingsManager.update(
            PomodoroSettings(
                focusDuration: TimeInterval(focusMinutes * 60),
                shortBreakDuration: TimeInterval(shortBreakMinutes * 60),
                longBreakDuration: TimeInterval(longBreakMinutes * 60),
                sessionsBeforeLongBreak: sessionsBeforeLongBreak
            )
        )
    }

    func restoreDefaults() {
        let defaults = PomodoroSettings.default
        focusMinutes = Int(defaults.focusDuration / 60)
        shortBreakMinutes = Int(defaults.shortBreakDuration / 60)
        longBreakMinutes = Int(defaults.longBreakDuration / 60)
        sessionsBeforeLongBreak = defaults.sessionsBeforeLongBreak
        save()
    }
}

