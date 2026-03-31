import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum ShortcutKeyCodeMap {
    private static let keyCodes: [String: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20,
        "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29, "]": 30,
        "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41,
        "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
        "delete": 51, "return": 36, "escape": 53, "forwardDelete": 117,
        "left": 123, "right": 124, "down": 125, "up": 126
    ]

    static func cgKeyCode(for key: String) -> CGKeyCode? {
        guard let keyCode = keyCodes[key] else {
            return nil
        }

        return CGKeyCode(keyCode)
    }

    static func carbonKeyCode(for key: String) -> UInt32? {
        guard let keyCode = keyCodes[key] else {
            return nil
        }

        return UInt32(keyCode)
    }
}

extension Array where Element == ModifierKey {
    var cgEventFlags: CGEventFlags {
        reduce(into: CGEventFlags()) { flags, modifier in
            switch modifier {
            case .shift:
                flags.insert(.maskShift)
            case .control:
                flags.insert(.maskControl)
            case .option:
                flags.insert(.maskAlternate)
            case .command:
                flags.insert(.maskCommand)
            }
        }
    }

    var carbonHotKeyModifiers: UInt32 {
        reduce(into: UInt32(0)) { modifiers, modifier in
            switch modifier {
            case .shift:
                modifiers |= UInt32(shiftKey)
            case .control:
                modifiers |= UInt32(controlKey)
            case .option:
                modifiers |= UInt32(optionKey)
            case .command:
                modifiers |= UInt32(cmdKey)
            }
        }
    }
}
