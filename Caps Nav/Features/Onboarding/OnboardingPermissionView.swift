import SwiftUI

struct OnboardingPermissionView: View {
    let permissionStatus: AccessibilityAuthorizationStatus
    let onBack: () -> Void
    let onNext: () -> Void
    let onRequestPermission: () -> Void

    private var isAuthorized: Bool {
        permissionStatus == .trusted
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)

            Text("需要辅助功能权限")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(CapsNavTheme.textPrimary)

            Text("为了监听全局键盘事件，需要授予权限")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
                .padding(.top, 6)

            Spacer()
                .frame(height: 24)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isAuthorized ? CapsNavTheme.success.opacity(0.15) : CapsNavTheme.warning.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Image(systemName: isAuthorized ? "checkmark.shield.fill" : "hand.raised.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(isAuthorized ? CapsNavTheme.success : CapsNavTheme.warning)
                }

                VStack(spacing: 6) {
                    Text("当前状态")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textMuted)

                    Text(permissionStatus.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isAuthorized ? CapsNavTheme.success : CapsNavTheme.warning)
                }
            }

            Spacer()
                .frame(height: 20)

            VStack(alignment: .leading, spacing: 10) {
                Text("为什么需要此权限？")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CapsNavTheme.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    PermissionReasonRow(text: "监听全局键盘事件")
                    PermissionReasonRow(text: "稳定识别前缀键按下与松开")
                    PermissionReasonRow(text: "拦截原始按键，避免字母漏出")
                    PermissionReasonRow(text: "把目标动作重发为系统编辑快捷键")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CapsNavTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 16)

            if !isAuthorized {
                Button {
                    onRequestPermission()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                        Text("打开系统设置")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(CapsNavTheme.accentStrong, in: Capsule())
                }
                .buttonStyle(.plain)
            }

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
                        Text(isAuthorized ? "下一步" : "稍后设置")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(isAuthorized ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }
}

private struct PermissionReasonRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(CapsNavTheme.accentStrong)

            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(CapsNavTheme.textSecondary)
        }
    }
}
