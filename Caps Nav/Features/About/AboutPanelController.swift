import AppKit
import SwiftUI

private let aboutPanelWindowSize = NSSize(width: 1000, height: 700)

@MainActor
final class AboutPanelController: NSObject, NSWindowDelegate {
    static let shared = AboutPanelController()

    private var window: NSWindow?

    func show() {
        let window = ensureWindow()
        window.contentViewController = NSHostingController(
            rootView: AboutPanelView(
                metadata: .current,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )

        window.setContentSize(aboutPanelWindowSize)
        NSApplication.shared.activate(ignoringOtherApps: true)
        centerWindowOnActiveScreen(window)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func ensureWindow() -> NSWindow {
        if let window {
            return window
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: aboutPanelWindowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "关于 Caps Nav"
        window.titleVisibility = .hidden
        window.minSize = aboutPanelWindowSize
        window.maxSize = aboutPanelWindowSize
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self

        self.window = window
        return window
    }

    private func centerWindowOnActiveScreen(_ window: NSWindow) {
        let activeScreen = NSScreen.screens.first(where: { screen in
            screen.frame.contains(NSEvent.mouseLocation)
        }) ?? window.screen ?? NSScreen.main

        guard let visibleFrame = activeScreen?.visibleFrame else {
            window.center()
            return
        }

        let origin = NSPoint(
            x: visibleFrame.midX - (window.frame.width / 2),
            y: visibleFrame.midY - (window.frame.height / 2)
        )
        window.setFrameOrigin(origin)
    }
}

enum AboutPanelPresenter {
    @MainActor
    static func show() {
        AboutPanelController.shared.show()
    }
}

private struct AboutPanelView: View {
    let metadata: AboutAppMetadata
    let onClose: () -> Void

    private let featureCards: [AboutFeature] = [
        AboutFeature(
            symbolName: "keyboard.badge.ellipsis",
            title: "前缀导航",
            description: "把 Caps Lock 变成顺手的前缀键，用单手完成移动、选中、删除等编辑动作。"
        ),
        AboutFeature(
            symbolName: "rectangle.on.rectangle.circle.fill",
            title: "多配置方案",
            description: "支持多套配置方案、拖拽排序与复制扩展，按你的输入习惯自由整理。"
        ),
        AboutFeature(
            symbolName: "sparkles.rectangle.stack.fill",
            title: "可视悬浮提示",
            description: "用轻量悬浮框提示当前状态和快捷键作用，熟悉之前也能安心上手。"
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [CapsNavTheme.windowTop, CapsNavTheme.windowBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(CapsNavTheme.glowPrimary)
                    .frame(width: 360, height: 360)
                    .blur(radius: 96)
                    .offset(x: -280, y: -220)

                Circle()
                    .fill(CapsNavTheme.glowSecondary)
                    .frame(width: 320, height: 320)
                    .blur(radius: 104)
                    .offset(x: 300, y: -210)

                HStack(alignment: .top, spacing: 20) {
                    heroPanel
                        .frame(width: 324, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 16) {
                        overviewCard

                        HStack(alignment: .top, spacing: 14) {
                            ForEach(featureCards) { feature in
                                AboutFeatureCard(feature: feature)
                            }
                        }

                        footerCard
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(26)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            }
        }
        .frame(width: aboutPanelWindowSize.width, height: aboutPanelWindowSize.height)
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            appIconSection

            VStack(alignment: .leading, spacing: 10) {
                Text("Caps Nav")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text("把 Caps Lock 变成可靠、顺手、能长期使用的前缀导航键。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                AboutInlineMetaRow(symbolName: "person.fill", title: "作者", value: metadata.author)
                AboutInlineMetaRow(symbolName: "shippingbox.fill", title: "版本", value: metadata.versionLabel)
                AboutInlineMetaRow(symbolName: "desktopcomputer", title: "平台", value: metadata.platformLabel)
            }

            HStack(spacing: 8) {
                AboutTag(title: "macOS 优先")
                AboutTag(title: "菜单栏常驻")
                AboutTag(title: "可配置")
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 14) {
                Text("设计目标")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)

                VStack(alignment: .leading, spacing: 10) {
                    AboutBulletRow(text: "尽量不打断已有输入习惯，让导航和编辑动作更自然。")
                    AboutBulletRow(text: "把配置、权限、提示和运行状态都放到可视化界面里。")
                    AboutBulletRow(text: "保持轻量常驻，适合作为长期使用的输入增强工具。")
                }
            }

            HStack(spacing: 10) {
                Button("关闭窗口") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(CapsNavTheme.accentStrong)

                Text("关于页仅展示产品信息，不会改动当前配置。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(panelBackground)
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.92), radius: 24, x: 0, y: 14)
    }

    private var appIconSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(CapsNavTheme.accentSoft)
                .frame(width: 112, height: 112)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [CapsNavTheme.surfacePrimary, CapsNavTheme.surfaceSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 92, height: 92)

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: CapsNavTheme.cardShadow.opacity(0.65), radius: 10, x: 0, y: 6)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("专为键盘重度输入场景设计")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Caps Nav 聚焦于一个目标：让光标移动、文本选择和常用编辑动作都能围绕 Caps Lock 前缀键稳定完成。")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                AboutStatusPill(title: "当前状态", value: "已安装")
            }

            HStack(spacing: 14) {
                AboutMetricCard(title: "版本号", value: metadata.version)
                AboutMetricCard(title: "构建号", value: metadata.build)
                AboutMetricCard(title: "最低系统", value: metadata.minimumSystemVersion)
            }
        }
        .padding(22)
        .background(panelBackground)
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.82), radius: 18, x: 0, y: 10)
    }

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CapsNavTheme.accentSurface)
                        .frame(width: 40, height: 40)

                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(CapsNavTheme.accentStrong)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("作者与产品定位")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    Text("由 \(metadata.author) 制作，面向所有需要文本编辑与键盘导航的 macOS 用户；编辑越频繁，收益越明显。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("适合谁")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textMuted)

                    Text("开发者、写作者、编辑、运营，以及任何希望少离开主键区的人。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("使用体验")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textMuted)

                    Text("优先保证识别稳定、提示清晰、配置直接，避免把常用能力埋进复杂设置。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .background(panelBackground)
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.78), radius: 16, x: 0, y: 10)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(CapsNavTheme.surfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.88), lineWidth: 1)
            )
    }
}

