import CoreData
import Foundation

@objc(CDScheduledTask)
final class CDScheduledTask: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var notes: String?
    @NSManaged var targetDuration: Double
    @NSManaged var scheduledDate: Date
    @NSManaged var startTime: Date?
    @NSManaged var isCompleted: Bool
    @NSManaged var linkedCalendarEventID: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
}

extension CDScheduledTask {
    func toDomain() -> ScheduledTask {
        ScheduledTask(
            id: id,
            title: title,
            notes: notes ?? "",
            targetDuration: targetDuration,
            scheduledDate: scheduledDate,
            startTime: startTime,
            isCompleted: isCompleted,
            linkedCalendarEventID: linkedCalendarEventID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from task: ScheduledTask) {
        id                    = task.id
        title                 = task.title
        notes                 = task.notes.isEmpty ? nil : task.notes
        targetDuration        = task.targetDuration
        scheduledDate         = task.scheduledDate
        startTime             = task.startTime
        isCompleted           = task.isCompleted
        linkedCalendarEventID = task.linkedCalendarEventID
        createdAt             = task.createdAt
        updatedAt             = task.updatedAt
    }
}
