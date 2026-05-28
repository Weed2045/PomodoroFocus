import Foundation
import NaturalLanguage
import UIKit
@preconcurrency import Vision

final class VisionOCRService {
    func recognizeText(
        from source: OCRSource,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> [OCRResult.PageResult] {
        switch source {
        case .images(let images):
            return try await recognizeFromImages(images, progress: progressHandler)
        case .cachedResult(let result):
            progressHandler?(1)
            return result.pages
        }
    }

    private func recognizeFromImages(
        _ images: [UIImage],
        progress: ((Double) -> Void)?
    ) async throws -> [OCRResult.PageResult] {
        guard !images.isEmpty else { throw OCRError.invalidImage }

        var results: [OCRResult.PageResult] = []
        for (index, image) in images.enumerated() {
            try Task.checkCancellation()
            let blocks = try await recognizeSingleImage(image)
            let text = blocks.map(\.text).joined(separator: "\n")
            results.append(.init(pageIndex: index, text: text, blocks: blocks))
            progress?(Double(index + 1) / Double(images.count))
        }
        return results
    }

    private func recognizeSingleImage(_ image: UIImage) async throws -> [OCRResult.PageResult.TextBlock] {
        guard let cgImage = image.cgImage else { throw OCRError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let blocks: [OCRResult.PageResult.TextBlock] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRResult.PageResult.TextBlock(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }
                continuation.resume(returning: blocks)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["vi-VN", "en-US"]
            request.minimumTextHeight = 0.015

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Anh scan khong hop le."
        case .processingFailed(let message):
            return "Loi OCR: \(message)"
        }
    }
}

final class NLPTaskExtractionService {
    func extractTasks(from text: String, documentID: UUID, language: String? = nil) async -> [ExtractedTaskItem] {
        let detectedLanguage = language ?? detectLanguage(text)
        let lines = splitIntoLines(text)
        var items: [ExtractedTaskItem] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count > 3 else { continue }
            if let item = analyzeLine(trimmed, fullLine: line, language: detectedLanguage) {
                items.append(item)
            }
        }

        return mergeDuplicates(items).sorted { $0.confidence > $1.confidence }
    }

    private func analyzeLine(_ line: String, fullLine: String, language: String) -> ExtractedTaskItem? {
        detectByPattern(line, fullLine: fullLine) ?? detectByNLP(line, fullLine: fullLine, language: language)
    }

    private func detectByPattern(_ line: String, fullLine: String) -> ExtractedTaskItem? {
        let patterns = [
            #"^\s*[\[\(]\s*[ xX✓✗]?\s*[\]\)]\s*(.+)"#,
            #"^\s*[☐☑☒]\s*(.+)"#,
            #"^\s*[-•*▪▸→]\s+(.+)"#,
            #"^\s*\d+[.)]\s+(.+)"#,
            #"^\s*TODO:?\s*(.+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: line) else {
                continue
            }
            return makeItem(title: String(line[range]), fullLine: fullLine, confidence: .high)
        }

