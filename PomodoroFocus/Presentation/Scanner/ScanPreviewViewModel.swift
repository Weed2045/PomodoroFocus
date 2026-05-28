import UIKit

@MainActor
final class ScanPreviewViewModel: ObservableObject {

    // MARK: – Published

    @Published var document: ScannedDocument
    @Published private(set) var renderedImages: [UUID: UIImage] = [:]
    @Published var exportURL: URL? = nil
    @Published var isExporting = false
    @Published var errorMessage: String? = nil

    // MARK: – Dependencies

    let repository: ScannedDocumentRepository
    let pdfExportService: PDFExportService
    let ocrViewModel: OCRTaskViewModel

    /// Internal cache of the base (uncompressed) PDF URL.
    /// Kept private and non-@Published so that setting it during `compressAndExport`
    /// does NOT trigger the `onChange(of: exportURL)` observer in the View — which
    /// would incorrectly open the original-quality share sheet while the
    /// CompressionSheet is already on screen.
    private var cachedPDFURL: URL? = nil

    // MARK: – Init

    init(
        document: ScannedDocument,
        repository: ScannedDocumentRepository,
        pdfExportService: PDFExportService,
        ocrViewModel: OCRTaskViewModel
    ) {
        self.document         = document
        self.repository       = repository
        self.pdfExportService = pdfExportService
        self.ocrViewModel = ocrViewModel
        loadRenderedImages()
    }

    // MARK: – Image access

    func loadRenderedImages() {
        AppLogger.scanner.info("🖼 loadRenderedImages — \(self.document.pageCount, privacy: .public) pages")
        var loaded = 0
        for page in document.pages {
            guard let base = repository.loadPageImage(fileName: page.imageFileName) else {
                AppLogger.scanner.warning("⚠️ loadRenderedImages — missing image for page \(page.pageIndex, privacy: .public): \(page.imageFileName, privacy: .public)")
                continue
            }
            renderedImages[page.id] = rendered(base, page: page)
            loaded += 1
        }
        AppLogger.scanner.info("✅ loadRenderedImages — \(loaded, privacy: .public)/\(self.document.pageCount, privacy: .public) loaded")
    }

    func renderedImage(for page: ScannedPage) -> UIImage? {
        renderedImages[page.id]
    }

    // MARK: – Page editing

