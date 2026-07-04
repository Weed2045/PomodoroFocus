import XCTest
@testable import PomodoroFocus

final class OCRTaskPipelineTests: XCTestCase {
    func test_extractTasks_detectsDeadlineAndEstimatedDurationFromOCRText() async {
        let sut = NLPTaskExtractionService()
        let documentID = UUID()

        let items = await sut.extractTasks(
            from: """
            ☐ Lam bao cao truoc ngay 31/12/2026.
            TODO: Call client.
            """,
            documentID: documentID,
            language: "vi"
        )

        let report = items.first { $0.rawLine.contains("bao cao") }
        XCTAssertEqual(report?.title, "Lam bao cao")
        XCTAssertEqual(report?.estimatedMinutes, 50)
        XCTAssertNotNil(report?.deadline)
        XCTAssertEqual(report?.confidence, .high)
    }

    @MainActor
    func test_createTasksFromOCR_createsTaskLinkAndScheduledTaskForDeadline() async throws {
        let taskRepository = PomodoroTaskRepositoryDouble()
        let taskManager = TaskManager(repository: taskRepository)
        let linkRepository = DocumentTaskLinkRepositoryDouble()
        let scheduledRepository = ScheduledTaskRepositoryDouble()
        let notificationService = OCRNotificationSchedulingDouble()
        let sut = CreateTasksFromOCRUseCase(
            taskManager: taskManager,
            linkRepository: linkRepository,
            scheduledTaskRepository: scheduledRepository,
            notificationService: notificationService
        )
        let documentID = UUID()
        let calendar = Calendar(identifier: .gregorian)
        let deadline = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 9))!
        let item = ExtractedTaskItem(
            id: UUID(),
            title: "Write final report",
            deadline: deadline,
            estimatedMinutes: 50,
            confidence: .high,
            isSelected: true,
            sourceRange: NSRange(location: 0, length: 18),
            rawLine: "TODO: Write final report due 31/12/2026"
        )

        let created = try await sut.execute(items: [item], documentID: documentID)

        XCTAssertEqual(created.count, 1)
        XCTAssertEqual(taskRepository.savedTasks.first?.title, "Write final report")
        XCTAssertEqual(linkRepository.links.first?.documentID, documentID)
        XCTAssertEqual(linkRepository.links.first?.taskID, created.first?.id)
        XCTAssertEqual(linkRepository.links.first?.sourceText, item.rawLine)
        XCTAssertEqual(linkRepository.links.first?.taskTitle, item.title)
        XCTAssertEqual(linkRepository.links.first?.deadline, deadline)
        XCTAssertEqual(linkRepository.links.first?.estimatedMinutes, 50)
        XCTAssertEqual(scheduledRepository.savedTasks.count, 1)
        XCTAssertEqual(scheduledRepository.savedTasks.first?.title, "Write final report")
        XCTAssertEqual(scheduledRepository.savedTasks.first?.pomodoroTaskID, created.first?.id)
        XCTAssertEqual(scheduledRepository.savedTasks.first?.scheduledDate, Calendar.current.startOfDay(for: deadline))
        XCTAssertEqual(scheduledRepository.savedTasks.first?.startTime, deadline)
        XCTAssertEqual(notificationService.scheduledTaskIDs, scheduledRepository.savedTasks.map(\.id))
    }

    func test_searchOCRResults_matchesCachedRawText() async throws {
        let suiteName = "OCRRepositorySearchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sut = OCRRepositoryImpl(defaults: defaults)
        let documentID = UUID()
        try await sut.saveOCRResult(
            OCRResult(
                documentID: documentID,
                rawText: "Meeting notes\nTODO: prepare contract summary before Friday",
                pages: [],
                extractedItems: [],
                processingDuration: 0.1
            )
        )

        let matches = try await sut.searchOCRResults(matching: "contract")

        XCTAssertEqual(matches.map(\.documentID), [documentID])
        XCTAssertTrue(matches.first?.snippet.localizedCaseInsensitiveContains("contract") == true)
        try await sut.deleteOCRResult(documentID: documentID)
    }
}

private final class PomodoroTaskRepositoryDouble: PomodoroTaskRepository {
    private(set) var savedTasks: [PomodoroTask] = []

    func loadTasks() -> [PomodoroTask] {
        savedTasks
    }

    func saveTasks(_ tasks: [PomodoroTask]) {
        savedTasks = tasks
    }
}

private final class DocumentTaskLinkRepositoryDouble: DocumentTaskLinkRepositoryProtocol {
    private(set) var links: [DocumentTaskLink] = []

    func saveLink(_ link: DocumentTaskLink) async throws {
        links.append(link)
    }

    func fetchLinks(documentID: UUID) async throws -> [DocumentTaskLink] {
        links.filter { $0.documentID == documentID }
    }

    func fetchLinks(taskID: UUID) async throws -> [DocumentTaskLink] {
        links.filter { $0.taskID == taskID }
    }

    func deleteLinks(documentID: UUID) async throws {
        links.removeAll { $0.documentID == documentID }
    }

    func deleteLink(id: UUID) async throws {
        links.removeAll { $0.id == id }
    }
}

private final class ScheduledTaskRepositoryDouble: ScheduledTaskRepository {
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

private final class OCRNotificationSchedulingDouble: NotificationScheduling {
    private(set) var scheduledTaskIDs: [UUID] = []
    private(set) var cancelledTaskIDs: [UUID] = []

    func requestAuthorization() {}
    func scheduleSessionEndNotification(for session: PomodoroSession, at date: Date) {}
    func cancelSessionEndNotification() {}

    func scheduleScheduledTaskReminder(for task: ScheduledTask) {
        scheduledTaskIDs.append(task.id)
    }

    func cancelScheduledTaskReminder(taskID: UUID) {
        cancelledTaskIDs.append(taskID)
    }
}
