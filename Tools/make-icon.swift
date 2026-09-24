// Draws MemBar's app icon: two stacked mini charts, pressure (purple) on top
// and usage (blue) below, echoing the panel. Usage: swift make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// macOS icon grid: 824pt body centered on the 1024 canvas.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Soft drop shadow, like system icons.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28,
              color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(shape)
ctx.setFillColor(NSColor.black.cgColor)
ctx.fillPath()
ctx.restoreGState()

// Background gradient.
ctx.saveGState()
ctx.addPath(shape)
ctx.clip()
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor(red: 0.20, green: 0.19, blue: 0.29, alpha: 1).cgColor,
    NSColor(red: 0.09, green: 0.09, blue: 0.14, alpha: 1).cgColor,
] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

/// One chart strip: a smooth line through `values` (0...1) with a faded fill beneath.
func strip(_ values: [CGFloat], in rect: CGRect, color: NSColor) {
    let step = rect.width / CGFloat(values.count - 1)
    let points = values.enumerated().map { i, v in
        CGPoint(x: rect.minX + CGFloat(i) * step, y: rect.minY + v * rect.height)
    }
    let line = CGMutablePath()
    line.move(to: points[0])
    for i in 1..<points.count {
        let a = points[i - 1], b = points[i]
        let midX = (a.x + b.x) / 2
        line.addCurve(to: b, control1: CGPoint(x: midX, y: a.y), control2: CGPoint(x: midX, y: b.y))
    }

    let area = line.mutableCopy()!
    area.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    area.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
    area.closeSubpath()
    ctx.saveGState()
    ctx.addPath(area)
    ctx.clip()
    let fill = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        color.withAlphaComponent(0.55).cgColor, color.withAlphaComponent(0.05).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(fill, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
    ctx.restoreGState()

    ctx.addPath(line)
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(26)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}

let inset = body.insetBy(dx: 110, dy: 120)
let gap: CGFloat = 70
let stripHeight = (inset.height - gap) / 2
let top = CGRect(x: inset.minX, y: inset.minY + stripHeight + gap, width: inset.width, height: stripHeight)
let bottom = CGRect(x: inset.minX, y: inset.minY, width: inset.width, height: stripHeight)

strip([0.30, 0.35, 0.28, 0.55, 0.85, 0.60, 0.45, 0.50], in: top,
      color: NSColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 1))
strip([0.45, 0.48, 0.50, 0.70, 0.78, 0.74, 0.72, 0.75], in: bottom,
      color: NSColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1))
ctx.restoreGState()

NSGraphicsContext.current = nil
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
