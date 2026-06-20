import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum AppSection: String, CaseIterable, Identifiable {
    case practice = "听写"
    case wordBook = "单词本"
    case wrongBook = "错题集"
    case settings = "设置"

    var id: String { rawValue }

    var iconResource: String {
        switch self {
        case .practice: "听写"
        case .wordBook: "单词本"
        case .wrongBook: "错题集"
        case .settings: "设置"
        }
    }

    var fallbackSystemImage: String {
        switch self {
        case .practice: "headphones"
        case .wordBook: "book.closed"
        case .wrongBook: "pencil.and.outline"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: AppSection = .practice

    var body: some View {
        ZStack {
            AppBackground()
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    SidebarBackground()

                    AppSidebar(selectedSection: $selectedSection)
                        .padding(.leading, 26)
                        .padding(.top, 54)
                        .padding(.bottom, 22)
                }
                .frame(minWidth: 202, idealWidth: 202, maxWidth: 202)
                .layoutPriority(2)
                .ignoresSafeArea(edges: .vertical)

                Rectangle()
                    .fill(PaperTheme.line.opacity(0.36))
                    .frame(width: 1)
                    .ignoresSafeArea(edges: .vertical)

                ZStack(alignment: .topLeading) {
                    PaperRuleLines()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    selectedContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 42)
                        .padding(.top, 40)
                        .padding(.trailing, 26)
                        .padding(.bottom, 22)
                }
                .layoutPriority(1)
            }
        }
        .background(WindowTitleCenterer())
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .practice:
            PracticeView()
        case .wordBook:
            WordBookView()
        case .wrongBook:
            WrongBookView()
        case .settings:
            SettingsView()
        }
    }
}

struct AppSidebar: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            AppLogoView()
                .padding(.bottom, 30)

            ForEach(AppSection.allCases) { section in
                SidebarButton(
                    section: section,
                    isSelected: selectedSection == section
                ) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedSection = section
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 176, alignment: .topLeading)
    }
}

struct SidebarBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.94),
                Color(red: 0.985, green: 0.955, blue: 0.875),
                Color(red: 0.955, green: 0.915, blue: 0.80)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct WindowTitleCenterer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(from: nsView)
        }
    }

    private func configureWindow(from view: NSView) {
        guard let window = view.window,
              let titlebar = window.standardWindowButton(.closeButton)?.superview else {
            return
        }

        window.title = "DictationCoach"
        window.titleVisibility = .hidden

        let tag = 20260618
        if titlebar.viewWithTag(tag) != nil { return }

        let label = NSTextField(labelWithString: "DictationCoach")
        label.tag = tag
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = NSColor.labelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        titlebar.addSubview(label)

        let closeButton = window.standardWindowButton(.closeButton)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: titlebar.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: closeButton?.centerYAnchor ?? titlebar.centerYAnchor)
        ])
    }
}

struct AppLogoView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Group {
                if let image = ResourceImageLoader.image(named: "AppIcon", extension: "icns") {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "textformat")
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                }
            }
            .frame(width: 54, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(PaperTheme.sheet)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(PaperTheme.line.opacity(0.36), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Text("v\(appVersion)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PaperTheme.mutedInk.opacity(0.68))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(width: 146, alignment: .center)
        .help("正字")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}

struct SidebarButton: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                BundledNavigationIcon(
                    resourceName: section.iconResource,
                    fallbackSystemImage: section.fallbackSystemImage,
                    colorHex: isSelected ? "#1F1A14" : "#9B948A"
                )
                .frame(width: 22, height: 22)

                Text(section.rawValue)
                    .font(AppFont.font(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? PaperTheme.ink : PaperTheme.mutedInk.opacity(isHovering ? 0.92 : 0.68))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(width: 146, height: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? PaperTheme.sidebarSelection : (isHovering ? PaperTheme.sheet.opacity(0.45) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .help(section.rawValue)
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = inside
            }
        }
    }
}

struct BundledNavigationIcon: View {
    let resourceName: String
    let fallbackSystemImage: String
    let colorHex: String

    var body: some View {
        Group {
            if let image = ResourceImageLoader.svgImage(named: resourceName, colorHex: colorHex) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: colorHex))
            }
        }
    }
}

