import Foundation
import Observation

@Observable final class WizardData {
    var fullName: String = ""
    var heightCm: Double = 170
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
    var sex: String = "male"       // "male" | "female"
    var weightKg: Double = 70
    var bodyFatPct: Double? = nil
    var activityLevel: ActivityLevel = .moderatelyActive
    var goal: Goal = .maintain
    var macroSplit: MacroSplit = .moderateCarb

    // Editable targets (auto-populated by recalculateTDEE)
    var calorieTarget: Double = 2000
    var proteinG: Double = 150
    var carbsG: Double = 200
    var fatG: Double = 67

    var preferences: Set<String> = []
    var allergies: Set<String> = []

    /// Maintenance TDEE (no goal adjustment).
    var maintenanceCalories: Double {
        TDEECalculator.calculate(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: ageYears(),
            activityLevel: activityLevel, goal: .maintain, macroSplit: macroSplit
        ).calories
    }

    /// Goal-adjusted calories — used for previews without mutating stored targets.
    var tdeeCalories: Double {
        TDEECalculator.calculate(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: ageYears(),
            activityLevel: activityLevel, goal: goal, macroSplit: macroSplit
        ).calories
    }

    func recalculateTDEE() {
        let t = TDEECalculator.calculate(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: ageYears(),
            activityLevel: activityLevel, goal: goal, macroSplit: macroSplit
        )
        calorieTarget = t.calories
        proteinG = t.proteinG
        carbsG   = t.carbsG
        fatG     = t.fatG
    }

    func macroPercentages(for split: MacroSplit) -> (Double, Double, Double) {
        TDEECalculator.macroPercentages(for: split)
    }

    private func ageYears() -> Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 30
    }
}
