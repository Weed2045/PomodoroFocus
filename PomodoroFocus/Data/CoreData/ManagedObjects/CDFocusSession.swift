import CoreData
import Foundation

@objc(CDFocusSession)
final class CDFocusSession: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var taskID: UUID?
    @NSManaged var taskTitle: String?
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var durationMinutes: Int32
    @NSManaged var targetDurationMinutes: Int32
    @NSManaged var sessionType: String
    @NSManaged var wasCompleted: Bool
    @NSManaged var isSyncedToHealthKit: Bool
}

extension CDFocusSession {
    func toDomain() -> FocusSession {
        FocusSession(
            id: id,
            taskID: taskID,
            taskTitle: taskTitle,
            startDate: startDate,
            endDate: endDate,
            durationMinutes: Int(durationMinutes),
            targetDurationMinutes: Int(targetDurationMinutes),
            sessionType: FocusSession.SessionType(rawValue: sessionType) ?? .focus,
            wasCompleted: wasCompleted,
            isSyncedToHealthKit: isSyncedToHealthKit
        )
    }

    func update(from session: FocusSession) {
        id                    = session.id
        taskID                = session.taskID
        taskTitle             = session.taskTitle
        startDate             = session.startDate
        endDate               = session.endDate
        durationMinutes       = Int32(session.durationMinutes)
        targetDurationMinutes = Int32(session.targetDurationMinutes)
        sessionType           = session.sessionType.rawValue
        wasCompleted          = session.wasCompleted
        isSyncedToHealthKit   = session.isSyncedToHealthKit
    }
}
