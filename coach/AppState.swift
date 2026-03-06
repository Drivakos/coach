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

// MARK: - App State

@Observable
final class AppState {
    /// Set to true by the notification tap handler to open the check-in sheet.
    var showCheckIn: Bool = false

    /// User's preferred weight display unit, loaded from Supabase on sign-in.
    var weightUnit: WeightUnit = .kg

    func loadWeightUnit() async {
        do {
            struct UnitRow: Decodable { let weight_unit: String }
            let row: UnitRow = try await supabase
                .from("users")
                .select("weight_unit")
                .single()
                .execute()
                .value
            weightUnit = WeightUnit(rawValue: row.weight_unit) ?? .kg
        } catch {
            // Default to kg if fetch fails
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
