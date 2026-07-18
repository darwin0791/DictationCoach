#!/usr/bin/env python3
"""
Build a compact ECDICT SQLite database for DictationCoach.

The full ECDICT database is used as a development-time source only. This script
extracts the words DictationCoach needs at runtime:

- all PEP 2012 and PEP 2024 textbook vocabulary words and phrase components
- words appearing in verified textbook sentences/proverbs
- ECDICT entries tagged as zk/gk/cet4
- high-frequency ECDICT words by frq/bnc rank

The output keeps the table name `stardict` so the app can reuse the existing
SQLite lookup code with minimal changes.
"""

from __future__ import annotations

import argparse
import json
import re
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "Sources" / "DictationCoachApp" / "Resources"
DEFAULT_SOURCE_CANDIDATES = [
    RESOURCE_DIR / "stardict.db",
    ROOT / "教材数据整理" / "raw" / "stardict_full.db",
    ROOT / "教材数据整理" / "stardict_full.db",
]
DEFAULT_OUTPUT = RESOURCE_DIR / "mini_stardict.db"
DEFAULT_REPORT = ROOT / "教材数据整理" / "mini_stardict_build_report.json"
VOCAB_PATHS = [
    RESOURCE_DIR / "pep_vocab.json",
    RESOURCE_DIR / "pep_vocab_supplement.json",
    RESOURCE_DIR / "pep2024_vocab.json",
]
SENTENCE_PATH = RESOURCE_DIR / "pep2012_sentences_verified.json"

WORD_TOKEN_RE = re.compile(r"[A-Za-z]+(?:'[A-Za-z]+)?")
SIMPLE_ENTRY_RE = re.compile(r"^[A-Za-z][A-Za-z' -]{0,63}$")
CONTRACTION_BASES = {
    "i'm": ["i", "am"],
    "you're": ["you", "are"],
    "he's": ["he", "is"],
    "she's": ["she", "is"],
    "it's": ["it", "is"],
    "we're": ["we", "are"],
    "they're": ["they", "are"],
    "isn't": ["is", "not"],
    "aren't": ["are", "not"],
    "can't": ["can", "not"],
    "don't": ["do", "not"],
    "doesn't": ["does", "not"],
    "didn't": ["did", "not"],
    "won't": ["will", "not"],
    "wouldn't": ["would", "not"],
    "couldn't": ["could", "not"],
    "shouldn't": ["should", "not"],
    "i'd": ["i", "would"],
    "i'll": ["i", "will"],
    "let's": ["let", "us"],
}


def normalize_entry(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip())


def token_key(value: str) -> str:
    return value.strip().lower()


def phrase_components(value: str) -> set[str]:
    return {
        match.group(0).lower()
        for match in WORD_TOKEN_RE.finditer(value)
        if len(match.group(0)) > 1 or match.group(0).lower() in {"a", "i"}
    }


def add_term(target: set[str], value: str) -> None:
    value = normalize_entry(value)
    if not value:
        return
    lowered = value.lower()
    target.add(lowered)
    for part in phrase_components(value):
        target.add(part)
        for expanded in CONTRACTION_BASES.get(part, []):
            target.add(expanded)


def load_required_terms() -> dict[str, set[str] | dict[str, str]]:
    vocab_terms: set[str] = set()
    sentence_terms: set[str] = set()
    textbook_meanings: dict[str, str] = {}

    for path in VOCAB_PATHS:
        data = json.loads(path.read_text(encoding="utf-8"))
        for word, records in data.items():
            add_term(vocab_terms, word)
            meaning = "；".join(
                sorted(
                    {
                        normalize_entry(record.get("meaning", ""))
                        for record in records
                        if normalize_entry(record.get("meaning", ""))
                    }
                )
            )
            if meaning:
                textbook_meanings[token_key(word)] = meaning

    sentences = json.loads(SENTENCE_PATH.read_text(encoding="utf-8"))
    for item in sentences:
        english = item.get("english", "")
        for match in WORD_TOKEN_RE.finditer(english):
            token = match.group(0).lower()
            add_term(sentence_terms, token)

    return {
        "vocab": vocab_terms,
        "sentences": sentence_terms,
        "all": vocab_terms | sentence_terms,
        "textbookMeanings": textbook_meanings,
    }


