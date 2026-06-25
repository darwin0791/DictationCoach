import Foundation

final class TextbookIndex {
    private var tagsByWord: [String: [TextbookTag]] = [:]
    private var phraseComponentTagsByWord: [String: [TextbookTag]] = [:]

    init() {
        tagsByWord = mergeIndexes([
            loadIndex(named: "pep_vocab"),
            loadIndex(named: "pep_vocab_supplement")
        ])
        phraseComponentTagsByWord = buildPhraseComponentIndex(from: tagsByWord)
    }

    var grades: [String] {
        sortedValues { $0.grade }
    }

    var books: [String] {
        sortedValues { $0.book }
    }

    var units: [String] {
        sortedValues { $0.unit }
    }

    var verifiedVocabulary: [(word: String, meaning: String)] {
        tagsByWord.map { word, tags in
            (word: word, meaning: tags.first?.meaning ?? "")
        }
        .sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
    }

    func tags(for word: String) -> [TextbookTag] {
        let normalized = normalize(word)
        if let tags = tagsByWord[normalized] {
            return tags
        }

        let lemmaTags = lemmaCandidates(for: normalized)
            .compactMap { tagsByWord[$0] }
            .flatMap { $0 }

        if !lemmaTags.isEmpty {
            return lemmaTags
        }

        if let phraseTags = phraseComponentTagsByWord[normalized] {
            return phraseTags
        }

        return lemmaCandidates(for: normalized)
            .compactMap { phraseComponentTagsByWord[$0] }
            .flatMap { $0 }
    }

    private func buildPhraseComponentIndex(from source: [String: [TextbookTag]]) -> [String: [TextbookTag]] {
        var index: [String: [TextbookTag]] = [:]

        for (wordOrPhrase, tags) in source where wordOrPhrase.contains(" ") {
            let components = wordOrPhrase
                .split(separator: " ")
                .map { normalize(String($0)) }
                .filter { !$0.isEmpty }

            for component in components {
                index[component, default: []].append(contentsOf: tags)
            }
        }

        return index.mapValues { tags in
            var seen = Set<String>()
            return tags.filter { tag in
                guard !seen.contains(tag.id) else { return false }
                seen.insert(tag.id)
                return true
            }
        }
    }

    private func loadIndex(named resourceName: String) -> [String: [TextbookTag]] {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [TextbookTag]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func mergeIndexes(_ indexes: [[String: [TextbookTag]]]) -> [String: [TextbookTag]] {
        var merged: [String: [TextbookTag]] = [:]

        for index in indexes {
            for (word, tags) in index {
                let normalized = normalize(word)
                for tag in tags where !merged[normalized, default: []].contains(where: { $0.id == tag.id }) {
                    merged[normalized, default: []].append(tag)
                }
            }
        }

        return merged
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sortedValues(_ keyPath: (TextbookTag) -> String) -> [String] {
        let values = tagsByWord.values
            .flatMap { $0 }
            .map(keyPath)
        return Array(Set(values)).sorted { lhs, rhs in
            sortKey(lhs) < sortKey(rhs)
        }
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

        var seen = Set<String>()
        return candidates.filter { candidate in
            guard candidate != word, !seen.contains(candidate) else { return false }
            seen.insert(candidate)
            return true
        }
    }
}
