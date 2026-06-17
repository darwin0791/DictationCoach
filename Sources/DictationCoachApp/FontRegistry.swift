import CoreText
import Foundation
import SwiftUI

enum AppFont {
    static let postScriptName = "UKaiCN"

    static func register() {
        guard let url = Bundle.module.url(forResource: "ukai", withExtension: "ttc") else {
            return
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(postScriptName, size: size).weight(weight)
    }
}
