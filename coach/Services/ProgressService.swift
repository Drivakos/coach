import Foundation
import Supabase

// MARK: - Time Range

enum ProgressTimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
}

// MARK: - Chart Data Models

struct DailyCaloriePoint: Identifiable {
    let date: Date
    let calories: Double
    var id: Date { date }
}

struct DailyWeightPoint: Identifiable {
    let date: Date
    let weightKg: Double
    var id: Date { date }
}

struct WeeklyMacros {
    let avgCalories: Double
    let avgProteinG: Double
    let avgCarbsG: Double
    let avgFatG: Double
    let daysLogged: Int
}

// MARK: - Service

struct ProgressService {

    private let checkInService = CheckInService()
    private let df = CheckInService.dateFormatter

    func dateRange(for timeRange: ProgressTimeRange) -> (start: Date, end: Date) {
        let cal = Calendar(identifier: .iso8601)
        let today = cal.startOfDay(for: Date())
        switch timeRange {
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            let monday = cal.date(from: comps) ?? today
            return (monday, today)
        case .month:
            var comps = cal.dateComponents([.year, .month], from: today)
            comps.day = 1
            let first = cal.date(from: comps) ?? today
            return (first, today)
        case .year:
            var comps = cal.dateComponents([.year], from: today)
            comps.month = 1
            comps.day = 1
            let first = cal.date(from: comps) ?? today
            return (first, today)
        }
    }

    // MARK: - Calories

    func fetchCaloriePoints(for timeRange: ProgressTimeRange) async throws -> [DailyCaloriePoint] {
        let (start, end) = dateRange(for: timeRange)
        let daily = try await fetchDailyCalories(from: start, to: end)
        return timeRange == .year ? aggregateCaloriesToMonthly(daily) : daily
    }

    private func aggregateCaloriesToMonthly(_ points: [DailyCaloriePoint]) -> [DailyCaloriePoint] {
        let cal = Calendar.current
        let byMonth = Dictionary(grouping: points) { point -> Date in
            var comps = cal.dateComponents([.year, .month], from: point.date)
            comps.day = 1
            return cal.date(from: comps)!
        }
        return byMonth.map { monthDate, pts in
            DailyCaloriePoint(date: monthDate, calories: pts.reduce(0) { $0 + $1.calories } / Double(pts.count))
        }.sorted { $0.date < $1.date }
    }

    private struct CalorieFoodLogRow: Decodable {
        let loggedAt: String
        let calories: Double
        enum CodingKeys: String, CodingKey {
            case loggedAt = "logged_at"
            case calories
        }
    }

    func fetchDailyCalories(from start: Date, to end: Date) async throws -> [DailyCaloriePoint] {
        let startStr = df.string(from: start)
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: end) else { return [] }
        let nextDayStr = df.string(from: nextDay)

        let rows: [CalorieFoodLogRow] = try await supabase
            .from("food_logs")
            .select("logged_at, calories")
            .gte("logged_at", value: startStr)
            .lt("logged_at", value: nextDayStr)
            .execute()
            .value

