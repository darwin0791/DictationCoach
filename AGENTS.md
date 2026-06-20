# AGENTS.md

这份文件是给后续 coding agent 看的项目执行规约。后续任何产品或代码迭代，都要同步检查并更新本文件。

## 项目定位

- 产品中文名：正字。
- 英文标题：DictationCoach。
- 平台：个人使用的 macOS 原生桌面应用。
- 技术栈：Swift Package 可执行应用，使用 SwiftUI、AVFoundation、Vision、SQLite3 和本地资源。
- 当前范围：英语单词听写、语音播放、人工判断对错、错词复听、本地词典查询、OCR 导入。
- 不要被旧版 `AI英语错题教练_PRD.md` 带偏。旧 PRD 是移动端 AI 学习产品，包含拍错题、语法诊断、作文批改、账号、知识地图等；当前 MVP 不是那个方向，除非用户明确要求扩展。

## 构建和运行

用户推荐运行方式：

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

注意：

- `swift build` 和 `./scripts/build_app.sh` 可能需要无沙箱权限，因为 SwiftPM 会写用户级构建缓存。
- 应用应保持“关闭最后一个窗口后自动退出”的行为。
- 为避免用户已有数据丢失，暂不改 `AIEnglishDictationCoach` 数据目录。

## 目录说明

- `产品说明书.md`：面向用户的产品定位、页面功能、使用流程、数据隐私与常见问题说明。
- `Package.swift`：Swift Package 配置。
- `Sources/DictationCoachApp/ContentView.swift`：主要 UI、左侧导航和四个主页面。
- `Sources/DictationCoachApp/WordStore.swift`：单词状态、导入、判定、持久化。
- `Sources/DictationCoachApp/SpeechService.swift`：语音预设和播放逻辑。
- `Sources/DictationCoachApp/SQLiteDictionary.swift`：ECDICT SQLite 查询和词形回退。
- `Sources/DictationCoachApp/OCRService.swift`：Vision OCR 图片识别。
- `Sources/DictationCoachApp/PaperStyles.swift`：纸张风格、卡片、按钮、标签。
- `Sources/DictationCoachApp/FontRegistry.swift`：`ukai.ttc` 字体注册。
- `Sources/DictationCoachApp/Resources/stardict.db`：大型本地 ECDICT SQLite 词典。
- `Sources/DictationCoachApp/Resources/ukai.ttc`：应用文字字体。
- `Sources/DictationCoachApp/Resources/ipa_dictionary.json`：轻量兜底词卡词典。
- `Sources/DictationCoachApp/Resources/pep_vocab.json`：人教版 PEP 3-6 年级教材词表索引。
- `Sources/DictationCoachApp/Resources/pep_vocab_supplement.json`：教材词表增补，目前用于补齐源页面缺失的六年级下册。
- `scripts/generate_pep_vocab.rb`：从 21 世纪教育网页面生成教材词表索引。

## 数据和产物

用户练习数据保存在：

```text
~/Library/Application Support/AIEnglishDictationCoach/words.json
```

规则：

- `build/` 和 `.build/` 是生成产物，已忽略。
- `.build/` 可以删除释放空间，下次构建会重新生成。
- `build/DictationCoach.app` 里会复制一份 `stardict.db`，所以 app 体积较大。
- 不要把 `.secrets/`、`.tools/`、`.vite/`、`.DS_Store`、`.build/`、`build/` 纳入版本历史。

## 产品和 UX 规则

