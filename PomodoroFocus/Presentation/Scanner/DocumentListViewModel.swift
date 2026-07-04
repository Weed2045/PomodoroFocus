import Foundation
import UIKit
import VisionKit

@MainActor
final class DocumentListViewModel: ObservableObject {

    // MARK: – Published

    @Published private(set) var documents: [ScannedDocument] = []
    @Published var isShowingCamera = false
    @Published var pendingDocument: ScannedDocument? = nil   // triggers navigation to preview
    @Published var errorMessage: String? = nil
    @Published var selectedOCRDocumentID: UUID? = nil
    @Published private var thumbnails: [UUID: UIImage] = [:]

    // MARK: – Dependencies

    private let repository: ScannedDocumentRepository
    private let ocrRepository: OCRRepositoryProtocol
    private let linkRepository: DocumentTaskLinkRepositoryProtocol
    let pdfExportService: PDFExportService
    let ocrViewModel: OCRTaskViewModel
    private var thumbnailTask: Task<Void, Never>?

    // MARK: – Init

    init(
        repository: ScannedDocumentRepository,
        pdfExportService: PDFExportService,
        ocrRepository: OCRRepositoryProtocol,
        linkRepository: DocumentTaskLinkRepositoryProtocol,
        ocrViewModel: OCRTaskViewModel
    ) {
        self.repository       = repository
        self.pdfExportService = pdfExportService
        self.ocrRepository = ocrRepository
        self.linkRepository = linkRepository
        self.ocrViewModel = ocrViewModel
        reload()
    }

    // MARK: – Actions

    func reload() {
        documents = repository.loadAll()
        loadThumbnails(for: documents)
        AppLogger.scanner.debug("🔄 reload — \(self.documents.count, privacy: .public) documents")
    }

    func startScan() {
        guard VNDocumentCameraViewController.isSupported else {
            AppLogger.scanner.error("❌ startScan — VNDocumentCameraViewController not supported on this device")
            errorMessage = L10n.Scanner.scanUnsupported
            return
        }
        AppLogger.scanner.info("📷 startScan — opening camera")
        isShowingCamera = true
    }

    func cancelScan() {
        AppLogger.scanner.info("📷 cancelScan")
        isShowingCamera = false
    }

    /// Called after VNDocumentCameraViewController returns pages.
    func handleScannedImages(_ images: [UIImage]) {
        AppLogger.scanner.info("📷 handleScannedImages — count=\(images.count, privacy: .public)")
        isShowingCamera = false
        guard !images.isEmpty else {
            AppLogger.scanner.warning("⚠️ handleScannedImages — empty image array, ignoring")
            return
        }

        let repository = repository
        let title = defaultTitle()
        Task { [weak self] in
            let doc = await Task.detached(priority: .userInitiated) {
                var doc = ScannedDocument(title: title)
                for (i, img) in images.enumerated() {
                    let pid = UUID()
                    let fileName = repository.savePageImage(img, pageID: pid)
                    doc.pages.append(ScannedPage(id: pid, imageFileName: fileName, pageIndex: i))
                    AppLogger.scanner.debug("📄 saved page \(i + 1, privacy: .public)/\(images.count, privacy: .public) → \(fileName, privacy: .public)")
                }
                repository.save(doc)
                return doc
            }.value

            guard let self else { return }
            self.reload()
            AppLogger.scanner.info("✅ scan saved — title='\(doc.title, privacy: .public)' pages=\(doc.pageCount, privacy: .public)")
            self.pendingDocument = doc   // triggers navigation
        }
    }

    func delete(_ document: ScannedDocument) {
        AppLogger.scanner.info("🗑 delete document '\(document.title, privacy: .public)'")
        repository.delete(id: document.id)
        Task {
            try? await ocrRepository.deleteOCRResult(documentID: document.id)
            try? await linkRepository.deleteLinks(documentID: document.id)
        }
        reload()
    }

    func thumbnail(for document: ScannedDocument) -> UIImage? {
        thumbnails[document.id]
    }

    // MARK: – Factory

    /// Called by the view once navigation to the preview has been triggered,
    /// so that a subsequent scan to the same document can re-trigger navigation.
    func consumePendingDocument() {
        pendingDocument = nil
    }

    func makePreviewViewModel(for document: ScannedDocument) -> ScanPreviewViewModel {
        ScanPreviewViewModel(
            document: document,
            repository: repository,
            pdfExportService: pdfExportService,
            ocrViewModel: ocrViewModel
        )
    }

    func extractTasks(from document: ScannedDocument) {
        selectedOCRDocumentID = document.id
        let repository = repository
        Task { [weak self] in
            let images = await Task.detached(priority: .userInitiated) {
                Self.renderedImages(for: document, repository: repository)
            }.value

            guard let self else { return }
            guard !images.isEmpty else {
                self.errorMessage = L10n.Scanner.documentNoReadablePages
                return
            }
            self.ocrViewModel.startExtraction(documentID: document.id, source: .images(images))
        }
    }

    // MARK: – Private

    private func defaultTitle() -> String {
        L10n.Scanner.defaultTitle(Date().formatted(.dateTime.month(.abbreviated).day().hour().minute()))
    }

    private func loadThumbnails(for documents: [ScannedDocument]) {
        thumbnailTask?.cancel()
        let repository = repository
        let pageRefs = documents.compactMap { document -> (UUID, String)? in
            guard let first = document.firstPage else { return nil }
            return (document.id, first.imageFileName)
        }

        thumbnailTask = Task.detached(priority: .utility) { [weak self] in
            var loaded: [UUID: UIImage] = [:]
            for (documentID, fileName) in pageRefs {
                guard !Task.isCancelled else { return }
                loaded[documentID] = repository.loadPageImage(fileName: fileName)
            }
            let loadedThumbnails = loaded
            await MainActor.run { [weak self] in
                self?.thumbnails = loadedThumbnails
            }
        }
    }

    nonisolated private static func renderedImages(
        for document: ScannedDocument,
        repository: ScannedDocumentRepository
    ) -> [UIImage] {
        document.pages.compactMap { page in
            guard let base = repository.loadPageImage(fileName: page.imageFileName) else { return nil }
            return ImageProcessingService.apply(
                to: base,
                brightness: page.brightness,
                contrast: page.contrast,
                filter: page.filter,
                rotationDegrees: page.rotationDegrees
            )
        }
    }
}
