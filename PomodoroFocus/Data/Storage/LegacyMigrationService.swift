import Foundation

/// One-time migration from UserDefaults JSON storage to CoreData.
///
/// Call `migrateIfNeeded(...)` at app startup (before the first data access).
/// The migration flag is persisted in UserDefaults so it only runs once.
final class LegacyMigrationService {
    private let defaults: UserDefaults
    private static let completedKey = "coredata_migration_v1_completed"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isMigrationNeeded: Bool {
        !defaults.bool(forKey: Self.completedKey)
    }

    // MARK: – Entry point

    func migrateIfNeeded(
        taskRepo:          PomodoroTaskRepository,
        scheduledTaskRepo: ScheduledTaskRepository,
        dailyStatsRepo:    DailyStatsRepository,
        analyticsRepo:     AnalyticsRepositoryProtocol
    ) {
        guard isMigrationNeeded else { return }

        migrateTasks(to: taskRepo)
        migrateScheduledTasks(to: scheduledTaskRepo)
        migrateDailyStats(to: dailyStatsRepo)
        migrateAnalyticsSessions(to: analyticsRepo)  // async, fire-and-forget

        defaults.set(true, forKey: Self.completedKey)
    }

    // MARK: – Individual migrations

    private func migrateTasks(to repo: PomodoroTaskRepository) {
        guard let tasks = loadJSON([PomodoroTask].self, key: "pomodoroTasks"),
              !tasks.isEmpty else { return }
        repo.saveTasks(tasks)
        defaults.removeObject(forKey: "pomodoroTasks")
    }

    private func migrateScheduledTasks(to repo: ScheduledTaskRepository) {
        guard let tasks = loadJSON([ScheduledTask].self, key: "scheduledTasks"),
              !tasks.isEmpty else { return }
        tasks.forEach { repo.save($0) }
        defaults.removeObject(forKey: "scheduledTasks")
    }

    private func migrateDailyStats(to repo: DailyStatsRepository) {
        guard let map = loadJSON([String: DailyStats].self, key: "dailyStats"),
              !map.isEmpty else { return }
        map.values.forEach { repo.save($0) }
        defaults.removeObject(forKey: "dailyStats")
    }

    /// Analytics sessions may be large (up to 10 000) — migrate off the main thread.
    private func migrateAnalyticsSessions(to repo: AnalyticsRepositoryProtocol) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try v2 key first, then legacy key
        let keys = ["pomodoro_sessions_v2", "pomodoro_sessions"]
        var sessions: [FocusSession] = []
        var usedKey: String?

        for key in keys {
            if let data = defaults.data(forKey: key),
               let decoded = try? decoder.decode([FocusSession].self, from: data),
               !decoded.isEmpty {
                sessions = decoded
                usedKey = key
                break
            }
        }

        guard !sessions.isEmpty, let key = usedKey else { return }

        Task.detached(priority: .utility) { [weak self, sessions] in
            for session in sessions {
                try? await repo.saveSession(session)
            }
            // Clean up both keys after successful migration
            await MainActor.run {
                self?.defaults.removeObject(forKey: key)
                self?.defaults.removeObject(forKey: "pomodoro_sessions")
            }
        }
    }

    // MARK: – Helpers

    private func loadJSON<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
