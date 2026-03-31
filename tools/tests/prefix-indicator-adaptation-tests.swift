import Foundation
import CoreGraphics

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

private func testDefaultOverlaySettings() {
    expect(AppSettings.default.prefixIndicatorPlacement == .right, "悬浮帮助框默认位置应改为右侧")
    expect(AppSettings.default.prefixIndicatorOpacityPercent == 82, "悬浮帮助框默认透明度应为 82%")
}

private func testOverlayOpacityDecodingFallback() throws {
    let legacyJSON = """
    {
      "activeProfileId": "default",
      "profileOrderIds": [],
      "isAppEnabled": true,
      "toggleAppShortcut": null,
      "themePreference": "system",
      "launchAtLogin": false,
      "showMenuBarIcon": true,
      "menuBarIconStyle": "defaultKeyboard",
      "showPrefixIndicatorOverlay": true,
      "prefixIndicatorPlacement": "right",
      "capsTapToggleThresholdMilliseconds": 200
    }
    """.data(using: .utf8)!

    let legacySettings = try JSONDecoder.capsNav().decode(AppSettings.self, from: legacyJSON)
    expect(legacySettings.prefixIndicatorOpacityPercent == 82, "旧 settings.json 缺少透明度字段时应回退到新默认值")

    let encoded = try JSONEncoder.capsNav().encode(AppSettings.default)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    expect(object?["prefixIndicatorOpacityPercent"] as? Int == 82, "默认设置编码后应包含 prefixIndicatorOpacityPercent=82")
}

private func testResponsiveOverlayLayoutRules() {
    let topLayout = PrefixIndicatorLayoutCalculator.layout(
        visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        placement: .top,
        isActive: true,
        helpEntryCount: 8
    )
    expect(topLayout.columnCount == 2, "顶部悬浮框在常规屏幕下应保持双列")
    expect(topLayout.panelWidth <= 640, "顶部悬浮框默认宽度应明显收窄")

    let sideLayout = PrefixIndicatorLayoutCalculator.layout(
        visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 800),
        placement: .right,
        isActive: true,
        helpEntryCount: 10
    )
    expect(sideLayout.columnCount == 2, "左右侧悬浮框也应保持双列")
    expect(sideLayout.showsScrollableHelpList == false, "侧边悬浮框不应依赖内部滚动")
    expect(sideLayout.panelWidth >= 520, "侧边悬浮框应通过增宽来容纳双列内容")
    expect(sideLayout.panelHeight <= 720, "侧边悬浮框仍应限制高度，避免超出小屏幕")

    let smallScreenTopLayout = PrefixIndicatorLayoutCalculator.layout(
        visibleFrame: CGRect(x: 0, y: 0, width: 960, height: 600),
        placement: .top,
        isActive: true,
        helpEntryCount: 8
    )
    expect(smallScreenTopLayout.columnCount == 1, "窄屏顶部悬浮框应自动降为单列")
    expect(smallScreenTopLayout.panelWidth <= 520, "窄屏顶部悬浮框应继续收窄")
}

private func testOverlayOpacityClampRange() {
    let low = AppSettings.default.withPrefixIndicatorOpacityPercent(5)
    let high = AppSettings.default.withPrefixIndicatorOpacityPercent(130)

    expect(low.prefixIndicatorOpacityPercent == 20, "悬浮帮助框透明度最低应支持到 20%")
    expect(high.prefixIndicatorOpacityPercent == 100, "悬浮帮助框透明度最高应支持到 100%")
}

@main
enum PrefixIndicatorAdaptationTestsMain {
    static func main() throws {
        testDefaultOverlaySettings()
        try testOverlayOpacityDecodingFallback()
        testResponsiveOverlayLayoutRules()
        testOverlayOpacityClampRange()
        print("Prefix indicator adaptation tests passed")
    }
}
