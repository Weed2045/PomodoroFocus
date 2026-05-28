import XCTest
@testable import PomodoroFocus

final class DomainEntityTests: XCTestCase {

    // MARK: – DailyStats.dayKey

    func test_dayKey_format() {
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2025; comps.month = 3; comps.day = 7
        let date = cal.date(from: comps)!
        XCTAssertEqual(DailyStats.dayKey(for: date, calendar: cal), "2025-03-07")
    }

    func test_dayKey_paddingZeros() {
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 1
        let date = cal.date(from: comps)!
        XCTAssertEqual(DailyStats.dayKey(for: date, calendar: cal), "2026-01-01")
    }

    func test_empty_dailyStats_hasZeroValues() {
        let stats = DailyStats.empty()
        XCTAssertEqual(stats.totalFocusTime, 0)
        XCTAssertEqual(stats.completedSessions, 0)
    }

    // MARK: – PomodoroTask.progressFraction

    func test_progressFraction_zero_when_no_focus() {
        let task = PomodoroTask(title: "Test", targetDuration: 1500)
        XCTAssertEqual(task.progressFraction, 0.0)
    }

    func test_progressFraction_half() {
        var task = PomodoroTask(title: "Test", targetDuration: 1500)
        task.totalFocusTime = 750
        XCTAssertEqual(task.progressFraction, 0.5, accuracy: 0.001)
    }

    func test_progressFraction_clampsAtOne() {
        var task = PomodoroTask(title: "Test", targetDuration: 1500)
        task.totalFocusTime = 9999
        XCTAssertEqual(task.progressFraction, 1.0)
    }

    func test_progressFraction_zero_targetDuration() {
        var task = PomodoroTask(title: "Test", targetDuration: 0)
        task.totalFocusTime = 100
        XCTAssertEqual(task.progressFraction, 0.0)
    }

    // MARK: – PomodoroSettings.duration(for:)

    func test_settings_duration_focus() {
        let settings = PomodoroSettings.default
        XCTAssertEqual(settings.duration(for: .focus), 25 * 60)
    }

    func test_settings_duration_shortBreak() {
        let settings = PomodoroSettings.default
        XCTAssertEqual(settings.duration(for: .shortBreak), 5 * 60)
    }

    func test_settings_duration_longBreak() {
        let settings = PomodoroSettings.default
        XCTAssertEqual(settings.duration(for: .longBreak), 15 * 60)
    }

    // MARK: – AppState.normalizedForToday

    func test_normalizedForToday_todayIsUnchanged() {
        let state = AppState(
            currentSession: nil,
            completedSessionsToday: 5,
            completedFocusSessionsInCycle: 2,
            status: .idle,
            pausedRemaining: nil,
            progressDate: Date(),
            lastUpdated: Date(),
            lastKnownUptime: nil,
            selectedTaskID: nil
        )
        let normalized = state.normalizedForToday()
        XCTAssertEqual(normalized.completedSessionsToday, 5)
        XCTAssertEqual(normalized.completedFocusSessionsInCycle, 2)
    }

    func test_normalizedForToday_yesterdayIsReset() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let state = AppState(
            currentSession: nil,
            completedSessionsToday: 7,
            completedFocusSessionsInCycle: 3,
            status: .idle,
            pausedRemaining: nil,
            progressDate: yesterday,
            lastUpdated: yesterday,
            lastKnownUptime: nil,
            selectedTaskID: nil
        )
        let normalized = state.normalizedForToday()
        XCTAssertEqual(normalized.completedSessionsToday, 0)
        XCTAssertEqual(normalized.completedFocusSessionsInCycle, 0)
    }
}
