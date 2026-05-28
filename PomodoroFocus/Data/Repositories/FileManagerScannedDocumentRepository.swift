import UIKit

final class FileManagerScannedDocumentRepository: ScannedDocumentRepository {

    // MARK: – Storage

    private let defaults: UserDefaults
    private let metadataKey = "com.pomodorofocus.scanned_documents"
    private let imagesDir: URL

    // MARK: – Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.imagesDir = docs.appendingPathComponent("ScannedPages", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            AppLogger.storage.info("📁 ScannedPages dir ready: \(self.imagesDir.path, privacy: .public)")
        } catch {
            AppLogger.storage.error("❌ Could not create ScannedPages dir: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: – Metadata

    func loadAll() -> [ScannedDocument] {
        guard
            let data = defaults.data(forKey: metadataKey),
            let docs = try? JSONDecoder().decode([ScannedDocument].self, from: data)
        else {
            AppLogger.storage.debug("📁 loadAll — no stored documents")
            return []
        }
        let sorted = docs.sorted { $0.createdAt > $1.createdAt }
        AppLogger.storage.info("📁 loadAll → \(sorted.count, privacy: .public) documents")
        return sorted
    }

    func load(id: UUID) -> ScannedDocument? {
        let doc = loadAll().first { $0.id == id }
        AppLogger.storage.debug("📁 load id=\(id.uuidString, privacy: .public) → \(doc != nil ? "found" : "not found", privacy: .public)")
        return doc
    }

    func save(_ document: ScannedDocument) {
        var all = loadAll()
        if let idx = all.firstIndex(where: { $0.id == document.id }) {
            all[idx] = document
            AppLogger.storage.info("📁 save — updated '\(document.title, privacy: .public)' pages=\(document.pageCount, privacy: .public)")
        } else {
            all.insert(document, at: 0)
            AppLogger.storage.info("📁 save — inserted '\(document.title, privacy: .public)' pages=\(document.pageCount, privacy: .public)")
        }
        persist(all)
    }

    func delete(id: UUID) {
        var all = loadAll()
        if let doc = all.first(where: { $0.id == id }) {
            AppLogger.storage.info("📁 delete '\(doc.title, privacy: .public)' pages=\(doc.pageCount, privacy: .public)")
            doc.pages.forEach { deletePageImage(fileName: $0.imageFileName) }
        }
        all.removeAll { $0.id == id }
        persist(all)
    }

    // MARK: – Images

    func savePageImage(_ image: UIImage, pageID: UUID) -> String {
        let fileName = "\(pageID.uuidString).jpg"
        let url = imagesDir.appendingPathComponent(fileName)
        if let data = normalised(image).jpegData(compressionQuality: 0.85) {
            do {
                try data.write(to: url, options: .atomic)
                AppLogger.storage.info("📁 savePageImage — \(fileName, privacy: .public) bytes=\(data.count, privacy: .public)")
            } catch {
                AppLogger.storage.error("❌ savePageImage failed for \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        } else {
            AppLogger.storage.error("❌ savePageImage — JPEG encoding failed for pageID=\(pageID.uuidString, privacy: .public)")
        }
        return fileName
    }

    func loadPageImage(fileName: String) -> UIImage? {
        let url = imagesDir.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else {
            AppLogger.storage.error("❌ loadPageImage — file not found: \(fileName, privacy: .public)")
            return nil
        }
        guard let img = UIImage(data: data) else {
            AppLogger.storage.error("❌ loadPageImage — corrupt JPEG: \(fileName, privacy: .public)")
            return nil
        }
        AppLogger.storage.debug("📁 loadPageImage — \(fileName, privacy: .public) bytes=\(data.count, privacy: .public)")
        return img
    }

    func deletePageImage(fileName: String) {
        let url = imagesDir.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: url)
            AppLogger.storage.info("📁 deletePageImage — \(fileName, privacy: .public)")
        } catch {
            AppLogger.storage.warning("⚠️ deletePageImage — \(fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: – Private

    private func persist(_ docs: [ScannedDocument]) {
        do {
            let data = try JSONEncoder().encode(docs)
            defaults.set(data, forKey: metadataKey)
            AppLogger.storage.debug("📁 persist — \(docs.count, privacy: .public) docs, \(data.count, privacy: .public) bytes")
        } catch {
            AppLogger.storage.error("❌ persist encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Normalises UIImage orientation so JPEG is always stored upright.
    private func normalised(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(at: .zero) }
    }
}
