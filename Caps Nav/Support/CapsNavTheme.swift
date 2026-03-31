import AppKit
import SwiftUI

enum CapsNavTheme {
    static let windowTop = Color.capsNav(light: 0xF7FAFD, dark: 0x0B1220)
    static let windowBottom = Color.capsNav(light: 0xEEF4FA, dark: 0x111B2E)
    static let glowPrimary = Color.capsNav(light: 0xCFF3FF, dark: 0x0D3550, alphaLight: 0.95, alphaDark: 0.9)
    static let glowSecondary = Color.capsNav(light: 0xFFEFC7, dark: 0x452A0A, alphaLight: 0.9, alphaDark: 0.7)

    static let surfacePrimarySolid = Color.capsNav(light: 0xFFFFFF, dark: 0x152033)
    static let surfacePrimary = Color.capsNav(light: 0xFFFFFF, dark: 0x152033, alphaLight: 0.82, alphaDark: 0.9)
    static let surfaceSecondary = Color.capsNav(light: 0xF4F8FC, dark: 0x1A2740, alphaLight: 0.9, alphaDark: 0.95)
    static let surfaceTertiary = Color.capsNav(light: 0xEAF1F8, dark: 0x22314C, alphaLight: 0.95, alphaDark: 0.98)

    static let borderSoft = Color.capsNav(light: 0xD6E1EE, dark: 0x2A3B58)
    static let borderStrong = Color.capsNav(light: 0xB6C7DB, dark: 0x3B567B)

    static let textPrimary = Color.capsNav(light: 0x102033, dark: 0xF2F7FB)
    static let textSecondary = Color.capsNav(light: 0x587089, dark: 0xA8BED3)
    static let textMuted = Color.capsNav(light: 0x7D90A4, dark: 0x6B8098)

    static let accent = Color.capsNav(light: 0x0891B2, dark: 0x22D3EE)
    static let accentStrong = Color.capsNav(light: 0x0E7490, dark: 0x67E8F9)
    static let accentSoft = Color.capsNav(light: 0xDFF8FF, dark: 0x113049)
    static let accentSurface = Color.capsNav(light: 0xF0FBFF, dark: 0x142A3F)

    static let success = Color.capsNav(light: 0x0F9F6E, dark: 0x34D399)
    static let warning = Color.capsNav(light: 0xD97706, dark: 0xFBBF24)
    static let danger = Color.capsNav(light: 0xDC2626, dark: 0xF87171)

    static let cardShadow = Color.black.opacity(0.08)
}

extension Color {
    static func capsNav(
        light: UInt32,
        dark: UInt32,
        alphaLight: Double = 1,
        alphaDark: Double = 1
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return NSColor(
                    hex: isDark ? dark : light,
                    alpha: isDark ? alphaDark : alphaLight
                )
            }
        )
    }
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: Double = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255

        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
