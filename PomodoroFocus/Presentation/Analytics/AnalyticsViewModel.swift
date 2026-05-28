import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedRange: AnalyticsRange = .week
    @Published var analyticsData: AnalyticsData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var exportURL: URL?
    @Published var showShareSheet = false
    @Published var isExporting = false

    @Published var healthKitStatus: HealthKitStatus = .unknown

    enum HealthKitStatus {
        case unknown
        case authorized
        case denied
        case unavailable
    }

    private let fetchAnalyticsUseCase: FetchAnalyticsUseCaseProtocol
    private let exportCSVUseCase: ExportCSVUseCaseProtocol
    private let healthKitSyncUseCase: HealthKitSyncUseCaseProtocol
    private var loadTask: Task<Void, Never>?

    init(
        fetch: FetchAnalyticsUseCaseProtocol,
        export: ExportCSVUseCaseProtocol,
        health: HealthKitSyncUseCaseProtocol
    ) {
        self.fetchAnalyticsUseCase = fetch
        self.exportCSVUseCase = export
        self.healthKitSyncUseCase = health
    }

    func onAppear() {
        loadAnalytics()
        checkHealthKitStatus()
    }

    func rangeChanged(_ range: AnalyticsRange) {
        selectedRange = range
        loadAnalytics()
    }

    func loadAnalytics() {
        loadTask?.cancel()
        loadTask = Task { [selectedRange] in
            isLoading = true
            errorMessage = nil
            do {
                let data = try await fetchAnalyticsUseCase.execute(range: selectedRange)
                guard !Task.isCancelled else { return }
                analyticsData = data
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func exportCSV() {
        Task {
            isExporting = true
            defer { isExporting = false }

            do {
                exportURL = try await exportCSVUseCase.execute()
                showShareSheet = true
            } catch {
                errorMessage = "Không thể xuất file: \(error.localizedDescription)"
            }
        }
    }

    func requestHealthKitAccess() {
        Task {
            do {
                let granted = try await healthKitSyncUseCase.requestAuthorization()
                healthKitStatus = granted ? .authorized : .denied
                if granted {
                    try await healthKitSyncUseCase.syncPendingSessions()
                }
            } catch {
                healthKitStatus = .denied
            }
        }
    }

    private func checkHealthKitStatus() {
        guard healthKitSyncUseCase.isAvailable else {
            healthKitStatus = .unavailable
            return
        }

        healthKitStatus = healthKitSyncUseCase.authorizationGranted ? .authorized : .unknown
    }
}

