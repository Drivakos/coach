import SwiftUI
import Charts

struct ProgressTabView: View {
    @Environment(AppState.self) private var appState
    @State private var timeRange: ProgressTimeRange = .week
    @State private var caloriePoints: [DailyCaloriePoint] = []
    @State private var weightPoints: [DailyWeightPoint] = []
    @State private var waterPoints: [DailyWaterPoint] = []
    @State private var photoCheckIns: [DailyCheckIn] = []
    @State private var workoutDays: Set<Date> = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var refreshTask: Task<Void, Never>? = nil

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
                        WaterChartSection(
                            points: waterPoints,
                            timeRange: timeRange
                        )
                        WorkoutChartSection(
                            workoutDays: workoutDays,
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
            .onReceive(NotificationCenter.default.publisher(for: .foodLogChanged)) { _ in
                refreshTask?.cancel()
                refreshTask = Task { await fetchAndUpdate() }
            }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        await fetchAndUpdate()
        isLoading = false
    }

    private func fetchAndUpdate() async {
        do {
            async let c = service.fetchCaloriePoints(for: timeRange)
            async let ci = service.fetchCheckInData(for: timeRange)
            let (cal, checkInData) = try await (c, ci)
            caloriePoints = cal
            weightPoints = checkInData.weights
            waterPoints  = checkInData.water
            photoCheckIns = checkInData.photos
            workoutDays = Set(checkInData.workouts)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Shared Axis Helper

private func calUnit(for range: ProgressTimeRange) -> Calendar.Component {
    range == .year ? .month : .day
}

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

    private var xDomain: ClosedRange<Date> {
        let cal = Calendar(identifier: .iso8601)
        let today = cal.startOfDay(for: Date())
        switch timeRange {
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            let monday = cal.date(from: comps) ?? today
            return monday...(cal.date(byAdding: .day, value: 7, to: monday) ?? today)
        case .month:
            var comps = cal.dateComponents([.year, .month], from: today)
            comps.day = 1
            let first = cal.date(from: comps) ?? today
            return first...(cal.date(byAdding: .month, value: 1, to: first) ?? today)
        case .year:
            var comps = cal.dateComponents([.year, .month], from: today)
            let currentMonth = comps.month ?? 1
            comps.month = 1; comps.day = 1
            let first = cal.date(from: comps) ?? today
            comps.month = currentMonth
            let monthStart = cal.date(from: comps) ?? today
            return first...(cal.date(byAdding: .month, value: 1, to: monthStart) ?? today)
        }
    }

    var body: some View {
        ChartCard(title: "Calories", systemImage: "flame.fill", tint: .orange) {
            if points.isEmpty {
                EmptyChartView(message: "No food logs for this period")
            } else {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: calUnit(for: timeRange)),
                            y: .value("Calories", point.calories)
                        )
                        .foregroundStyle(barColor(for: point.calories))
                        .cornerRadius(3)
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
                .chartXScale(domain: xDomain)
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

    private func barColor(for calories: Double) -> Color {
        guard let target else { return .orange.opacity(0.8) }
        let overageThreshold: Double = 200  // mirrors CalorieMiniChart.overageThreshold
        return calories > target + overageThreshold ? Color.red.opacity(0.7) : Color.orange.opacity(0.8)
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

// MARK: - Workout Chart

private struct WorkoutChartSection: View {
    let workoutDays: Set<Date>
    let timeRange: ProgressTimeRange

    private let cal = Calendar(identifier: .iso8601)

    var body: some View {
        ChartCard(title: "Workouts", systemImage: "dumbbell.fill", tint: .green) {
            if timeRange == .year {
                yearView
            } else {
                habitGridView
            }
        }
    }

    // MARK: Year — bar chart of monthly workout counts

    private var yearView: some View {
        let monthly = monthlyWorkoutCounts()
        return Group {
            if monthly.isEmpty {
                EmptyChartView(message: "No workouts logged this year")
            } else {
                Chart {
                    ForEach(monthly, id: \.date) { item in
                        BarMark(
                            x: .value("Month", item.date, unit: .month),
                            y: .value("Workouts", item.count)
                        )
                        .foregroundStyle(Color.green.opacity(0.75))
                        .cornerRadius(3)
                    }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)").font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Week / Month — habit grid

    private var habitGridView: some View {
        let days = periodDays()
        let spacing: CGFloat = timeRange == .week ? 6 : 4
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)

        return VStack(alignment: .leading, spacing: 8) {
            if timeRange == .week {
                // veryShortWeekdaySymbols is Sun-first (index 0 = Sun); reorder to Mon–Sun
                let symbols = Calendar.current.veryShortWeekdaySymbols
                let monToSun = Array(1..<symbols.count) + [0]
                HStack(spacing: 0) {
                    ForEach(monToSun, id: \.self) { i in
                        Text(symbols[i])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let worked = workoutDays.contains(cal.startOfDay(for: day))
                    let isToday = cal.isDateInToday(day)
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(worked ? Color.green.opacity(0.75) : Color(.tertiarySystemBackground))
                        if isToday && !worked {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.green.opacity(0.4), lineWidth: 1)
                        }
                        if timeRange == .month {
                            Text("\(cal.component(.day, from: day))")
                                .font(.system(size: 9))
                                .foregroundStyle(worked ? .white : .secondary)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
            HStack(spacing: 4) {
                Text("\(workoutDays.count) workout\(workoutDays.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Circle().fill(Color.green.opacity(0.75)).frame(width: 8, height: 8)
                Text("Worked out").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func periodDays() -> [Date] {
        let today = cal.startOfDay(for: Date())
        switch timeRange {
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            guard let monday = cal.date(from: comps) else { return [] }
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
        case .month:
            var comps = cal.dateComponents([.year, .month], from: today)
            comps.day = 1
            guard let first = cal.date(from: comps),
                  let range = cal.range(of: .day, in: .month, for: first) else { return [] }
            return (0..<range.count).compactMap { cal.date(byAdding: .day, value: $0, to: first) }
        case .year:
            return []
        }
    }

    private func monthlyWorkoutCounts() -> [(date: Date, count: Int)] {
        let byMonth = Dictionary(grouping: workoutDays) { day -> Date in
            var comps = cal.dateComponents([.year, .month], from: day)
            comps.day = 1
            return cal.date(from: comps) ?? day
        }
        return byMonth.map { (date: $0.key, count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Water Chart

private let waterGoalLitres = 2.0

private struct WaterChartSection: View {
    let points: [DailyWaterPoint]
    let timeRange: ProgressTimeRange

    var body: some View {
        ChartCard(title: "Hydration", systemImage: "drop.fill", tint: .teal) {
            if points.isEmpty {
                EmptyChartView(message: "No water logged for this period")
            } else {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: calUnit(for: timeRange)),
                            y: .value("Water (L)", point.waterMl / 1000)
                        )
                        .foregroundStyle(Color.teal.opacity(0.75))
                        .cornerRadius(3)
                    }
                    RuleMark(y: .value("Goal", waterGoalLitres))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("\(Int(waterGoalLitres)) L goal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 4)
                        }
                }
                .frame(height: 180)
                .chartXAxis { xAxisContent(for: timeRange) }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v < 1 ? "\(Int(v * 1000))ml" : String(format: "%.1gL", v))
                                    .font(.caption2)
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

#Preview {
    ProgressTabView()
        .environment(AppState())
}
