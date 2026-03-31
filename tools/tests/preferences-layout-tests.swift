import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

private func loadPreferencesSource() throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let sourceURL = rootURL.appendingPathComponent("Caps Nav/Features/Preferences/PreferencesRootView.swift")
    return try String(contentsOf: sourceURL, encoding: .utf8)
}

private func testOverviewUsesAlignedToggleRow() throws {
    let source = try loadPreferencesSource()

    guard let overviewStart = source.range(of: "private var overviewPage: some View {"),
          let overviewEnd = source.range(of: "private var keyboardPage: some View {") else {
        fputs("Assertion failed: 找不到概览页源码范围\n", stderr)
        exit(1)
    }

    let overviewSection = String(source[overviewStart.lowerBound..<overviewEnd.lowerBound])

    expect(
        overviewSection.contains("SettingsToggleRow("),
        "概览页中的运行总开关应使用统一的左标题右控件行组件"
    )
    expect(
        !overviewSection.contains("Toggle("),
        "概览页中的运行总开关不应继续直接使用原生 Toggle(label:) 布局"
    )
}

@main
enum PreferencesLayoutTestsMain {
    static func main() throws {
        try testOverviewUsesAlignedToggleRow()
        print("Preferences layout tests passed")
    }
}
