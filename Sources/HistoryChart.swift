import Charts
import SwiftUI

struct HistoryPoint: Identifiable {
    let date: Date
    let pressure: Int
    let usagePercent: Double

    var id: Date { date }
}

/// Rolling chart: usage (as % of total RAM) as a filled area,
/// pressure as a line on the same 0–100% scale.
struct HistoryChart: View {
    let history: [HistoryPoint]

    var body: some View {
        Chart(history) { point in
            AreaMark(
                x: .value("Time", point.date),
                y: .value("Percent", point.usagePercent)
            )
            .foregroundStyle(by: .value("Series", "Usage"))
            .opacity(0.35)

            LineMark(
                x: .value("Time", point.date),
                y: .value("Percent", point.pressure),
                series: .value("Series", "Pressure")
            )
            .foregroundStyle(by: .value("Series", "Pressure"))
        }
        .chartForegroundStyleScale(["Pressure": Color.purple, "Usage": Color.blue])
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let percent = value.as(Int.self) { Text("\(percent)%") }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartLegend(position: .top, alignment: .leading)
    }
}
