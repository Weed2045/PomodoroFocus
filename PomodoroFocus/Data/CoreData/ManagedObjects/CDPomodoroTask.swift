import CoreData
import Foundation

@objc(CDPomodoroTask)
final class CDPomodoroTask: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var notes: String?
    @NSManaged var targetDuration: Double
    @NSManaged var totalFocusTime: Double
    @NSManaged var completedSessions: Int32
    @NSManaged var isCompleted: Bool
    @NSManaged var isArchived: Bool
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
}

extension CDPomodoroTask {
    // MARK: Domain mapping
    func toDomain() -> PomodoroTask {
        PomodoroTask(
            id: id,
            title: title,
            notes: notes ?? "",
            targetDuration: targetDuration,
            totalFocusTime: totalFocusTime,
            completedSessions: Int(completedSessions),
            isCompleted: isCompleted,
            isArchived: isArchived,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from task: PomodoroTask) {
        id                = task.id
        title             = task.title
        notes             = task.notes.isEmpty ? nil : task.notes
        targetDuration    = task.targetDuration
        totalFocusTime    = task.totalFocusTime
        completedSessions = Int32(task.completedSessions)
        isCompleted       = task.isCompleted
        isArchived        = task.isArchived
        createdAt         = task.createdAt
        updatedAt         = task.updatedAt
    }
}
