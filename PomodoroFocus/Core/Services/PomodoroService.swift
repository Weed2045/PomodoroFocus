import Combine
import Foundation
import UIKit

protocol PomodoroServicing: AnyObject {
    var statePublisher: AnyPublisher<AppState, Never> { get }
    var currentState: AppState { get }
    var settings: PomodoroSettings { get }

    func startFocus()
    func start()
    func pause()
    func resume()
    func reset()
    func refreshTimerState()
    func handleAppDidEnterBackground()
    func selectTask(id: UUID?)
}

final class PomodoroService: PomodoroServicing {
    private let appStateRepository: AppStateRepository
    private let settingsManager: SettingsManaging
    private let statsManager: StatsManaging
    private let taskManager: TaskManaging
    private let gamificationManager: GamificationManaging
    private let notificationService: NotificationScheduling
    private let analyticsRepository: AnalyticsRepositoryProtocol
    private let healthKitSyncUseCase: HealthKitSyncUseCaseProtocol
    private let liveActivityService: LiveActivityServiceProtocol
    private let timerManager: TimerManaging
    private let stateSubject: CurrentValueSubject<AppState, Never>
    private var cancellables = Set<AnyCancellable>()
    private var completionWorkItem: DispatchWorkItem?

    var statePublisher: AnyPublisher<AppState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var currentState: AppState {
        stateSubject.value
    }

    var settings: PomodoroSettings {
        settingsManager.currentSettings
    }

    init(
        appStateRepository: AppStateRepository,
        settingsManager: SettingsManaging,
        statsManager: StatsManaging,
        taskManager: TaskManaging,
        gamificationManager: GamificationManaging,
        notificationService: NotificationScheduling,
        analyticsRepository: AnalyticsRepositoryProtocol,
        healthKitSyncUseCase: HealthKitSyncUseCaseProtocol,
        liveActivityService: LiveActivityServiceProtocol,
        timerManager: TimerManaging = TimerManager()
    ) {
        self.appStateRepository = appStateRepository
        self.settingsManager = settingsManager
        self.statsManager = statsManager
        self.taskManager = taskManager
        self.gamificationManager = gamificationManager
        self.notificationService = notificationService
        self.analyticsRepository = analyticsRepository
        self.healthKitSyncUseCase = healthKitSyncUseCase
        self.liveActivityService = liveActivityService
        self.timerManager = timerManager
        self.stateSubject = CurrentValueSubject(appStateRepository.load())
        bindNotificationActions()
        bindFocusFilterRequests()
        setupAppGroupBridge()
        refreshTimerState()
        scheduleCompletionIfNeeded(for: stateSubject.value)
    }

    func startFocus() {
        startSession(type: .focus)
    }

    func start() {
        if currentState.status == .paused {
            resume()
        } else if currentState.status == .completed, let session = currentState.currentSession {
            startSession(type: nextSessionType(after: session))
        } else if currentState.currentSession == nil {
            startFocus()
        }
    }

    func pause() {
        AppLogger.timer.info("⏸ pause requested — status=\(self.currentState.status.rawValue, privacy: .public)")
        refreshTimerState()
        guard let nextState = timerManager.pause(currentState, now: Date()) else {
            AppLogger.timer.warning("⏸ pause ignored — not in running state")
            return
        }
        persist(nextState)
        notificationService.cancelSessionEndNotification()
        completionWorkItem?.cancel()
        updateLiveActivity(for: nextState)
        AppLogger.timer.info("⏸ paused — remaining=\(String(format: "%.0f", nextState.pausedRemaining ?? 0), privacy: .public)s")
    }

    func resume() {
        AppLogger.timer.info("▶️ resume requested — status=\(self.currentState.status.rawValue, privacy: .public)")
        guard let nextState = timerManager.resume(currentState, now: Date()),
              let resumedSession = nextState.currentSession else {
            AppLogger.timer.warning("▶️ resume ignored — not in paused state")
            return
        }
        persist(nextState)
        notificationService.scheduleSessionEndNotification(for: resumedSession, at: resumedSession.endTime)
        scheduleCompletionIfNeeded(for: nextState)
        updateLiveActivity(for: nextState)
        AppLogger.timer.info("▶️ resumed — type=\(resumedSession.type.rawValue, privacy: .public) remaining=\(String(format: "%.0f", resumedSession.duration), privacy: .public)s")
    }

    func reset() {
        AppLogger.timer.info("⏹ reset — was status=\(self.currentState.status.rawValue, privacy: .public)")
        recordIncompleteSessionIfNeeded()
        let nextState = timerManager.reset(currentState, now: Date())
        persist(nextState)
        notificationService.cancelSessionEndNotification()
        completionWorkItem?.cancel()
        endLiveActivity(.immediate)
    }

