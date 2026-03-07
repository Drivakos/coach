import Foundation

// MARK: - Daily Check-in

struct DailyCheckIn: Identifiable, Decodable {
    let id: UUID
    let userId: UUID
    let date: String                // "yyyy-MM-dd"
    let weightKg: Double?
    let photoUrl: String?           // TODO: Supabase Storage
    let workoutCompleted: Bool
    let workoutNotes: String?
    let steps: Int?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case weightKg = "weight_kg"
        case photoUrl = "photo_url"
        case workoutCompleted = "workout_completed"
        case workoutNotes = "workout_notes"
        case steps
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DailyCheckInUpsert: Encodable {
    let userId: UUID
    let date: String
    let weightKg: Double?
    let workoutCompleted: Bool
    let workoutNotes: String?
    let steps: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case date
        case weightKg = "weight_kg"
        case workoutCompleted = "workout_completed"
        case workoutNotes = "workout_notes"
        case steps
    }
}

// MARK: - Weekly Summary

struct WeeklySummary: Identifiable, Decodable {
    let id: UUID
    let userId: UUID
    let weekStart: String           // "yyyy-MM-dd" (Monday)

    /// Parsed Monday date for display. Uses the shared formatter from CheckInService.
    var weekStartDate: Date? { CheckInService.dateFormatter.date(from: weekStart) }
    let avgWeightKg: Double?
    let avgCalories: Double?
    let avgProteinG: Double?
    let avgCarbsG: Double?
    let avgFatG: Double?
    let totalWorkouts: Int?
    let avgSteps: Double?
    let daysLogged: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case weekStart = "week_start"
        case avgWeightKg = "avg_weight_kg"
        case avgCalories = "avg_calories"
        case avgProteinG = "avg_protein_g"
        case avgCarbsG = "avg_carbs_g"
        case avgFatG = "avg_fat_g"
        case totalWorkouts = "total_workouts"
        case avgSteps = "avg_steps"
        case daysLogged = "days_logged"
        case createdAt = "created_at"
    }
}

// MARK: - Monthly Summary

struct MonthlySummary: Identifiable, Decodable {
    let id: UUID
    let userId: UUID
    let monthStart: String          // "yyyy-MM-dd" (first of month)

    var monthStartDate: Date? { CheckInService.dateFormatter.date(from: monthStart) }
    let avgWeightKg: Double?
    let avgCalories: Double?
    let avgProteinG: Double?
    let avgCarbsG: Double?
    let avgFatG: Double?
    let totalWorkouts: Int?
    let avgSteps: Double?
    let daysLogged: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case monthStart = "month_start"
        case avgWeightKg = "avg_weight_kg"
        case avgCalories = "avg_calories"
        case avgProteinG = "avg_protein_g"
        case avgCarbsG = "avg_carbs_g"
        case avgFatG = "avg_fat_g"
        case totalWorkouts = "total_workouts"
        case avgSteps = "avg_steps"
        case daysLogged = "days_logged"
        case createdAt = "created_at"
    }
}

struct MonthlySummaryUpsert: Encodable {
    let userId: UUID
    let monthStart: String
    let avgWeightKg: Double?
    let avgCalories: Double?
    let avgProteinG: Double?
    let avgCarbsG: Double?
    let avgFatG: Double?
    let totalWorkouts: Int?
    let avgSteps: Double?
    let daysLogged: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case monthStart = "month_start"
        case avgWeightKg = "avg_weight_kg"
        case avgCalories = "avg_calories"
        case avgProteinG = "avg_protein_g"
        case avgCarbsG = "avg_carbs_g"
        case avgFatG = "avg_fat_g"
        case totalWorkouts = "total_workouts"
        case avgSteps = "avg_steps"
        case daysLogged = "days_logged"
    }
}

struct WeeklySummaryUpsert: Encodable {
    let userId: UUID
    let weekStart: String
    let avgWeightKg: Double?
    let avgCalories: Double?
    let avgProteinG: Double?
    let avgCarbsG: Double?
    let avgFatG: Double?
    let totalWorkouts: Int?
    let avgSteps: Double?
    let daysLogged: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case weekStart = "week_start"
        case avgWeightKg = "avg_weight_kg"
        case avgCalories = "avg_calories"
        case avgProteinG = "avg_protein_g"
        case avgCarbsG = "avg_carbs_g"
        case avgFatG = "avg_fat_g"
        case totalWorkouts = "total_workouts"
        case avgSteps = "avg_steps"
        case daysLogged = "days_logged"
    }
}
