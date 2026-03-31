import CoreGraphics
import Foundation
import OSLog

struct KeyStroke {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    let description: String
}

final class ActionResolver {
    private let logger = AppLogger.make(category: "ActionResolver")

    func resolve(output: Output) -> KeyStroke? {
        let keyStroke: KeyStroke?

        switch output {
        case let .builtin(action):
            keyStroke = action.defaultKeyStroke
        case let .shortcut(shortcut):
            keyStroke = shortcut.toKeyStroke()
        }

        if let keyStroke {
            logger.debug("Resolved output to \(keyStroke.description, privacy: .public)")
        } else {
            logger.error("Failed to resolve output \(output.debugDescription, privacy: .public)")
        }

        return keyStroke
    }
}

private extension BuiltinAction {
    var defaultKeyStroke: KeyStroke {
        switch self {
        case .moveLeft:
            return KeyStroke(keyCode: 123, flags: [], description: "Left Arrow")
        case .moveRight:
            return KeyStroke(keyCode: 124, flags: [], description: "Right Arrow")
        case .moveUp:
            return KeyStroke(keyCode: 126, flags: [], description: "Up Arrow")
        case .moveDown:
            return KeyStroke(keyCode: 125, flags: [], description: "Down Arrow")
        case .selectLeft:
            return KeyStroke(keyCode: 123, flags: [.maskShift], description: "Shift + Left Arrow")
        case .selectRight:
            return KeyStroke(keyCode: 124, flags: [.maskShift], description: "Shift + Right Arrow")
        case .selectUp:
            return KeyStroke(keyCode: 126, flags: [.maskShift], description: "Shift + Up Arrow")
        case .selectDown:
            return KeyStroke(keyCode: 125, flags: [.maskShift], description: "Shift + Down Arrow")
        case .moveWordLeft:
            return KeyStroke(keyCode: 123, flags: [.maskAlternate], description: "Option + Left Arrow")
        case .moveWordRight:
            return KeyStroke(keyCode: 124, flags: [.maskAlternate], description: "Option + Right Arrow")
        case .selectWordLeft:
            return KeyStroke(keyCode: 123, flags: [.maskShift, .maskAlternate], description: "Shift + Option + Left Arrow")
        case .selectWordRight:
            return KeyStroke(keyCode: 124, flags: [.maskShift, .maskAlternate], description: "Shift + Option + Right Arrow")
        case .moveToLineStart:
            return KeyStroke(keyCode: 123, flags: [.maskCommand], description: "Command + Left Arrow")
        case .moveToLineEnd:
            return KeyStroke(keyCode: 124, flags: [.maskCommand], description: "Command + Right Arrow")
        case .selectToLineStart:
            return KeyStroke(keyCode: 123, flags: [.maskShift, .maskCommand], description: "Shift + Command + Left Arrow")
        case .selectToLineEnd:
            return KeyStroke(keyCode: 124, flags: [.maskShift, .maskCommand], description: "Shift + Command + Right Arrow")
        case .deleteBackward:
            return KeyStroke(keyCode: 51, flags: [], description: "Delete")
        case .deleteForward:
            return KeyStroke(keyCode: 117, flags: [], description: "Forward Delete")
        case .deleteWordBackward:
            return KeyStroke(keyCode: 51, flags: [.maskAlternate], description: "Option + Delete")
        case .deleteWordForward:
            return KeyStroke(keyCode: 117, flags: [.maskAlternate], description: "Option + Forward Delete")
        }
    }
}

private extension Shortcut {
    func toKeyStroke() -> KeyStroke? {
        guard let keyCode = ShortcutKeyCodeMap.cgKeyCode(for: key) else {
            return nil
        }

        return KeyStroke(
            keyCode: keyCode,
            flags: modifiers.cgEventFlags,
            description: debugDescription
        )
    }
}
