# 教材选择页 Design QA

## 对照范围

- source visual truth path: `/Users/orange/.codex/generated_images/019eea55-8ceb-7f51-b96d-6a98e06fc909/exec-8d1a1f89-aa15-4e45-8695-23419b80411d.png`
- source delta: 按用户最终要求移除“上次使用”批注；卡片主体保持纯白，页签和边框使用中性灰，不使用蓝色卡片。
- implementation screenshot path: `/Users/orange/Downloads/AI 英语错题教练/design-qa-implementation-assets.png`
- viewport: 1397 × 768，macOS 原生窗口，浅色模式。
- base visual state: 听写模块的教材选择页；PEP 2012 可进入，另外两套教材在数据接入前显示“准备中”。
- latest functional state: PEP 2024 单词接入后，听写、单词本和错题集中的第二张卡片已启用；常用句中的第二张卡片仍为“准备中”，7–9 年级保持“准备中”。

## 对照证据

- full-view comparison evidence: `/Users/orange/Downloads/AI 英语错题教练/design-qa-comparison-full.png`
- focused region comparison evidence: `/Users/orange/Downloads/AI 英语错题教练/design-qa-comparison-cards.png`
- 重点区域单独比较了三张卡片、文件夹页签、书架、主操作与准备中状态；因此无需再追加更小的局部裁切。

## 检查结果

- 字体与层级：实现使用项目既有 `ukai.ttc` 和 HeaderBlock 层级；教材名、版本、数量、状态和操作按钮均清晰，无截断或异常换行。
- 间距与布局：三张卡片固定为单行等宽布局并落在同一书架上；默认窗口内无横向溢出，侧栏保持固定宽度。
- 颜色与视觉 token：三张卡片主体均为纯白；页签、边框、准备中状态使用中性灰；当前模块可用教材的主操作按钮使用蓝色。
- 图像与素材：文件夹与书架均已替换为项目内透明 PNG 素材；同时沿用纸张背景、Logo 和铅笔素材。素材缩放、裁切、透明边缘和高分辨率插值正常。
- 文案与状态：没有“上次使用”批注；三个教材名、PEP 2012、PEP 2024 和各模块数量口径均正确。PEP 2024 运行词库为 836 个不同单词或短语。
- 交互：已验证进入 PEP 2012、点击“更换教材”返回、再次点击当前左侧模块重置到教材选择页；接入后又验证错题集中的 PEP 2024 卡片可进入并显示 114 个当前本机错词，7–9 年级准备中卡片不响应进入操作。
- 原生应用不使用浏览器控制台；Swift release 构建通过，未发现编译错误。

## 比较历史

1. 第一轮发现 P2：SwiftUI 禁用态降低整张卡片透明度，使准备中卡片透出暖黄背景，不符合纯白填充要求。
   - 修复：准备中卡片改为非交互静态卡，只弱化文字和状态按钮，不再对整张卡片应用禁用透明度。
   - 修复后证据：`design-qa-implementation-v2.png`，三张卡片主体均恢复纯白。
2. 第二轮发现 P2：准备中卡片中部状态缺失，文件夹页签与参考图的中性层次不足。
   - 修复：补回卡片中部“准备中”，加入中性灰页签，同时保留底部禁用状态按钮。
   - 修复后证据：`design-qa-implementation-final.png`。
3. 用户进一步要求不要用代码近似还原立体文件夹和书架。
   - 修复：分别生成 `textbook-folder-card.png` 与 `textbook-shelf.png` 两个透明素材，移除原 `FolderCardShape`、`FolderTabShape` 和矩形书架绘制，SwiftUI 只负责尺寸、文字和交互叠加。
   - 修复后证据：`design-qa-implementation-assets.png` 及两张最终对照图。
4. PEP 2024 单词数据接入后，第二张卡片按模块开放。
   - 听写、单词本和错题集：显示 `PEP 2024`、对应数量和蓝色主操作按钮。
   - 常用句：因为没有新版句子数据，继续显示“准备中”。
   - 通过本机原生窗口可访问性树和截图复核：错题集第二张卡片为可点击按钮，当前本机显示 114 个错词。

## 最终结论

当前没有待处理的 P0、P1 或 P2 差异。参考图中的旧版本号和“上次使用”批注未复刻，属于产品版本更新和用户明确要求的有意差异。

final result: passed
