import Foundation
import Observation

@Observable final class WizardData {
    var fullName: String = ""
    var heightCm: Double = 170
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
    var sex: String = "male"       // "male" | "female"
    var weightKg: Double = 70
    var bodyFatPct: Double? = nil
    var activityLevel: String = "moderately_active"
    var goal: String = "maintain"        // "lose_weight" | "maintain" | "gain_muscle"
    var macroSplit: String = "moderate_carb" // "moderate_carb" | "lower_carb" | "higher_carb"

    // Editable targets (auto-populated by recalculateTDEE)
    var calorieTarget: Double = 2000
    var proteinG: Double = 150
    var carbsG: Double = 200
    var fatG: Double = 67

    var preferences: Set<String> = []
    var allergies: Set<String> = []

    /// Maintenance TDEE (no goal adjustment).
    var maintenanceCalories: Double {
        let age = ageYears()
        let bmr = sex == "male"
            ? 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
            : 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        let multiplier: Double
        switch activityLevel {
        case "sedentary":         multiplier = 1.2
        case "lightly_active":    multiplier = 1.375
        case "moderately_active": multiplier = 1.55
        case "very_active":       multiplier = 1.725
        case "extra_active":      multiplier = 1.9
        default:                  multiplier = 1.55
        }
        return bmr * multiplier
    }

    /// Goal-adjusted calories — used for previews without mutating stored targets.
    var tdeeCalories: Double {
        var calories = maintenanceCalories
        switch goal {
        case "lose_weight": calories -= 300  // moderate deficit (~0.3 kg/week)
        case "gain_muscle": calories += 300  // lean surplus
        default: break
        }
        return max(calories, 1200)
    }

    func recalculateTDEE() {
        let calories = tdeeCalories
        calorieTarget = calories.rounded()

        let (pPct, fPct, cPct) = macroPercentages(for: macroSplit)
        proteinG = ((calories * pPct) / 4).rounded()
        fatG     = ((calories * fPct) / 9).rounded()
        carbsG   = ((calories * cPct) / 4).rounded()
    }

    /// Returns (proteinPct, fatPct, carbsPct) for a given split ID.
    func macroPercentages(for split: String) -> (Double, Double, Double) {
        switch split {
        case "lower_carb":  return (0.40, 0.40, 0.20)
        case "higher_carb": return (0.30, 0.20, 0.50)
        default:            return (0.30, 0.35, 0.35) // moderate_carb
        }
    }

    private func ageYears() -> Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 30
    }
}
