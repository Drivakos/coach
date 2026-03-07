import Foundation
import Supabase

struct FoodLogService {

    func fetch(for date: Date) async throws -> [FoodLog] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return try await supabase
            .from("food_logs")
            .select()
            .gte("logged_at", value: iso.string(from: start))
            .lt("logged_at", value: iso.string(from: end))
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
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rows: [Row] = try await supabase
            .from("food_logs")
            .select("calories, protein_g, carbs_g, fat_g")
            .gte("logged_at", value: iso.string(from: start))
            .lt("logged_at", value: iso.string(from: end))
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
}

struct FoodLogTotals {
    var calories: Double = 0
    var protein: Double  = 0
    var carbs: Double    = 0
    var fat: Double      = 0
}
