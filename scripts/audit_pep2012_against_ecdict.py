#!/usr/bin/env python3
"""Rough-screen OCR English spelling against ECDICT.

The full ECDICT database is a development-time source and is no longer bundled
in the app resources. This audit uses the full raw source when available, then
falls back to the compact runtime dictionary.
"""

import json
import re
import sqlite3
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_CANDIDATES = [
    ROOT / "教材数据整理/raw/stardict_full.db",
    ROOT / "教材数据整理/stardict_full.db",
    ROOT / "Sources/DictationCoachApp/Resources/stardict.db",
    ROOT / "Sources/DictationCoachApp/Resources/mini_stardict.db",
]
DB_PATH = next((path for path in DB_CANDIDATES if path.exists()), DB_CANDIDATES[-1])
VOCAB_PATHS = [
    ROOT / "Sources/DictationCoachApp/Resources/pep_vocab.json",
    ROOT / "Sources/DictationCoachApp/Resources/pep_vocab_supplement.json",
]
SENTENCE_PATH = ROOT / "教材数据整理/pep2012_sentences_verified.json"
OUTPUT_DIR = ROOT / "教材数据整理"

WORD_RE = re.compile(r"[A-Za-z]+(?:['’-][A-Za-z]+)*")
KNOWN_VALID_TOKENS = {"binbin"}
KNOWN_OCR_PATTERNS = re.compile(
    r"\b(?:Im|T'm|T'd|Theyre|canit|isnit|mulel|Mikes|isnt|arent|wasnt|werent|dont|doesnt|didnt|cant|couldnt|wont|wouldnt|havent|hasnt|hadnt)\b|Appendix|[•⋯]",
    flags=re.I,
)

CONTRACTIONS = {
    "i'm": ["i", "am"], "you're": ["you", "are"], "he's": ["he", "is"],
    "she's": ["she", "is"], "it's": ["it", "is"], "we're": ["we", "are"],
    "they're": ["they", "are"], "isn't": ["is", "not"], "aren't": ["are", "not"],
    "wasn't": ["was", "not"], "weren't": ["were", "not"], "don't": ["do", "not"],
    "doesn't": ["does", "not"], "didn't": ["did", "not"], "can't": ["can", "not"],
    "couldn't": ["could", "not"], "won't": ["will", "not"], "wouldn't": ["would", "not"],
    "let's": ["let", "us"], "what's": ["what", "is"], "who's": ["who", "is"],
    "where's": ["where", "is"], "that's": ["that", "is"], "there's": ["there", "is"],
    "i'll": ["i", "will"], "we'll": ["we", "will"], "i'd": ["i", "would"],
    "you've": ["you", "have"], "we've": ["we", "have"], "haven't": ["have", "not"],
    "hasn't": ["has", "not"], "hadn't": ["had", "not"],
}


def lemma_candidates(word: str) -> list[str]:
    candidates = [word]
    if word.endswith("ies") and len(word) > 3:
        candidates.append(word[:-3] + "y")
    if word.endswith("es") and len(word) > 2:
        candidates.append(word[:-2])
    if word.endswith("s") and len(word) > 1:
        candidates.append(word[:-1])
    if word.endswith("ing") and len(word) > 4:
        candidates.extend([word[:-3], word[:-3] + "e"])
    if word.endswith("ed") and len(word) > 3:
        candidates.extend([word[:-2], word[:-1]])
    if word.endswith("er") and len(word) > 3:
        candidates.extend([word[:-2], word[:-1]])
    return list(dict.fromkeys(candidates))


connection = sqlite3.connect(DB_PATH)
lookup_cache: dict[str, bool] = {}
suggestion_cache: dict[str, list[str]] = {}


def lookup_exact(word: str) -> bool:
    normalized = word.lower().replace("’", "'").strip()
    if normalized not in lookup_cache:
        row = connection.execute(
            "SELECT 1 FROM stardict WHERE word = ? COLLATE NOCASE LIMIT 1",
            (normalized,),
        ).fetchone()
        lookup_cache[normalized] = row is not None
    return lookup_cache[normalized]


def resolves(word: str) -> bool:
    normalized = word.lower().replace("’", "'")
    if normalized in KNOWN_VALID_TOKENS:
        return True
    expanded = CONTRACTIONS.get(normalized)
    if expanded:
        return all(any(lookup_exact(candidate) for candidate in lemma_candidates(part)) for part in expanded)
    if normalized.endswith("'s"):
        normalized = normalized[:-2]
    return any(lookup_exact(candidate) for candidate in lemma_candidates(normalized))