        let byDay = Dictionary(grouping: rows) { String($0.loggedAt.prefix(10)) }
        return byDay.compactMap { dateStr, logs -> DailyCaloriePoint? in
            guard let date = df.date(from: dateStr) else { return nil }
            return DailyCaloriePoint(date: date, calories: logs.reduce(0) { $0 + $1.calories })
        }.sorted { $0.date < $1.date }
    }


    // MARK: - Weight + Photos (combined to avoid duplicate fetchRange calls)

    /// Returns weight chart points and photo check-ins in a single DB round-trip.
    func fetchCheckInData(for timeRange: ProgressTimeRange) async throws -> (weights: [DailyWeightPoint], photos: [DailyCheckIn]) {
        let (start, end) = dateRange(for: timeRange)
        let checkIns = try await checkInService.fetchRange(
            from: df.string(from: start),
            to: df.string(from: end)
        )
        let dailyWeights = checkIns.compactMap { checkIn -> DailyWeightPoint? in
            guard let w = checkIn.weightKg, let date = df.date(from: checkIn.date) else { return nil }
            return DailyWeightPoint(date: date, weightKg: w)
        }
        let weights = timeRange == .year ? aggregateWeightsToMonthly(dailyWeights) : dailyWeights
        let photos = checkIns.filter { $0.photoUrl != nil }
        return (weights, photos)
    }

    // MARK: - Dashboard: last 7 days (single food_logs query for both calories and macros)

    private struct MacroFoodLogRow: Decodable {
        let loggedAt: String
        let calories: Double
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
        enum CodingKeys: String, CodingKey {
            case loggedAt = "logged_at"
            case calories
            case proteinG = "protein_g"
            case carbsG   = "carbs_g"
            case fatG     = "fat_g"
        }
    }

    func fetchLast7DayDashboardData() async throws -> (calories: [DailyCaloriePoint], macros: WeeklyMacros) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: end)!
        let startStr = df.string(from: start)
        guard let nextDay = cal.date(byAdding: .day, value: 1, to: end) else {
            return ([], WeeklyMacros(avgCalories: 0, avgProteinG: 0, avgCarbsG: 0, avgFatG: 0, daysLogged: 0))
        }

        let rows: [MacroFoodLogRow] = try await supabase
            .from("food_logs")
            .select("logged_at, calories, protein_g, carbs_g, fat_g")
            .gte("logged_at", value: startStr)
            .lt("logged_at", value: df.string(from: nextDay))
            .execute()
            .value

        let byDay = Dictionary(grouping: rows) { String($0.loggedAt.prefix(10)) }

        let caloriePoints = byDay.compactMap { dateStr, logs -> DailyCaloriePoint? in
            guard let date = df.date(from: dateStr) else { return nil }
            return DailyCaloriePoint(date: date, calories: logs.reduce(0) { $0 + $1.calories })
        }.sorted { $0.date < $1.date }

        let daysLogged = byDay.count
        guard daysLogged > 0 else {
            return (caloriePoints, WeeklyMacros(avgCalories: 0, avgProteinG: 0, avgCarbsG: 0, avgFatG: 0, daysLogged: 0))
        }

        let totals = byDay.values.map { logs in (
            cal:  logs.reduce(0) { $0 + $1.calories },
            pro:  logs.reduce(0) { $0 + $1.proteinG },
            carb: logs.reduce(0) { $0 + $1.carbsG   },
            fat:  logs.reduce(0) { $0 + $1.fatG      }
        )}
        let macros = WeeklyMacros(
            avgCalories: totals.reduce(0) { $0 + $1.cal  } / Double(daysLogged),
            avgProteinG: totals.reduce(0) { $0 + $1.pro  } / Double(daysLogged),
            avgCarbsG:   totals.reduce(0) { $0 + $1.carb } / Double(daysLogged),
            avgFatG:     totals.reduce(0) { $0 + $1.fat  } / Double(daysLogged),
            daysLogged: daysLogged
        )
        return (caloriePoints, macros)
    }

    func fetchLast7DayWeights() async throws -> [DailyWeightPoint] {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: end)!
        let checkIns = try await checkInService.fetchRange(
            from: df.string(from: start),
            to: df.string(from: end)
        )
        return checkIns.compactMap { ci -> DailyWeightPoint? in
            guard let w = ci.weightKg, let date = df.date(from: ci.date) else { return nil }
            return DailyWeightPoint(date: date, weightKg: w)
        }
    }

    private func aggregateWeightsToMonthly(_ points: [DailyWeightPoint]) -> [DailyWeightPoint] {
        let cal = Calendar.current
        let byMonth = Dictionary(grouping: points) { point -> Date in
            var comps = cal.dateComponents([.year, .month], from: point.date)
            comps.day = 1
            return cal.date(from: comps)!
        }
        return byMonth.map { monthDate, pts in
            DailyWeightPoint(date: monthDate, weightKg: pts.reduce(0) { $0 + $1.weightKg } / Double(pts.count))
        }.sorted { $0.date < $1.date }
    }

}
