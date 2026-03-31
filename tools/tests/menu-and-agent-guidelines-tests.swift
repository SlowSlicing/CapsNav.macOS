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

private func testAgentsDocumentPinsMacOS13Baseline() throws {
    let agents = try loadFile(at: "AGENTS.md")

    expect(
        agents.contains("最低支持系统版本固定为 `macOS 13.0+`。"),
        "AGENTS.md 应明确固定最低支持系统版本为 macOS 13.0+"
    )
}

private func testMenuBarEntriesUseIcons() throws {
    let source = try loadFile(at: "Caps Nav/Features/MenuBar/MenuBarMenuView.swift")

    expect(
        source.contains("Label(\"切换配置方案\", systemImage: \"square.stack.3d.up.fill\")"),
        "切换配置方案菜单应带图标"
    )
    expect(
        source.contains("Label(\"打开设置\", systemImage: \"gearshape.fill\")"),
        "打开设置菜单应带图标"
    )
    expect(
        source.contains("Label(\"快捷键练习\", systemImage: \"gamecontroller.fill\")"),
        "快捷键练习菜单应带图标"
    )
    expect(
        source.contains("Label(\"关于 Caps Nav\", systemImage: \"info.circle.fill\")"),
        "关于 Caps Nav 菜单应带图标"
    )
    expect(
        source.contains("Label(\"退出 Caps Nav\", systemImage: \"power\")"),
        "退出 Caps Nav 菜单应带图标"
    )
}

@main
enum MenuAndAgentGuidelinesTestsMain {
    static func main() throws {
        try testAgentsDocumentPinsMacOS13Baseline()
        try testMenuBarEntriesUseIcons()
        print("Menu and agent guidelines tests passed")
    }
}