def suggestions(word: str) -> list[str]:
    normalized = word.lower().replace("’", "'")
    if normalized in suggestion_cache:
        return suggestion_cache[normalized]
    if not normalized or not normalized[0].isalpha():
        return []
    rows = connection.execute(
        """
        SELECT word FROM stardict
        WHERE word LIKE ? AND length(word) BETWEEN ? AND ?
        LIMIT 800
        """,
        (normalized[0] + "%", max(1, len(normalized) - 2), len(normalized) + 2),
    ).fetchall()
    ranked = sorted(
        ((SequenceMatcher(None, normalized, row[0].lower()).ratio(), row[0]) for row in rows),
        reverse=True,
    )
    result = [candidate for score, candidate in ranked if score >= 0.64][:3]
    suggestion_cache[normalized] = result
    return result


# Check textbook word and phrase spellings. A phrase is accepted when every component resolves.
vocab_issues = []
for path in VOCAB_PATHS:
    data = json.loads(path.read_text(encoding="utf-8"))
    for word, tags in data.items():
        components = WORD_RE.findall(word)
        exact = lookup_exact(word)
        unresolved = [component for component in components if not resolves(component)]
        if exact or (len(components) > 1 and not unresolved):
            continue
        issue = "unknown_word" if len(components) == 1 else "unknown_phrase_components"
        for tag in tags:
            vocab_issues.append({
                "issue": issue,
                "word": word,
                "grade": tag["grade"],
                "book": tag["book"],
                "unit": tag["unit"],
                "unknownComponents": unresolved,
                "suggestions": {token: suggestions(token) for token in unresolved or components},
            })


# Check OCR sentence English tokens and known OCR artifacts.
sentence_source = json.loads(SENTENCE_PATH.read_text(encoding="utf-8"))
sentence_issues = []
for index, entry in enumerate(sentence_source):
    tokens = WORD_RE.findall(entry["english"])
    unresolved = sorted({token for token in tokens if not resolves(token)}, key=str.lower)
    known_pattern = KNOWN_OCR_PATTERNS.search(entry["english"]) is not None
    if not unresolved and not known_pattern:
        continue
    sentence_issues.append({
        "priority": "high" if known_pattern else "review",
        "issues": (["known_ocr_pattern"] if known_pattern else []) + (["unknown_tokens"] if unresolved else []),
        "index": index,
        "grade": entry["grade"],
        "book": entry["book"],
        "unit": entry["unit"],
        "kind": entry["kind"],
        "sourcePDFPage": entry["sourcePDFPage"],
        "english": entry["english"],
        "unknownTokens": unresolved,
        "suggestions": {token: suggestions(token) for token in unresolved},
    })

connection.close()

vocab_issues.sort(key=lambda item: (item["grade"], item["book"], item["unit"], item["word"]))
sentence_issues.sort(key=lambda item: (0 if item["priority"] == "high" else 1, item["sourcePDFPage"], item["index"]))

(OUTPUT_DIR / "ecdict_vocab_spelling_review.json").write_text(
    json.dumps(vocab_issues, ensure_ascii=False, indent=2), encoding="utf-8"
)
(OUTPUT_DIR / "ecdict_sentence_spelling_review.json").write_text(
    json.dumps(sentence_issues, ensure_ascii=False, indent=2), encoding="utf-8"
)

priority_counts = Counter(item["priority"] for item in sentence_issues)
summary = f"""# PEP 2012 英文拼写粗筛

本检查只使用 ECDICT 校验英文拼写，不判断或修改中文翻译。

## 词汇

- 教材记录：816 条
- 不同单词或短语：785 个
- 需要人工确认的词汇记录：{len(vocab_issues)} 条

单个英文词未被 ECDICT 或基础词形命中时会进入清单；短语只有在某个组成词也无法命中时才进入清单。

## 句子、常用表达和谚语

- 总数：{len(sentence_source)} 条
- 需要人工确认：{len(sentence_issues)} 条
- 命中已知 OCR 异常模式：{priority_counts['high']} 条
- 含 ECDICT 未识别词：{sum(1 for item in sentence_issues if 'unknown_tokens' in item['issues'])} 条

未知词可能是 OCR 错拼，也可能是人名、地名、缩写或教材专有词。清单提供相近的 ECDICT 候选，但不会自动替换。
"""
(OUTPUT_DIR / "ecdict_spelling_audit_summary.md").write_text(summary, encoding="utf-8")

print(json.dumps({
    "vocabReview": len(vocab_issues),
    "sentenceReview": len(sentence_issues),
    "knownOCRPatterns": priority_counts["high"],
}, ensure_ascii=False))
