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
    var commonMeaning: String?
    var meanings: [WordMeaning]?
    var exampleEnglish: String?
    var exampleChinese: String?
    var correctCount: Int
    var wrongCount: Int
    var consecutiveCorrectInWrongBook: Int
    var lastPracticedAt: Date?
    var lastWrongAt: Date?
    var isInWrongBook: Bool
    var masteryStatus: MasteryStatus
    var isArchivedFromWordBook: Bool?

    init(word: String, dictionaryEntry: DictionaryEntry? = nil) {
        self.id = UUID()
        self.word = word
        self.ipaUS = dictionaryEntry?.usIPA
        self.ipaUK = dictionaryEntry?.ukIPA
        self.commonMeaning = dictionaryEntry?.commonMeaning
        self.meanings = dictionaryEntry?.meanings
        self.exampleEnglish = dictionaryEntry?.example?.english
        self.exampleChinese = dictionaryEntry?.example?.chinese
        self.correctCount = 0
        self.wrongCount = 0
        self.consecutiveCorrectInWrongBook = 0
        self.lastPracticedAt = nil
        self.lastWrongAt = nil
        self.isInWrongBook = false
        self.masteryStatus = .new
        self.isArchivedFromWordBook = false
    }

    var displayIPA: String {
        if let ipaUS, !ipaUS.isEmpty {
            return ipaUS
        }
        if let ipaUK, !ipaUK.isEmpty {
            return ipaUK
        }
        return "未收录音标"
    }

    var displayMeaning: String {
        if let commonMeaning, !commonMeaning.isEmpty {
            return commonMeaning
        }
        if let first = meanings?.first, !first.chinese.isEmpty {
            return first.chinese
        }
        return "未收录释义"
    }
}

enum PracticeMode: String, CaseIterable, Identifiable, Codable {
    case all = "全部单词"
    case wrongOnly = "错题复听"

    var id: String { rawValue }
}

enum DictationMethod: String, CaseIterable, Identifiable, Codable {
    case english = "英文听写"
    case chinese = "中文默写"

    var id: String { rawValue }

    var iconResource: String {
        switch self {
        case .english: "英文_english"
        case .chinese: "中文_chinese"
        }
    }
}

struct PracticeSessionSnapshot: Codable {
    var mode: PracticeMode
    var dictationMethod: DictationMethod?
    var showEnglishHints: Bool?
    var wordIDs: [UUID]
    var currentIndex: Int
    var selectedGrade: String
    var selectedBook: String
    var selectedUnit: String
    var savedAt: Date
}

struct WordInputWarning: Identifiable {
    var id: String { word + title }
    var word: String
    var title: String
    var message: String
}

struct TextbookTag: Codable, Hashable, Identifiable {
    var grade: String
    var book: String
    var unit: String
    var meaning: String

    var id: String {
        "\(grade)-\(book)-\(unit)-\(meaning)"
    }

    var label: String {
        "\(grade)\(book) \(unit)"
    }
}

enum SentenceKind: String, Codable, CaseIterable, Identifiable {
    case expression
    case proverb

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expression: return "常用句与表达"
        case .proverb: return "谚语"
        }
    }
}

struct TextbookSentenceSource: Codable {
    var grade: String
    var book: String
    var unit: String
    var english: String
    var chinese: String
    var kind: SentenceKind
    var sourcePDFPage: Int?
}

struct SentenceEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var grade: String
    var book: String
    var unit: String
    var english: String
    var chinese: String
    var kind: SentenceKind
    var sourcePDFPage: Int?

    init(source: TextbookSentenceSource) {
        id = UUID()
        grade = source.grade
        book = source.book
        unit = source.unit
        english = source.english
        chinese = source.chinese
        kind = source.kind
        sourcePDFPage = source.sourcePDFPage
    }

    init(
        grade: String = "自定义",
        book: String = "未分类",
        unit: String = "未分类",
        english: String,
        chinese: String,
        kind: SentenceKind = .expression
    ) {
        id = UUID()
        self.grade = grade
        self.book = book
        self.unit = unit
        self.english = english
        self.chinese = chinese
        self.kind = kind
        sourcePDFPage = nil
    }

    var textbookLabel: String {
        "\(grade)\(book) \(unit)"
    }
}
