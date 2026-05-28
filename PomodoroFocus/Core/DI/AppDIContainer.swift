import Foundation

@MainActor
final class AppDIContainer {
    private let appStateRepository: AppStateRepository
    private let settingsRepository: PomodoroSettingsRepository
    private let dailyStatsRepository: DailyStatsRepository
    private let taskRepository: PomodoroTaskRepository
    private let scheduledTaskRepository: ScheduledTaskRepository
    private let scannedDocumentRepository: ScannedDocumentRepository
    private let analyticsRepository: AnalyticsRepositoryProtocol
    private let ocrRepository: OCRRepositoryProtocol
    private let documentTaskLinkRepository: DocumentTaskLinkRepositoryProtocol
    private let firstLaunchStore: FirstLaunchStore
    private let notificationService: NotificationScheduling
    private let settingsManager: SettingsManaging
    private let statsManager: StatsManaging
    private let taskManager: TaskManaging
    private let gamificationManager: GamificationManaging
    private let eventKitService: EventKitService
    private let pdfExportService: PDFExportService
    private let analyticsComputationService: AnalyticsComputationService
    private let csvExportService: CSVExportService
    private let healthKitService: HealthKitService
    private let healthKitSyncUseCase: HealthKitSyncUseCaseProtocol
    private let liveActivityService: LiveActivityServiceProtocol
    private let visionOCRService: VisionOCRService
    private let nlpTaskExtractionService: NLPTaskExtractionService
    private let performOCRUseCase: PerformOCRUseCaseProtocol
    private let extractTasksUseCase: ExtractTasksUseCaseProtocol
    private let createTasksFromOCRUseCase: CreateTasksFromOCRUseCaseProtocol
    private let ambientAudioEngine: AmbientAudioEngine
    private let audioInterruptionHandler: AudioInterruptionHandler
    private let focusFilterService: FocusFilterService
    private let ambientSoundRepository: AmbientSoundRepositoryProtocol
    private let focusModeCoordinator: FocusModeCoordinator

    let pomodoroService: PomodoroServicing