def is_runtime_candidate(row: sqlite3.Row) -> bool:
    word = normalize_entry(row["word"] or "")
    translation = (row["translation"] or "").strip()
    if not word or not translation:
        return False
    if len(word) > 64 or not SIMPLE_ENTRY_RE.match(word):
        return False
    if word.startswith(("'", "-")) or word.endswith(("-", "'")):
        return False
    if any(ch.isdigit() for ch in word):
        return False
    return True


def table_schema() -> str:
    return """
    CREATE TABLE stardict (
        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE,
        word VARCHAR(64) COLLATE NOCASE NOT NULL UNIQUE,
        sw VARCHAR(64) COLLATE NOCASE NOT NULL,
        phonetic VARCHAR(64),
        translation TEXT,
        pos VARCHAR(16),
        tag VARCHAR(64),
        bnc INTEGER DEFAULT(NULL),
        frq INTEGER DEFAULT(NULL),
        exchange TEXT
    );
    """


def create_output_db(path: Path) -> sqlite3.Connection:
    if path.exists():
        path.unlink()
    db = sqlite3.connect(path)
    db.executescript(
        table_schema()
        + """
        CREATE UNIQUE INDEX stardict_1 ON stardict (id);
        CREATE UNIQUE INDEX stardict_2 ON stardict (word);
        CREATE INDEX stardict_3 ON stardict (sw, word COLLATE NOCASE);
        CREATE INDEX sd_1 ON stardict (word COLLATE NOCASE);
        """
    )
    return db


def resolve_source(path_arg: str | None) -> Path:
    if path_arg:
        path = Path(path_arg)
        return path if path.is_absolute() else ROOT / path
    for candidate in DEFAULT_SOURCE_CANDIDATES:
        if candidate.exists():
            return candidate
    raise FileNotFoundError(
        "Cannot find full stardict.db. Expected one of: "
        + ", ".join(str(path) for path in DEFAULT_SOURCE_CANDIDATES)
    )


def fetch_exact(source: sqlite3.Connection, terms: set[str]) -> tuple[dict[str, sqlite3.Row], set[str]]:
    rows: dict[str, sqlite3.Row] = {}
    missing: set[str] = set()
    query = """
        SELECT word, sw, phonetic, translation, pos, tag, bnc, frq, exchange
        FROM stardict
        WHERE word = ? COLLATE NOCASE
        LIMIT 1
    """
    for term in sorted(terms):
        row = source.execute(query, (term,)).fetchone()
        if row and is_runtime_candidate(row):
            rows[token_key(row["word"])] = row
        else:
            missing.add(term)
    return rows, missing


def fetch_rule_candidates(source: sqlite3.Connection, frq_limit: int, bnc_limit: int) -> dict[str, sqlite3.Row]:
    query = """
        SELECT word, sw, phonetic, translation, pos, tag, bnc, frq, exchange
        FROM stardict
        WHERE translation IS NOT NULL
          AND translation <> ''
          AND (
            tag LIKE '%zk%'
            OR tag LIKE '%gk%'
            OR tag LIKE '%cet4%'
            OR (frq IS NOT NULL AND frq > 0 AND frq <= ?)
            OR (bnc IS NOT NULL AND bnc > 0 AND bnc <= ?)
          )
    """
    rows: dict[str, sqlite3.Row] = {}
    for row in source.execute(query, (frq_limit, bnc_limit)):
        if is_runtime_candidate(row):
            rows.setdefault(token_key(row["word"]), row)
    return rows


def common_inflections(term: str) -> set[str]:
    if " " in term or "-" in term or "'" in term:
        return set()
    forms = {term + "s", term + "es", term + "ed", term + "ing"}
    if term.endswith("y") and len(term) > 2:
        forms.add(term[:-1] + "ies")
        forms.add(term[:-1] + "ied")
    if term.endswith("e") and len(term) > 2:
        forms.add(term[:-1] + "ing")
        forms.add(term + "d")
    if len(term) > 2 and term[-1] not in "aeiouwxy":
        forms.add(term + term[-1] + "ed")
        forms.add(term + term[-1] + "ing")
    return forms


