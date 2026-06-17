import AppKit
import Foundation
import Vision

enum OCRService {
    static func recognizeWords(from imageURL: URL) async throws -> [String] {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""

                continuation.resume(returning: extractEnglishWords(from: text))
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func extractEnglishWords(from text: String) -> [String] {
        let pattern = #"[A-Za-z]+(?:[-'][A-Za-z]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var seen = Set<String>()
        var words: [String] = []
        for match in matches {
            let word = nsText.substring(with: match.range).lowercased()
            guard word.count > 1, !seen.contains(word) else { continue }
            seen.insert(word)
            words.append(word)
        }
        return words
    }
}
