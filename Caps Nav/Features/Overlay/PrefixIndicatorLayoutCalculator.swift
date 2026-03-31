import CoreGraphics
import Foundation

struct PrefixIndicatorLayout {
    let panelWidth: CGFloat
    let panelHeight: CGFloat
    let columnCount: Int
    let showsScrollableHelpList: Bool
}

enum PrefixIndicatorLayoutCalculator {
    static func layout(
        visibleFrame: CGRect,
        placement: PrefixIndicatorPlacement,
        isActive: Bool,
        helpEntryCount: Int
    ) -> PrefixIndicatorLayout {
        guard isActive, helpEntryCount > 0 else {
            return PrefixIndicatorLayout(
                panelWidth: 360,
                panelHeight: 94,
                columnCount: 1,
                showsScrollableHelpList: false
            )
        }

        let availableWidth = max(visibleFrame.width - 56, 320)
        let availableHeight = max(visibleFrame.height - 88, 240)
        let usesSingleColumn = placement == .top && (availableWidth < 1120 || availableHeight < 700)
        let columnCount = usesSingleColumn ? 1 : 2
        let rows = Int(ceil(Double(helpEntryCount) / Double(columnCount)))

        let preferredWidth: CGFloat
        if placement == .top {
            preferredWidth = usesSingleColumn
                ? min(max(availableWidth * 0.56, 420), 500)
                : min(max(availableWidth * 0.58, 560), 620)
        } else {
            preferredWidth = min(max(availableWidth * 0.46, 520), 640)
        }

        let headerHeight: CGFloat = placement == .top ? 154 : 138
        let rowHeight: CGFloat = placement == .top ? 54 : 50
        let contentBottomPadding: CGFloat = 14
        let rawHeight = headerHeight + (CGFloat(rows) * rowHeight) + contentBottomPadding
        let maxHeight = placement == .top
            ? min(availableHeight * 0.62, 520)
            : min(availableHeight * 0.92, 720)
        let panelHeight = min(max(rawHeight, 228), maxHeight)

        return PrefixIndicatorLayout(
            panelWidth: preferredWidth.rounded(.up),
            panelHeight: panelHeight.rounded(.up),
            columnCount: columnCount,
            showsScrollableHelpList: false
        )
    }
}
