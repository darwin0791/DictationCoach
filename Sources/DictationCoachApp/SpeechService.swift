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

enum ChineseVoicePreset: String, CaseIterable, Identifiable {
    case yue = "高级女声"
    case tingting = "标准女声"

    var id: String { rawValue }

    var gender: AVSpeechSynthesisVoiceGender {
        .female
    }

    var preferredIdentifier: String {
        switch self {
        case .yue:
            return "com.apple.voice.premium.zh-CN.Yue"
        case .tingting:
            return "com.apple.voice.compact.zh-CN.Tingting"
        }
    }

    var preferredNames: [String] {
        switch self {
        case .yue:
            return ["Yue", "悦"]
        case .tingting:
            return ["Tingting", "婷婷"]
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
    @Published var chineseVoicePreset: ChineseVoicePreset = .yue
    @Published var pace: SpeechPace = .normal

    private let synthesizer = AVSpeechSynthesizer()
    private var repeatTask: Task<Void, Never>?

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        repeatTask?.cancel()
        repeatTask = nil
        speakOnce(trimmed, voice: selectedEnglishVoice())
    }

    func speakChinese(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        repeatTask?.cancel()
        repeatTask = nil
        speakOnce(trimmed, voice: selectedChineseVoice())
    }

    func speakRepeated(_ text: String, count: Int = 3, interval: TimeInterval = 3) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, count > 0 else { return }

        repeatTask?.cancel()
        repeatTask = Task { [weak self] in
            for index in 0..<count {
                guard !Task.isCancelled else { return }
                self?.speakOnce(trimmed, voice: self?.selectedEnglishVoice())

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

    func speakChineseRepeated(_ text: String, count: Int = 3, interval: TimeInterval = 3) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, count > 0 else { return }

        repeatTask?.cancel()
        repeatTask = Task { [weak self] in
            for index in 0..<count {
                guard !Task.isCancelled else { return }
                self?.speakOnce(trimmed, voice: self?.selectedChineseVoice())

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

    func chineseVoiceName(for preset: ChineseVoicePreset) -> String {
        selectedChineseVoice(for: preset)?.name ?? "系统语音"
    }

    private func speakOnce(_ text: String, voice: AVSpeechSynthesisVoice?) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = pace.rate
        utterance.volume = 1
        utterance.pitchMultiplier = 1
        utterance.voice = voice

        synthesizer.speak(utterance)
    }

    func stop() {
        repeatTask?.cancel()
        repeatTask = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func selectedEnglishVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == voicePreset.language }

        for name in voicePreset.preferredNames {
            if let voice = voices.first(where: { $0.name == name || $0.name.hasPrefix(name) }) {
                return voice
            }
        }

        return AVSpeechSynthesisVoice(language: voicePreset.language)
    }

    private func selectedChineseVoice() -> AVSpeechSynthesisVoice? {
        selectedChineseVoice(for: chineseVoicePreset)
    }

    private func selectedChineseVoice(for preset: ChineseVoicePreset) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "zh-CN" }

        if let identifierMatch = voices.first(where: { $0.identifier == preset.preferredIdentifier }) {
            return identifierMatch
        }

        for name in preset.preferredNames {
            if let voice = voices.first(where: {
                $0.name == name || $0.name.hasPrefix(name)
            }) {
                return voice
            }
        }

        if preset == .yue,
           let premiumFallback = voices
            .filter({ $0.gender == .female })
            .max(by: { $0.quality.rawValue < $1.quality.rawValue }) {
            return premiumFallback
        }

        if let genderMatch = voices.first(where: { $0.gender == preset.gender }) {
            return genderMatch
        }

        return AVSpeechSynthesisVoice(language: "zh-CN")
    }
}
