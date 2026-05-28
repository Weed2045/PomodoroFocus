import os

// MARK: – AppLogger
//
// Centralised logging namespace for PomodoroFocus.
// Each category maps to a logical subsystem visible in Xcode console and Console.app.
//
// USAGE
//   AppLogger.timer.info("Session started: \(type, privacy: .public)")
//   AppLogger.scanner.error("Failed to save page: \(error, privacy: .public)")
//
// FILTERING IN XCODE CONSOLE
//   Type "subsystem:com.codex.PomodoroFocus" to see only app logs.
//   Further filter by category: "category:Timer", "category:Scanner" etc.
//
// FILTERING IN CONSOLE.APP
//   Action → Include Info Messages / Include Debug Messages
//   Filter field: "com.codex.PomodoroFocus"
//
// PRIVACY NOTE
//   Strings marked `.public` appear in plain text in Console.app even in release
//   builds. Use `.private` (the default) for user-identifiable content in production.
//   During development all values are visible in a debugger session regardless of
//   privacy level, so the `.public` annotations here are intentional for observability.

enum AppLogger {
    private static let subsystem = "com.codex.PomodoroFocus"

    /// Pomodoro timer lifecycle — start, pause, resume, reset, complete.
    static let timer        = Logger(subsystem: subsystem, category: "Timer")

    /// Calendar permission requests, EKEvent fetching.
    static let calendar     = Logger(subsystem: subsystem, category: "Calendar")

    /// VisionKit scanning, document/page CRUD.
    static let scanner      = Logger(subsystem: subsystem, category: "Scanner")

    /// PDF generation and compression.
    static let pdf          = Logger(subsystem: subsystem, category: "PDF")

    /// Disk and UserDefaults persistence operations.
    static let storage      = Logger(subsystem: subsystem, category: "Storage")

    /// Local notification scheduling and actions.
    static let notify       = Logger(subsystem: subsystem, category: "Notification")

    /// Streak calculation and achievements.
    static let gamify       = Logger(subsystem: subsystem, category: "Gamification")

    /// CoreImage filter/render pipeline.
    static let image        = Logger(subsystem: subsystem, category: "ImageProcessing")

    /// App-level lifecycle: foreground, background, scene phase.
    static let app          = Logger(subsystem: subsystem, category: "App")
}
