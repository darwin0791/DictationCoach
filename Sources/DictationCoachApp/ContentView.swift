import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        ZStack {
            AppBackground()
            TabView {
                PracticeView()
                    .tabItem { Label("听写", systemImage: "speaker.wave.2") }

                WordBookView()
                    .tabItem { Label("单词本", systemImage: "book.closed") }

                WrongBookView()
                    .tabItem { Label("错题集", systemImage: "pencil.and.outline") }

                SettingsView()
                    .tabItem { Label("设置", systemImage: "slider.horizontal.3") }
            }
            .padding(18)
        }
    }
}

struct PracticeView: View {
    @EnvironmentObject private var store: WordStore
    @EnvironmentObject private var speech: SpeechService

    @State private var mode: PracticeMode = .all
    @State private var queue: [WordEntry] = []
    @State private var currentIndex = 0
    @State private var hoveredDecision: Bool?
    @State private var sessionMessage = "先导入一些单词，然后开始听写。"

    private var currentWord: WordEntry? {
        guard queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    private var isSessionActive: Bool {
        !queue.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(title: "听写", subtitle: "播放发音，让对方听写；你负责判定对错。")

            HStack(alignment: .top, spacing: 18) {
                PaperCard(title: "练习纸", tint: PaperTheme.sheet) {
                    VStack(alignment: .center, spacing: 18) {
                        Picker("模式", selection: $mode) {
                            ForEach(PracticeMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)

                        Text(progressText)
                            .font(AppFont.font(size: 15, weight: .medium))
                            .foregroundStyle(PaperTheme.mutedInk)

                        practiceCard
                        .frame(height: 210)

                        HStack(spacing: 12) {
                            if isSessionActive {
                                Button {
                                    previousWord()
                                } label: {
                                    Label("上一个", systemImage: "backward.fill")
                                }
                                .buttonStyle(StampButtonStyle(color: PaperTheme.mutedInk))
                                .disabled(currentIndex == 0)

                                Button {
                                    if let currentWord { speech.speak(currentWord.word) }
                                } label: {
                                    Label("播放", systemImage: "speaker.wave.2.fill")
                                }
                                .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))

                                Button {
                                    nextWord()
                                } label: {
                                    Label("下一个", systemImage: "forward.fill")
                                }
                                .buttonStyle(StampButtonStyle(color: PaperTheme.mutedInk))
                                .disabled(currentIndex + 1 >= queue.count)

                                Button {
                                    stopSession()
                                } label: {
                                    Label("停止", systemImage: "stop.fill")
                                }
                                .buttonStyle(StampButtonStyle(color: PaperTheme.redPencil))
                            } else {
                                Button {
                                    startSession()
                                } label: {
                                    Label("开始", systemImage: "play.fill")
                                }
                                .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                PaperCard(title: "本轮记录", tint: PaperTheme.sheet) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(sessionMessage)
                            .font(AppFont.font(size: 15))
                            .foregroundStyle(PaperTheme.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        StatLine(label: "全部单词", value: "\(store.words.count)")
                        StatLine(label: "错题集", value: "\(store.wrongWords.count)")
                        StatLine(label: "待复听", value: "\(store.activeWrongWords.count)")

                        if let currentWord {
                            Divider()
                            StatusTag(text: currentWord.masteryStatus.rawValue, color: currentWord.isInWrongBook ? PaperTheme.redPencil : PaperTheme.blueInk)
                            StatLine(label: "释义", value: currentWord.displayMeaning)
                            StatLine(label: "答对", value: "\(currentWord.correctCount)")
                            StatLine(label: "答错", value: "\(currentWord.wrongCount)")
                        }
                    }
                    .frame(width: 250, alignment: .leading)
                }
            }
        }
        .padding(18)
    }

    private var practiceCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(PaperTheme.note.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(PaperTheme.line.opacity(0.55), lineWidth: 1)
                )

            if let hoveredDecision, currentWord != nil {
                HStack(spacing: 0) {
                    if hoveredDecision == true {
                        decisionBadge(title: "对", systemImage: "checkmark.circle.fill", color: PaperTheme.greenInk)
                            .padding(.leading, 18)
                        Spacer(minLength: 0)
                    } else {
                        Spacer(minLength: 0)
                        decisionBadge(title: "错", systemImage: "xmark.circle.fill", color: PaperTheme.redPencil)
                            .padding(.trailing, 18)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: hoveredDecision == true
                            ? [PaperTheme.greenInk.opacity(0.14), .clear, .clear]
                            : [.clear, .clear, PaperTheme.redPencil.opacity(0.14)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .transition(.opacity)
            }

            VStack(spacing: 10) {
                Text(currentWord?.word ?? "暂无单词")
                    .font(AppFont.font(size: 46, weight: .bold))
                    .foregroundStyle(currentWord == nil ? PaperTheme.mutedInk : PaperTheme.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(currentWord?.displayIPA ?? "先开始一轮听写")
                    .font(AppFont.font(size: 21, weight: .medium))
                    .foregroundStyle(currentWord == nil ? PaperTheme.mutedInk.opacity(0.65) : PaperTheme.blueInk)

                if let currentWord {
                    Text(currentWord.displayMeaning)
                        .font(AppFont.font(size: 24, weight: .semibold))
                        .foregroundStyle(PaperTheme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .padding(.top, 4)
                }
            }
            .padding()

            if currentWord != nil {
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onHover { inside in
                            withAnimation(.easeOut(duration: 0.16)) {
                                hoveredDecision = inside ? true : nil
                            }
                        }
                        .onTapGesture {
                            markCurrent(correct: true)
                        }

                    Color.clear
                        .contentShape(Rectangle())
                        .onHover { inside in
                            withAnimation(.easeOut(duration: 0.16)) {
                                hoveredDecision = inside ? false : nil
                            }
                        }
                        .onTapGesture {
                            markCurrent(correct: false)
                        }
                }
            }
        }
    }

    private func decisionBadge(title: String, systemImage: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
            Text(title)
                .font(AppFont.font(size: 20, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PaperTheme.sheet.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
    }

    private var progressText: String {
        guard !queue.isEmpty else { return "未开始" }
        return "第 \(min(currentIndex + 1, queue.count)) / \(queue.count) 个"
    }

    private func startSession() {
        let source = mode == .all ? store.allWordsSorted : store.activeWrongWords
        queue = source.shuffled()
        currentIndex = 0
        hoveredDecision = nil

        if let first = queue.first {
            sessionMessage = "本轮 \(queue.count) 个单词。"
            speech.speak(first.word)
        } else {
            sessionMessage = mode == .all ? "单词本还是空的，先去导入单词。" : "目前没有待复听错词。"
        }
    }

    private func previousWord() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        hoveredDecision = nil
        if let currentWord {
            speech.speak(currentWord.word)
        }
    }

    private func nextWord() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        hoveredDecision = nil
        if let currentWord {
            speech.speak(currentWord.word)
        }
    }

    private func stopSession() {
        speech.stop()
        queue = []
        currentIndex = 0
        hoveredDecision = nil
        sessionMessage = "本轮已停止。"
    }

    private func markCurrent(correct: Bool) {
        guard let word = currentWord else { return }
        if correct {
            store.markCorrect(word)
            sessionMessage = "\(word.word) 已记为正确。"
        } else {
            store.markWrong(word)
            sessionMessage = "\(word.word) 已加入错题集。"
        }

        if currentIndex + 1 < queue.count {
            currentIndex += 1
            hoveredDecision = nil
            if let next = currentWord {
                speech.speak(next.word)
            }
        } else {
            sessionMessage += " 本轮结束。"
            queue = []
            currentIndex = 0
            hoveredDecision = nil
        }
    }
}

struct WordBookView: View {
    @EnvironmentObject private var store: WordStore
    @State private var searchText = ""

    private var filteredWords: [WordEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.allWordsSorted }

        return store.allWordsSorted.filter { word in
            wordMatches(word, query: query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(title: "单词本", subtitle: "手动新增或批量导入单词，自动匹配音标；未收录的可以手动补。")

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 18) {
                    PaperCard(title: "手动新增", tint: PaperTheme.sheet) {
                        HStack(spacing: 10) {
                            TextField("输入一个英语单词", text: $store.singleWordText)
                                .textFieldStyle(.roundedBorder)
                                .font(AppFont.font(size: 16))
                                .onSubmit {
                                    store.addSingleWord()
                                }

                            Button {
                                store.addSingleWord()
                            } label: {
                                Label("新增", systemImage: "plus.circle")
                            }
                            .buttonStyle(StampButtonStyle(color: PaperTheme.greenInk))
                        }

                        Text("按回车也可以新增。")
                            .font(AppFont.font(size: 13))
                            .foregroundStyle(PaperTheme.mutedInk)
                    }

                    PaperCard(title: "批量导入", tint: PaperTheme.sheet) {
                        TextEditor(text: $store.importText)
                            .font(AppFont.font(size: 16))
                            .scrollContentBackground(.hidden)
                            .background(PaperTheme.note.opacity(0.45))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(PaperTheme.line.opacity(0.5), lineWidth: 1)
                            )
                            .frame(height: 170)

                        Button {
                            store.importWords()
                        } label: {
                            Label("导入单词", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
                    }

                    OCRImportView()

                    Text(store.dataMessage)
                        .font(AppFont.font(size: 13))
                        .foregroundStyle(PaperTheme.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 330)

                PaperCard(title: "全部单词（\(store.words.count)）", tint: PaperTheme.sheet) {
                    if store.words.isEmpty {
                        EmptyState(text: "还没有单词。")
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(PaperTheme.mutedInk)

                                TextField("搜索单词或中文释义", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(AppFont.font(size: 15))

                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
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

                            Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "共 \(store.words.count) 个单词" : "找到 \(filteredWords.count) 个")
                                .font(AppFont.font(size: 13))
                                .foregroundStyle(PaperTheme.mutedInk)

                            if filteredWords.isEmpty {
                                EmptyState(text: "没有找到匹配单词。")
                            } else {
                                List {
                                    ForEach(filteredWords) { word in
                                        WordRow(word: word)
                                            .listRowBackground(Color.clear)
                                    }
                                }
                                .listStyle(.plain)
                                .scrollContentBackground(.hidden)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
    }

    private func wordMatches(_ word: WordEntry, query: String) -> Bool {
        let haystacks = [
            word.word,
            word.displayIPA,
            word.displayMeaning,
            word.commonMeaning ?? "",
            word.customMeaning ?? "",
            word.meanings?.map { "\($0.partOfSpeech) \($0.chinese)" }.joined(separator: " ") ?? "",
            word.exampleEnglish ?? "",
            word.exampleChinese ?? ""
        ]

        return haystacks
            .map { $0.lowercased() }
            .contains { $0.contains(query) }
    }
}

struct OCRImportView: View {
    @EnvironmentObject private var store: WordStore
    @State private var recognizedWords: [String] = []
    @State private var isRecognizing = false
    @State private var message = "支持 PNG、JPG、截图。"

    var body: some View {
        PaperCard(title: "图片识别导入", tint: PaperTheme.sheet) {
            HStack(spacing: 10) {
                Button {
                    chooseImage()
                } label: {
                    Label(isRecognizing ? "识别中" : "选择图片 OCR", systemImage: "text.viewfinder")
                }
                .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
                .disabled(isRecognizing)

                Button {
                    store.importWords(recognizedWords, source: "OCR")
                    recognizedWords = []
                    message = "已提交导入。"
                } label: {
                    Label("导入识别单词", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(StampButtonStyle(color: PaperTheme.greenInk))
                .disabled(recognizedWords.isEmpty || isRecognizing)
            }

            Text(message)
                .font(AppFont.font(size: 13))
                .foregroundStyle(PaperTheme.mutedInk)

            if !recognizedWords.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(recognizedWords, id: \.self) { word in
                            Text(word)
                                .font(AppFont.font(size: 13))
                                .foregroundStyle(PaperTheme.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(PaperTheme.note.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 105)
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
        recognizedWords = []

        Task {
            do {
                let words = try await OCRService.recognizeWords(from: url)
                await MainActor.run {
                    recognizedWords = words
                    message = words.isEmpty ? "没有识别到英文单词。" : "识别到 \(words.count) 个英文单词，请确认后导入。"
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

struct WordRow: View {
    @EnvironmentObject private var store: WordStore
    @EnvironmentObject private var speech: SpeechService
    var word: WordEntry
    @State private var draftWord = ""
    @State private var isEditingWord = false
    @FocusState private var isWordFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(word.word)
                            .font(AppFont.font(size: 20, weight: .semibold))
                            .foregroundStyle(PaperTheme.ink)
                        Text("— \(word.displayMeaning)")
                            .font(AppFont.font(size: 18, weight: .semibold))
                            .foregroundStyle(word.displayMeaning == "未收录释义" ? PaperTheme.redPencil : PaperTheme.ink)
                            .lineLimit(1)
                    }
                    HStack(spacing: 8) {
                        Text(word.displayIPA)
                            .font(AppFont.font(size: 15))
                            .foregroundStyle(word.displayIPA == "未收录音标" ? PaperTheme.redPencil : PaperTheme.blueInk)
                        Button {
                            speech.speak(word.word)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                        .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.blueInk))
                        .help("播放 \(word.word)")
                    }

                    if let meanings = word.meanings, !meanings.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(meanings, id: \.self) { meaning in
                                HStack(alignment: .top, spacing: 10) {
                                    Text(meaning.partOfSpeech)
                                        .foregroundStyle(PaperTheme.mutedInk)
                                        .frame(width: 34, alignment: .leading)
                                    Text(meaning.chinese)
                                        .foregroundStyle(PaperTheme.ink)
                                }
                            }
                        }
                        .font(AppFont.font(size: 14))
                    }

                    if let exampleEnglish = word.exampleEnglish, let exampleChinese = word.exampleChinese {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("例句  \(exampleEnglish)")
                            Text(exampleChinese)
                        }
                        .font(AppFont.font(size: 13))
                        .foregroundStyle(PaperTheme.mutedInk)
                        .padding(.top, 2)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    if isEditingWord {
                        TextField("单词", text: $draftWord)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .focused($isWordFieldFocused)
                            .onSubmit {
                                saveWordEdit()
                            }

                        Button {
                            saveWordEdit()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.greenInk))
                        .help("保存单词")
                    } else {
                        Button {
                            draftWord = word.word
                            isEditingWord = true
                            isWordFieldFocused = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.blueInk))
                        .help("编辑单词")
                    }

                    Button {
                        store.deleteWord(word)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(IconOnlyButtonStyle(color: PaperTheme.redPencil))
                    .help("删除单词")
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            syncDrafts()
        }
        .onChange(of: word) { _ in
            syncDrafts()
        }
        .onChange(of: isWordFieldFocused) { focused in
            if !focused {
                isEditingWord = false
                draftWord = word.word
            }
        }
    }

    private func syncDrafts() {
        draftWord = word.word
    }

    private func saveWordEdit() {
        store.updateWord(for: word, newWord: draftWord)
        isEditingWord = false
        isWordFieldFocused = false
    }
}

struct WrongBookView: View {
    @EnvironmentObject private var store: WordStore
    @EnvironmentObject private var speech: SpeechService

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(title: "错题集", subtitle: "错词会留在这里，复听时会优先练习仍不稳定的词。")

            PaperCard(title: "红笔批注", tint: PaperTheme.sheet) {
                if store.wrongWords.isEmpty {
                    EmptyState(text: "还没有错词。听写时点“错”，这里就会自动记录。")
                } else {
                    List {
                        ForEach(store.wrongWords) { word in
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(word.word)
                                        .font(AppFont.font(size: 21, weight: .semibold))
                                        .foregroundStyle(PaperTheme.ink)
                                    Text(word.displayIPA)
                                        .font(AppFont.font(size: 15))
                                        .foregroundStyle(PaperTheme.blueInk)
                                    Text(word.displayMeaning)
                                        .font(AppFont.font(size: 15, weight: .medium))
                                        .foregroundStyle(PaperTheme.ink)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 6) {
                                    StatusTag(text: word.masteryStatus.rawValue, color: word.masteryStatus == .basic ? PaperTheme.greenInk : PaperTheme.redPencil)
                                    Text("错 \(word.wrongCount) 次 / 连对 \(word.consecutiveCorrectInWrongBook)")
                                        .font(AppFont.font(size: 13))
                                        .foregroundStyle(PaperTheme.mutedInk)
                                }
                                Button {
                                    speech.speak(word.word)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                }
                                .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .padding(18)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var speech: SpeechService

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(title: "设置", subtitle: "调一下发音和节奏，让听写更像你的日常使用方式。")

            PaperCard(title: "语音", tint: PaperTheme.sheet) {
                Picker("英文语音", selection: $speech.voicePreset) {
                    ForEach(VoicePreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                Picker("语速", selection: $speech.pace) {
                    ForEach(SpeechPace.allCases) { pace in
                        Text(pace.rawValue).tag(pace)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 210)

                Button {
                    speech.speak("environment")
                } label: {
                    Label("试听 environment", systemImage: "speaker.wave.2")
                }
                .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
            }
        }
        .padding(18)
    }
}

struct HeaderBlock: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppFont.font(size: 34, weight: .bold))
                .foregroundStyle(PaperTheme.ink)
            Text(subtitle)
                .font(AppFont.font(size: 15))
                .foregroundStyle(PaperTheme.mutedInk)
        }
    }
}

struct StatLine: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(PaperTheme.mutedInk)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(PaperTheme.ink)
        }
        .font(AppFont.font(size: 14))
    }
}

struct EmptyState: View {
    var text: String

    var body: some View {
        Text(text)
            .font(AppFont.font(size: 15))
            .foregroundStyle(PaperTheme.mutedInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(30)
    }
}
