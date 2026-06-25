import Foundation

@MainActor
final class SentenceStore: ObservableObject {
    @Published private(set) var sentences: [SentenceEntry] = []
    @Published var singleEnglish = ""
    @Published var singleChinese = ""
    @Published var importText = ""
    @Published var dataMessage = ""

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        loadSentences()
    }

    var allSentencesSorted: [SentenceEntry] {
        sentences.sorted {
            let lhs = sortKey(for: $0)
            let rhs = sortKey(for: $1)
            return lhs == rhs
                ? $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending
                : lhs < rhs
        }
    }

    var grades: [String] { sortedValues(\.grade) }
    var books: [String] { sortedValues(\.book) }
    var units: [String] { sortedValues(\.unit) }

    var expressionCount: Int {
        sentences.filter { $0.kind == .expression }.count
    }

    var proverbCount: Int {
        sentences.filter { $0.kind == .proverb }.count
    }

    func addSingleSentence() {
        let english = clean(singleEnglish)
        let chinese = clean(singleChinese)
        guard !english.isEmpty else {
            dataMessage = "先输入英文句子。"
            return
        }
        guard !contains(english) else {
            dataMessage = "这条英文句子已经在常用句中。"
            return
        }

        sentences.append(SentenceEntry(english: english, chinese: chinese))
        singleEnglish = ""
        singleChinese = ""
        saveSentences()
        dataMessage = "已新增常用句。"
    }

    func importSentences() {
        let candidates = parseImportLines(importText)
        guard !candidates.isEmpty else {
            dataMessage = "先输入一些句子。"
            return
        }

        let result = append(candidates)
        importText = ""
        dataMessage = "已导入 \(result.imported) 条，跳过 \(result.skipped) 条重复内容。"
    }

    func importRecognizedLines(_ lines: [String]) {
        let candidates = lines
            .map { SentenceEntry(english: clean($0), chinese: "") }
            .filter { !$0.english.isEmpty }
        guard !candidates.isEmpty else {
            dataMessage = "OCR 没有可导入的英文句子。"
            return
        }
        let result = append(candidates)
        dataMessage = "OCR 已导入 \(result.imported) 条，跳过 \(result.skipped) 条重复内容。"
    }

    func updateSentence(_ entry: SentenceEntry, english: String, chinese: String) {
        let cleanedEnglish = clean(english)
        guard !cleanedEnglish.isEmpty,
              let index = sentences.firstIndex(where: { $0.id == entry.id }) else { return }
        if sentences.contains(where: { $0.id != entry.id && normalized($0.english) == normalized(cleanedEnglish) }) {
            dataMessage = "这条英文句子已经存在。"
            return
        }
        sentences[index].english = cleanedEnglish
        sentences[index].chinese = clean(chinese)
        saveSentences()
        dataMessage = "已保存句子。"
    }

    func deleteSentence(_ entry: SentenceEntry) {
        guard let index = sentences.firstIndex(where: { $0.id == entry.id }) else { return }
        sentences.remove(at: index)
        saveSentences()
        dataMessage = "已删除句子。"
    }

    private func append(_ candidates: [SentenceEntry]) -> (imported: Int, skipped: Int) {
        var imported = 0
        var skipped = 0
        for candidate in candidates {
            if contains(candidate.english) {
                skipped += 1
            } else {
                sentences.append(candidate)
                imported += 1
            }
        }
        saveSentences()
        return (imported, skipped)
    }

    private func parseImportLines(_ text: String) -> [SentenceEntry] {
        text.components(separatedBy: .newlines).compactMap { rawLine in
            let line = clean(rawLine)
            guard !line.isEmpty else { return nil }
            let separators = ["|", "\t"]
            for separator in separators where line.contains(separator) {
                let parts = line.components(separatedBy: separator)
                return SentenceEntry(
                    english: clean(parts.first ?? ""),
                    chinese: clean(parts.dropFirst().joined(separator: separator))
                )
            }
            return SentenceEntry(english: line, chinese: "")
        }
    }

    private func contains(_ english: String) -> Bool {
        sentences.contains { normalized($0.english) == normalized(english) }
    }

    private func loadSentences() {
        let savedURL = sentencesFileURL()
        if FileManager.default.fileExists(atPath: savedURL.path),
           let data = try? Data(contentsOf: savedURL),
           let decoded = try? decoder.decode([SentenceEntry].self, from: data) {
            sentences = decoded
            return
        }

        guard let url = Bundle.module.url(forResource: "pep2012_sentences_verified", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let sources = try? decoder.decode([TextbookSentenceSource].self, from: data) else {
            dataMessage = "未找到已核验的常用句数据。"
            return
        }

        sentences = sources.map(SentenceEntry.init(source:))
        saveSentences()
    }

    private func saveSentences() {
        do {
            let directory = appSupportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(sentences)
            try data.write(to: sentencesFileURL(), options: [.atomic])
        } catch {
            dataMessage = "常用句保存失败：\(error.localizedDescription)"
        }
    }

    private func sortedValues(_ keyPath: KeyPath<SentenceEntry, String>) -> [String] {
        Array(Set(sentences.map { $0[keyPath: keyPath] })).sorted { sortKey($0) < sortKey($1) }
    }

    private func sortKey(for sentence: SentenceEntry) -> String {
        "\(sortKey(sentence.grade))-\(sortKey(sentence.book))-\(sortKey(sentence.unit))"
    }

    private func sortKey(_ value: String) -> String {
        value
            .replacingOccurrences(of: "三年级", with: "3")
            .replacingOccurrences(of: "四年级", with: "4")
            .replacingOccurrences(of: "五年级", with: "5")
            .replacingOccurrences(of: "六年级", with: "6")
            .replacingOccurrences(of: "上册", with: "1")
            .replacingOccurrences(of: "下册", with: "2")
            .replacingOccurrences(of: "Unit ", with: "")
    }

    private func normalized(_ value: String) -> String {
        clean(value)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("AIEnglishDictationCoach", isDirectory: true)
    }

    private func sentencesFileURL() -> URL {
        appSupportDirectory().appendingPathComponent("sentences.json")
    }
}
