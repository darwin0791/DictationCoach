import SwiftUI

enum PaperTheme {
    static let page = Color(red: 0.96, green: 0.93, blue: 0.86)
    static let sheet = Color(red: 1.00, green: 0.985, blue: 0.94)
    static let note = Color(red: 1.00, green: 0.96, blue: 0.78)
    static let ink = Color(red: 0.16, green: 0.13, blue: 0.10)
    static let mutedInk = Color(red: 0.46, green: 0.39, blue: 0.31)
    static let line = Color(red: 0.78, green: 0.68, blue: 0.53)
    static let redPencil = Color(red: 0.76, green: 0.18, blue: 0.14)
    static let greenInk = Color(red: 0.16, green: 0.46, blue: 0.30)
    static let blueInk = Color(red: 0.17, green: 0.33, blue: 0.57)
    static let sidebarSelection = Color(red: 0.97, green: 0.80, blue: 0.44)
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.985, green: 0.955, blue: 0.875),
                Color(red: 0.955, green: 0.915, blue: 0.80),
                Color(red: 0.985, green: 0.965, blue: 0.905)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct PaperRuleLines: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<36, id: \.self) { _ in
                Rectangle()
                    .fill(Color.black.opacity(0.035))
                    .frame(height: 1)
            }
        }
        .padding(.top, 44)
    }
}

struct PaperCard<Content: View>: View {
    var title: String?
    var tint: Color = PaperTheme.sheet
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(AppFont.font(size: 17, weight: .semibold))
                    .foregroundStyle(PaperTheme.ink)
            }
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tint)
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(PaperTheme.line.opacity(0.55), lineWidth: 1)
        )
    }
}

struct SectionTitle: View {
    var icon: String
    var title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PaperTheme.blueInk)

            Text(title)
                .font(AppFont.font(size: 20, weight: .bold))
                .foregroundStyle(PaperTheme.ink)
        }
    }
}

struct StampButtonStyle: ButtonStyle {
    var color: Color = PaperTheme.blueInk

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.font(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(PaperTheme.sheet.opacity(configuration.isPressed ? 0.75 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(color.opacity(configuration.isPressed ? 0.95 : 0.7), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .rotationEffect(.degrees(configuration.isPressed ? -0.7 : 0))
    }
}

struct PracticeToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.font(size: 17, weight: .semibold))
            .foregroundStyle(PaperTheme.ink.opacity(isEnabled ? 0.92 : 0.35))
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(PaperTheme.sheet.opacity(configuration.isPressed ? 0.76 : 0.9))
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.08), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(PaperTheme.line.opacity(isEnabled ? 0.58 : 0.28), lineWidth: 1.25)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct PracticePlayButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(PaperTheme.ink.opacity(isEnabled ? 0.92 : 0.35))
            .frame(width: 66, height: 66)
            .background(
                Circle()
                    .fill(PaperTheme.sheet.opacity(configuration.isPressed ? 0.82 : 0.96))
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.16), radius: 10, x: 0, y: 5)
            )
            .overlay(
                Circle()
                    .stroke(PaperTheme.line.opacity(isEnabled ? 0.5 : 0.25), lineWidth: 1.1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

struct PaperDropdown: View {
    let title: String
    @Binding var selection: String
    let values: [String]
    var width: CGFloat = 178

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(AppFont.font(size: 15, weight: .semibold))
                .foregroundStyle(PaperTheme.ink.opacity(0.82))
                .frame(width: 56, height: 38, alignment: .center)

            Rectangle()
                .fill(PaperTheme.line.opacity(0.26))
                .frame(width: 1, height: 26)

            Menu {
                ForEach(values, id: \.self) { value in
                    Button {
                        selection = value
                    } label: {
                        if value == selection {
                            Label(displayText(for: value), systemImage: "checkmark")
                        } else {
                            Text(displayText(for: value))
                        }
                    }
                }
            } label: {
                Text(displayText(for: selection))
                    .font(AppFont.font(size: 15, weight: .semibold))
                    .foregroundStyle(PaperTheme.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .center)
                .padding(.leading, 6)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
        }
        .frame(width: width, height: 38)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PaperTheme.sheet.opacity(0.92))
                .shadow(color: .black.opacity(0.045), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PaperTheme.line.opacity(0.45), lineWidth: 1.15)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func displayText(for value: String) -> String {
        if value == "全部\(title)" {
            return "全部"
        }
        return value
    }
}

struct PracticeModeDropdown: View {
    @Binding var selection: PracticeMode
    var width: CGFloat = 160

    var body: some View {
        HStack(spacing: 0) {
            Text("模式")
                .font(AppFont.font(size: 15, weight: .semibold))
                .foregroundStyle(PaperTheme.ink.opacity(0.82))
                .frame(width: 56, height: 38, alignment: .center)

            Rectangle()
                .fill(PaperTheme.line.opacity(0.26))
                .frame(width: 1, height: 26)

            Menu {
                ForEach(PracticeMode.allCases) { mode in
                    Button {
                        selection = mode
                    } label: {
                        if mode == selection {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            } label: {
                Text(selection.rawValue)
                    .font(AppFont.font(size: 15, weight: .semibold))
                    .foregroundStyle(PaperTheme.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.leading, 6)
                    .padding(.trailing, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
        }
        .frame(width: width, height: 38)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(PaperTheme.sheet.opacity(0.92))
                .shadow(color: .black.opacity(0.045), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PaperTheme.line.opacity(0.45), lineWidth: 1.15)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusTag: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(AppFont.font(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct IconOnlyButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color.opacity(configuration.isPressed ? 0.55 : 1))
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
    }
}