- 保持个人工具定位，简单、直接、低配置负担。
- 视觉保持克制拟物纸张风格：暖黄渐变纸张背景、轻纸卡、细边框、轻阴影、红笔批注感。
- 应用图标要和产品视觉一致，使用纸张、语音、红笔批注元素；打包时必须写入 `CFBundleIconFile`。
- 全局文字使用 `ukai.ttc`。
- SF Symbols 图标必须使用系统符号字体，不能套 `ukai.ttc`，否则图标会消失。
- 主导航使用左侧浅色竖向导航，不使用顶部系统 `TabView`。从上到下为产品 Logo、听写、单词本、错题集、设置。
- 左侧导航栏背景使用从上方白色到下方暖黄的纵向渐变。
- 左侧导航选中项使用柔和的暖金黄背景 `PaperTheme.sidebarSelection`，图标和文字保持深墨色。
- 主导航显示图标和文字，右侧用细分割线隔开内容区。
- 左侧导航宽度固定为 202pt，不允许被右侧页面内容挤压；新增页面或装饰素材时必须先保证默认窗口宽度下不压缩侧栏。
- 左侧产品 Logo 下方显示当前版本号，优先读取 `CFBundleShortVersionString`；版本号使用 macOS 系统默认字体，不使用 `ukai.ttc`。
- 左侧分割线要贯穿内容窗口上下边，不要留断开的上下边距。
- 背景纸张横线只出现在右侧内容区，不延伸到左侧菜单栏。
- 窗口标题 `DictationCoach` 使用居中标题栏显示。
- 四个主页面的页头使用统一固定高度和顶部基线，不得因下方内容差异产生上下跳动。
- 主导航不放退出按钮。
- 避免后台系统、管理面板、落地页式 UI。
- 卡片级模块标题统一使用 `SectionTitle`：左侧 SF Symbol 图标 20pt、蓝色 `PaperTheme.blueInk`；右侧标题文字 20pt bold、深墨色 `PaperTheme.ink`。不要再使用 `PaperCard(title:)` 的纯文字小标题作为主要模块标题。
- 页面 Header 说明保持短句风格：听写“按范围开始听写，记录每一次对错”；单词本“整理你的单词来源，随时查找和导入”；错题集“集中复听错词，直到真正掌握”；设置“管理你的听写偏好”。
- 不要重新引入长语音列表。设置页保持简单：美式女声、美式男声、英式女声、英式男声 + `正常/慢速`。
- 设置页采用左右两列：左侧语音设置，右侧关于；大标题说明文字为“管理你的听写偏好”。
- 设置页装饰素材：`hxz.png` 回形针放关于卡右上角，`qb.png` 铅笔放页面右下角；素材比例要克制，作为纸面装饰，不要抢正文。
- 听写页右侧「本轮记录」卡片右上角也使用同款 `hxz.png` 回形针装饰，尺寸和角度保持克制。
- 听写页右侧「本轮记录」在当前单词详情区显示教材来源标签，放在掌握状态标签旁边，格式如“三年级上册 Unit 2”；未匹配教材时不显示。
- 不要在单词行里重新放“手动音标 / 手动中文释义”等低价值控件，除非用户明确要求。
- 用户偏好图标按钮胜过文字按钮，但图标必须清晰、无多余边框。

## 当前交互模型

单词本：

- 主体为左右两列：左侧是占主要宽度的全部单词，右侧是手动新增、批量导入和 OCR 导入工具。
- 批量导入的文本输入区高度为 70pt，避免右侧三张工具卡撑高整个单词本布局。
- 批量导入的「导入单词」按钮放在卡片标题行右上角，不放在文本输入区下方。
- 批量导入的多行输入区高度保持为 100pt，避免右侧三个工具卡片撑高整个单词本页面。
- 支持单个手动新增。
- 支持文本批量导入。
- 支持 OCR 图片导入：选择图片，Vision 识别英文，预览后导入。
- 支持搜索：英文、中文释义、音标、词性释义、例句。
- 支持教材筛选：年级、册、单元。词条会显示教材来源小标签。
- 听写页也必须支持年级、册、单元筛选；开始听写时只从当前筛选范围抽词。
- 听写页模式选择放在年级筛选前面，使用和年级/册/单元一致的纸面下拉控件，不使用系统分段切换。
- 听写控制快捷键：左箭头=上一个，右箭头=下一个，空格=播放，Esc=停止。
- 听写页点击开始或播放时，当前单词连续播放 3 次，每次启动间隔 3 秒；切换单词、停止或发起新的播放时，必须取消未完成的重复播放。
- 听写过程中要持久化会话进度；误关窗口后，下次打开应恢复上次队列、当前索引、模式和筛选条件。
- 单词行支持播放、编辑、保存、删除。
- 手动新增单词要做规格检测：不像英文或本地词典查不到时，弹窗提示用户确认，确认后仍允许添加。
- 编辑单词：点击铅笔图标出现输入框和保存图标；点击空白处取消编辑。

听写：

