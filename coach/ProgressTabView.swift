import SwiftUI
import Charts

struct ProgressTabView: View {
    @Environment(AppState.self) private var appState
    @State private var timeRange: ProgressTimeRange = .week
    @State private var caloriePoints: [DailyCaloriePoint] = []
    @State private var weightPoints: [DailyWeightPoint] = []
    @State private var photoCheckIns: [DailyCheckIn] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private let service = ProgressService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Range", selection: $timeRange) {
                        ForEach(ProgressTimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let error = loadError {
                        ContentUnavailableView(
                            "Couldn't load progress",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                    } else {
                        CalorieChartSection(
                            points: caloriePoints,
                            target: appState.nutritionTarget?.calories,
                            timeRange: timeRange
                        )
                        WeightChartSection(
                            points: weightPoints,
                            weightUnit: appState.weightUnit,
                            timeRange: timeRange
                        )
                        PhotosSection(checkIns: photoCheckIns)
                    }
                }
                .padding()
            }
            .navigationTitle("Progress")
            .task(id: timeRange) { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            async let c = service.fetchCaloriePoints(for: timeRange)
            async let ci = service.fetchCheckInData(for: timeRange)
            let (cal, checkInData) = try await (c, ci)
            caloriePoints = cal
            weightPoints = checkInData.weights
            photoCheckIns = checkInData.photos
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Shared Axis Helper

@AxisContentBuilder
private func xAxisContent(for range: ProgressTimeRange) -> some AxisContent {
    switch range {
    case .week:
        AxisMarks(values: .stride(by: .day)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                .font(.caption2)
        }
    case .month:
        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.day(), centered: true)
                .font(.caption2)
        }
    case .year:
        AxisMarks(values: .stride(by: .month)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                .font(.caption2)
        }
    }
}

// MARK: - Calorie Chart

private struct CalorieChartSection: View {
    let points: [DailyCaloriePoint]
    let target: Double?
    let timeRange: ProgressTimeRange

    var body: some View {
        ChartCard(title: "Calories", systemImage: "flame.fill", tint: .orange) {
            if points.isEmpty {
                EmptyChartView(message: "No food logs for this period")
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Calories", point.calories)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange.opacity(0.4), .orange.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Calories", point.calories)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }

                    if let target {
                        RuleMark(y: .value("Target", target))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 4)
                            }
                    }
                }
                .frame(height: 180)
                .chartXAxis { xAxisContent(for: timeRange) }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))").font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Weight Chart

private struct WeightChartSection: View {
    let points: [DailyWeightPoint]
    let weightUnit: WeightUnit
    let timeRange: ProgressTimeRange

    private func displayPoints() -> [(date: Date, value: Double)] {
        points.map { (date: $0.date, value: weightUnit.convert($0.weightKg)) }
    }

    private func yDomain(_ pts: [(date: Date, value: Double)]) -> ClosedRange<Double> {
        let values = pts.map(\.value)
        guard let min = values.min(), let max = values.max() else { return 0...200 }
        let padding = Swift.max(0.5, (max - min) * 0.25)
        return (min - padding)...(max + padding)
    }

    var body: some View {
        ChartCard(title: "Weight", systemImage: "scalemass.fill", tint: .blue) {
            if points.isEmpty {
                EmptyChartView(message: "No weight data for this period")
            } else {
                let pts = displayPoints()
                Chart {
                    ForEach(pts, id: \.date) { point in
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Weight", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.25), .blue.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Weight", point.value)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Weight", point.value)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(28)
                    }
                }
                .frame(height: 180)
                .chartYScale(domain: yDomain(pts))
                .chartXAxis { xAxisContent(for: timeRange) }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.1f", v)).font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Photos Section

private struct PhotosSection: View {
    let checkIns: [DailyCheckIn]

    private func displayDate(_ dateStr: String) -> String {
        guard let date = CheckInService.dateFormatter.date(from: dateStr) else { return dateStr }
        return CheckInService.shortDateFormatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progress Photos", systemImage: "photo.on.rectangle.angled")
                .font(.headline)
                .padding(.horizontal, 4)

            if checkIns.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No progress photos yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Add a photo during your morning check-in")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(checkIns) { checkIn in
                        if let urlStr = checkIn.photoUrl {
                            PhotoTile(urlString: urlStr, dateLabel: displayDate(checkIn.date))
                        }
                    }
                }
            }
        }
    }
}

private struct PhotoTile: View {
    let urlString: String
    let dateLabel: String

    var body: some View {
        VStack(spacing: 4) {
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(dateLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared Helpers

private struct ChartCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let content: Content

    init(title: String, systemImage: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct EmptyChartView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

#Preview {
    ProgressTabView()
        .environment(AppState())
}
