import Carbon.HIToolbox
import CoreGraphics
import Foundation
import IOKit.hid
import IOKit.hidsystem
import OSLog

enum PrefixRoutingMode: String, Equatable {
    case inactive
    case remappedF18
    case rawCapsFallback

    var displayName: String {
        switch self {
        case .inactive:
            return "未启用"
        case .remappedF18:
            return "Caps Lock 前缀键"
        case .rawCapsFallback:
            return "Caps Lock 前缀键（兼容模式）"
        }
    }

    var overlaySubtitle: String {
        switch self {
        case .inactive:
            return "前缀监听未启用"
        case .remappedF18:
            return "前缀键：Caps Lock"
        case .rawCapsFallback:
            return "前缀键：Caps Lock（兼容模式）"
        }
    }

    var prefixKeyCode: CGKeyCode? {
        switch self {
        case .inactive:
            return nil
        case .remappedF18:
            return CGKeyCode(kVK_F18)
        case .rawCapsFallback:
            return CGKeyCode(kVK_CapsLock)
        }
    }
}

final class PrefixKeyRouter {
    private static let usagePagePrefix: UInt64 = 0x700000000
    private static let capsUsage = usagePagePrefix | UInt64(kHIDUsage_KeyboardCapsLock)
    private static let f18Usage = usagePagePrefix | UInt64(kHIDUsage_KeyboardF18)

    private let logger = AppLogger.make(category: "PrefixKeyRouter")
    private let stateStore: PrefixRoutingStateStore

    private var originalMappings: [HIDUserKeyMapping] = []
    private var isRemappingApplied = false

    init(stateStore: PrefixRoutingStateStore) {
        self.stateStore = stateStore
    }

    func activatePreferredRouting() -> PrefixRoutingMode {
        if isRemappingApplied {
            return .remappedF18
        }

        let observedMappings = normalizedMappings(from: currentMappingsProperty())
        let currentMappings = PrefixRoutingMappingSanitizer.sanitizeRestorableOriginalMappings(
            observedMappings,
            hasPersistedSnapshot: stateStore.hasSnapshot
        )
        let updatedMappings = upsertingCapsToF18Mapping(into: currentMappings)

        if currentMappings != observedMappings,
           PrefixRoutingMappingSanitizer.containsAppInjectedCapsToF18Mapping(observedMappings) {
            logger.warning("Detected stale Caps routing residue before activation. The stale Caps -> F18 mapping will not be treated as the original system state.")
        }

        guard applyMappings(updatedMappings) else {
            logger.error("Failed to apply Caps -> F18 remapping. Falling back to raw Caps handling.")
            return .rawCapsFallback
        }

        originalMappings = currentMappings
        isRemappingApplied = true
        persistOriginalMappingsIfNeeded()

        logger.info("Activated Caps -> F18 runtime remapping.")
        return .remappedF18
    }

    func deactivateRouting() {
        guard isRemappingApplied else {
            return
        }

        if applyMappings(originalMappings) {
            logger.info("Restored previous UserKeyMapping state.")
            clearPersistedStateIfNeeded()
        } else {
            logger.error("Failed to restore previous UserKeyMapping state.")
        }

        originalMappings = []
        isRemappingApplied = false
    }

    deinit {
        deactivateRouting()
    }

    func recoverPersistedRoutingIfNeeded() {
        if let mappingsToRestore = try? stateStore.loadOriginalMappings(),
           !mappingsToRestore.isEmpty || stateStore.hasSnapshot {
            guard applyMappings(mappingsToRestore) else {
                logger.error("Failed to recover persisted Caps routing state on launch.")
                return
            }

            clearPersistedStateIfNeeded()
            logger.info("Recovered persisted Caps routing state on launch.")
            return
        }

        let observedMappings = normalizedMappings(from: currentMappingsProperty())

        guard let repairedMappings = PrefixRoutingMappingSanitizer.startupRepairTargetMappings(
            observedMappings: observedMappings,
            hasPersistedSnapshot: stateStore.hasSnapshot
        ) else {
            return
        }

        guard applyMappings(repairedMappings) else {
            logger.error("Failed to repair stale Caps routing residue on launch.")
            return
        }

        logger.warning("Repaired stale Caps routing residue on launch.")
    }

    private func normalizedMappings(from property: AnyObject?) -> [HIDUserKeyMapping] {
        (property as? [HIDUserKeyMapping]) ?? []
    }

    private func currentMappingsProperty() -> AnyObject? {
        let propertyKey = kIOHIDUserKeyUsageMapKey as NSString
        let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
        return IOHIDEventSystemClientCopyProperty(client, propertyKey)
    }

    private func upsertingCapsToF18Mapping(into mappings: [HIDUserKeyMapping]) -> [HIDUserKeyMapping] {
        let filteredMappings = mappings.filter { mapping in
            mapping[kIOHIDKeyboardModifierMappingSrcKey]?.uint64Value != Self.capsUsage
        }

        let capsMapping: HIDUserKeyMapping = [
            kIOHIDKeyboardModifierMappingSrcKey: NSNumber(value: Self.capsUsage),
            kIOHIDKeyboardModifierMappingDstKey: NSNumber(value: Self.f18Usage)
        ]

        return filteredMappings + [capsMapping]
    }

    private func applyMappings(_ mappings: [HIDUserKeyMapping]) -> Bool {
        if applyMappingsUsingIOHIDClient(mappings) {
            return true
        }

        return applyMappingsUsingHIDUtil(mappings)
    }

    private func applyMappingsUsingIOHIDClient(_ mappings: [HIDUserKeyMapping]) -> Bool {
        let propertyKey = kIOHIDUserKeyUsageMapKey as NSString
        let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)

        guard IOHIDEventSystemClientSetProperty(client, propertyKey, mappings as CFArray) else {
            logger.error("IOHIDEventSystemClientSetProperty failed for UserKeyMapping update.")
            return false
        }

        return true
    }

    private func applyMappingsUsingHIDUtil(_ mappings: [HIDUserKeyMapping]) -> Bool {
        let payloadMappings = mappings.compactMap { mapping -> [String: UInt64]? in
            guard let srcKey = mapping[kIOHIDKeyboardModifierMappingSrcKey]?.uint64Value,
                  let dstKey = mapping[kIOHIDKeyboardModifierMappingDstKey]?.uint64Value else {
                return nil
            }

            return [
                "HIDKeyboardModifierMappingSrc": srcKey,
                "HIDKeyboardModifierMappingDst": dstKey
            ]
        }

        guard let payloadData = try? JSONSerialization.data(
            withJSONObject: ["UserKeyMapping": payloadMappings],
            options: []
        ),
        let payload = String(data: payloadData, encoding: .utf8) else {
            logger.error("Failed to encode hidutil UserKeyMapping payload.")
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", payload]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.error("Failed to launch hidutil for UserKeyMapping update: \(error.localizedDescription, privacy: .public)")
            return false
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? ""
            logger.error("hidutil UserKeyMapping update failed: \(errorMessage, privacy: .public)")
            return false
        }

        logger.info("Updated UserKeyMapping via hidutil fallback.")
        return true
    }

    private func persistOriginalMappingsIfNeeded() {
        do {
            try stateStore.save(originalMappings: originalMappings)
        } catch {
            logger.error("Failed to persist original UserKeyMapping state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearPersistedStateIfNeeded() {
        do {
            try stateStore.clear()
        } catch {
            logger.error("Failed to clear persisted UserKeyMapping state: \(error.localizedDescription, privacy: .public)")
        }
    }
}
