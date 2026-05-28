import Foundation

protocol OCRRepositoryProtocol {
    func saveOCRResult(_ result: OCRResult) async throws
    func fetchOCRResult(documentID: UUID) async throws -> OCRResult?
    func deleteOCRResult(documentID: UUID) async throws
}

protocol DocumentTaskLinkRepositoryProtocol {
    func saveLink(_ link: DocumentTaskLink) async throws
    func fetchLinks(documentID: UUID) async throws -> [DocumentTaskLink]
    func fetchLinks(taskID: UUID) async throws -> [DocumentTaskLink]
    func deleteLinks(documentID: UUID) async throws
    func deleteLink(id: UUID) async throws
}

