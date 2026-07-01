import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteDictionary {
    private var db: OpaquePointer?

    init() {
        guard let url = Bundle.module.url(forResource: "mini_stardict", withExtension: "db") else {
            return
        }

        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            db = nil
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func lookup(_ word: String) -> DictionaryEntry? {
        let exact = lookupExact(word)
        guard exact?.usIPA == nil else {
            return exact
        }

        if let base = lemmaCandidates(for: word).compactMap(lookupExact).first(where: { $0.usIPA != nil }) {
            guard let exact else { return base }
            return DictionaryEntry(
                usIPA: base.usIPA,
                ukIPA: exact.ukIPA ?? base.ukIPA,
                commonMeaning: exact.commonMeaning ?? base.commonMeaning,
                meanings: exact.meanings ?? base.meanings,
                example: exact.example ?? base.example
            )
        }

        return exact
    }

    private func lookupExact(_ word: String) -> DictionaryEntry? {
        guard let db else { return nil }

        let sql = """
        SELECT phonetic, translation
        FROM stardict
        WHERE word = ?
        LIMIT 1
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, word, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        let phonetic = columnText(statement, index: 0)
        let translation = columnText(statement, index: 1)
        let meanings = parseMeanings(translation)
        let commonMeaning = meanings.first?.chinese ?? cleanTranslation(translation)

        return DictionaryEntry(
            usIPA: wrapIPA(phonetic),
            ukIPA: nil,
            commonMeaning: commonMeaning,
            meanings: meanings.isEmpty ? nil : meanings,
            example: nil
        )
    }

    private func lemmaCandidates(for word: String) -> [String] {
        var candidates: [String] = []

        if word.hasSuffix("ies"), word.count > 3 {
            candidates.append(String(word.dropLast(3)) + "y")
        }
        if word.hasSuffix("es"), word.count > 2 {
            candidates.append(String(word.dropLast(2)))
        }
        if word.hasSuffix("s"), word.count > 1 {
            candidates.append(String(word.dropLast()))
        }
        if word.hasSuffix("ing"), word.count > 4 {
            candidates.append(String(word.dropLast(3)))
            candidates.append(String(word.dropLast(3)) + "e")
        }
        if word.hasSuffix("ed"), word.count > 3 {
            candidates.append(String(word.dropLast(2)))
            candidates.append(String(word.dropLast(1)))
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            guard candidate != word, !seen.contains(candidate) else { return false }
            seen.insert(candidate)
            return true
        }
    }

    private func columnText(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else { return nil }
        let text = String(cString: value).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func wrapIPA(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("/") && value.hasSuffix("/") {
            return value
        }
        return "/\(value)/"
    }

    private func parseMeanings(_ value: String?) -> [WordMeaning] {
        guard let value else { return [] }

        return value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }
            .map { line in
                let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
                guard parts.count == 2, isPartOfSpeech(parts[0]) else {
                    return WordMeaning(partOfSpeech: "", chinese: line)
                }
                return WordMeaning(partOfSpeech: parts[0], chinese: parts[1])
            }
    }

    private func cleanTranslation(_ value: String?) -> String? {
        guard let value else { return nil }
        return value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.hasPrefix("[") }
    }

    private func isPartOfSpeech(_ value: String) -> Bool {
        value.hasSuffix(".") || value == "interj." || value == "aux." || value == "prep."
    }
}
