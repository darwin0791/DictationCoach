import Foundation

enum MasteryStatus: String, Codable, CaseIterable, Identifiable {
    case new = "新词"
    case reviewing = "复习中"
    case basic = "基本掌握"

    var id: String { rawValue }
}

struct WordMeaning: Codable, Hashable {
    var partOfSpeech: String
    var chinese: String
}

struct WordExample: Codable, Hashable {
    var english: String
    var chinese: String
}

struct DictionaryEntry: Codable {
    var usIPA: String?
    var ukIPA: String?
    var commonMeaning: String?
    var meanings: [WordMeaning]?
    var example: WordExample?
}

struct WordEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var word: String
    var ipaUS: String?
    var ipaUK: String?
    var customIPA: String?
    var commonMeaning: String?
    var meanings: [WordMeaning]?
    var exampleEnglish: String?
    var exampleChinese: String?
    var customMeaning: String?
    var correctCount: Int
    var wrongCount: Int
    var consecutiveCorrectInWrongBook: Int
    var lastPracticedAt: Date?
    var lastWrongAt: Date?
    var isInWrongBook: Bool
    var masteryStatus: MasteryStatus

    init(word: String, dictionaryEntry: DictionaryEntry? = nil) {
        self.id = UUID()
        self.word = word
        self.ipaUS = dictionaryEntry?.usIPA
        self.ipaUK = dictionaryEntry?.ukIPA
        self.customIPA = nil
        self.commonMeaning = dictionaryEntry?.commonMeaning
        self.meanings = dictionaryEntry?.meanings
        self.exampleEnglish = dictionaryEntry?.example?.english
        self.exampleChinese = dictionaryEntry?.example?.chinese
        self.customMeaning = nil
        self.correctCount = 0
        self.wrongCount = 0
        self.consecutiveCorrectInWrongBook = 0
        self.lastPracticedAt = nil
        self.lastWrongAt = nil
        self.isInWrongBook = false
        self.masteryStatus = .new
    }

    var displayIPA: String {
        if let customIPA, !customIPA.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customIPA
        }
        if let ipaUS, !ipaUS.isEmpty {
            return ipaUS
        }
        if let ipaUK, !ipaUK.isEmpty {
            return ipaUK
        }
        return "未收录音标"
    }

    var displayMeaning: String {
        if let customMeaning, !customMeaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return customMeaning
        }
        if let commonMeaning, !commonMeaning.isEmpty {
            return commonMeaning
        }
        if let first = meanings?.first, !first.chinese.isEmpty {
            return first.chinese
        }
        return "未收录释义"
    }
}

enum PracticeMode: String, CaseIterable, Identifiable {
    case all = "全部单词"
    case wrongOnly = "错题复听"

    var id: String { rawValue }
}
