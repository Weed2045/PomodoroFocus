import Foundation

final class UserDefaultsScheduledTaskRepository: ScheduledTaskRepository {
    private let defaults: UserDefaults
    private let key = "scheduledTasks"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func loadTasks(for date: Date) -> [ScheduledTask] {
        loadAllTasks().filter {
            Calendar.current.isDate($0.scheduledDate, inSameDayAs: date)
        }
        .sorted { lhs, rhs in
            switch (lhs.startTime, rhs.startTime) {
            case let (l?, r?): return l < r
            case (nil, _?):    return false
            case (_?, nil):    return true
            case (nil, nil):   return lhs.createdAt < rhs.createdAt
            }
        }
    }

    func loadAllTasks() -> [ScheduledTask] {
        UserDefaultsCoding.load([ScheduledTask].self, key: key, defaults: defaults) ?? []
    }

    func save(_ task: ScheduledTask) {
        var all = loadAllTasks()
        if let index = all.firstIndex(where: { $0.id == task.id }) {
            all[index] = task
        } else {
            all.append(task)
        }
        UserDefaultsCoding.save(all, key: key, defaults: defaults)
    }

    func delete(id: UUID) {
        var all = loadAllTasks()
        all.removeAll { $0.id == id }
        UserDefaultsCoding.save(all, key: key, defaults: defaults)
    }

    func hasTasks(on date: Date) -> Bool {
        // Only show the dot indicator when at least one task is still pending (not completed).
        loadAllTasks().contains {
            Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) && !$0.isCompleted
        }
    }
}