- 听写页右下角使用与设置页相同的铅笔素材、比例和柔和投影，素材放在内容背景层，不遮挡操作。
- 进度区到听写纸张卡片的垂直间距固定为 30pt；纸张卡片到下方操作按钮区的垂直间距也固定为 30pt。
- 听写纸张卡片最大宽度为 820pt，高度按 `zzbj.png` 原始尺寸 `1513:602` 自动计算，在宽窗口中居中显示。使用 `GeometryReader` 将素材、中央文字和对错热区统一绑定到卡片实际尺寸；素材必须等比完整显示，不裁掉上下边缘，也不得溢出遮挡其他区域。
- 未开始时显示 `开始`。
- 未开始的开始按钮只使用大圆播放按钮，不显示 `开始` 文字；位置在听写卡片内部中上方，不放在卡片下方，且不得遮挡“暂无单词”。
- 听写卡片空状态只显示播放按钮和“点击播放，开始听写”，不显示“暂无单词”；练习卡背景使用 `zzbj.png`，需裁切进圆角卡片内，不要退回纯色黄底。
- 听写卡片中的真实单词字号为 56。
- 听写页外层「练习纸」容器需要有足够高度承托内容，避免卡片下方露出大块背景空白；调整留白时优先调整外层容器高度，不要压缩听写卡片素材。
- 听写页未开始状态下，顶部状态显示为“当前范围 X 个”和“未开始”左右排列；开始后改为“进度 当前/总数 + 橙色进度条”。
- 听写卡片的 `zzbj.png` 纸张素材需要带柔和阴影，强化纸张叠放感。
- 听写纸张素材与上方进度、下方控制按钮之间要留出呼吸感，不要紧贴。
- 开始后显示 `上一个 / 播放 / 下一个 / 停止`。
- 听写控制区的播放按钮使用独立大圆按钮；上一个、下一个、停止使用轻边框胶囊按钮。
- 对错不是普通按钮。鼠标划过卡片左侧显示 `对`，划过右侧显示 `错`，点击对应区域记录并进入下一个。
- 对错悬停反馈必须靠左右边缘，不得遮挡单词、音标和释义；只显示小浮标，不给整张纸加绿色/红色背景染色。

错题集：

- 答错过的词保留在错题集可见。
- `错题复听` 只抽取未标记为 `基本掌握` 的词。
- 错题集支持和单词本一致的搜索与教材筛选：可搜索英文、中文释义、音标、词性释义、例句；可按年级、册、单元筛选。

## 错题逻辑

点“错”：

- `wrongCount += 1`
- `isInWrongBook = true`
- `masteryStatus = 复习中`
- `consecutiveCorrectInWrongBook = 0`
- 更新 `lastWrongAt` 和 `lastPracticedAt`

点“对”：

- `correctCount += 1`
- 如果已经在错题集中，`consecutiveCorrectInWrongBook += 1`
- 连续答对 3 次后，`masteryStatus = 基本掌握`

当前还没有单独的“移出错题集”操作。

## 本地词典逻辑

- 优先查 `stardict.db`。
- 查不到再用 `ipa_dictionary.json` 兜底。
- 如果精确词条有中文释义但没有音标，尝试基础词形补音标：
  - `parents -> parent`
  - `ies -> y`
  - 简单 `ed`、`ing` 形式
- 借用基础词形音标时，要保留原词自己的中文释义。

## 教材分类逻辑

- 教材索引主数据来自 `http://zy.21cnjy.com/17820367` 的人教版 PEP 3-6 年级词汇表。
- 该源页面缺少六年级下册；六年级下册放在 `pep_vocab_supplement.json`，应用启动时会和主词表合并。
- 本地资源文件是 `pep_vocab.json`，结构为 `word -> [grade/book/unit/meaning]`。
- 单词本筛选器包括：年级、册、单元。
- 筛选清空操作在所有页面统一使用「重置」文字按钮，文字不得换行或被压缩成竖条；不使用单独图标。
- 年级、册、单元下拉筛选统一使用纸面下拉样式：外层圆角矩形包住控件，左侧是字段名，中间细分割线，右侧才是可点击下拉选项区，默认显示“全部”，展开后显示字典项。不要退回系统默认小灰色 Picker。
- 未匹配到教材索引的单词，在未筛选时正常显示；启用教材筛选后不显示。
- 对教材短语做反向组件匹配：如 `ice cream` 会让 `ice`、`cream` 也归到同一单元；`post office` 同理。
- 如果重新生成教材索引，运行：

```bash
ruby scripts/generate_pep_vocab.rb /tmp/pep_vocab.html Sources/DictationCoachApp/Resources/pep_vocab.json
```

## 验证要求

代码修改后运行：

```bash
swift build
```

用户可见的 app 修改后重新打包：

```bash
./scripts/build_app.sh
```

词典 JSON 修改后要先校验 JSON。

GUI 运行通常需要用户侧执行：

```bash
open build/DictationCoach.app
```

不要假设无头环境可以完整检查窗口效果。
