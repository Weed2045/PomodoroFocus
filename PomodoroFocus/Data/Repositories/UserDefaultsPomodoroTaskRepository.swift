import Foundation

final class UserDefaultsPomodoroTaskRepository: PomodoroTaskRepository {
    private let defaults: UserDefaults
    private let key = "pomodoroTasks"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func loadTasks() -> [PomodoroTask] {
        UserDefaultsCoding.load([PomodoroTask].self, key: key, defaults: defaults) ?? []
    }

    func saveTasks(_ tasks: [PomodoroTask]) {
        UserDefaultsCoding.save(tasks, key: key, defaults: defaults)
    }
}

