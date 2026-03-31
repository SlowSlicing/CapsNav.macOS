import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

private func testLegacySettingsDecodeDefaults() throws {
    let legacyJSON = """
    {
      "activeProfileId": "default",
      "profileOrderIds": [],
      "themePreference": "system",
      "launchAtLogin": false,
      "showMenuBarIcon": true,
      "menuBarIconStyle": "defaultKeyboard",
      "showPrefixIndicatorOverlay": true,
      "prefixIndicatorPlacement": "top",
      "capsTapToggleThresholdMilliseconds": 200
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder.capsNav().decode(AppSettings.self, from: legacyJSON)
    expect(settings.isAppEnabled == true, "旧 settings.json 升级后，总开关默认应保持启用")
    expect(settings.toggleAppShortcut == nil, "旧 settings.json 升级后，全局开关快捷键默认应为空")
}

private func testDefaultSettingsContainNewFields() throws {
    let data = try JSONEncoder.capsNav().encode(AppSettings.default)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    expect(object?["isAppEnabled"] as? Bool == true, "默认设置编码后应包含 isAppEnabled=true")
    expect(object?.keys.contains("toggleAppShortcut") == true, "默认设置编码后应包含 toggleAppShortcut 键")
}

private func testOperationalStateResolution() {
    let enabled = AppOperationalState.resolve(isAppEnabled: true, accessibilityStatus: .trusted)
    let paused = AppOperationalState.resolve(isAppEnabled: false, accessibilityStatus: .trusted)
    let permissionRequired = AppOperationalState.resolve(isAppEnabled: true, accessibilityStatus: .notTrusted)

    expect(enabled == .enabled, "已启用且已授权时应为 enabled")
    expect(paused == .paused, "手动关闭时应为 paused")
    expect(permissionRequired == .permissionRequired, "已启用但未授权时应为 permissionRequired")
    expect(enabled.menuActionTitle == "暂停 Caps Nav", "运行中状态的菜单操作应为暂停")
    expect(paused.menuActionTitle == "启用 Caps Nav", "暂停状态的菜单操作应为启用")
    expect(permissionRequired.displayName == "等待授权", "未授权状态的显示文案应明确说明等待授权")
}

private func testGlobalToggleShortcutRules() {
    expect(
        GlobalToggleShortcutRules.validate(nil) == .valid,
        "全局开关快捷键允许为空"
    )
    expect(
        GlobalToggleShortcutRules.validate(Shortcut(key: "k", modifiers: [])) == .missingModifier,
        "全局开关快捷键必须带修饰键"
    )
    expect(
        GlobalToggleShortcutRules.validate(Shortcut(key: "k", modifiers: [.command])) == .valid,
        "带修饰键的快捷键应允许保存"
    )
}

@main
enum AppOperationalStateTestsMain {
    static func main() throws {
        try testLegacySettingsDecodeDefaults()
        try testDefaultSettingsContainNewFields()
        testOperationalStateResolution()
        testGlobalToggleShortcutRules()
        print("App operational state tests passed")
    }
}
