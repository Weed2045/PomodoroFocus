import Combine
import Foundation

protocol TaskManaging {
    var tasksPublisher: AnyPublisher<[PomodoroTask], Never> { get }
    var activeTasks: [PomodoroTask] { get }
    func createTask(title: String, targetDuration: TimeInterval, notes: String)
    func createTaskFromOCR(title: String, targetDuration: TimeInterval, notes: String) -> PomodoroTask?
    func updateTask(id: UUID, title: String, targetDuration: TimeInterval, notes: String)
    func deleteTask(id: UUID)
    func task(id: UUID?) -> PomodoroTask?
    func recordFocusSession(taskID: UUID?, duration: TimeInterval)
}

final class TaskManager: TaskManaging {
    private let repository: PomodoroTaskRepository
    private let tasksSubject: CurrentValueSubject<[PomodoroTask], Never>

    var tasksPublisher: AnyPublisher<[PomodoroTask], Never> {
        tasksSubject.eraseToAnyPublisher()
    }

    var activeTasks: [PomodoroTask] {
        tasksSubject.value.filter { !$0.isArchived }
    }

    init(repository: PomodoroTaskRepository) {
        self.repository = repository
        self.tasksSubject = CurrentValueSubject(repository.loadTasks())
    }

    func createTask(title: String, targetDuration: TimeInterval, notes: String) {
        _ = createTaskFromOCR(title: title, targetDuration: targetDuration, notes: notes)
    }

    func createTaskFromOCR(title: String, targetDuration: TimeInterval, notes: String) -> PomodoroTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let task = PomodoroTask(
            title: trimmed,
            notes: notes,
            targetDuration: max(targetDuration, 60) // minimum 1 minute
        )
        var tasks = tasksSubject.value
        tasks.insert(task, at: 0)
        save(tasks)
        return task
    }

    func updateTask(id: UUID, title: String, targetDuration: TimeInterval, notes: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var tasks = tasksSubject.value
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].title = trimmed
        tasks[index].notes = notes
        tasks[index].targetDuration = max(targetDuration, 60)
        tasks[index].updatedAt = Date()

        // Re-evaluate completion whenever the target changes.
        tasks[index].isCompleted = tasks[index].totalFocusTime >= tasks[index].targetDuration
        save(tasks)
    }

    func deleteTask(id: UUID) {
        var tasks = tasksSubject.value
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isArchived = true
        tasks[index].updatedAt = Date()
        save(tasks)
    }

    func task(id: UUID?) -> PomodoroTask? {
        guard let id else { return nil }
        return tasksSubject.value.first { $0.id == id && !$0.isArchived }
    }

    /// Called by PomodoroService at the end of every focus session.
    /// Accumulates time and auto-completes the task when the target is met.
    func recordFocusSession(taskID: UUID?, duration: TimeInterval) {
        guard let taskID else { return }

        var tasks = tasksSubject.value
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }

        tasks[index].completedSessions += 1
        tasks[index].totalFocusTime += duration
        tasks[index].updatedAt = Date()

        // Auto-complete once accumulated focus time meets or exceeds the target.
        if !tasks[index].isCompleted,
           tasks[index].totalFocusTime >= tasks[index].targetDuration {
            tasks[index].isCompleted = true
        }

        save(tasks)
    }

    private func save(_ tasks: [PomodoroTask]) {
        repository.saveTasks(tasks)
        tasksSubject.send(tasks)
    }
}
