import Foundation
import Supabase

struct WeeklySummaryService {

    private let checkInService = CheckInService()

    // Minimal projection for computing macro averages from food_logs
    private struct FoodLogProjection: Decodable {
        let loggedAt: Date
        let calories: Double
        let proteinG: Double
        let carbsG: Double
        let fatG: Double

        enum CodingKeys: String, CodingKey {
            case loggedAt = "logged_at"
            case calories
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
        }
    }

    // MARK: - Compute & save

    /// Fetches check-ins and food logs for the given week, computes averages, and upserts to weekly_summaries.
    func computeAndSave(weekStart: String) async throws {
        let df = CheckInService.dateFormatter
        let cal = Calendar(identifier: .iso8601)

        guard let monday = df.date(from: weekStart),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday),
              let dayAfterSunday = cal.date(byAdding: .day, value: 7, to: monday)
        else { return }

        let sundayStr = df.string(from: sunday)
        let nextMonday = df.string(from: dayAfterSunday)

        let session = try await supabase.auth.session
        let userId = session.user.id

        // 1. Check-ins for the week
        let checkIns = try await checkInService.fetchRange(from: weekStart, to: sundayStr)

        // 2. Food logs for the week
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let foodLogs: [FoodLogProjection] = try await supabase
            .from("food_logs")
            .select("logged_at, calories, protein_g, carbs_g, fat_g")
            .gte("logged_at", value: weekStart)
            .lt("logged_at", value: nextMonday)
            .execute()
            .value

        // 3. Compute weight average (only days with a weight entry)
        let weights = checkIns.compactMap(\.weightKg)
        let avgWeight: Double? = weights.isEmpty ? nil : weights.reduce(0, +) / Double(weights.count)

        // 4. Workout count
        let totalWorkouts = checkIns.filter(\.workoutCompleted).count

        // 5. Steps average
        let stepValues = checkIns.compactMap(\.steps).map(Double.init)
        let avgSteps: Double? = stepValues.isEmpty ? nil : stepValues.reduce(0, +) / Double(stepValues.count)

        // 6. Macro averages: group by day, sum per day, then average across 7 days
        let logsByDay = Dictionary(grouping: foodLogs) { log in
            df.string(from: cal.startOfDay(for: log.loggedAt))
        }
        let dailyCalories = logsByDay.values.map { $0.reduce(0) { $0 + $1.calories } }
        let dailyProtein  = logsByDay.values.map { $0.reduce(0) { $0 + $1.proteinG } }
        let dailyCarbs    = logsByDay.values.map { $0.reduce(0) { $0 + $1.carbsG } }
        let dailyFat      = logsByDay.values.map { $0.reduce(0) { $0 + $1.fatG } }

        func avg(_ arr: [Double]) -> Double? { arr.isEmpty ? nil : arr.reduce(0, +) / Double(arr.count) }

        let payload = WeeklySummaryUpsert(
            userId: userId,
            weekStart: weekStart,
            avgWeightKg: avgWeight,
            avgCalories: avg(dailyCalories),
            avgProteinG: avg(dailyProtein),
            avgCarbsG: avg(dailyCarbs),
            avgFatG: avg(dailyFat),
            totalWorkouts: totalWorkouts,
            avgSteps: avgSteps,
            daysLogged: checkIns.count
        )

        try await supabase
            .from("weekly_summaries")
            .upsert(payload, onConflict: "user_id,week_start")
            .execute()
    }

    // MARK: - Fetch all

    func fetchAll() async throws -> [WeeklySummary] {
        let results: [WeeklySummary] = try await supabase
            .from("weekly_summaries")
            .select()
            .order("week_start", ascending: false)
            .execute()
            .value
        return results
    }

    // MARK: - Auto rollup on Monday

    /// Runs on app launch. If today is Monday and last week's summary is missing, computes it.
    func rollUpIfNeeded() async {
        let cal = Calendar(identifier: .iso8601)
        let today = Date()

        // Only run on Mondays (weekday == 2 in ISO 8601)
        guard cal.component(.weekday, from: today) == 2 else { return }

        guard let lastMonday = cal.date(byAdding: .day, value: -7, to: today) else { return }
        let lastMondayStr = CheckInService.dateFormatter.string(from: lastMonday)

        do {
            struct IDOnly: Decodable { let id: UUID }
            let existing: [IDOnly] = try await supabase
                .from("weekly_summaries")
                .select("id")
                .eq("week_start", value: lastMondayStr)
                .limit(1)
                .execute()
                .value

            if existing.isEmpty {
                try await computeAndSave(weekStart: lastMondayStr)
            }
        } catch {
            print("WeeklySummaryService rollUpIfNeeded error:", error)
        }
    }
}
