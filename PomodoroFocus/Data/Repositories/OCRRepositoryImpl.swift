import Foundation

final class OCRRepositoryImpl: OCRRepositoryProtocol {
    private let defaults: UserDefaults
    private let cacheKey = "com.pomodorofocus.ocr_results_index"
    private let cacheDirectory: URL

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cacheDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OCRResults", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func saveOCRResult(_ result: OCRResult) async throws {
        let data = try JSONEncoder().encode(result)
        try data.write(to: cacheURL(for: result.documentID), options: .atomic)
        var index = loadIndex()
        index.insert(result.documentID.uuidString)
        defaults.set(Array(index), forKey: cacheKey)
    }

    func fetchOCRResult(documentID: UUID) async throws -> OCRResult? {
        let url = cacheURL(for: documentID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(OCRResult.self, from: data)
    }

    func deleteOCRResult(documentID: UUID) async throws {
        try? FileManager.default.removeItem(at: cacheURL(for: documentID))
        var index = loadIndex()
        index.remove(documentID.uuidString)
        defaults.set(Array(index), forKey: cacheKey)
    }

    func searchOCRResults(matching query: String) async throws -> [OCRSearchMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var matches: [OCRSearchMatch] = []
        for idString in loadIndex() {
            guard let documentID = UUID(uuidString: idString),
                  let result = try await fetchOCRResult(documentID: documentID),
                  let range = result.rawText.range(
                    of: trimmed,
                    options: [.caseInsensitive, .diacriticInsensitive]
                  ) else {
                continue
            }

            matches.append(
                OCRSearchMatch(
                    documentID: documentID,
                    snippet: snippet(in: result.rawText, around: range)
                )
            )
        }
        return matches
    }

    private func cacheURL(for id: UUID) -> URL {
        cacheDirectory.appendingPathComponent("ocr_\(id.uuidString).json")
    }

    private func loadIndex() -> Set<String> {
        Set(defaults.stringArray(forKey: cacheKey) ?? [])
    }

    private func snippet(in text: String, around range: Range<String.Index>) -> String {
        let prefix = text[..<range.lowerBound].suffix(52)
        let match = text[range]
        let suffix = text[range.upperBound...].prefix(72)
        return ([String(prefix), String(match), String(suffix)]
            .joined()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

final class DocumentTaskLinkRepositoryImpl: DocumentTaskLinkRepositoryProtocol {
    private let defaults: UserDefaults
    private let key = "com.pomodorofocus.document_task_links"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveLink(_ link: DocumentTaskLink) async throws {
        var links = loadAll()
        links.removeAll { $0.documentID == link.documentID && $0.taskID == link.taskID }
        links.append(link)
        try persist(links)
    }

    func fetchLinks(documentID: UUID) async throws -> [DocumentTaskLink] {
        loadAll().filter { $0.documentID == documentID }
    }

    func fetchLinks(taskID: UUID) async throws -> [DocumentTaskLink] {
        loadAll().filter { $0.taskID == taskID }
    }

    func deleteLinks(documentID: UUID) async throws {
        try persist(loadAll().filter { $0.documentID != documentID })
    }

    func deleteLink(id: UUID) async throws {
        try persist(loadAll().filter { $0.id != id })
    }

    private func loadAll() -> [DocumentTaskLink] {
        guard let data = defaults.data(forKey: key),
              let links = try? JSONDecoder().decode([DocumentTaskLink].self, from: data) else {
            return []
        }
        return links
    }

    private func persist(_ links: [DocumentTaskLink]) throws {
        defaults.set(try JSONEncoder().encode(links), forKey: key)
    }
}
