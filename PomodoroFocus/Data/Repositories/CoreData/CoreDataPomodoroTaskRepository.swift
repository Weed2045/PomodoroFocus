import CoreData
import Foundation

final class CoreDataPomodoroTaskRepository: PomodoroTaskRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: – Read

    func loadTasks() -> [PomodoroTask] {
        let request = NSFetchRequest<CDPomodoroTask>(entityName: "CDPomodoroTask")
        request.sortDescriptors = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "createdAt",   ascending: false)
        ]
        do {
            return try stack.viewContext.fetch(request).map { $0.toDomain() }
        } catch {
            assertionFailure("loadTasks failed: \(error)")
            return []
        }
    }

    // MARK: – Write

    /// Full replace: deletes tasks removed from the list, upserts the rest.
    func saveTasks(_ tasks: [PomodoroTask]) {
        let ctx = stack.viewContext
        ctx.performAndWait {
            // Load all existing managed objects
            let request = NSFetchRequest<CDPomodoroTask>(entityName: "CDPomodoroTask")
            let existing = (try? ctx.fetch(request)) ?? []
            var byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

            let incomingIDs = Set(tasks.map(\.id))

            // Delete tasks that no longer exist in the incoming list
            for managed in existing where !incomingIDs.contains(managed.id) {
                ctx.delete(managed)
            }

            // Upsert
            for task in tasks {
                let managed = byID[task.id] ?? CDPomodoroTask(context: ctx)
                managed.update(from: task)
                byID[task.id] = managed
            }

            do { try ctx.save() } catch { assertionFailure("saveTasks failed: \(error)") }
        }
    }
}
