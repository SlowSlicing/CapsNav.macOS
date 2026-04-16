import AppKit
import Foundation
import OSLog
import SwiftUI

struct PrefixIndicatorHelpEntry: Identifiable, Equatable {
    let id: String
    let triggerText: String
    let actionText: String
    let isHighlighted: Bool
}

@MainActor
final class PrefixIndicatorController {
    private let logger = AppLogger.make(category: "PrefixIndicator")

    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func update(
        isActive: Bool,
        routingMode: PrefixRoutingMode,
        profileName: String,
        helpEntries: [PrefixIndicatorHelpEntry],
        placement: PrefixIndicatorPlacement,
        opacityPercent: Int
    ) {
        guard routingMode != .inactive else {
            hideImmediately()
            return
        }

        let panel = ensurePanel()
        let screen = targetScreen()
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let layout = PrefixIndicatorLayoutCalculator.layout(
            visibleFrame: visibleFrame,
            placement: placement,
            isActive: isActive,
            helpEntryCount: helpEntries.count
        )

        panel.contentView = NSHostingView(
            rootView: PrefixIndicatorView(
                isActive: isActive,
                routingMode: routingMode,
                profileName: profileName,
                helpEntries: helpEntries,
                layout: layout,
                opacityPercent: opacityPercent
            )
        )
        panel.setContentSize(NSSize(width: layout.panelWidth, height: layout.panelHeight))
        position(panel, placement: placement, on: screen)
        panel.orderFrontRegardless()
        panel.alphaValue = 1

        hideWorkItem?.cancel()

        if isActive {
            logger.debug("Displayed active prefix indicator with help entries.")
        } else {
            logger.debug("Displayed released prefix indicator.")
            scheduleHide()
        }
    }

    func hideImmediately() {
        hideWorkItem?.cancel()
        panel?.orderOut(nil)
        panel?.alphaValue = 0
    }

    private func ensurePanel() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 94),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0

        self.panel = panel
        return panel
    }

    private func targetScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func position(_ panel: NSPanel, placement: PrefixIndicatorPlacement, on screen: NSScreen?) {
        guard let screen else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let horizontalInset: CGFloat = 28
        let topInset: CGFloat = 28
        let bottomInset: CGFloat = 60
        let boundedFrame = NSRect(
            x: visibleFrame.minX + horizontalInset,
            y: visibleFrame.minY + bottomInset,
            width: max(visibleFrame.width - (horizontalInset * 2), 0),
            height: max(visibleFrame.height - topInset - bottomInset, 0)
        )

        let x: CGFloat
        let y: CGFloat

        switch placement {
        case .top:
            x = boundedFrame.midX - (panel.frame.width / 2)
            y = boundedFrame.maxY - panel.frame.height
        case .bottom:
            x = boundedFrame.midX - (panel.frame.width / 2)
            y = boundedFrame.minY
        case .left:
            x = boundedFrame.minX
            y = boundedFrame.midY - (panel.frame.height / 2)
        case .right:
            x = boundedFrame.maxX - panel.frame.width
            y = boundedFrame.midY - (panel.frame.height / 2)
        }

        let maxX = max(boundedFrame.minX, boundedFrame.maxX - panel.frame.width)
        let maxY = max(boundedFrame.minY, boundedFrame.maxY - panel.frame.height)
        let clampedX = min(max(x, boundedFrame.minX), maxX)
        let clampedY = min(max(y, boundedFrame.minY), maxY)

        panel.setFrame(
            NSRect(
                x: clampedX,
                y: clampedY,
                width: panel.frame.width,
                height: panel.frame.height
            ),
            display: false
        )
    }

    private func scheduleHide(after delay: TimeInterval = 0.8) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel else {
                return
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.orderOut(nil)
            }
        }

        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

private struct PrefixIndicatorView: View {
    let isActive: Bool
    let routingMode: PrefixRoutingMode
    let profileName: String
    let helpEntries: [PrefixIndicatorHelpEntry]
    let layout: PrefixIndicatorLayout
    let opacityPercent: Int

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: layout.columnCount == 1 ? 0 : 240), spacing: 12, alignment: .leading),
            count: layout.columnCount
        )
    }

    private var overlayOpacity: Double {
        Double(opacityPercent) / 100
    }

    @ViewBuilder
    private var helpEntriesSection: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(helpEntries) { entry in
                PrefixIndicatorHelpRow(entry: entry)
            }
        }
        .padding(.bottom, 14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isActive ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted.opacity(0.35))
                        .frame(width: 14, height: 14)

                    Circle()
                        .stroke(isActive ? CapsNavTheme.accentStrong.opacity(0.35) : Color.clear, lineWidth: 8)
                        .frame(width: 22, height: 22)
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isActive ? "Caps 前缀已按下" : "Caps 前缀已松开")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(CapsNavTheme.textPrimary)

                    Text(routingMode.overlaySubtitle)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(CapsNavTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Text(isActive ? "LIVE" : "READY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? CapsNavTheme.accentStrong : CapsNavTheme.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isActive ? CapsNavTheme.accentSoft : CapsNavTheme.surfaceSecondary)
                    )
            }

            if isActive, !helpEntries.isEmpty {
                Divider()
                    .overlay(CapsNavTheme.borderSoft.opacity(0.75))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("当前配置方案：\(profileName)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textPrimary)

                        Spacer(minLength: 0)

                        Text("按住 Caps 时可用")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CapsNavTheme.accentStrong)
                            .padding(.top, 2)

                        Text("松开 Caps 即会关闭这条悬浮提示；也可以在“设置 -> 悬浮提示”里直接关闭帮助框。")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(CapsNavTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    helpEntriesSection
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(width: layout.panelWidth, height: layout.panelHeight, alignment: .topLeading)
        .opacity(overlayOpacity)
        .background(
            LinearGradient(
                colors: [CapsNavTheme.surfacePrimary, CapsNavTheme.surfaceSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isActive
                        ? CapsNavTheme.accentStrong.opacity(0.42)
                        : CapsNavTheme.borderSoft.opacity(0.9),
                    lineWidth: 1
                )
        )
        .shadow(color: CapsNavTheme.cardShadow.opacity(0.9), radius: 24, x: 0, y: 14)
    }
}

private struct PrefixIndicatorHelpRow: View {
    let entry: PrefixIndicatorHelpEntry

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(entry.triggerText)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(entry.isHighlighted ? CapsNavTheme.surfacePrimary : CapsNavTheme.accentStrong)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(entry.isHighlighted ? CapsNavTheme.accentStrong : CapsNavTheme.accentSoft)
                )
                .frame(width: 96, alignment: .leading)

            Text(entry.actionText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(entry.isHighlighted ? CapsNavTheme.textPrimary : CapsNavTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(entry.isHighlighted ? CapsNavTheme.accentSurface.opacity(0.96) : CapsNavTheme.surfaceSecondary.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    entry.isHighlighted ? CapsNavTheme.accentStrong.opacity(0.55) : CapsNavTheme.borderSoft.opacity(0.75),
                    lineWidth: entry.isHighlighted ? 1.2 : 1
                )
        )
        .shadow(
            color: entry.isHighlighted ? CapsNavTheme.accentStrong.opacity(0.12) : .clear,
            radius: 12,
            x: 0,
            y: 6
        )
    }
}
