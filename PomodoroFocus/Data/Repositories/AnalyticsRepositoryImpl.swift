import Foundation

final class AnalyticsRepositoryImpl: AnalyticsRepositoryProtocol {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let sessionsKey = "pomodoro_sessions_v2"
    private let legacySessionsKey = "pomodoro_sessions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func fetchSessions(from: Date, to: Date) async throws -> [FocusSession] {
        loadAll().filter { $0.startDate >= from && $0.startDate <= to }
    }

    func fetchAllSessions() async throws -> [FocusSession] {
        loadAll()
    }

    func saveSession(_ session: FocusSession) async throws {
        var all = loadAll()
        if let index = all.firstIndex(where: { $0.id == session.id }) {
            all[index] = session
        } else {
            all.append(session)
        }
        all.sort { $0.startDate < $1.startDate }
        if all.count > 10_000 {
            all = Array(all.suffix(10_000))
        }
        try persist(all)
    }

    func updateSession(_ session: FocusSession) async throws {
        var all = loadAll()
        guard let index = all.firstIndex(where: { $0.id == session.id }) else { return }
        all[index] = session
        try persist(all)
    }

    func deleteSession(id: UUID) async throws {
        var all = loadAll()
        all.removeAll { $0.id == id }
        try persist(all)
    }

    private func loadAll() -> [FocusSession] {
        if let data = defaults.data(forKey: sessionsKey),
           let sessions = try? decoder.decode([FocusSession].self, from: data) {
            return sessions
        }

        if let legacyData = defaults.data(forKey: legacySessionsKey),
           let sessions = try? decoder.decode([FocusSession].self, from: legacyData) {
            try? persist(sessions)
            defaults.removeObject(forKey: legacySessionsKey)
            return sessions
        }

        return []
    }

    private func persist(_ sessions: [FocusSession]) throws {
        let data = try encoder.encode(sessions)
        defaults.set(data, forKey: sessionsKey)
    }
}

