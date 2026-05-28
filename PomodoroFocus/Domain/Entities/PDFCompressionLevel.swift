import Foundation

// MARK: – PDFCompressionLevel

/// Describes how aggressively a scanned-document PDF should be compressed.
/// Each case controls both the JPEG encoding quality and the per-page render scale,
/// giving a predictable size-vs-quality trade-off.
///
/// UI-only properties (colours, icons) live in `PDFCompressionLevel+UI.swift`
/// so the Domain layer stays free of SwiftUI dependencies.
enum PDFCompressionLevel: String, CaseIterable, Identifiable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"

    var id: String { rawValue }

    // MARK: – Compression parameters

    /// JPEG quality passed to `jpegData(compressionQuality:)`. Range 0–1.
    var jpegQuality: CGFloat {
        switch self {
        case .low:    0.25
        case .medium: 0.50
        case .high:   0.75
        }
    }

    /// Scale factor applied when rasterising each PDF page.
    /// A lower scale reduces pixel count before JPEG encoding.
    var renderScale: CGFloat {
        switch self {
        case .low:    0.50   // 50 % of original resolution
        case .medium: 0.70   // 70 %
        case .high:   1.00   // 100 % (full resolution, only JPEG artefacts)
        }
    }

    // MARK: – UI text (no SwiftUI types — safe to keep in Domain)

    var label: String {
        switch self {
        case .low:    L10n.PDFQuality.Low.label
        case .medium: L10n.PDFQuality.Medium.label
        case .high:   L10n.PDFQuality.High.label
        }
    }

    var detail: String {
        switch self {
        case .low:    L10n.PDFQuality.Low.detail
        case .medium: L10n.PDFQuality.Medium.detail
        case .high:   L10n.PDFQuality.High.detail
        }
    }

    var reductionHint: String {
        switch self {
        case .low:    L10n.PDFQuality.Low.hint
        case .medium: L10n.PDFQuality.Medium.hint
        case .high:   L10n.PDFQuality.High.hint
        }
    }

    var systemIcon: String {
        switch self {
        case .low:    "doc.fill"
        case .medium: "doc.text.fill"
        case .high:   "doc.richtext.fill"
        }
    }
}
