import Foundation
import Supabase

struct MonthlySummaryService {

    private let checkInService = CheckInService()

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

    // MARK: - Date helpers

    static func firstDayOfMonthString(of date: Date = Date()) -> String {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: date)
        comps.day = 1
        let first = cal.date(from: comps)!
        return CheckInService.dateFormatter.string(from: first)
    }

    // MARK: - Compute & save

    func computeAndSave(monthStart: String) async throws {
        let df = CheckInService.dateFormatter
        let cal = Calendar.current

        guard let firstDay = df.date(from: monthStart),
              let nextMonth = cal.date(byAdding: .month, value: 1, to: firstDay),
              let lastDay = cal.date(byAdding: .day, value: -1, to: nextMonth)
        else { return }

        let lastDayStr = df.string(from: lastDay)
        let nextMonthStr = df.string(from: nextMonth)

        let session = try await supabase.auth.session
        let userId = session.user.id

        let checkIns = try await checkInService.fetchRange(from: monthStart, to: lastDayStr)

        let foodLogs: [FoodLogProjection] = try await supabase
            .from("food_logs")
            .select("logged_at, calories, protein_g, carbs_g, fat_g")
            .gte("logged_at", value: monthStart)
            .lt("logged_at", value: nextMonthStr)
            .execute()
            .value

        let weights = checkIns.compactMap(\.weightKg)
        let avgWeight: Double? = weights.isEmpty ? nil : weights.reduce(0, +) / Double(weights.count)

        let totalWorkouts = checkIns.filter(\.workoutCompleted).count

        let stepValues = checkIns.compactMap(\.steps).map(Double.init)
        let avgSteps: Double? = stepValues.isEmpty ? nil : stepValues.reduce(0, +) / Double(stepValues.count)

        let logsByDay = Dictionary(grouping: foodLogs) { String($0.loggedAt.prefix(10)) }
        let dailyCalories = logsByDay.values.map { $0.reduce(0) { $0 + $1.calories } }
        let dailyProtein  = logsByDay.values.map { $0.reduce(0) { $0 + $1.proteinG } }
        let dailyCarbs    = logsByDay.values.map { $0.reduce(0) { $0 + $1.carbsG } }
        let dailyFat      = logsByDay.values.map { $0.reduce(0) { $0 + $1.fatG } }

        func avg(_ arr: [Double]) -> Double? { arr.isEmpty ? nil : arr.reduce(0, +) / Double(arr.count) }

        let payload = MonthlySummaryUpsert(
            userId: userId,
            monthStart: monthStart,
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
            .from("monthly_summaries")
            .upsert(payload, onConflict: "user_id,month_start")
            .execute()
    }

}
