import AppKit
import Foundation

private enum DMGBackgroundError: Error {
    case missingOutputPath
    case bitmapCreationFailed
    case graphicsContextCreationFailed
    case pngEncodingFailed
}

private let canvasSize = NSSize(width: 920, height: 540)

do {
    let outputURL = try resolveOutputURL()
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let imageData = try makePNG(size: canvasSize)
    try imageData.write(to: outputURL, options: .atomic)
    print("Generated DMG background at \(outputURL.path)")
} catch {
    fputs("Failed to generate DMG background: \(error.localizedDescription)\n", stderr)
    exit(1)
}

private func resolveOutputURL() throws -> URL {
    guard CommandLine.arguments.count > 1 else {
        throw DMGBackgroundError.missingOutputPath
    }

    return URL(fileURLWithPath: CommandLine.arguments[1])
}

private func makePNG(size: NSSize) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw DMGBackgroundError.bitmapCreationFailed
    }

    bitmap.size = size

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        throw DMGBackgroundError.graphicsContextCreationFailed
    }

    NSGraphicsContext.current = context
    context.cgContext.setShouldAntialias(true)
    context.imageInterpolation = .high

    drawBackground(in: NSRect(origin: .zero, size: size))

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw DMGBackgroundError.pngEncodingFailed
    }

    return pngData
}

private func drawBackground(in rect: NSRect) {
    NSColor.clear.setFill()
    rect.fill()

    drawBaseGradient(in: rect)
    drawAmbientGlows(in: rect)
    drawRightInstallPanel(in: rect)
    drawBrandHero(in: rect)
    drawInstallHint(in: rect)
    drawDragArrow(in: rect)
    drawLightOverlays(in: rect)
}

private func drawBaseGradient(in rect: NSRect) {
    let gradient = NSGradient(
        colorsAndLocations:
            (NSColor(hex: 0x07111D), 0.0),
            (NSColor(hex: 0x0D2234), 0.46),
            (NSColor(hex: 0x102A3F), 1.0)
    )
    gradient?.draw(in: rect, angle: -22)
}

private func drawAmbientGlows(in rect: NSRect) {
    drawGlow(
        in: NSRect(x: -110, y: rect.height - 330, width: 420, height: 420),
        color: NSColor(hex: 0x3CC7E8, alpha: 0.32)
    )
    drawGlow(
        in: NSRect(x: 80, y: 70, width: 320, height: 320),
        color: NSColor(hex: 0x0EA5C6, alpha: 0.22)
    )
    drawGlow(
        in: NSRect(x: 275, y: 120, width: 220, height: 220),
        color: NSColor(hex: 0xF8C36B, alpha: 0.12)
    )
}

