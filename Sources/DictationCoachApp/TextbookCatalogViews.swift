import SwiftUI

struct TextbookCatalog: Identifiable, Hashable {
    static let pepPrimary2012ID = "pep-primary-2012"
    static let pepPrimary2024ID = "pep-primary-2024"

    let id: String
    let displayName: String
    let edition: String?
    let availableModules: Set<CatalogModule>

    static let all: [TextbookCatalog] = [
        TextbookCatalog(
            id: pepPrimary2012ID,
            displayName: "人教版 3–6 年级",
            edition: "PEP 2012",
            availableModules: Set(CatalogModule.allCases)
        ),
        TextbookCatalog(
            id: pepPrimary2024ID,
            displayName: "人教版 3–6 年级（新）",
            edition: "PEP 2024",
            availableModules: [.practice, .wordBook, .wrongBook]
        ),
        TextbookCatalog(
            id: "pep-junior",
            displayName: "人教版 7–9 年级",
            edition: nil,
            availableModules: []
        )
    ]

    static func catalog(withID id: String) -> TextbookCatalog? {
        all.first { $0.id == id }
    }

    func isAvailable(in module: CatalogModule) -> Bool {
        availableModules.contains(module)
    }
}

enum CatalogModule: CaseIterable, Hashable {
    case practice
    case wordBook
    case sentences
    case wrongBook

    var title: String {
        switch self {
        case .practice: return "听写"
        case .wordBook: return "单词本"
        case .sentences: return "常用句"
        case .wrongBook: return "错题集"
        }
    }

    var actionTitle: String {
        switch self {
        case .practice: return "开始听写"
        case .wordBook: return "查看单词"
        case .sentences: return "查看常用句"
        case .wrongBook: return "查看错题"
        }
    }

    func countText(_ count: Int) -> String {
        switch self {
        case .practice: return "\(count) 个可练习单词"
        case .wordBook: return "\(count) 个单词"
        case .sentences: return "\(count) 条常用句"
        case .wrongBook: return "\(count) 个错词"
        }
    }
}

struct TextbookCatalogSelectionView: View {
    let module: CatalogModule
    let countForCatalog: (String) -> Int
    let onSelect: (TextbookCatalog) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DecorativeResourceImage(name: "qb", fileExtension: "png")
                .frame(width: 230, height: 230)
                .blendMode(.multiply)
                .opacity(0.78)
                .shadow(color: .black.opacity(0.14), radius: 14, x: 9, y: 11)
                .offset(x: 78, y: 42)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HeaderBlock(title: module.title, subtitle: "选择孩子当前使用的教材")

                HStack(alignment: .bottom, spacing: 18) {
                    ForEach(TextbookCatalog.all) { catalog in
                        TextbookFolderCard(
                            catalog: catalog,
                            module: module,
                            count: countForCatalog(catalog.id),
                            onSelect: { onSelect(catalog) }
                        )
                    }
                }
                .padding(.top, 150)

                Image(nsImage: ResourceImageLoader.image(named: "textbook-shelf", extension: "png") ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 3)
                    .padding(.horizontal, -8)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct TextbookFolderCard: View {
    let catalog: TextbookCatalog
    let module: CatalogModule
    let count: Int
    let onSelect: () -> Void

    private var isAvailable: Bool {
        catalog.isAvailable(in: module)
    }

    var body: some View {
        Group {
            if isAvailable {
                Button(action: onSelect) { cardContent }
                    .buttonStyle(.plain)
                    .accessibilityHint(module.actionTitle)
            } else {
                cardContent
                    .accessibilityElement(children: .ignore)
                    .accessibilityValue("准备中")
            }
        }
        .accessibilityLabel(catalog.displayName)
    }

    private var cardContent: some View {
        ZStack(alignment: .topLeading) {
                Image(nsImage: ResourceImageLoader.image(named: "textbook-folder-card", extension: "png") ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(maxWidth: .infinity)
                    .frame(height: 238)
                    .shadow(color: .black.opacity(0.13), radius: 8, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 16) {
                    Text(catalog.displayName)
                        .font(AppFont.font(size: 22, weight: .semibold))
                        .foregroundStyle(isAvailable ? PaperTheme.ink : PaperTheme.mutedInk.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if isAvailable {
                        HStack(spacing: 12) {
                            if let edition = catalog.edition {
                                Text(edition)
                            }
                            Rectangle()
                                .fill(PaperTheme.line.opacity(0.38))
                                .frame(width: 1, height: 22)
                            Text(module.countText(count))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .font(AppFont.font(size: 15, weight: .medium))
                        .foregroundStyle(PaperTheme.mutedInk)

                        Spacer(minLength: 0)

                        HStack {
                            Spacer()
                            Text(module.actionTitle)
                                .font(AppFont.font(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 22)
                                .frame(height: 42)
                                .background(PaperTheme.blueInk)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    } else {
                        Spacer(minLength: 0)
                        Text("准备中")
                            .font(AppFont.font(size: 16, weight: .semibold))
                            .foregroundStyle(PaperTheme.mutedInk.opacity(0.76))
                            .frame(maxWidth: .infinity, alignment: .center)

                        Spacer(minLength: 0)
                        HStack {
                            Spacer()
                            Text("准备中")
                                .font(AppFont.font(size: 14, weight: .semibold))
                                .foregroundStyle(PaperTheme.mutedInk.opacity(0.62))
                                .padding(.horizontal, 20)
                                .frame(height: 38)
                                .background(Color.black.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(PaperTheme.line.opacity(0.28), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 58)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 238)
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CatalogContextBar: View {
    let catalog: TextbookCatalog
    let onChangeCatalog: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("教材词库")
                .foregroundStyle(PaperTheme.mutedInk)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PaperTheme.mutedInk.opacity(0.7))
            Text(catalog.displayName)
                .foregroundStyle(PaperTheme.ink)
                .fontWeight(.semibold)
            if let edition = catalog.edition {
                Text(edition)
                    .foregroundStyle(PaperTheme.blueInk)
            }
            Spacer()
            Button("更换教材", action: onChangeCatalog)
                .buttonStyle(StampButtonStyle(color: PaperTheme.blueInk))
        }
        .font(AppFont.font(size: 14, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.white.opacity(0.76))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(PaperTheme.line.opacity(0.42), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
