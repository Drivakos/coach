import Foundation
import Supabase

/// Read-only plan service + single "generate" call that delegates to the
/// server-side Edge Function. No engines, no Perplexity, no rollup logic here.
struct WeeklyPlanService {

    // MARK: - Fetch

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

    // MARK: - Generation (delegates to Edge Function)

    /// Calls the `generate-weekly-plans` Edge Function for the current user,
    /// then reads back the freshly created plan.
    ///
    /// - Parameter force: pass `true` to regenerate even if a plan already exists.
    @discardableResult
    func generateForCurrentWeek(force: Bool = false) async throws -> WeeklyPlan {
        struct Payload: Encodable { let force: Bool }
        try await supabase.functions.invoke(
            "generate-weekly-plans",
            options: .init(body: Payload(force: force))
        )
        let weekStart = CheckInService.mondayString()
        guard let plan = try await fetchPlan(for: weekStart) else {
            throw WeeklyPlanError.planNotFound
        }
        return plan
    }

    // MARK: - Private

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
}

enum WeeklyPlanError: LocalizedError {
    case planNotFound
    var errorDescription: String? { "Plan could not be generated. Please try again." }
}
