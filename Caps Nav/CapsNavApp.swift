//
//  CapsNavApp.swift
//  CapsNav
//
//  Created by 郭青松 on 2026/3/24.
//

import AppKit
import SwiftUI

@main
struct CapsNavApp: App {
    @NSApplicationDelegateAdaptor(CapsNavApplicationDelegate.self) private var appDelegate

    private let appBootstrap: AppBootstrap

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        let bootstrap = AppBootstrap()
        self.appBootstrap = bootstrap
        appDelegate.appBootstrap = bootstrap

        DispatchQueue.main.async {
            bootstrap.start()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuView(appBootstrap: appBootstrap)
        } label: {
            MenuBarExtraLabelView(appBootstrap: appBootstrap)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Caps Nav 设置") {
                    appBootstrap.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .appSettings) {
                Button("打开快捷键练习") {
                    appBootstrap.openShortcutTrainerWindow()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appInfo) {
                Button("关于 Caps Nav") {
                    AboutPanelPresenter.show()
                }
            }

            CommandGroup(replacing: .appTermination) {
                Button("退出 Caps Nav") {
                    appBootstrap.quitApplication()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

private struct MenuBarExtraLabelView: View {
    @ObservedObject var appBootstrap: AppBootstrap

    var body: some View {
        MenuBarIconGlyphView(
            style: appBootstrap.menuBarIconStyle,
            tint: appBootstrap.operationalState == .paused ? .secondary : .primary,
            symbolSize: 14,
            showsPausedBadge: appBootstrap.operationalState == .paused
        )
    }
}

struct MenuBarIconGlyphView: View {
    let style: MenuBarIconStyle
    var tint: Color = .primary
    var symbolSize: CGFloat = 15
    var showsPausedBadge = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch style.glyphKind {
                case let .symbol(symbolName):
                    Image(systemName: symbolName)
                        .font(.system(size: symbolSize, weight: .bold))
                case let .overlay(base, badge):
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: base)
                            .font(.system(size: symbolSize, weight: .bold))

                        Image(systemName: badge)
                            .font(.system(size: max(symbolSize - 5, 8), weight: .black))
                            .offset(x: 3, y: 2)
                    }
                case let .capsuleText(text):
                    Text(text)
                        .font(.system(size: max(symbolSize - 5, 8), weight: .black, design: .rounded))
                        .tracking(text.count > 2 ? -0.5 : 0)
                        .padding(.horizontal, text.count > 2 ? 4 : 5)
                        .padding(.vertical, 2)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(tint.opacity(0.55), lineWidth: 1)
                        )
                }
            }
            .foregroundStyle(tint)
            .opacity(showsPausedBadge ? 0.72 : 1)

            if showsPausedBadge {
                ZStack {
                    Circle()
                        .fill(.background.opacity(0.95))
                        .frame(width: max(symbolSize - 2, 10), height: max(symbolSize - 2, 10))

                    Image(systemName: "pause.fill")
                        .font(.system(size: max(symbolSize - 8, 7), weight: .black))
                        .foregroundStyle(Color.orange.opacity(0.95))
                }
                .offset(x: 5, y: -4)
            }
        }
    }
}
