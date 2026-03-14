import SwiftUI
import Charts

/// Compact 7-day weight trend chart for use inside a List row.
/// For full-size progress charts, see ProgressTabView's WeightChartSection.
struct WeightSparkline: View {
    let points: [DailyWeightPoint]
    let unit: WeightUnit

    private var displayPoints: [(date: Date, value: Double)] {
        points.map { (date: $0.date, value: unit.convert($0.weightKg)) }
    }

    private var yDomain: ClosedRange<Double> {
        let values = displayPoints.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        let pad = Swift.max(0.3, (hi - lo) * 0.4)
        return (lo - pad)...(hi + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("7-day weight")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(displayPoints, id: \.date) { pt in
                    AreaMark(
                        x: .value("Day", pt.date, unit: .day),
                        y: .value("Weight", pt.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .blue.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Day", pt.date, unit: .day),
                        y: .value("Weight", pt.value)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", pt.date, unit: .day),
                        y: .value("Weight", pt.value)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(20)
                }
            }
            .frame(height: 70)
            .chartYScale(domain: yDomain)
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
