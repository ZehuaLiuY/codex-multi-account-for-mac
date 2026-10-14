import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent(".build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    NSGraphicsContext.current?.imageInterpolation = .high
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 36
    shadow.shadowOffset = NSSize(width: 0, height: -13)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor(srgbRed: 0.15, green: 0.18, blue: 0.16, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 96, y: 96, width: 832, height: 832), xRadius: 185, yRadius: 185).fill()
    NSGraphicsContext.restoreGraphicsState()
    // Three open layers echo the native square.stack.3d.up symbol.
    NSColor(srgbRed: 0.94, green: 0.96, blue: 0.92, alpha: 1).setStroke()
    for y: CGFloat in [440, 350] {
        let layer = NSBezierPath()
        layer.lineWidth = 26
        layer.lineJoinStyle = .round
        layer.lineCapStyle = .round
        layer.move(to: NSPoint(x: 300, y: y + 90))
        layer.line(to: NSPoint(x: 512, y: y - 10))
        layer.line(to: NSPoint(x: 724, y: y + 90))
        layer.stroke()
    }
    let top = NSBezierPath()
    top.lineWidth = 26
    top.lineJoinStyle = .round
    top.move(to: NSPoint(x: 300, y: 620))
    top.line(to: NSPoint(x: 512, y: 720))
    top.line(to: NSPoint(x: 724, y: 620))
    top.line(to: NSPoint(x: 512, y: 520))
    top.close()
    top.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for logicalSize in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let suffix = factor == 2 ? "@2x" : ""
        try drawIcon(size: logicalSize * factor).write(to: iconset.appendingPathComponent("icon_\(logicalSize)x\(logicalSize)\(suffix).png"))
    }
}
print(iconset.path)
