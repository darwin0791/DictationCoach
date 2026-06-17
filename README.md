# AI 英语听写错题教练

一个个人使用的 macOS 原生 SwiftUI 应用：导入英语单词，播放系统英文语音，人工判断听写对错，并把错词沉淀到错题集中复听。

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

## 当前功能

- 分标签页：听写、单词本、错题集、设置。
- 单词新增：支持单个手动新增。
- 批量导入：支持换行、逗号、分号、空格、制表符分隔。
- OCR 导入：选择图片后用 macOS Vision 识别英文单词，预览后导入。
- 单词搜索：支持按英文、中文释义、音标、词性释义和例句搜索。
- 本地词典：接入 ECDICT `stardict.db`，离线查询中文释义和音标。
- 词形回退：复数等词条缺音标时，会尝试用基础词形补音标。
- 语音播放：基于 macOS `AVSpeechSynthesizer`。
- 语音设置：保留美式女声、美式男声、英式男声；语速为正常/慢速。
- 听写交互：开始后显示上一个、播放、下一个、停止。
- 对错判定：鼠标划过单词卡左侧显示“对”，右侧显示“错”，点击后记录并进入下一个。
- 错题集：答错自动加入错题集，连续答对 3 次后标记为“基本掌握”。
- 单词本管理：支持编辑单词、删除单词、单词行播放发音。
- 视觉风格：暖白纸张背景、轻纸卡、克制拟物风格。
- 字体：全局使用 `ukai.ttc`，图标使用系统 SF Symbols。

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

## 体积说明

`stardict.db` 约 812MB。为了离线查词，打包后的 `build/DictationCoach.app` 里也会包含一份词典副本，所以应用体积较大。

`.build/` 是 SwiftPM 构建缓存，可以删除释放空间；下次构建会重新生成。
