import Foundation

/// Builds a 7-day meal plan by mining the user's food log history.
///
/// Algorithm:
/// 1. Group recent logs by meal time (breakfast / lunch / dinner / snack)
/// 2. Rank foods by frequency within each slot
/// 3. Pick top 3 foods per slot, rotating across days for variety
/// 4. Average quantities/macros across all logged instances of each food
///
/// Requires ≥7 food logs across ≥2 distinct meal slots.
/// Returns needsAI = true when data is insufficient (AI skeleton planned later).
struct MealPlanEngine {
    let recentLogs: [FoodLog]

    private let minimumLogs      = 7
    private let minimumMealTypes = 2
    private let optionsPerSlot   = 3

    func generate() -> (days: [EngineDay]?, needsAI: Bool) {
        let grouped = groupByMealType(recentLogs)

        guard recentLogs.count  >= minimumLogs,
              grouped.keys.count >= minimumMealTypes else {
            return (nil, true)
        }

        let topByType: [MealType: [EngineItem]] = MealType.allCases.reduce(into: [:]) { dict, slot in
            guard let logs = grouped[slot], !logs.isEmpty else { return }
            dict[slot] = topItems(from: logs, max: optionsPerSlot)
        }

        let days: [EngineDay] = (1...7).map { dayOfWeek in
            let rotationIndex = dayOfWeek - 1
            let meals: [EngineMeal] = MealType.allCases.compactMap { slot in
                guard let options = topByType[slot], !options.isEmpty else { return nil }
                return EngineMeal(type: slot, items: [options[rotationIndex % options.count]])
            }
            return EngineDay(dayOfWeek: dayOfWeek, meals: meals)
        }

        return (days, false)
    }

    // MARK: - Private helpers

    private func groupByMealType(_ logs: [FoodLog]) -> [MealType: [FoodLog]] {
        let cal = Calendar.current
        return Dictionary(grouping: logs) { log in
            MealType.from(hour: cal.component(.hour, from: log.loggedAt))
        }
    }

    /// Groups logs by food name, sorts by frequency, averages macros.
    private func topItems(from logs: [FoodLog], max count: Int) -> [EngineItem] {
        let byName = Dictionary(grouping: logs) { $0.name.lowercased() }
        return byName
            .sorted { $0.value.count > $1.value.count }
            .prefix(count)
            .map { _, items in
                let n = Double(items.count)
                return EngineItem(
                    name:          items.first!.name,
                    calories:      (items.reduce(0) { $0 + $1.calories      } / n).rounded(),
                    proteinG:      (items.reduce(0) { $0 + $1.protein       } / n).rounded(),
                    carbsG:        (items.reduce(0) { $0 + $1.carbs         } / n).rounded(),
                    fatG:          (items.reduce(0) { $0 + $1.fat           } / n).rounded(),
                    quantityGrams: (items.reduce(0) { $0 + $1.quantityGrams } / n).rounded()
                )
            }
    }
}
