import AppKit
import SwiftUI

struct MenuBarMenuView: View {
    @ObservedObject var appBootstrap: AppBootstrap

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caps Nav")
                .font(.headline)

            Text("当前状态：\(appBootstrap.operationalState.displayName)")
                .font(.subheadline)

            Text("当前配置方案：\(appBootstrap.activeProfileName)")
                .font(.caption)

            Text("辅助功能权限：\(appBootstrap.accessibilityStatus.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button {
                appBootstrap.toggleAppEnabled()
            } label: {
                Label(
                    appBootstrap.operationalState.menuActionTitle,
                    systemImage: appBootstrap.isAppEnabled ? "pause.circle.fill" : "play.circle.fill"
                )
            }

            if !appBootstrap.profiles.isEmpty {
                Menu {
                    ForEach(appBootstrap.profiles, id: \.id) { profile in
                        Button {
                            appBootstrap.switchActiveProfile(to: profile.id)
                        } label: {
                            if profile.id == appBootstrap.activeProfileID {
                                Label(profile.name, systemImage: "checkmark")
                            } else {
                                Text(profile.name)
                            }
                        }
                    }
                } label: {
                    Label("切换配置方案", systemImage: "square.stack.3d.up.fill")
                }
            }

            Button {
                appBootstrap.openSettingsWindow()
            } label: {
                Label("打开设置", systemImage: "gearshape.fill")
            }

            Button {
                appBootstrap.openShortcutTrainerWindow()
            } label: {
                Label("快捷键练习", systemImage: "gamecontroller.fill")
            }

            if appBootstrap.accessibilityStatus != .trusted {
                Button {
                    appBootstrap.requestAccessibilityPermission()
                } label: {
                    Label("申请辅助功能权限", systemImage: "hand.raised.fill")
                }
            }

            Button {
                AboutPanelPresenter.show()
            } label: {
                Label("关于 Caps Nav", systemImage: "info.circle.fill")
            }

            Divider()

            Button {
                appBootstrap.quitApplication()
            } label: {
                Label("退出 Caps Nav", systemImage: "power")
            }
        }
        .padding(.vertical, 4)
        .frame(minWidth: 240, alignment: .leading)
    }
}
