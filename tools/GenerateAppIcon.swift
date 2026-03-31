import AppKit
import Foundation

struct IconSpec {
    let filename: String
    let pixelSize: Int
}

private let specs: [IconSpec] = [
    .init(filename: "icon_16x16.png", pixelSize: 16),
    .init(filename: "icon_16x16@2x.png", pixelSize: 32),
    .init(filename: "icon_32x32.png", pixelSize: 32),
    .init(filename: "icon_32x32@2x.png", pixelSize: 64),
    .init(filename: "icon_128x128.png", pixelSize: 128),
    .init(filename: "icon_128x128@2x.png", pixelSize: 256),
    .init(filename: "icon_256x256.png", pixelSize: 256),
    .init(filename: "icon_256x256@2x.png", pixelSize: 512),
    .init(filename: "icon_512x512.png", pixelSize: 512),
    .init(filename: "icon_512x512@2x.png", pixelSize: 1024)
]

private let outputDirectory: URL = {
    if CommandLine.arguments.count > 1 {
        return URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("CapsNav/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
}()

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    for spec in specs {
        let imageData = try makePNG(sideLength: spec.pixelSize)
        try imageData.write(to: outputDirectory.appendingPathComponent(spec.filename), options: .atomic)
    }

    print("Generated \(specs.count) app icon images in \(outputDirectory.path)")
} catch {
    fputs("Failed to generate app icons: \(error.localizedDescription)\n", stderr)
    exit(1)
}

private func makePNG(sideLength: Int) throws -> Data {
    let pixelsWide = sideLength
    let pixelsHigh = sideLength

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelsWide,
        pixelsHigh: pixelsHigh,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconGenerationError.bitmapCreationFailed
    }

    bitmap.size = NSSize(width: sideLength, height: sideLength)

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        throw IconGenerationError.graphicsContextCreationFailed
    }

    NSGraphicsContext.current = context
    context.cgContext.setShouldAntialias(true)
    context.imageInterpolation = .high

    let canvas = NSRect(x: 0, y: 0, width: sideLength, height: sideLength)
    drawIcon(in: canvas)

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.pngEncodingFailed
    }

    return pngData
}

private func drawIcon(in rect: NSRect) {
    NSColor.clear.setFill()
    rect.fill()

    let outerInset = rect.width * 0.055
    let iconRect = rect.insetBy(dx: outerInset, dy: outerInset)
    let iconRadius = rect.width * 0.23
    let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: iconRadius, yRadius: iconRadius)

    NSGraphicsContext.saveGraphicsState()
    let backgroundShadow = NSShadow()
    backgroundShadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
    backgroundShadow.shadowBlurRadius = rect.width * 0.08
    backgroundShadow.shadowOffset = NSSize(width: 0, height: -(rect.width * 0.03))
    backgroundShadow.set()
    NSColor.black.withAlphaComponent(0.12).setFill()
    iconPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let backgroundGradient = NSGradient(
        colorsAndLocations:
            (NSColor(hex: 0x0D3B66), 0.0),
            (NSColor(hex: 0x0E7490), 0.42),
            (NSColor(hex: 0x22A6C8), 1.0)
    )
    backgroundGradient?.draw(in: iconPath, angle: -42)

    NSGraphicsContext.saveGraphicsState()
    iconPath.addClip()
    drawGlow(
        in: NSRect(
            x: iconRect.minX - rect.width * 0.08,
            y: iconRect.maxY - rect.width * 0.34,
            width: rect.width * 0.56,
            height: rect.width * 0.56
        ),
        color: NSColor(hex: 0xA5F3FC, alpha: 0.42)
    )

    drawGlow(
        in: NSRect(
            x: iconRect.maxX - rect.width * 0.38,
            y: iconRect.minY - rect.width * 0.02,
            width: rect.width * 0.34,
            height: rect.width * 0.34
        ),
        color: NSColor(hex: 0xF7B955, alpha: 0.18)
    )
    NSGraphicsContext.restoreGraphicsState()

    let keyRect = NSRect(
        x: rect.minX + rect.width * 0.24,
        y: rect.minY + rect.height * 0.22,
        width: rect.width * 0.52,
        height: rect.height * 0.56
    )
    let keyRadius = rect.width * 0.12
    let keyPath = NSBezierPath(roundedRect: keyRect, xRadius: keyRadius, yRadius: keyRadius)

    NSGraphicsContext.saveGraphicsState()
    let keyShadow = NSShadow()
    keyShadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
    keyShadow.shadowBlurRadius = rect.width * 0.05
    keyShadow.shadowOffset = NSSize(width: 0, height: -(rect.width * 0.015))
    keyShadow.set()
    NSColor.white.withAlphaComponent(0.6).setFill()
    keyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let keyGradient = NSGradient(
        colorsAndLocations:
            (NSColor(hex: 0xFFFFFF, alpha: 0.98), 0.0),
            (NSColor(hex: 0xE9F6FB, alpha: 0.98), 0.52),
            (NSColor(hex: 0xD6EAF4, alpha: 0.98), 1.0)
    )
    keyGradient?.draw(in: keyPath, angle: -90)

    NSColor(hex: 0xFFFFFF, alpha: 0.82).setStroke()
    keyPath.lineWidth = max(1.25, rect.width * 0.017)
    keyPath.stroke()

    let innerHighlightRect = keyRect.insetBy(dx: rect.width * 0.035, dy: rect.width * 0.035)
    let innerHighlightPath = NSBezierPath(
        roundedRect: innerHighlightRect,
        xRadius: rect.width * 0.08,
        yRadius: rect.width * 0.08
    )
    NSColor(hex: 0xFFFFFF, alpha: 0.18).setStroke()
    innerHighlightPath.lineWidth = max(0.8, rect.width * 0.008)
    innerHighlightPath.stroke()

    drawCapsSymbol(in: keyRect, canvasRect: rect)
    drawStatusLight(in: iconRect, canvasRect: rect)

    if rect.width >= 64 {
        drawNavigationCross(in: keyRect, canvasRect: rect)
    }

    NSColor.white.withAlphaComponent(0.16).setStroke()
    iconPath.lineWidth = max(1.1, rect.width * 0.012)
    iconPath.stroke()
}

