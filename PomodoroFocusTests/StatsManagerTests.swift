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
