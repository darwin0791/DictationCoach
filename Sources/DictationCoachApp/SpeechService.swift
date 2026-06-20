import AVFoundation
import Foundation

enum VoicePreset: String, CaseIterable, Identifiable {
    case usFemale = "美式女声"
    case usMale = "美式男声"
    case ukFemale = "英式女声"
    case ukMale = "英式男声"

    var id: String { rawValue }

    var language: String {
        switch self {
        case .usFemale, .usMale:
            return "en-US"
        case .ukFemale, .ukMale:
            return "en-GB"
        }
    }

    var preferredNames: [String] {
        switch self {
        case .usFemale:
            return ["Samantha", "Ava", "Allison"]
        case .usMale:
            return ["Alex", "Tom", "Fred"]
        case .ukFemale:
            return ["Shelley", "Sandy", "Flo", "Serena", "Kate"]
        case .ukMale:
            return ["Daniel", "Oliver", "Arthur"]
        }
    }

    var primaryVoiceName: String {
        preferredNames.first ?? ""
    }
}

enum SpeechPace: String, CaseIterable, Identifiable {
    case normal = "正常"
    case slow = "慢速"

    var id: String { rawValue }

    var rate: Float {
        switch self {
        case .normal:
            return 0.43
        case .slow:
            return 0.32
        }
    }
}

@MainActor
final class SpeechService: NSObject, ObservableObject {
    @Published var voicePreset: VoicePreset = .usFemale
    @Published var pace: SpeechPace = .normal

    private let synthesizer = AVSpeechSynthesizer()
    private var repeatTask: Task<Void, Never>?

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        repeatTask?.cancel()
        repeatTask = nil
        speakOnce(trimmed)
    }

    func speakRepeated(_ text: String, count: Int = 3, interval: TimeInterval = 3) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, count > 0 else { return }

        repeatTask?.cancel()
        repeatTask = Task { [weak self] in
            for index in 0..<count {
                guard !Task.isCancelled else { return }
                self?.speakOnce(trimmed)

                if index + 1 < count {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    } catch {
                        return
                    }
                }
            }
        }
    }

    private func speakOnce(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = pace.rate
        utterance.volume = 1
        utterance.pitchMultiplier = 1
        utterance.voice = selectedVoice()

        synthesizer.speak(utterance)
    }

    func stop() {
        repeatTask?.cancel()
        repeatTask = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == voicePreset.language }

        for name in voicePreset.preferredNames {
            if let voice = voices.first(where: { $0.name == name || $0.name.hasPrefix(name) }) {
                return voice
            }
        }

        return AVSpeechSynthesisVoice(language: voicePreset.language)
    }
}
