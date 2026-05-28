import CoreData
import Foundation

final class CoreDataAnalyticsRepository: AnalyticsRepositoryProtocol {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: – Fetch

    func fetchSessions(from: Date, to: Date) async throws -> [FocusSession] {
        try await performBackground { ctx in
            let request = NSFetchRequest<CDFocusSession>(entityName: "CDFocusSession")
            request.predicate = NSPredicate(
                format: "startDate >= %@ AND startDate <= %@",
                from as NSDate, to as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            return try ctx.fetch(request).map { $0.toDomain() }
        }
    }

    func fetchAllSessions() async throws -> [FocusSession] {
        try await performBackground { ctx in
            let request = NSFetchRequest<CDFocusSession>(entityName: "CDFocusSession")
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            return try ctx.fetch(request).map { $0.toDomain() }
        }
    }

    // MARK: – Mutate

    func saveSession(_ session: FocusSession) async throws {
        try await performBackgroundVoid { ctx in
            let managed = self.findOrCreate(id: session.id, in: ctx)
            managed.update(from: session)
            try ctx.save()
        }
    }

    func updateSession(_ session: FocusSession) async throws {
        try await saveSession(session)   // upsert is identical
    }

    func deleteSession(id: UUID) async throws {
        try await performBackgroundVoid { ctx in
            let request = NSFetchRequest<CDFocusSession>(entityName: "CDFocusSession")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let obj = try ctx.fetch(request).first {
                ctx.delete(obj)
                try ctx.save()
            }
        }
    }

    // MARK: – Helpers

    private func findOrCreate(id: UUID, in ctx: NSManagedObjectContext) -> CDFocusSession {
        let request = NSFetchRequest<CDFocusSession>(entityName: "CDFocusSession")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? ctx.fetch(request).first) ?? CDFocusSession(context: ctx)
    }

    // Generic helper — runs `work` on a fresh background context, returns T.
    private func performBackground<T: Sendable>(
        _ work: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let ctx = stack.newBackgroundContext()
        return try await withCheckedThrowingContinuation { continuation in
            ctx.perform {
                do {
                    let result = try work(ctx)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performBackgroundVoid(
        _ work: @escaping (NSManagedObjectContext) throws -> Void
    ) async throws {
        let ctx = stack.newBackgroundContext()
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            ctx.perform {
                do { try work(ctx); c.resume() } catch { c.resume(throwing: error) }
            }
        }
    }
}
