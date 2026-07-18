import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CommonSentencesView: View {
    @EnvironmentObject private var store: SentenceStore
    @State private var searchText = ""
    @State private var selectedGrade = "全部年级"
    @State private var selectedBook = "全部册"
    @State private var selectedUnit = "全部单元"
    @State private var selectedKind = "全部类型"
    @State private var selectedCatalogID: String?

    private var activeCatalogID: String {
        selectedCatalogID ?? TextbookCatalog.pepPrimary2012ID
    }

    private var catalogSentences: [SentenceEntry] {
        store.sentences(inCatalog: activeCatalogID)
    }

    private var filteredSentences: [SentenceEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return catalogSentences.filter { sentence in
            let matchesSearch = query.isEmpty || [
                sentence.english,
                sentence.chinese,
                sentence.grade,
                sentence.book,
                sentence.unit,
                sentence.kind.displayName
            ].contains { $0.lowercased().contains(query) }

            return matchesSearch
                && (selectedGrade == "全部年级" || sentence.grade == selectedGrade)
                && (selectedBook == "全部册" || sentence.book == selectedBook)
                && (selectedUnit == "全部单元" || sentence.unit == selectedUnit)
                && (selectedKind == "全部类型" || sentence.kind.displayName == selectedKind)
        }
    }

    private var hasActiveFilter: Bool {
        selectedGrade != "全部年级"
            || selectedBook != "全部册"
            || selectedUnit != "全部单元"
            || selectedKind != "全部类型"
    }

    var body: some View {
        if let selectedCatalogID,
           let catalog = TextbookCatalog.catalog(withID: selectedCatalogID) {
            sentenceContent(catalog: catalog)
        } else {
            TextbookCatalogSelectionView(
                module: .sentences,
                countForCatalog: { store.sentences(inCatalog: $0).count },
                onSelect: { selectedCatalogID = $0.id }
            )
        }
    }

    private func sentenceContent(catalog: TextbookCatalog) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(title: "常用句", subtitle: "整理教材表达，随时查找和跟读")
            CatalogContextBar(catalog: catalog) {
                selectedCatalogID = nil
                resetFilters()
            }

            HStack(alignment: .top, spacing: 18) {
                sentenceListCard

                VStack(spacing: 18) {
                    PaperCard(title: nil, tint: PaperTheme.sheet) {
                        SectionTitle(icon: "plus.circle.fill", title: "手动新增")

                        TextField("输入英文句子", text: $store.singleEnglish)
                            .textFieldStyle(.roundedBorder)
                            .font(AppFont.font(size: 15))

                        TextField("输入中文释义", text: $store.singleChinese)
                            .textFieldStyle(.roundedBorder)
                            .font(AppFont.font(size: 15))
                            .onSubmit { store.addSingleSentence(catalogID: activeCatalogID) }

                        HStack {
                            Text("按回车也可以新增。")
                                .font(AppFont.font(size: 13))
                                .foregroundStyle(PaperTheme.mutedInk)
                            Spacer()
                            Button {
                                store.addSingleSentence(catalogID: activeCatalogID)
                            } label: {
                                Label("新增", systemImage: "plus.circle")
                            }
                            .buttonStyle(StampButtonStyle(color: PaperTheme.greenInk))
                        }
                    }

                    PaperCard(title: nil, tint: PaperTheme.sheet) {
                        HStack(spacing: 12) {
                            SectionTitle(icon: "square.and.arrow.down", title: "批量导入")
                            Spacer(minLength: 0)
                            Button {
                                store.importSentences(catalogID: activeCatalogID)
                            } label: {
                                Label("导入句子", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
                        }

                        TextEditor(text: $store.importText)
                            .font(AppFont.font(size: 15))
                            .scrollContentBackground(.hidden)
                            .background(PaperTheme.note.opacity(0.45))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(PaperTheme.line.opacity(0.5), lineWidth: 1)
                            )
                            .frame(height: 70)

                        Text("每行一条：英文 | 中文")
                            .font(AppFont.font(size: 12))
                            .foregroundStyle(PaperTheme.mutedInk)
                    }

                    SentenceOCRImportView(catalogID: activeCatalogID)

                    Text(store.dataMessage)
                        .font(AppFont.font(size: 13))
                        .foregroundStyle(PaperTheme.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 330)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var sentenceListCard: some View {
        PaperCard(title: nil, tint: PaperTheme.sheet) {
            SectionTitle(icon: "text.quote", title: "全部常用句（\(catalogSentences.count)）")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PaperTheme.mutedInk)
                TextField("搜索英文、中文或教材分类", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(AppFont.font(size: 15))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.mutedInk))
                    .help("清空搜索")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(PaperTheme.note.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(PaperTheme.line.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))

            HStack(spacing: 8) {
                PaperDropdown(title: "年级", selection: $selectedGrade, values: ["全部年级"] + store.grades(catalogID: activeCatalogID), width: 112)
                PaperDropdown(title: "册", selection: $selectedBook, values: ["全部册"] + store.books(catalogID: activeCatalogID), width: 100)
                PaperDropdown(title: "单元", selection: $selectedUnit, values: ["全部单元"] + store.units(catalogID: activeCatalogID), width: 118)
                PaperDropdown(title: "类型", selection: $selectedKind, values: ["全部类型"] + SentenceKind.allCases.map(\.displayName), width: 150)

                if hasActiveFilter {
                    Button {
                        resetFilters()
                    } label: {
                        Text("重置")
                            .font(AppFont.font(size: 13, weight: .semibold))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(StampButtonStyle(color: PaperTheme.mutedInk))
                    .help("重置筛选")
                }
            }

            HStack {
                Text(searchText.isEmpty && !hasActiveFilter ? "共 \(catalogSentences.count) 条" : "找到 \(filteredSentences.count) 条")
                Spacer()
                Text("常用句与表达 \(catalogSentences.filter { $0.kind == .expression }.count)  ·  谚语 \(catalogSentences.filter { $0.kind == .proverb }.count)")
            }
            .font(AppFont.font(size: 13))
            .foregroundStyle(PaperTheme.mutedInk)

            if filteredSentences.isEmpty {
                EmptyState(text: "没有找到匹配的句子。")
            } else {
                List {
                    ForEach(filteredSentences) { sentence in
                        SentenceRow(sentence: sentence)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func resetFilters() {
        searchText = ""
        selectedGrade = "全部年级"
        selectedBook = "全部册"
        selectedUnit = "全部单元"
        selectedKind = "全部类型"
    }
}

private struct SentenceRow: View {
    @EnvironmentObject private var store: SentenceStore
    @EnvironmentObject private var speech: SpeechService
    let sentence: SentenceEntry
    @State private var isEditing = false
    @State private var draftEnglish = ""
    @State private var draftChinese = ""
    @FocusState private var focusedField: EditField?

    private enum EditField { case english, chinese }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                HStack(spacing: 8) {
                    VStack(spacing: 7) {
                        TextField("英文句子", text: $draftEnglish)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .english)
                        TextField("中文释义", text: $draftChinese)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .chinese)
                    }
                    Button {
                        store.updateSentence(sentence, english: draftEnglish, chinese: draftChinese)
                        isEditing = false
                        focusedField = nil
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.greenInk))
                    .help("保存")
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sentence.english)
                            .font(AppFont.font(size: 18, weight: .semibold))
                            .foregroundStyle(PaperTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if !sentence.chinese.isEmpty {
                            Text(sentence.chinese)
                                .font(AppFont.font(size: 15, weight: .medium))
                                .foregroundStyle(PaperTheme.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 7) {
                            Text(sentence.textbookLabel)
                                .foregroundStyle(PaperTheme.blueInk)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PaperTheme.note.opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            StatusTag(
                                text: sentence.kind.displayName,
                                color: sentence.kind == .proverb ? PaperTheme.redPencil : PaperTheme.greenInk
                            )
                        }
                        .font(AppFont.font(size: 12, weight: .semibold))
                    }

                    Spacer(minLength: 12)

                    Button { speech.speak(sentence.english) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.blueInk))
                    .help("播放")

                    Button {
                        draftEnglish = sentence.english
                        draftChinese = sentence.chinese
                        isEditing = true
                        focusedField = .english
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.blueInk))
                    .help("编辑")

                    Button { store.deleteSentence(sentence) } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.redPencil))
                    .help("删除")
                }
            }
        }
        .padding(.vertical, 8)
        .onChange(of: focusedField) { newValue in
            if isEditing, newValue == nil {
                isEditing = false
            }
        }
    }
}

