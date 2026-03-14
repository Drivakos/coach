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
        let insights = coachInsights
        return NavigationStack {
            List {
                checkInCard
                nutritionCard
                if !insights.isEmpty {
                    insightsSection(insights)
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
            if isLoading && todayCheckIn == nil {
                ProgressView().frame(maxWidth: .infinity)
            } else if let checkIn = todayCheckIn {
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
                if let water = checkIn.waterMl, water > 0 {
                    HStack {
                        Label("Water", systemImage: "drop.fill")
                        Spacer()
                        Text(water < 1000 ? "\(water) ml" : DailyCheckInSheet.formatWater(water))
                            .fontWeight(.medium)
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
                            Text("Weight · Workout · Steps · Water").font(.caption).foregroundStyle(.secondary)
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
                MacroProgressBar(
                    label: "Calories",
                    current: nutrition.calories, target: target.calories,
                    unit: "kcal", color: .accentColor
                )
                MacroProgressBar(
                    label: "Protein",
                    current: nutrition.protein, target: target.proteinG,
                    unit: "g", color: .blue
                )
                MacroProgressBar(
                    label: "Carbs",
                    current: nutrition.carbs, target: target.carbsG,
                    unit: "g", color: .orange
                )
                MacroProgressBar(
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
    private func insightsSection(_ insights: [CoachInsight]) -> some View {
        Section {
            ForEach(insights) { insight in
                CoachInsightRow(insight: insight)
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
        async let stepsFetch     = HealthKitService.shared.fetchTodaySteps()

        do { todayCheckIn = try await checkInFetch }
        catch { print("DashboardView checkIn error:", error) }

        weekWeightPoints = (try? await weightsFetch) ?? []
        liveSteps        = await stepsFetch
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

#Preview {
    DashboardView()
        .environment(AppState())
}
