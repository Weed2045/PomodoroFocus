import Foundation

// MARK: – ScanFilter

enum ScanFilter: String, Codable, CaseIterable, Identifiable {
    case original   = "Original"
    case grayscale  = "Grayscale"
    case blackWhite = "B&W"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .original:   "photo"
        case .grayscale:  "circle.lefthalf.filled"
        case .blackWhite: "doc.text"
        }
    }
}

// MARK: – ScannedPage

struct ScannedPage: Codable, Identifiable, Hashable {
    let id: UUID
    var imageFileName: String   // JPEG stored in Documents/ScannedPages/
    var pageIndex: Int

    // Edit parameters
    var brightness: Float        // –1.0 … +1.0  (default 0)
    var contrast: Float          //  0.5 … 2.0   (default 1)
    var filter: ScanFilter
    var rotationDegrees: Double  // 0 | 90 | 180 | 270
    let createdAt: Date

    init(
        id: UUID = UUID(),
        imageFileName: String,
        pageIndex: Int,
        brightness: Float = 0,
        contrast: Float = 1,
        filter: ScanFilter = .original,
        rotationDegrees: Double = 0
    ) {
        self.id              = id
        self.imageFileName   = imageFileName
        self.pageIndex       = pageIndex
        self.brightness      = brightness
        self.contrast        = contrast
        self.filter          = filter
        self.rotationDegrees = rotationDegrees
        self.createdAt       = Date()
    }
}

// MARK: – ScannedDocument

struct ScannedDocument: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var pages: [ScannedPage]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, pages: [ScannedPage] = []) {
        self.id        = id
        self.title     = title
        self.pages     = pages
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var pageCount: Int       { pages.count }
    var firstPage: ScannedPage? { pages.first }
}
