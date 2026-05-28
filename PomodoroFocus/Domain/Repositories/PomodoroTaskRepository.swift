import Foundation

protocol PomodoroTaskRepository {
    func loadTasks() -> [PomodoroTask]
    func saveTasks(_ tasks: [PomodoroTask])
}

