import CoreGraphics
import Foundation
import OSLog

final class EventEmitter {
    private let logger = AppLogger.make(category: "EventEmitter")

    func emit(_ keyStroke: KeyStroke) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyStroke.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyStroke.keyCode, keyDown: false) else {
            logger.error("Failed to create synthetic keyboard events.")
            return
        }

        keyDown.flags = keyStroke.flags
        keyUp.flags = keyStroke.flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        logger.debug("Posted synthetic key stroke: \(keyStroke.description, privacy: .public)")
    }
}
