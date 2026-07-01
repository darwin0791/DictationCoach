#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "json"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
MAIN_VOCAB = File.join(ROOT, "Sources/DictationCoachApp/Resources/pep_vocab.json")
SUPPLEMENT_VOCAB = File.join(ROOT, "Sources/DictationCoachApp/Resources/pep_vocab_supplement.json")
OUTPUT = File.join(ROOT, "教材数据整理/词汇学习要求标注表.csv")
README = File.join(ROOT, "教材数据整理/词汇学习要求标注说明.md")

GRADE_ORDER = {
  "三年级" => 3,
  "四年级" => 4,
  "五年级" => 5,
  "六年级" => 6
}.freeze

BOOK_ORDER = {
  "上册" => 1,
  "下册" => 2
}.freeze

REQUIREMENT_LABELS = {
  "write" => "会写",
  "recognize" => "认读",
  "unknown" => ""
}.freeze

def load_vocab(path)
  return {} unless File.exist?(path)

  JSON.parse(File.read(path, encoding: "UTF-8"))
end

def unit_number(unit)
  unit.to_s[/\d+/].to_i
end

def sort_key(row)
  [
    GRADE_ORDER.fetch(row[:grade], 99),
    BOOK_ORDER.fetch(row[:book], 99),
    unit_number(row[:unit]),
    row[:word]
  ]
end

combined = {}
[load_vocab(MAIN_VOCAB), load_vocab(SUPPLEMENT_VOCAB)].each do |vocab|
  vocab.each do |word, entries|
    combined[word] ||= []
    combined[word].concat(entries)
  end
end

rows = combined.flat_map do |word, entries|
  entries.map do |entry|
    {
      grade: entry["grade"].to_s,
      book: entry["book"].to_s,
      unit: entry["unit"].to_s,
      word: word.to_s,
      meaning: entry["meaning"].to_s,
      requirement: REQUIREMENT_LABELS.fetch(entry["requirement"].to_s, ""),
      note: ""
    }
  end
end

rows.sort_by! { |row| sort_key(row) }

FileUtils.mkdir_p(File.dirname(OUTPUT))

CSV.open(OUTPUT, "w:UTF-8") do |csv|
  csv << ["\uFEFF年级", "册", "单元", "单词或短语", "教材释义", "要求", "备注"]
  rows.each do |row|
    csv << [
      row[:grade],
      row[:book],
      row[:unit],
      row[:word],
      row[:meaning],
      row[:requirement],
      row[:note]
    ]
  end
end

File.write(
  README,
  <<~MARKDOWN,
    # 词汇学习要求标注说明

    标注文件：`词汇学习要求标注表.csv`

    这份表用于给教材词汇补充“会写 / 认读”标识。请只填写或修改 CSV 中的「要求」列，其他列尽量不要改动，方便后续导回产品词库。

    ## 要求列填写方式

    - `会写`：课本要求听说读写，需要默写/拼写。
    - `认读`：课本只要求听说读，不要求默写/拼写。
    - 留空：暂时不确定，后续导入时会按“未标注”处理。

    ## 注意

    - 如果同一个单词出现在不同年级、册或单元，请分别按对应课本要求标注。
    - 教材里如果通过加粗体和标准体区分要求，建议人工核对后填写；不要依赖 OCR 自动判断粗体。
    - 填完后，把 `词汇学习要求标注表.csv` 发回即可，我会再导入产品词库。
  MARKDOWN
  encoding: "UTF-8"
)

unique_words = rows.map { |row| row[:word] }.uniq.size
puts "导出完成：#{OUTPUT}"
puts "记录数：#{rows.size}"
puts "不同单词或短语：#{unique_words}"
puts "说明文件：#{README}"
