import Foundation
import SwiftUI

// MARK: - Insight Model

struct CoachInsight: Identifiable {
    enum Severity { case success, info, caution, warning }

    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let severity: Severity
}

extension CoachInsight.Severity {
    var color: Color {
        switch self {
        case .success: return .green
        case .info:    return .blue
        case .caution: return .orange
        case .warning: return .red
        }
    }
}

// MARK: - Engine

/// Pure, stateless rule engine. No network calls — all inputs are pre-fetched.
struct CoachEngine {
    let weightPoints: [DailyWeightPoint]
    let weeklyMacros: WeeklyMacros?
    let target: StoredTarget
    let goal: Goal

    func generate() -> [CoachInsight] {
        [
            weightChangeInsight(),
            calorieAdherenceInsight(),
            proteinInsight(),
            loggingConsistencyInsight()
        ].compactMap { $0 }
    }

    // MARK: - Rule 1: Weight change rate
    // Science: Safe fat loss = 0.5–1% BW/week. Lean gain = 0.1–0.5% BW/week.
    // Source: Helms et al. (2014), Barbalho et al. (2020)

    private func weightChangeInsight() -> CoachInsight? {
        let sorted = weightPoints.sorted { $0.date < $1.date }
        guard sorted.count >= 2,
              let first = sorted.first, let last = sorted.last else { return nil }

        let daysDiff = max(1, Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1)
        guard daysDiff >= 2 else { return nil }

        let changeKg = last.weightKg - first.weightKg
        let weeklyRateKg = changeKg / Double(daysDiff) * 7
        let refWeight = sorted.map(\.weightKg).reduce(0, +) / Double(sorted.count)
        let weeklyRatePct = (weeklyRateKg / refWeight) * 100

        switch goal {
        case .loseWeight:
            if weeklyRatePct < -1.0 {
                return CoachInsight(
                    icon: "exclamationmark.triangle.fill",
                    title: "Losing weight too fast",
                    message: String(format: "You're losing ~%.1fkg/week. Above 1%%/week risks muscle loss — add 150–200 kcal.", abs(weeklyRateKg)),
                    severity: .warning
                )
            } else if weeklyRatePct > -0.15 && daysDiff >= 5 {
                return CoachInsight(
                    icon: "info.circle.fill",
                    title: "Weight loss stalled",
                    message: "No significant change this week. Try reducing intake by 100–150 kcal or adding 2,000 steps/day.",
                    severity: .caution
                )
            } else if weeklyRatePct <= -0.15 && weeklyRatePct >= -1.0 {
                return CoachInsight(
                    icon: "checkmark.circle.fill",
                    title: "Weight loss on track",
                    message: String(format: "Losing ~%.1fkg/week — within the safe 0.5–1%% body weight range.", abs(weeklyRateKg)),
                    severity: .success
                )
            }

        case .gainMuscle:
            if weeklyRatePct > 0.5 {
                return CoachInsight(
                    icon: "exclamationmark.triangle.fill",
                    title: "Gaining too fast",
                    message: String(format: "+%.1fkg/week exceeds the optimal lean gaining rate. Reduce by ~100 kcal to minimise fat gain.", weeklyRateKg),
                    severity: .caution
                )
            } else if weeklyRatePct >= 0.1 && weeklyRatePct <= 0.5 {
                return CoachInsight(
                    icon: "checkmark.circle.fill",
                    title: "Lean bulk on track",
                    message: String(format: "+%.1fkg/week — ideal rate for lean muscle gain.", weeklyRateKg),
                    severity: .success
                )
            } else if weeklyRatePct < 0.1 && daysDiff >= 5 {
                return CoachInsight(
                    icon: "info.circle.fill",
                    title: "Not gaining",
                    message: "Weight hasn't increased this week. Ensure you're in a 200–300 kcal surplus with adequate protein.",
                    severity: .caution
                )
            }

        case .maintain:
            if weeklyRatePct < -0.5 {
                return CoachInsight(
                    icon: "info.circle.fill",
                    title: "Weight trending down",
                    message: String(format: "Losing ~%.1fkg/week. If unintentional, increase calories slightly.", abs(weeklyRateKg)),
                    severity: .caution
                )
            } else if weeklyRatePct > 0.5 {
                return CoachInsight(
                    icon: "info.circle.fill",
                    title: "Weight trending up",
                    message: String(format: "Gaining ~%.1fkg/week. If unintentional, review portion sizes.", weeklyRateKg),
                    severity: .caution
                )
            }
        }
        return nil
    }

    // MARK: - Rule 2: Calorie adherence
    // Science: Consistent caloric intake drives predictable body composition change.

    private func calorieAdherenceInsight() -> CoachInsight? {
        guard let macros = weeklyMacros, macros.daysLogged > 0 else { return nil }
        let avg = macros.avgCalories
        let tgt = target.calories
        let diff = avg - tgt

        if diff > 250 {
            return CoachInsight(
                icon: "flame.fill",
                title: "Over calorie target",
                message: String(format: "Averaging +%.0f kcal over goal. Small daily surpluses compound quickly — review portions.", diff),
                severity: .caution
            )
        } else if diff < -300 {
            return CoachInsight(
                icon: "fork.knife",
                title: "Under calorie target",
                message: String(format: "Averaging %.0f kcal below goal. Chronic under-eating slows metabolism and reduces muscle retention.", abs(diff)),
                severity: .warning
            )
        } else {
            return CoachInsight(
                icon: "checkmark.circle.fill",
                title: "Calories on target",
                message: String(format: "Averaging %.0f kcal — within range of your %.0f kcal goal.", avg, tgt),
                severity: .success
            )
        }
    }

    // MARK: - Rule 3: Protein adequacy
    // Science: 1.6g/kg minimum for muscle retention; 2.0–2.2g/kg during a deficit.
    // Source: Morton et al. (2018), Stokes et al. (2018)

    private func proteinInsight() -> CoachInsight? {
        guard let macros = weeklyMacros, macros.daysLogged >= 3 else { return nil }
        let avg = macros.avgProteinG
        let tgt = target.proteinG
        let pct = avg / max(tgt, 1)

        if pct < 0.8 {
            return CoachInsight(
                icon: "exclamationmark.triangle.fill",
                title: "Low protein intake",
                message: String(format: "Averaging %.0fg vs your %.0fg target. Aim for ≥1.6g/kg to protect muscle.", avg, tgt),
                severity: .warning
            )
        } else if pct >= 1.0 {
            return CoachInsight(
                icon: "checkmark.circle.fill",
                title: "Protein on target",
                message: String(format: "Averaging %.0fg — meeting your %.0fg goal. Muscle retention is supported.", avg, tgt),
                severity: .success
            )
        }
        return nil
    }

    // MARK: - Rule 4: Logging consistency
    // Science: Self-monitoring frequency correlates strongly with dietary adherence.
    // Source: Burke et al. (2011)

    private func loggingConsistencyInsight() -> CoachInsight? {
        guard let macros = weeklyMacros else { return nil }
        let days = macros.daysLogged
        if days < 4 {
            return CoachInsight(
                icon: "calendar.badge.exclamationmark",
                title: "Log more consistently",
                message: "You've logged \(days)/7 days. Consistent tracking is the #1 predictor of dietary success — aim for 5+ days.",
                severity: .caution
            )
        }
        return nil
    }
}
