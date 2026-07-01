# 正字 / DictationCoach

正字是一款个人使用的 macOS 原生英语听写工具。它面向家长和孩子的日常练习场景：按教材范围听写单词、中文默写英文、复听错词，并把练习记录保存在本机。

当前版本：`0.2.0`

## 产品定位

正字不是通用背单词平台，也不是 AI 批改系统。它的目标很窄：帮助孩子把教材里的英语单词真正记住。

当前重点：

- 以人教 PEP 2012 版 3-6 年级教材词汇为基准。
- 支持英文听写和中文默写两种练习方式。
- 家长或孩子在纸上作答，应用只负责播放、记录对错和沉淀错词。
- 所有学习数据保存在本机，不需要账号和云端同步。

## 功能概览

- 听写
  - 支持“英文听写 / 中文默写”切换。
  - 支持按要求、年级、册、单元筛选。
  - 当前词连续播放 3 次。
  - 支持快捷键：左箭头上一个、右箭头下一个、空格播放、Esc 停止。
  - 听写过程中误关窗口后，下次打开可恢复队列和进度。

- 中文默写
  - 只播报教材中文释义，让孩子写英文。
  - 默认隐藏英文单词和音标，避免提前看到答案。
  - 可打开“显示英文提示”查看答案。
  - 中文语音会剔除释义里的英文词形说明，避免泄露答案。

- 单词本
  - 支持手动新增、批量导入和 OCR 图片导入。
  - 支持搜索英文、中文释义、音标、词性释义。
  - 显示教材来源标签。
  - 支持按教材范围和学习要求筛选。

- 常用句
  - 内置 285 条已核验教材表达。
  - 其中常用句与表达 263 条，谚语 22 条。
  - 支持搜索、筛选、播放、新增、批量导入、OCR、编辑和删除。

- 错题集
  - 答错自动进入错题集。
  - 错题连续答对 3 次后标记为“基本掌握”。
  - “错题复听”只抽取未基本掌握的错词。

- 设置
  - 英文发音人：美式女声、美式男声、英式女声、英式男声。
  - 中文发音人：高级女声 Yue、标准女声 Tingting。
  - 支持正常/慢速语速。

## 教材和词典数据

教材词汇基准：

- 人教 PEP 2012 版 3-6 年级。
- 816 条教材记录。
- 785 个不同单词或短语。
- 已导入学习要求标识：
  - 会写：463 条。
  - 认读：353 条。
  - 未标注：0 条。

教材句子基准：

- `Sources/DictationCoachApp/Resources/pep2012_sentences_verified.json`
- 共 285 条。
- 常用句与表达 263 条，谚语 22 条。

本地词典：

- 运行时使用精简 ECDICT SQLite 词典：
  - `Sources/DictationCoachApp/Resources/mini_stardict.db`
  - 当前约 3.09MB，13,832 条词条。
- 完整 ECDICT 不随 app 打包。
- 如需重新抽取精简词典，将完整原料库放在已忽略路径：
  - `教材数据整理/raw/stardict_full.db`
- 然后运行：

```bash
python3 scripts/build_mini_stardict.py
```

精简词典抽取范围：

- PEP 2012 教材词和短语。
- 教材句子与谚语中的英文词。
- ECDICT 中带 `zk/gk/cet4` 标签的基础词。
- ECDICT `frq` 或 `bnc` 排名前 10000 的高频词。
- 常见复数、`-ed`、`-ing` 等变形。
- ECDICT 未收录的教材短语，会用教材释义生成 `pep2012` 兜底词条。

ECDICT 项目来源：[skywind3000/ECDICT](https://github.com/skywind3000/ECDICT)

## 本地数据

用户练习数据保存在：

```text
~/Library/Application Support/AIEnglishDictationCoach/words.json
```

听写会话进度保存在：

```text
~/Library/Application Support/AIEnglishDictationCoach/practice_session.json
```

常用句用户数据保存在：

```text
~/Library/Application Support/AIEnglishDictationCoach/sentences.json
```

说明：为避免旧数据丢失，当前仍沿用 `AIEnglishDictationCoach` 数据目录。

## 构建和运行

环境要求：

- macOS 13 或更高版本。
- Xcode Command Line Tools / Swift Package Manager。

开发运行：

```bash
swift run DictationCoach
```

打包 app：

```bash
./scripts/build_app.sh
open build/DictationCoach.app
```

也可以直接打开已打包版本：

```bash
open build/DictationCoach.app
```

注意：`swift build` 和 `./scripts/build_app.sh` 可能需要访问 SwiftPM 用户级构建缓存。

## 常用维护脚本

重新生成教材词表后，必须应用 PEP 2012 PDF 修正：

```bash
ruby scripts/apply_pep2012_pdf_corrections.rb Sources/DictationCoachApp/Resources/pep_vocab.json
```

导出词汇学习要求人工标注表：

```bash
ruby scripts/export_vocab_requirement_template.rb
```

导入人工标注后的学习要求：

```bash
ruby scripts/import_vocab_requirements.rb
```

清理并核验教材句子参考数据：

```bash
ruby scripts/clean_pep2012_sentences.rb
```

用 ECDICT 粗筛英文拼写：

```bash
python3 scripts/audit_pep2012_against_ecdict.py
```

重新生成精简运行词典：

```bash
python3 scripts/build_mini_stardict.py
```

## 项目结构

```text
Sources/DictationCoachApp/
  ContentView.swift              主界面和听写/单词本/错题集页面
  SentenceViews.swift            常用句页面
  WordStore.swift                单词状态、导入、判定和持久化
  SentenceStore.swift            常用句加载、导入和持久化
  SQLiteDictionary.swift         精简 ECDICT 查询和词形回退
  SpeechService.swift            英文/中文语音播放
  OCRService.swift               Vision OCR 图片识别
  Resources/                     本地词典、教材数据、字体和图片资源

scripts/
  build_app.sh                   打包 macOS app
  build_mini_stardict.py         生成精简 ECDICT 运行词典
  audit_pep2012_against_ecdict.py 英文拼写粗筛
  apply_pep2012_pdf_corrections.rb 教材词表修正

教材数据整理/
  README.md                      教材数据整理过程和校验记录
  pep2012_sentences_verified.json 已核验句子参考数据
  词汇学习要求标注表.csv          人工标注表
```
