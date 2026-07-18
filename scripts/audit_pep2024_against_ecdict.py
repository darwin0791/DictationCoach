#!/usr/bin/env python3
"""Rough-screen PEP 2024 English spellings against ECDICT.

This audit checks English only, never Chinese meanings, and never modifies the
textbook resource automatically.
"""

from __future__ import annotations

import json
import re
import sqlite3
from difflib import SequenceMatcher
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "Sources" / "DictationCoachApp" / "Resources" / "pep2024_vocab.json"
OUTPUT = ROOT / "教材数据整理" / "pep2024_ecdict_spelling_review.json"
SUMMARY = ROOT / "教材数据整理" / "pep2024_ecdict_spelling_audit_summary.md"
DB_CANDIDATES = [
    ROOT / "教材数据整理" / "raw" / "stardict_full.db",
    ROOT / "教材数据整理" / "stardict_full.db",
    ROOT / "Sources" / "DictationCoachApp" / "Resources" / "mini_stardict.db",
]
WORD_RE = re.compile(r"[A-Za-z]+(?:['’-][A-Za-z]+)*")
KNOWN_VALID_TOKENS = {"jinggangshan", "kong-zhuhai-macao"}

CONTRACTIONS = {
    "i'm": ["i", "am"], "you're": ["you", "are"], "he's": ["he", "is"],
    "she's": ["she", "is"], "it's": ["it", "is"], "we're": ["we", "are"],
    "they're": ["they", "are"], "isn't": ["is", "not"], "aren't": ["are", "not"],
    "don't": ["do", "not"], "doesn't": ["does", "not"], "didn't": ["did", "not"],
    "can't": ["can", "not"], "couldn't": ["could", "not"], "won't": ["will", "not"],
    "wouldn't": ["would", "not"], "let's": ["let", "us"], "what's": ["what", "is"],
    "who's": ["who", "is"], "where's": ["where", "is"], "that's": ["that", "is"],
    "there's": ["there", "is"], "i'll": ["i", "will"], "we'll": ["we", "will"],
    "i'd": ["i", "would"], "you've": ["you", "have"], "we've": ["we", "have"],
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


def main() -> None:
    db_path = next((path for path in DB_CANDIDATES if path.exists()), None)
    if db_path is None:
        raise SystemExit("未找到 ECDICT 数据库")
    connection = sqlite3.connect(db_path)
    lookup_cache: dict[str, bool] = {}

    def lookup_exact(word: str) -> bool:
        normalized = word.lower().replace("’", "'").strip()
        if normalized not in lookup_cache:
            lookup_cache[normalized] = connection.execute(
                "SELECT 1 FROM stardict WHERE word = ? COLLATE NOCASE LIMIT 1", (normalized,)
            ).fetchone() is not None
        return lookup_cache[normalized]

    def resolves(word: str) -> bool:
        normalized = word.lower().replace("’", "'")
        if normalized in KNOWN_VALID_TOKENS:
            return True
        if normalized in CONTRACTIONS:
            return all(any(lookup_exact(candidate) for candidate in lemma_candidates(part)) for part in CONTRACTIONS[normalized])
        if normalized.endswith("'s"):
            normalized = normalized[:-2]
        return any(lookup_exact(candidate) for candidate in lemma_candidates(normalized))

    def suggestions(word: str) -> list[str]:
        normalized = word.lower().replace("’", "'")
        if not normalized or not normalized[0].isalpha():
            return []
        rows = connection.execute(
            "SELECT word FROM stardict WHERE word LIKE ? AND length(word) BETWEEN ? AND ? LIMIT 800",
            (normalized[0] + "%", max(1, len(normalized) - 2), len(normalized) + 2),
        ).fetchall()
        ranked = sorted(
            ((SequenceMatcher(None, normalized, row[0].lower()).ratio(), row[0]) for row in rows),
            reverse=True,
        )
        return [candidate for score, candidate in ranked if score >= 0.64][:3]

    vocabulary = json.loads(RESOURCE.read_text(encoding="utf-8"))
    issues = []
    for word, tags in vocabulary.items():
        components = WORD_RE.findall(word)
        unresolved = [component for component in components if not resolves(component)]
        if lookup_exact(word) or (len(components) > 1 and not unresolved):
            continue
        for tag in tags:
            issues.append({
                "word": word,
                "grade": tag["grade"],
                "book": tag["book"],
                "unit": tag["unit"],
                "unknownComponents": unresolved,
                "suggestions": {token: suggestions(token) for token in unresolved or components},
            })
    connection.close()

    issues.sort(key=lambda item: (item["grade"], item["book"], item["unit"], item["word"].lower()))
    OUTPUT.write_text(json.dumps(issues, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    SUMMARY.write_text(
        "# PEP 2024 英文拼写粗筛\n\n"
        "本检查只使用 ECDICT 和基础词形规则校验英文拼写，不判断中文翻译，也不自动替换。\n\n"
        f"- 教材记录：{sum(len(tags) for tags in vocabulary.values())} 条\n"
        f"- 不同单词或短语：{len(vocabulary)} 个\n"
        f"- 需要人工确认的记录：{len(issues)} 条\n",
        encoding="utf-8",
    )
    print(json.dumps({"database": str(db_path), "review": len(issues), "output": str(OUTPUT)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
