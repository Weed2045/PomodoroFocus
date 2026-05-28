import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var settings: PomodoroSettings
    @Published private(set) var completedSessionsToday: Int
    @Published private(set) var totalFocusTimeToday: TimeInterval
    @Published private(set) var activeSessionTitle: String?
    @Published private(set) var tasks: [PomodoroTask] = []
    @Published private(set) var selectedTaskID: UUID?
    @Published private(set) var gamificationSummary: GamificationSummary = .empty

    private let getSettingsUseCase: GetPomodoroSettingsUseCase
    private let getAppStateUseCase: GetAppStateUseCase
    private let pomodoroService: PomodoroServicing
    private let settingsManager: SettingsManaging
    private let statsManager: StatsManaging
    private let taskManager: TaskManaging
    private let gamificationManager: GamificationManaging
    private var cancellables = Set<AnyCancellable>()

    init(
        getSettingsUseCase: GetPomodoroSettingsUseCase,
        getAppStateUseCase: GetAppStateUseCase,
        pomodoroService: PomodoroServicing,
        settingsManager: SettingsManaging,
        statsManager: StatsManaging,
        taskManager: TaskManaging,
        gamificationManager: GamificationManaging
    ) {
        self.getSettingsUseCase = getSettingsUseCase
        self.getAppStateUseCase = getAppStateUseCase
        self.pomodoroService = pomodoroService
        self.settingsManager = settingsManager
        self.statsManager = statsManager
        self.taskManager = taskManager
        self.gamificationManager = gamificationManager
        self.settings = getSettingsUseCase.execute()
        let state = getAppStateUseCase.execute()
        self.completedSessionsToday = state.completedSessionsToday
        self.totalFocusTimeToday = statsManager.todayStats.totalFocusTime
        self.activeSessionTitle = state.currentSession?.type.title
        self.selectedTaskID = state.selectedTaskID
        self.tasks = taskManager.activeTasks
        self.gamificationSummary = gamificationManager.currentSummary

        settingsManager.settingsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$settings)

        statsManager.todayStatsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.totalFocusTimeToday = stats.totalFocusTime
                self?.completedSessionsToday = stats.completedSessions
            }
            .store(in: &cancellables)

        taskManager.tasksPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.tasks = tasks.filter { !$0.isArchived }
            }
            .store(in: &cancellables)

        gamificationManager.summaryPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$gamificationSummary)

        pomodoroService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.activeSessionTitle = state.status == .idle ? nil : state.currentSession?.type.title
                self?.selectedTaskID = state.selectedTaskID
            }
            .store(in: &cancellables)
    }

    func refresh() {
        pomodoroService.refreshTimerState()
        statsManager.refreshToday()
        settings = getSettingsUseCase.execute()
        gamificationManager.refresh()
        let state = getAppStateUseCase.execute()
        completedSessionsToday = statsManager.todayStats.completedSessions
        totalFocusTimeToday = statsManager.todayStats.totalFocusTime
        activeSessionTitle = state.status == .idle ? nil : state.currentSession?.type.title
        selectedTaskID = state.selectedTaskID
    }

    func createTask(title: String, targetDuration: TimeInterval, notes: String) {
        taskManager.createTask(title: title, targetDuration: targetDuration, notes: notes)
    }

    func updateTask(id: UUID, title: String, targetDuration: TimeInterval, notes: String) {
        taskManager.updateTask(id: id, title: title, targetDuration: targetDuration, notes: notes)
    }

    func deleteTask(id: UUID) {
        taskManager.deleteTask(id: id)
        if selectedTaskID == id {
            selectTask(id: nil)
        }
    }

    func selectTask(id: UUID?) {
        pomodoroService.selectTask(id: id)
    }
}
