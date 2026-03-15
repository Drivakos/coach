import Foundation
import Supabase

struct WeeklySummaryService {

    private let checkInService = CheckInService()

    // Minimal projection for computing macro averages from food_logs.
    // loggedAt is kept as String to avoid decoder configuration issues with supabase-swift's
    // internal decoder; we only need the date prefix for day-grouping.
    private struct FoodLogProjection: Decodable {
        let loggedAt: String
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

        // 6. Macro averages: group by day, sum per day, then average across 7 days.
        // ISO timestamps always begin with yyyy-MM-dd, so prefix(10) is a safe day key.
        let logsByDay = Dictionary(grouping: foodLogs) { log in
            String(log.loggedAt.prefix(10))
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
            // daysLogged = days with at least one food entry (used by WeeklyPlanEngine
            // to assess dietary adherence before adjusting targets)
            daysLogged: logsByDay.count
        )

        try await supabase
            .from("weekly_summaries")
            .upsert(payload, onConflict: "user_id,week_start")
            .execute()
    }

    /// Returns the `limit` most-recent summaries with week_start strictly before `weekStart`,
    /// ordered newest-first. Used by `WeeklyPlanService` which only needs the last 2.
    func fetchPast(before weekStart: String, limit: Int) async throws -> [WeeklySummary] {
        try await supabase
            .from("weekly_summaries")
            .select()
            .lt("week_start", value: weekStart)
            .order("week_start", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

}
