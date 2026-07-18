#!/usr/bin/env python3
"""Convert the reviewed PEP 2024 workbook into the app textbook index.

The script uses only Python's standard library so the resource can be rebuilt
without a local Excel installation or Codex-specific spreadsheet runtime.
"""

from __future__ import annotations

import argparse
import json
import re
import zipfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "教材数据整理" / "2024版PEP人教版小学英语3-6年级单词表_合并版_补齐音标.xlsx"
DEFAULT_OUTPUT = ROOT / "Sources" / "DictationCoachApp" / "Resources" / "pep2024_vocab.json"
CATALOG_ID = "pep-primary-2024"

MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
NS = {"x": MAIN_NS, "r": REL_NS, "pr": PKG_REL_NS}

REQUIREMENT_MAP = {
    "会写": "write",
    "会认": "recognize",
    "认读": "recognize",
    "补充词汇": "unknown",
    "未标注": "unknown",
    "": "unknown",
}
EXPECTED_HEADERS = ["单词", "音标", "中文释义", "学习要求", "年级", "册", "单元"]
SPELLING_CORRECTIONS = {
    "Dragon Boat Festi": ("Dragon Boat Festival", "/ˈdræɡən boʊt ˈfestɪvəl/", "端午节"),
    "CC Founding D": ("CPC Founding Day", "/ˌsiː piː ˈsiː ˈfaʊndɪŋ deɪ/", "中国共产党建党日"),
    "gingerbread hous": ("gingerbread house", "/ˈdʒɪndʒərbred haʊs/", "姜饼屋"),
    "g Kong-Zhuhai-Mac": ("Hong Kong-Zhuhai-Macao Bridge", "/hɒŋ kɒŋ ˈdʒuːhaɪ məˈkaʊ brɪdʒ/", "港珠澳大桥"),
    "Terracotta Warri": ("Terracotta Warriors", "/ˌterəˈkɒtə ˈwɒriərz/", "兵马俑"),
    "gangshan Revolution": ("Jinggangshan Revolution", "/ˈdʒɪŋɡɑːŋʃɑːn ˌrevəˈluːʃən/", "井冈山革命"),
}
EXCLUDED_UNVERIFIED = {"Jeel", "Jew"}


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("’", "'").replace("‘", "'")).strip()


def normalize_ipa(value: str) -> str:
    value = normalize_text(value)
    if not value:
        return ""
    if value.startswith(("/", "[")) and value.endswith(("/", "]")):
        return value
    return f"/{value}/"


def column_index(reference: str) -> int:
    letters = "".join(character for character in reference if character.isalpha())
    index = 0
    for letter in letters.upper():
        index = index * 26 + ord(letter) - ord("A") + 1
    return index - 1


def shared_strings(archive: zipfile.ZipFile) -> list[str]:
    try:
        root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    except KeyError:
        return []
    return ["".join(node.text or "" for node in item.findall(".//x:t", NS)) for item in root.findall("x:si", NS)]


def sheet_path(archive: zipfile.ZipFile, sheet_name: str) -> str:
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    sheet = next((item for item in workbook.findall("x:sheets/x:sheet", NS) if item.get("name") == sheet_name), None)
    if sheet is None:
        raise ValueError(f"工作簿中没有工作表：{sheet_name}")

    relationship_id = sheet.get(f"{{{REL_NS}}}id")
    relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    relation = next((item for item in relationships.findall("pr:Relationship", NS) if item.get("Id") == relationship_id), None)
    if relation is None:
        raise ValueError(f"无法解析工作表路径：{sheet_name}")
    target = relation.get("Target", "").lstrip("/")
    return target if target.startswith("xl/") else f"xl/{target}"


def cell_value(cell: ET.Element, strings: list[str]) -> str:
    cell_type = cell.get("t")
    if cell_type == "inlineStr":
        return "".join(node.text or "" for node in cell.findall(".//x:t", NS))
    value = cell.findtext("x:v", default="", namespaces=NS)
    if cell_type == "s" and value:
        return strings[int(value)]
    return value


def read_rows(path: Path, sheet_name: str) -> list[list[str]]:
    with zipfile.ZipFile(path) as archive:
        strings = shared_strings(archive)
        root = ET.fromstring(archive.read(sheet_path(archive, sheet_name)))
        rows: list[list[str]] = []
        for row in root.findall(".//x:sheetData/x:row", NS):
            values: list[str] = []
            for cell in row.findall("x:c", NS):
                index = column_index(cell.get("r", "A1"))
                while len(values) <= index:
                    values.append("")
                values[index] = cell_value(cell, strings)
            rows.append(values)
        return rows


def build_index(rows: list[list[str]]) -> tuple[dict[str, list[dict[str, str]]], Counter[str]]:
    if not rows:
        raise ValueError("单词表为空")
    headers = [normalize_text(value) for value in rows[0]]
    missing = [header for header in EXPECTED_HEADERS if header not in headers]
    if missing:
        raise ValueError(f"缺少必要列：{', '.join(missing)}")
    positions = {header: headers.index(header) for header in EXPECTED_HEADERS}

    result: dict[str, list[dict[str, str]]] = {}
    requirement_counts: Counter[str] = Counter()
    seen_locations: set[tuple[str, str, str, str]] = set()

    for row_number, row in enumerate(rows[1:], start=2):
        def value(header: str) -> str:
            index = positions[header]
            return normalize_text(row[index] if index < len(row) else "")

        word = value("单词")
        if not word:
            continue
        if word in EXCLUDED_UNVERIFIED:
            continue
        grade, book, unit = value("年级"), value("册"), value("单元")
        meaning = value("中文释义")
        ipa = normalize_ipa(value("音标"))
        if word in SPELLING_CORRECTIONS:
            word, ipa, meaning = SPELLING_CORRECTIONS[word]
        if not all((grade, book, unit, meaning, ipa)):
            raise ValueError(f"第 {row_number} 行存在空白必要字段")

        original_requirement = value("学习要求")
        if original_requirement not in REQUIREMENT_MAP:
            raise ValueError(f"第 {row_number} 行存在未知学习要求：{original_requirement}")
        requirement = REQUIREMENT_MAP[original_requirement]
        location = (word.lower(), grade, book, unit)
        if location in seen_locations:
            raise ValueError(f"第 {row_number} 行存在重复教材位置：{word} {grade}{book} {unit}")
        seen_locations.add(location)

        result.setdefault(word, []).append({
            "catalogID": CATALOG_ID,
            "grade": grade,
            "book": book,
            "unit": unit,
            "meaning": meaning,
            "requirement": requirement,
            "ipa": ipa,
        })
        requirement_counts[requirement] += 1

    return dict(sorted(result.items(), key=lambda item: item[0].lower())), requirement_counts


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", nargs="?", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--sheet", default="单词表")
    args = parser.parse_args()

    index, requirements = build_index(read_rows(args.input, args.sheet))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    record_count = sum(len(tags) for tags in index.values())
    print(json.dumps({
        "records": record_count,
        "uniqueWords": len(index),
        "requirements": dict(sorted(requirements.items())),
        "skippedUnverified": len(EXCLUDED_UNVERIFIED),
        "output": str(args.output),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
