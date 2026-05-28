import PDFKit
import UIKit

// MARK: – PDFCompressionService

/// Stateless service that re-rasterises every page of an image-based PDF at a lower
/// resolution and JPEG quality, producing a smaller file while keeping text readable.
///
/// All heavy work is performed on a background thread via `Task.detached`; the
/// caller `await`s the result without blocking the main actor.
enum PDFCompressionService {

    // MARK: – Errors

    enum CompressionError: LocalizedError {
        case sourceNotFound
        case loadFailed
        case noPages
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .sourceNotFound: "Source PDF file not found."
            case .loadFailed:     "Could not open the PDF. The file may be corrupted."
            case .noPages:        "The PDF contains no pages."
            case .writeFailed:    "Could not write the compressed file. Check available storage."
            }
        }
    }

    // A4 page at 72 pt/inch — mirrors PDFExportService
    private static let a4 = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)

    // MARK: – Public API

    /// Compresses `sourceURL` at the given `level` and returns the URL of the
    /// new compressed file in the system temporary directory.
    ///
    /// - Parameters:
    ///   - sourceURL: Path to the original PDF.
    ///   - level:     Desired quality/size trade-off.
    /// - Returns: URL of the compressed PDF (caller is responsible for cleanup).
    /// - Throws: `CompressionError` on failure.
    static func compress(url sourceURL: URL,
                         level: PDFCompressionLevel) async throws -> URL {
        AppLogger.pdf.info("🗜 compress start — file=\(sourceURL.lastPathComponent, privacy: .public) level=\(level.rawValue, privacy: .public) jpegQ=\(level.jpegQuality, privacy: .public) scale=\(level.renderScale, privacy: .public)")

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            AppLogger.pdf.error("❌ compress — source not found: \(sourceURL.lastPathComponent, privacy: .public)")
            throw CompressionError.sourceNotFound
        }

        // All heavy work off the main actor.
        return try await Task.detached(priority: .userInitiated) {
            try Self.compressSync(sourceURL: sourceURL, level: level)
        }.value
    }

    // MARK: – Private

    private static func compressSync(sourceURL: URL,
                                     level: PDFCompressionLevel) throws -> URL {
        guard let pdf = PDFDocument(url: sourceURL) else {
            AppLogger.pdf.error("❌ compressSync — PDFDocument could not load file")
            throw CompressionError.loadFailed
        }
        let pageCount = pdf.pageCount
        guard pageCount > 0 else {
            AppLogger.pdf.error("❌ compressSync — PDF has 0 pages")
            throw CompressionError.noPages
        }
        AppLogger.pdf.info("🗜 compressSync — pageCount=\(pageCount, privacy: .public)")

        let jpegQuality = level.jpegQuality
        let renderScale = level.renderScale
        let pageRect    = Self.a4

        let outputData = NSMutableData()
        UIGraphicsBeginPDFContextToData(outputData, .zero, nil)

        var pageRendered = false
        var skippedPages = 0

        for i in 0..<pageCount {
            autoreleasepool {
                guard let page = pdf.page(at: i) else {
                    AppLogger.pdf.warning("⚠️ page \(i, privacy: .public) could not be loaded — skipping")
                    skippedPages += 1
                    return
                }

                let mediaBox = page.bounds(for: .mediaBox)
                let renderSize = CGSize(
                    width:  max(1, mediaBox.width  * renderScale),
                    height: max(1, mediaBox.height * renderScale)
                )

                let pageImage = page.thumbnail(of: renderSize, for: .mediaBox)

                guard
                    let jpegData   = pageImage.jpegData(compressionQuality: jpegQuality),
                    let compressed = UIImage(data: jpegData)
                else {
                    AppLogger.pdf.warning("⚠️ page \(i, privacy: .public) JPEG encoding failed — skipping")
                    skippedPages += 1
                    return
                }

                let drawRect = Self.fitRect(imageSize: compressed.size, inPage: pageRect)
                UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
                compressed.draw(in: drawRect)
                pageRendered = true
                AppLogger.pdf.debug("📄 compressed page \(i + 1, privacy: .public)/\(pageCount, privacy: .public) jpegBytes=\(jpegData.count, privacy: .public)")
            }
        }

        // MUST call EndPDFContext before reading outputData — it writes the
        // cross-reference table and %%EOF trailer.  Using defer would snapshot
        // the bytes before the trailer is appended, producing an invalid PDF.
        UIGraphicsEndPDFContext()

        if skippedPages > 0 {
            AppLogger.pdf.warning("⚠️ \(skippedPages, privacy: .public) pages were skipped during compression")
        }

        guard pageRendered else {
            AppLogger.pdf.error("❌ compressSync — no pages rendered successfully")
            throw CompressionError.writeFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed_\(UUID().uuidString).pdf")
        do {
            try (outputData as Data).write(to: outputURL, options: .atomic)
        } catch {
            AppLogger.pdf.error("❌ compressSync — write failed: \(error.localizedDescription, privacy: .public)")
            throw CompressionError.writeFailed
        }

        let originalSize = (try? Data(contentsOf: sourceURL).count) ?? 0
        let compressedSize = outputData.length
        let reduction = originalSize > 0
            ? String(format: "%.1f%%", (1.0 - Double(compressedSize) / Double(originalSize)) * 100)
            : "unknown"
        AppLogger.pdf.info("✅ compressSync done — original=\(originalSize, privacy: .public)B compressed=\(compressedSize, privacy: .public)B reduction=\(reduction, privacy: .public)")
        return outputURL
    }

    /// Scales `imageSize` proportionally to fit inside `pageRect`, centred.
    /// Returns the full page rect if either image dimension is zero to avoid ÷0.
    private static func fitRect(imageSize: CGSize, inPage pageRect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return pageRect }
        let iRatio = imageSize.width  / imageSize.height
        let pRatio = pageRect.width   / pageRect.height
        if iRatio > pRatio {
            let h = pageRect.width / iRatio
            return CGRect(x: 0, y: (pageRect.height - h) / 2,
                          width: pageRect.width, height: h)
        } else {
            let w = pageRect.height * iRatio
            return CGRect(x: (pageRect.width - w) / 2, y: 0,
                          width: w, height: pageRect.height)
        }
    }
}