    /// Called by EditScanView when the user taps "Apply".
    func applyEdit(_ updatedPage: ScannedPage) {
        guard let idx = document.pages.firstIndex(where: { $0.id == updatedPage.id }) else { return }
        document.pages[idx] = updatedPage
        document.updatedAt = Date()
        repository.save(document)
        // Invalidate cached PDFs — pages have changed so the old files are stale.
        cachedPDFURL = nil
        exportURL    = nil

        // Re-render off the main thread to avoid blocking the UI with CoreImage work.
        guard let base = repository.loadPageImage(fileName: updatedPage.imageFileName) else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            let img = ImageProcessingService.apply(
                to: base,
                brightness: updatedPage.brightness,
                contrast:   updatedPage.contrast,
                filter:     updatedPage.filter,
                rotationDegrees: updatedPage.rotationDegrees
            )
            await MainActor.run { [weak self] in
                self?.renderedImages[updatedPage.id] = img
            }
        }
    }

    func deletePage(id: UUID) {
        if let page = document.pages.first(where: { $0.id == id }) {
            AppLogger.scanner.info("🗑 deletePage \(page.pageIndex, privacy: .public) — \(page.imageFileName, privacy: .public)")
            repository.deletePageImage(fileName: page.imageFileName)
        }
        document.pages.removeAll { $0.id == id }
        renderedImages.removeValue(forKey: id)
        document.updatedAt = Date()
        repository.save(document)
        cachedPDFURL = nil
        exportURL    = nil
        AppLogger.scanner.info("🗑 deletePage done — remaining=\(self.document.pageCount, privacy: .public)")
    }

    // MARK: – PDF export

    // MARK: – PDF export

    func exportPDF() async {
        AppLogger.scanner.info("📄 exportPDF — '\(self.document.title, privacy: .public)' pages=\(self.document.pageCount, privacy: .public)")
        isExporting = true
        defer { isExporting = false }
        let images = document.pages.compactMap { renderedImages[$0.id] }
        do {
            let url = try pdfExportService.exportURL(title: document.title, images: images)
            cachedPDFURL = url   // keep for potential subsequent compression
            exportURL    = url   // @Published → triggers share sheet in View
            AppLogger.scanner.info("✅ exportPDF done — \(url.lastPathComponent, privacy: .public)")
        } catch {
            AppLogger.scanner.error("❌ exportPDF failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    /// Generates (or reuses) the base PDF, compresses it at `level`, and returns
    /// the compressed file URL for the CompressionSheet to share.
    ///
    /// Uses `cachedPDFURL` (private, non-@Published) as an intermediate cache so
    /// that generating the base PDF does NOT accidentally trigger the
    /// `onChange(of: exportURL)` observer and open the original share sheet while
    /// the CompressionSheet is already on screen.
    func compressAndExport(level: PDFCompressionLevel) async throws -> URL {
        AppLogger.scanner.info("🗜 compressAndExport — level=\(level.rawValue, privacy: .public) '\(self.document.title, privacy: .public)'")

        // Step 1 — produce the base PDF using the private cache.
        if cachedPDFURL == nil {
            AppLogger.scanner.debug("🗜 compressAndExport — no cached PDF, generating base PDF first")
            isExporting = true
            do {
                let images = document.pages.compactMap { renderedImages[$0.id] }
                cachedPDFURL = try pdfExportService.exportURL(title: document.title,
                                                              images: images)
                AppLogger.scanner.debug("🗜 compressAndExport — base PDF cached at \(self.cachedPDFURL?.lastPathComponent ?? "nil", privacy: .public)")
            } catch {
                AppLogger.scanner.error("❌ compressAndExport — base PDF generation failed: \(error.localizedDescription, privacy: .public)")
                isExporting = false
                throw error
            }
            isExporting = false
        }

        guard let sourceURL = cachedPDFURL else {
            AppLogger.scanner.error("❌ compressAndExport — sourceURL is nil after generation attempt")
            throw PDFCompressionService.CompressionError.sourceNotFound
        }

        // Step 2 — compress off the main thread and return the result URL.
        AppLogger.scanner.info("🗜 compressAndExport — compressing \(sourceURL.lastPathComponent, privacy: .public)")
        let result = try await PDFCompressionService.compress(url: sourceURL, level: level)
        AppLogger.scanner.info("✅ compressAndExport done — \(result.lastPathComponent, privacy: .public)")
        return result
    }

    func extractTasks() {
        let images = document.pages.compactMap { page -> UIImage? in
            if let rendered = renderedImages[page.id] {
                return rendered
            }
            guard let base = repository.loadPageImage(fileName: page.imageFileName) else { return nil }
            return self.rendered(base, page: page)
        }

        guard !images.isEmpty else {
            errorMessage = "Document has no readable pages."
            return
        }

        ocrViewModel.startExtraction(documentID: document.id, source: .images(images))
    }

    // MARK: – Factory

    func makeEditViewModel(for page: ScannedPage) -> EditScanViewModel {
        EditScanViewModel(
            page: page,
            repository: repository,
            onSave: { [weak self] updated in self?.applyEdit(updated) }
        )
    }

    // MARK: – Private

    private func rendered(_ base: UIImage, page: ScannedPage) -> UIImage {
        ImageProcessingService.apply(
            to: base,
            brightness: page.brightness,
            contrast: page.contrast,
            filter: page.filter,
            rotationDegrees: page.rotationDegrees
        )
    }
}
