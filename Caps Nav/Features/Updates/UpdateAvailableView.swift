import SwiftUI

private let updateAvailableDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct UpdateAvailableView: View {
    let currentVersion: String
    let updateInfo: AppUpdateInfo
    let isSystemCompatible: Bool
    let onDownload: () -> Void
    let onOpenReleasePage: () -> Void
    let onClose: () -> Void

    private var normalizedNotesMarkdown: String {
        updateInfo.notesMarkdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private var publishedAtText: String {
        updateAvailableDateFormatter.string(from: updateInfo.publishedAt)
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
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: -280, y: -220)

            Circle()
                .fill(CapsNavTheme.glowSecondary)
                .frame(width: 320, height: 320)
                .blur(radius: 104)
                .offset(x: 300, y: -220)

            HStack(alignment: .top, spacing: 20) {
                heroPanel
                    .frame(width: 320, alignment: .topLeading)

                contentPanel
            }
            .padding(24)
            .frame(width: updateAvailableWindowSize.width, height: updateAvailableWindowSize.height, alignment: .topLeading)
        }
        .frame(width: updateAvailableWindowSize.width, height: updateAvailableWindowSize.height)
    }

    private var heroPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CapsNavTheme.accentSoft)
                    .frame(width: 92, height: 92)

                Image(systemName: isSystemCompatible ? "arrow.down.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(isSystemCompatible ? CapsNavTheme.accentStrong : CapsNavTheme.warning)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(isSystemCompatible ? "发现新版本" : "发现新版本，但当前系统暂不支持")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    isSystemCompatible
                    ? "Caps Nav \(updateInfo.version) 已可下载。你可以先看更新说明，再决定是否跳转到下载页。"
                    : "最新版本要求 macOS \(updateInfo.minimumSystemVersion)+。当前设备还不能安装，但你仍然可以先查看更新说明。"
                )
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                UpdateMetaRow(title: "当前版本", value: currentVersion)
                UpdateMetaRow(title: "新版本", value: updateInfo.version)
                UpdateMetaRow(title: "发布时间", value: publishedAtText)
                UpdateMetaRow(title: "最低系统", value: "macOS \(updateInfo.minimumSystemVersion)+")
            }

            if !isSystemCompatible {
                UpdateInlineNotice(
                    text: "当前设备还不满足新版本的系统要求，因此下载按钮会先禁用。",
                    color: CapsNavTheme.warning
                )
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    onDownload()
                } label: {
                    Label("下载更新", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CapsNavTheme.accentStrong)
                .disabled(!isSystemCompatible)

                HStack(spacing: 10) {
                    Button("查看完整发布说明") {
                        onOpenReleasePage()
                    }
                    .buttonStyle(.bordered)

                    Button("稍后再说") {
                        onClose()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CapsNavTheme.textSecondary)
                }
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(updatePanelBackground)
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.92), radius: 24, x: 0, y: 14)
    }

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("更新内容")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    Text("以下内容直接来自 GitHub Release 的手写说明。")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            ScrollView {
                ReleaseNotesMarkdownView(markdown: normalizedNotesMarkdown)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(updatePanelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.84), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: CapsNavTheme.cardShadow.opacity(0.78), radius: 16, x: 0, y: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var updatePanelBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(CapsNavTheme.surfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(CapsNavTheme.borderSoft.opacity(0.88), lineWidth: 1)
            )
    }
}

private struct UpdateMetaRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct UpdateInlineNotice: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CapsNavTheme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
    }
}
