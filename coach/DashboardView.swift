import SwiftUI
import Charts


struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var todayCheckIn: DailyCheckIn? = nil
    @State private var showCheckInSheet = false
    @State private var nutrition = FoodLogTotals()
    @State private var liveSteps: Int? = nil
    @State private var isLoading = true
    @State private var weekCaloriePoints: [DailyCaloriePoint] = []
    @State private var weekWeightPoints: [DailyWeightPoint] = []
    @State private var weeklyMacros: WeeklyMacros? = nil
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var refreshTask: Task<Void, Never>? = nil

    private let checkInService = CheckInService()
    private let foodLogService = FoodLogService()
    private let progressService = ProgressService()

    private var effectiveSteps: Int? { liveSteps ?? todayCheckIn?.steps }

    /// Calorie/macro target adjusted for today's actual steps.
    /// The stored plan target is always the floor — steps only add, never subtract.
    private var effectiveTarget: StoredTarget? {
        guard let stored = appState.nutritionTarget else { return nil }
        guard let steps = effectiveSteps, steps > 0,
              let adjusted = appState.adjustedTarget(forSteps: steps, weightKg: todayCheckIn?.weightKg),
              adjusted.calories > stored.calories else { return stored }
        return adjusted
    }

    private var coachInsights: [CoachInsight] {
        guard let target = appState.nutritionTarget else { return [] }
        return CoachEngine(
            weightPoints: weekWeightPoints,
            weeklyMacros: weeklyMacros,
            target: target,
            goal: appState.goal
        ).generate()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                checkInCard
                nutritionCard
                if !coachInsights.isEmpty {
                    insightsCard
                }
            }
            .navigationTitle("Dashboard")
            .onAppear {
                loadTask?.cancel()
                loadTask = Task { await loadAll() }
            }
            .refreshable { await loadAll() }
            .onReceive(NotificationCenter.default.publisher(for: .foodLogChanged)) { _ in
                refreshTask?.cancel()
                refreshTask = Task { await refreshNutrition() }
            }
            .sheet(isPresented: $showCheckInSheet) {
                DailyCheckInSheet(existing: todayCheckIn) { saved in
                    todayCheckIn = saved
                    if let steps = saved.steps { liveSteps = steps }
                }
                .environment(appState)
            }
        }
    }

    // MARK: - Check-in card

    @ViewBuilder
    private var checkInCard: some View {
        Section("Today's Check-in") {
            if let checkIn = todayCheckIn {
                if let wkg = checkIn.weightKg {
                    HStack {
                        Label("Weight", systemImage: "scalemass.fill")
                        Spacer()
                        Text(appState.weightUnit.formatted(wkg)).fontWeight(.medium)
                    }
                }
                HStack {
                    Label("Workout", systemImage: "dumbbell.fill")
                    Spacer()
                    Text(checkIn.workoutCompleted ? "Done" : "Rest day")
                        .fontWeight(.medium)
                        .foregroundStyle(checkIn.workoutCompleted ? .green : .secondary)
                }
                if let steps = effectiveSteps {
                    HStack {
                        Label("Steps", systemImage: "figure.walk")
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(steps.formatted()).fontWeight(.medium)
                            Text(TDEECalculator.activityLabel(fromSteps: steps))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Edit Check-in") { showCheckInSheet = true }
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            } else {
                Button { showCheckInSheet = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Log your morning check-in").font(.subheadline.bold())
                            Text("Weight · Workout · Steps").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            if weekWeightPoints.count >= 2 {
                WeightSparkline(points: weekWeightPoints, unit: appState.weightUnit)
            }
        }
    }

    // MARK: - Nutrition card

    @ViewBuilder
    private var nutritionCard: some View {
        Section("Today's Nutrition") {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let target = effectiveTarget {
                MacroProgressRow(
                    label: "Calories",
                    current: nutrition.calories, target: target.calories,
                    unit: "kcal", color: .accentColor
                )
                MacroProgressRow(
                    label: "Protein",
                    current: nutrition.protein, target: target.proteinG,
                    unit: "g", color: .blue
                )
                MacroProgressRow(
                    label: "Carbs",
                    current: nutrition.carbs, target: target.carbsG,
                    unit: "g", color: .orange
                )
                MacroProgressRow(
                    label: "Fat",
                    current: nutrition.fat, target: target.fatG,
                    unit: "g", color: .yellow
                )

                if !weekCaloriePoints.isEmpty {
                    CalorieMiniChart(points: weekCaloriePoints, target: target.calories)
                }
            } else {
                Text("Complete your profile to set nutrition targets")
                    .foregroundStyle(.secondary).font(.subheadline)
            }
        }
    }

    // MARK: - Insights card

    @ViewBuilder
    private var insightsCard: some View {
        Section {
            ForEach(coachInsights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .foregroundStyle(insight.severity.color)
                        .font(.subheadline)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title).font(.subheadline.bold())
                        Text(insight.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Label("Coach Insights", systemImage: "brain.head.profile")
        }
    }

    // MARK: - Data loading

    private func loadAll() async {
        isLoading = true
        async let checkInFetch   = checkInService.fetchToday()
        async let weightsFetch   = progressService.fetchLast7DayWeights()
        async let nutritionFetch = foodLogService.fetchTotals(for: Date())
        async let dashboardFetch = progressService.fetchLast7DayDashboardData()

        do { todayCheckIn = try await checkInFetch }
        catch { print("DashboardView checkIn error:", error) }

        weekWeightPoints = (try? await weightsFetch) ?? []
        liveSteps        = await HealthKitService.shared.fetchTodaySteps()
        nutrition        = (try? await nutritionFetch) ?? FoodLogTotals()
        if let data      = try? await dashboardFetch {
            weekCaloriePoints = data.calories
            weeklyMacros      = data.macros
        }
        isLoading = false
    }

    private func refreshNutrition() async {
        async let nutritionFetch = foodLogService.fetchTotals(for: Date())
        async let dashboardFetch = progressService.fetchLast7DayDashboardData()
        if let totals = try? await nutritionFetch {
            nutrition = totals
        }
        if let data = try? await dashboardFetch {
            weekCaloriePoints = data.calories
            weeklyMacros      = data.macros
        }
    }
}

// MARK: - Weight sparkline (7-day trend)

private struct WeightSparkline: View {
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

// MARK: - Calorie mini bar chart (7-day)

private struct CalorieMiniChart: View {
    let points: [DailyCaloriePoint]
    let target: Double

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
                    .foregroundStyle(pt.calories > target + 200 ? Color.red.opacity(0.7) : Color.orange.opacity(0.8))
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

// MARK: - Macro progress row

private struct MacroProgressRow: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    private var fraction: Double { min(current / max(target, 1), 1.0) }
    private var isOver: Bool { current > target }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.subheadline.bold())
                    .foregroundStyle(isOver ? .orange : .primary)
            }
            ProgressView(value: fraction)
                .tint(isOver ? .orange : color)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Severity color

private extension CoachInsight.Severity {
    var color: Color {
        switch self {
        case .success: return .green
        case .info:    return .blue
        case .caution: return .orange
        case .warning: return .red
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
}
