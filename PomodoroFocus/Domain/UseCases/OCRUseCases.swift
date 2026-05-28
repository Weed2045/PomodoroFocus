import UIKit

enum OCRSource {
    case images([UIImage])
    case cachedResult(OCRResult)
}

protocol PerformOCRUseCaseProtocol {
    func execute(
        documentID: UUID,
        source: OCRSource,
        progressHandler: ((Double) -> Void)?
    ) async throws -> OCRResult
}

protocol ExtractTasksUseCaseProtocol {
    func execute(from text: String, documentID: UUID, language: String?) async -> [ExtractedTaskItem]
}

protocol CreateTasksFromOCRUseCaseProtocol {
    func execute(items: [ExtractedTaskItem], documentID: UUID) async throws -> [PomodoroTask]
}

final class PerformOCRUseCase: PerformOCRUseCaseProtocol {
    private let visionService: VisionOCRService
    private let repository: OCRRepositoryProtocol

    init(visionService: VisionOCRService, repository: OCRRepositoryProtocol) {
        self.visionService = visionService
        self.repository = repository
    }

    func execute(
        documentID: UUID,
        source: OCRSource,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> OCRResult {
        if case .cachedResult(let cached) = source {
            return cached
        }
        if let cached = try await repository.fetchOCRResult(documentID: documentID) {
            progressHandler?(1)
            return cached
        }

        let startedAt = Date()
        let pages = try await visionService.recognizeText(from: source, progressHandler: progressHandler)
        let rawText = pages.map(\.text).joined(separator: "\n\n--- Page Break ---\n\n")
        let result = OCRResult(
            documentID: documentID,
            rawText: rawText,
            pages: pages,
            extractedItems: [],
            processingDuration: Date().timeIntervalSince(startedAt)
        )
        try await repository.saveOCRResult(result)
        return result
    }
}

final class ExtractTasksUseCase: ExtractTasksUseCaseProtocol {
    private let nlpService: NLPTaskExtractionService

    init(nlpService: NLPTaskExtractionService) {
        self.nlpService = nlpService
    }

    func execute(from text: String, documentID: UUID, language: String?) async -> [ExtractedTaskItem] {
        await nlpService.extractTasks(from: text, documentID: documentID, language: language)
    }
}

final class CreateTasksFromOCRUseCase: CreateTasksFromOCRUseCaseProtocol {
    private let taskManager: TaskManaging
    private let linkRepository: DocumentTaskLinkRepositoryProtocol

    init(taskManager: TaskManaging, linkRepository: DocumentTaskLinkRepositoryProtocol) {
        self.taskManager = taskManager
        self.linkRepository = linkRepository
    }

    func execute(items: [ExtractedTaskItem], documentID: UUID) async throws -> [PomodoroTask] {
        let selectedItems = items.filter { $0.isSelected && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var created: [PomodoroTask] = []

        for item in selectedItems {
            var noteLines = ["Source document: \(documentID.uuidString)"]
            if let deadline = item.deadline {
                noteLines.append("Deadline: \(deadline.formatted(date: .abbreviated, time: .shortened))")
            }
            let notes = noteLines.joined(separator: "\n")
            guard let task = await MainActor.run(body: {
                taskManager.createTaskFromOCR(
                    title: item.title,
                    targetDuration: TimeInterval(max(item.estimatedMinutes, 1) * 60),
                    notes: notes
                )
            }) else {
                continue
            }

            let link = DocumentTaskLink(
                documentID: documentID,
                taskID: task.id,
                sourceRange: item.sourceRange
            )
            try await linkRepository.saveLink(link)
            created.append(task)
        }

        return created
    }
}
