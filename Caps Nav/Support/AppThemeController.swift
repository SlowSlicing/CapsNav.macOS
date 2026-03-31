import AppKit
import Foundation

@MainActor
final class AppThemeController {
    func apply(_ themePreference: AppThemePreference) {
        let appearance = nsAppearance(for: themePreference)

        NSApplication.shared.appearance = appearance
        NSApplication.shared.windows.forEach { window in
            window.appearance = appearance
        }
    }

    private func nsAppearance(for themePreference: AppThemePreference) -> NSAppearance? {
        switch themePreference {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}
