import Foundation

enum GlobalToggleShortcutValidationResult: Equatable {
    case valid
    case missingModifier
}

enum GlobalToggleShortcutRules {
    static func validate(_ shortcut: Shortcut?) -> GlobalToggleShortcutValidationResult {
        guard let shortcut else {
            return .valid
        }

        return shortcut.modifiers.isEmpty ? .missingModifier : .valid
    }
}
