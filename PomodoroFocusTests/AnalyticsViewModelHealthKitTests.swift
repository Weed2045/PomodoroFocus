import XCTest
@testable import PomodoroFocus

@MainActor
final class AnalyticsViewModelHealthKitTests: XCTestCase {
    func test_onAppear_mapsUnavailableStatus() {
        let health = HealthKitSyncUseCaseDouble(isAvailable: false, authorizationState: .sharingAuthorized)
        let sut = makeSUT(health: health)

        sut.onAppear()

        XCTAssertEqual(sut.healthKitStatus, .unavailable)
    }

    func test_onAppear_mapsNotDeterminedStatusToUnknown() {
        let health = HealthKitSyncUseCaseDouble(isAvailable: true, authorizationState: .notDetermined)
        let sut = makeSUT(health: health)

        sut.onAppear()

        XCTAssertEqual(sut.healthKitStatus, .unknown)
    }

    func test_onAppear_mapsSharingDeniedStatus() {
        let health = HealthKitSyncUseCaseDouble(isAvailable: true, authorizationState: .sharingDenied)
        let sut = makeSUT(health: health)

        sut.onAppear()

        XCTAssertEqual(sut.healthKitStatus, .denied)
    }

    func test_requestHealthKitAccess_authorizedStatusSyncsPendingSessions() async {
        let health = HealthKitSyncUseCaseDouble(
            isAvailable: true,
            authorizationState: .notDetermined,
            requestedState: .sharingAuthorized
        )
        let sut = makeSUT(health: health)

        await sut.requestHealthKitAccessAsync()

        XCTAssertEqual(sut.healthKitStatus, .authorized)
        XCTAssertEqual(health.syncPendingCallCount, 1)
    }

    func test_requestHealthKitAccess_deniedStatusDoesNotSyncPendingSessions() async {
        let health = HealthKitSyncUseCaseDouble(
            isAvailable: true,
            authorizationState: .notDetermined,
            requestedState: .sharingDenied
        )
        let sut = makeSUT(health: health)

        await sut.requestHealthKitAccessAsync()

        XCTAssertEqual(sut.healthKitStatus, .denied)
        XCTAssertEqual(health.syncPendingCallCount, 0)
    }

    private func makeSUT(health: HealthKitSyncUseCaseDouble) -> AnalyticsViewModel {
        AnalyticsViewModel(
            fetch: FetchAnalyticsUseCaseDouble(),
            export: ExportCSVUseCaseDouble(),
            health: health
        )
    }
}

private final class FetchAnalyticsUseCaseDouble: FetchAnalyticsUseCaseProtocol {
    func execute(range: AnalyticsRange) async throws -> AnalyticsData {
        AnalyticsData(
            sessions: [],
            summary: .init(
                totalSessions: 0,
                totalFocusMinutes: 0,
                averageDailyMinutes: 0,
                currentStreak: 0,
                longestStreak: 0,
                bestDay: nil,
                mostProductiveHour: nil
            ),
            heatmapMatrix: Array(repeating: Array(repeating: 0, count: 24), count: 7),
            dailyFocusMinutes: [],
            dailySessions: []
        )
    }
}

private final class ExportCSVUseCaseDouble: ExportCSVUseCaseProtocol {
    func execute() async throws -> URL {
        URL(fileURLWithPath: "/tmp/pomodoro-focus-test.csv")
    }
}

private final class HealthKitSyncUseCaseDouble: HealthKitSyncUseCaseProtocol {
    let isAvailable: Bool
    private(set) var authorizationState: HealthKitAuthorizationState
    private let requestedState: HealthKitAuthorizationState
    private(set) var syncPendingCallCount = 0

    init(
        isAvailable: Bool,
        authorizationState: HealthKitAuthorizationState,
        requestedState: HealthKitAuthorizationState? = nil
    ) {
        self.isAvailable = isAvailable
        self.authorizationState = authorizationState
        self.requestedState = requestedState ?? authorizationState
    }

    func requestAuthorization() async throws -> HealthKitAuthorizationState {
        authorizationState = requestedState
        return requestedState
    }

    func syncSession(_ session: FocusSession) async throws {}

    func syncPendingSessions() async throws {
        syncPendingCallCount += 1
    }
}
