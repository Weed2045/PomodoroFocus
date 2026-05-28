import Combine
import EventKit
import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {

    // MARK: – Published state

    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    @Published private(set) var scheduledTasks: [ScheduledTask] = []
    @Published private(set) var calendarEvents: [EKEvent] = []

    // MARK: – Dependencies

    private let repository: ScheduledTaskRepository
    let eventKitService: EventKitService

    // MARK: – Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: – Init

    init(repository: ScheduledTaskRepository, eventKitService: EventKitService) {
        self.repository = repository
        self.eventKitService = eventKitService

        // Forward EventKitService changes (e.g. authorizationStatus) so CalendarView re-renders.
        eventKitService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        reload()
    }

    // MARK: – Navigation

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
        AppLogger.calendar.debug("📅 selectDate → \(self.selectedDate.formatted(.dateTime.year().month().day()), privacy: .public)")
        reload()
    }

    func navigateMonth(by offset: Int) {
        guard let newMonth = Calendar.current.date(
            byAdding: .month, value: offset, to: displayedMonth
        ) else { return }
        displayedMonth = newMonth
        AppLogger.calendar.debug("📅 navigateMonth offset=\(offset, privacy: .public) → \(self.monthYearString, privacy: .public)")
    }

    func goToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        selectedDate = today
        displayedMonth = today
        AppLogger.calendar.debug("📅 goToToday")
        reload()
    }

    // MARK: – Calendar access

    func requestCalendarAccess() async {
        AppLogger.calendar.info("📅 requestCalendarAccess — current status=\(self.eventKitService.authorizationStatus.rawValue, privacy: .public)")
        await eventKitService.requestAccess()
        AppLogger.calendar.info("📅 requestCalendarAccess done — new status=\(self.eventKitService.authorizationStatus.rawValue, privacy: .public)")
        reload()
    }

    /// Refresh status after the user returns from iOS Settings.
    func refreshAfterSettingsReturn() {
        AppLogger.calendar.debug("📅 refreshAfterSettingsReturn")
        eventKitService.refreshStatus()
        reload()
    }

    // MARK: – Task CRUD

    func addTask(title: String, targetDuration: TimeInterval, notes: String, startTime: Date?) {
        AppLogger.calendar.info("📅 addTask '\(title, privacy: .public)' duration=\(targetDuration, privacy: .public)s date=\(self.selectedDate.formatted(.dateTime.year().month().day()), privacy: .public)")
        let task = ScheduledTask(
            title: title,
            notes: notes,
            targetDuration: max(targetDuration, 60),
            scheduledDate: selectedDate,
            startTime: startTime
        )
        repository.save(task)
        reload()
    }

    func deleteTask(id: UUID) {
        AppLogger.calendar.info("📅 deleteTask id=\(id.uuidString, privacy: .public)")
        repository.delete(id: id)
        reload()
    }

    func toggleComplete(task: ScheduledTask) {
        AppLogger.calendar.info("📅 toggleComplete '\(task.title, privacy: .public)' → \(!task.isCompleted, privacy: .public)")
        var updated = task
        updated.isCompleted.toggle()
        updated.updatedAt = Date()
        repository.save(updated)
        reload()
    }

    // MARK: – Calendar grid helpers

    /// Returns an array of optional Dates filling the month grid (Mon-first).
    /// `nil` entries represent padding cells before the 1st of the month.
    func datesInDisplayedMonth() -> [Date?] {
        let cal = Calendar.current
        guard let startOfMonth = cal.date(
            from: cal.dateComponents([.year, .month], from: displayedMonth)
        ) else { return [] }

        let range = cal.range(of: .day, in: .month, for: startOfMonth) ?? 1..<2

        // Weekday of the 1st: Sun=1…Sat=7 → convert to Mon=0…Sun=6
        let firstWeekday = cal.component(.weekday, from: startOfMonth)
        let offset = (firstWeekday + 5) % 7   // Mon-first

        var dates: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = cal.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                dates.append(date)
            }
        }
        return dates
    }

    func hasTasks(on date: Date) -> Bool {
        repository.hasTasks(on: date)
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    func isInDisplayedMonth(_ date: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.month, from: date) == cal.component(.month, from: displayedMonth)
            && cal.component(.year, from: date) == cal.component(.year, from: displayedMonth)
    }

    // MARK: – Formatted strings

    var monthYearString: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    var selectedDayString: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today · " + selectedDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
        }
        return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    // MARK: – Private

    private func reload() {
        scheduledTasks = repository.loadTasks(for: selectedDate)
        if eventKitService.isAuthorized {
            calendarEvents = eventKitService.fetchEvents(for: selectedDate)
        } else {
            calendarEvents = []
        }
        AppLogger.calendar.debug("📅 reload — tasks=\(self.scheduledTasks.count, privacy: .public) events=\(self.calendarEvents.count, privacy: .public) date=\(self.selectedDate.formatted(.dateTime.year().month().day()), privacy: .public)")
    }
}
