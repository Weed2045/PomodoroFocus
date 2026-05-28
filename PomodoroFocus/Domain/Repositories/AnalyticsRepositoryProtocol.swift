import Foundation

protocol AnalyticsRepositoryProtocol {
    func fetchSessions(from: Date, to: Date) async throws -> [FocusSession]
    func fetchAllSessions() async throws -> [FocusSession]
    func saveSession(_ session: FocusSession) async throws
    func updateSession(_ session: FocusSession) async throws
    func deleteSession(id: UUID) async throws
}

