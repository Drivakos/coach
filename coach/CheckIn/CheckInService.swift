import Foundation
import Supabase

struct CheckInService {

    // MARK: - Date helpers

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    /// Returns the Monday of the week containing the given date.
    static func mondayString(of date: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2
        let weekday = cal.component(.weekday, from: date)
        let daysToMonday = (weekday - 2 + 7) % 7
        let monday = cal.date(byAdding: .day, value: -daysToMonday, to: date)!
        return dateFormatter.string(from: monday)
    }

    // MARK: - Supabase operations

    func fetchToday() async throws -> DailyCheckIn? {
        let today = Self.todayString()
        let results: [DailyCheckIn] = try await supabase
            .from("daily_checkins")
            .select()
            .eq("date", value: today)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    func upsert(_ payload: DailyCheckInUpsert) async throws -> DailyCheckIn {
        let result: DailyCheckIn = try await supabase
            .from("daily_checkins")
            .upsert(payload, onConflict: "user_id,date")
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func fetchRange(from startDate: String, to endDate: String) async throws -> [DailyCheckIn] {
        let results: [DailyCheckIn] = try await supabase
            .from("daily_checkins")
            .select()
            .gte("date", value: startDate)
            .lte("date", value: endDate)
            .order("date", ascending: true)
            .execute()
            .value
        return results
    }
}
