import Foundation

struct GetPomodoroSettingsUseCase {
    private let repository: PomodoroSettingsRepository

    init(repository: PomodoroSettingsRepository) {
        self.repository = repository
    }

    func execute() -> PomodoroSettings {
        repository.load()
    }
}