private func drawRightInstallPanel(in rect: NSRect) {
    let panelRect = NSRect(x: 380, y: 58, width: 490, height: 424)
    let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 28, yRadius: 28)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -16)
    shadow.set()
    NSColor.black.withAlphaComponent(0.12).setFill()
    panelPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    let panelGradient = NSGradient(
        colorsAndLocations:
            (NSColor(hex: 0x183149, alpha: 0.94), 0.0),
            (NSColor(hex: 0x12293F, alpha: 0.96), 0.58),
            (NSColor(hex: 0x112438, alpha: 0.98), 1.0)
    )
    panelGradient?.draw(in: panelPath, angle: -90)

    NSColor(hex: 0x5AD4F0, alpha: 0.22).setStroke()
    panelPath.lineWidth = 1.4
    panelPath.stroke()

    let innerGlowPath = NSBezierPath(roundedRect: panelRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 26, yRadius: 26)
    NSColor.white.withAlphaComponent(0.06).setStroke()
    innerGlowPath.lineWidth = 1
    innerGlowPath.stroke()

    let divider = NSBezierPath()
    divider.move(to: CGPoint(x: panelRect.minX + 28, y: panelRect.maxY - 96))
    divider.line(to: CGPoint(x: panelRect.maxX - 28, y: panelRect.maxY - 96))
    NSColor.white.withAlphaComponent(0.08).setStroke()
    divider.lineWidth = 1
    divider.stroke()

    let installAreaRect = NSRect(x: 404, y: 92, width: 442, height: 274)
    let installAreaPath = NSBezierPath(roundedRect: installAreaRect, xRadius: 24, yRadius: 24)
    let installAreaGradient = NSGradient(
        colorsAndLocations:
            (NSColor(hex: 0xF1F9FD, alpha: 0.98), 0.0),
            (NSColor(hex: 0xE3F0F8, alpha: 0.99), 0.48),
            (NSColor(hex: 0xD7E7F2, alpha: 1.0), 1.0)
    )
    installAreaGradient?.draw(in: installAreaPath, angle: -90)

    NSColor(hex: 0xFFFFFF, alpha: 0.55).setStroke()
    installAreaPath.lineWidth = 1.2
    installAreaPath.stroke()

    let areaHighlight = NSBezierPath(roundedRect: installAreaRect.insetBy(dx: 1.5, dy: 1.5), xRadius: 22, yRadius: 22)
    NSColor(hex: 0xFFFFFF, alpha: 0.22).setStroke()
    areaHighlight.lineWidth = 1
    areaHighlight.stroke()

    let areaTopSheen = NSBezierPath(roundedRect: NSRect(x: installAreaRect.minX + 16, y: installAreaRect.maxY - 72, width: installAreaRect.width - 32, height: 48), xRadius: 18, yRadius: 18)
    let areaTopGradient = NSGradient(
        colorsAndLocations:
            (NSColor.white.withAlphaComponent(0.24), 0.0),
            (NSColor.white.withAlphaComponent(0.02), 1.0)
    )
    areaTopGradient?.draw(in: areaTopSheen, angle: -90)

    drawGlow(
        in: NSRect(x: installAreaRect.minX + 10, y: installAreaRect.midY - 78, width: 156, height: 156),
        color: NSColor(hex: 0xFFFFFF, alpha: 0.18)
    )
    drawGlow(
        in: NSRect(x: installAreaRect.maxX - 166, y: installAreaRect.midY - 78, width: 156, height: 156),
        color: NSColor(hex: 0xFFFFFF, alpha: 0.18)
    )
}

private func drawBrandHero(in rect: NSRect) {
    let haloRect = NSRect(x: 84, y: 136, width: 238, height: 238)
    let haloPath = NSBezierPath(ovalIn: haloRect)
    let haloGradient = NSGradient(
        colorsAndLocations:
            (NSColor(hex: 0x2FDBF3, alpha: 0.34), 0.0),
            (NSColor(hex: 0x0E7490, alpha: 0.04), 1.0)
    )
    haloGradient?.draw(in: haloPath, relativeCenterPosition: NSPoint(x: 0, y: 0))

    let ringPath = NSBezierPath(ovalIn: haloRect.insetBy(dx: 10, dy: 10))
    NSColor(hex: 0x6AE8F8, alpha: 0.18).setStroke()
    ringPath.lineWidth = 1.5
    ringPath.stroke()

    if let iconImage = loadAppIcon() {
        let iconRect = NSRect(x: 110, y: 164, width: 184, height: 184)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -14)
        shadow.set()
        iconImage.draw(in: iconRect)
        NSGraphicsContext.restoreGraphicsState()
    }

    drawNavigationLines(in: rect)
}

