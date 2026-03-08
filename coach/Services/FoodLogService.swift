import Foundation
import Supabase

struct FoodLogService {

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func dayRange(for date: Date) -> (start: String, end: String) {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return (Self.iso.string(from: start), Self.iso.string(from: end))
    }

    func fetch(for date: Date) async throws -> [FoodLog] {
        let (start, end) = dayRange(for: date)
        return try await supabase
            .from("food_logs")
            .select()
            .gte("logged_at", value: start)
            .lt("logged_at", value: end)
            .order("logged_at", ascending: false)
            .execute()
            .value
    }

    func fetchTotals(for date: Date) async throws -> FoodLogTotals {
        struct Row: Decodable {
            let calories: Double
            let protein_g: Double
            let carbs_g: Double
            let fat_g: Double
        }
        let (start, end) = dayRange(for: date)
        let rows: [Row] = try await supabase
            .from("food_logs")
            .select("calories, protein_g, carbs_g, fat_g")
            .gte("logged_at", value: start)
            .lt("logged_at", value: end)
            .execute()
            .value
        return FoodLogTotals(
            calories: rows.reduce(0) { $0 + $1.calories },
            protein:  rows.reduce(0) { $0 + $1.protein_g },
            carbs:    rows.reduce(0) { $0 + $1.carbs_g },
            fat:      rows.reduce(0) { $0 + $1.fat_g }
        )
    }

    func insert(_ payload: FoodLogInsert) async throws -> FoodLog {
        try await supabase
            .from("food_logs")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
    }

    func update(_ log: FoodLog) async throws -> FoodLog {
        try await supabase
            .from("food_logs")
            .update(log)
            .eq("id", value: log.id)
            .select()
            .single()
            .execute()
            .value
    }

    func delete(_ log: FoodLog) async throws {
        try await supabase
            .from("food_logs")
            .delete()
            .eq("id", value: log.id)
            .execute()
    }

    func deleteMeal(_ mealType: MealType, on date: Date) async throws {
        let (start, end) = dayRange(for: date)
        try await supabase
            .from("food_logs")
            .delete()
            .eq("meal_type", value: mealType.rawValue)
            .gte("logged_at", value: start)
            .lt("logged_at", value: end)
            .execute()
    }
}

struct FoodLogTotals {
    var calories: Double = 0
    var protein: Double  = 0
    var carbs: Double    = 0
    var fat: Double      = 0
}
