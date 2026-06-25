# 正字 / DictationCoach

一个个人使用的 macOS 原生 SwiftUI 应用：导入英语单词，播放系统英文语音，人工判断听写对错，并把错词沉淀到错题集中复听。

产品中文名：正字。英文标题：DictationCoach。

## 运行

推荐用已打包的 `.app` 运行：

```bash
open build/DictationCoach.app
```

重新打包：

```bash
./scripts/build_app.sh
open build/DictationCoach.app
```

开发调试：

```bash
swift run DictationCoach
```

首次启动后，练习数据保存在：

```text
~/Library/Application Support/AIEnglishDictationCoach/words.json
```

听写中的会话进度保存在：

```text
~/Library/Application Support/AIEnglishDictationCoach/practice_session.json
```

常用句的用户修改保存在：

```text
~/Library/Application Support/AIEnglishDictationCoach/sentences.json
```

说明：为避免旧数据丢失，数据目录仍沿用 `AIEnglishDictationCoach`。

## 当前功能

- 左侧导航：听写、单词本、常用句、错题集、设置。
- 教材基准词库：首次启动时同步 785 个已核对教材单词或短语；相同词保留学习统计，非教材历史错词仍保留在错题集。
- 常用句：内置 285 条已核验 PEP 2012 数据，包含常用句与表达 263 条、谚语 22 条；支持搜索、教材/类型筛选、播放、新增、批量导入、OCR、编辑和删除。
- 单词新增：支持单个手动新增。
- 新增检测：非英文形态或本地词典未查到的单词，会提示确认后再添加。
- 批量导入：支持换行、逗号、分号、空格、制表符分隔。
- OCR 导入：选择图片后用 macOS Vision 识别英文单词，预览后导入。
- 单词本和错题集搜索：支持按英文、中文释义、音标、词性释义和例句搜索。
- 教材筛选：基于人教版 PEP 3-6 年级词汇表，单词本、错题集和听写页均支持按年级、册、单元筛选。
- 下拉筛选：年级、册、单元统一使用纸面下拉样式；外层圆角矩形包住控件，左侧是字段名，右侧是下拉选项区，默认显示“全部”。
- 听写模式：放在年级筛选前面，使用和年级相同的纸面下拉样式，不使用分段切换。
- 本地词典：接入 ECDICT `stardict.db`，离线查询中文释义和音标。
- 词形回退：复数等词条缺音标时，会尝试用基础词形补音标。
- 语音播放：基于 macOS `AVSpeechSynthesizer`。
- 语音设置：保留美式女声、美式男声、英式女声、英式男声；语速为正常/慢速。
- 设置页：左右两列布局，左侧为语音设置，右侧为关于信息；关于卡右上使用回形针素材，页面右下使用铅笔素材，保持低存在感纸张装饰。
- 页面说明文案：听写为“按范围开始听写，记录每一次对错”；单词本为“整理你的单词来源，随时查找和导入”；错题集为“集中复听错词，直到真正掌握”；设置为“管理你的听写偏好”。
- 听写交互：开始后显示上一个、圆形播放按钮、下一个、停止。
- 听写卡片：空状态提示为“点击播放，开始听写”，背景使用 `zzbj.png` 纸张素材。
- 听写快捷键：左箭头上一个，右箭头下一个，空格播放，Esc 停止。
- 听写筛选：可按教材年级、册、单元限定听写范围。
- 听写续练：听写过程中误关窗口后，下次打开会恢复上次听写队列和当前进度。
- 对错判定：鼠标划过单词卡左侧显示“对”，右侧显示“错”，点击后记录并进入下一个。
- 错题集：答错自动加入错题集，连续答对 3 次后标记为“基本掌握”。
- 单词本管理：支持编辑单词、删除单词、单词行播放发音。
- 导航结构：左侧浅色竖向导航，顶部为产品 Logo，下方依次为听写、单词本、常用句、错题集、设置，图标和文字并列展示，右侧用细分割线隔开内容区。
- 版本显示：左侧产品 Logo 下方展示当前版本号。
- 视觉风格：暖黄渐变纸张背景、轻纸卡、克制拟物风格。
- 应用图标：使用纸张、语音、红笔批注元素，不使用 macOS 默认占位图标。
- 字体：全局使用 `ukai.ttc`；主导航使用本地 SVG 图标，功能按钮可使用系统 SF Symbols。

## 错题规则

- 点“错”：加入错题集，错误次数 +1，状态变为“复习中”。
- 点“对”：正确次数 +1。
- 错题连续答对 3 次：状态变为“基本掌握”。
- “错题复听”只抽取未基本掌握的错题。
- 当前没有单独“移出错题集”按钮；删除单词会同时删除该词的记录。

## 本地词典

应用资源里包含：

```text
Sources/DictationCoachApp/Resources/stardict.db
```

它来自开源项目 ECDICT：

```text
https://github.com/skywind3000/ECDICT
```

用途：输入英文单词时，应用优先从 `stardict.db` 查询音标和中文释义；查不到时再使用轻量 JSON 词卡兜底。

轻量兜底词典位于：

```text
Sources/DictationCoachApp/Resources/ipa_dictionary.json
```

教材词表索引位于：

```text
Sources/DictationCoachApp/Resources/pep_vocab.json
Sources/DictationCoachApp/Resources/pep_vocab_supplement.json
```

历史初始来源：

```text
http://zy.21cnjy.com/17820367
```

当前教材基准是用户已核对确认的人教 PEP 2012 版 3-6 年级教材数据，共 816 条教材记录、785 个不同单词或短语。上述网页只是初始数据的历史来源，不再作为产品数据真值来源。

当前六年级下册 92 条记录仍以 `pep_vocab_supplement.json` 存放，应用启动时与主词表合并。听写页只展示教材释义；单词本和错题集展示 ECDICT 通用释义。产品不允许手动修改音标或中文释义。ECDICT 仍用于补充音标、通用释义和词形，不用于判定 3-6 年级教材归属。

练习纸支持英文听写和中文默写。中文默写只朗读教材中文释义；“显示英文提示”关闭时隐藏卡片上的英文单词和音标，打开时显示完整答案。语音不会朗读释义中的英文词形说明。

常用句基准资源位于：

```text
Sources/DictationCoachApp/Resources/pep2012_sentences_verified.json
```

## 体积说明

`stardict.db` 约 812MB。为了离线查词，打包后的 `build/DictationCoach.app` 里也会包含一份词典副本，所以应用体积较大。

`.build/` 是 SwiftPM 构建缓存，可以删除释放空间；下次构建会重新生成。