enum ResourceImageLoader {
    static func image(named name: String, extension fileExtension: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension) else { return nil }
        return NSImage(contentsOf: url)
    }

    static func svgImage(named name: String, colorHex: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              var svg = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        svg = svg
            .replacingOccurrences(of: "#333", with: colorHex)
            .replacingOccurrences(of: "#333333", with: colorHex)

        guard let data = svg.data(using: .utf8) else { return nil }
        return NSImage(data: data)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = Int(hex, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
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
    @State private var selectedGrade = "全部年级"
    @State private var selectedBook = "全部册"
    @State private var selectedUnit = "全部单元"
    @State private var didRestoreSession = false

    private var currentWord: WordEntry? {
        guard queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    private var isSessionActive: Bool {
        !queue.isEmpty
    }

    private var practicePool: [WordEntry] {
        let source = mode == .all ? store.allWordsSorted : store.activeWrongWords
        return source.filter(wordMatchesTextbookFilter)
    }

    private var hasActiveFilter: Bool {
        selectedGrade != "全部年级" || selectedBook != "全部册" || selectedUnit != "全部单元"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(title: "听写", subtitle: "按范围开始听写，记录每一次对错")

            HStack(alignment: .top, spacing: 18) {
                PaperCard(title: nil, tint: PaperTheme.sheet) {
                    SectionTitle(icon: "doc.text", title: "练习纸")

                    VStack(alignment: .center, spacing: 0) {
                        HStack(spacing: 8) {
                            PracticeModeDropdown(selection: $mode)
                            textbookPicker(title: "年级", selection: $selectedGrade, values: ["全部年级"] + store.textbookGrades)
                            textbookPicker(title: "册", selection: $selectedBook, values: ["全部册"] + store.textbookBooks)
                            textbookPicker(title: "单元", selection: $selectedUnit, values: ["全部单元"] + store.textbookUnits)

                            if hasActiveFilter {
                                Button {
                                    selectedGrade = "全部年级"
                                    selectedBook = "全部册"
                                    selectedUnit = "全部单元"
                                } label: {
                                    Text("重置")
                                        .font(AppFont.font(size: 13, weight: .semibold))
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .buttonStyle(StampButtonStyle(color: PaperTheme.mutedInk))
                                .help("重置筛选")
                            }
                        }
                        .disabled(isSessionActive)
                        .opacity(isSessionActive ? 0.62 : 1)

                        practiceProgressHeader
                            .padding(.top, 18)

                        practiceCard
                            .frame(maxWidth: 820)
                            .aspectRatio(1513.0 / 602.0, contentMode: .fit)
                            .padding(.top, 30)

                        if isSessionActive {
                            HStack(spacing: 20) {
                                Button {
                                    previousWord()
                                } label: {
                                    Label("上一个", systemImage: "backward.end.fill")
                                        .labelStyle(.titleAndIcon)
                                }
                                .buttonStyle(PracticeToolbarButtonStyle())
                                .disabled(currentIndex == 0)
                                .keyboardShortcut(.leftArrow, modifiers: [])
                                .help("上一个（←）")

                                Button {
                                    if let currentWord { speech.speakRepeated(currentWord.word) }
                                } label: {
                                    Image(systemName: "play.fill")
                                        .padding(.leading, 4)
                                }
                                .buttonStyle(PracticePlayButtonStyle())
                                .keyboardShortcut(.space, modifiers: [])
                                .help("播放（空格）")

                                Text("播放")
                                    .font(AppFont.font(size: 18, weight: .semibold))
                                    .foregroundStyle(PaperTheme.ink)
                                    .padding(.leading, -8)
                                    .padding(.trailing, 8)

                                Button {
                                    nextWord()
                                } label: {
                                    Label("下一个", systemImage: "forward.end.fill")
                                        .labelStyle(.titleAndIcon)
                                }
                                .buttonStyle(PracticeToolbarButtonStyle())
                                .disabled(currentIndex + 1 >= queue.count)
                                .keyboardShortcut(.rightArrow, modifiers: [])
                                .help("下一个（→）")

                                Button {
                                    stopSession()
                                } label: {
                                    Label("停止", systemImage: "stop.fill")
                                        .labelStyle(.titleAndIcon)
                                }
                                .buttonStyle(PracticeToolbarButtonStyle())
                                .keyboardShortcut(.escape, modifiers: [])
                                    .help("停止（Esc）")
                            }
                            .padding(.top, 30)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 470, alignment: .top)
                }

                PaperCard(title: nil, tint: PaperTheme.sheet) {
                    ZStack(alignment: .topTrailing) {
                        DecorativeResourceImage(name: "hxz", fileExtension: "png")
                            .frame(width: 30, height: 43)
                            .rotationEffect(.degrees(17))
                            .blendMode(.multiply)
                            .opacity(0.92)
                            .shadow(color: Color.black.opacity(0.14), radius: 2, x: 1, y: 1)
                            .offset(x: 0, y: -24)
                            .allowsHitTesting(false)

                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(icon: "list.bullet.rectangle", title: "本轮记录")

                            Text(sessionMessage)
                                .font(AppFont.font(size: 15))
                                .foregroundStyle(PaperTheme.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider()

                            StatLine(label: "全部单词", value: "\(store.words.count)")
                            StatLine(label: "当前范围", value: "\(practicePool.count)")
                            StatLine(label: "错题集", value: "\(store.wrongWords.count)")
                            StatLine(label: "待复听", value: "\(store.activeWrongWords.count)")

                            if let currentWord {
                                Divider()
                                HStack(spacing: 8) {
                                    StatusTag(text: currentWord.masteryStatus.rawValue, color: currentWord.isInWrongBook ? PaperTheme.redPencil : PaperTheme.blueInk)

                                    if let textbookTag = store.textbookTags(for: currentWord).first {
                                        Text(textbookTag.label)
                                            .font(AppFont.font(size: 12, weight: .semibold))
                                            .foregroundStyle(PaperTheme.blueInk)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(PaperTheme.note.opacity(0.68))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                StatLine(label: "释义", value: currentWord.displayMeaning)
                                StatLine(label: "答对", value: "\(currentWord.correctCount)")
                                StatLine(label: "答错", value: "\(currentWord.wrongCount)")
                            }
                        }
                        .frame(width: 220, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .bottomTrailing) {
            DecorativeResourceImage(name: "qb", fileExtension: "png")
                .frame(width: 268, height: 268)
                .blendMode(.multiply)
                .opacity(0.82)
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 12, y: 14)
                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 3, y: 5)
                .offset(x: 84, y: -16)
                .allowsHitTesting(false)
        }
        .onAppear {
            restorePracticeSessionIfNeeded()
        }
    }

    private var practiceCard: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = ResourceImageLoader.image(named: "zzbj", extension: "png") {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(PaperTheme.note.opacity(0.08))
                        )
                        .shadow(color: .black.opacity(0.12), radius: 13, x: 0, y: 7)
                        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PaperTheme.note.opacity(0.82))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(PaperTheme.line.opacity(0.55), lineWidth: 1)
                        )
                }

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
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .transition(.opacity)
                }

                if let currentWord {
                    VStack(spacing: 10) {
                        Text(currentWord.word)
                            .font(AppFont.font(size: 56, weight: .bold))
                            .foregroundStyle(PaperTheme.ink)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)

                        Text(currentWord.displayIPA)
                            .font(AppFont.font(size: 21, weight: .medium))
                            .foregroundStyle(PaperTheme.blueInk)

                        Text(currentWord.displayMeaning)
                            .font(AppFont.font(size: 24, weight: .semibold))
                            .foregroundStyle(PaperTheme.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .padding(.top, 4)
                    }
                    .padding()
                } else {
                    VStack(spacing: 26) {
                        Button {
                            startSession()
                        } label: {
                            Image(systemName: "play.fill")
                                .padding(.leading, 4)
                        }
                        .buttonStyle(PracticePlayButtonStyle())
                        .help("开始听写")

                        Text("点击播放，开始听写")
                            .font(AppFont.font(size: 21, weight: .medium))
                            .foregroundStyle(PaperTheme.mutedInk.opacity(0.65))
                    }
                    .padding()
                }

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
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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

    private var practiceProgressHeader: some View {
        Group {
            if queue.isEmpty {
                HStack(spacing: 42) {
                    Text("当前范围 \(practicePool.count) 个")
                    Text("未开始")
                }
                .font(AppFont.font(size: 15, weight: .medium))
                .foregroundStyle(PaperTheme.mutedInk)
            } else {
                HStack(spacing: 14) {
                    Text("进度")
                    Text("\(min(currentIndex + 1, queue.count)) / \(queue.count)")
                    ProgressView(value: Double(min(currentIndex + 1, queue.count)), total: Double(max(queue.count, 1)))
                        .progressViewStyle(.linear)
                        .tint(Color(red: 1.0, green: 0.58, blue: 0.06))
                        .frame(width: 330)
                }
                .font(AppFont.font(size: 15, weight: .semibold))
                .foregroundStyle(PaperTheme.ink.opacity(0.86))
            }
        }
    }

    private func startSession() {
        queue = practicePool.shuffled()
        currentIndex = 0
        hoveredDecision = nil

        if let first = queue.first {
            sessionMessage = "本轮 \(queue.count) 个单词。"
            persistPracticeSession()
            speech.speakRepeated(first.word)
        } else {
            sessionMessage = emptyPoolMessage
            store.clearPracticeSession()
        }
    }

    private var emptyPoolMessage: String {
        if hasActiveFilter {
            return mode == .all ? "当前筛选下没有单词。" : "当前筛选下没有待复听错词。"
        }
        return mode == .all ? "单词本还是空的，先去导入单词。" : "目前没有待复听错词。"
    }

    private func textbookPicker(title: String, selection: Binding<String>, values: [String]) -> some View {
        PaperDropdown(
            title: title,
            selection: selection,
            values: values,
            width: title == "单元" ? 146 : 132
        )
    }

    private func wordMatchesTextbookFilter(_ word: WordEntry) -> Bool {
        guard hasActiveFilter else { return true }

        let tags = store.textbookTags(for: word)
        return tags.contains { tag in
            (selectedGrade == "全部年级" || tag.grade == selectedGrade)
                && (selectedBook == "全部册" || tag.book == selectedBook)
                && (selectedUnit == "全部单元" || tag.unit == selectedUnit)
        }
    }

    private func previousWord() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        hoveredDecision = nil
        persistPracticeSession()
        if let currentWord {
            speech.speak(currentWord.word)
        }
    }

    private func nextWord() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        hoveredDecision = nil
        persistPracticeSession()
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
        store.clearPracticeSession()
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
            persistPracticeSession()
            if let next = currentWord {
                speech.speak(next.word)
            }
        } else {
            sessionMessage += " 本轮结束。"
            queue = []
            currentIndex = 0
            hoveredDecision = nil
            store.clearPracticeSession()
        }
    }

    private func restorePracticeSessionIfNeeded() {
        guard !didRestoreSession else { return }
        didRestoreSession = true

        guard let snapshot = store.loadPracticeSession() else { return }
        let restoredQueue = snapshot.wordIDs.compactMap { store.word(withID: $0) }
        guard !restoredQueue.isEmpty else {
            store.clearPracticeSession()
            return
        }

        mode = snapshot.mode
        selectedGrade = snapshot.selectedGrade
        selectedBook = snapshot.selectedBook
        selectedUnit = snapshot.selectedUnit
        queue = restoredQueue
        currentIndex = min(max(snapshot.currentIndex, 0), restoredQueue.count - 1)
        hoveredDecision = nil
        sessionMessage = "已恢复上次听写进度。"
    }

    private func persistPracticeSession() {
        guard !queue.isEmpty else {
            store.clearPracticeSession()
            return
        }

        store.savePracticeSession(PracticeSessionSnapshot(
            mode: mode,
            wordIDs: queue.map(\.id),
            currentIndex: currentIndex,
            selectedGrade: selectedGrade,
            selectedBook: selectedBook,
            selectedUnit: selectedUnit,
            savedAt: Date()
        ))
    }
}