private func drawCapsSymbol(in keyRect: NSRect, canvasRect: NSRect) {
    let symbolColor = NSColor(hex: 0x0E7490)

    let arrowPath = NSBezierPath()
    let arrowTop = CGPoint(x: keyRect.midX, y: keyRect.maxY - keyRect.height * 0.20)
    let arrowLeft = CGPoint(x: keyRect.midX - keyRect.width * 0.17, y: keyRect.maxY - keyRect.height * 0.39)
    let arrowStemLeft = CGPoint(x: keyRect.midX - keyRect.width * 0.07, y: keyRect.maxY - keyRect.height * 0.39)
    let arrowStemBottomLeft = CGPoint(x: keyRect.midX - keyRect.width * 0.07, y: keyRect.minY + keyRect.height * 0.34)
    let arrowStemBottomRight = CGPoint(x: keyRect.midX + keyRect.width * 0.07, y: keyRect.minY + keyRect.height * 0.34)
    let arrowStemRight = CGPoint(x: keyRect.midX + keyRect.width * 0.07, y: keyRect.maxY - keyRect.height * 0.39)
    let arrowRight = CGPoint(x: keyRect.midX + keyRect.width * 0.17, y: keyRect.maxY - keyRect.height * 0.39)

    arrowPath.move(to: arrowTop)
    arrowPath.line(to: arrowLeft)
    arrowPath.line(to: arrowStemLeft)
    arrowPath.line(to: arrowStemBottomLeft)
    arrowPath.line(to: arrowStemBottomRight)
    arrowPath.line(to: arrowStemRight)
    arrowPath.line(to: arrowRight)
    arrowPath.close()

    symbolColor.setFill()
    arrowPath.fill()

    let barRect = NSRect(
        x: keyRect.midX - keyRect.width * 0.18,
        y: keyRect.minY + keyRect.height * 0.16,
        width: keyRect.width * 0.36,
        height: max(2.2, canvasRect.width * 0.028)
    )
    let barPath = NSBezierPath(
        roundedRect: barRect,
        xRadius: barRect.height / 2,
        yRadius: barRect.height / 2
    )
    barPath.fill()
}

private func drawStatusLight(in iconRect: NSRect, canvasRect: NSRect) {
    let size = max(2.5, canvasRect.width * 0.10)
    let lightRect = NSRect(
        x: iconRect.minX + iconRect.width * 0.15,
        y: iconRect.maxY - iconRect.height * 0.27,
        width: size,
        height: size
    )

    drawGlow(
        in: lightRect.insetBy(dx: -size * 0.55, dy: -size * 0.55),
        color: NSColor(hex: 0xFFD998, alpha: 0.38)
    )

    let lightPath = NSBezierPath(ovalIn: lightRect)
    NSColor(hex: 0xFFD27A).setFill()
    lightPath.fill()

    NSColor.white.withAlphaComponent(0.6).setStroke()
    lightPath.lineWidth = max(0.7, canvasRect.width * 0.006)
    lightPath.stroke()
}

private func drawNavigationCross(in keyRect: NSRect, canvasRect: NSRect) {
    let center = CGPoint(
        x: keyRect.maxX - keyRect.width * 0.16,
        y: keyRect.minY + keyRect.height * 0.18
    )
    let armLength = canvasRect.width * 0.078
    let armThickness = max(3.2, canvasRect.width * 0.026)
    let armRadius = armThickness / 2
    let color = NSColor(hex: 0x0E7490, alpha: 0.9)

    let horizontalRect = NSRect(
        x: center.x - armLength / 2,
        y: center.y - armThickness / 2,
        width: armLength,
        height: armThickness
    )
    let verticalRect = NSRect(
        x: center.x - armThickness / 2,
        y: center.y - armLength / 2,
        width: armThickness,
        height: armLength
    )

    color.setFill()
    NSBezierPath(roundedRect: horizontalRect, xRadius: armRadius, yRadius: armRadius).fill()
    NSBezierPath(roundedRect: verticalRect, xRadius: armRadius, yRadius: armRadius).fill()

    let centerDotRect = NSRect(
        x: center.x - armThickness * 0.28,
        y: center.y - armThickness * 0.28,
        width: armThickness * 0.56,
        height: armThickness * 0.56
    )
    NSColor.white.withAlphaComponent(0.82).setFill()
    NSBezierPath(ovalIn: centerDotRect).fill()
}

private func drawGlow(in rect: NSRect, color: NSColor) {
    let glowPath = NSBezierPath(ovalIn: rect)
    NSGraphicsContext.saveGraphicsState()
    color.setFill()
    glowPath.fill()
    NSGraphicsContext.restoreGraphicsState()
}

private enum IconGenerationError: Error {
    case bitmapCreationFailed
    case graphicsContextCreationFailed
    case pngEncodingFailed
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
