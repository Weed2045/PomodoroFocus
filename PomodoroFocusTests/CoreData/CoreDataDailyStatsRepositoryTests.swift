import XCTest
@testable import PomodoroFocus

final class CoreDataDailyStatsRepositoryTests: XCTestCase {
    private var stack: CoreDataStack!
    private var sut: CoreDataDailyStatsRepository!

    override func setUp() {
        super.setUp()
        stack = CoreDataStack(inMemory: true)
        sut = CoreDataDailyStatsRepository(stack: stack)
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: – loadStats(for:)

    func test_loadStats_returnsEmptyForUnknownDate() {
        let stats = sut.loadStats(for: Date())
        XCTAssertEqual(stats.completedSessions, 0)
        XCTAssertEqual(stats.totalFocusTime, 0)
    }

    // MARK: – save / loadStats round-trip

    func test_save_and_reload_preservesAllFields() {
        var stats = DailyStats.empty(for: Date())
        stats.totalFocusTime = 3600
        stats.completedSessions = 4
        sut.save(stats)

        let loaded = sut.loadStats(for: Date())
        XCTAssertEqual(loaded.totalFocusTime, 3600)
        XCTAssertEqual(loaded.completedSessions, 4)
        XCTAssertEqual(loaded.dayKey, stats.dayKey)
    }

    func test_save_upserts_existingDayKey() {
        var stats = DailyStats.empty(for: Date())
        stats.completedSessions = 2
        sut.save(stats)

        stats.completedSessions = 5
        sut.save(stats)

        XCTAssertEqual(sut.loadStats(for: Date()).completedSessions, 5)
    }

    // MARK: – loadRecentStats

    func test_loadRecentStats_returnsCorrectLimit() {
        let cal = Calendar.current
        for i in 0..<10 {
            let date = cal.date(byAdding: .day, value: -i, to: Date())!
            var s = DailyStats.empty(for: date)
            s.completedSessions = i + 1
            sut.save(s)
        }
        let recent = sut.loadRecentStats(limit: 5)
        XCTAssertEqual(recent.count, 5)
    }

    func test_loadRecentStats_sortedNewestFirst() {
        let cal = Calendar.current
        for i in 0..<3 {
            let date = cal.date(byAdding: .day, value: -i, to: Date())!
            sut.save(DailyStats.empty(for: date))
        }
        let recent = sut.loadRecentStats(limit: 3)
        XCTAssertGreaterThanOrEqual(recent[0].dayKey, recent[1].dayKey)
        XCTAssertGreaterThanOrEqual(recent[1].dayKey, recent[2].dayKey)
    }

    // MARK: – loadAllStats

    func test_loadAllStats_returnsEverything() {
        let cal = Calendar.current
        for i in 0..<7 {
            let date = cal.date(byAdding: .day, value: -i, to: Date())!
            sut.save(DailyStats.empty(for: date))
        }
        XCTAssertEqual(sut.loadAllStats().count, 7)
    }

    func test_loadAllStats_emptyWhenNothingSaved() {
        XCTAssertTrue(sut.loadAllStats().isEmpty)
    }
}
