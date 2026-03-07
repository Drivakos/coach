import Foundation
import Supabase

struct CheckInService {

    // MARK: - Date helpers

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "MMM d" display formatter (e.g. "Mar 7") — shared across the app.
    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    /// Returns the Monday of the ISO week containing the given date.
    static func mondayString(of date: Date = Date()) -> String {
        let cal = Calendar(identifier: .iso8601)
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let monday = cal.date(from: components)!
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