    init() {
        let defaults = UserDefaults.standard

        // ── CoreData repositories (replaces UserDefaults for growing collections) ──
        let coreDataStack = CoreDataStack.shared
        self.taskRepository          = CoreDataPomodoroTaskRepository(stack: coreDataStack)
        self.scheduledTaskRepository = CoreDataScheduledTaskRepository(stack: coreDataStack)
        self.dailyStatsRepository    = CoreDataDailyStatsRepository(stack: coreDataStack)
        self.analyticsRepository     = CoreDataAnalyticsRepository(stack: coreDataStack)

        // ── UserDefaults repositories (small, single-value settings) ──
        self.appStateRepository         = UserDefaultsAppStateRepository(defaults: defaults)
        self.settingsRepository         = UserDefaultsPomodoroSettingsRepository(defaults: defaults)
        self.scannedDocumentRepository  = FileManagerScannedDocumentRepository(defaults: defaults)
        self.ocrRepository              = OCRRepositoryImpl(defaults: defaults)
        self.documentTaskLinkRepository = DocumentTaskLinkRepositoryImpl(defaults: defaults)
        self.firstLaunchStore           = UserDefaultsFirstLaunchStore(defaults: defaults)

        // ── One-time UserDefaults → CoreData migration ──
        LegacyMigrationService(defaults: defaults).migrateIfNeeded(
            taskRepo:          taskRepository,
            scheduledTaskRepo: scheduledTaskRepository,
            dailyStatsRepo:    dailyStatsRepository,
            analyticsRepo:     analyticsRepository
        )
        self.notificationService        = NotificationManager.shared
        self.settingsManager            = SettingsManager(repository: settingsRepository)
        self.statsManager               = StatsManager(repository: dailyStatsRepository)
        self.taskManager                = TaskManager(repository: taskRepository)
        self.gamificationManager        = GamificationManager(repository: dailyStatsRepository)
        self.eventKitService            = EventKitService()
        self.pdfExportService           = PDFExportService()
        self.analyticsComputationService = AnalyticsComputationService()
        self.csvExportService           = CSVExportService()
        self.healthKitService           = HealthKitService()
        self.healthKitSyncUseCase       = HealthKitSyncUseCase(
            repository: analyticsRepository,
            healthKitService: healthKitService
        )
        if #available(iOS 16.2, *) {
            self.liveActivityService = LiveActivityServiceImpl()
        } else {
            self.liveActivityService = LiveActivityServiceStub()
        }
        self.visionOCRService = VisionOCRService()
        self.nlpTaskExtractionService = NLPTaskExtractionService()
        self.performOCRUseCase = PerformOCRUseCase(
            visionService: visionOCRService,
            repository: ocrRepository
        )
        self.extractTasksUseCase = ExtractTasksUseCase(nlpService: nlpTaskExtractionService)
        self.createTasksFromOCRUseCase = CreateTasksFromOCRUseCase(
            taskManager: taskManager,
            linkRepository: documentTaskLinkRepository
        )
        self.pomodoroService            = PomodoroService(
            appStateRepository: appStateRepository,
            settingsManager: settingsManager,
            statsManager: statsManager,
            taskManager: taskManager,
            gamificationManager: gamificationManager,
            notificationService: notificationService,
            analyticsRepository: analyticsRepository,
            healthKitSyncUseCase: healthKitSyncUseCase,
            liveActivityService: liveActivityService
        )
        self.ambientAudioEngine = AmbientAudioEngine()
        self.audioInterruptionHandler = AudioInterruptionHandler()
        self.focusFilterService = FocusFilterService()
        self.ambientSoundRepository = AmbientSoundRepositoryImpl(defaults: defaults)
        self.focusModeCoordinator = FocusModeCoordinator(
            audioEngine: ambientAudioEngine,
            interruptionHandler: audioInterruptionHandler,
            focusFilterService: focusFilterService,
            repository: ambientSoundRepository
        )
    }

    // MARK: – Factory methods

    func makeSplashViewModel() -> SplashViewModel {
        SplashViewModel(firstLaunchStore: firstLaunchStore)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getSettingsUseCase: GetPomodoroSettingsUseCase(repository: settingsRepository),
            getAppStateUseCase: GetAppStateUseCase(repository: appStateRepository),
            pomodoroService: pomodoroService,
            settingsManager: settingsManager,
            statsManager: statsManager,
            taskManager: taskManager,
            gamificationManager: gamificationManager
        )
    }

    func makeTimerViewModel() -> TimerViewModel {
        TimerViewModel(
            pomodoroService: pomodoroService,
            taskManager: taskManager,
            focusModeCoordinator: focusModeCoordinator
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(settingsManager: settingsManager)
    }

    func makeCalendarViewModel() -> CalendarViewModel {
        CalendarViewModel(
            repository: scheduledTaskRepository,
            eventKitService: eventKitService
        )
    }

    func makeDocumentListViewModel() -> DocumentListViewModel {
        DocumentListViewModel(
            repository: scannedDocumentRepository,
            pdfExportService: pdfExportService,
            ocrRepository: ocrRepository,
            linkRepository: documentTaskLinkRepository,
            ocrViewModel: makeOCRTaskViewModel()
        )
    }

    func makeOCRTaskViewModel() -> OCRTaskViewModel {
        OCRTaskViewModel(
            performOCR: performOCRUseCase,
            extractTasks: extractTasksUseCase,
            createTasks: createTasksFromOCRUseCase
        )
    }

    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        AnalyticsViewModel(
            fetch: FetchAnalyticsUseCase(
                repository: analyticsRepository,
                computationService: analyticsComputationService
            ),
            export: ExportCSVUseCase(
                repository: analyticsRepository,
                exportService: csvExportService
            ),
            health: healthKitSyncUseCase
        )
    }

    func makeAmbientSoundViewModel() -> AmbientSoundViewModel {
        AmbientSoundViewModel(coordinator: focusModeCoordinator)
    }
}
