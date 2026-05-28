import XCTest
@testable import PomodoroFocus

final class CoreDataScheduledTaskRepositoryTests: XCTestCase {
    private var stack: CoreDataStack!
    private var sut: CoreDataScheduledTaskRepository!

    private let cal = Calendar.current

    override func setUp() {
        super.setUp()
        stack = CoreDataStack(inMemory: true)
        sut = CoreDataScheduledTaskRepository(stack: stack)
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: – Helpers

    private func today() -> Date { cal.startOfDay(for: Date()) }

    private func makeTask(title: String = "Task", scheduledDate: Date? = nil) -> ScheduledTask {
        ScheduledTask(title: title, scheduledDate: scheduledDate ?? today())
    }

    // MARK: – save / loadTasks(for:)

    func test_save_and_loadForDate_returnsTask() {
        let task = makeTask(title: "My Task")
        sut.save(task)
        let loaded = sut.loadTasks(for: today())
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "My Task")
    }

    func test_loadForDate_doesNotReturnTasksOnOtherDays() {
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today())!
        sut.save(makeTask(title: "Today"))
        sut.save(makeTask(title: "Tomorrow", scheduledDate: tomorrow))

        let todayTasks = sut.loadTasks(for: today())
        XCTAssertEqual(todayTasks.count, 1)
        XCTAssertEqual(todayTasks[0].title, "Today")
    }

    func test_save_upserts_existingID() {
        var task = makeTask(title: "Original")
        sut.save(task)
        task.title = "Updated"
        sut.save(task)

        let loaded = sut.loadTasks(for: today())
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Updated")
    }

    // MARK: – loadAllTasks

    func test_loadAllTasks_returnsAllDays() {
        let yesterday = cal.date(byAdding: .day, value: -1, to: today())!
        sut.save(makeTask(title: "A"))
        sut.save(makeTask(title: "B", scheduledDate: yesterday))
        XCTAssertEqual(sut.loadAllTasks().count, 2)
    }

    // MARK: – delete

    func test_delete_removesTask() {
        let task = makeTask()
        sut.save(task)
        sut.delete(id: task.id)
        XCTAssertTrue(sut.loadTasks(for: today()).isEmpty)
    }

    func test_delete_unknownID_isIdempotent() {
        sut.save(makeTask())
        sut.delete(id: UUID())
        XCTAssertEqual(sut.loadTasks(for: today()).count, 1)
    }

    // MARK: – hasTasks(on:)

    func test_hasTasks_falseWhenEmpty() {
        XCTAssertFalse(sut.hasTasks(on: today()))
    }

    func test_hasTasks_trueWhenPendingTaskExists() {
        sut.save(makeTask())
        XCTAssertTrue(sut.hasTasks(on: today()))
    }

    func test_hasTasks_falseWhenAllTasksCompleted() {
        var task = makeTask()
        task.isCompleted = true
        sut.save(task)
        XCTAssertFalse(sut.hasTasks(on: today()))
    }
}