    func refreshTimerState() {
        AppLogger.timer.debug("🔄 refreshTimerState called")
        let state = timerManager.resolvedState(from: appStateRepository.load(), now: Date()) { [weak self] session, state in
            guard let self else { return state }
            return complete(session: session, in: state)
        }
        persist(state)
        scheduleCompletionIfNeeded(for: state)
        syncLiveActivityAfterRefresh(state)
        AppLogger.timer.debug("🔄 refreshTimerState → status=\(state.status.rawValue, privacy: .public)")
    }

    func handleAppDidEnterBackground() {
        AppLogger.timer.info("🌙 handleAppDidEnterBackground")
        refreshTimerState()
    }

    func selectTask(id: UUID?) {
        AppLogger.timer.info("🎯 selectTask id=\(id?.uuidString ?? "nil", privacy: .public)")
        var nextState = currentState
        nextState.selectedTaskID = id
        persist(nextState)
    }

    private func startSession(type: PomodoroSessionType) {
        let duration = settings.duration(for: type)
        AppLogger.timer.info("▶️ startSession type=\(type.rawValue, privacy: .public) duration=\(String(format: "%.0f", duration), privacy: .public)s")
        notificationService.requestAuthorization()

        let taskID = type == .focus ? currentState.selectedTaskID : currentState.currentSession?.taskID
        let nextState = timerManager.startSession(type: type, duration: duration, taskID: taskID, from: currentState, now: Date())
        guard let session = nextState.currentSession else {
            AppLogger.timer.error("❌ startSession — no session in state after start")
            return
        }

        persist(nextState)
        notificationService.scheduleSessionEndNotification(for: session, at: session.endTime)
        scheduleCompletionIfNeeded(for: nextState)
        startLiveActivity(for: nextState)
        AppLogger.timer.info("✅ session started — endTime=\(session.endTime, privacy: .public)")
    }

