#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

path = ARGV[0] || "教材数据整理/pep2012_sentences_verified.json"
entries = JSON.parse(File.read(path))

# Remove OCR-only appendix headers.
entries.reject! do |entry|
  entry["english"].include?("Appendix 5") && entry["chinese"] == "谚语"
end

# Restore expressions split across columns or mixed with page headers.
if (entry = entries.find { |item| item["sourcePDFPage"] == 11 && item["english"].include?("Appendix 3") })
  entry["english"] = "Time to go home, kids."
  entry["chinese"] = "该回家了，孩子们。"
end

if (entry = entries.find { |item| item["sourcePDFPage"] == 8 && item["english"].include?("Appendix 4") })
  entry["english"] = "No, there isn't."
  entry["chinese"] = "不，森林里没有河。"
end

first_half = entries.find { |item| item["sourcePDFPage"] == 6 && item["english"].start_with?("Yesterday") }
second_half = entries.find { |item| item["sourcePDFPage"] == 6 && item["english"].start_with?("these are") }
if first_half && second_half
  first_half["english"] = "Yesterday, today and tomorrow—these are the three days of man."
  first_half["chinese"] = "人生有三天：昨天、今天和明天。"
  entries.delete(second_half)
end

proverbs = [
  "Less is more.",
  "All work and no play makes Jack a dull boy.",
  "All's well that ends well.",
  "Life is what you make it.",
  "Better to ask the way than go astray.",
  "Horses for courses.",
  "Think today and speak tomorrow.",
  "A friend in need is a friend indeed.",
  "Like father, like son.",
  "No pleasure without pain.",
  "The early bird catches the worm.",
  "Every season brings its joy.",
  "Life has seasons.",
  "Yesterday, today and tomorrow—these are the three days of man.",
  "Let sleeping dogs lie.",
  "It's the empty can that makes the most noise.",
  "You can't judge a book by its cover.",
  "For the hard-working, a week has seven days; for the lazy, seven tomorrows.",
  "An apple a day keeps the doctor away.",
  "Practice makes perfect.",
  "East or west, home is best.",
  "Seeing is believing."
]

entries.each do |entry|
  entry["kind"] = proverbs.include?(entry["english"]) ? "proverb" : "expression"
  # Pages 2, 4 and 6 place the proverbs in Appendix 5 rather than a unit.
  if entry["kind"] == "proverb" && [2, 4, 6].include?(entry["sourcePDFPage"])
    entry["unit"] = "附录"
  end
end

# Corrections confirmed by the user against the source PDF.
ocr_spelling_corrections = {
  "T'd" => "I'd",
  "T'm" => "I'm",
  "Theyre" => "They're",
  "Im" => "I'm",
  "isnit" => "isn't",
  "canit" => "can't",
  "mulel" => "mule"
}

entries.each do |entry|
  ocr_spelling_corrections.each do |incorrect, correct|
    entry["english"] = entry["english"].gsub(/\b#{Regexp.escape(incorrect)}\b/, correct)
  end
end

confirmed_sentence_corrections = {
  "No, it isn't. It's Mikes." => "No, it isn't. It's Mike.",
  "No. it isnt. / Yes, it is." => "No. it isn't. / Yes, it is."
}

entries.each do |entry|
  entry["english"] = confirmed_sentence_corrections.fetch(entry["english"], entry["english"])
end

if (entry = entries.find { |item| item["english"] == "All's well that ends well." })
  entry["chinese"] = "结果好，一切都好。"
end

if (entry = entries.find { |item| item["english"] == "Seeing is believing." })
  entry["chinese"] = "眼见为实。"
end

missing = proverbs.reject { |proverb| entries.any? { |entry| entry["english"] == proverb } }
abort("missing proverbs: #{missing.join(" | ")}") unless missing.empty?

File.write(path, JSON.pretty_generate(entries))
puts "total=#{entries.length}"
puts "expressions=#{entries.count { |entry| entry["kind"] == "expression" }}"
puts "proverbs=#{entries.count { |entry| entry["kind"] == "proverb" }}"
