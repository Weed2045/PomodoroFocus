import CoreData
import Foundation

final class CoreDataDailyStatsRepository: DailyStatsRepository {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: – Read

    func loadStats(for date: Date) -> DailyStats {
        let key = DailyStats.dayKey(for: date)
        return fetchManaged(dayKey: key)?.toDomain() ?? .empty(for: date)
    }

    func loadRecentStats(limit: Int) -> [DailyStats] {
        let request = NSFetchRequest<CDDailyStats>(entityName: "CDDailyStats")
        request.sortDescriptors = [NSSortDescriptor(key: "dayKey", ascending: false)]
        request.fetchLimit = limit
        do {
            return try stack.viewContext.fetch(request).map { $0.toDomain() }
        } catch {
            assertionFailure("loadRecentStats failed: \(error)")
            return []
        }
    }

    func loadAllStats() -> [DailyStats] {
        let request = NSFetchRequest<CDDailyStats>(entityName: "CDDailyStats")
        request.sortDescriptors = [NSSortDescriptor(key: "dayKey", ascending: false)]
        do {
            return try stack.viewContext.fetch(request).map { $0.toDomain() }
        } catch {
            assertionFailure("loadAllStats failed: \(error)")
            return []
        }
    }

    // MARK: – Write

    func save(_ stats: DailyStats) {
        let ctx = stack.viewContext
        ctx.performAndWait {
            let managed = self.findOrCreate(dayKey: stats.dayKey, in: ctx)
            managed.update(from: stats)
            do { try ctx.save() } catch { assertionFailure("save(_:) failed: \(error)") }
        }
    }

    // MARK: – Helpers

    private func fetchManaged(dayKey: String) -> CDDailyStats? {
        let request = NSFetchRequest<CDDailyStats>(entityName: "CDDailyStats")
        request.predicate = NSPredicate(format: "dayKey == %@", dayKey)
        request.fetchLimit = 1
        return try? stack.viewContext.fetch(request).first
    }

    private func findOrCreate(dayKey: String, in ctx: NSManagedObjectContext) -> CDDailyStats {
        let request = NSFetchRequest<CDDailyStats>(entityName: "CDDailyStats")
        request.predicate = NSPredicate(format: "dayKey == %@", dayKey)
        request.fetchLimit = 1
        if let existing = try? ctx.fetch(request).first { return existing }
        let obj = CDDailyStats(context: ctx)
        obj.dayKey = dayKey
        return obj
    }
}