def synthetic_textbook_rows(
    missing_terms: set[str], textbook_meanings: dict[str, str]
) -> dict[str, dict[str, str | int | None]]:
    rows: dict[str, dict[str, str | int | None]] = {}
    for term in sorted(missing_terms):
        meaning = textbook_meanings.get(term)
        if not meaning:
            continue
        rows[term] = {
            "word": term,
            "sw": term,
            "phonetic": None,
            "translation": meaning,
            "pos": None,
            "tag": "pep2012",
            "bnc": None,
            "frq": None,
            "exchange": None,
        }
    return rows


def insert_rows(output: sqlite3.Connection, rows: dict[str, sqlite3.Row]) -> None:
    insert = """
        INSERT OR IGNORE INTO stardict
        (word, sw, phonetic, translation, pos, tag, bnc, frq, exchange)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """
    output.executemany(
        insert,
        [
            (
                row["word"],
                row["sw"] or row["word"].lower(),
                row["phonetic"],
                row["translation"],
                row["pos"],
                row["tag"],
                row["bnc"],
                row["frq"],
                row["exchange"],
            )
            for row in rows.values()
        ],
    )
    output.commit()


def db_size_mb(path: Path) -> float:
    return round(path.stat().st_size / 1024 / 1024, 2)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build compact ECDICT SQLite database.")
    parser.add_argument("--source", help="Path to the full stardict.db source")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="Output mini db path")
    parser.add_argument("--report", default=str(DEFAULT_REPORT), help="Build report JSON path")
    parser.add_argument("--frq-limit", type=int, default=10000, help="Keep ECDICT words with frq rank <= limit")
    parser.add_argument("--bnc-limit", type=int, default=10000, help="Keep ECDICT words with bnc rank <= limit")
    args = parser.parse_args()

    source_path = resolve_source(args.source)
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    report_path = Path(args.report)
    if not report_path.is_absolute():
        report_path = ROOT / report_path

    required = load_required_terms()

    source = sqlite3.connect(source_path)
    source.row_factory = sqlite3.Row

    exact_rows, missing_required = fetch_exact(source, required["all"])
    synthetic_rows = synthetic_textbook_rows(
        missing_required, required["textbookMeanings"]  # type: ignore[arg-type]
    )
    missing_after_synthetic = missing_required - set(synthetic_rows.keys())
    inflections = set()
    for term in exact_rows.keys():
        inflections.update(common_inflections(term))
    inflection_rows, _ = fetch_exact(source, inflections)
    rule_rows = fetch_rule_candidates(source, args.frq_limit, args.bnc_limit)

    all_rows = {}
    all_rows.update(rule_rows)
    all_rows.update(inflection_rows)
    all_rows.update(exact_rows)
    all_rows.update(synthetic_rows)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output = create_output_db(output_path)
    insert_rows(output, all_rows)

    output.execute("VACUUM")
    output.close()

    mini = sqlite3.connect(output_path)
    total = mini.execute("SELECT COUNT(*) FROM stardict").fetchone()[0]
    tagged = mini.execute(
        "SELECT COUNT(*) FROM stardict WHERE tag LIKE '%zk%' OR tag LIKE '%gk%' OR tag LIKE '%cet4%'"
    ).fetchone()[0]
    mini.close()

    report = {
        "source": str(source_path),
        "output": str(output_path),
        "sizeMB": db_size_mb(output_path),
        "totalEntries": total,
        "taggedZkGkCet4Entries": tagged,
        "frqLimit": args.frq_limit,
        "bncLimit": args.bnc_limit,
        "requiredTerms": {
            "vocab": len(required["vocab"]),
            "sentences": len(required["sentences"]),
            "all": len(required["all"]),
        },
        "syntheticTextbookEntries": sorted(synthetic_rows.keys()),
        "syntheticTextbookEntryCount": len(synthetic_rows),
        "missingRequiredTerms": sorted(missing_after_synthetic),
        "missingRequiredCount": len(missing_after_synthetic),
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(
        f"mini_stardict entries={total} size={report['sizeMB']}MB "
        f"missing_required={len(missing_after_synthetic)} report={report_path}"
    )


if __name__ == "__main__":
    main()
