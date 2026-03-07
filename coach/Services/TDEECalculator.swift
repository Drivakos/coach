import Foundation

struct TDEECalculator {

    struct Targets {
        let calories: Double
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
    }

    // MARK: - Macro split percentages

    /// Returns (proteinPct, fatPct, carbsPct) for a given macro split.
    static func macroPercentages(for split: MacroSplit) -> (Double, Double, Double) {
        switch split {
        case .lowerCarb:  return (0.40, 0.40, 0.20)
        case .higherCarb: return (0.30, 0.20, 0.50)
        case .moderateCarb: return (0.30, 0.35, 0.35)
        }
    }

    // MARK: - Step-count → activity label

    static func multiplier(fromSteps steps: Int) -> Double {
        switch steps {
        case ..<3_000:          return 1.2
        case 3_000..<5_000:     return 1.375
        case 5_000..<8_000:     return 1.55
        case 8_000..<12_000:    return 1.725
        default:                return 1.9
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

    // MARK: - Core calculation

    /// Calculate targets from a pre-resolved activity multiplier.
    static func calculate(
        sex: String,
        weightKg: Double,
        heightCm: Double,
        age: Int,
        activityMultiplier: Double,
        goal: Goal,
        macroSplit: MacroSplit
    ) -> Targets {
        let bmr = sex == "male"
            ? 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
            : 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161

        var calories = bmr * activityMultiplier + goal.calorieAdjustment
        calories = max(calories, 1200).rounded()

        let (pPct, fPct, cPct) = macroPercentages(for: macroSplit)
        return Targets(
            calories: calories,
            proteinG: ((calories * pPct) / 4).rounded(),
            carbsG:   ((calories * cPct) / 4).rounded(),
            fatG:     ((calories * fPct) / 9).rounded()
        )
    }

    /// Calculate targets from typed domain enums.
    static func calculate(
        sex: String, weightKg: Double, heightCm: Double, age: Int,
        activityLevel: ActivityLevel, goal: Goal, macroSplit: MacroSplit
    ) -> Targets {
        calculate(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age,
            activityMultiplier: activityLevel.activityMultiplier,
            goal: goal, macroSplit: macroSplit
        )
    }

    /// Calculate targets from raw Supabase strings.
    static func calculate(
        sex: String, weightKg: Double, heightCm: Double, age: Int,
        activityLevel: String, goal goalStr: String, macroSplit splitStr: String
    ) -> Targets {
        calculate(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age,
            activityLevel: ActivityLevel(rawValue: activityLevel) ?? .moderatelyActive,
            goal: Goal(rawValue: goalStr) ?? .maintain,
            macroSplit: MacroSplit(rawValue: splitStr) ?? .moderateCarb
        )
    }

    /// Calculate targets from today's actual step count.
    static func calculate(
        sex: String, weightKg: Double, heightCm: Double, age: Int,
        steps: Int, goal: Goal, macroSplit: MacroSplit
    ) -> Targets {
        calculate(
            sex: sex, weightKg: weightKg, heightCm: heightCm, age: age,
            activityMultiplier: multiplier(fromSteps: steps),
            goal: goal, macroSplit: macroSplit
        )
    }
}
