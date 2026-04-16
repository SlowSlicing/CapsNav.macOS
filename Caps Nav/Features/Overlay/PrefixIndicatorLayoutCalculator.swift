import CoreGraphics
import Foundation

struct PrefixIndicatorLayout {
    let panelWidth: CGFloat
    let panelHeight: CGFloat
    let columnCount: Int
    let showsScrollableHelpList: Bool
}

enum PrefixIndicatorLayoutCalculator {
    private static let headerHeight: CGFloat = 154
    private static let rowHeight: CGFloat = 54
    private static let contentBottomPadding: CGFloat = 14
    private static let minColumnWidth: CGFloat = 260
    private static let columnSpacing: CGFloat = 12

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

        if placement == .top {
            return topLayout(
                availableWidth: availableWidth,
                availableHeight: availableHeight,
                helpEntryCount: helpEntryCount
            )
        }

        return sideOrBottomLayout(
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            helpEntryCount: helpEntryCount
        )
    }

    private static func topLayout(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        helpEntryCount: Int
    ) -> PrefixIndicatorLayout {
        let maxHeight = min(availableHeight * 0.72, 600)
        let maxColumns = max(Int(floor((availableWidth * 0.9 + columnSpacing) / (minColumnWidth + columnSpacing))), 1)

        var bestColumnCount = 1
        for cols in 1...maxColumns {
            let rows = Int(ceil(Double(helpEntryCount) / Double(cols)))
            let height = headerHeight + CGFloat(rows) * rowHeight + contentBottomPadding
            bestColumnCount = cols
            if height <= maxHeight {
                break
            }
        }

        let rows = Int(ceil(Double(helpEntryCount) / Double(bestColumnCount)))
        let rawHeight = headerHeight + CGFloat(rows) * rowHeight + contentBottomPadding
        let panelHeight = min(max(rawHeight, 228), maxHeight)

        let panelWidth: CGFloat
        if bestColumnCount == 1 {
            panelWidth = min(max(availableWidth * 0.56, 420), 500)
        } else {
            let contentWidth = CGFloat(bestColumnCount) * minColumnWidth + CGFloat(bestColumnCount - 1) * columnSpacing + 32
            panelWidth = min(max(contentWidth, 560), availableWidth * 0.9)
        }

        return PrefixIndicatorLayout(
            panelWidth: panelWidth.rounded(.up),
            panelHeight: panelHeight.rounded(.up),
            columnCount: bestColumnCount,
            showsScrollableHelpList: false
        )
    }

    private static func sideOrBottomLayout(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        helpEntryCount: Int
    ) -> PrefixIndicatorLayout {
        let columnCount = 2
        let rows = Int(ceil(Double(helpEntryCount) / Double(columnCount)))
        let rawHeight = headerHeight + CGFloat(rows) * rowHeight + contentBottomPadding
        let maxHeight = min(availableHeight * 0.92, 720)
        let panelHeight = min(max(rawHeight, 228), maxHeight)
        let panelWidth = min(max(availableWidth * 0.46, 520), 640)

        return PrefixIndicatorLayout(
            panelWidth: panelWidth.rounded(.up),
            panelHeight: panelHeight.rounded(.up),
            columnCount: columnCount,
            showsScrollableHelpList: false
        )
    }
}
