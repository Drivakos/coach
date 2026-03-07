import Foundation

/// Pure, stateless engine that computes next week's calorie/macro targets
/// based on last week's data and goal. No network calls.
///
/// Science basis:
/// - Fat loss rate: 0.5–1% body weight/week (Helms et al. 2014)
/// - Lean bulk rate: 0.1–0.5% body weight/week (Barbalho et al. 2020)
/// - Max weekly adjustment: ±300 kcal (avoid metabolic adaptation shock)
/// - Protein always protected (1.6g/kg minimum; Morton et al. 2018)
/// - Calorie floor: 1200 kcal (absolute minimum)
struct WeeklyPlanEngine {
    let lastWeek: WeeklySummary
    let previousWeek: WeeklySummary?
    let currentTarget: StoredTarget
    let goal: Goal

    func adjust() -> WeeklyPlanAdjustment {
        let (rawDelta, reason) = computeDelta()
        return applyDelta(rawDelta, reason: reason)
    }

    // MARK: - Step 1: Determine kcal delta and reason

    private func computeDelta() -> (Double, String) {
        let weightChangePct: Double? = {
            guard let lastW  = lastWeek.avgWeightKg,
                  let prevW  = previousWeek?.avgWeightKg,
                  prevW > 0 else { return nil }
            return ((lastW - prevW) / prevW) * 100
        }()

        let goodAdherence = (lastWeek.daysLogged ?? 0) >= 4

        switch goal {

        case .loseWeight:
            guard let pct = weightChangePct else {
                return (0, "No weight data yet. Log your morning weight daily to unlock automatic target adjustments.")
            }
            if pct < -1.0 {
                return (+200, String(format: "Losing %.1f%%/week — above the safe threshold. Added 200 kcal to protect muscle.", abs(pct)))
            } else if pct >= -0.15 {
                if goodAdherence {
                    return (-150, String(format: "Weight stalled (%.1f%%/week) with consistent tracking. Reduced by 150 kcal.", pct))
                } else {
                    return (0, "Weight unchanged, but tracking was inconsistent. Log at least 5 days before targets are adjusted.")
                }
            } else {
                return (0, String(format: "Weight loss on track at %.1f%%/week. Targets maintained.", abs(pct)))
            }

        case .gainMuscle:
            guard let pct = weightChangePct else {
                return (0, "No weight data yet. Log your morning weight daily to unlock automatic target adjustments.")
            }
            if pct > 0.5 {
                return (-100, String(format: "Gaining +%.1f%%/week — above optimal lean bulk rate. Reduced by 100 kcal to limit fat gain.", pct))
            } else if pct < 0.1 {
                return (+200, "Weight not increasing. Added 200 kcal to support muscle growth.")
            } else {
                return (0, String(format: "Lean bulk on track at +%.1f%%/week. Targets maintained.", pct))
            }

        case .maintain:
            guard let pct = weightChangePct else {
                return (0, "No weight data yet. Log your morning weight daily to unlock automatic target adjustments.")
            }
            if pct < -0.5 {
                return (+100, String(format: "Weight dropping %.1f%%/week. Added 100 kcal to stabilise.", abs(pct)))
            } else if pct > 0.5 {
                return (-100, String(format: "Weight rising +%.1f%%/week. Reduced by 100 kcal to stabilise.", pct))
            } else {
                return (0, "Weight stable. Targets maintained.")
            }
        }
    }

    // MARK: - Step 2: Apply delta, protect protein, redistribute macros

    private func applyDelta(_ rawDelta: Double, reason: String) -> WeeklyPlanAdjustment {
        // Clamp to ±300 kcal per week
        let clampedDelta = max(min(rawDelta, 300), -300)
        let newCalories  = max((currentTarget.calories + clampedDelta).rounded(), 1200)
        let actualDelta  = newCalories - currentTarget.calories

        // Protein is always fixed (protect muscle)
        let protein = currentTarget.proteinG

        // Distribute remaining calories between carbs and fat using current ratio
        let currentCarbsCal = currentTarget.carbsG * 4
        let currentFatCal   = currentTarget.fatG   * 9
        let currentCFTotal  = currentCarbsCal + currentFatCal
        let carbsRatio = currentCFTotal > 0 ? currentCarbsCal / currentCFTotal : 0.6

        let remainingForCF = newCalories - (protein * 4)
        let newCarbs = max(((remainingForCF * carbsRatio)       / 4).rounded(), 0)
        let newFat   = max(((remainingForCF * (1 - carbsRatio)) / 9).rounded(), 0)

        return WeeklyPlanAdjustment(
            calories:  newCalories,
            proteinG:  protein,
            carbsG:    newCarbs,
            fatG:      newFat,
            deltaKcal: actualDelta,
            reason:    reason
        )
    }
}
