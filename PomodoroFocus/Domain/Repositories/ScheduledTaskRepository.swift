import Foundation

protocol ScheduledTaskRepository {
    func loadTasks(for date: Date) -> [ScheduledTask]
    func loadAllTasks() -> [ScheduledTask]
    /// Inserts a new task or replaces an existing one with the same id.
    func save(_ task: ScheduledTask)
    func delete(id: UUID)
    /// Returns true if at least one non-completed task exists on `date`.
    func hasTasks(on date: Date) -> Bool
    /// Returns local calendar day keys for non-completed tasks in `[start, end)`.
    func pendingTaskDayKeys(from start: Date, to end: Date) -> Set<String>
}