    private func complete(session: PomodoroSession, in state: AppState) -> AppState {
        AppLogger.timer.info("🏁 completing session type=\(session.type.rawValue, privacy: .public) totalDuration=\(String(format: "%.0f", session.totalDuration), privacy: .public)s")
        var nextState = state
        let completedSession = PomodoroSession(
            id: session.id,
            type: session.type,
            duration: session.duration,
            totalDuration: session.totalDuration,
            startTime: session.startTime,
            taskID: session.taskID,
            isCompleted: true
        )
        nextState.currentSession = completedSession
        nextState.status = .completed
        nextState.pausedRemaining = nil
        nextState.lastUpdated = Date()

        if session.type == .focus {
            nextState.completedSessionsToday += 1
            nextState.completedFocusSessionsInCycle += 1
            AppLogger.timer.info("🍅 focus complete — today=\(nextState.completedSessionsToday, privacy: .public) cycle=\(nextState.completedFocusSessionsInCycle, privacy: .public)")
            statsManager.recordCompletedFocusSession(duration: session.totalDuration, completedAt: Date())
            taskManager.recordFocusSession(taskID: session.taskID, duration: session.totalDuration)
            gamificationManager.refresh()
        } else if session.type == .longBreak {
            nextState.completedFocusSessionsInCycle = 0
            AppLogger.timer.info("😴 long break complete — cycle reset")
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        recordFocusSessionHistory(from: session, wasCompleted: true)
        endLiveActivity(.after(5))
        return nextState
    }

    private func recordIncompleteSessionIfNeeded() {
        guard let session = currentState.currentSession,
              currentState.status == .running || currentState.status == .paused else { return }

        let now = Date()
        let elapsed = currentState.status == .paused
            ? max(session.totalDuration - (currentState.pausedRemaining ?? session.duration), 0)
            : min(max(now.timeIntervalSince(session.startTime), 0), session.totalDuration)
        guard elapsed >= 60 else { return }
        let endDate = currentState.status == .paused
            ? session.startTime.addingTimeInterval(elapsed)
            : now
        recordFocusSessionHistory(from: session, wasCompleted: false, endDate: endDate, actualDuration: elapsed)
    }

    private func recordFocusSessionHistory(
        from session: PomodoroSession,
        wasCompleted: Bool,
        endDate: Date? = nil,
        actualDuration: TimeInterval? = nil
    ) {
        let actualEndDate = endDate ?? session.endTime
        let measuredDuration = actualDuration ?? actualEndDate.timeIntervalSince(session.startTime)
        let actualMinutes = max(Int(measuredDuration / 60), wasCompleted ? Int(session.totalDuration / 60) : 0)
        let task = taskManager.task(id: session.taskID)
        let focusSession = FocusSession(
            id: session.id,
            taskID: session.taskID,
            taskTitle: task?.title,
            startDate: session.startTime,
            endDate: actualEndDate,
            durationMinutes: actualMinutes,
            targetDurationMinutes: max(Int(session.totalDuration / 60), 1),
            sessionType: FocusSession.SessionType(session.type),
            wasCompleted: wasCompleted
        )

        Task {
            do {
                try await analyticsRepository.saveSession(focusSession)
                if focusSession.sessionType == .focus && focusSession.wasCompleted {
                    try? await healthKitSyncUseCase.syncSession(focusSession)
                }
            } catch {
                AppLogger.timer.error("❌ save analytics session failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func nextSessionType(after session: PomodoroSession) -> PomodoroSessionType {
        switch session.type {
        case .focus:
            let shouldTakeLongBreak = currentState.completedFocusSessionsInCycle >= settings.sessionsBeforeLongBreak
            let next: PomodoroSessionType = shouldTakeLongBreak ? .longBreak : .shortBreak
            AppLogger.timer.info("➡️ next after focus: \(next.rawValue, privacy: .public) (cycle=\(self.currentState.completedFocusSessionsInCycle, privacy: .public)/\(self.settings.sessionsBeforeLongBreak, privacy: .public))")
            return next
        case .shortBreak:
            AppLogger.timer.info("➡️ next after shortBreak: focus")
            return .focus
        case .longBreak:
            AppLogger.timer.info("➡️ next after longBreak: focus")
            return .focus
        }
    }

    private func persist(_ state: AppState) {
        let normalized = state.normalizedForToday()
        appStateRepository.save(normalized)
        stateSubject.send(normalized)
    }

    private func bindNotificationActions() {
        guard let actionPublisher = notificationService as? NotificationActionPublishing else { return }

        actionPublisher.actionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                self?.handleNotificationAction(action)
            }
            .store(in: &cancellables)
    }

    private func bindFocusFilterRequests() {
        NotificationCenter.default
            .publisher(for: .pomodoroFocusFilterAutoStartRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshTimerState()
                if self.currentState.status == .idle || self.currentState.status == .completed {
                    self.start()
                }
            }
            .store(in: &cancellables)
    }

    private func setupAppGroupBridge() {
        AppGroupBridge.shared.startObserving { [weak self] in
            guard let self else { return }
            switch self.currentState.status {
            case .running:
                self.pause()
            case .paused:
                self.resume()
            case .idle, .completed:
                break
            }
        }
    }

    private func handleNotificationAction(_ action: PomodoroNotificationAction) {
        AppLogger.notify.info("🔔 notification action received: \(String(describing: action), privacy: .public)")
        refreshTimerState()

        switch action {
        case .startBreak:
            guard currentState.status == .completed,
                  currentState.currentSession?.type == .focus,
                  let session = currentState.currentSession else {
                AppLogger.notify.warning("🔔 startBreak action ignored — unexpected state")
                return
            }
            startSession(type: nextSessionType(after: session))
        case .skip:
            reset()
        }
    }

    private func scheduleCompletionIfNeeded(for state: AppState) {
        completionWorkItem?.cancel()

        guard let session = state.currentSession, state.status == .running else { return }

        let delay = max(session.endTime.timeIntervalSinceNow, 0)
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshTimerState()
        }
        completionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func startLiveActivity(for state: AppState) {
        guard let session = state.currentSession, state.status == .running else { return }
        let taskTitle = taskManager.task(id: session.taskID)?.title
        Task {
            try? await liveActivityService.start(
                sessionID: session.id,
                taskTitle: taskTitle,
                targetDuration: max(Int(session.totalDuration), 1),
                remainingSeconds: max(Int(session.endTime.timeIntervalSinceNow), 0),
                sessionType: session.type,
                endDate: session.endTime,
                completedToday: state.completedSessionsToday
            )
        }
    }

    private func updateLiveActivity(for state: AppState) {
        guard let session = state.currentSession else {
            endLiveActivity(.immediate)
            return
        }

        let remaining = state.status == .paused
            ? Int(state.pausedRemaining ?? session.duration)
            : max(Int(session.endTime.timeIntervalSinceNow), 0)
        let isRunning = state.status == .running
        Task {
            await liveActivityService.update(
                sessionID: session.id,
                remainingSeconds: max(remaining, 0),
                isRunning: isRunning,
                endDate: isRunning ? session.endTime : nil,
                completedToday: state.completedSessionsToday
            )
        }
    }

    private func syncLiveActivityAfterRefresh(_ state: AppState) {
        switch state.status {
        case .running, .paused:
            if liveActivityService.isActive {
                updateLiveActivity(for: state)
            } else if state.status == .running {
                startLiveActivity(for: state)
            }
        case .completed:
            updateLiveActivity(for: state)
        case .idle:
            break
        }
    }

    private func endLiveActivity(_ dismissalPolicy: LiveActivityDismissalPolicy) {
        Task {
            await liveActivityService.end(dismissalPolicy: dismissalPolicy)
        }
    }
}
