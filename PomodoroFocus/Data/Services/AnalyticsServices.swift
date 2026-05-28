import Foundation
import HealthKit

final class AnalyticsComputationService {
    func compute(sessions: [FocusSession], range: AnalyticsRange) -> AnalyticsData {
        let focusSessions = sessions.filter {
            $0.sessionType == .focus && $0.wasCompleted
        }

        return AnalyticsData(
            sessions: sessions,
            summary: computeSummary(focusSessions),
            heatmapMatrix: buildHeatmap(focusSessions),
            dailyFocusMinutes: buildDailyMinutes(focusSessions, range: range),
            dailySessions: buildDailySessions(focusSessions, range: range)
        )
    }

    private func buildHeatmap(_ sessions: [FocusSession]) -> AnalyticsData.HeatmapMatrix {
        var matrix = Array(repeating: Array(repeating: 0, count: 24), count: 7)
        let calendar = Calendar.current

        for session in sessions {
            let weekday = calendar.component(.weekday, from: session.startDate) - 1
            let hour = calendar.component(.hour, from: session.startDate)
            matrix[weekday][hour] += session.durationMinutes
        }

        return matrix
    }

    private func computeSummary(_ sessions: [FocusSession]) -> AnalyticsData.Summary {
        let calendar = Calendar.current
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let days = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.startDate)
        }
        let bestDay = days
            .mapValues { $0.reduce(0) { $0 + $1.durationMinutes } }
            .max(by: { $0.value < $1.value })
        let streaks = computeStreaks(days: Array(days.keys))

        return AnalyticsData.Summary(
            totalSessions: sessions.count,
            totalFocusMinutes: totalMinutes,
            averageDailyMinutes: days.isEmpty ? 0 : Double(totalMinutes) / Double(days.count),
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            bestDay: bestDay.map { ($0.key, $0.value) },
            mostProductiveHour: computeMostProductiveHour(sessions)
        )
    }

    private func computeStreaks(days: [Date]) -> (current: Int, longest: Int) {
        guard !days.isEmpty else { return (0, 0) }

        let calendar = Calendar.current
        let uniqueDays = Array(Set(days.map { calendar.startOfDay(for: $0) })).sorted()
        var longest = 1
        var running = 1

        if uniqueDays.count > 1 {
            for index in 1..<uniqueDays.count {
                let expected = calendar.date(byAdding: .day, value: 1, to: uniqueDays[index - 1])!
                if calendar.isDate(uniqueDays[index], inSameDayAs: expected) {
                    running += 1
                    longest = max(longest, running)
                } else {
                    running = 1
                }
            }
        }

        let last = uniqueDays.last!
        let isActive = calendar.isDateInToday(last) || calendar.isDateInYesterday(last)
        return (isActive ? running : 0, longest)
    }

    private func computeMostProductiveHour(_ sessions: [FocusSession]) -> Int? {
        guard !sessions.isEmpty else { return nil }
        var hourTotals: [Int: Int] = [:]

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startDate)
            hourTotals[hour, default: 0] += session.durationMinutes
        }

        return hourTotals.max(by: { $0.value < $1.value })?.key
    }

    private func buildDailyMinutes(_ sessions: [FocusSession], range: AnalyticsRange) -> [AnalyticsData.DailyValue] {
        buildDailyValues(sessions, range: range) { sessions in
            Double(sessions.reduce(0) { $0 + $1.durationMinutes })
        }
    }

    private func buildDailySessions(_ sessions: [FocusSession], range: AnalyticsRange) -> [AnalyticsData.DailyValue] {
        buildDailyValues(sessions, range: range) { sessions in
            Double(sessions.count)
        }
    }

    private func buildDailyValues(
        _ sessions: [FocusSession],
        range: AnalyticsRange,
        value: ([FocusSession]) -> Double
    ) -> [AnalyticsData.DailyValue] {
        let calendar = Calendar.current
        let interval = range.dateInterval
        var result: [AnalyticsData.DailyValue] = []
        var cursor = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end)
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startDate) }

        while cursor <= end {
            result.append(.init(id: cursor, date: cursor, value: value(grouped[cursor] ?? [])))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return result
    }
}

final class CSVExportService {
    func generateCSV(sessions: [FocusSession]) throws -> URL {
        let formatter = ISO8601DateFormatter()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pomodoro_sessions_\(Int(Date().timeIntervalSince1970)).csv")

        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        try write("id,taskTitle,startDate,endDate,durationMinutes,targetDurationMinutes,sessionType,wasCompleted\n", to: handle)
        for session in sessions {
            let row = [
                session.id.uuidString,
                (session.taskTitle ?? "").csvEscaped,
                formatter.string(from: session.startDate),
                formatter.string(from: session.endDate),
                "\(session.durationMinutes)",
                "\(session.targetDurationMinutes)",
                session.sessionType.rawValue,
                session.wasCompleted ? "true" : "false"
            ].joined(separator: ",")
            try write(row + "\n", to: handle)
        }

        return url
    }

    private func write(_ string: String, to handle: FileHandle) throws {
        if let data = string.data(using: .utf8) {
            try handle.write(contentsOf: data)
        }
    }
}

final class HealthKitService {
    private let store = HKHealthStore()

    private var mindfulType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .mindfulSession)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable() && mindfulType != nil
    }

    var authorizationGranted: Bool {
        guard let mindfulType else { return false }
        return store.authorizationStatus(for: mindfulType) == .sharingAuthorized
    }

    func requestAuthorization() async throws -> Bool {
        guard isAvailable, let mindfulType else { return false }
        try await store.requestAuthorization(toShare: [mindfulType], read: [])
        return store.authorizationStatus(for: mindfulType) == .sharingAuthorized
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        guard isAvailable, let mindfulType, authorizationGranted, end > start else { return }
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end,
            metadata: [HKMetadataKeyWasUserEntered: false]
        )
        try await store.save(sample)
    }

    func syncPending(sessions: [FocusSession]) async throws {
        guard isAvailable, let mindfulType, authorizationGranted, !sessions.isEmpty else { return }
        let sorted = sessions.sorted { $0.startDate < $1.startDate }
        let predicate = HKQuery.predicateForSamples(withStart: sorted.first?.startDate, end: sorted.last?.endDate)
        let existing: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: mindfulType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
                }
            }
            store.execute(query)
        }

        let existingRanges = existing.map { ($0.startDate, $0.endDate) }
        for session in sorted where session.sessionType == .focus && session.wasCompleted {
            let alreadySaved = existingRanges.contains {
                abs($0.0.timeIntervalSince(session.startDate)) < 5 &&
                abs($0.1.timeIntervalSince(session.endDate)) < 5
            }
            if !alreadySaved {
                try await saveMindfulSession(start: session.startDate, end: session.endDate)
            }
        }
    }
}

private extension String {
    var csvEscaped: String {
        if contains(",") || contains("\"") || contains("\n") {
            return "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return self
    }
}

