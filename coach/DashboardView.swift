import SwiftUI


struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var todayCheckIn: DailyCheckIn? = nil
    @State private var showCheckInSheet = false
    @State private var nutrition = FoodLogTotals()
    @State private var liveSteps: Int? = nil
    @State private var isLoading = true

    private let checkInService = CheckInService()
    private let foodLogService = FoodLogService()

    /// Steps for display in the check-in card only.
    private var effectiveSteps: Int? { liveSteps ?? todayCheckIn?.steps }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                checkInCard
                nutritionCard
            }
            .navigationTitle("Dashboard")
            .task { await loadAll() }
            .refreshable { await loadAll() }
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
        }
    }

    // MARK: - Nutrition card

    @ViewBuilder
    private var nutritionCard: some View {
        Section("Today's Nutrition") {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if let target = appState.nutritionTarget {
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
            } else {
                Text("Complete your profile to set nutrition targets")
                    .foregroundStyle(.secondary).font(.subheadline)
            }
        }
    }

    // MARK: - Data loading

    private func loadAll() async {
        isLoading = true
        async let checkInFetch = checkInService.fetchToday()
        async let nutritionFetch = foodLogService.fetchTotals(for: Date())

        do { todayCheckIn = try await checkInFetch }
        catch { print("DashboardView checkIn error:", error) }

        nutrition = (try? await nutritionFetch) ?? FoodLogTotals()
        liveSteps = await HealthKitService.shared.fetchTodaySteps()
        isLoading = false
    }
}

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

#Preview {
    DashboardView()
        .environment(AppState())
}
