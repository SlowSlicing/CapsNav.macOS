import CoreGraphics

enum SettingsMappingEffectPreviewPlacementDirection {
    case above
    case below
}

struct SettingsMappingEffectPreviewPlacement: Equatable {
    let origin: CGPoint
    let direction: SettingsMappingEffectPreviewPlacementDirection
}

enum SettingsMappingEffectPreviewLayout {
    static let preferredHorizontalOffset: CGFloat = -128
    static let preferredVerticalGap: CGFloat = 4
    static let padding: CGFloat = 18

    static func placement(
        triggerFrame: CGRect,
        cardSize: CGSize,
        containerBounds: CGRect
    ) -> SettingsMappingEffectPreviewPlacement {
        let fittedCardSize = CGSize(
            width: min(cardSize.width, max(containerBounds.width - (padding * 2), 0)),
            height: min(cardSize.height, max(containerBounds.height - (padding * 2), 0))
        )

        let preferredX = triggerFrame.minX + preferredHorizontalOffset
        let clampedX = clamp(
            preferredX,
            minValue: containerBounds.minX + padding,
            maxValue: containerBounds.maxX - padding - fittedCardSize.width
        )

        let spaceBelow = (containerBounds.maxY - padding) - triggerFrame.maxY
        let spaceAbove = triggerFrame.minY - (containerBounds.minY + padding)
        let requiredHeight = fittedCardSize.height + preferredVerticalGap

        let direction: SettingsMappingEffectPreviewPlacementDirection
        let preferredY: CGFloat

        if spaceBelow >= requiredHeight {
            direction = .below
            preferredY = triggerFrame.maxY + preferredVerticalGap
        } else if spaceAbove >= requiredHeight {
            direction = .above
            preferredY = triggerFrame.minY - preferredVerticalGap - fittedCardSize.height
        } else if spaceBelow >= spaceAbove {
            direction = .below
            preferredY = triggerFrame.maxY + preferredVerticalGap
        } else {
            direction = .above
            preferredY = triggerFrame.minY - preferredVerticalGap - fittedCardSize.height
        }

        let clampedY = clamp(
            preferredY,
            minValue: containerBounds.minY + padding,
            maxValue: containerBounds.maxY - padding - fittedCardSize.height
        )

        return SettingsMappingEffectPreviewPlacement(
            origin: CGPoint(x: clampedX, y: clampedY),
            direction: direction
        )
    }

    private static func clamp(_ value: CGFloat, minValue: CGFloat, maxValue: CGFloat) -> CGFloat {
        guard minValue <= maxValue else {
            return minValue
        }

        return min(max(value, minValue), maxValue)
    }
}
