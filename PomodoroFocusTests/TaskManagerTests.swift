import Combine
import XCTest
@testable import PomodoroFocus

final class TaskManagerTests: XCTestCase {
    private var sut: TaskManager!
    private var repo: InMemoryTaskRepository!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        repo = InMemoryTaskRepository()
        sut = TaskManager(repository: repo)
    }

    override func tearDown() {
        cancellables.removeAll()
        sut = nil
        repo = nil
        super.tearDown()
    }

    // MARK: – createTask

    func test_createTask_addsToActiveTasks() {
        sut.createTask(title: "Write tests", targetDuration: 1500, notes: "")
        XCTAssertEqual(sut.activeTasks.count, 1)
        XCTAssertEqual(sut.activeTasks.first?.title, "Write tests")
    }

    func test_createTask_trimsWhitespace() {
        sut.createTask(title: "  Whitespace  ", targetDuration: 1500, notes: "")
        XCTAssertEqual(sut.activeTasks.first?.title, "Whitespace")
    }

    func test_createTask_emptyTitle_doesNothing() {
        sut.createTask(title: "   ", targetDuration: 1500, notes: "")
        XCTAssertTrue(sut.activeTasks.isEmpty)
    }

    func test_createTask_enforcesMinimumDuration() {
        sut.createTask(title: "Quick", targetDuration: 10, notes: "")
        XCTAssertEqual(sut.activeTasks.first?.targetDuration, 60)
    }

    func test_createTask_persistsToRepository() {
        sut.createTask(title: "Persist me", targetDuration: 1500, notes: "note")
        XCTAssertEqual(repo.savedTasks.count, 1)
    }

    // MARK: – updateTask

    func test_updateTask_changesTitle() {
        sut.createTask(title: "Original", targetDuration: 1500, notes: "")
        let id = sut.activeTasks.first!.id
        sut.updateTask(id: id, title: "Updated", targetDuration: 1500, notes: "")
        XCTAssertEqual(sut.task(id: id)?.title, "Updated")
    }

    func test_updateTask_unknownID_doesNothing() {
        sut.createTask(title: "Task", targetDuration: 1500, notes: "")
        sut.updateTask(id: UUID(), title: "Ghost", targetDuration: 1500, notes: "")
        XCTAssertEqual(sut.activeTasks.count, 1)
        XCTAssertEqual(sut.activeTasks.first?.title, "Task")
    }

    func test_updateTask_reEvaluatesCompletion_whenTargetDecreased() {
        sut.createTask(title: "Task", targetDuration: 3000, notes: "")
        var id: UUID!
        sut.tasksPublisher.first().sink { id = $0.first!.id }.store(in: &cancellables)

        // Manually push some focus time
        sut.recordFocusSession(taskID: id, duration: 2000)
        // Lower the target below accumulated time
        sut.updateTask(id: id, title: "Task", targetDuration: 1500, notes: "")
        XCTAssertEqual(sut.task(id: id)?.isCompleted, true)
    }

    // MARK: – deleteTask (soft-archive)

    func test_deleteTask_archivesIt() {
        sut.createTask(title: "Archive me", targetDuration: 1500, notes: "")
        let id = sut.activeTasks.first!.id
        sut.deleteTask(id: id)
        XCTAssertTrue(sut.activeTasks.isEmpty)
        XCTAssertEqual(repo.savedTasks.first?.isArchived, true)
    }

    // MARK: – recordFocusSession

    func test_recordFocusSession_accumulatesTime() {
        sut.createTask(title: "Focus task", targetDuration: 3000, notes: "")
        let id = sut.activeTasks.first!.id
        sut.recordFocusSession(taskID: id, duration: 1000)
        sut.recordFocusSession(taskID: id, duration: 500)
        XCTAssertEqual(sut.task(id: id)?.totalFocusTime, 1500)
    }

    func test_recordFocusSession_incrementsSessionCount() {
        sut.createTask(title: "Count me", targetDuration: 3000, notes: "")
        let id = sut.activeTasks.first!.id
        sut.recordFocusSession(taskID: id, duration: 500)
        sut.recordFocusSession(taskID: id, duration: 500)
        XCTAssertEqual(sut.task(id: id)?.completedSessions, 2)
    }

    func test_recordFocusSession_autoCompletesWhenTargetMet() {
        sut.createTask(title: "Almost done", targetDuration: 1500, notes: "")
        let id = sut.activeTasks.first!.id
        sut.recordFocusSession(taskID: id, duration: 1500)
        XCTAssertEqual(sut.task(id: id)?.isCompleted, true)
    }

    func test_recordFocusSession_nilTaskID_doesNothing() {
        sut.createTask(title: "Untouched", targetDuration: 1500, notes: "")
        sut.recordFocusSession(taskID: nil, duration: 999)
        XCTAssertEqual(sut.activeTasks.first?.totalFocusTime, 0)
    }

    // MARK: – Publisher

    func test_tasksPublisher_emitsOnCreate() {
        let exp = expectation(description: "publisher fires")
        sut.tasksPublisher
            .dropFirst()   // skip initial empty value
            .sink { tasks in
                if tasks.count == 1 { exp.fulfill() }
            }
            .store(in: &cancellables)
        sut.createTask(title: "New", targetDuration: 1500, notes: "")
        wait(for: [exp], timeout: 1)
    }
}

// MARK: – Test double

final class InMemoryTaskRepository: PomodoroTaskRepository {
    private(set) var savedTasks: [PomodoroTask] = []

    func loadTasks() -> [PomodoroTask] { savedTasks }
    func saveTasks(_ tasks: [PomodoroTask]) { savedTasks = tasks }
}
