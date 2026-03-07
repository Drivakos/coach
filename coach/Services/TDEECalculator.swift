import Foundation

struct TDEECalculator {

    struct Targets {
        let calories: Double
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
    }

    // MARK: - Step-count → activity multiplier
    // Based on standard step-count activity thresholds used in fitness research.

    static func multiplier(fromSteps steps: Int) -> Double {
        switch steps {
        case ..<3_000:          return 1.2     // sedentary
        case 3_000..<5_000:     return 1.375   // lightly active
        case 5_000..<8_000:     return 1.55    // moderately active
        case 8_000..<12_000:    return 1.725   // very active
        default:                return 1.9     // extra active
        }
    }

    static func activityLabel(fromSteps steps: Int) -> String {
        switch steps {
        case ..<3_000:          return "Sedentary"
        case 3_000..<5_000:     return "Lightly Active"
        case 5_000..<8_000:     return "Moderately Active"
        case 8_000..<12_000:    return "Very Active"
        default:                return "Extra Active"
        }
    }

    // MARK: - Activity level string → multiplier

    static func multiplier(fromLevel level: String) -> Double {
        switch level {
        case "sedentary":           return 1.2
        case "lightly_active":      return 1.375
        case "moderately_active":   return 1.55
        case "very_active":         return 1.725
        case "extra_active":        return 1.9
        default:                    return 1.55
        }
    }

    // MARK: - Core calculation

    /// Calculate targets from a pre-resolved activity multiplier.
    static func calculate(
        sex: String,
        weightKg: Double,
        heightCm: Double,
        age: Int,
        activityMultiplier: Double,
        goal: String,
        macroSplit: String
    ) -> Targets {
        let bmr = sex == "male"
            ? 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
            : 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161

        var calories = bmr * activityMultiplier
        switch goal {
        case "lose_weight": calories -= 300
        case "gain_muscle": calories += 300
        default: break
        }
        calories = max(calories, 1200).rounded()

        let (pPct, fPct, cPct): (Double, Double, Double)
        switch macroSplit {
        case "lower_carb":  (pPct, fPct, cPct) = (0.40, 0.40, 0.20)
        case "higher_carb": (pPct, fPct, cPct) = (0.30, 0.20, 0.50)
        default:            (pPct, fPct, cPct) = (0.30, 0.35, 0.35)
        }

        return Targets(
            calories: calories,
            proteinG: ((calories * pPct) / 4).rounded(),
            carbsG:   ((calories * cPct) / 4).rounded(),
            fatG:     ((calories * fPct) / 9).rounded()
        )
    }

    /// Calculate targets from a profile activity level string.
    static func calculate(
        sex: String, weightKg: Double, heightCm: Double, age: Int,
        activityLevel: String, goal: String, macroSplit: String
    ) -> Targets {
        calculate(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age,
            activityMultiplier: multiplier(fromLevel: activityLevel),
            goal: goal, macroSplit: macroSplit
        )
    }

    /// Calculate targets from today's actual step count.
    static func calculate(
        sex: String, weightKg: Double, heightCm: Double, age: Int,
        steps: Int, goal: String, macroSplit: String
    ) -> Targets {
        calculate(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age,
            activityMultiplier: multiplier(fromSteps: steps),
            goal: goal, macroSplit: macroSplit
        )
    }
}
