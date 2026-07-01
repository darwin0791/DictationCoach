#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "json"

ROOT = File.expand_path("..", __dir__)
CSV_PATH = File.join(ROOT, "教材数据整理/词汇学习要求标注表.csv")
VOCAB_PATHS = [
  File.join(ROOT, "Sources/DictationCoachApp/Resources/pep_vocab.json"),
  File.join(ROOT, "Sources/DictationCoachApp/Resources/pep_vocab_supplement.json")
].freeze

REQUIREMENT_MAP = {
  "会写" => "write",
  "听说读写" => "write",
  "write" => "write",
  "认读" => "recognize",
  "听说读" => "recognize",
  "recognize" => "recognize",
  "" => "unknown"
}.freeze

def normalize(value)
  value.to_s
       .sub(/\A\uFEFF/, "")
       .tr("’‘", "''")
       .strip
       .downcase
end

def key_for(grade:, book:, unit:, word:)
  [grade.to_s.strip, book.to_s.strip, unit.to_s.strip, normalize(word)].join("\t")
end

unless File.exist?(CSV_PATH)
  abort "找不到标注表：#{CSV_PATH}"
end

requirements = {}
invalid = []

CSV.foreach(CSV_PATH, headers: true, encoding: "bom|utf-8") do |row|
  grade = row["年级"] || row[0]
  book = row["册"] || row[1]
  unit = row["单元"] || row[2]
  word = row["单词或短语"] || row[3]
  raw_requirement = (row["要求"] || row[5]).to_s.strip
  requirement = REQUIREMENT_MAP[raw_requirement]

  if requirement.nil?
    invalid << "#{grade} #{book} #{unit} #{word}: #{raw_requirement}"
    next
  end

  requirements[key_for(grade: grade, book: book, unit: unit, word: word)] = requirement
end

abort "发现无法识别的要求值：\n#{invalid.join("\n")}" unless invalid.empty?

updated = 0
missing = []

VOCAB_PATHS.each do |path|
  vocab = JSON.parse(File.read(path, encoding: "UTF-8"))

  vocab.each do |word, entries|
    entries.each do |entry|
      key = key_for(
        grade: entry["grade"],
        book: entry["book"],
        unit: entry["unit"],
        word: word
      )

      requirement = requirements[key]
      if requirement
        entry["requirement"] = requirement
        updated += 1
      else
        entry["requirement"] = "unknown"
        missing << "#{entry["grade"]} #{entry["book"]} #{entry["unit"]} #{word}"
      end
    end
  end

  File.write(path, JSON.pretty_generate(vocab) + "\n", encoding: "UTF-8")
end

summary = requirements.values.each_with_object(Hash.new(0)) { |value, counts| counts[value] += 1 }
puts "导入完成"
puts "更新教材记录：#{updated}"
puts "标注表统计：会写 #{summary["write"] || 0}，认读 #{summary["recognize"] || 0}，未标注 #{summary["unknown"] || 0}"
puts "词库中未在标注表命中的记录：#{missing.size}"
missing.first(20).each { |item| puts "  - #{item}" }
