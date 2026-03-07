import Foundation
import Supabase

struct WizardService {
    func saveAll(_ data: WizardData) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        let email  = session.user.email ?? ""

        // 1. UPSERT public.users (guards against missing row if auth trigger didn't fire)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dobString = dateFormatter.string(from: data.dateOfBirth)

        struct UserUpsert: Encodable {
            let id: UUID
            let email: String
            let full_name: String
            let height_cm: Double
            let date_of_birth: String
            let sex: String
            let activity_level: String
            let goal: String
            let macro_split: String
        }
        try await supabase
            .from("users")
            .upsert(UserUpsert(
                id: userId,
                email: email,
                full_name: data.fullName,
                height_cm: data.heightCm,
                date_of_birth: dobString,
                sex: data.sex,
                activity_level: data.activityLevel.rawValue,
                goal: data.goal.rawValue,
                macro_split: data.macroSplit.rawValue
            ))
            .execute()

        // 2. INSERT INTO body_metrics
        try await supabase
            .from("body_metrics")
            .insert(BodyMetricInsert(user_id: userId, weight_kg: data.weightKg, body_fat_pct: data.bodyFatPct))
            .execute()

        // 3. INSERT INTO nutrition_targets
        try await supabase
            .from("nutrition_targets")
            .insert(NutritionTargetInsert(
                user_id: userId,
                calories: data.calorieTarget,
                protein_g: data.proteinG,
                carbs_g: data.carbsG,
                fat_g: data.fatG
            ))
            .execute()

        // 4. INSERT INTO food_preferences
        if !data.preferences.isEmpty {
            try await supabase
                .from("food_preferences")
                .insert(data.preferences.map { FoodPreferenceInsert(user_id: userId, preference: $0) })
                .execute()
        }

        // 5. INSERT INTO allergies
        if !data.allergies.isEmpty {
            try await supabase
                .from("allergies")
                .insert(data.allergies.map { AllergyInsert(user_id: userId, allergen: $0) })
                .execute()
        }
    }
}

enum WizardError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be signed in to complete setup."
        }
    }
}
