import Foundation
import IOKit.hid

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

private func makeMapping(src: UInt64, dst: UInt64) -> HIDUserKeyMapping {
    [
        kIOHIDKeyboardModifierMappingSrcKey: NSNumber(value: src),
        kIOHIDKeyboardModifierMappingDstKey: NSNumber(value: dst)
    ]
}

@MainActor
private func runPrefixRoutingMappingSanitizerTests() {
    let usagePagePrefix: UInt64 = 0x700000000
    let capsUsage = usagePagePrefix | UInt64(kHIDUsage_KeyboardCapsLock)
    let f18Usage = usagePagePrefix | UInt64(kHIDUsage_KeyboardF18)
    let escapeUsage = usagePagePrefix | UInt64(kHIDUsage_KeyboardEscape)

    let staleCapsMapping = makeMapping(src: capsUsage, dst: f18Usage)
    let unrelatedMapping = makeMapping(src: escapeUsage, dst: f18Usage)
    let mappings = [staleCapsMapping, unrelatedMapping]

    let sanitized = PrefixRoutingMappingSanitizer.sanitizeRestorableOriginalMappings(
        mappings,
        hasPersistedSnapshot: false
    )
    expect(sanitized.count == 1, "无快照时应剔除残留的 Caps -> F18 映射")
    expect(
        PrefixRoutingMappingSanitizer.containsAppInjectedCapsToF18Mapping(sanitized) == false,
        "剔除后不应再包含 Caps -> F18 残留映射"
    )
    expect(
        sanitized.first?[kIOHIDKeyboardModifierMappingSrcKey]?.uint64Value == escapeUsage,
        "不相关映射应被保留"
    )

    let preserved = PrefixRoutingMappingSanitizer.sanitizeRestorableOriginalMappings(
        mappings,
        hasPersistedSnapshot: true
    )
    expect(preserved.count == 2, "有快照时不应擅自篡改原始映射")
    expect(
        PrefixRoutingMappingSanitizer.containsAppInjectedCapsToF18Mapping(preserved),
        "有快照时应保留原始映射，交给快照恢复链路处理"
    )

    let startupRepairTarget = PrefixRoutingMappingSanitizer.startupRepairTargetMappings(
        observedMappings: mappings,
        hasPersistedSnapshot: false
    )
    expect(startupRepairTarget?.count == 1, "启动自愈时应返回需要恢复到的安全映射集")
    expect(
        startupRepairTarget?.first?[kIOHIDKeyboardModifierMappingSrcKey]?.uint64Value == escapeUsage,
        "启动自愈不应误删无关映射"
    )

    let startupRepairTargetWithSnapshot = PrefixRoutingMappingSanitizer.startupRepairTargetMappings(
        observedMappings: mappings,
        hasPersistedSnapshot: true
    )
    expect(startupRepairTargetWithSnapshot == nil, "有快照时不应走残留映射自愈分支")

    let startupRepairTargetWithoutResidue = PrefixRoutingMappingSanitizer.startupRepairTargetMappings(
        observedMappings: [unrelatedMapping],
        hasPersistedSnapshot: false
    )
    expect(startupRepairTargetWithoutResidue == nil, "没有残留映射时不应做启动自愈")

    print("PrefixRoutingMappingSanitizer tests passed")
}

@main
enum PrefixRoutingMappingSanitizerTestsMain {
    @MainActor
    static func main() {
        runPrefixRoutingMappingSanitizerTests()
    }
}
