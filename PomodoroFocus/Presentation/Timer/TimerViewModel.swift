import Combine
import CoreGraphics
import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var sessionType: PomodoroSessionType = .focus
    @Published private(set) var status: TimerStatus = .idle
    @Published private(set) var remainingTime: TimeInterval = PomodoroSettings.default.focusDuration
    @Published private(set) var duration: TimeInterval = PomodoroSettings.default.focusDuration
    @Published private(set) var completedSessionsToday: Int = 0
    @Published private(set) var tasks: [PomodoroTask] = []
    @Published var selectedTaskID: UUID?
    @Published private(set) var activeTaskTitle: String = L10n.Timer.activeTaskNoneSelected
    @Published private(set) var progressConfiguration = TimerProgressConfiguration.idle(
        duration: PomodoroSettings.default.focusDuration,
        tint: .focus
    )

    private let pomodoroService: PomodoroServicing
    private let taskManager: TaskManaging
    private let focusModeCoordinator: FocusModeCoordinator
    private var cancellables = Set<AnyCancellable>()
    private var previousStatus: TimerStatus?

    var primaryActionTitle: String {
        switch status {
        case .idle:
            L10n.Timer.actionStart
        case .running:
            L10n.Timer.actionPause
        case .paused:
            L10n.Timer.actionResume
        case .completed:
            sessionType == .focus ? L10n.Timer.actionStartBreak : L10n.Timer.actionStartFocus
        }
    }

    var primaryActionIcon: String {
        status == .running ? "pause.fill" : "play.fill"
    }

    init(
        pomodoroService: PomodoroServicing,
        taskManager: TaskManaging,
        focusModeCoordinator: FocusModeCoordinator
    ) {
        self.pomodoroService = pomodoroService
        self.taskManager = taskManager
        self.focusModeCoordinator = focusModeCoordinator
        self.tasks = taskManager.activeTasks
        self.selectedTaskID = pomodoroService.currentState.selectedTaskID
        self.activeTaskTitle = taskManager.task(id: selectedTaskID)?.title ?? L10n.Timer.activeTaskNoneSelected
        bind()
        update(from: pomodoroService.currentState)
    }

    func onAppear() {
        pomodoroService.refreshTimerState()
    }

    func primaryAction() {
        switch status {
        case .running:
            pomodoroService.pause()
        case .paused:
            pomodoroService.resume()
        case .idle, .completed:
            pomodoroService.start()
        }
    }

    func reset() {
        pomodoroService.reset()
        focusModeCoordinator.onTimerReset()
    }

    func selectTask(id: UUID?) {
        pomodoroService.selectTask(id: id)
    }

    func progressAnimationCompleted() {
        pomodoroService.refreshTimerState()
    }

    private func bind() {
        pomodoroService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.update(from: state)
            }
            .store(in: &cancellables)

        taskManager.tasksPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                guard let self else { return }
                self.tasks = tasks.filter { !$0.isArchived }
                self.activeTaskTitle = self.taskManager.task(id: self.selectedTaskID)?.title ?? L10n.Timer.activeTaskNoneSelected
            }
            .store(in: &cancellables)
    }

    private func update(from state: AppState) {
        handleFocusModeTransition(to: state.status)
        status = state.status
        completedSessionsToday = state.completedSessionsToday
        selectedTaskID = state.selectedTaskID
        let activeTaskID = state.currentSession?.taskID ?? state.selectedTaskID
        activeTaskTitle = taskManager.task(id: activeTaskID)?.title ?? L10n.Timer.activeTaskNoneSelected

        guard let session = state.currentSession else {
            sessionType = .focus
            duration = pomodoroService.settings.focusDuration
            remainingTime = duration
            progressConfiguration = .idle(duration: duration, tint: .focus)
            return
        }

        sessionType = session.type
        duration = session.totalDuration

        switch state.status {
        case .running:
            remainingTime = max(session.endTime.timeIntervalSinceNow, 0)
            progressConfiguration = .running(
                sessionID: session.id,
                startTime: session.startTime,
                endTime: session.endTime,
                totalDuration: session.totalDuration,
                tint: session.type
            )
        case .paused:
            remainingTime = max(state.pausedRemaining ?? session.duration, 0)
            progressConfiguration = .paused(
                sessionID: session.id,
                remainingTime: remainingTime,
                totalDuration: session.totalDuration,
                tint: session.type
            )
        case .completed:
            remainingTime = 0
            progressConfiguration = .completed(sessionID: session.id, tint: session.type)
        case .idle:
            remainingTime = pomodoroService.settings.duration(for: session.type)
            progressConfiguration = .idle(duration: remainingTime, tint: session.type)
        }
    }

    private func handleFocusModeTransition(to newStatus: TimerStatus) {
        defer { previousStatus = newStatus }
        guard previousStatus != newStatus else { return }

        switch (previousStatus, newStatus) {
        case (.some(.paused), .running):
            focusModeCoordinator.onTimerResumed()
        case (.some(.running), .paused):
            focusModeCoordinator.onTimerPaused()
        case (_, .running):
            focusModeCoordinator.onTimerStarted()
        case (.some(.running), .completed), (.some(.paused), .completed):
            focusModeCoordinator.onTimerEnded()
        case (.some(.running), .idle), (.some(.paused), .idle), (.some(.completed), .idle):
            focusModeCoordinator.onTimerReset()
        default:
            break
        }
    }
}

