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
        let sut = CreateTasksFromOCRUseCase(
            taskManager: taskManager,
            linkRepository: linkRepository,
            scheduledTaskRepository: scheduledRepository
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
        XCTAssertEqual(scheduledRepository.savedTasks.count, 1)
        XCTAssertEqual(scheduledRepository.savedTasks.first?.title, "Write final report")
        XCTAssertEqual(scheduledRepository.savedTasks.first?.scheduledDate, Calendar.current.startOfDay(for: deadline))
        XCTAssertEqual(scheduledRepository.savedTasks.first?.startTime, deadline)
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