        return nil
    }

    private func detectByNLP(_ line: String, fullLine: String, language: String) -> ExtractedTaskItem? {
        let lowercased = line.lowercased()
        let actionKeywords = [
            "viet", "viết", "lam", "làm", "hoan thanh", "hoàn thành", "gui", "gửi",
            "goi", "gọi", "doc", "đọc", "chuan bi", "chuẩn bị", "kiem tra", "kiểm tra",
            "sua", "sửa", "cap nhat", "cập nhật", "tao", "tạo", "nop", "nộp",
            "hop", "họp", "nghien cuu", "nghiên cứu", "write", "complete", "send",
            "call", "read", "prepare", "review", "fix", "update", "create", "plan",
            "submit", "schedule", "research", "implement", "design", "test"
        ]
        guard actionKeywords.contains(where: { lowercased.contains($0) }) else { return nil }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = line
        var tokenCount = 0
        var hasVerb = false
        var hasNoun = false
        tagger.enumerateTags(
            in: line.startIndex..<line.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, _ in
            tokenCount += 1
            if tag == .verb { hasVerb = true }
            if tag == .noun { hasNoun = true }
            return true
        }

        let isVietnamese = language.hasPrefix("vi")
        guard isVietnamese || (hasVerb && hasNoun && tokenCount <= 24) else { return nil }
        return makeItem(title: line, fullLine: fullLine, confidence: .medium)
    }

    private func makeItem(title: String, fullLine: String, confidence: ExtractedTaskItem.Confidence) -> ExtractedTaskItem {
        let deadline = extractDeadline(from: title)
        let cleanedTitle = deadline == nil ? title : removeDeadlinePart(from: title)
        return ExtractedTaskItem(
            id: UUID(),
            title: cleanedTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            deadline: deadline,
            estimatedMinutes: estimateDuration(cleanedTitle),
            confidence: confidence,
            isSelected: true,
            sourceRange: NSRange(fullLine.startIndex..., in: fullLine),
            rawLine: fullLine
        )
    }

    private func extractDeadline(from text: String) -> Date? {
        extractWithDataDetector(text) ?? extractVietnameseDate(text)
    }

    private func extractWithDataDetector(_ text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        return detector
            .matches(in: text, range: NSRange(text.startIndex..., in: text))
            .first?
            .date
    }

    private func extractVietnameseDate(_ text: String) -> Date? {
        let lowered = text.lowercased()
        let calendar = Calendar.current

        if lowered.contains("ngay mai") || lowered.contains("ngày mai") || lowered.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: Date())
        }

        let datePattern = #"\b(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{2,4}))?\b"#
        if let regex = try? NSRegularExpression(pattern: datePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            var components = DateComponents()
            if let dayRange = Range(match.range(at: 1), in: text) {
                components.day = Int(text[dayRange])
            }
            if let monthRange = Range(match.range(at: 2), in: text) {
                components.month = Int(text[monthRange])
            }
            if match.range(at: 3).location != NSNotFound,
               let yearRange = Range(match.range(at: 3), in: text),
               let parsedYear = Int(text[yearRange]) {
                components.year = parsedYear < 100 ? 2000 + parsedYear : parsedYear
            } else {
                components.year = calendar.component(.year, from: Date())
            }
            return calendar.date(from: components)
        }

        let weekdayMap: [String: Int] = [
            "thu hai": 2, "thứ hai": 2, "monday": 2,
            "thu ba": 3, "thứ ba": 3, "tuesday": 3,
            "thu tu": 4, "thứ tư": 4, "wednesday": 4,
            "thu nam": 5, "thứ năm": 5, "thursday": 5,
            "thu sau": 6, "thứ sáu": 6, "friday": 6,
            "thu bay": 7, "thứ bảy": 7, "saturday": 7,
            "chu nhat": 1, "chủ nhật": 1, "sunday": 1
        ]
        for (key, weekday) in weekdayMap where lowered.contains(key) {
            return nextWeekday(weekday)
        }

        return nil
    }

    private func nextWeekday(_ weekday: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        var delta = weekday - today
        if delta <= 0 { delta += 7 }
        return calendar.date(byAdding: .day, value: delta, to: Date()) ?? Date()
    }

    private func removeDeadlinePart(from text: String) -> String {
        let patterns = [
            #"\bngay mai\b"#, #"\bngày mai\b"#, #"\btomorrow\b"#,
            #"\bthu (hai|ba|tu|nam|sau|bay)\b"#,
            #"\bthứ (hai|ba|tư|năm|sáu|bảy)\b"#,
            #"\bchu nhat\b"#, #"\bchủ nhật\b"#,
            #"\b\d{1,2}[/\-]\d{1,2}(?:[/\-]\d{2,4})?\b"#,
            #"\bdeadline:?\s*"#, #"\bdue:?\s*"#,
            #"\btruoc\s+ngay\b"#, #"\btrước\s+ngày\b"#, #"\bbefore\b"#
        ]
        return patterns.reduce(text) { partial, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return partial
            }
            return regex.stringByReplacingMatches(
                in: partial,
                range: NSRange(partial.startIndex..., in: partial),
                withTemplate: ""
            )
        }
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func estimateDuration(_ title: String) -> Int {
        let lowercased = title.lowercased()
        let heavy = ["bao cao", "báo cáo", "research", "nghien cuu", "nghiên cứu", "design", "thiet ke", "thiết kế", "implement", "lap trinh", "lập trình", "presentation"]
        if heavy.contains(where: { lowercased.contains($0) }) { return 50 }

        let light = ["call", "goi", "gọi", "reply", "tra loi", "trả lời", "send", "gui", "gửi", "email", "check", "kiem tra nhanh"]
        if light.contains(where: { lowercased.contains($0) }) { return 15 }

        return 25
    }

    private func detectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(800)))
        return recognizer.dominantLanguage?.rawValue ?? "vi"
    }

    private func splitIntoLines(_ text: String) -> [String] {
        let rawLines = text.components(separatedBy: .newlines)
        var merged: [String] = []
        var buffer = ""

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !buffer.isEmpty {
                    merged.append(buffer)
                    buffer = ""
                }
                continue
            }

            if trimmed.last.map({ ".!?:".contains($0) }) == true || trimmed.count > 45 {
                merged.append(buffer.isEmpty ? trimmed : buffer + " " + trimmed)
                buffer = ""
            } else {
                buffer = buffer.isEmpty ? trimmed : buffer + " " + trimmed
            }
        }

        if !buffer.isEmpty { merged.append(buffer) }
        return merged
    }

    private func mergeDuplicates(_ items: [ExtractedTaskItem]) -> [ExtractedTaskItem] {
        var seen = Set<String>()
        return items.filter { item in
            seen.insert(item.title.lowercased()).inserted
        }
    }
}
