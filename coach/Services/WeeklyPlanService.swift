import Foundation
import Supabase

struct WeeklyPlanService {

    private let weeklySummaryService = WeeklySummaryService()

    // MARK: - Minimal read-back structs (private to this file)

    private struct InsertedDay: Decodable {
        let id: UUID
        let dayOfWeek: Int
        enum CodingKeys: String, CodingKey { case id; case dayOfWeek = "day_of_week" }
    }

    private struct InsertedMeal: Decodable {
        let id: UUID
        let mealPlanDayId: UUID
        let mealType: String
        enum CodingKeys: String, CodingKey {
            case id
            case mealPlanDayId = "meal_plan_day_id"
            case mealType      = "meal_type"
        }
    }

    // MARK: - Public API

    func generateIfNeeded(goal: Goal, currentTarget: StoredTarget) async {
        let thisMonday = CheckInService.mondayString()
        do {
            guard try await fetchPlan(for: thisMonday) == nil else { return }
            _ = try await generateForWeek(thisMonday, goal: goal, currentTarget: currentTarget)
        } catch {
            print("WeeklyPlanService generateIfNeeded error:", error)
        }
    }

    func fetchCurrentPlan() async throws -> WeeklyPlan? {
        try await fetchPlan(for: CheckInService.mondayString())
    }

    func fetchDays(forPlan planId: UUID) async throws -> [MealPlanDay] {
        try await supabase
            .from("meal_plan_days")
            .select("*, meal_plan_meals(*, meal_plan_items(*))")
            .eq("weekly_plan_id", value: planId)
            .order("day_of_week")
            .execute()
            .value
    }

    // MARK: - Item editing (full user control)

    func deleteItem(_ itemId: UUID) async throws {
        try await supabase
            .from("meal_plan_items")
            .delete()
            .eq("id", value: itemId)
            .execute()
    }

