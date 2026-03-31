import Carbon.HIToolbox
import Foundation
import OSLog

struct GlobalToggleHotKeyDescriptor: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    init?(shortcut: Shortcut) {
        guard let keyCode = ShortcutKeyCodeMap.carbonKeyCode(for: shortcut.key) else {
            return nil
        }

        self.keyCode = keyCode
        self.modifiers = shortcut.modifiers.carbonHotKeyModifiers
    }
}

enum GlobalToggleHotKeyRegistrationStatus: Equatable {
    case unconfigured
    case registered(Shortcut)
    case invalidShortcut
    case registrationFailed

    var displayName: String {
        switch self {
        case .unconfigured:
            return "未设置"
        case let .registered(shortcut):
            return shortcut.userFacingDescription
        case .invalidShortcut:
            return "快捷键无效"
        case .registrationFailed:
            return "注册失败"
        }
    }
}

final class GlobalToggleHotKeyManager {
    var onTriggered: (() -> Void)?

    private let logger = AppLogger.make(category: "GlobalToggleHotKey")
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyID = EventHotKeyID(signature: 0x434E5447, id: 1) // CNTG

    init() {
        installEventHandlerIfNeeded()
    }

    deinit {
        unregister()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func update(shortcut: Shortcut?) -> GlobalToggleHotKeyRegistrationStatus {
        unregister()

        guard let shortcut else {
            return .unconfigured
        }

        guard GlobalToggleShortcutRules.validate(shortcut) == .valid,
              let descriptor = GlobalToggleHotKeyDescriptor(shortcut: shortcut) else {
            return .invalidShortcut
        }

        var hotKeyRef: EventHotKeyRef?
        let result = RegisterEventHotKey(
            descriptor.keyCode,
            descriptor.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard result == noErr, let hotKeyRef else {
            logger.error("Failed to register global toggle hotkey. status=\(result, privacy: .public)")
            return .registrationFailed
        }

        self.hotKeyRef = hotKeyRef
        logger.info("Registered global toggle hotkey: \(shortcut.userFacingDescription, privacy: .public)")
        return .registered(shortcut)
    }

    private func unregister() {
        guard let hotKeyRef else {
            return
        }

        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        if status != noErr {
            logger.error("Failed to install global hotkey event handler. status=\(status, privacy: .public)")
        }
    }

    private func handleEvent(_ event: EventRef?) -> OSStatus {
        var eventHotKeyID = EventHotKeyID()
        let result = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &eventHotKeyID
        )

        guard result == noErr else {
            return result
        }

        guard eventHotKeyID.signature == hotKeyID.signature,
              eventHotKeyID.id == hotKeyID.id else {
            return OSStatus(eventNotHandledErr)
        }

        DispatchQueue.main.async { [weak self] in
            self?.onTriggered?()
        }

        return noErr
    }

    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard let userData else {
            return OSStatus(eventNotHandledErr)
        }

        let manager = Unmanaged<GlobalToggleHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        return manager.handleEvent(event)
    }
}
