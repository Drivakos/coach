import Foundation

// MARK: - Meal type

enum MealType: String, CaseIterable, Codable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MealType(rawValue: raw) ?? .snack
    }

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        case .snack:     return "carrot.fill"
        }
    }

    static func from(hour: Int) -> MealType {
        switch hour {
        case 5..<10:  return .breakfast
        case 10..<15: return .lunch
        case 15..<21: return .dinner
        default:      return .snack
        }
    }
}

// MARK: - DB read models (fetched via nested Supabase select)

struct MealPlanDay: Identifiable, Decodable {
    let id: UUID
    let weeklyPlanId: UUID
    let dayOfWeek: Int
    var meals: [MealPlanMeal]

    enum CodingKeys: String, CodingKey {
        case id
        case weeklyPlanId  = "weekly_plan_id"
        case dayOfWeek     = "day_of_week"
        case meals         = "meal_plan_meals"
    }

    var totalCalories: Double { meals.reduce(0) { $0 + $1.totalCalories } }
    var totalProtein:  Double { meals.reduce(0) { $0 + $1.totalProtein  } }
    var totalCarbs:    Double { meals.reduce(0) { $0 + $1.totalCarbs    } }
    var totalFat:      Double { meals.reduce(0) { $0 + $1.totalFat      } }
}

struct MealPlanMeal: Identifiable, Decodable {
    let id: UUID
    let mealType: MealType
    var items: [MealPlanItem]

    enum CodingKeys: String, CodingKey {
        case id
        case mealType = "meal_type"
        case items    = "meal_plan_items"
    }

    var totalCalories:   Double { items.reduce(0) { $0 + $1.calories } }
    var totalProtein:    Double { items.reduce(0) { $0 + $1.proteinG } }
    var totalCarbs:      Double { items.reduce(0) { $0 + $1.carbsG   } }
    var totalFat:        Double { items.reduce(0) { $0 + $1.fatG     } }
    /// Calories from primary (non-alternative) items only — used in the weekly plan view.
    var primaryCalories: Double { items.filter { !$0.isAlternative }.reduce(0) { $0 + $1.calories } }
}

struct MealPlanItem: Identifiable, Decodable {
    let id: UUID
    var name: String
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var quantityGrams: Double
    var sortOrder: Int
    var isFamiliar: Bool
    var isAlternative: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, calories
        case proteinG      = "protein_g"
        case carbsG        = "carbs_g"
        case fatG          = "fat_g"
        case quantityGrams = "quantity_grams"
        case sortOrder     = "sort_order"
        case isFamiliar    = "is_familiar"
        case isAlternative = "is_alternative"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,   forKey: .id)
        name          = try c.decode(String.self, forKey: .name)
        calories      = try c.decode(Double.self, forKey: .calories)
        proteinG      = try c.decode(Double.self, forKey: .proteinG)
        carbsG        = try c.decode(Double.self, forKey: .carbsG)
        fatG          = try c.decode(Double.self, forKey: .fatG)
        quantityGrams = try c.decode(Double.self, forKey: .quantityGrams)
        sortOrder     = try c.decode(Int.self,    forKey: .sortOrder)
        // Columns added in migration — default false for older rows
        isFamiliar    = (try? c.decode(Bool.self, forKey: .isFamiliar))    ?? false
        isAlternative = (try? c.decode(Bool.self, forKey: .isAlternative)) ?? false
    }
}

// MARK: - DB insert models

struct MealPlanDayInsert: Encodable {
    let weeklyPlanId: UUID
    let dayOfWeek: Int
    enum CodingKeys: String, CodingKey {
        case weeklyPlanId = "weekly_plan_id"
        case dayOfWeek    = "day_of_week"
    }
}

struct MealPlanMealInsert: Encodable {
    let mealPlanDayId: UUID
    let mealType: String
    let sortOrder: Int
    enum CodingKeys: String, CodingKey {
        case mealPlanDayId = "meal_plan_day_id"
        case mealType      = "meal_type"
        case sortOrder     = "sort_order"
    }
}

struct MealPlanItemInsert: Encodable {
    let mealPlanMealId: UUID
    let name: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let quantityGrams: Double
    let sortOrder: Int
    let isFamiliar: Bool
    let isAlternative: Bool
    enum CodingKeys: String, CodingKey {
        case mealPlanMealId = "meal_plan_meal_id"
        case name, calories
        case proteinG      = "protein_g"
        case carbsG        = "carbs_g"
        case fatG          = "fat_g"
        case quantityGrams = "quantity_grams"
        case sortOrder     = "sort_order"
        case isFamiliar    = "is_familiar"
        case isAlternative = "is_alternative"
    }
}

// MARK: - Weekly plan (DB read model — no JSONB)

struct WeeklyPlan: Identifiable, Decodable {
    let id: UUID
    let weekStart: String
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let adjustmentKcal: Double
    let adjustmentReason: String?
    let needsAIPlan: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case weekStart        = "week_start"
        case calories
        case proteinG         = "protein_g"
        case carbsG           = "carbs_g"
        case fatG             = "fat_g"
        case adjustmentKcal   = "adjustment_kcal"
        case adjustmentReason = "adjustment_reason"
        case needsAIPlan      = "needs_ai_plan"
        case createdAt        = "created_at"
    }
}

