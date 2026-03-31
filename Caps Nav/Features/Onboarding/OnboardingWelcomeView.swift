import SwiftUI

struct OnboardingWelcomeView: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(CapsNavTheme.accentStrong)
                    .padding(.bottom, 8)

                Text("欢迎使用 Caps Nav")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text("把 Caps Lock 变成你的导航前缀键")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
            }

            Spacer()
                .frame(height: 32)

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "arrow.up.arrow.down",
                    title: "主键区导航",
                    description: "在主键区完成光标移动，减少手部移动"
                )

                FeatureRow(
                    icon: "text.cursor",
                    title: "高效文本编辑",
                    description: "快速选中、删词、跳转行首行尾"
                )

                FeatureRow(
                    icon: "gearshape.fill",
                    title: "完全可配置",
                    description: "自定义键位映射，打造专属快捷键布局"
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    onSkip()
                } label: {
                    Text("跳过引导")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                        .frame(width: 100)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onNext()
                } label: {
                    HStack(spacing: 6) {
                        Text("下一步")
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

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CapsNavTheme.accentStrong)
                .frame(width: 32, height: 32)
                .background(CapsNavTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                Text(description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
            }
        }
    }
}
