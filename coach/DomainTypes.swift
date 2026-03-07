import Foundation

// MARK: - Activity Level

enum ActivityLevel: String, CaseIterable {
    case sedentary        = "sedentary"
    case lightlyActive    = "lightly_active"
    case moderatelyActive = "moderately_active"
    case veryActive       = "very_active"
    case extraActive      = "extra_active"

    var label: String {
        switch self {
        case .sedentary:        return "Sedentary"
        case .lightlyActive:    return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive:       return "Very Active"
        case .extraActive:      return "Extra Active"
        }
    }

    var activityMultiplier: Double {
        switch self {
        case .sedentary:        return 1.2
        case .lightlyActive:    return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive:       return 1.725
        case .extraActive:      return 1.9
        }
    }
}

// MARK: - Goal

enum Goal: String, CaseIterable {
    case loseWeight = "lose_weight"
    case maintain   = "maintain"
    case gainMuscle = "gain_muscle"

    var label: String {
        switch self {
        case .loseWeight:  return "Lose Weight"
        case .maintain:    return "Maintain Weight"
        case .gainMuscle:  return "Gain Muscle"
        }
    }

    var calorieAdjustment: Double {
        switch self {
        case .loseWeight: return -300
        case .maintain:   return 0
        case .gainMuscle: return +300
        }
    }
}

// MARK: - Macro Split

enum MacroSplit: String, CaseIterable {
    case moderateCarb = "moderate_carb"
    case lowerCarb    = "lower_carb"
    case higherCarb   = "higher_carb"

    var label: String {
        switch self {
        case .moderateCarb: return "Moderate Carb"
        case .lowerCarb:    return "Lower Carb"
        case .higherCarb:   return "Higher Carb"
        }
    }
}
