import Foundation

/// A focus task planned for a specific calendar date.
struct ScheduledTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    /// Target cumulative focus time for this task (seconds).
    var targetDuration: TimeInterval
    /// The day this task is scheduled for (time component stripped).
    var scheduledDate: Date
    /// Optional specific start time on that day.
    var startTime: Date?
    /// Manually toggled or auto-set when linked to a completed PomodoroTask.
    var isCompleted: Bool
    /// EKEvent.eventIdentifier of a linked iPhone Calendar event, if any.
    var linkedCalendarEventID: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        targetDuration: TimeInterval = 25 * 60,
        scheduledDate: Date,
        startTime: Date? = nil,
        isCompleted: Bool = false,
        linkedCalendarEventID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.targetDuration = targetDuration
        // Always store the start-of-day so date comparisons are consistent.
        self.scheduledDate = Calendar.current.startOfDay(for: scheduledDate)
        self.startTime = startTime
        self.isCompleted = isCompleted
        self.linkedCalendarEventID = linkedCalendarEventID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
