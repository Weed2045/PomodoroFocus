import Foundation
import UIKit

@MainActor
final class OCRTaskViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case processing(progress: Double)
        case reviewing
        case creating
        case success(taskCount: Int)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var extractedItems: [ExtractedTaskItem] = []
    @Published var showReviewSheet = false
    @Published var rawTextPreview = ""

    private let performOCR: PerformOCRUseCaseProtocol
    private let extractTasks: ExtractTasksUseCaseProtocol
    private let createTasks: CreateTasksFromOCRUseCaseProtocol
    private var extractionTask: Task<Void, Never>?

    init(
        performOCR: PerformOCRUseCaseProtocol,
        extractTasks: ExtractTasksUseCaseProtocol,
        createTasks: CreateTasksFromOCRUseCaseProtocol
    ) {
        self.performOCR = performOCR
        self.extractTasks = extractTasks
        self.createTasks = createTasks
    }

    var selectedCount: Int {
        extractedItems.filter(\.isSelected).count
    }

    func startExtraction(documentID: UUID, source: OCRSource) {
        extractionTask?.cancel()
        extractionTask = Task {
            await runExtraction(documentID: documentID, source: source)
        }
    }

    func cancelExtraction() {
        extractionTask?.cancel()
        state = .idle
    }

    func toggleItem(_ id: UUID) {
        guard let index = extractedItems.firstIndex(where: { $0.id == id }) else { return }
        extractedItems[index].isSelected.toggle()
    }

    func updateTitle(_ id: UUID, newTitle: String) {
        guard let index = extractedItems.firstIndex(where: { $0.id == id }) else { return }
        extractedItems[index].title = newTitle
    }

    func updateDeadline(_ id: UUID, date: Date?) {
        guard let index = extractedItems.firstIndex(where: { $0.id == id }) else { return }
        extractedItems[index].deadline = date
    }

    func updateDuration(_ id: UUID, minutes: Int) {
        guard let index = extractedItems.firstIndex(where: { $0.id == id }) else { return }
        extractedItems[index].estimatedMinutes = minutes
    }

    func deleteItem(_ id: UUID) {
        extractedItems.removeAll { $0.id == id }
    }

    func selectAll() {
        extractedItems.indices.forEach { extractedItems[$0].isSelected = true }
    }

    func confirmCreation(documentID: UUID) {
        Task {
            state = .creating
            do {
                let tasks = try await createTasks.execute(items: extractedItems, documentID: documentID)
                showReviewSheet = false
                state = .success(taskCount: tasks.count)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if case .success = state {
                    state = .idle
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    private func runExtraction(documentID: UUID, source: OCRSource) async {
        state = .processing(progress: 0.05)
        do {
            let result = try await performOCR.execute(
                documentID: documentID,
                source: source,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.state = .processing(progress: min(progress * 0.65, 0.65))
                    }
                }
            )
            try Task.checkCancellation()

            rawTextPreview = String(result.rawText.prefix(2_000))
            state = .processing(progress: 0.75)

            let items = await extractTasks.execute(from: result.rawText, documentID: documentID, language: nil)
            try Task.checkCancellation()

            extractedItems = items
            state = .processing(progress: 1)

            if items.isEmpty {
                state = .error("Khong tim thay task nao trong tai lieu nay.")
            } else {
                state = .reviewing
                showReviewSheet = true
            }
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

