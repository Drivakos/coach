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
        }
        let userUpsert = UserUpsert(
            id: userId,
            email: email,
            full_name: data.fullName,
            height_cm: data.heightCm,
            date_of_birth: dobString,
            sex: data.sex,
            activity_level: data.activityLevel
        )
        try await supabase
            .from("users")
            .upsert(userUpsert)
            .execute()

        // 2. INSERT INTO body_metrics
        struct BodyMetricsInsert: Encodable {
            let user_id: UUID
            let weight_kg: Double
            let body_fat_pct: Double?
        }
        let bodyInsert = BodyMetricsInsert(
            user_id: userId,
            weight_kg: data.weightKg,
            body_fat_pct: data.bodyFatPct
        )
        try await supabase
            .from("body_metrics")
            .insert(bodyInsert)
            .execute()

        // 3. INSERT INTO nutrition_targets
        struct NutritionTargetInsert: Encodable {
            let user_id: UUID
            let calories: Double
            let protein_g: Double
            let carbs_g: Double
            let fat_g: Double
        }
        let nutritionInsert = NutritionTargetInsert(
            user_id: userId,
            calories: data.calorieTarget,
            protein_g: data.proteinG,
            carbs_g: data.carbsG,
            fat_g: data.fatG
        )
        try await supabase
            .from("nutrition_targets")
            .insert(nutritionInsert)
            .execute()

        // 4. INSERT INTO food_preferences
        if !data.preferences.isEmpty {
            struct PrefInsert: Encodable {
                let user_id: UUID
                let preference: String
            }
            let prefRows = data.preferences.map { PrefInsert(user_id: userId, preference: $0) }
            try await supabase
                .from("food_preferences")
                .insert(prefRows)
                .execute()
        }

        // 5. INSERT INTO allergies
        if !data.allergies.isEmpty {
            struct AllergyInsert: Encodable {
                let user_id: UUID
                let allergen: String
            }
            let allergyRows = data.allergies.map { AllergyInsert(user_id: userId, allergen: $0) }
            try await supabase
                .from("allergies")
                .insert(allergyRows)
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
