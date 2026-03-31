import SwiftUI

struct OnboardingCompleteView: View {
    let onOpenTrainer: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(CapsNavTheme.success.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(CapsNavTheme.success)
                }

                Text("准备就绪！")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text("Caps Nav 已在菜单栏运行")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
            }

            Spacer()
                .frame(height: 32)

            VStack(alignment: .leading, spacing: 16) {
                TipRow(
                    icon: "keyboard.badge.eye",
                    text: "按住 Caps Lock 时会显示快捷键提示框"
                )
                TipRow(
                    icon: "slider.horizontal.3",
                    text: "在设置中可以自定义键位映射"
                )
                TipRow(
                    icon: "gamecontroller.fill",
                    text: "使用「快捷键练习」可以更快熟悉键位"
                )
                TipRow(
                    icon: "menubar.rectangle",
                    text: "点击菜单栏图标可以快速启用或暂停"
                )
            }
            .padding(20)
            .background(CapsNavTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    onOpenTrainer()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                        Text("打开快捷键练习")
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.accentStrong)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(CapsNavTheme.accentSoft, in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onComplete()
                } label: {
                    HStack(spacing: 6) {
                        Text("开始使用")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(CapsNavTheme.accentStrong, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }
}

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CapsNavTheme.accentStrong)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
        }
    }
}
