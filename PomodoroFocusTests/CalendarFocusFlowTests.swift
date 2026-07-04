import Combine
import XCTest
@testable import PomodoroFocus

@MainActor
final class CalendarFocusFlowTests: XCTestCase {
    func test_addTask_createsLinkedPomodoroTaskAndSchedulesReminder() {
        let repository = CalendarScheduledTaskRepositoryDouble()
        let taskManager = CalendarTaskManagingDouble()
        let pomodoroService = CalendarPomodoroServicingDouble()
        let notificationService = CalendarNotificationSchedulingDouble()
        let sut = makeSUT(
            repository: repository,
            taskManager: taskManager,
            pomodoroService: pomodoroService,
            notificationService: notificationService
        )
        let startTime = Date().addingTimeInterval(3600)

        sut.addTask(title: "Draft proposal", targetDuration: 1500, notes: "outline", startTime: startTime)

        let scheduledTask = repository.savedTasks.first
        XCTAssertEqual(taskManager.createdTasks.first?.title, "Draft proposal")
        XCTAssertEqual(scheduledTask?.pomodoroTaskID, taskManager.createdTasks.first?.id)
        XCTAssertEqual(notificationService.scheduledReminderTaskIDs, [scheduledTask?.id].compactMap { $0 })
    }

    func test_startFocus_createsPomodoroTaskForLegacyScheduledTaskAndStartsTimer() {
        let repository = CalendarScheduledTaskRepositoryDouble()
        let taskManager = CalendarTaskManagingDouble()
        let pomodoroService = CalendarPomodoroServicingDouble()
        let sut = makeSUT(
            repository: repository,
            taskManager: taskManager,
            pomodoroService: pomodoroService,
            notificationService: CalendarNotificationSchedulingDouble()
        )
        let legacyTask = ScheduledTask(
            title: "Read chapter",
            notes: "from calendar",
            targetDuration: 25 * 60,
            scheduledDate: Date()
        )
        repository.save(legacyTask)

        sut.startFocus(task: legacyTask)

        XCTAssertEqual(taskManager.createdTasks.first?.title, "Read chapter")
        XCTAssertEqual(pomodoroService.selectedTaskID, taskManager.createdTasks.first?.id)
        XCTAssertEqual(pomodoroService.startFocusCallCount, 1)
        XCTAssertEqual(repository.savedTasks.first?.pomodoroTaskID, taskManager.createdTasks.first?.id)
    }

    private func makeSUT(
        repository: CalendarScheduledTaskRepositoryDouble,
        taskManager: CalendarTaskManagingDouble,
        pomodoroService: CalendarPomodoroServicingDouble,
        notificationService: CalendarNotificationSchedulingDouble
    ) -> CalendarViewModel {
        CalendarViewModel(
            repository: repository,
            taskManager: taskManager,
            pomodoroService: pomodoroService,
            notificationService: notificationService,
            eventKitService: EventKitService()
        )
    }
}

private final class CalendarScheduledTaskRepositoryDouble: ScheduledTaskRepository {
    private(set) var savedTasks: [ScheduledTask] = []

    func loadTasks(for date: Date) -> [ScheduledTask] {
        savedTasks.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    func loadAllTasks() -> [ScheduledTask] {
        savedTasks
    }

    func save(_ task: ScheduledTask) {
        savedTasks.removeAll { $0.id == task.id }
        savedTasks.append(task)
    }

    func delete(id: UUID) {
        savedTasks.removeAll { $0.id == id }
    }

    func hasTasks(on date: Date) -> Bool {
        savedTasks.contains { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) && !$0.isCompleted }
    }

    func pendingTaskDayKeys(from start: Date, to end: Date) -> Set<String> {
        Set(
            savedTasks
                .filter { !$0.isCompleted && $0.scheduledDate >= start && $0.scheduledDate < end }
                .map { DailyStats.dayKey(for: $0.scheduledDate) }
        )
    }
}

private final class CalendarTaskManagingDouble: TaskManaging {
    private let subject = CurrentValueSubject<[PomodoroTask], Never>([])
    private(set) var createdTasks: [PomodoroTask] = []

    var tasksPublisher: AnyPublisher<[PomodoroTask], Never> {
        subject.eraseToAnyPublisher()
    }

    var activeTasks: [PomodoroTask] {
        subject.value.filter { !$0.isArchived }
    }

    @discardableResult
    func createTask(title: String, targetDuration: TimeInterval, notes: String) -> PomodoroTask? {
        createTaskFromOCR(title: title, targetDuration: targetDuration, notes: notes)
    }

    func createTaskFromOCR(title: String, targetDuration: TimeInterval, notes: String) -> PomodoroTask? {
        let task = PomodoroTask(title: title, notes: notes, targetDuration: targetDuration)
        createdTasks.append(task)
        subject.send([task] + subject.value)
        return task
    }

    func updateTask(id: UUID, title: String, targetDuration: TimeInterval, notes: String) {}
    func deleteTask(id: UUID) {}

    func task(id: UUID?) -> PomodoroTask? {
        guard let id else { return nil }
        return subject.value.first { $0.id == id && !$0.isArchived }
    }

    func recordFocusSession(taskID: UUID?, duration: TimeInterval) {}
}

private final class CalendarPomodoroServicingDouble: PomodoroServicing {
    private let subject = CurrentValueSubject<AppState, Never>(.initial)
    private(set) var selectedTaskID: UUID?
    private(set) var startFocusCallCount = 0

    var statePublisher: AnyPublisher<AppState, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentState: AppState {
        subject.value
    }

    var settings: PomodoroSettings {
        .default
    }

    func startFocus() {
        startFocusCallCount += 1
        var state = subject.value
        state.status = .running
        subject.send(state)
    }

    func start() {}
    func pause() {}
    func resume() {}
    func reset() {}
    func refreshTimerState() {}
    func handleAppDidEnterBackground() {}

    func selectTask(id: UUID?) {
        selectedTaskID = id
        var state = subject.value
        state.selectedTaskID = id
        subject.send(state)
    }
}

private final class CalendarNotificationSchedulingDouble: NotificationScheduling {
    private(set) var scheduledReminderTaskIDs: [UUID] = []
    private(set) var cancelledReminderTaskIDs: [UUID] = []

    func requestAuthorization() {}
    func scheduleSessionEndNotification(for session: PomodoroSession, at date: Date) {}
    func cancelSessionEndNotification() {}

    func scheduleScheduledTaskReminder(for task: ScheduledTask) {
        scheduledReminderTaskIDs.append(task.id)
    }

    func cancelScheduledTaskReminder(taskID: UUID) {
        cancelledReminderTaskIDs.append(taskID)
    }
}
