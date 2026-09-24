import ServiceManagement
import SwiftUI

/// What the panel draws. Only publishes while the panel is open: SwiftUI keeps
/// the panel's views alive after it closes, and redrawing the charts there on
/// every tick costs ~75MB of GPU memory for nothing.
@MainActor
final class PanelModel: ObservableObject {
    @Published private(set) var sample: MemorySample?
    @Published private(set) var history: [HistoryPoint] = []

    private var latest: (sample: MemorySample?, history: [HistoryPoint]) = (nil, [])

    var isVisible = false {
        didSet { if isVisible { publish() } }
    }

    func update(sample: MemorySample?, history: [HistoryPoint]) {
        latest = (sample, history)
        if isVisible { publish() }
    }

    private func publish() {
        sample = latest.sample
        history = latest.history
    }
}

/// Remembers whether the user wants Launch at login, because macOS can drop the
/// registration when the app is rebuilt (new ad-hoc signature) or replaced.
enum LoginItem {
    private static let key = "launchAtLogin"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: key)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {}
    }

    /// Re-registers on launch if the user wanted it but macOS forgot.
    static func restore() {
        let wanted = UserDefaults.standard.object(forKey: key) as? Bool ?? isEnabled
        if wanted, !isEnabled {
            try? SMAppService.mainApp.register()
        }
        UserDefaults.standard.set(wanted, forKey: key)
    }
}

@MainActor
final class Monitor: ObservableObject {
    @Published private(set) var sample: MemorySample?
    @Published private(set) var barImage: NSImage?
    private var history: [HistoryPoint] = []
    let panel = PanelModel()

    /// Kept short on purpose: a memory monitor shouldn't hoard memory.
    let historyWindow: TimeInterval = 60

    @Published var interval: Double {
        didSet {
            UserDefaults.standard.set(interval, forKey: "refreshInterval")
            restart()
        }
    }

    @Published var stacked: Bool {
        didSet {
            UserDefaults.standard.set(stacked, forKey: "stackedLayout")
            render()
        }
    }

    private var timer: Timer?

    init() {
        UserDefaults.standard.register(defaults: [
            "refreshInterval": 2.0,
            "stackedLayout": true,
        ])
        interval = UserDefaults.standard.double(forKey: "refreshInterval")
        stacked = UserDefaults.standard.bool(forKey: "stackedLayout")
        LoginItem.restore()
        restart()
    }

    /// Single-line form, e.g. "13%/17GB".
    var title: String {
        guard let sample else { return "—" }
        return "\(sample.pressure)%/\(Int(sample.usedGB.rounded()))GB"
    }

    private func restart() {
        timer?.invalidate()
        refresh()

        // .common so the readout keeps ticking while a menu is open.
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        sample = MemoryReader.sample()
        record()
        panel.update(sample: sample, history: history)
        render()
    }

    private func record() {
        guard let sample else { return }
        let now = Date()
        history.append(HistoryPoint(
            date: now,
            pressure: Double(sample.pressure),
            usagePercent: sample.usedGB / sample.totalGB * 100
        ))
        // Keep exactly one point at or beyond the window's left edge, so the
        // chart's line always reaches it instead of leaving a gap.
        let cutoff = now.addingTimeInterval(-historyWindow)
        while history.count > 1, history[1].date <= cutoff {
            history.removeFirst()
        }
    }

    private func render() {
        guard stacked, let sample else {
            barImage = nil
            return
        }
        let pressureLevel = Level(pressure: sample.pressure)
        let usageLevel = Level(usagePercent: Int(sample.usedGB / sample.totalGB * 100))

        // Stay a template while both are normal so macOS adapts it to the menu bar.
        // Once either crosses a threshold, colors must survive, so the normal line
        // gets an explicit color matching the current appearance.
        // Ask the menu bar itself: an LSUIElement app can report light while the bar is dark.
        let barAppearance = NSApp.windows
            .first { $0.className.contains("NSStatusBarWindow") }?
            .effectiveAppearance ?? NSApp.effectiveAppearance
        let isDark = barAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        barImage = StackedReadout.image(
            sample: sample,
            pressureLevel: pressureLevel,
            usageLevel: usageLevel,
            base: isDark ? .white : .black,
            template: pressureLevel == .normal && usageLevel == .normal
        )
    }
}

struct MenuContent: View {
    /// Not observed: the panel redraws from `panel`, which is quiet while closed.
    let monitor: Monitor
    @ObservedObject var panel: PanelModel
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let sample = panel.sample {
                // Pressure on top, usage below: same order as the two lines in the bar.
                VStack(alignment: .leading, spacing: 4) {
                    stat("Pressure", "\(sample.pressure)%", color: pressureColor)
                    SeriesChart(history: panel.history, value: \.pressure,
                                color: pressureColor, window: monitor.historyWindow)
                        .frame(height: 60)
                }

                VStack(alignment: .leading, spacing: 4) {
                    stat("Used", String(format: "%.2f / %.0f GB", sample.usedGB, sample.totalGB),
                         color: usageColor)
                    SeriesChart(history: panel.history, value: \.usagePercent,
                                color: usageColor, window: monitor.historyWindow,
                                showsTimeLabels: true)
                        .frame(height: 75)
                }
            } else {
                Text("Reading memory failed")
            }

            Divider()

            HStack {
                // Rarely-touched settings live behind the gear to keep the panel about the data.
                Menu {
                    Toggle("Stacked layout", isOn: Binding(get: { monitor.stacked }, set: { monitor.stacked = $0 }))
                    Toggle("Launch at login", isOn: launchAtLoginBinding)
                    Picker("Refresh", selection: Binding(get: { monitor.interval }, set: { monitor.interval = $0 })) {
                        Text("1 second").tag(1.0)
                        Text("2 seconds").tag(2.0)
                        Text("5 seconds").tag(5.0)
                        Text("10 seconds").tag(10.0)
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Spacer()

                Button("Quit MemBar") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { panel.isVisible = true }
        .onDisappear { panel.isVisible = false }
    }

    // Series color while normal, orange/red once the current value crosses its threshold.
    private var pressureColor: Color {
        Level(pressure: panel.sample?.pressure ?? 0).color(base: SeriesColor.pressure)
    }

    private var usageColor: Color {
        guard let sample = panel.sample else { return SeriesColor.usage }
        return Level(usagePercent: Int(sample.usedGB / sample.totalGB * 100))
            .color(base: SeriesColor.usage)
    }

    /// Chart title; the dot matches the chart color.
    private func stat(_ label: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
        .font(.system(size: 12).monospacedDigit())
    }

    /// Registers with the system directly; toggles inside a Menu don't reliably fire onChange.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                LoginItem.set(enabled)
                launchAtLogin = LoginItem.isEnabled
            }
        )
    }
}

@main
struct MemBarApp: App {
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: monitor, panel: monitor.panel)
        } label: {
            if let barImage = monitor.barImage {
                Image(nsImage: barImage)
            } else {
                // Monospaced digits so the width doesn't jitter as numbers change.
                Text(monitor.title)
                    .font(.system(size: 13).monospacedDigit())
            }
        }
        // .window so the panel can host a live chart; a plain menu can't.
        .menuBarExtraStyle(.window)
    }
}
