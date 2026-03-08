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

    // MARK: - Profile loading

    func loadProfile() async {
        do {
            let (weightUnitRaw, goalRaw, targets) = try await _fetchProfileData()

            weightUnit = WeightUnit(rawValue: weightUnitRaw ?? "kg") ?? .kg
            goal = Goal(rawValue: goalRaw ?? "maintain") ?? .maintain
            if let t = targets.first {
                nutritionTarget = StoredTarget(
                    calories: t.calories,
                    proteinG: t.protein_g,
                    carbsG: t.carbs_g,
                    fatG: t.fat_g
                )
            }
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
nonisolated private func _fetchProfileData() async throws -> (weightUnit: String?, goal: String?, targets: [AppStateTargetRow]) {
    struct ProfileRow: Decodable { let weight_unit: String?; let goal: String? }
    async let pFetch: ProfileRow = supabase
        .from("users").select("weight_unit, goal").single().execute().value
    async let tFetch: [AppStateTargetRow] = supabase
        .from("nutrition_targets")
        .select("calories, protein_g, carbs_g, fat_g")
        .order("effective_from", ascending: false)
        .order("created_at", ascending: false)
        .limit(1).execute().value
    let (p, t) = try await (pFetch, tFetch)
    return (p.weight_unit, p.goal, t)
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
