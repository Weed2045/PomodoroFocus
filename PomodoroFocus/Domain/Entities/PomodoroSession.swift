import Foundation

struct PomodoroSession: Identifiable, Codable, Equatable {
    let id: UUID
    let type: PomodoroSessionType
    let duration: TimeInterval
    let totalDuration: TimeInterval
    let startTime: Date
    let taskID: UUID?
    let isCompleted: Bool

    init(
        id: UUID = UUID(),
        type: PomodoroSessionType,
        duration: TimeInterval,
        totalDuration: TimeInterval? = nil,
        startTime: Date,
        taskID: UUID? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.type = type
        self.duration = duration
        self.totalDuration = totalDuration ?? duration
        self.startTime = startTime
        self.taskID = taskID
        self.isCompleted = isCompleted
    }

    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }
}
