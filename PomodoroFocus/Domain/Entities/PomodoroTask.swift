import Foundation

struct PomodoroTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    /// Optional notes / description added when creating or editing the task.
    var notes: String
    /// Target cumulative focus time the user wants to spend on this task (seconds).
    var targetDuration: TimeInterval
    /// Total focus time accumulated across all sessions (seconds).
    var totalFocusTime: TimeInterval
    /// Number of focus sessions completed for this task.
    var completedSessions: Int
    /// Set automatically to `true` once `totalFocusTime >= targetDuration`.
    var isCompleted: Bool
    var isArchived: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        targetDuration: TimeInterval = 25 * 60,
        totalFocusTime: TimeInterval = 0,
        completedSessions: Int = 0,
        isCompleted: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.targetDuration = targetDuration
        self.totalFocusTime = totalFocusTime
        self.completedSessions = completedSessions
        self.isCompleted = isCompleted
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Fraction of the target duration completed. Clamped to [0, 1].
    var progressFraction: Double {
        guard targetDuration > 0 else { return 0 }
        return min(totalFocusTime / targetDuration, 1)
    }
}
