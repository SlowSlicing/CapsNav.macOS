import CoreGraphics
import Foundation
import OSLog

final class KeyEventInterceptor {
    var activeProfileProvider: (() -> Profile?)?
    var isEnabledProvider: (() -> Bool)?
    var prefixRoutingModeProvider: (() -> PrefixRoutingMode)?
    var capsTapThresholdMillisecondsProvider: (() -> Int)?
    var onResolvedAction: ((String) -> Void)?
    var onShortTapDetected: (() -> Void)?
    var onHighlightedTriggerChanged: ((String?) -> Void)?
    var onTriggerRecorded: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let permissionManager: PermissionManager
    private let prefixStateManager: PrefixStateManager
    private let actionResolver: ActionResolver
    private let eventEmitter: EventEmitter
    private let logger = AppLogger.make(category: "KeyEventInterceptor")

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        permissionManager: PermissionManager,
        prefixStateManager: PrefixStateManager,
        actionResolver: ActionResolver,
        eventEmitter: EventEmitter
    ) {
        self.permissionManager = permissionManager
        self.prefixStateManager = prefixStateManager
        self.actionResolver = actionResolver
        self.eventEmitter = eventEmitter
    }

    deinit {
        stop()
    }

    func start() {
        guard eventTap == nil else {
            return
        }

        guard permissionManager.refreshStatus() == .trusted else {
            logger.info("Skipped starting event tap because Accessibility permission is missing.")
            onHighlightedTriggerChanged?(nil)
            return
        }

        let eventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            let message = "无法创建全局键盘事件 tap，请检查辅助功能权限，且确认 App Sandbox 已关闭。"
            logger.error("\(message, privacy: .public)")
            onError?(message)
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        logger.info("Global key event tap started.")
    }

    func stop() {
        onHighlightedTriggerChanged?(nil)
        prefixStateManager.reset()

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            return handleFlagsChanged(event)

        case .keyDown:
            return handleKeyDown(event)

        case .keyUp:
            return handleKeyUp(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabledProvider?() ?? true else {
            return Unmanaged.passUnretained(event)
        }

        if prefixRoutingModeProvider?() == .remappedF18,
           prefixStateManager.isPrefixActive,
           let remappedPrefixKeyCode = PrefixRoutingMode.remappedF18.prefixKeyCode,
           event.keyCode != remappedPrefixKeyCode {
            prefixStateManager.noteInteractionDuringCurrentPress(source: "flags-changed-\(event.keyCode)")
        }

        guard prefixRoutingModeProvider?() == .rawCapsFallback,
              let prefixKeyCode = PrefixRoutingMode.rawCapsFallback.prefixKeyCode,
              event.keyCode == prefixKeyCode else {
            return Unmanaged.passUnretained(event)
        }

        prefixStateManager.handleRawCapsFlagsChangedFallback()
        return nil
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabledProvider?() ?? true else {
            return Unmanaged.passUnretained(event)
        }

        if isPrefixKeyDown(event) {
            prefixStateManager.handlePrefixKeyDown()
            return nil
        }

        if prefixStateManager.isPrefixActive {
            prefixStateManager.noteInteractionDuringCurrentPress(source: "key-down-\(event.keyCode)")
        }

        guard prefixStateManager.isPrefixActive,
              let profile = activeProfileProvider?(),
              let trigger = Trigger(event: event),
              let output = profile.output(for: trigger),
              let keyStroke = actionResolver.resolve(output: output) else {
            return Unmanaged.passUnretained(event)
        }

        onHighlightedTriggerChanged?(trigger.signature)
        eventEmitter.emit(keyStroke)

        let message = "\(trigger.debugDescription) -> \(keyStroke.description)"
        onResolvedAction?(message)
        onTriggerRecorded?(trigger.signature)
        logger.info("Intercepted trigger: \(message, privacy: .public)")

        return nil
    }

    private func handleKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isEnabledProvider?() ?? true else {
            return Unmanaged.passUnretained(event)
        }

        if isPrefixKeyUp(event) {
            onHighlightedTriggerChanged?(nil)
            let tapThresholdMilliseconds = capsTapThresholdMillisecondsProvider?() ?? AppSettings.default.capsTapToggleThresholdMilliseconds
            let isShortTap = prefixStateManager.handlePrefixKeyUp(tapThresholdMilliseconds: tapThresholdMilliseconds)

            if isShortTap {
                onShortTapDetected?()
            }

            return nil
        }

        guard prefixStateManager.isPrefixActive,
              let profile = activeProfileProvider?(),
              let trigger = Trigger(event: event),
              profile.output(for: trigger) != nil else {
            return Unmanaged.passUnretained(event)
        }

        onHighlightedTriggerChanged?(nil)
        return nil
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let interceptor = Unmanaged<KeyEventInterceptor>.fromOpaque(userInfo).takeUnretainedValue()

        return MainActor.assumeIsolated {
            interceptor.handleEvent(type: type, event: event)
        }
    }

    private func isPrefixKeyDown(_ event: CGEvent) -> Bool {
        guard prefixRoutingModeProvider?() == .remappedF18,
              let prefixKeyCode = PrefixRoutingMode.remappedF18.prefixKeyCode else {
            return false
        }

        return event.keyCode == prefixKeyCode
    }

    private func isPrefixKeyUp(_ event: CGEvent) -> Bool {
        guard prefixRoutingModeProvider?() == .remappedF18,
              let prefixKeyCode = PrefixRoutingMode.remappedF18.prefixKeyCode else {
            return false
        }

        return event.keyCode == prefixKeyCode
    }
}

private extension CGEvent {
    var keyCode: CGKeyCode {
        CGKeyCode(getIntegerValueField(.keyboardEventKeycode))
    }
}

private extension Trigger {
    init?(event: CGEvent) {
        var actualLength = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &actualLength,
            unicodeString: &buffer
        )

        guard actualLength > 0 else {
            return nil
        }

        let text = String(utf16CodeUnits: buffer, count: actualLength)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !text.isEmpty else {
            return nil
        }

        self.init(key: text, modifiers: event.flags.profileModifiers)
    }
}

private extension CGEventFlags {
    var profileModifiers: [ModifierKey] {
        var modifiers: [ModifierKey] = []

        if contains(.maskShift) {
            modifiers.append(.shift)
        }

        if contains(.maskControl) {
            modifiers.append(.control)
        }

        if contains(.maskAlternate) {
            modifiers.append(.option)
        }

        if contains(.maskCommand) {
            modifiers.append(.command)
        }

        return modifiers
    }
}