struct TimerProgressConfiguration: Equatable {
    let sessionID: UUID?
    let status: TimerStatus
    let startTime: Date?
    let endTime: Date?
    let remainingTime: TimeInterval
    let totalDuration: TimeInterval
    let tint: PomodoroSessionType

    static func idle(duration: TimeInterval, tint: PomodoroSessionType) -> TimerProgressConfiguration {
        TimerProgressConfiguration(
            sessionID: nil,
            status: .idle,
            startTime: nil,
            endTime: nil,
            remainingTime: duration,
            totalDuration: duration,
            tint: tint
        )
    }

    static func running(
        sessionID: UUID,
        startTime: Date,
        endTime: Date,
        totalDuration: TimeInterval,
        tint: PomodoroSessionType
    ) -> TimerProgressConfiguration {
        TimerProgressConfiguration(
            sessionID: sessionID,
            status: .running,
            startTime: startTime,
            endTime: endTime,
            remainingTime: max(endTime.timeIntervalSinceNow, 0),
            totalDuration: totalDuration,
            tint: tint
        )
    }

    static func paused(
        sessionID: UUID,
        remainingTime: TimeInterval,
        totalDuration: TimeInterval,
        tint: PomodoroSessionType
    ) -> TimerProgressConfiguration {
        TimerProgressConfiguration(
            sessionID: sessionID,
            status: .paused,
            startTime: nil,
            endTime: nil,
            remainingTime: remainingTime,
            totalDuration: totalDuration,
            tint: tint
        )
    }

    static func completed(sessionID: UUID, tint: PomodoroSessionType) -> TimerProgressConfiguration {
        TimerProgressConfiguration(
            sessionID: sessionID,
            status: .completed,
            startTime: nil,
            endTime: nil,
            remainingTime: 0,
            totalDuration: 1,
            tint: tint
        )
    }

    func progress(at date: Date = Date()) -> CGFloat {
        switch status {
        case .idle:
            return 0
        case .paused:
            return clampedProgress(1 - remainingTime / totalDuration)
        case .completed:
            return 1
        case .running:
            guard let endTime else { return 0 }
            return clampedProgress(1 - max(endTime.timeIntervalSince(date), 0) / totalDuration)
        }
    }

    func remaining(at date: Date = Date()) -> TimeInterval {
        switch status {
        case .running:
            guard let endTime else { return remainingTime }
            return max(endTime.timeIntervalSince(date), 0)
        case .idle, .paused, .completed:
            return remainingTime
        }
    }

    private func clampedProgress(_ value: TimeInterval) -> CGFloat {
        CGFloat(min(max(value, 0), 1))
    }
}
