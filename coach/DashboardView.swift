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
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        if let target = effectiveTarget {
                            calorieRingCard(target: target)
                            macroRow(target: target)
                        } else {
                            missingTargetCard
                        }
                        checkInCard
                        if !weekCaloriePoints.isEmpty || weekWeightPoints.count >= 2 {
                            chartsCard
                        }
                        if !insights.isEmpty {
                            insightsCard(insights)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
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

    // MARK: - Calorie ring card

    @ViewBuilder
    private func calorieRingCard(target: StoredTarget) -> some View {
        let fraction = min(nutrition.calories / max(target.calories, 1), 1.0)
        let isOver = nutrition.calories > target.calories
        let remaining = target.calories - nutrition.calories

        DashCard {
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.12), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(
                            isOver ? Color.orange : Color.accentColor,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: fraction)
                    VStack(spacing: 2) {
                        Text("\(Int(nutrition.calories))")
                            .font(.title2.bold())
                            .foregroundStyle(isOver ? .orange : .primary)
                        Text("kcal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Goal").font(.caption).foregroundStyle(.secondary)
                        Text("\(Int(target.calories)) kcal").font(.subheadline.bold())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(remaining >= 0 ? "Remaining" : "Over budget")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: remaining >= 0 ? "flame.fill" : "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(remaining < 0 ? .orange : .accentColor)
                            Text("\(abs(Int(remaining))) kcal")
                                .font(.subheadline.bold())
                                .foregroundStyle(remaining < 0 ? .orange : .primary)
                        }
                    }
                }

                Spacer()
            }
            .padding(18)
        }
    }

    // MARK: - Macro row

    @ViewBuilder
    private func macroRow(target: StoredTarget) -> some View {
        HStack(spacing: 10) {
            MacroCard(label: "Protein", current: nutrition.protein, target: target.proteinG, unit: "g", color: .blue)
            MacroCard(label: "Carbs", current: nutrition.carbs, target: target.carbsG, unit: "g", color: .orange)
            MacroCard(label: "Fat", current: nutrition.fat, target: target.fatG, unit: "g", color: .yellow)
        }
    }

    // MARK: - Check-in card

    @ViewBuilder
    private var checkInCard: some View {
        DashCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Today's Check-in", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                    Spacer()
                    Button(todayCheckIn == nil ? "Log" : "Edit") {
                        showCheckInSheet = true
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.tint)
                }

                if let checkIn = todayCheckIn {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        if let wkg = checkIn.weightKg {
                            CheckInTile(
                                icon: "scalemass.fill",
                                label: "Weight",
                                value: appState.weightUnit.formatted(wkg),
                                color: .blue
                            )
                        }
                        CheckInTile(
                            icon: "dumbbell.fill",
                            label: "Workout",
                            value: checkIn.workoutCompleted ? "Done" : "Rest day",
                            color: checkIn.workoutCompleted ? .green : .secondary
                        )
                        if let steps = effectiveSteps {
                            CheckInTile(
                                icon: "figure.walk",
                                label: "Steps",
                                value: steps.formatted(),
                                subtitle: TDEECalculator.activityLabel(fromSteps: steps),
                                color: .purple
                            )
                        }
                        if let water = checkIn.waterMl, water > 0 {
                            CheckInTile(
                                icon: "drop.fill",
                                label: "Water",
                                value: water < 1000 ? "\(water) ml" : DailyCheckInSheet.formatWater(water),
                                color: .cyan
                            )
                        }
                    }
                } else {
                    Button { showCheckInSheet = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Log your morning check-in")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Weight · Workout · Steps · Water")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Charts card

    @ViewBuilder
    private var chartsCard: some View {
        DashCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("This Week")
                    .font(.headline)
                    .padding(.bottom, 2)

                if !weekCaloriePoints.isEmpty, let target = effectiveTarget {
                    CalorieMiniChart(points: weekCaloriePoints, target: target.calories)
                }

                if weekWeightPoints.count >= 2 {
                    if !weekCaloriePoints.isEmpty {
                        Divider()
                    }
                    WeightSparkline(points: weekWeightPoints, unit: appState.weightUnit)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Missing target card

    @ViewBuilder
    private var missingTargetCard: some View {
        DashCard {
            VStack(spacing: 10) {
                Image(systemName: "person.fill.questionmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Complete your profile to set nutrition targets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    // MARK: - Insights card

    @ViewBuilder
    private func insightsCard(_ insights: [CoachInsight]) -> some View {
        DashCard {
            VStack(alignment: .leading, spacing: 0) {
                Label("Coach Insights", systemImage: "brain.head.profile")
                    .font(.headline)
                    .padding(16)

                ForEach(insights) { insight in
                    if insight.id != insights.first?.id { Divider().padding(.leading, 16) }
                    CoachInsightRow(insight: insight)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
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

// MARK: - DashCard

private struct DashCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - MacroCard

private struct MacroCard: View {
    let label: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    private var fraction: Double { min(current / max(target, 1), 1.0) }
    private var isOver: Bool { current > target }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isOver ? Color.orange : color)
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(Int(current))\(unit)")
                .font(.subheadline.bold())
                .foregroundStyle(isOver ? .orange : .primary)
            Text("/ \(Int(target))\(unit)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule()
                    .fill(isOver ? Color.orange : color)
                    .scaleEffect(x: fraction, y: 1, anchor: .leading)
                    .animation(.easeInOut(duration: 0.4), value: fraction)
            }
            .frame(height: 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - CheckInTile

private struct CheckInTile: View {
    let icon: String
    let label: String
    let value: String
    var subtitle: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
}
