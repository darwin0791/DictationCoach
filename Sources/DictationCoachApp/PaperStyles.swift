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
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            PaperTheme.page
            VStack(spacing: 16) {
                ForEach(0..<36, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.035))
                        .frame(height: 1)
                }
            }
            .padding(.top, 44)
        }
        .ignoresSafeArea()
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
