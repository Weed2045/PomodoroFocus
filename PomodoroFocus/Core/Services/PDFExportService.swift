import UIKit

final class PDFExportService {

    // MARK: – Errors

    enum PDFExportError: LocalizedError {
        case noPages
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .noPages:      "No pages to export."
            case .renderFailed: "Failed to render the PDF."
            }
        }
    }

    // A4 page at 72 pt/inch
    private static let a4 = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)

    // MARK: – Public API

    /// Renders all images into a single PDF and returns the raw Data.
    func generateData(from images: [UIImage]) throws -> Data {
        AppLogger.pdf.info("📄 generateData — pages=\(images.count, privacy: .public)")
        guard !images.isEmpty else {
            AppLogger.pdf.error("❌ generateData — no pages")
            throw PDFExportError.noPages
        }

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)

        for (i, image) in images.enumerated() {
            let drawRect = fitRect(imageSize: image.size, inPage: Self.a4)
            UIGraphicsBeginPDFPageWithInfo(Self.a4, nil)
            image.draw(in: drawRect)
            AppLogger.pdf.debug("📄 rendered page \(i + 1, privacy: .public)/\(images.count, privacy: .public) size=\(image.size.width, privacy: .public)×\(image.size.height, privacy: .public)")
        }

        // MUST call EndPDFContext before reading pdfData — it writes the
        // cross-reference table and %%EOF trailer.  Using defer would snapshot
        // the bytes before the trailer is appended, producing an invalid PDF.
        UIGraphicsEndPDFContext()

        guard pdfData.length > 0 else {
            AppLogger.pdf.error("❌ generateData — output empty after rendering")
            throw PDFExportError.renderFailed
        }
        AppLogger.pdf.info("✅ generateData — bytes=\(pdfData.length, privacy: .public)")
        return pdfData as Data
    }

    /// Writes the PDF to a uniquely-named temp file and returns its URL.
    func exportURL(title: String, images: [UIImage]) throws -> URL {
        AppLogger.pdf.info("📄 exportURL — title=\(title, privacy: .public) pages=\(images.count, privacy: .public)")
        let data = try generateData(from: images)
        let safe = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safe).pdf")
        try data.write(to: url, options: .atomic)
        AppLogger.pdf.info("✅ exportURL → \(url.lastPathComponent, privacy: .public)")
        return url
    }

    // MARK: – Private

    /// Scales `imageSize` to fit inside `pageRect` preserving aspect ratio, centred.
    private func fitRect(imageSize: CGSize, inPage pageRect: CGRect) -> CGRect {
        let iRatio = imageSize.width  / imageSize.height
        let pRatio = pageRect.width   / pageRect.height

        if iRatio > pRatio {
            let h = pageRect.width / iRatio
            return CGRect(x: 0,
                          y: (pageRect.height - h) / 2,
                          width: pageRect.width,
                          height: h)
        } else {
            let w = pageRect.height * iRatio
            return CGRect(x: (pageRect.width - w) / 2,
                          y: 0,
                          width: w,
                          height: pageRect.height)
        }
    }
}
