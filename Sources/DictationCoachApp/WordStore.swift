import Foundation
import SwiftUI

@MainActor
final class WordStore: ObservableObject {
    private enum ImportWordResult: Equatable {
        case added
        case tagged
        case existing
    }

    private struct ImportSummary {
        var added = 0
        var tagged = 0
        var existing = 0
    }
    @Published private(set) var words: [WordEntry] = []
    @Published var importText = ""
    @Published var singleWordText = ""
    @Published var dataMessage = ""

    private var dictionary: [String: DictionaryEntry] = [:]
    private let sqliteDictionary = SQLiteDictionary()
    private let textbookIndex = TextbookIndex()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        loadIPADictionary()
        loadWords()
        migrateToVerifiedTextbookBaselineIfNeeded()
        migrateToCatalogBaselineIfNeeded()
        migrateToPep2024CatalogIfNeeded()
        enrichWordsFromDictionary()
    }

    var wrongWords: [WordEntry] {
        words
            .filter { $0.isInWrongBook }
            .sorted {
                if $0.masteryStatus != $1.masteryStatus {
                    return statusPriority($0.masteryStatus) < statusPriority($1.masteryStatus)
                }
                if $0.wrongCount != $1.wrongCount {
                    return $0.wrongCount > $1.wrongCount
                }
                return ($0.lastWrongAt ?? .distantPast) > ($1.lastWrongAt ?? .distantPast)
            }
    }

    var activeWrongWords: [WordEntry] {
        wrongWords.filter { $0.masteryStatus != .basic }
    }

    var allWordsSorted: [WordEntry] {
        words
            .filter { $0.isArchivedFromWordBook != true }
            .sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }

    func words(inCatalog catalogID: String) -> [WordEntry] {
        allWordsSorted.filter { wordBelongsToCatalog($0, catalogID: catalogID) }
    }

    func wrongWords(inCatalog catalogID: String) -> [WordEntry] {
        wrongWords.filter { wordBelongsToCatalog($0, catalogID: catalogID) }
    }

    func activeWrongWords(inCatalog catalogID: String) -> [WordEntry] {
        activeWrongWords.filter { wordBelongsToCatalog($0, catalogID: catalogID) }
    }

    func textbookGrades(catalogID: String) -> [String] {
        textbookIndex.grades(catalogID: catalogID)
    }

    func textbookBooks(catalogID: String) -> [String] {
        textbookIndex.books(catalogID: catalogID)
    }

    func textbookUnits(catalogID: String) -> [String] {
        textbookIndex.units(catalogID: catalogID)
    }

    func textbookTags(for word: WordEntry, catalogID: String? = nil) -> [TextbookTag] {
        let indexed = textbookIndex.tags(for: word.word, catalogID: catalogID)
        let userTags = (word.userTextbookTags ?? []).filter { tag in
            catalogID == nil || tag.effectiveCatalogID == catalogID
        }
        var seen = Set<String>()
        return (indexed + userTags).filter { seen.insert($0.id).inserted }
    }

    func word(withID id: UUID) -> WordEntry? {
        words.first { $0.id == id }
    }

    func savePracticeSession(_ snapshot: PracticeSessionSnapshot) {
        do {
            let directory = appSupportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: practiceSessionFileURL(), options: [.atomic])
        } catch {
            dataMessage = "听写进度保存失败：\(error.localizedDescription)"
        }
    }

    func loadPracticeSession() -> PracticeSessionSnapshot? {
        let url = practiceSessionFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(PracticeSessionSnapshot.self, from: data)
        } catch {
            dataMessage = "听写进度读取失败：\(error.localizedDescription)"
            return nil
        }
    }

    func clearPracticeSession() {
        let url = practiceSessionFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func addSingleWord(destination: TextbookImportDestination, force: Bool = false) {
        let word = normalizeWord(singleWordText)
        guard !word.isEmpty else {
            dataMessage = "先输入一个单词。"
            return
        }

        if !force, !words.contains(where: { $0.word == word }), let warning = singleWordWarning(for: word) {
            dataMessage = warning.message
            return
        }

        let result = importWord(word, destination: destination)
        saveWords()
        singleWordText = ""
        dataMessage = result == .existing ? "\(word) 已在当前单元。" : "已新增 \(word)。"
    }

    func pendingSingleWordWarning() -> WordInputWarning? {
        let word = normalizeWord(singleWordText)
        guard !word.isEmpty else { return nil }
        guard !words.contains(where: { $0.word == word }) else { return nil }
        return singleWordWarning(for: word)
    }

    func importWords(destination: TextbookImportDestination) {
        let candidates = importText
            .components(separatedBy: CharacterSet(charactersIn: "\n,，;；\t "))
            .map(normalizeWord)
            .filter { !$0.isEmpty }

        guard !candidates.isEmpty else {
            dataMessage = "先输入一些单词。"
            return
        }

        let summary = importWords(candidates, destination: destination)

        saveWords()
        importText = ""
        dataMessage = summaryMessage(prefix: "已导入", summary: summary)
    }

    func importWords(_ candidates: [String], source: String, destination: TextbookImportDestination) {
        let normalizedWords = candidates
            .map(normalizeWord)
            .filter { !$0.isEmpty }

        guard !normalizedWords.isEmpty else {
            dataMessage = "\(source) 没有可导入的单词。"
            return
        }

        let summary = importWords(normalizedWords, destination: destination)

        saveWords()
        dataMessage = summaryMessage(prefix: "\(source) 已导入", summary: summary)
    }

    func updateWord(for entry: WordEntry, newWord rawWord: String) {
        let newWord = normalizeWord(rawWord)
        guard !newWord.isEmpty else {
            dataMessage = "单词不能为空。"
            return
        }

        guard let index = words.firstIndex(where: { $0.id == entry.id }) else { return }

        if words.contains(where: { $0.id != entry.id && $0.word == newWord }) {
            dataMessage = "\(newWord) 已经在单词本里。"
            return
        }

        words[index].word = newWord
        let dictionaryEntry = lookupDictionaryEntry(for: newWord)
        words[index].ipaUS = dictionaryEntry?.usIPA
        words[index].ipaUK = dictionaryEntry?.ukIPA
        words[index].commonMeaning = dictionaryEntry?.commonMeaning
        words[index].meanings = dictionaryEntry?.meanings
        words[index].exampleEnglish = dictionaryEntry?.example?.english
        words[index].exampleChinese = dictionaryEntry?.example?.chinese
        saveWords()
        dataMessage = "已修改为 \(newWord)。"
    }

    func deleteWord(_ entry: WordEntry) {
        guard let index = words.firstIndex(where: { $0.id == entry.id }) else { return }
        let word = words[index].word
        words.remove(at: index)
        saveWords()
        dataMessage = "已删除 \(word)。"
    }

    func markCorrect(_ entry: WordEntry) {
        guard let index = words.firstIndex(where: { $0.id == entry.id }) else { return }
        words[index].correctCount += 1
        words[index].lastPracticedAt = Date()
        if words[index].isInWrongBook {
            words[index].consecutiveCorrectInWrongBook += 1
            if words[index].consecutiveCorrectInWrongBook >= 3 {
                words[index].masteryStatus = .basic
            } else {
                words[index].masteryStatus = .reviewing
            }
        }
        saveWords()
    }

    func markWrong(_ entry: WordEntry) {
        guard let index = words.firstIndex(where: { $0.id == entry.id }) else { return }
        words[index].wrongCount += 1
        words[index].consecutiveCorrectInWrongBook = 0
        words[index].lastPracticedAt = Date()
        words[index].lastWrongAt = Date()
        words[index].isInWrongBook = true
        words[index].masteryStatus = .reviewing
        saveWords()
    }

    func resetPracticeStats(for entry: WordEntry) {
        guard let index = words.firstIndex(where: { $0.id == entry.id }) else { return }
        let word = words[index].word
        let ipaUS = words[index].ipaUS
        let ipaUK = words[index].ipaUK
        let commonMeaning = words[index].commonMeaning
        let meanings = words[index].meanings
        let exampleEnglish = words[index].exampleEnglish
        let exampleChinese = words[index].exampleChinese
        let isArchivedFromWordBook = words[index].isArchivedFromWordBook
        let catalogID = words[index].catalogID
        let userTextbookTags = words[index].userTextbookTags
        words[index] = WordEntry(word: word, dictionaryEntry: DictionaryEntry(
            usIPA: ipaUS,
            ukIPA: ipaUK,
            commonMeaning: commonMeaning,
            meanings: meanings,
            example: exampleEnglish == nil && exampleChinese == nil ? nil : WordExample(
                english: exampleEnglish ?? "",
                chinese: exampleChinese ?? ""
            )
        ))
        words[index].id = entry.id
        words[index].isArchivedFromWordBook = isArchivedFromWordBook
        words[index].catalogID = catalogID
        words[index].userTextbookTags = userTextbookTags
        saveWords()
    }

    func refreshDictionaryPronunciation(for entry: WordEntry) {
        guard let index = words.firstIndex(where: { $0.id == entry.id }) else { return }
        let dictionaryEntry = lookupDictionaryEntry(for: entry.word)
        words[index].ipaUS = dictionaryEntry?.usIPA
        words[index].ipaUK = dictionaryEntry?.ukIPA
        words[index].commonMeaning = dictionaryEntry?.commonMeaning
        words[index].meanings = dictionaryEntry?.meanings
        words[index].exampleEnglish = dictionaryEntry?.example?.english
        words[index].exampleChinese = dictionaryEntry?.example?.chinese
        saveWords()
    }

    private func wordBelongsToCatalog(_ word: WordEntry, catalogID: String) -> Bool {
        if (word.catalogID ?? TextbookCatalog.pepPrimary2012ID) == catalogID {
            return true
        }
        return textbookTags(for: word, catalogID: catalogID).isEmpty == false
    }

    private func importWords(_ candidates: [String], destination: TextbookImportDestination) -> ImportSummary {
        var summary = ImportSummary()
        var seen = Set<String>()
        for word in candidates where seen.insert(word).inserted {
            switch importWord(word, destination: destination) {
            case .added: summary.added += 1
            case .tagged: summary.tagged += 1
            case .existing: summary.existing += 1
            }
        }
        return summary
    }

    private func importWord(_ word: String, destination: TextbookImportDestination) -> ImportWordResult {
        let tag = TextbookTag(
            catalogID: destination.catalogID,
            grade: destination.grade,
            book: destination.book,
            unit: destination.unit,
            meaning: textbookIndex.tags(for: word, catalogID: destination.catalogID).first(where: {
                $0.grade == destination.grade && $0.book == destination.book && $0.unit == destination.unit
            })?.meaning ?? "",
            requirement: destination.requirement
        )

        if let index = words.firstIndex(where: { $0.word == word }) {
            let alreadyExists = textbookTags(for: words[index], catalogID: destination.catalogID).contains {
                $0.grade == destination.grade && $0.book == destination.book && $0.unit == destination.unit
            }
            guard !alreadyExists else { return .existing }
            words[index].userTextbookTags = (words[index].userTextbookTags ?? []) + [tag]
            words[index].isArchivedFromWordBook = false
            return .tagged
        }

        var entry = WordEntry(word: word, dictionaryEntry: lookupDictionaryEntry(for: word))
        entry.catalogID = destination.catalogID
        entry.userTextbookTags = [tag]
        words.append(entry)
        return .added
    }

    private func summaryMessage(prefix: String, summary: ImportSummary) -> String {
        "\(prefix) \(summary.added) 个新单词，追加 \(summary.tagged) 个教材归属，已存在 \(summary.existing) 个。"
    }

    private func normalizeWord(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func singleWordWarning(for word: String) -> WordInputWarning? {
        if !isEnglishWordLike(word) {
            return WordInputWarning(
                word: word,
                title: "这看起来不像英文单词",
                message: "“\(word)” 包含非英文单词常见字符，是否仍然添加？"
            )
        }

        if lookupDictionaryEntry(for: word) == nil {
            return WordInputWarning(
                word: word,
                title: "可能拼写有误",
                message: "本地词典没有查到 “\(word)”。如果这是专有名词或你确认拼写正确，可以继续添加。"
            )
        }

        return nil
    }

    private func isEnglishWordLike(_ word: String) -> Bool {
        let pattern = #"^[a-z]+(?:[-'][a-z]+)*$"#
        return word.range(of: pattern, options: .regularExpression) != nil
    }

    private func lookupDictionaryEntry(for word: String) -> DictionaryEntry? {
        if let sqliteEntry = sqliteDictionary.lookup(word) {
            return merge(primary: sqliteEntry, fallback: dictionary[word])
        }
        return dictionary[word]
    }

    private func merge(primary: DictionaryEntry, fallback: DictionaryEntry?) -> DictionaryEntry {
        DictionaryEntry(
            usIPA: primary.usIPA ?? fallback?.usIPA,
            ukIPA: primary.ukIPA ?? fallback?.ukIPA,
            commonMeaning: primary.commonMeaning ?? fallback?.commonMeaning,
            meanings: primary.meanings ?? fallback?.meanings,
            example: primary.example ?? fallback?.example
        )
    }

    private func statusPriority(_ status: MasteryStatus) -> Int {
        switch status {
        case .reviewing:
            return 0
        case .new:
            return 1
        case .basic:
            return 2
        }
    }

    private func loadIPADictionary() {
        guard let url = Bundle.module.url(forResource: "ipa_dictionary", withExtension: "json") else {
            dataMessage = "未找到内置音标词典。"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            dictionary = try decoder.decode([String: DictionaryEntry].self, from: data)
        } catch {
            dataMessage = "音标词典读取失败：\(error.localizedDescription)"
        }
    }

    private func loadWords() {
        let url = wordsFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            words = try decoder.decode([WordEntry].self, from: data)
        } catch {
            dataMessage = "本地数据读取失败：\(error.localizedDescription)"
        }
    }

    private func migrateToVerifiedTextbookBaselineIfNeeded() {
        let migrationVersion = "pep2012-verified-816-v1"
        let markerURL = textbookMigrationMarkerURL()
        if (try? String(contentsOf: markerURL, encoding: .utf8)) == migrationVersion {
            return
        }

        guard backupWordsBeforeTextbookMigration() else { return }

        var existingByWord = Dictionary(grouping: words) { canonicalWord($0.word) }
        var migrated: [WordEntry] = []

        for vocabulary in textbookIndex.verifiedVocabulary {
            let key = canonicalWord(vocabulary.word)
            let matches = existingByWord.removeValue(forKey: key) ?? []
            var entry: WordEntry

            if matches.isEmpty {
                entry = WordEntry(word: vocabulary.word, dictionaryEntry: lookupDictionaryEntry(for: vocabulary.word))
            } else {
                entry = mergeLearningHistory(matches, canonicalWord: vocabulary.word)
                entry.word = vocabulary.word
            }

            if needsDictionaryRefresh(entry.commonMeaning, missingText: "未收录释义"), !vocabulary.meaning.isEmpty {
                entry.commonMeaning = vocabulary.meaning
            }
            entry.isArchivedFromWordBook = false
            migrated.append(entry)
        }

        let preservedWrongWords = existingByWord.values
            .flatMap { $0 }
            .filter(\.isInWrongBook)
            .map { entry -> WordEntry in
                var archived = entry
                archived.isArchivedFromWordBook = true
                return archived
            }

        words = migrated + preservedWrongWords
        saveWords()

        do {
            let directory = appSupportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try migrationVersion.write(to: markerURL, atomically: true, encoding: .utf8)
            dataMessage = "已同步 \(migrated.count) 个教材词条，并保留 \(preservedWrongWords.count) 个历史错词。"
        } catch {
            dataMessage = "教材词库已同步，但迁移标记保存失败：\(error.localizedDescription)"
        }
    }

    private func migrateToCatalogBaselineIfNeeded() {
        let migrationVersion = "catalog-baseline-v1"
        let markerURL = appSupportDirectory().appendingPathComponent("catalog_baseline_version.txt")
        if (try? String(contentsOf: markerURL, encoding: .utf8)) == migrationVersion {
            return
        }

        var changed = false
        for index in words.indices {
            if words[index].catalogID == nil {
                words[index].catalogID = TextbookCatalog.pepPrimary2012ID
                changed = true
            }
            if words[index].isArchivedFromWordBook == true {
                words[index].isArchivedFromWordBook = false
                changed = true
            }
        }
        if changed { saveWords() }

        do {
            let directory = appSupportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try migrationVersion.write(to: markerURL, atomically: true, encoding: .utf8)
        } catch {
            dataMessage = "教材词库迁移标记保存失败：\(error.localizedDescription)"
        }
    }

    private func migrateToPep2024CatalogIfNeeded() {
        let migrationVersion = "pep2024-vocab-845-v1"
        let markerURL = appSupportDirectory().appendingPathComponent("pep2024_vocab_version.txt")
        if (try? String(contentsOf: markerURL, encoding: .utf8)) == migrationVersion {
            return
        }

        let vocabulary = textbookIndex.vocabulary(catalogID: TextbookCatalog.pepPrimary2024ID)
        var existingByWord: [String: Int] = [:]
        for index in words.indices where existingByWord[canonicalWord(words[index].word)] == nil {
            existingByWord[canonicalWord(words[index].word)] = index
        }
        var added = 0
        var updatedIPA = 0

        for item in vocabulary {
            let key = canonicalWord(item.word)
            if let index = existingByWord[key] {
                if needsDictionaryRefresh(words[index].ipaUS, missingText: "未收录音标"),
                   let ipa = item.tag.ipa, !ipa.isEmpty {
                    words[index].ipaUS = ipa
                    updatedIPA += 1
                }
                continue
            }

            var entry = WordEntry(word: item.word, dictionaryEntry: lookupDictionaryEntry(for: item.word))
            entry.catalogID = TextbookCatalog.pepPrimary2024ID
            if needsDictionaryRefresh(entry.ipaUS, missingText: "未收录音标"),
               let ipa = item.tag.ipa, !ipa.isEmpty {
                entry.ipaUS = ipa
            }
            words.append(entry)
            existingByWord[key] = words.count - 1
            added += 1
        }

        if added > 0 || updatedIPA > 0 { saveWords() }

        do {
            let directory = appSupportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try migrationVersion.write(to: markerURL, atomically: true, encoding: .utf8)
            dataMessage = "已接入人教版 3–6 年级（新）\(vocabulary.count) 个单词，其中新增 \(added) 个。"
        } catch {
            dataMessage = "新版教材词库已接入，但迁移标记保存失败：\(error.localizedDescription)"
        }
    }

    private func mergeLearningHistory(_ entries: [WordEntry], canonicalWord: String) -> WordEntry {
        var merged = entries.max {
            ($0.lastPracticedAt ?? .distantPast) < ($1.lastPracticedAt ?? .distantPast)
        } ?? WordEntry(word: canonicalWord)

        merged.correctCount = entries.reduce(0) { $0 + $1.correctCount }
        merged.wrongCount = entries.reduce(0) { $0 + $1.wrongCount }
        merged.isInWrongBook = entries.contains(where: \.isInWrongBook)
        merged.consecutiveCorrectInWrongBook = entries.map(\.consecutiveCorrectInWrongBook).max() ?? 0
        merged.lastPracticedAt = entries.compactMap(\.lastPracticedAt).max()
        merged.lastWrongAt = entries.compactMap(\.lastWrongAt).max()

        if merged.isInWrongBook {
            merged.masteryStatus = merged.consecutiveCorrectInWrongBook >= 3 ? .basic : .reviewing
        } else {
            merged.masteryStatus = entries.contains(where: { $0.masteryStatus == .basic }) ? .basic : .new
        }
        return merged
    }

    private func backupWordsBeforeTextbookMigration() -> Bool {
        let source = wordsFileURL()
        guard FileManager.default.fileExists(atPath: source.path) else { return true }

        let backup = appSupportDirectory().appendingPathComponent("words_before_pep2012_migration.json")
        guard !FileManager.default.fileExists(atPath: backup.path) else { return true }

        do {
            try FileManager.default.copyItem(at: source, to: backup)
            return true
        } catch {
            dataMessage = "原单词数据备份失败，已取消教材词库迁移：\(error.localizedDescription)"
            return false
        }
    }

    private func canonicalWord(_ value: String) -> String {
        normalizeWord(value)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
    }

    private func enrichWordsFromDictionary() {
        var changed = false

        for index in words.indices {
            guard let dictionaryEntry = lookupDictionaryEntry(for: words[index].word) else { continue }

            if needsDictionaryRefresh(words[index].ipaUS, missingText: "未收录音标") {
                words[index].ipaUS = dictionaryEntry.usIPA
                changed = true
            }
            if needsDictionaryRefresh(words[index].ipaUK, missingText: "未收录音标") {
                words[index].ipaUK = dictionaryEntry.ukIPA
                changed = true
            }
            if needsDictionaryRefresh(words[index].commonMeaning, missingText: "未收录释义") {
                words[index].commonMeaning = dictionaryEntry.commonMeaning
                changed = true
            }
            if words[index].meanings == nil {
                words[index].meanings = dictionaryEntry.meanings
                changed = true
            }
            if words[index].exampleEnglish == nil {
                words[index].exampleEnglish = dictionaryEntry.example?.english
                changed = true
            }
            if words[index].exampleChinese == nil {
                words[index].exampleChinese = dictionaryEntry.example?.chinese
                changed = true
            }
        }

        if changed {
            saveWords()
        }
    }

    private func needsDictionaryRefresh(_ value: String?, missingText: String) -> Bool {
        guard let value else { return true }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == missingText
    }

    private func saveWords() {
        do {
            let directory = appSupportDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(words)
            try data.write(to: wordsFileURL(), options: [.atomic])
        } catch {
            dataMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func appSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("AIEnglishDictationCoach", isDirectory: true)
    }

    private func wordsFileURL() -> URL {
        appSupportDirectory().appendingPathComponent("words.json")
    }

    private func practiceSessionFileURL() -> URL {
        appSupportDirectory().appendingPathComponent("practice_session.json")
    }

    private func textbookMigrationMarkerURL() -> URL {
        appSupportDirectory().appendingPathComponent("textbook_baseline_version.txt")
    }
}
