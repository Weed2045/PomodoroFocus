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
    @Published private(set) var scanSourceLinks: [UUID: DocumentTaskLink] = [:]
    @Published private(set) var sourceDocumentError: String?

    private let getSettingsUseCase: GetPomodoroSettingsUseCase
    private let getAppStateUseCase: GetAppStateUseCase
    private let pomodoroService: PomodoroServicing
    private let settingsManager: SettingsManaging
    private let statsManager: StatsManaging
    private let taskManager: TaskManaging
    private let scheduledTaskRepository: ScheduledTaskRepository
    private let scannedDocumentRepository: ScannedDocumentRepository
    private let linkRepository: DocumentTaskLinkRepositoryProtocol
    private let gamificationManager: GamificationManaging
    private var cancellables = Set<AnyCancellable>()
    private var linkLoadTask: Task<Void, Never>?

    init(
        getSettingsUseCase: GetPomodoroSettingsUseCase,
        getAppStateUseCase: GetAppStateUseCase,
        pomodoroService: PomodoroServicing,
        settingsManager: SettingsManaging,
        statsManager: StatsManaging,
        taskManager: TaskManaging,
        scheduledTaskRepository: ScheduledTaskRepository,
        scannedDocumentRepository: ScannedDocumentRepository,
        linkRepository: DocumentTaskLinkRepositoryProtocol,
        gamificationManager: GamificationManaging
    ) {
        self.getSettingsUseCase = getSettingsUseCase
        self.getAppStateUseCase = getAppStateUseCase
        self.pomodoroService = pomodoroService
        self.settingsManager = settingsManager
        self.statsManager = statsManager
        self.taskManager = taskManager
        self.scheduledTaskRepository = scheduledTaskRepository
        self.scannedDocumentRepository = scannedDocumentRepository
        self.linkRepository = linkRepository
        self.gamificationManager = gamificationManager
        self.settings = getSettingsUseCase.execute()
        let state = getAppStateUseCase.execute()
        self.completedSessionsToday = state.completedSessionsToday
        self.totalFocusTimeToday = statsManager.todayStats.totalFocusTime
        self.activeSessionTitle = state.currentSession?.type.title
        self.selectedTaskID = state.selectedTaskID
        self.tasks = taskManager.activeTasks
        self.gamificationSummary = gamificationManager.currentSummary
        loadScanSourceLinks(for: self.tasks)

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
                guard let self else { return }
                let activeTasks = tasks.filter { !$0.isArchived }
                self.tasks = activeTasks
                self.loadScanSourceLinks(for: activeTasks)
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
        loadScanSourceLinks(for: tasks)
    }

    func createTask(title: String, targetDuration: TimeInterval, notes: String) {
        taskManager.createTask(title: title, targetDuration: targetDuration, notes: notes)
    }

    func planToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let plannedTaskIDs = Set(
            scheduledTaskRepository
                .loadTasks(for: today)
                .compactMap(\.pomodoroTaskID)
        )
        let candidates = taskManager.activeTasks
            .filter { !$0.isCompleted && !plannedTaskIDs.contains($0.id) }
            .prefix(5)

        for task in candidates {
            scheduledTaskRepository.save(
                ScheduledTask(
                    title: task.title,
                    notes: task.notes,
                    targetDuration: task.targetDuration,
                    scheduledDate: today,
                    pomodoroTaskID: task.id
                )
            )
        }

        return candidates.count
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

    func hasScanSource(for taskID: UUID) -> Bool {
        scanSourceLinks[taskID] != nil
    }

    func openSourceDocument(for taskID: UUID) {
        guard let documentID = scanSourceLinks[taskID]?.documentID,
              scannedDocumentRepository.load(id: documentID) != nil else {
            sourceDocumentError = L10n.Home.sourceDocumentMissingMessage
            return
        }

        NotificationCenter.default.post(
            name: .openScannedDocument,
            object: nil,
            userInfo: [AppNavigationUserInfoKey.documentID: documentID]
        )
    }

    func clearSourceDocumentError() {
        sourceDocumentError = nil
    }

    private func loadScanSourceLinks(for tasks: [PomodoroTask]) {
        linkLoadTask?.cancel()
        let taskIDs = tasks.map(\.id)
        let linkRepository = linkRepository

        linkLoadTask = Task { [weak self] in
            var linksByTaskID: [UUID: DocumentTaskLink] = [:]
            for taskID in taskIDs {
                guard !Task.isCancelled else { return }
                let links = (try? await linkRepository.fetchLinks(taskID: taskID)) ?? []
                if let newest = links.sorted(by: { $0.createdAt > $1.createdAt }).first {
                    linksByTaskID[taskID] = newest
                }
            }

            guard !Task.isCancelled else { return }
            self?.scanSourceLinks = linksByTaskID
        }
    }
}
