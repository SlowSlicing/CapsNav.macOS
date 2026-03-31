import Carbon.HIToolbox
import CoreGraphics
import Foundation
import IOKit
import IOKit.hidsystem
import OSLog

final class CapsLockToggleController {
    private let logger = AppLogger.make(category: "CapsLockToggle")

    @discardableResult
    func toggleCapsLock() -> Bool {
        if toggleUsingIOHIDSystemLockState() {
            return true
        }

        if toggleUsingSyntheticCapsKeyEvent() {
            return true
        }

        logger.error("Failed to restore default Caps Lock behavior.")
        return false
    }

    private func toggleUsingIOHIDSystemLockState() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != IO_OBJECT_NULL else {
            logger.error("Unable to locate IOHIDSystem service.")
            return false
        }

        defer {
            IOObjectRelease(service)
        }

        var connection: io_connect_t = IO_OBJECT_NULL
        let openResult = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection)

        guard openResult == KERN_SUCCESS else {
            logger.error("IOServiceOpen for IOHIDSystem failed: \(openResult, privacy: .public)")
            return false
        }

        defer {
            IOServiceClose(connection)
        }

        var currentState = false
        let getResult = IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &currentState)

        guard getResult == KERN_SUCCESS else {
            logger.error("IOHIDGetModifierLockState failed: \(getResult, privacy: .public)")
            return false
        }

        let nextState = !currentState
        let setResult = IOHIDSetModifierLockState(connection, Int32(kIOHIDCapsLockState), nextState)

        guard setResult == KERN_SUCCESS else {
            logger.error("IOHIDSetModifierLockState failed: \(setResult, privacy: .public)")
            return false
        }

        logger.info("Restored Caps Lock using IOHIDSystem. newState=\(nextState, privacy: .public)")
        return true
    }

    private func toggleUsingSyntheticCapsKeyEvent() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_CapsLock), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_CapsLock), keyDown: false) else {
            logger.error("Failed to create synthetic Caps Lock events.")
            return false
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        logger.info("Restored Caps Lock using synthetic key events.")
        return true
    }
}
