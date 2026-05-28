import UIKit

protocol ScannedDocumentRepository {
    func loadAll() -> [ScannedDocument]
    func load(id: UUID) -> ScannedDocument?
    func save(_ document: ScannedDocument)
    func delete(id: UUID)

    // Image persistence
    /// Stores `image` to disk and returns the generated file name.
    func savePageImage(_ image: UIImage, pageID: UUID) -> String
    func loadPageImage(fileName: String) -> UIImage?
    func deletePageImage(fileName: String)
}
