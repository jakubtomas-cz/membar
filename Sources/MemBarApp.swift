import ServiceManagement
import SwiftUI

@MainActor
final class Monitor: ObservableObject {
    @Published private(set) var sample: MemorySample?

    @Published var interval: Double {
        didSet {
            UserDefaults.standard.set(interval, forKey: "refreshInterval")
            restart()
        }
    }

    private var timer: Timer?

    init() {
        let stored = UserDefaults.standard.double(forKey: "refreshInterval")
        interval = stored > 0 ? stored : 2
        restart()
    }

    /// What shows in the bar, e.g. "13%/15GB".
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
            // Monospaced digits so the width doesn't jitter as numbers change.
            Text(monitor.title)
                .font(.system(size: 13).monospacedDigit())
        }
        .menuBarExtraStyle(.menu)
    }
}
