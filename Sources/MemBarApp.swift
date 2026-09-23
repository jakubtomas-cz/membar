import ServiceManagement
import SwiftUI

@MainActor
final class Monitor: ObservableObject {
    @Published private(set) var sample: MemorySample?
    @Published private(set) var barImage: NSImage?

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
        render()
    }

    private func render() {
        guard stacked, let sample else {
            barImage = nil
            return
        }
        barImage = StackedReadout(sample: sample).renderedAsTemplate()
    }
}

struct MenuContent: View {
    @ObservedObject var monitor: Monitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        if let sample = monitor.sample {
            Text("Pressure: \(sample.pressure)%")
            Text(String(format: "Used: %.2f / %.2f GB", sample.usedGB, sample.totalGB))
        } else {
            Text("Reading memory failed")
        }

        Divider()

        Toggle("Stacked Layout", isOn: $monitor.stacked)

        Picker("Refresh", selection: $monitor.interval) {
            Text("1 second").tag(1.0)
            Text("2 seconds").tag(2.0)
            Text("5 seconds").tag(5.0)
            Text("10 seconds").tag(10.0)
        }

        Toggle("Launch at Login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }

        Divider()

        Button("Quit MemBar") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@main
struct MemBarApp: App {
    @StateObject private var monitor = Monitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: monitor)
        } label: {
            if let barImage = monitor.barImage {
                Image(nsImage: barImage)
            } else {
                // Monospaced digits so the width doesn't jitter as numbers change.
                Text(monitor.title)
                    .font(.system(size: 13).monospacedDigit())
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
