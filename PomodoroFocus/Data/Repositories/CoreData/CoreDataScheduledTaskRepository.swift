import CoreData
import Foundation

final class CoreDataScheduledTaskRepository: ScheduledTaskRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: – Read

    func loadTasks(for date: Date) -> [ScheduledTask] {
        let (start, end) = dayRange(for: date)
        let request = NSFetchRequest<CDScheduledTask>(entityName: "CDScheduledTask")
        request.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND scheduledDate < %@",
            start as NSDate, end as NSDate
        )
        // nil startTime sorts last; secondary sort by createdAt
        request.sortDescriptors = [
            NSSortDescriptor(key: "startTime", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        do {
            return try stack.viewContext.fetch(request).map { $0.toDomain() }
        } catch {
            assertionFailure("loadTasks(for:) failed: \(error)")
            return []
        }
    }

    func loadAllTasks() -> [ScheduledTask] {
        let request = NSFetchRequest<CDScheduledTask>(entityName: "CDScheduledTask")
        request.sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: false)]
        do {
            return try stack.viewContext.fetch(request).map { $0.toDomain() }
        } catch {
            assertionFailure("loadAllTasks failed: \(error)")
            return []
        }
    }

    func hasTasks(on date: Date) -> Bool {
        let (start, end) = dayRange(for: date)
        let request = NSFetchRequest<CDScheduledTask>(entityName: "CDScheduledTask")
        request.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND scheduledDate < %@ AND isCompleted == NO",
            start as NSDate, end as NSDate
        )
        request.fetchLimit = 1
        return (try? stack.viewContext.count(for: request) ?? 0) ?? 0 > 0
    }

    // MARK: – Write

    func save(_ task: ScheduledTask) {
        let ctx = stack.viewContext
        ctx.performAndWait {
            let managed = self.findOrCreate(id: task.id, in: ctx)
            managed.update(from: task)
            do { try ctx.save() } catch { assertionFailure("save(_:) failed: \(error)") }
        }
    }

    func delete(id: UUID) {
        let ctx = stack.viewContext
        ctx.performAndWait {
            let request = NSFetchRequest<CDScheduledTask>(entityName: "CDScheduledTask")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let obj = try? ctx.fetch(request).first else { return }
            ctx.delete(obj)
            do { try ctx.save() } catch { assertionFailure("delete(id:) failed: \(error)") }
        }
    }

    // MARK: – Helpers

    private func findOrCreate(id: UUID, in ctx: NSManagedObjectContext) -> CDScheduledTask {
        let request = NSFetchRequest<CDScheduledTask>(entityName: "CDScheduledTask")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? ctx.fetch(request).first) ?? CDScheduledTask(context: ctx)
    }

    private func dayRange(for date: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }
}
