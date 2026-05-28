import UIKit

@MainActor
final class EditScanViewModel: ObservableObject {

    // MARK: – Published

    @Published var page: ScannedPage
    @Published var previewImage: UIImage?
    @Published var isProcessing = false

    // MARK: – Private

    private let repository: ScannedDocumentRepository
    private let onSave: (ScannedPage) -> Void
    /// Raw (unedited) image loaded once and kept for re-applying adjustments.
    private let baseImage: UIImage?
    /// Tracks the in-flight render task so we can cancel it before starting a new one.
    private var renderTask: Task<Void, Never>?

    // MARK: – Init

    init(
        page: ScannedPage,
        repository: ScannedDocumentRepository,
        onSave: @escaping (ScannedPage) -> Void
    ) {
        self.page       = page
        self.repository = repository
        self.onSave     = onSave
        self.baseImage  = repository.loadPageImage(fileName: page.imageFileName)
        AppLogger.scanner.info("✏️ EditScanViewModel init — page=\(page.pageIndex, privacy: .public) file=\(page.imageFileName, privacy: .public) baseLoaded=\(self.baseImage != nil, privacy: .public)")
        refreshPreview()
    }

    // MARK: – Edit actions

    func setBrightness(_ value: Float) {
        AppLogger.scanner.debug("✏️ setBrightness → \(value, privacy: .public)")
        page.brightness = value
        refreshPreview()
    }

    func setContrast(_ value: Float) {
        AppLogger.scanner.debug("✏️ setContrast → \(value, privacy: .public)")
        page.contrast = value
        refreshPreview()
    }

    func setFilter(_ filter: ScanFilter) {
        AppLogger.scanner.debug("✏️ setFilter → \(filter.rawValue, privacy: .public)")
        page.filter = filter
        refreshPreview()
    }

    func rotateLeft() {
        page.rotationDegrees = (page.rotationDegrees - 90 + 360)
            .truncatingRemainder(dividingBy: 360)
        AppLogger.scanner.debug("✏️ rotateLeft → \(self.page.rotationDegrees, privacy: .public)°")
        refreshPreview()
    }

    func rotateRight() {
        page.rotationDegrees = (page.rotationDegrees + 90)
            .truncatingRemainder(dividingBy: 360)
        AppLogger.scanner.debug("✏️ rotateRight → \(self.page.rotationDegrees, privacy: .public)°")
        refreshPreview()
    }

    func resetAll() {
        AppLogger.scanner.info("✏️ resetAll — page=\(self.page.pageIndex, privacy: .public)")
        page.brightness      = 0
        page.contrast        = 1
        page.filter          = .original
        page.rotationDegrees = 0
        refreshPreview()
    }

    func save() {
        AppLogger.scanner.info("✏️ save — page=\(self.page.pageIndex, privacy: .public) filter=\(self.page.filter.rawValue, privacy: .public) brightness=\(self.page.brightness, privacy: .public) contrast=\(self.page.contrast, privacy: .public) rotation=\(self.page.rotationDegrees, privacy: .public)°")
        onSave(page)
    }

    // MARK: – Preview rendering

    /// Cancels any in-flight render then starts a fresh one on a background thread.
    /// Cancellation prevents stale results from overwriting a newer preview when
    /// the user rapidly moves a slider.
    private func refreshPreview() {
        guard let base = baseImage else {
            AppLogger.scanner.warning("⚠️ refreshPreview — baseImage is nil, skipping render")
            return
        }
        renderTask?.cancel()
        isProcessing = true
        let snap = page   // capture value type snapshot
        AppLogger.scanner.debug("✏️ refreshPreview — filter=\(snap.filter.rawValue, privacy: .public) brightness=\(snap.brightness, privacy: .public) contrast=\(snap.contrast, privacy: .public) rotation=\(snap.rotationDegrees, privacy: .public)°")

        renderTask = Task.detached(priority: .userInitiated) { [weak self] in
            let processed = ImageProcessingService.apply(
                to: base,
                brightness: snap.brightness,
                contrast:   snap.contrast,
                filter:     snap.filter,
                rotationDegrees: snap.rotationDegrees
            )
            // Drop stale results if a newer render was already kicked off.
            guard !Task.isCancelled else {
                AppLogger.scanner.debug("✏️ refreshPreview — render cancelled (stale)")
                return
            }
            await MainActor.run { [weak self] in
                self?.previewImage  = processed
                self?.isProcessing  = false
            }
        }
    }
}
