import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case usageDemo = 1
    case permission = 2
    case complete = 3

    var title: String {
        switch self {
        case .welcome:
            return "欢迎"
        case .usageDemo:
            return "核心用法"
        case .permission:
            return "权限"
        case .complete:
            return "完成"
        }
    }
}

struct OnboardingRootView: View {
    @ObservedObject var controller: OnboardingWindowController

    let permissionStatus: AccessibilityAuthorizationStatus
    let onComplete: () -> Void
    let onRequestPermission: () -> Void
    let onOpenTrainer: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepIndicator(
                currentStep: controller.currentStep,
                steps: OnboardingStep.allCases
            )
            .padding(.top, 24)
            .padding(.horizontal, 32)

            Divider()
                .overlay(CapsNavTheme.borderSoft.opacity(0.5))
                .padding(.top, 16)

            Group {
                switch controller.currentStep {
                case .welcome:
                    OnboardingWelcomeView(
                        onNext: {
                            controller.currentStep = .usageDemo
                        },
                        onSkip: onComplete
                    )
                case .usageDemo:
                    OnboardingUsageDemoView(
                        onBack: {
                            controller.currentStep = .welcome
                        },
                        onNext: {
                            controller.currentStep = .permission
                        }
                    )
                case .permission:
                    OnboardingPermissionView(
                        permissionStatus: permissionStatus,
                        onBack: {
                            controller.currentStep = .usageDemo
                        },
                        onNext: {
                            controller.currentStep = .complete
                        },
                        onRequestPermission: onRequestPermission
                    )
                case .complete:
                    OnboardingCompleteView(
                        onOpenTrainer: onOpenTrainer,
                        onComplete: onComplete
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            LinearGradient(
                colors: [CapsNavTheme.windowTop, CapsNavTheme.windowBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .animation(.easeInOut(duration: 0.25), value: controller.currentStep)
    }
}

private struct OnboardingStepIndicator: View {
    let currentStep: OnboardingStep
    let steps: [OnboardingStep]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 8) {
                    ZStack {
                        if step.rawValue < currentStep.rawValue {
                            Circle()
                                .fill(CapsNavTheme.accentStrong)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else if step == currentStep {
                            Circle()
                                .fill(CapsNavTheme.accentStrong)
                                .frame(width: 24, height: 24)

                            Text("\(step.rawValue + 1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        } else {
                            Circle()
                                .stroke(CapsNavTheme.borderSoft, lineWidth: 1.5)
                                .frame(width: 24, height: 24)

                            Text("\(step.rawValue + 1)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(CapsNavTheme.textMuted)
                        }
                    }

                    Text(step.title)
                        .font(.system(size: 13, weight: step == currentStep ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(step == currentStep ? CapsNavTheme.textPrimary : CapsNavTheme.textMuted)
                }

                if index < steps.count - 1 {
                    Spacer()

                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? CapsNavTheme.accentStrong : CapsNavTheme.borderSoft)
                        .frame(height: 1.5)
                        .frame(maxWidth: 40)

                    Spacer()
                }
            }
        }
    }
}