private func drawNavigationLines(in rect: NSRect) {
    let accent = NSColor(hex: 0x5AD4F0, alpha: 0.18)
    let secondary = NSColor(hex: 0xF4C976, alpha: 0.10)

    let horizontal = NSBezierPath()
    horizontal.move(to: CGPoint(x: 54, y: 268))
    horizontal.line(to: CGPoint(x: 360, y: 268))
    accent.setStroke()
    horizontal.lineWidth = 1.5
    horizontal.stroke()

    let vertical = NSBezierPath()
    vertical.move(to: CGPoint(x: 208, y: 96))
    vertical.line(to: CGPoint(x: 208, y: 438))
    accent.setStroke()
    vertical.lineWidth = 1.5
    vertical.stroke()

    for point in [
        CGPoint(x: 90, y: 268),
        CGPoint(x: 326, y: 268),
        CGPoint(x: 208, y: 130),
        CGPoint(x: 208, y: 404)
    ] {
        let nodeRect = NSRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
        let nodePath = NSBezierPath(ovalIn: nodeRect)
        secondary.setFill()
        nodePath.fill()
        accent.setStroke()
        nodePath.lineWidth = 1
        nodePath.stroke()
    }
}

private func drawInstallHint(in rect: NSRect) {
    let hintRect = NSRect(x: 420, y: 374, width: 410, height: 48)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let attributed = NSAttributedString(
        string: "拖动到 Applications 即可安装",
        attributes: [
            .font: NSFont(name: "PingFang SC Semibold", size: 28) ?? NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor(hex: 0xF2FBFF),
            .paragraphStyle: paragraph,
            .kern: 0.2
        ]
    )

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 10
    shadow.shadowOffset = NSSize(width: 0, height: -4)
    shadow.set()
    attributed.draw(in: hintRect)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawDragArrow(in rect: NSRect) {
    let arrowPath = NSBezierPath()
    arrowPath.move(to: CGPoint(x: 600, y: 224))
    arrowPath.curve(
        to: CGPoint(x: 690, y: 224),
        controlPoint1: CGPoint(x: 628, y: 236),
        controlPoint2: CGPoint(x: 660, y: 236)
    )

    NSGraphicsContext.saveGraphicsState()
    let dash: [CGFloat] = [8, 10]
    arrowPath.setLineDash(dash, count: dash.count, phase: 0)
    NSColor(hex: 0x8DE9FA, alpha: 0.72).setStroke()
    arrowPath.lineWidth = 4
    arrowPath.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let arrowHead = NSBezierPath()
    arrowHead.move(to: CGPoint(x: 706, y: 224))
    arrowHead.line(to: CGPoint(x: 684, y: 236))
    arrowHead.line(to: CGPoint(x: 688, y: 224))
    arrowHead.line(to: CGPoint(x: 684, y: 212))
    arrowHead.close()
    NSColor(hex: 0x8DE9FA, alpha: 0.82).setFill()
    arrowHead.fill()
}

private func drawLightOverlays(in rect: NSRect) {
    let topHighlight = NSBezierPath()
    topHighlight.move(to: CGPoint(x: 0, y: rect.height - 1))
    topHighlight.line(to: CGPoint(x: rect.width, y: rect.height - 1))
    NSColor.white.withAlphaComponent(0.06).setStroke()
    topHighlight.lineWidth = 1
    topHighlight.stroke()

    let rightGlow = NSBezierPath(roundedRect: NSRect(x: 404, y: 82, width: 442, height: 374), xRadius: 24, yRadius: 24)
    NSColor(hex: 0x94F2FF, alpha: 0.04).setStroke()
    rightGlow.lineWidth = 18
    rightGlow.stroke()
}

private func drawGlow(in rect: NSRect, color: NSColor) {
    let path = NSBezierPath(ovalIn: rect)
    let gradient = NSGradient(
        colorsAndLocations:
            (color, 0.0),
            (color.withAlphaComponent(0.0), 1.0)
    )
    gradient?.draw(in: path, relativeCenterPosition: .zero)
}

private func loadAppIcon() -> NSImage? {
    let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    let iconURL = repoRoot
        .appendingPathComponent("Caps Nav", isDirectory: true)
        .appendingPathComponent("Assets.xcassets", isDirectory: true)
        .appendingPathComponent("AppIcon.appiconset", isDirectory: true)
        .appendingPathComponent("icon-512.png")

    return NSImage(contentsOf: iconURL)
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
