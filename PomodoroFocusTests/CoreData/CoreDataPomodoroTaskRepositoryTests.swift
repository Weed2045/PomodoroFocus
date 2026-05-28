import CoreData
import XCTest
@testable import PomodoroFocus

final class CoreDataPomodoroTaskRepositoryTests: XCTestCase {
    private var stack: CoreDataStack!
    private var sut: CoreDataPomodoroTaskRepository!

    override func setUp() {
        super.setUp()
        stack = CoreDataStack(inMemory: true)
        sut = CoreDataPomodoroTaskRepository(stack: stack)
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: – Helpers

    private func makeTask(title: String = "Task", targetDuration: TimeInterval = 1500) -> PomodoroTask {
        PomodoroTask(title: title, targetDuration: targetDuration)
    }

    // MARK: – loadTasks

    func test_loadTasks_emptyInitially() {
        XCTAssertTrue(sut.loadTasks().isEmpty)
    }

    // MARK: – saveTasks / loadTasks round-trip

    func test_saveTasks_persistsAllFields() {
        let task = makeTask(title: "Deep Work", targetDuration: 3000)
        sut.saveTasks([task])

        let loaded = sut.loadTasks()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, task.id)
        XCTAssertEqual(loaded[0].title, "Deep Work")
        XCTAssertEqual(loaded[0].targetDuration, 3000)
        XCTAssertFalse(loaded[0].isCompleted)
        XCTAssertFalse(loaded[0].isArchived)
    }

    func test_saveTasks_multipleTasks() {
        let tasks = (1...5).map { makeTask(title: "Task \($0)") }
        sut.saveTasks(tasks)
        XCTAssertEqual(sut.loadTasks().count, 5)
    }

    func test_saveTasks_upserts_existingTask() {
        var task = makeTask(title: "Before")
        sut.saveTasks([task])

        task.title = "After"
        sut.saveTasks([task])

        let loaded = sut.loadTasks()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "After")
    }

    func test_saveTasks_deletesRemovedTasks() {
        let t1 = makeTask(title: "Keep")
        let t2 = makeTask(title: "Remove")
        sut.saveTasks([t1, t2])

        // Save only t1
        sut.saveTasks([t1])
        let loaded = sut.loadTasks()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Keep")
    }

    func test_saveTasks_emptyList_deletesAll() {
        sut.saveTasks([makeTask(), makeTask()])
        sut.saveTasks([])
        XCTAssertTrue(sut.loadTasks().isEmpty)
    }

    // MARK: – Boolean fields

    func test_saveTasks_preserves_isCompleted() {
        var task = makeTask()
        task.isCompleted = true
        sut.saveTasks([task])
        XCTAssertEqual(sut.loadTasks().first?.isCompleted, true)
    }

    func test_saveTasks_preserves_isArchived() {
        var task = makeTask()
        task.isArchived = true
        sut.saveTasks([task])
        XCTAssertEqual(sut.loadTasks().first?.isArchived, true)
    }

    // MARK: – Notes (optional)

    func test_saveTasks_emptyNotes_storedAsNil() {
        let task = PomodoroTask(title: "Task", notes: "")
        sut.saveTasks([task])
        // Domain model returns "" for nil notes — that's fine
        XCTAssertEqual(sut.loadTasks().first?.notes, "")
    }

    func test_saveTasks_nonEmptyNotes_preserved() {
        let task = PomodoroTask(title: "Task", notes: "Some note")
        sut.saveTasks([task])
        XCTAssertEqual(sut.loadTasks().first?.notes, "Some note")
    }
}
