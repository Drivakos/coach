import Foundation
import Supabase

// MARK: - Weight Unit

enum WeightUnit: String, CaseIterable {
    case kg = "kg"
    case lbs = "lbs"

    func convert(_ valueKg: Double) -> Double {
        switch self {
        case .kg:  return valueKg
        case .lbs: return valueKg * 2.20462
        }
    }

    func toKg(_ value: Double) -> Double {
        switch self {
        case .kg:  return value
        case .lbs: return value / 2.20462
        }
    }

    func formatted(_ valueKg: Double, decimals: Int = 1) -> String {
        let v = convert(valueKg)
        return String(format: "%.\(decimals)f \(rawValue)", v)
    }
}

struct StoredTarget {
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
}


// MARK: - App State

@Observable
final class AppState {
    /// Set to true by the notification tap handler to open the check-in sheet.
    var showCheckIn: Bool = false

    /// User's preferred weight display unit, loaded from Supabase on sign-in.
    var weightUnit: WeightUnit = .kg

    /// User's current goal, loaded from Supabase on sign-in.
    var goal: Goal = .maintain

    /// Most recent stored nutrition targets, kept in sync with the DB.
    var nutritionTarget: StoredTarget? = nil

    // MARK: - Profile fields for step-adjusted calorie calculation
    var sex: String = "male"
    var heightCm: Double = 170
    var ageYears: Int = 30
    var macroSplit: MacroSplit = .moderateCarb
    /// Most recent body metric weight (kg), used for step-adjusted TDEE.
    var profileWeightKg: Double = 70

    /// Returns a calorie/macro target adjusted for today's actual step count.
    /// Falls back to `nutritionTarget` if profile data isn't loaded yet.
    func adjustedTarget(forSteps steps: Int, weightKg: Double? = nil) -> StoredTarget? {
        guard nutritionTarget != nil else { return nil }
        let wkg = weightKg ?? profileWeightKg
        let t = TDEECalculator.calculate(
            sex: sex, weightKg: wkg, heightCm: heightCm, age: ageYears,
            steps: steps, goal: goal, macroSplit: macroSplit
        )
        return StoredTarget(calories: t.calories, proteinG: t.proteinG, carbsG: t.carbsG, fatG: t.fatG)
    }

    // MARK: - Profile loading

    func loadProfile() async {
        do {
            let result = try await _fetchProfileData()

            weightUnit = WeightUnit(rawValue: result.weightUnit ?? "kg") ?? .kg
            goal = Goal(rawValue: result.goal ?? "maintain") ?? .maintain
            if let t = result.targets.first {
                nutritionTarget = StoredTarget(
                    calories: t.calories,
                    proteinG: t.protein_g,
                    carbsG: t.carbs_g,
                    fatG: t.fat_g
                )
            }
            sex = result.sex ?? "male"
            heightCm = result.heightCm ?? 170
            macroSplit = MacroSplit(rawValue: result.macroSplit ?? "moderate_carb") ?? .moderateCarb
            if let dobStr = result.dateOfBirth,
               let dob = CheckInService.dateFormatter.date(from: dobStr) {
                ageYears = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 30
            }
            if let w = result.profileWeightKg { profileWeightKg = w }
        } catch {
            print("AppState loadProfile error:", error)
        }
    }

    func saveWeightUnit(_ unit: WeightUnit) async {
        weightUnit = unit
        do {
            let session = try await supabase.auth.session
            struct UnitUpdate: Encodable { let weight_unit: String }
            try await supabase
                .from("users")
                .update(UnitUpdate(weight_unit: unit.rawValue))
                .eq("id", value: session.user.id)
                .execute()
        } catch {
            // Unit is already updated locally; Supabase will sync on next load
        }
    }

    /// Subscribes to Apple NotificationCenter posts from the notification delegate.
    func listenForNotificationTaps() {
        NotificationCenter.default.addObserver(
            forName: .openCheckIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.showCheckIn = true
        }
    }
}

// Nonisolated free function — module-level functions are nonisolated by default,
// so the local Decodable types here are never inferred as @MainActor.
nonisolated private func _fetchProfileData() async throws -> (
    weightUnit: String?, goal: String?, targets: [AppStateTargetRow],
    sex: String?, heightCm: Double?, dateOfBirth: String?, macroSplit: String?,
    profileWeightKg: Double?
) {
    struct ProfileRow: Decodable {
        let weight_unit: String?; let goal: String?
        let sex: String?; let height_cm: Double?
        let date_of_birth: String?; let macro_split: String?
    }
    struct BodyMetricRow: Decodable { let weight_kg: Double }
    async let pFetch: ProfileRow = supabase
        .from("users").select("weight_unit, goal, sex, height_cm, date_of_birth, macro_split").single().execute().value
    async let tFetch: [AppStateTargetRow] = supabase
        .from("nutrition_targets")
        .select("calories, protein_g, carbs_g, fat_g")
        .order("effective_from", ascending: false)
        .order("created_at", ascending: false)
        .limit(1).execute().value
    async let wFetch: [BodyMetricRow] = supabase
        .from("body_metrics")
        .select("weight_kg")
        .order("created_at", ascending: false)
        .limit(1).execute().value
    let (p, t, w) = try await (pFetch, tFetch, wFetch)
    return (p.weight_unit, p.goal, t, p.sex, p.height_cm, p.date_of_birth, p.macro_split, w.first?.weight_kg)
}

struct AppStateTargetRow: Decodable {
    let calories: Double
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
}

extension Notification.Name {
    static let openCheckIn   = Notification.Name("openCheckIn")
    static let foodLogChanged = Notification.Name("foodLogChanged")
}
