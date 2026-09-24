import Charts
import SwiftUI

struct HistoryPoint: Identifiable {
    let date: Date
    let pressure: Double
    let usagePercent: Double

    var id: Date { date }
}

enum SeriesColor {
    static let pressure = Color.purple
    static let usage = Color.blue
}

/// One metric over the rolling window, as a filled area with a line on top,
/// on a fixed 0–100% scale so the two stacked charts compare at a glance.
struct SeriesChart: View {
    let history: [HistoryPoint]
    let value: KeyPath<HistoryPoint, Double>
    let color: Color
    let window: TimeInterval
    var showsTimeLabels = false

    var body: some View {
        let end = history.last?.date ?? Date()
        let start = end.addingTimeInterval(-window)

        Chart(history) { point in
            AreaMark(
                x: .value("Time", point.date),
                y: .value("Percent", point[keyPath: value])
            )
            .foregroundStyle(color.opacity(0.25))
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Time", point.date),
                y: .value("Percent", point[keyPath: value])
            )
            .foregroundStyle(color)
            .interpolationMethod(.monotone)
        }
        // Fixed window so the chart scrolls instead of stretching while history fills.
        .chartXScale(domain: start...end)
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { mark in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = mark.as(Int.self) { Text("\(percent)%") }
                }
            }
        }
        // Labels as axis marks so they line up with the plot, not the y-axis labels.
        .chartXAxis {
            if showsTimeLabels {
                AxisMarks(values: [start, end]) { mark in
                    let isStart = mark.as(Date.self) == start
                    AxisValueLabel(anchor: isStart ? .topLeading : .topTrailing) {
                        Text(isStart ? "\(Int(window / 60)) min ago" : "now")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