    func addItem(_ insert: MealPlanItemInsert) async throws -> MealPlanItem {
        try await supabase
            .from("meal_plan_items")
            .insert(insert)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Plan generation

    @discardableResult
    func generateForWeek(_ weekStart: String, goal: Goal, currentTarget: StoredTarget) async throws -> WeeklyPlan {
        let session = try await supabase.auth.session
        let userId  = session.user.id

        // 1. Ensure this week's summary is fresh
        await weeklySummaryService.rollUpIfNeeded()

        // 2. Past weekly summaries (most-recent first, excluding current week)
        let allSummaries  = try await weeklySummaryService.fetchAll()
        let pastSummaries = allSummaries
            .filter { $0.weekStart < weekStart }
            .sorted { $0.weekStart > $1.weekStart }

        // 3. Science-based target adjustment
        let adjustment: WeeklyPlanAdjustment = {
            guard let last = pastSummaries.first else {
                return WeeklyPlanAdjustment(
                    calories: currentTarget.calories, proteinG: currentTarget.proteinG,
                    carbsG:   currentTarget.carbsG,   fatG:     currentTarget.fatG,
                    deltaKcal: 0, reason: "First week — targets set from your profile."
                )
            }
            return WeeklyPlanEngine(
                lastWeek:      last,
                previousWeek:  pastSummaries.dropFirst().first,
                currentTarget: currentTarget,
                goal:          goal
            ).adjust()
        }()

        // 4. Food log history for meal plan
        let recentLogs            = try await fetchRecentFoodLogs()
        let (engineDays, needsAI) = MealPlanEngine(recentLogs: recentLogs).generate()

        // 5. Upsert weekly_plans → get plan ID back
        let plan: WeeklyPlan = try await supabase
            .from("weekly_plans")
            .upsert(WeeklyPlanInsert(
                userId:           userId,
                weekStart:        weekStart,
                calories:         adjustment.calories,
                proteinG:         adjustment.proteinG,
                carbsG:           adjustment.carbsG,
                fatG:             adjustment.fatG,
                adjustmentKcal:   adjustment.deltaKcal,
                adjustmentReason: adjustment.reason,
                needsAIPlan:      needsAI
            ), onConflict: "user_id,week_start")
            .select()
            .single()
            .execute()
            .value

        // 6. Save relational meal plan (3 batch inserts)
        if let days = engineDays {
            try await saveMealPlan(days: days, planId: plan.id)
        }

        // 7. Write new nutrition_targets if targets changed
        if abs(adjustment.deltaKcal) > 1 {
            try await insertNewNutritionTargets(
                userId: userId, calories: adjustment.calories,
                proteinG: adjustment.proteinG, carbsG: adjustment.carbsG,
                fatG: adjustment.fatG, effectiveFrom: weekStart
            )
        }

        return plan
    }

    // MARK: - Relational meal plan insertion (3 round-trips regardless of plan size)

    private func saveMealPlan(days: [EngineDay], planId: UUID) async throws {
        // Clear any previous meal plan for this week (handles regeneration)
        try await supabase
            .from("meal_plan_days")
            .delete()
            .eq("weekly_plan_id", value: planId)
            .execute()

        // Batch 1: all 7 days → IDs
        let insertedDays: [InsertedDay] = try await supabase
            .from("meal_plan_days")
            .insert(days.map { MealPlanDayInsert(weeklyPlanId: planId, dayOfWeek: $0.dayOfWeek) })
            .select("id, day_of_week")
            .execute()
            .value

        let dayDict = Dictionary(uniqueKeysWithValues: insertedDays.map { ($0.dayOfWeek, $0) })

        // Batch 2: all meals → IDs
        let mealInserts: [MealPlanMealInsert] = days.flatMap { day -> [MealPlanMealInsert] in
            guard let inserted = dayDict[day.dayOfWeek] else { return [] }
            return day.meals.enumerated().map { idx, meal in
                MealPlanMealInsert(mealPlanDayId: inserted.id, mealType: meal.type.rawValue, sortOrder: idx)
            }
        }
        guard !mealInserts.isEmpty else { return }

        let insertedMeals: [InsertedMeal] = try await supabase
            .from("meal_plan_meals")
            .insert(mealInserts)
            .select("id, meal_plan_day_id, meal_type")
            .execute()
            .value

        let mealDict = Dictionary(uniqueKeysWithValues: insertedMeals.map {
            ("\($0.mealPlanDayId)-\($0.mealType)", $0)
        })

        // Batch 3: all items
        let itemInserts: [MealPlanItemInsert] = days.flatMap { day -> [MealPlanItemInsert] in
            guard let insertedDay = dayDict[day.dayOfWeek] else { return [] }
            return day.meals.flatMap { meal -> [MealPlanItemInsert] in
                guard let insertedMeal = mealDict["\(insertedDay.id)-\(meal.type.rawValue)"]
                else { return [] }
                return meal.items.enumerated().map { idx, item in
                    MealPlanItemInsert(
                        mealPlanMealId: insertedMeal.id, name: item.name,
                        calories: item.calories, proteinG: item.proteinG,
                        carbsG: item.carbsG, fatG: item.fatG,
                        quantityGrams: item.quantityGrams, sortOrder: idx
                    )
                }
            }
        }
        if !itemInserts.isEmpty {
            try await supabase.from("meal_plan_items").insert(itemInserts).execute()
        }
    }

    // MARK: - Private fetch helpers

    private func fetchPlan(for weekStart: String) async throws -> WeeklyPlan? {
        let results: [WeeklyPlan] = try await supabase
            .from("weekly_plans")
            .select()
            .eq("week_start", value: weekStart)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    private func fetchRecentFoodLogs() async throws -> [FoodLog] {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let iso   = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return try await supabase
            .from("food_logs")
            .select()
            .gte("logged_at", value: iso.string(from: start))
            .order("logged_at", ascending: false)
            .execute()
            .value
    }

    private func insertNewNutritionTargets(
        userId: UUID, calories: Double, proteinG: Double,
        carbsG: Double, fatG: Double, effectiveFrom: String
    ) async throws {
        struct T: Encodable {
            let user_id: UUID; let calories: Double
            let protein_g: Double; let carbs_g: Double; let fat_g: Double
            let effective_from: String
        }
        try await supabase
            .from("nutrition_targets")
            .insert(T(user_id: userId, calories: calories, protein_g: proteinG,
                      carbs_g: carbsG, fat_g: fatG, effective_from: effectiveFrom))
            .execute()
    }
}

enum WeeklyPlanError: LocalizedError {
    case noNutritionTargets
    var errorDescription: String? { "No nutrition targets found. Complete your profile setup." }
}
