import CoreData
import Foundation

// MARK: - Stack

final class CoreDataStack {

    // MARK: Singleton
    static let shared = CoreDataStack()

    // MARK: Init — private for singleton, internal for tests
    private convenience init() { self.init(inMemory: false) }

    init(inMemory: Bool) {
        let container = NSPersistentContainer(
            name: "PomodoroFocus",
            managedObjectModel: CoreDataStack.makeModel()
        )
        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.url = URL(fileURLWithPath: "/dev/null")
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        } else {
            let desc = container.persistentStoreDescriptions.first
            desc?.setOption(
                FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
        }
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("CoreData store load failed: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.name = inMemory ? "test-context" : "main-context"
        _persistentContainer = container
    }

    // MARK: Container
    private let _persistentContainer: NSPersistentContainer
    var persistentContainer: NSPersistentContainer { _persistentContainer }

    // MARK: Contexts
    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }

    /// Creates a new private background context for write operations.
    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.name = "background-context"
        return ctx
    }

    /// Save the view context if it has pending changes.
    @discardableResult
    func saveViewContext() -> Bool {
        let ctx = viewContext
        guard ctx.hasChanges else { return true }
        do {
            try ctx.save()
            return true
        } catch {
            assertionFailure("ViewContext save failed: \(error)")
            return false
        }
    }
}

// MARK: - Programmatic model

extension CoreDataStack {

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            makePomodoroTaskEntity(),
            makeScheduledTaskEntity(),
            makeFocusSessionEntity(),
            makeDailyStatsEntity()
        ]
        return model
    }

    // MARK: CDPomodoroTask
    private static func makePomodoroTaskEntity() -> NSEntityDescription {
        let e = entity("CDPomodoroTask", class: CDPomodoroTask.self)
        e.properties = [
            attr("id",                type: .UUIDAttributeType),
            attr("title",             type: .stringAttributeType),
            attr("notes",             type: .stringAttributeType, optional: true),
            attr("targetDuration",    type: .doubleAttributeType),
            attr("totalFocusTime",    type: .doubleAttributeType),
            attr("completedSessions", type: .integer32AttributeType),
            attr("isCompleted",       type: .booleanAttributeType),
            attr("isArchived",        type: .booleanAttributeType),
            attr("createdAt",         type: .dateAttributeType),
            attr("updatedAt",         type: .dateAttributeType)
        ]
        return e
    }

    // MARK: CDScheduledTask
    private static func makeScheduledTaskEntity() -> NSEntityDescription {
        let e = entity("CDScheduledTask", class: CDScheduledTask.self)
        e.properties = [
            attr("id",                    type: .UUIDAttributeType),
            attr("title",                 type: .stringAttributeType),
            attr("notes",                 type: .stringAttributeType, optional: true),
            attr("targetDuration",        type: .doubleAttributeType),
            attr("scheduledDate",         type: .dateAttributeType,   indexed: true),
            attr("startTime",             type: .dateAttributeType,   optional: true),
            attr("isCompleted",           type: .booleanAttributeType),
            attr("linkedCalendarEventID", type: .stringAttributeType, optional: true),
            attr("createdAt",             type: .dateAttributeType),
            attr("updatedAt",             type: .dateAttributeType)
        ]
        return e
    }

    // MARK: CDFocusSession
    private static func makeFocusSessionEntity() -> NSEntityDescription {
        let e = entity("CDFocusSession", class: CDFocusSession.self)
        e.properties = [
            attr("id",                    type: .UUIDAttributeType),
            attr("taskID",                type: .UUIDAttributeType,    optional: true),
            attr("taskTitle",             type: .stringAttributeType,  optional: true),
            attr("startDate",             type: .dateAttributeType,    indexed: true),
            attr("endDate",               type: .dateAttributeType),
            attr("durationMinutes",       type: .integer32AttributeType),
            attr("targetDurationMinutes", type: .integer32AttributeType),
            attr("sessionType",           type: .stringAttributeType),
            attr("wasCompleted",          type: .booleanAttributeType),
            attr("isSyncedToHealthKit",   type: .booleanAttributeType)
        ]
        return e
    }

    // MARK: CDDailyStats
    private static func makeDailyStatsEntity() -> NSEntityDescription {
        let e = entity("CDDailyStats", class: CDDailyStats.self)
        e.properties = [
            attr("dayKey",            type: .stringAttributeType, indexed: true),
            attr("totalFocusTime",    type: .doubleAttributeType),
            attr("completedSessions", type: .integer32AttributeType)
        ]
        return e
    }

    // MARK: Helpers
    private static func entity<T: NSManagedObject>(
        _ name: String, class: T.Type
    ) -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = name
        e.managedObjectClassName = NSStringFromClass(`class`)
        return e
    }

    private static func attr(
        _ name: String,
        type: NSAttributeType,
        optional: Bool = false,
        indexed: Bool = false
    ) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = optional
        a.isIndexed = indexed
        return a
    }
}
