#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

path = ARGV[0] || "Sources/DictationCoachApp/Resources/pep_vocab.json"
data = JSON.parse(File.read(path))

def find_tag!(data, word, grade, book, unit)
  tag = data.fetch(word).find do |item|
    item["grade"] == grade && item["book"] == book && item["unit"] == unit
  end
  abort("missing tag: #{word} #{grade}#{book} #{unit}") unless tag
  tag
end

def correct_meaning!(data, word, grade, book, unit, meaning)
  find_tag!(data, word, grade, book, unit)["meaning"] = meaning
end

def rename_entry!(data, old_word, new_word, grade, book, unit, meaning)
  old_tags = data[old_word] || []
  index = old_tags.index do |item|
    item["grade"] == grade && item["book"] == book && item["unit"] == unit
  end
  unless index
    existing = (data[new_word] || []).find do |item|
      item["grade"] == grade && item["book"] == book && item["unit"] == unit
    end
    if existing
      existing["meaning"] = meaning
      return
    end
    abort("missing rename source: #{old_word} #{grade}#{book} #{unit}")
  end

  tag = old_tags.delete_at(index)
  data.delete(old_word) if old_tags.empty?
  tag["meaning"] = meaning
  data[new_word] ||= []
  data[new_word] << tag unless data[new_word].any? do |item|
    item["grade"] == grade && item["book"] == book && item["unit"] == unit
  end
end

# Entries split incorrectly by the original webpage parser.
renames = [
  ["baby", "baby brother", "四年级", "上册", "Unit 6", "婴儿小弟弟"],
  ["english", "english book", "四年级", "上册", "Unit 2", "英语书"],
  ["football", "football player", "四年级", "上册", "Unit 6", "足球运动员"],
  ["good", "good job", "五年级", "下册", "Unit 2", "做得好"],
  ["have", "have ... class", "五年级", "下册", "Unit 1", "上……课"],
  ["having", "having ... class", "五年级", "下册", "Unit 6", "（正在）上……课"],
  ["help", "help yourself", "四年级", "上册", "Unit 5", "为（自己）取用"],
  ["keep to the", "keep to the right", "五年级", "下册", "Unit 6", "靠右"],
  ["listening to", "listening to music", "五年级", "下册", "Unit 6", "（正在）听音乐"],
  ["lots", "lots of", "五年级", "上册", "Unit 5", "大量；许多"],
  ["maths", "maths book", "四年级", "上册", "Unit 2", "数学书"],
  ["play the", "play the pipa", "五年级", "上册", "Unit 4", "弹琵琶"],
  ["reading a", "reading a book", "五年级", "下册", "Unit 6", "（正在）看书"],
  ["sing english", "sing english songs", "五年级", "上册", "Unit 4", "唱英文歌曲"],
  ["sports", "sports meet", "五年级", "下册", "Unit 3", "运动会"],
  ["teacher's", "teacher's desk", "四年级", "上册", "Unit 1", "讲台"],
  ["doing morning", "doing morning exercises", "五年级", "下册", "Unit 6", "（正在）做早操"],
  ["eating", "eating lunch", "五年级", "下册", "Unit 6", "（正在）吃午饭"]
]

renames.each { |args| rename_entry!(data, *args) }

# Meanings checked against the supplied PEP 2012 textbook appendix scans.
corrections = [
  ["art room", "四年级", "下册", "Unit 1", "美术教室"],
  ["above", "五年级", "上册", "Unit 5", "在（或向）……上面"],
  ["behind", "五年级", "上册", "Unit 5", "在（或向）……后面"],
  ["best", "五年级", "下册", "Unit 2", "最；最高程度地"],
  ["between", "五年级", "上册", "Unit 5", "在……中间"],
  ["clock", "五年级", "上册", "Unit 5", "时钟；钟"],
  ["do", "五年级", "上册", "Unit 2", "做；干"],
  ["do morning exercises", "五年级", "下册", "Unit 1", "做早操"],
  ["every", "五年级", "上册", "Unit 2", "每一个；每个"],
  ["expensive", "四年级", "下册", "Unit 6", "昂贵的；花钱多的"],
  ["favourite", "五年级", "上册", "Unit 3", "特别喜爱的"],
  ["few", "五年级", "下册", "Unit 3", "不多；很少"],
  ["finish", "五年级", "上册", "Unit 1", "完成；做好"],
  ["funny", "五年级", "上册", "Unit 1", "滑稽的；可笑的"],
  ["fur", "五年级", "下册", "Unit 4", "（某些动物的）浓密的软毛"],
  ["helpful", "五年级", "上册", "Unit 1", "有用的；愿意帮忙的"],
  ["ice cream", "五年级", "上册", "Unit 3", "冰激凌"],
  ["kind", "五年级", "上册", "Unit 1", "体贴的；慈祥的；宽容的"],
  ["love", "四年级", "下册", "Unit 3", "（写信结尾的热情问候语）爱你的"],
  ["mountain", "五年级", "上册", "Unit 6", "高山；山岳"],
  ["noise", "五年级", "下册", "Unit 4", "声音；响声；噪音"],
  ["old", "五年级", "上册", "Unit 1", "老的；年纪大的"],
  ["quickly", "六年级", "上册", "Unit 5", "迅速地"],
  ["rabbit", "五年级", "上册", "Unit 6", "兔；野兔"],
  ["really", "四年级", "上册", "Unit 1", "（表示兴趣或惊讶）真的"],
  ["river", "五年级", "上册", "Unit 6", "河；江"],
  ["send", "五年级", "上册", "Unit 4", "邮寄；发送"],
  ["show", "五年级", "下册", "Unit 6", "展览"],
  ["shy", "五年级", "上册", "Unit 1", "羞怯的；腼腆的；怕生的"],
  ["sing", "五年级", "上册", "Unit 4", "唱；唱歌"],
  ["singapore", "四年级", "下册", "Unit 3", "新加坡（市）"],
  ["special", "五年级", "下册", "Unit 4", "特殊的；特别的"],
  ["sunday", "五年级", "上册", "Unit 2", "星期日"],
  ["tea", "五年级", "上册", "Unit 3", "茶；茶水"],
  ["their", "五年级", "上册", "Unit 5", "他们的；她们的；它们的"],
  ["travel", "六年级", "上册", "Unit 3", "（尤指长途）旅行"],
  ["village", "五年级", "上册", "Unit 6", "村庄；村镇"],
  ["wear", "六年级", "上册", "Unit 2", "穿"],
  ["wonderful", "五年级", "上册", "Unit 4", "极好的；了不起的"]
]

corrections.each { |word, grade, book, unit, meaning| correct_meaning!(data, word, grade, book, unit, meaning) }

# The source page merged Friday into Thursday; the scan has two entries.
correct_meaning!(data, "thursday", "五年级", "上册", "Unit 2", "星期四")
data["friday"] ||= []
data["friday"] << {
  "grade" => "五年级",
  "book" => "上册",
  "unit" => "Unit 2",
  "meaning" => "星期五"
} unless data["friday"].any? do |item|
  item["grade"] == "五年级" && item["book"] == "上册" && item["unit"] == "Unit 2"
end

File.write(path, JSON.pretty_generate(data.sort.to_h))
puts "corrected=#{corrections.length}"
puts "renamed=#{renames.length}"
puts "words=#{data.length}"
