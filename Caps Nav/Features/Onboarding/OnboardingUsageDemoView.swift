import Combine
import SwiftUI

struct OnboardingUsageDemoView: View {
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)

            Text("核心用法")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)

            Text("按住 Caps Lock，再按字母键触发动作")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .padding(.top, 6)

            Spacer()
                .frame(height: 20)

            KeyPressAnimationView()
                .frame(height: 120)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 16)

            VStack(alignment: .leading, spacing: 12) {
                Text("常用映射速览")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)
                    .padding(.bottom, 4)

                HStack(spacing: 24) {
                    MappingGroup(
                        title: "方向移动",
                        mappings: [
                            ("E", "上"),
                            ("D", "下"),
                            ("S", "左"),
                            ("F", "右")
                        ]
                    )

                    MappingGroup(
                        title: "删除",
                        mappings: [
                            ("W", "删前"),
                            ("R", "删后"),
                            ("Q", "删词←"),
                            ("T", "删词→")
                        ]
                    )

                    MappingGroup(
                        title: "选中",
                        mappings: [
                            ("J", "选左"),
                            ("L", "选右"),
                            ("I", "选上"),
                            ("K", "选下")
                        ]
                    )
                }
            }
            .padding(20)
            .background(CapsNavTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                        Text("上一步")
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(CapsNavTheme.surfaceSecondary, in: Capsule())
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

private struct MappingGroup: View {
    let title: String
    let mappings: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textMuted)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(mappings.enumerated()), id: \.offset) { _, mapping in
                    HStack(spacing: 8) {
                        Text(mapping.0)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(CapsNavTheme.accentStrong)
                            .frame(width: 20)

                        Text(mapping.1)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct KeyPressAnimationView: View {
    @State private var animationPhase = 0
    @State private var cursorOffset: CGFloat = 0

    private let timer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()

    private var isCapsPressed: Bool { animationPhase >= 1 && animationPhase <= 4 }
    private var isKeyPressed: Bool { animationPhase >= 2 && animationPhase <= 3 }
    private var showEffect: Bool { animationPhase >= 3 && animationPhase <= 5 }

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(CapsNavTheme.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(CapsNavTheme.borderSoft, lineWidth: 1)
                    )

                HStack(spacing: 0) {
                    Text("Hello ")
                        .font(.system(size: 20, design: .monospaced))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    ZStack(alignment: .leading) {
                        Text("World")
                            .font(.system(size: 20, design: .monospaced))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Rectangle()
                            .fill(CapsNavTheme.accentStrong)
                            .frame(width: 2, height: 24)
                            .offset(x: cursorOffset)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 48)

            HStack(spacing: 12) {
                KeyCapView(label: "Caps", isPressed: isCapsPressed)

                Text("+")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CapsNavTheme.textMuted)

                KeyCapView(label: "F", isPressed: isKeyPressed)

                Text("=")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CapsNavTheme.textMuted)

                HStack(spacing: 6) {
                    Text("光标向右移动")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(showEffect ? CapsNavTheme.accentStrong : CapsNavTheme.textSecondary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(showEffect ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted)
                }
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                animationPhase = (animationPhase + 1) % 7
            }

            if animationPhase == 3 {
                withAnimation(.easeOut(duration: 0.15)) {
                    cursorOffset += 13
                }
            }

            if animationPhase == 0 {
                cursorOffset = 0
            }
        }
        .onAppear {
            animationPhase = 0
            cursorOffset = 0
        }
    }
}

private struct KeyCapView: View {
    let label: String
    let isPressed: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(isPressed ? .white : CapsNavTheme.textPrimary)
            .frame(width: label == "Caps" ? 52 : 36, height: 36)
            .background(
                isPressed ? CapsNavTheme.accentStrong : CapsNavTheme.surfacePrimary,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isPressed ? CapsNavTheme.accentStrong : CapsNavTheme.borderSoft, lineWidth: 1)
            )
            .shadow(color: CapsNavTheme.cardShadow, radius: 2, y: 1)
    }
}
