#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "json"

html_path = ARGV[0] || "/tmp/pep_vocab.html"
out_path = ARGV[1] || "Sources/DictationCoachApp/Resources/pep_vocab.json"

html = File.read(html_path)
match = html.match(%r{<p class="assets-intro">(.*?)</p>}m)
abort("assets-intro not found") unless match

text = match[1]
  .gsub(%r{<br\s*/?>}i, "\n")
  .gsub(/<[^>]+>/, "")
text = CGI.unescapeHTML(text)

grade = nil
book = nil
unit = nil
entries = []

grade_book_patterns = [
  [/三年级上册/, ["三年级", "上册"]],
  [/三年级下册/, ["三年级", "下册"]],
  [/四年级上册/, ["四年级", "上册"]],
  [/四年级.*下册/, ["四年级", "下册"]],
  [/五年级上册/, ["五年级", "上册"]],
  [/五年级下册/, ["五年级", "下册"]],
  [/六年级上册/, ["六年级", "上册"]],
  [/六年级下册/, ["六年级", "下册"]]
]

unit_cn = {
  "一" => "Unit 1",
  "二" => "Unit 2",
  "三" => "Unit 3",
  "四" => "Unit 4",
  "五" => "Unit 5",
  "六" => "Unit 6"
}

def normalize_word(value)
  value.downcase
    .gsub(/[’‘]/, "'")
    .gsub(/\s+/, " ")
    .strip
end

def parse_vocab_line(line)
  original = line.strip
  return nil if original.empty?

  line = original
    .sub(/^\d+[.．、]\s*/, "")
    .sub(/^\d+/, "")
    .strip
    .gsub(/[（(][^)）]*\)/, "")
    .strip

  if (m = line.match(/\A([A-Za-z][A-Za-z .'\-]*[A-Za-z])\s+(.+)\z/))
    word = normalize_word(m[1])
    meaning = m[2].strip
  elsif (m = line.match(/\A([A-Za-z][A-Za-z .'\-]*?)([\p{Han}（(].*)\z/))
    word = normalize_word(m[1])
    meaning = m[2].strip
  else
    return nil
  end

  return nil if word.empty? || meaning.empty?
  return nil if word.length > 48

  {
    "word" => word,
    "meaning" => meaning
  }
end

text.lines.each do |raw_line|
  line = raw_line.strip
  next if line.empty?

  if (pair = grade_book_patterns.find { |pattern, _| line.match?(pattern) })
    grade, book = pair[1]
    unit = nil
    next
  end

  if (m = line.match(/\A第([一二三四五六])单元词汇表\z/))
    unit = unit_cn[m[1]]
    next
  end

  if (m = line.match(/\AUnit\s*([1-6])\z/i))
    unit = "Unit #{m[1]}"
    next
  end

  next unless grade && book && unit

  parsed = parse_vocab_line(line)
  next unless parsed

  entries << parsed.merge(
    "grade" => grade,
    "book" => book,
    "unit" => unit
  )
end

grouped = {}
entries.each do |entry|
  grouped[entry["word"]] ||= []
  next if grouped[entry["word"]].any? { |item| item["grade"] == entry["grade"] && item["book"] == entry["book"] && item["unit"] == entry["unit"] }

  grouped[entry["word"]] << {
    "grade" => entry["grade"],
    "book" => entry["book"],
    "unit" => entry["unit"],
    "meaning" => entry["meaning"]
  }
end

File.write(out_path, JSON.pretty_generate(grouped.sort.to_h))
puts "entries=#{entries.length}"
puts "unique_words=#{grouped.length}"
puts "written=#{out_path}"
