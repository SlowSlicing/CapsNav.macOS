import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

private func loadFile(at relativePath: String) throws -> String {
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let fileURL = rootURL.appendingPathComponent(relativePath)
    return try String(contentsOf: fileURL, encoding: .utf8)
}

private func testDeploymentTargetIsMacOS13() throws {
    let project = try loadFile(at: "Caps Nav.xcodeproj/project.pbxproj")

    expect(
        !project.contains("MACOSX_DEPLOYMENT_TARGET = 14.0;"),
        "工程中不应继续保留 macOS 14.0 作为最低版本"
    )
    expect(
        project.contains("MACOSX_DEPLOYMENT_TARGET = 13.0;"),
        "工程中应明确把最低版本设置为 macOS 13.0"
    )
}

private func testSourceAvoidsMacOS14OnlySwiftUISyntax() throws {
    let preferences = try loadFile(at: "Caps Nav/Features/Preferences/PreferencesRootView.swift")
    let trainer = try loadFile(at: "Caps Nav/Features/Trainer/ShortcutTrainerView.swift")

    let combined = preferences + "\n" + trainer

    expect(
        !combined.contains("onChange(of: appBootstrap.capsTapToggleThresholdMilliseconds) { _, _ in"),
        "不应继续使用双参数 onChange 的新语法"
    )
    expect(
        !combined.contains("onChange(of: isThresholdFieldFocused) { _, isFocused in"),
        "焦点状态监听应改为兼容 macOS 13 的写法"
    )
    expect(
        !combined.contains("onChange(of: selectedPane) { _, newPane in"),
        "页面切换监听应改为兼容 macOS 13 的写法"
    )
    expect(
        !combined.contains("onChange(of: appBootstrap.activeProfileID) { _, _ in"),
        "profile 变更监听应改为兼容 macOS 13 的写法"
    )
    expect(
        !combined.contains("onChange(of: appBootstrap.isPrefixActive) { _, isActive in"),
        "训练窗口前缀状态监听应改为兼容 macOS 13 的写法"
    )
    expect(
        !combined.contains("onChange(of: appBootstrap.highlightedPrefixTriggerSignature) { _, signature in"),
        "训练窗口高亮监听应改为兼容 macOS 13 的写法"
    )
    expect(
        !combined.contains("onChange(of: item?.id) { _, _ in"),
        "预览项切换监听应改为兼容 macOS 13 的写法"
    )
    expect(
        !combined.contains("onChange(of: geometry.size) { _, newSize in"),
        "几何尺寸监听应改为兼容 macOS 13 的写法"
    )
    expect(
        !trainer.contains(".scrollBounceBehavior(.basedOnSize)"),
        "训练窗口不应继续依赖较新的 scrollBounceBehavior API"
    )
}

@main
enum MacOS13CompatibilityTestsMain {
    static func main() throws {
        try testDeploymentTargetIsMacOS13()
        try testSourceAvoidsMacOS14OnlySwiftUISyntax()
        print("macOS 13 compatibility tests passed")
    }
}
