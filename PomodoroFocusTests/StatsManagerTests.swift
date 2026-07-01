import XCTest
@testable import PomodoroFocus

final class StatsManagerTests: XCTestCase {
    private var sut: StatsManager!
    private var repo: InMemoryDailyStatsRepository!

    override func setUp() {
        super.setUp()
        repo = InMemoryDailyStatsRepository()
        sut = StatsManager(repository: repo)
    }

    override func tearDown() {
        sut = nil
        repo = nil
        super.tearDown()
    }

    // MARK: – todayStats

    func test_todayStats_startsEmpty() {
        XCTAssertEqual(sut.todayStats.completedSessions, 0)
        XCTAssertEqual(sut.todayStats.totalFocusTime, 0)
    }

    // MARK: – recordCompletedFocusSession

    func test_record_incrementsSessionCount() {
        sut.recordCompletedFocusSession(duration: 1500, completedAt: Date())
        XCTAssertEqual(sut.todayStats.completedSessions, 1)
    }

    func test_record_accumulatesFocusTime() {
        sut.recordCompletedFocusSession(duration: 1500, completedAt: Date())
        sut.recordCompletedFocusSession(duration: 900, completedAt: Date())
        XCTAssertEqual(sut.todayStats.totalFocusTime, 2400)
    }

    func test_record_persistsToRepository() {
        sut.recordCompletedFocusSession(duration: 1500, completedAt: Date())
        let key = DailyStats.dayKey(for: Date())
        XCTAssertEqual(repo.store[key]?.completedSessions, 1)
    }

    func test_record_forYesterday_doesNotUpdateTodaySubject() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        sut.recordCompletedFocusSession(duration: 1500, completedAt: yesterday)
        // Today's published value should still be 0
        XCTAssertEqual(sut.todayStats.completedSessions, 0)
    }

    // MARK: – refreshToday

    func test_refreshToday_picksUpExternalChanges() {
        // Simulate an external write directly to the repo
        var stats = DailyStats.empty(for: Date())
        stats.completedSessions = 99
        repo.save(stats)
        sut.refreshToday()
        XCTAssertEqual(sut.todayStats.completedSessions, 99)
    }

    // MARK: – Multiple days

    func test_record_multipledays_storesCorrectlyPerDay() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        sut.recordCompletedFocusSession(duration: 1500, completedAt: today)
        sut.recordCompletedFocusSession(duration: 3000, completedAt: yesterday)

        let todayKey = DailyStats.dayKey(for: today)
        let yestKey  = DailyStats.dayKey(for: yesterday)
        XCTAssertEqual(repo.store[todayKey]?.totalFocusTime, 1500)
        XCTAssertEqual(repo.store[yestKey]?.totalFocusTime, 3000)
    }
}

// MARK: – Test double

final class InMemoryDailyStatsRepository: DailyStatsRepository {
    var store: [String: DailyStats] = [:]

    func loadStats(for date: Date) -> DailyStats {
        store[DailyStats.dayKey(for: date)] ?? .empty(for: date)
    }

    func save(_ stats: DailyStats) {
        store[stats.dayKey] = stats
    }

    func loadRecentStats(limit: Int) -> [DailyStats] {
        Array(store.values.sorted { $0.dayKey > $1.dayKey }.prefix(limit))
    }

    func loadAllStats() -> [DailyStats] {
        store.values.sorted { $0.dayKey > $1.dayKey }
    }
}

// MARK: – PomodoroService completion date regression

final class PomodoroServiceStatsDateTests: XCTestCase {
    func test_refreshCompletedPastSession_recordsStatsOnSessionEndDate() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let completedAt = cal.date(byAdding: .hour, value: 22, to: yesterday)!
        let session = PomodoroSession(
            type: .focus,
            duration: 25 * 60,
            startTime: completedAt.addingTimeInterval(-(25 * 60))
        )
        let initialState = AppState(
            currentSession: session,
            completedSessionsToday: 3,
            completedFocusSessionsInCycle: 2,
            status: .running,
            pausedRemaining: nil,
            progressDate: completedAt,
            lastUpdated: completedAt,
            lastKnownUptime: nil,
            selectedTaskID: nil
        )
        let appStateRepo = PomodoroServiceAppStateRepositoryDouble(initialState)
        let statsRepo = InMemoryDailyStatsRepository()

