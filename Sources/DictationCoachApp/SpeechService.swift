import AVFoundation
import Foundation

enum VoicePreset: String, CaseIterable, Identifiable {
    case usFemale = "美式女声"
    case usMale = "美式男声"
    case ukMale = "英式男声"

    var id: String { rawValue }

    var language: String {
        switch self {
        case .usFemale, .usMale:
            return "en-US"
        case .ukMale:
            return "en-GB"
        }
    }

    var preferredNames: [String] {
        switch self {
        case .usFemale:
            return ["Samantha", "Ava", "Allison"]
        case .usMale:
            return ["Alex", "Tom", "Fred"]
        case .ukMale:
            return ["Daniel", "Oliver", "Arthur"]
        }
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

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = pace.rate
        utterance.volume = 1
        utterance.pitchMultiplier = 1
        utterance.voice = selectedVoice()

        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == voicePreset.language }

        for name in voicePreset.preferredNames {
            if let voice = voices.first(where: { $0.name == name }) {
                return voice
            }
        }

        return AVSpeechSynthesisVoice(language: voicePreset.language)
    }
}