private struct SentenceOCRImportView: View {
    @EnvironmentObject private var store: SentenceStore
    @State private var recognizedLines: [String] = []
    @State private var isRecognizing = false
    @State private var message = "支持 PNG、JPG、截图。"
    let catalogID: String

    var body: some View {
        PaperCard(title: nil, tint: PaperTheme.sheet) {
            SectionTitle(icon: "text.viewfinder", title: "图片识别导入")

            HStack(spacing: 10) {
                Button { chooseImage() } label: {
                    Label(isRecognizing ? "识别中" : "选择图片 OCR", systemImage: "text.viewfinder")
                }
                .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
                .disabled(isRecognizing)

                Button {
                    store.importRecognizedLines(recognizedLines, catalogID: catalogID)
                    recognizedLines = []
                    message = "已提交导入。"
                } label: {
                    Label("导入识别句子", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(StampButtonStyle(color: PaperTheme.greenInk))
                .disabled(recognizedLines.isEmpty || isRecognizing)
            }

            Text(message)
                .font(AppFont.font(size: 12))
                .foregroundStyle(PaperTheme.mutedInk)

            if !recognizedLines.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(recognizedLines, id: \.self) { line in
                            Text(line)
                                .font(AppFont.font(size: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isRecognizing = true
        message = "正在识别图片文字..."
        recognizedLines = []
        Task {
            do {
                let lines = try await OCRService.recognizeLines(from: url)
                await MainActor.run {
                    recognizedLines = lines
                    message = lines.isEmpty ? "没有识别到英文句子。" : "识别到 \(lines.count) 行，请确认后导入。"
                    isRecognizing = false
                }
            } catch {
                await MainActor.run {
                    message = "OCR 失败：\(error.localizedDescription)"
                    isRecognizing = false
                }
            }
        }
    }
}
