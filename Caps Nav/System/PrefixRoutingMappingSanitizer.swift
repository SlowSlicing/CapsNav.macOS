import Foundation
import IOKit.hid

enum PrefixRoutingMappingSanitizer {
    private static let usagePagePrefix: UInt64 = 0x700000000
    private static let capsUsage = usagePagePrefix | UInt64(kHIDUsage_KeyboardCapsLock)
    private static let f18Usage = usagePagePrefix | UInt64(kHIDUsage_KeyboardF18)

    static func sanitizeRestorableOriginalMappings(
        _ currentMappings: [HIDUserKeyMapping],
        hasPersistedSnapshot: Bool
    ) -> [HIDUserKeyMapping] {
        guard !hasPersistedSnapshot else {
            return currentMappings
        }

        return currentMappings.filter { !isAppInjectedCapsToF18Mapping($0) }
    }

    static func containsAppInjectedCapsToF18Mapping(_ mappings: [HIDUserKeyMapping]) -> Bool {
        mappings.contains(where: isAppInjectedCapsToF18Mapping)
    }

    static func startupRepairTargetMappings(
        observedMappings: [HIDUserKeyMapping],
        hasPersistedSnapshot: Bool
    ) -> [HIDUserKeyMapping]? {
        guard !hasPersistedSnapshot,
              containsAppInjectedCapsToF18Mapping(observedMappings) else {
            return nil
        }

        let sanitizedMappings = sanitizeRestorableOriginalMappings(
            observedMappings,
            hasPersistedSnapshot: false
        )

        return sanitizedMappings == observedMappings ? nil : sanitizedMappings
    }

    private static func isAppInjectedCapsToF18Mapping(_ mapping: HIDUserKeyMapping) -> Bool {
        mapping[kIOHIDKeyboardModifierMappingSrcKey]?.uint64Value == capsUsage &&
            mapping[kIOHIDKeyboardModifierMappingDstKey]?.uint64Value == f18Usage
    }
}
