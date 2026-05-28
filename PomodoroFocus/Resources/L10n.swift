import Foundation

// MARK: - L10n — Type-safe localization wrapper
//
// Usage:
//   Text(L10n.Home.headerTitle)
//   Text(L10n.Home.currentSession("My Task"))
//   Label(L10n.Timer.actionStart, systemImage: "play.fill")

enum L10n {

    // MARK: - Core helper
    static func tr(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
    static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: args)
    }

    // MARK: - Common
    enum Common {
        static var ok: String             { tr("common.ok") }
        static var cancel: String         { tr("common.cancel") }
        static var delete: String         { tr("common.delete") }
        static var edit: String           { tr("common.edit") }
        static var save: String           { tr("common.save") }
        static var done: String           { tr("common.done") }
        static var new: String            { tr("common.new") }
        static var error: String          { tr("common.error") }
        static var settings: String       { tr("common.settings") }
        static var today: String          { tr("common.today") }
        static var notesPlaceholder: String { tr("common.notes.placeholder") }
    }

    // MARK: - Tabs
    enum Tab {
        static var focus: String     { tr("tab.focus") }
        static var calendar: String  { tr("tab.calendar") }
        static var analytics: String { tr("tab.analytics") }
        static var scanner: String   { tr("tab.scanner") }
    }

    // MARK: - Splash
    enum Splash {
        static var tagline: String { tr("splash.tagline") }
    }

    // MARK: - Home
    enum Home {
        static var headerTitle: String       { tr("home.header.title") }
        static var headerSubtitle: String    { tr("home.header.subtitle") }
        static func currentSession(_ name: String) -> String { tr("home.header.current_session", name) }
        static var sectionSettings: String   { tr("home.section.settings") }
        static var sectionToday: String      { tr("home.section.today") }
        static var sectionTasks: String      { tr("home.section.tasks") }
        static var sectionProgress: String   { tr("home.section.progress") }
        static var settingsFocus: String     { tr("home.settings.focus") }
        static var settingsBreak: String     { tr("home.settings.break") }
        static var settingsLong: String      { tr("home.settings.long") }
        static var settingsLongBreakEvery: String { tr("home.settings.long_break_every") }
        static func settingsSessionsCount(_ n: Int) -> String { tr("home.settings.sessions_count", n) }
        static var todaySessionsCompleted: String { tr("home.today.sessions_completed") }
        static var todayTotalTime: String    { tr("home.today.total_time") }
        static var taskEmptyTitle: String    { tr("home.task.empty.title") }
        static var taskEmptySubtitle: String { tr("home.task.empty.subtitle") }
        static var taskStatusDone: String    { tr("home.task.status.done") }
        static var taskFromScan: String      { tr("home.task.from_scan") }
        static func taskProgress(done: Int, target: Int, sessions: Int) -> String {
            let key = sessions == 1 ? "home.task.progress" : "home.task.progress.plural"
            return tr(key, done, target, sessions)
        }
        static var gamificationStreak: String { tr("home.gamification.streak") }
        static var gamificationBadges: String { tr("home.gamification.badges") }
        static var actionStartPomodoro: String { tr("home.action.start_pomodoro") }
        static var actionSettings: String    { tr("home.action.settings") }
    }

    // MARK: - Task Form
    enum TaskForm {
        static var addTitle: String         { tr("task.form.add.title") }
        static var addSubtitle: String      { tr("task.form.add.subtitle") }
        static var editTitle: String        { tr("task.form.edit.title") }
        static var editSubtitle: String     { tr("task.form.edit.subtitle") }
        static var editCompletedSubtitle: String { tr("task.form.edit.completed_subtitle") }
        static var fieldTitle: String       { tr("task.form.field.title") }
        static var fieldTitlePlaceholder: String { tr("task.form.field.title.placeholder") }
        static var fieldDuration: String    { tr("task.form.field.duration") }
        static var fieldNotes: String       { tr("task.form.field.notes") }
        static var fieldNotesPlaceholder: String { tr("task.form.field.notes.placeholder") }
        static var durationMinutes: String  { tr("task.form.duration.minutes") }
        static var buttonAdd: String        { tr("task.form.button.add") }
        static var buttonSave: String       { tr("task.form.button.save") }
        static var buttonCancel: String     { tr("task.form.button.cancel") }
        static var progressCompleted: String { tr("task.form.progress.completed") }
        static var progressTitle: String    { tr("task.form.progress.title") }
        static var progressFocused: String  { tr("task.form.progress.focused") }
        static var progressGoal: String     { tr("task.form.progress.goal") }
        static func progressSessions(_ n: Int) -> String {
            tr(n == 1 ? "task.form.progress.session" : "task.form.progress.sessions")
        }
    }

    // MARK: - Timer
    enum Timer {
        static var navTitle: String          { tr("timer.nav.title") }
        static var sessionStay: String       { tr("timer.session.stay") }
        static var sessionRest: String       { tr("timer.session.rest") }
        static var activeTaskLabel: String   { tr("timer.active_task.label") }
        static var activeTaskNone: String    { tr("timer.active_task.none") }
        static var activeTaskNoneSelected: String { tr("timer.active_task.none_selected") }
        static var statusReady: String       { tr("timer.status.ready") }
        static var statusRunning: String     { tr("timer.status.running") }
        static var statusPaused: String      { tr("timer.status.paused") }
        static var statusComplete: String    { tr("timer.status.complete") }
        static func completedToday(_ n: Int) -> String { tr("timer.completed_today", n) }
        static var actionStart: String       { tr("timer.action.start") }
        static var actionPause: String       { tr("timer.action.pause") }
        static var actionResume: String      { tr("timer.action.resume") }
        static var actionStartBreak: String  { tr("timer.action.start_break") }
        static var actionStartFocus: String  { tr("timer.action.start_focus") }
        static var actionReset: String       { tr("timer.action.reset") }
    }

    // MARK: - Session Types
    enum Session {
        static var focus: String      { tr("session.focus") }
        static var shortBreak: String { tr("session.short_break") }
        static var longBreak: String  { tr("session.long_break") }
        static var focusCompletionTitle: String   { tr("session.focus.completion_title") }
        static var focusCompletionMessage: String { tr("session.focus.completion_message") }
        static var breakCompletionTitle: String   { tr("session.break.completion_title") }
        static var breakCompletionMessage: String { tr("session.break.completion_message") }
    }

    // MARK: - Settings
    enum Settings {
        static var navTitle: String          { tr("settings.nav.title") }
        static var sectionDurations: String  { tr("settings.section.durations") }
        static var sectionCycle: String      { tr("settings.section.cycle") }
        static var focus: String             { tr("settings.focus") }
        static var shortBreak: String        { tr("settings.short_break") }
        static var longBreak: String         { tr("settings.long_break") }
        static var longBreakAfter: String    { tr("settings.long_break_after") }
        static func sessionsCount(_ n: Int) -> String { tr("settings.sessions_count", n) }
        static var restoreDefaults: String   { tr("settings.restore_defaults") }
        static var buttonSave: String        { tr("settings.button.save") }
    }

    // MARK: - Calendar
    enum Calendar {
        static var navTitle: String          { tr("calendar.nav.title") }
        static var addTaskAccessibility: String { tr("calendar.add_task_accessibility") }
        static var buttonToday: String       { tr("calendar.button.today") }
        static var eventsEmpty: String       { tr("calendar.events.empty") }
        static var sectionIphoneCalendar: String { tr("calendar.section.iphone_calendar") }
        static var sectionPlannedTasks: String { tr("calendar.section.planned_tasks") }
        static var tasksEmpty: String        { tr("calendar.tasks.empty") }
        static var eventAllDay: String       { tr("calendar.event.all_day") }
        static var permissionDeniedTitle: String   { tr("calendar.permission.denied.title") }
        static var permissionNeededTitle: String   { tr("calendar.permission.needed.title") }
        static var permissionDeniedMessage: String { tr("calendar.permission.denied.message") }
        static var permissionNeededMessage: String { tr("calendar.permission.needed.message") }
        static var permissionButtonSettings: String { tr("calendar.permission.button.settings") }
        static var permissionButtonGrant: String    { tr("calendar.permission.button.grant") }
        static var scheduleHeaderTitle: String      { tr("calendar.schedule.header.title") }
        static func scheduleHeaderSubtitle(_ date: String) -> String { tr("calendar.schedule.header.subtitle", date) }
        static var scheduleFieldTitle: String       { tr("calendar.schedule.field.title") }
        static var scheduleFieldTitlePlaceholder: String { tr("calendar.schedule.field.title.placeholder") }
        static var scheduleFieldDuration: String    { tr("calendar.schedule.field.duration") }
        static var scheduleFieldStartTime: String   { tr("calendar.schedule.field.start_time") }
        static var scheduleFieldStartTimeToggle: String { tr("calendar.schedule.field.start_time.toggle") }
        static var scheduleFieldNotes: String       { tr("calendar.schedule.field.notes") }
        static var scheduleFieldNotesPlaceholder: String { tr("calendar.schedule.field.notes.placeholder") }
        static var scheduleButtonAdd: String        { tr("calendar.schedule.button.add") }
        static var scheduleButtonCancel: String     { tr("calendar.schedule.button.cancel") }
    }

    // MARK: - Scanner
    enum Scanner {
        static var navTitle: String          { tr("scanner.nav.title") }
        static var emptyTitle: String        { tr("scanner.empty.title") }
        static var emptySubtitle: String     { tr("scanner.empty.subtitle") }
        static var buttonNewScan: String     { tr("scanner.button.new_scan") }
        static var actionDelete: String      { tr("scanner.action.delete") }
        static var deleteAlertTitle: String  { tr("scanner.delete.alert.title") }
        static var deleteAlertMessage: String { tr("scanner.delete.alert.message") }
        static var deleteButtonConfirm: String { tr("scanner.delete.button.confirm") }
        static var deleteButtonCancel: String  { tr("scanner.delete.button.cancel") }
        static var errorTitle: String        { tr("scanner.error.title") }
        static func pageCount(_ n: Int) -> String { tr("scanner.page.count", n) }
        static func tasksCreated(_ n: Int) -> String {
            n == 1 ? tr("scanner.task_created") : tr("scanner.tasks_created", n)
        }
    }

    // MARK: - Scan Preview
    enum ScanPreview {
        static var toolbarExtractTasks: String { tr("scan_preview.toolbar.extract_tasks") }
        static func sectionPages(_ n: Int) -> String { tr("scan_preview.section.pages", n) }
        static var pagesEmpty: String          { tr("scan_preview.pages.empty") }
        static var contextEditPage: String     { tr("scan_preview.context.edit_page") }
        static var contextDeletePage: String   { tr("scan_preview.context.delete_page") }
        static var buttonExportPDF: String     { tr("scan_preview.button.export_pdf") }
        static var buttonExtractOCR: String    { tr("scan_preview.button.extract_ocr") }
        static var buttonCompress: String      { tr("scan_preview.button.compress") }
        static var exporting: String           { tr("scan_preview.exporting") }
        static var exportError: String         { tr("scan_preview.export_error") }
        static var ocrError: String            { tr("scan_preview.ocr_error") }
    }

    // MARK: - Compression
    enum Compression {
        static var headerTitle: String    { tr("compression.header.title") }
        static var headerSubtitle: String { tr("compression.header.subtitle") }
        static var fieldQuality: String   { tr("compression.field.quality") }
        static var buttonCompress: String { tr("compression.button.compress") }
        static var buttonCancel: String   { tr("compression.button.cancel") }
        static func progress(_ n: Int) -> String { tr("compression.progress", n) }
        static var errorTitle: String     { tr("compression.error.title") }
    }

    // MARK: - PDF Quality
    enum PDFQuality {
        enum Low {
            static var label: String  { tr("pdf.quality.low.label") }
            static var detail: String { tr("pdf.quality.low.detail") }
            static var hint: String   { tr("pdf.quality.low.hint") }
        }
        enum Medium {
            static var label: String  { tr("pdf.quality.medium.label") }
            static var detail: String { tr("pdf.quality.medium.detail") }
            static var hint: String   { tr("pdf.quality.medium.hint") }
        }
        enum High {
            static var label: String  { tr("pdf.quality.high.label") }
            static var detail: String { tr("pdf.quality.high.detail") }
            static var hint: String   { tr("pdf.quality.high.hint") }
        }
    }

    // MARK: - Edit Scan
    enum EditScan {
        static var navTitle: String          { tr("edit_scan.nav.title") }
        static var buttonCancel: String      { tr("edit_scan.button.cancel") }
        static var buttonApply: String       { tr("edit_scan.button.apply") }
        static var controlFilter: String     { tr("edit_scan.control.filter") }
        static var controlBrightness: String { tr("edit_scan.control.brightness") }
        static var controlContrast: String   { tr("edit_scan.control.contrast") }
        static var controlRotate: String     { tr("edit_scan.control.rotate") }
        static var controlRotateLeft: String { tr("edit_scan.control.rotate_left") }
        static var controlRotateRight: String{ tr("edit_scan.control.rotate_right") }
        static var buttonReset: String       { tr("edit_scan.button.reset") }
    }

    // MARK: - OCR
    enum OCR {
        static var processingTitle: String    { tr("ocr.processing.title") }
        static var stageReading: String       { tr("ocr.processing.stage.reading") }
        static var stageRecognizing: String   { tr("ocr.processing.stage.recognizing") }
        static var stageAnalyzing: String     { tr("ocr.processing.stage.analyzing") }
        static var stageFinishing: String     { tr("ocr.processing.stage.finishing") }
        static var processingCancel: String   { tr("ocr.processing.button.cancel") }
        static var reviewNavTitle: String     { tr("ocr.review.nav.title") }
        static var reviewSelectAll: String    { tr("ocr.review.toolbar.select_all") }
        static func reviewFound(_ n: Int) -> String    { tr("ocr.review.header.found", n) }
        static func reviewSelected(_ n: Int) -> String { tr("ocr.review.header.selected", n) }
        static var reviewRowPlaceholder: String { tr("ocr.review.row.placeholder") }
        static func reviewRowFrom(_ s: String) -> String { tr("ocr.review.row.from", s) }
        static var deadlineNavTitle: String   { tr("ocr.review.deadline.nav.title") }
        static var deadlineRemove: String     { tr("ocr.review.deadline.remove") }
        static var deadlineDone: String       { tr("ocr.review.deadline.done") }
        static var actionCancel: String       { tr("ocr.review.action.cancel") }
        static var actionCreating: String     { tr("ocr.review.action.creating") }
        static func actionCreate(_ n: Int) -> String { tr("ocr.review.action.create", n) }
        static var empty: String              { tr("ocr.review.empty") }
        static var cellExtract: String        { tr("ocr.cell.button.extract") }
        static var confidenceLow: String      { tr("ocr.confidence.low") }
        static var confidenceMedium: String   { tr("ocr.confidence.medium") }
        static var confidenceHigh: String     { tr("ocr.confidence.high") }
        static func durationFormat(_ n: Int) -> String { tr("ocr.duration.format", n) }
        /// Maps a progress value 0–1 to the appropriate stage label.
        static func processingStage(for progress: Double) -> String {
            switch progress {
            case 0..<0.3:  return stageReading
            case 0.3..<0.7: return stageRecognizing
            case 0.7..<0.95: return stageAnalyzing
            default:        return stageFinishing
            }
        }
    }

    // MARK: - Analytics
    enum Analytics {
        static var navTitle: String               { tr("analytics.nav.title") }
        static var exportCSVAccessibility: String { tr("analytics.export_csv.accessibility") }
        static var errorTitle: String             { tr("analytics.error.title") }
        static var metricStreak: String           { tr("analytics.metric.streak") }
        static func metricStreakUnit(_ n: Int) -> String { tr("analytics.metric.streak.unit", n) }
        static var metricTotalTime: String        { tr("analytics.metric.total_time") }
        static var metricDailyAvg: String         { tr("analytics.metric.daily_avg") }
        static func metricDailyAvgValue(_ n: Int) -> String { tr("analytics.metric.daily_avg.value", n) }
        static var metricTotalSessions: String    { tr("analytics.metric.total_sessions") }
        static var bestDayLabel: String           { tr("analytics.best_day.label") }
        static func bestDayHour(_ h: Int) -> String { tr("analytics.best_day.hour", h) }
        static var chartFocusMinutesTitle: String    { tr("analytics.chart.focus_minutes.title") }
        static var chartFocusMinutesSubtitle: String { tr("analytics.chart.focus_minutes.subtitle") }
        static var chartSessionsTitle: String        { tr("analytics.chart.sessions.title") }
        static var chartSessionsSubtitle: String     { tr("analytics.chart.sessions.subtitle") }
        static var heatmapTitle: String           { tr("analytics.heatmap.title") }
        static var heatmapSubtitle: String        { tr("analytics.heatmap.subtitle") }
        static var heatmapLegendLow: String       { tr("analytics.heatmap.legend.low") }
        static func heatmapLegendHigh(_ n: Int) -> String { tr("analytics.heatmap.legend.high", n) }
        static func weekday(_ index: Int) -> String { tr("analytics.heatmap.weekday.\(index)") }
        static var healthKitConnectTitle: String    { tr("analytics.healthkit.connect.title") }
        static var healthKitConnectSubtitle: String { tr("analytics.healthkit.connect.subtitle") }
        static var healthKitConnectButton: String   { tr("analytics.healthkit.connect.button") }
        static var healthKitConnected: String       { tr("analytics.healthkit.connected") }
        static var healthKitDeniedLabel: String     { tr("analytics.healthkit.denied.label") }
        static var healthKitDeniedSettings: String  { tr("analytics.healthkit.denied.settings") }
        static var emptyTitle: String             { tr("analytics.empty.title") }
        static var emptySubtitle: String          { tr("analytics.empty.subtitle") }
        static var rangeWeek: String              { tr("analytics.range.week") }
        static var rangeMonth: String             { tr("analytics.range.month") }
        static var rangeThreeMonths: String       { tr("analytics.range.three_months") }
        static var rangeYear: String              { tr("analytics.range.year") }
        static var rangeAllTime: String           { tr("analytics.range.all_time") }
        static func minutesSummary(_ minutes: Int) -> String {
            let h = minutes / 60, m = minutes % 60
            return h > 0
                ? tr("analytics.minutes.hours_minutes", h, m)
                : tr("analytics.minutes.minutes_only", m)
        }
    }

    // MARK: - Live Activity
    enum LiveActivity {
        static var sessionFocus: String      { tr("live_activity.session.focus") }
        static var sessionShortBreak: String { tr("live_activity.session.short_break") }
        static var sessionLongBreak: String  { tr("live_activity.session.long_break") }
        static func transitionBody(_ minutes: Int) -> String { tr("live_activity.transition.body", minutes) }
        static var paused: String { tr("live_activity.paused") }
    }

    // MARK: - Sound & Focus Panel
    enum Sound {
        static var navTitle: String               { tr("sound.nav.title") }
        static var sectionAmbient: String         { tr("sound.section.ambient") }
        static var sectionTracks: String          { tr("sound.section.tracks") }
        static var playing: String                { tr("sound.playing") }
        static var stopped: String                { tr("sound.stopped") }

        // Focus Mode row
        static var focusModeSection: String       { tr("sound.focus_mode.section") }
        static var focusModeTitle: String         { tr("sound.focus_mode.title") }
        static var focusModeSubtitleAuto: String  { tr("sound.focus_mode.subtitle.auto") }
        static var focusModeSubtitleManual: String{ tr("sound.focus_mode.subtitle.manual") }
        static var focusModeAutoPlay: String      { tr("sound.focus_mode.auto_play") }
        static var focusModeSettingsButton: String{ tr("sound.focus_mode.settings_button") }
        static var focusModeActiveBadge: String   { tr("sound.focus_mode.active_badge") }

        // Focus Settings sheet
        static var focusSettingsNavTitle: String          { tr("sound.focus_settings.nav.title") }
        static var focusSettingsSectionAutomation: String { tr("sound.focus_settings.section.automation") }
        static var focusSettingsAutoActivate: String      { tr("sound.focus_settings.toggle.auto_activate") }
        static var focusSettingsFocusFilter: String       { tr("sound.focus_settings.toggle.focus_filter") }
        static var focusSettingsPauseMusic: String        { tr("sound.focus_settings.toggle.pause_music") }
        static var focusSettingsSectionInterface: String  { tr("sound.focus_settings.section.interface") }
        static var focusSettingsDimLabel: String          { tr("sound.focus_settings.dim_label") }
        static var focusSettingsDimDescription: String    { tr("sound.focus_settings.dim_description") }
        static var focusSettingsSectionSystem: String     { tr("sound.focus_settings.section.system") }
        static var focusSettingsFilterTitle: String       { tr("sound.focus_settings.filter_title") }
        static var focusSettingsFilterDescription: String { tr("sound.focus_settings.filter_description") }
        static var focusSettingsOpenSettings: String      { tr("sound.focus_settings.open_settings") }
        static var focusSettingsButtonSave: String        { tr("sound.focus_settings.button.save") }
        static var focusSettingsButtonCancel: String      { tr("sound.focus_settings.button.cancel") }

        // Tracks
        static var trackRain: String       { tr("sound.track.rain") }
        static var trackCafe: String       { tr("sound.track.cafe") }
        static var trackForest: String     { tr("sound.track.forest") }
        static var trackWhiteNoise: String { tr("sound.track.white_noise") }
    }
}
