import SwiftUI
import Charts

/// Compact 7-day calorie bar chart with a target reference line.
/// For full-size progress charts, see ProgressTabView's CalorieChartSection.
struct CalorieMiniChart: View {
    let points: [DailyCaloriePoint]
    let target: Double

    // Bars turn red when calories exceed target by this amount (mirrors CalorieChartSection).
    private let overageThreshold: Double = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("7-day calories")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(points) { pt in
                    BarMark(
                        x: .value("Day", pt.date, unit: .day),
                        y: .value("Cal", pt.calories)
                    )
                    .foregroundStyle(pt.calories > target + overageThreshold ? Color.red.opacity(0.7) : Color.orange.opacity(0.8))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Target", target))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 4)
                    }
            }
            .frame(height: 80)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .font(.caption2)
                }
            }
            .chartYAxis(.hidden)
        }
        .padding(.vertical, 4)
    }
}