        let service = PomodoroService(
            appStateRepository: appStateRepo,
            settingsManager: SettingsManager(repository: PomodoroServiceSettingsRepositoryDouble()),
            statsManager: StatsManager(repository: statsRepo),
            taskManager: TaskManager(repository: PomodoroServiceTaskRepositoryDouble()),
            gamificationManager: GamificationManager(repository: statsRepo),
            notificationService: PomodoroServiceNotificationDouble(),
            analyticsRepository: PomodoroServiceAnalyticsRepositoryDouble(),
            healthKitSyncUseCase: PomodoroServiceHealthKitDouble(),
            liveActivityService: PomodoroServiceLiveActivityDouble()
        )

        XCTAssertEqual(statsRepo.store[DailyStats.dayKey(for: completedAt)]?.completedSessions, 1)
        XCTAssertEqual(statsRepo.store[DailyStats.dayKey(for: today)]?.completedSessions ?? 0, 0)
        XCTAssertEqual(service.currentState.completedSessionsToday, 0)
    }
}

private final class PomodoroServiceAppStateRepositoryDouble: AppStateRepository {
    private var state: AppState

    init(_ state: AppState) {
        self.state = state
    }

    func load() -> AppState {
        state
    }

    func save(_ state: AppState) {
        self.state = state
    }
}

private final class PomodoroServiceSettingsRepositoryDouble: PomodoroSettingsRepository {
    private var settings = PomodoroSettings.default

    func load() -> PomodoroSettings {
        settings
    }

    func save(_ settings: PomodoroSettings) {
        self.settings = settings
    }
}

private final class PomodoroServiceTaskRepositoryDouble: PomodoroTaskRepository {
    private var tasks: [PomodoroTask] = []

    func loadTasks() -> [PomodoroTask] {
        tasks
    }

    func saveTasks(_ tasks: [PomodoroTask]) {
        self.tasks = tasks
    }
}

private final class PomodoroServiceNotificationDouble: NotificationScheduling {
    func requestAuthorization() {}
    func scheduleSessionEndNotification(for session: PomodoroSession, at date: Date) {}
    func cancelSessionEndNotification() {}
}

private final class PomodoroServiceAnalyticsRepositoryDouble: AnalyticsRepositoryProtocol {
    private var sessions: [FocusSession] = []

    func fetchSessions(from: Date, to: Date) async throws -> [FocusSession] {
        sessions.filter { $0.startDate >= from && $0.startDate <= to }
    }

    func fetchAllSessions() async throws -> [FocusSession] {
        sessions
    }

    func saveSession(_ session: FocusSession) async throws {
        sessions.append(session)
    }

    func updateSession(_ session: FocusSession) async throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func deleteSession(id: UUID) async throws {
        sessions.removeAll { $0.id == id }
    }
}

private final class PomodoroServiceHealthKitDouble: HealthKitSyncUseCaseProtocol {
    var isAvailable: Bool { false }
    var authorizationGranted: Bool { false }

    func requestAuthorization() async throws -> Bool { false }
    func syncSession(_ session: FocusSession) async throws {}
    func syncPendingSessions() async throws {}
}

private final class PomodoroServiceLiveActivityDouble: LiveActivityServiceProtocol {
    var isSupported: Bool { false }
    var isActive: Bool { false }

    func start(
        sessionID: UUID,
        taskTitle: String?,
        targetDuration: Int,
        remainingSeconds: Int,
        sessionType: PomodoroSessionType,
        endDate: Date,
        completedToday: Int
    ) async throws {}

    func update(
        sessionID: UUID?,
        remainingSeconds: Int,
        isRunning: Bool,
        endDate: Date?,
        completedToday: Int
    ) async {}

    func transition(
        to sessionType: PomodoroSessionType,
        targetDuration: Int,
        remainingSeconds: Int,
        endDate: Date,
        completedToday: Int
    ) async {}

    func end(dismissalPolicy: LiveActivityDismissalPolicy) async {}
}
