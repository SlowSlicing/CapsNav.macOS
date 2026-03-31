import AppKit
import SwiftUI

private let accessibilityPermissionPromptWindowSize = NSSize(width: 1040, height: 640)

@MainActor
final class AccessibilityPermissionPromptController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    func show(appBootstrap: AppBootstrap, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let window = ensureWindow()
        window.contentViewController = NSHostingController(
            rootView: AccessibilityPermissionPromptView(
                appBootstrap: appBootstrap,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )

        window.setContentSize(accessibilityPermissionPromptWindowSize)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: accessibilityPermissionPromptWindowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Caps Nav 辅助功能权限"
        window.minSize = accessibilityPermissionPromptWindowSize
        window.maxSize = accessibilityPermissionPromptWindowSize
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self

        self.window = window
        return window
    }
}

private struct AccessibilityPermissionPromptView: View {
    @ObservedObject var appBootstrap: AppBootstrap
    let onClose: () -> Void

    private var isTrusted: Bool {
        appBootstrap.accessibilityStatus == .trusted
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CapsNavTheme.windowTop, CapsNavTheme.windowBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(CapsNavTheme.glowPrimary)
                .frame(width: 340, height: 340)
                .blur(radius: 92)
                .offset(x: -260, y: -220)

            Circle()
                .fill(CapsNavTheme.glowSecondary)
                .frame(width: 300, height: 300)
                .blur(radius: 98)
                .offset(x: 260, y: -230)

            HStack(alignment: .top, spacing: 20) {
                introPanel
                    .frame(width: 360, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 18) {
                        permissionCard(
                            title: "为什么必须要这个权限",
                            symbolName: "waveform.path.ecg.rectangle",
                            lines: [
                                "监听全局键盘事件，稳定识别 Caps Lock 的按下与松开。",
                                "拦截 Caps Lock + 快捷键，避免原始按键继续传给当前应用。",
                                "把映射动作重发为移动、选中、删除等系统级编辑命令。"
                            ]
                        )

                        permissionCard(
                            title: "授权步骤",
                            symbolName: "slider.horizontal.3",
                            lines: [
                                "点击“打开系统授权”后，macOS 会跳到辅助功能授权入口。",
                                "在系统设置里找到 Caps Nav，并勾选允许控制你的电脑。",
                                "授权完成后回到这个窗口会自动检测；你也可以手动点“重新检查权限”。"
                            ]
                        )
                    }

                    Spacer(minLength: 0)

                    footerSection
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(24)
            .frame(width: accessibilityPermissionPromptWindowSize.width, height: accessibilityPermissionPromptWindowSize.height, alignment: .topLeading)
        }
        .frame(width: accessibilityPermissionPromptWindowSize.width, height: accessibilityPermissionPromptWindowSize.height)
    }

    private var introPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CapsNavTheme.accentSoft)
                    .frame(width: 88, height: 88)

                Image(systemName: isTrusted ? "checkmark.shield.fill" : "lock.shield.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(isTrusted ? CapsNavTheme.success : CapsNavTheme.accentStrong)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(isTrusted ? "辅助功能权限已就绪" : "Caps Nav 需要辅助功能权限")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    isTrusted
                    ? "权限已经授予，Caps Nav 可以正常接管 Caps Lock 前缀键、拦截映射按键并重发系统导航动作。"
                    : "没有这个权限时，App 只能显示界面，无法监听全局键盘、拦截原始按键，也无法把快捷键动作重发给当前应用。"
                )
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                PermissionStatusPill(
                    title: "当前状态",
                    value: appBootstrap.accessibilityStatus.displayName,
                    tone: isTrusted ? .success : .warning
                )
            }

            permissionSummaryRow(
                symbolName: "keyboard.badge.ellipsis",
                title: "没有权限时会怎样",
                text: "App 只能显示界面，无法监听全局按键，也无法阻断 Caps Lock + 快捷键的原始事件。"
            )

            permissionSummaryRow(
                symbolName: "sparkles.rectangle.stack.fill",
                title: "授权后会恢复什么",
                text: "前缀识别、快捷键重发和悬浮帮助都会立即恢复，你可以立刻开始测试。"
            )

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CapsNavTheme.accentStrong)
                    .padding(.top, 2)

                Text("这个窗口可以随时关闭。之后如果还没授权，也可以在“概览 -> 权限与激活”里再次打开。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.9), radius: 24, x: 0, y: 14)
    }

    private func permissionSummaryRow(symbolName: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CapsNavTheme.accentSurface)
                    .frame(width: 34, height: 34)

                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CapsNavTheme.accentStrong)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func permissionCard(title: String, symbolName: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CapsNavTheme.accentSurface)
                        .frame(width: 38, height: 38)

                    Image(systemName: symbolName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(CapsNavTheme.accentStrong)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(line)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 228, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.75), radius: 16, x: 0, y: 10)
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isTrusted ? "权限已经准备好，可以直接返回设置页继续配置。" : "完成系统授权后，回到这里会自动刷新权限状态；“重新检查权限”仍然保留给你手动确认。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("关闭窗口") {
                    onClose()
                }
                .buttonStyle(.bordered)

                Button("重新检查权限") {
                    appBootstrap.refreshAccessibilityStatus()
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                if !isTrusted {
                    Button("打开系统授权") {
                        appBootstrap.requestSystemAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CapsNavTheme.accentStrong)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.9), lineWidth: 1)
        )
    }
}

private struct PermissionStatusPill: View {
    enum Tone {
        case success
        case warning

        var foreground: Color {
            switch self {
            case .success:
                return CapsNavTheme.success
            case .warning:
                return CapsNavTheme.warning
            }
        }

        var background: Color {
            switch self {
            case .success:
                return CapsNavTheme.surfaceSecondary
            case .warning:
                return CapsNavTheme.surfaceSecondary
            }
        }
    }

    let title: String
    let value: String
    let tone: Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(tone.foreground)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CapsNavTheme.borderSoft.opacity(0.7), lineWidth: 1)
        )
    }
}