private struct AboutFeature: Identifiable {
    let id = UUID()
    let symbolName: String
    let title: String
    let description: String
}

private struct AboutAppMetadata {
    let version: String
    let build: String
    let minimumSystemVersion: String
    let author: String

    var versionLabel: String {
        "Version \(version) (\(build))"
    }

    var platformLabel: String {
        "macOS \(minimumSystemVersion)+"
    }

    static var current: AboutAppMetadata {
        AboutAppMetadata(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            minimumSystemVersion: Bundle.main.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String ?? "14.0",
            author: "大漠知秋"
        )
    }
}

private struct AboutFeatureCard: View {
    let feature: AboutFeature

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CapsNavTheme.accentSurface)
                    .frame(width: 42, height: 42)

                Image(systemName: feature.symbolName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CapsNavTheme.accentStrong)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(feature.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(feature.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 172, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CapsNavTheme.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(CapsNavTheme.borderSoft.opacity(0.84), lineWidth: 1)
                )
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.72), radius: 14, x: 0, y: 8)
    }
}

private struct AboutMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(CapsNavTheme.borderSoft.opacity(0.8), lineWidth: 1)
                )
        )
    }
}

private struct AboutInlineMetaRow: View {
    let symbolName: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CapsNavTheme.accentStrong)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)
                .frame(width: 34, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AboutBulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(CapsNavTheme.accentStrong)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AboutTag: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(CapsNavTheme.accentStrong)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(CapsNavTheme.accentSoft)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(CapsNavTheme.accentStrong.opacity(0.18), lineWidth: 1)
                    )
            )
    }
}

private struct AboutStatusPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(CapsNavTheme.success)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(CapsNavTheme.borderSoft.opacity(0.78), lineWidth: 1)
                )
        )
    }
}
