import AppKit
import SwiftUI

/// Percent thresholds for turning orange (warning) and red (critical).
enum Thresholds {
    static let pressure = (warning: 70, critical: 85)
    /// Usage runs high by design on macOS, so it gets later thresholds.
    static let usage = (warning: 80, critical: 90)
}

extension Level {
    init(pressure: Int) {
        self.init(percent: pressure, warning: Thresholds.pressure.warning,
                  critical: Thresholds.pressure.critical)
    }

    init(usagePercent: Int) {
        self.init(percent: usagePercent, warning: Thresholds.usage.warning,
                  critical: Thresholds.usage.critical)
    }
}

/// Normal / warning / critical, from caller-supplied percent thresholds.
enum Level {
    case normal, warning, critical

    init(percent: Int, warning: Int, critical: Int) {
        switch percent {
        case ..<warning: self = .normal
        case ..<critical: self = .warning
        default: self = .critical
        }
    }

    func color(base: Color) -> Color {
        Color(nsColor: nsColor(base: NSColor(base)))
    }

    func nsColor(base: NSColor) -> NSColor {
        switch self {
        case .normal: base
        case .warning: .systemOrange
        case .critical: .systemRed
        }
    }
}

/// Two-line bar layout: pressure top-left, usage bottom-right, sized for
/// the ~22pt menu bar. Drawn with plain CoreGraphics rather than SwiftUI's
/// ImageRenderer, which spins up GPU buffers (~75MB) on every refresh.
enum StackedReadout {
    private static let size = NSSize(width: 30, height: 21)
    private static let lineHeight: CGFloat = 10.5
    // Monospaced digits keep the item from shifting as values change.
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)

    /// As a template, macOS handles light/dark and the dimmed state while the
    /// menu is open; non-template keeps the given colors.
    static func image(
        sample: MemorySample,
        pressureLevel: Level,
        usageLevel: Level,
        base: NSColor,
        template: Bool
    ) -> NSImage {
        let top = text("\(sample.pressure)%", color: pressureLevel.nsColor(base: base))
        let bottom = text("\(Int(sample.usedGB.rounded()))G", color: usageLevel.nsColor(base: base))

        let image = NSImage(size: size, flipped: true) { _ in
            draw(top, line: 0, alignRight: false)
            draw(bottom, line: 1, alignRight: true)
            return true
        }
        image.isTemplate = template
        return image
    }

    private static func text(_ string: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    }

    /// Centers the glyph box vertically in its line, matching the old SwiftUI frames.
    private static func draw(_ text: NSAttributedString, line: Int, alignRight: Bool) {
        let textSize = text.size()
        let x = alignRight ? size.width - textSize.width : 0
        let y = CGFloat(line) * lineHeight + (lineHeight - textSize.height) / 2
        text.draw(at: NSPoint(x: x, y: y))
    }
}
