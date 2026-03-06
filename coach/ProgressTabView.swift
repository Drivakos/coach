import SwiftUI

struct ProgressTabView: View {
    @Environment(AppState.self) private var appState
    @State private var summaries: [WeeklySummary] = []
    @State private var isLoading = true
    @State private var loadError: String?

    private let service = WeeklySummaryService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError {
                    ContentUnavailableView(
                        "Couldn't load progress",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if summaries.isEmpty {
                    ContentUnavailableView(
                        "No weekly data yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Complete your first week of check-ins to see your progress summary.")
                    )
                } else {
                    List(summaries) { summary in
                        WeeklySummaryRow(summary: summary, weightUnit: appState.weightUnit)
                    }
                }
            }
            .navigationTitle("Progress")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            summaries = try await service.fetchAll()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Weekly Summary Row

private struct WeeklySummaryRow: View {
    let summary: WeeklySummary
    let weightUnit: WeightUnit

    private var weekLabel: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        guard let monday = df.date(from: summary.weekStart) else { return summary.weekStart }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        guard let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday) else {
            return fmt.string(from: monday)
        }
        return "\(fmt.string(from: monday)) – \(fmt.string(from: sunday))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(weekLabel)
                .font(.subheadline.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if let w = summary.avgWeightKg {
                    StatCell(label: "Avg Weight", value: weightUnit.formatted(w))
                }
                if let cal = summary.avgCalories {
                    StatCell(label: "Avg Calories", value: "\(Int(cal)) kcal")
                }
                if let workouts = summary.totalWorkouts {
                    StatCell(label: "Workouts", value: "\(workouts)/7 days")
                }
                if let s = summary.avgSteps {
                    StatCell(label: "Avg Steps", value: Int(s).formatted())
                }
                if let p = summary.avgProteinG {
                    StatCell(label: "Avg Protein", value: "\(Int(p))g")
                }
                if let days = summary.daysLogged {
                    StatCell(label: "Days Logged", value: "\(days)/7")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ProgressTabView()
        .environment(AppState())
}
