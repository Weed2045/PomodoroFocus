import Foundation

protocol FetchAnalyticsUseCaseProtocol {
    func execute(range: AnalyticsRange) async throws -> AnalyticsData
}

protocol ExportCSVUseCaseProtocol {
    func execute() async throws -> URL
}

protocol HealthKitSyncUseCaseProtocol {
    var isAvailable: Bool { get }
    var authorizationGranted: Bool { get }
    func requestAuthorization() async throws -> Bool
    func syncSession(_ session: FocusSession) async throws
    func syncPendingSessions() async throws
}

final class FetchAnalyticsUseCase: FetchAnalyticsUseCaseProtocol {
    private let repository: AnalyticsRepositoryProtocol
    private let computationService: AnalyticsComputationService

    init(repository: AnalyticsRepositoryProtocol, computationService: AnalyticsComputationService) {
        self.repository = repository
        self.computationService = computationService
    }

    func execute(range: AnalyticsRange) async throws -> AnalyticsData {
        let interval = range.dateInterval
        let sessions = try await repository.fetchSessions(from: interval.start, to: interval.end)
        return computationService.compute(sessions: sessions, range: range)
    }
}

final class ExportCSVUseCase: ExportCSVUseCaseProtocol {
    private let repository: AnalyticsRepositoryProtocol
    private let exportService: CSVExportService

    init(repository: AnalyticsRepositoryProtocol, exportService: CSVExportService) {
        self.repository = repository
        self.exportService = exportService
    }

    func execute() async throws -> URL {
        let sessions = try await repository.fetchAllSessions()
        return try exportService.generateCSV(sessions: sessions)
    }
}

final class HealthKitSyncUseCase: HealthKitSyncUseCaseProtocol {
    private let repository: AnalyticsRepositoryProtocol
    private let healthKitService: HealthKitService

    var isAvailable: Bool {
        healthKitService.isAvailable
    }

    var authorizationGranted: Bool {
        healthKitService.authorizationGranted
    }

    init(repository: AnalyticsRepositoryProtocol, healthKitService: HealthKitService) {
        self.repository = repository
        self.healthKitService = healthKitService
    }

    func requestAuthorization() async throws -> Bool {
        try await healthKitService.requestAuthorization()
    }

    func syncSession(_ session: FocusSession) async throws {
        guard session.sessionType == .focus, session.wasCompleted else { return }
        try await healthKitService.saveMindfulSession(start: session.startDate, end: session.endDate)
        var synced = session
        synced.isSyncedToHealthKit = true
        try await repository.updateSession(synced)
    }

    func syncPendingSessions() async throws {
        let sessions = try await repository.fetchAllSessions()
            .filter { $0.sessionType == .focus && $0.wasCompleted && !$0.isSyncedToHealthKit }
        try await healthKitService.syncPending(sessions: sessions)

        for session in sessions {
            var synced = session
            synced.isSyncedToHealthKit = true
            try await repository.updateSession(synced)
        }
    }
}

