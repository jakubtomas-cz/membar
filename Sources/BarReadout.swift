import AppKit
import SwiftUI

/// Percent thresholds for turning orange (warning) and red (critical),
/// shared by pressure and usage.
enum Thresholds {
    static let warning = 70
    static let critical = 85
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
        switch self {
        case .normal: base
        case .warning: Color(nsColor: .systemOrange)
        case .critical: Color(nsColor: .systemRed)
        }
    }
}

/// Two-line bar layout: pressure top-left, usage bottom-right.
/// Sized to fit inside the ~22pt menu bar.
struct StackedReadout: View {
    let sample: MemorySample
    let pressureLevel: Level
    let usageLevel: Level
    let base: Color

    private let width: CGFloat = 30
    private let lineHeight: CGFloat = 10.5

    var body: some View {
        VStack(spacing: 0) {
            Text("\(sample.pressure)%")
                .foregroundStyle(pressureLevel.color(base: base))
                .frame(width: width, height: lineHeight, alignment: .leading)
            Text("\(Int(sample.usedGB.rounded()))G")
                .foregroundStyle(usageLevel.color(base: base))
                .frame(width: width, height: lineHeight, alignment: .trailing)
        }
        // Monospaced digits keep the item from shifting as values change.
        .font(.system(size: 10, weight: .medium).monospacedDigit())
    }
}

extension View {
    /// Rasterizes the view for the menu bar. As a template, macOS handles
    /// light/dark and the dimmed state while the menu is open; non-template
    /// keeps the view's own colors.
    @MainActor
    func renderedForMenuBar(template: Bool) -> NSImage? {
        let renderer = ImageRenderer(content: self)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        renderer.scale = scale

        guard let cgImage = renderer.cgImage else { return nil }
        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: CGFloat(cgImage.width) / scale,
                         height: CGFloat(cgImage.height) / scale)
        )
        image.isTemplate = template
        return image
    }
}
