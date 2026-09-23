import AppKit
import SwiftUI

/// Two-line bar layout: pressure top-left, usage bottom-right.
/// Sized to fit inside the ~22pt menu bar.
struct StackedReadout: View {
    let sample: MemorySample

    private let width: CGFloat = 30
    private let lineHeight: CGFloat = 9.5

    var body: some View {
        VStack(spacing: 0) {
            Text("\(sample.pressure)%")
                .frame(width: width, height: lineHeight, alignment: .leading)
            Text("\(Int(sample.usedGB.rounded()))GB")
                .frame(width: width, height: lineHeight, alignment: .trailing)
        }
        // Monospaced digits keep the item from shifting as values change.
        .font(.system(size: 9, weight: .medium).monospacedDigit())
    }
}

extension View {
    /// Rasterizes the view for the menu bar. Template mode lets macOS handle
    /// light/dark and the dimmed state while the menu is open.
    @MainActor
    func renderedAsTemplate() -> NSImage? {
        let renderer = ImageRenderer(content: self)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        renderer.scale = scale

        guard let cgImage = renderer.cgImage else { return nil }
        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: CGFloat(cgImage.width) / scale,
                         height: CGFloat(cgImage.height) / scale)
        )
        image.isTemplate = true
        return image
    }
}