struct WordBookView: View {
    @EnvironmentObject private var store: WordStore
    @State private var searchText = ""
    @State private var selectedGrade = "全部年级"
    @State private var selectedBook = "全部册"
    @State private var selectedUnit = "全部单元"
    @State private var wordInputWarning: WordInputWarning?

    private var filteredWords: [WordEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return store.allWordsSorted.filter { word in
            let matchesSearch = query.isEmpty || wordMatches(word, query: query)
            return matchesSearch && wordMatchesTextbookFilter(word)
        }
    }

    private var hasActiveFilter: Bool {
        selectedGrade != "全部年级" || selectedBook != "全部册" || selectedUnit != "全部单元"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(title: "单词本", subtitle: "整理你的单词来源，随时查找和导入")

            HStack(alignment: .top, spacing: 18) {
                wordListCard

                VStack(spacing: 18) {
                    PaperCard(title: nil, tint: PaperTheme.sheet) {
                        SectionTitle(icon: "plus.circle.fill", title: "手动新增")

                        HStack(spacing: 10) {
                            TextField("输入一个英语单词", text: $store.singleWordText)
                                .textFieldStyle(.roundedBorder)
                                .font(AppFont.font(size: 16))
                                .onSubmit {
                                    attemptAddSingleWord()
                                }

                            Button {
                                attemptAddSingleWord()
                            } label: {
                                Label("新增", systemImage: "plus.circle")
                            }
                            .buttonStyle(StampButtonStyle(color: PaperTheme.greenInk))
                        }

                        Text("按回车也可以新增。")
                            .font(AppFont.font(size: 13))
                            .foregroundStyle(PaperTheme.mutedInk)
                    }

                    PaperCard(title: nil, tint: PaperTheme.sheet) {
                        HStack(spacing: 12) {
                            SectionTitle(icon: "square.and.arrow.down", title: "批量导入")

                            Spacer(minLength: 0)

                            Button {
                                store.importWords()
                            } label: {
                                Label("导入单词", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
                        }

                        TextEditor(text: $store.importText)
                            .font(AppFont.font(size: 16))
                            .scrollContentBackground(.hidden)
                            .background(PaperTheme.note.opacity(0.45))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(PaperTheme.line.opacity(0.5), lineWidth: 1)
                            )
                            .frame(height: 70)
                    }

                    OCRImportView()

                    Text(store.dataMessage)
                        .font(AppFont.font(size: 13))
                        .foregroundStyle(PaperTheme.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 330)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .alert(item: $wordInputWarning) { warning in
            Alert(
                title: Text(warning.title),
                message: Text(warning.message),
                primaryButton: .default(Text("仍然添加")) {
                    store.addSingleWord(force: true)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private func attemptAddSingleWord() {
        if let warning = store.pendingSingleWordWarning() {
            wordInputWarning = warning
        } else {
            store.addSingleWord()
        }
    }

    private var wordListCard: some View {
        PaperCard(title: nil, tint: PaperTheme.sheet) {
            SectionTitle(icon: "book.closed.fill", title: "全部单词（\(store.words.count)）")

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

                    HStack(spacing: 8) {
                        textbookPicker(title: "年级", selection: $selectedGrade, values: ["全部年级"] + store.textbookGrades)
                        textbookPicker(title: "册", selection: $selectedBook, values: ["全部册"] + store.textbookBooks)
                        textbookPicker(title: "单元", selection: $selectedUnit, values: ["全部单元"] + store.textbookUnits)

                        if hasActiveFilter {
                            Button {
                                selectedGrade = "全部年级"
                                selectedBook = "全部册"
                                selectedUnit = "全部单元"
                            } label: {
                                Text("重置")
                                    .font(AppFont.font(size: 13, weight: .semibold))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .buttonStyle(StampButtonStyle(color: PaperTheme.mutedInk))
                            .help("重置筛选")
                        }
                    }

                    Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasActiveFilter ? "共 \(store.words.count) 个单词" : "找到 \(filteredWords.count) 个")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func textbookPicker(title: String, selection: Binding<String>, values: [String]) -> some View {
        PaperDropdown(
            title: title,
            selection: selection,
            values: values,
            width: title == "单元" ? 146 : 132
        )
    }

    private func wordMatchesTextbookFilter(_ word: WordEntry) -> Bool {
        guard hasActiveFilter else { return true }

        let tags = store.textbookTags(for: word)
        return tags.contains { tag in
            (selectedGrade == "全部年级" || tag.grade == selectedGrade)
                && (selectedBook == "全部册" || tag.book == selectedBook)
                && (selectedUnit == "全部单元" || tag.unit == selectedUnit)
        }
    }

    private func wordMatches(_ word: WordEntry, query: String) -> Bool {
        let textbookText = store.textbookTags(for: word)
            .map { "\($0.grade) \($0.book) \($0.unit) \($0.meaning)" }
            .joined(separator: " ")
        let haystacks = [
            word.word,
            word.displayIPA,
            word.displayMeaning,
            word.commonMeaning ?? "",
            word.customMeaning ?? "",
            word.meanings?.map { "\($0.partOfSpeech) \($0.chinese)" }.joined(separator: " ") ?? "",
            word.exampleEnglish ?? "",
            word.exampleChinese ?? "",
            textbookText
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
        PaperCard(title: nil, tint: PaperTheme.sheet) {
            SectionTitle(icon: "text.viewfinder", title: "图片识别导入")

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

                    let tags = store.textbookTags(for: word)
                    if !tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(tags.prefix(2)) { tag in
                                Text(tag.label)
                                    .font(AppFont.font(size: 12, weight: .semibold))
                                    .foregroundStyle(PaperTheme.blueInk)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(PaperTheme.note.opacity(0.75))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
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
    @State private var searchText = ""
    @State private var selectedGrade = "全部年级"
    @State private var selectedBook = "全部册"
    @State private var selectedUnit = "全部单元"

    private var filteredWrongWords: [WordEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return store.wrongWords.filter { word in
            let matchesSearch = query.isEmpty || wordMatches(word, query: query)
            return matchesSearch && wordMatchesTextbookFilter(word)
        }
    }

    private var hasActiveFilter: Bool {
        selectedGrade != "全部年级" || selectedBook != "全部册" || selectedUnit != "全部单元"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderBlock(title: "错题集", subtitle: "集中复听错词，直到真正掌握")

            PaperCard(title: nil, tint: PaperTheme.sheet) {
                SectionTitle(icon: "pencil.and.outline", title: "红笔批注")

                if store.wrongWords.isEmpty {
                    EmptyState(text: "还没有错词。听写时点“错”，这里就会自动记录。")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(PaperTheme.mutedInk)

                            TextField("搜索错词或中文释义", text: $searchText)
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

                        HStack(spacing: 8) {
                            textbookPicker(title: "年级", selection: $selectedGrade, values: ["全部年级"] + store.textbookGrades)
                            textbookPicker(title: "册", selection: $selectedBook, values: ["全部册"] + store.textbookBooks)
                            textbookPicker(title: "单元", selection: $selectedUnit, values: ["全部单元"] + store.textbookUnits)

                            if hasActiveFilter {
                                Button {
                                    selectedGrade = "全部年级"
                                    selectedBook = "全部册"
                                    selectedUnit = "全部单元"
                                } label: {
                                    Text("重置")
                                        .font(AppFont.font(size: 13, weight: .semibold))
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .buttonStyle(StampButtonStyle(color: PaperTheme.mutedInk))
                                .help("重置筛选")
                            }
                        }

                        Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasActiveFilter ? "共 \(store.wrongWords.count) 个错词" : "找到 \(filteredWrongWords.count) 个")
                            .font(AppFont.font(size: 13))
                            .foregroundStyle(PaperTheme.mutedInk)

                        if filteredWrongWords.isEmpty {
                            EmptyState(text: "没有找到匹配错词。")
                        } else {
                            List {
                                ForEach(filteredWrongWords) { word in
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
            }
        }
    }

    private func textbookPicker(title: String, selection: Binding<String>, values: [String]) -> some View {
        PaperDropdown(
            title: title,
            selection: selection,
            values: values,
            width: title == "单元" ? 146 : 132
        )
    }

    private func wordMatchesTextbookFilter(_ word: WordEntry) -> Bool {
        guard hasActiveFilter else { return true }

        let tags = store.textbookTags(for: word)
        return tags.contains { tag in
            (selectedGrade == "全部年级" || tag.grade == selectedGrade)
                && (selectedBook == "全部册" || tag.book == selectedBook)
                && (selectedUnit == "全部单元" || tag.unit == selectedUnit)
        }
    }

    private func wordMatches(_ word: WordEntry, query: String) -> Bool {
        let textbookText = store.textbookTags(for: word)
            .map { "\($0.grade) \($0.book) \($0.unit) \($0.meaning)" }
            .joined(separator: " ")
        let haystacks = [
            word.word,
            word.displayIPA,
            word.displayMeaning,
            word.commonMeaning ?? "",
            word.customMeaning ?? "",
            word.meanings?.map { "\($0.partOfSpeech) \($0.chinese)" }.joined(separator: " ") ?? "",
            word.exampleEnglish ?? "",
            word.exampleChinese ?? "",
            textbookText
        ]

        return haystacks
            .map { $0.lowercased() }
            .contains { $0.contains(query) }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var speech: SpeechService

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DecorativeResourceImage(name: "qb", fileExtension: "png")
                .frame(width: 268, height: 268)
                .blendMode(.multiply)
                .opacity(0.82)
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 12, y: 14)
                .shadow(color: Color.black.opacity(0.08), radius: 5, x: 3, y: 5)
                .offset(x: 84, y: -16)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 18) {
                HeaderBlock(title: "设置", subtitle: "管理你的听写偏好")

                HStack(alignment: .top, spacing: 18) {
                    PaperCard(title: nil, tint: PaperTheme.sheet) {
                        SectionTitle(icon: "speaker.wave.2.fill", title: "语音设置")

                        Text("发音人")
                            .font(AppFont.font(size: 15, weight: .semibold))
                            .foregroundStyle(PaperTheme.ink)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(VoicePreset.allCases) { preset in
                                VoiceChoiceRow(
                                    preset: preset,
                                    isSelected: speech.voicePreset == preset
                                ) {
                                    speech.voicePreset = preset
                                }
                            }
                        }

                        Divider()
                            .padding(.vertical, 6)

                        HStack(alignment: .center, spacing: 18) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("语速")
                                    .font(AppFont.font(size: 15, weight: .semibold))
                                    .foregroundStyle(PaperTheme.ink)

                                HStack(spacing: 0) {
                                    ForEach(SpeechPace.allCases) { pace in
                                        Button {
                                            speech.pace = pace
                                        } label: {
                                            Text(pace.rawValue)
                                                .font(AppFont.font(size: 16, weight: .semibold))
                                                .frame(width: 118, height: 38)
                                                .foregroundStyle(speech.pace == pace ? PaperTheme.ink : PaperTheme.mutedInk)
                                                .background(speech.pace == pace ? PaperTheme.note.opacity(0.92) : Color.clear)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .background(PaperTheme.sheet)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(PaperTheme.line.opacity(0.65), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Spacer()

                            VStack(spacing: 8) {
                                Text("预览")
                                    .font(AppFont.font(size: 14, weight: .semibold))
                                    .foregroundStyle(PaperTheme.mutedInk)
                                Button {
                                    speech.speak("environment")
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(PaperTheme.blueInk)
                                        .frame(width: 46, height: 46)
                                        .background(PaperTheme.sheet)
                                        .overlay(
                                            Circle()
                                                .stroke(PaperTheme.line.opacity(0.72), lineWidth: 1.2)
                                        )
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("试听 environment")
                            }
                        }
                    }
                    .frame(width: 410, alignment: .leading)

                    AboutSettingsCard()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

struct DecorativeResourceImage: View {
    let name: String
    let fileExtension: String

    var body: some View {
        Group {
            if let image = ResourceImageLoader.image(named: name, extension: fileExtension) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

struct VoiceChoiceRow: View {
    let preset: VoicePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? PaperTheme.redPencil.opacity(0.95) : PaperTheme.mutedInk.opacity(0.48))

                Text(preset.rawValue)
                    .font(AppFont.font(size: 16, weight: .semibold))
                    .foregroundStyle(PaperTheme.ink)
                    .frame(width: 88, alignment: .leading)

                Text(preset.primaryVoiceName)
                    .font(AppFont.font(size: 13, weight: .medium))
                    .foregroundStyle(PaperTheme.mutedInk.opacity(0.72))

                Spacer(minLength: 0)
            }
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AboutSettingsCard: View {
    var body: some View {
        PaperCard(title: nil, tint: PaperTheme.sheet) {
            ZStack(alignment: .topTrailing) {
                DecorativeResourceImage(name: "hxz", fileExtension: "png")
                    .frame(width: 30, height: 43)
                    .rotationEffect(.degrees(17))
                    .blendMode(.multiply)
                    .opacity(0.92)
                    .shadow(color: Color.black.opacity(0.14), radius: 2, x: 1, y: 1)
                    .offset(x: 2, y: -34)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(icon: "info.circle.fill", title: "关于")

                    HStack(alignment: .center, spacing: 20) {
                        Group {
                            if let image = ResourceImageLoader.image(named: "AppIcon", extension: "icns") {
                                Image(nsImage: image)
                                    .resizable()
                                    .interpolation(.high)
                            } else {
                                Image(systemName: "textformat")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(20)
                            }
                        }
                        .frame(width: 112, height: 112)
                        .background(PaperTheme.sheet)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(PaperTheme.line.opacity(0.36), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("正字 / DictationCoach")
                                .font(AppFont.font(size: 24, weight: .bold))
                                .foregroundStyle(PaperTheme.blueInk)

                            Text("英语听写好帮助，提升拼写与听力的每一天")
                                .font(AppFont.font(size: 16, weight: .medium))
                                .foregroundStyle(PaperTheme.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("版本 v\(appVersion)")
                                .font(AppFont.font(size: 15, weight: .semibold))
                                .foregroundStyle(PaperTheme.mutedInk.opacity(0.78))
                        }
                    }
                }
                .padding(.trailing, 22)
            }
        }
        .frame(width: 500, alignment: .leading)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
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
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58, alignment: .topLeading)
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
