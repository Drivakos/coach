import SwiftUI
import Supabase

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var todayCheckIn: DailyCheckIn? = nil
    @State private var showCheckInSheet = false
    @State private var todayCalories: Double = 0
    @State private var isLoading = true

    private let checkInService = CheckInService()

    var body: some View {
        NavigationStack {
            List {
                checkInCard
                nutritionCard
            }
            .navigationTitle("Dashboard")
            .task {
                await loadAll()
            }
            .refreshable {
                await loadAll()
            }
            .sheet(isPresented: $showCheckInSheet) {
                DailyCheckInSheet(existing: todayCheckIn) { saved in
                    todayCheckIn = saved
                }
                .environment(appState)
            }
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private var checkInCard: some View {
        Section("Today's Check-in") {
            if let checkIn = todayCheckIn {
                if let wkg = checkIn.weightKg {
                    HStack {
                        Label("Weight", systemImage: "scalemass.fill")
                        Spacer()
                        Text(appState.weightUnit.formatted(wkg))
                            .fontWeight(.medium)
                    }
                }
                HStack {
                    Label("Workout", systemImage: "dumbbell.fill")
                    Spacer()
                    Text(checkIn.workoutCompleted ? "Done" : "Rest day")
                        .fontWeight(.medium)
                        .foregroundStyle(checkIn.workoutCompleted ? .green : .secondary)
                }
                if let s = checkIn.steps {
                    HStack {
                        Label("Steps", systemImage: "figure.walk")
                        Spacer()
                        Text(s.formatted())
                            .fontWeight(.medium)
                    }
                }
                Button("Edit Check-in") {
                    showCheckInSheet = true
                }
                .font(.subheadline)
                .foregroundStyle(.tint)
            } else {
                Button {
                    showCheckInSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Log your morning check-in")
                                .font(.subheadline.bold())
                            Text("Weight · Workout · Steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var nutritionCard: some View {
        Section("Today's Nutrition") {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if todayCalories > 0 {
                HStack {
                    Label("Calories", systemImage: "fork.knife")
                    Spacer()
                    Text("\(Int(todayCalories)) kcal")
                        .fontWeight(.medium)
                }
            } else {
                Text("No food logged today")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Data

    private func loadAll() async {
        isLoading = true
        async let checkInFetch = checkInService.fetchToday()
        async let caloriesFetch = fetchTodayCalories()
        do {
            todayCheckIn = try await checkInFetch
        } catch {
            print("DashboardView checkIn error:", error)
        }
        todayCalories = await caloriesFetch
        isLoading = false
    }

    private func fetchTodayCalories() async -> Double {
        do {
            let start = Calendar.current.startOfDay(for: Date())
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            struct CalRow: Decodable { let calories: Double }
            let logs: [CalRow] = try await supabase
                .from("food_logs")
                .select("calories")
                .gte("logged_at", value: isoFormatter.string(from: start))
                .execute()
                .value
            return logs.reduce(0) { $0 + $1.calories }
        } catch {
            return 0
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
}
