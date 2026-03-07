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

// MARK: - Private Decodable helpers (top-level to avoid Swift 6 actor-isolation warnings)

private struct ProfileRow: Decodable { let weight_unit: String? }
private struct TargetRow: Decodable {
    let calories: Double
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
}

// MARK: - App State

@Observable
final class AppState {
    /// Set to true by the notification tap handler to open the check-in sheet.
    var showCheckIn: Bool = false

    /// User's preferred weight display unit, loaded from Supabase on sign-in.
    var weightUnit: WeightUnit = .kg

    /// Most recent stored nutrition targets, kept in sync with the DB.
    var nutritionTarget: StoredTarget? = nil

    // MARK: - Profile loading

    func loadProfile() async {
        do {
            async let pFetch: ProfileRow = supabase
                .from("users").select("weight_unit").single().execute().value
            async let tFetch: [TargetRow] = supabase
                .from("nutrition_targets")
                .select("calories, protein_g, carbs_g, fat_g")
                .order("effective_from", ascending: false)
                .order("created_at", ascending: false)
                .limit(1).execute().value
            let (p, targets) = try await (pFetch, tFetch)

            weightUnit = WeightUnit(rawValue: p.weight_unit ?? "kg") ?? .kg
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

extension Notification.Name {
    static let openCheckIn = Notification.Name("openCheckIn")
}
