import Carbon.HIToolbox
import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

private func testDescriptorBuildsFromShortcut() {
    let descriptor = GlobalToggleHotKeyDescriptor(shortcut: Shortcut(key: "k", modifiers: [.command, .option]))
    expect(descriptor != nil, "受支持的快捷键应能生成热键描述")
    expect(descriptor?.keyCode == 40, "K 的 Carbon keyCode 应为 40")
    expect(
        descriptor?.modifiers == UInt32(cmdKey | optionKey),
        "Command + Option 应映射到 Carbon modifiers"
    )
}

private func testDescriptorRejectsUnsupportedKey() {
    let descriptor = GlobalToggleHotKeyDescriptor(shortcut: Shortcut(key: "f13", modifiers: [.command]))
    expect(descriptor == nil, "不支持的按键不应生成热键描述")
}

@main
enum GlobalToggleHotKeyDescriptorTestsMain {
    static func main() {
        testDescriptorBuildsFromShortcut()
        testDescriptorRejectsUnsupportedKey()
        print("Global toggle hotkey descriptor tests passed")
    }
}
