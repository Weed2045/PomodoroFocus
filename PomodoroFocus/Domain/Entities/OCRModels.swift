import CoreGraphics
import Foundation

struct ExtractedTaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var deadline: Date?
    var estimatedMinutes: Int
    var confidence: Confidence
    var isSelected: Bool
    var sourceRange: NSRange?
    var rawLine: String

    enum Confidence: Double, Codable, Comparable {
        case low = 0.4
        case medium = 0.7
        case high = 0.9

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var label: String {
            switch self {
            case .low: return L10n.OCR.confidenceLow
            case .medium: return L10n.OCR.confidenceMedium
            case .high: return L10n.OCR.confidenceHigh
            }
        }

        var colorHex: String {
            switch self {
            case .low: return "#F39C12"
            case .medium: return "#2980B9"
            case .high: return "#27AE60"
            }
        }
    }
}

struct OCRResult: Codable, Equatable {
    let documentID: UUID
    let rawText: String
    let pages: [PageResult]
    let extractedItems: [ExtractedTaskItem]
    let processingDuration: TimeInterval

    struct PageResult: Codable, Equatable {
        let pageIndex: Int
        let text: String
        let blocks: [TextBlock]

        struct TextBlock: Codable, Equatable {
            let text: String
            let boundingBox: CGRect
            let confidence: Float
        }
    }
}

struct DocumentTaskLink: Codable, Identifiable, Equatable {
    let id: UUID
    let documentID: UUID
    let taskID: UUID
    let createdAt: Date
    let pageIndex: Int?
    let sourceRange: NSRange?

    init(
        id: UUID = UUID(),
        documentID: UUID,
        taskID: UUID,
        createdAt: Date = Date(),
        pageIndex: Int? = nil,
        sourceRange: NSRange? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.taskID = taskID
        self.createdAt = createdAt
        self.pageIndex = pageIndex
        self.sourceRange = sourceRange
    }
}

