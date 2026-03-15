import SwiftUI

// MARK: - Main view

struct WeeklyPlanView: View {
    @Environment(AppState.self) private var appState
    @State private var plan: WeeklyPlan?           = nil
    @State private var days: [MealPlanDay]         = []
    @State private var isLoading                   = true
    @State private var errorMessage: String?       = nil
    @State private var addingToMeal: MealPlanMeal? = nil
    @State private var selectedDay: Int            = {
        let w = Calendar.current.component(.weekday, from: Date())
        return w == 1 ? 7 : w - 1
    }()
    @State private var expandedMealIds: Set<UUID>  = []

    private let service = WeeklyPlanService()

    private var isoToday: Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return w == 1 ? 7 : w - 1
    }

    private var weekLabel: String {
        guard let monday = CheckInService.dateFormatter.date(from: CheckInService.mondayString())
        else { return "" }
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday)!
        return "\(CheckInService.shortDateFormatter.string(from: monday)) – \(CheckInService.shortDateFormatter.string(from: sunday))"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let msg = errorMessage {
                    ContentUnavailableView(
                        "Couldn't load plan",
                        systemImage: "exclamationmark.triangle",
                        description: Text(msg)
                    )
                } else if let p = plan {
                    planContent(p)
                } else {
                    emptyState
                }
            }
            .navigationTitle("This Week")
            .navigationBarTitleDisplayMode(.large)
            .task { await load() }
            .sheet(item: $addingToMeal) { meal in
                FoodSearchSheet(logDate: Date(), mealType: meal.mealType) { logInsert in
                    Task { await addFood(logInsert, toMeal: meal) }
                }
            }
        }
    }

    // MARK: - Plan content

    @ViewBuilder
    private func planContent(_ plan: WeeklyPlan) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                PlanTargetsCard(plan: plan, weekLabel: weekLabel)

                PlanDayStrip(days: days, selectedDay: $selectedDay, isoToday: isoToday)
                    .onChange(of: selectedDay) { _, _ in
                        withAnimation { expandedMealIds = [] }
                    }

                if plan.needsAIPlan || days.isEmpty {
                    PlanNeedsAICard()
                } else if let di = days.firstIndex(where: { $0.dayOfWeek == selectedDay }) {
                    PlanDayMacroBar(day: days[di], targets: plan)

                    ForEach($days[di].meals) { $meal in
                        PlanMealCard(
                            meal: $meal,
                            isExpanded: expandedMealIds.contains(meal.id),
                            onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    if expandedMealIds.contains(meal.id) {
                                        expandedMealIds.remove(meal.id)
                                    } else {
                                        expandedMealIds.insert(meal.id)
                                    }
                                }
                            },
                            onAddFood: { addingToMeal = meal },
                            onDeleteItem: { item in
                                Task { await deleteItem(item, fromMealId: meal.id, inDayIndex: di) }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Text("No plan yet this week").font(.headline)
                Text("Your plan is generated automatically every Monday based on last week's data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func deleteItem(_ item: MealPlanItem, fromMealId: UUID, inDayIndex di: Int) async {
        do {
            try await service.deleteItem(item.id)
            if let mi = days[di].meals.firstIndex(where: { $0.id == fromMealId }) {
                days[di].meals[mi].items.removeAll { $0.id == item.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addFood(_ logInsert: FoodLogInsert, toMeal meal: MealPlanMeal) async {
        do {
            let newItem = try await service.addItem(MealPlanItemInsert(
                mealPlanMealId: meal.id,
                name:           logInsert.name,
                calories:       logInsert.calories,
                proteinG:       logInsert.protein,
                carbsG:         logInsert.carbs,
                fatG:           logInsert.fat,
                quantityGrams:  logInsert.quantityGrams,
                sortOrder:      meal.items.count,
                isFamiliar:     false,
                isAlternative:  false
            ))
            if let di = days.firstIndex(where: { $0.meals.contains { $0.id == meal.id } }),
               let mi = days[di].meals.firstIndex(where: { $0.id == meal.id }) {
                days[di].meals[mi].items.append(newItem)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func load() async {
        isLoading    = true
        errorMessage = nil
        do {
            plan = try await service.fetchCurrentPlan()
            if let p = plan {
                days = try await service.fetchDays(forPlan: p.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

}


// MARK: - Targets card

private struct PlanTargetsCard: View {
    let plan: WeeklyPlan
    let weekLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Daily Targets")
                        .font(.headline)
                }
                Spacer()
                if plan.adjustmentKcal != 0 {
                    Label(
                        plan.adjustmentKcal > 0
                            ? "+\(Int(plan.adjustmentKcal)) kcal"
                            : "\(Int(plan.adjustmentKcal)) kcal",
                        systemImage: plan.adjustmentKcal > 0
                            ? "arrow.up.circle.fill"
                            : "arrow.down.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(plan.adjustmentKcal > 0 ? .green : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (plan.adjustmentKcal > 0 ? Color.green : Color.orange).opacity(0.12),
                        in: Capsule()
                    )
                }
            }

            HStack(spacing: 8) {
                PlanMacroChip(label: "Calories", value: "\(Int(plan.calories))", unit: "kcal", color: .orange)
                PlanMacroChip(label: "Protein",  value: "\(Int(plan.proteinG))", unit: "g",    color: .red)
                PlanMacroChip(label: "Carbs",    value: "\(Int(plan.carbsG))",   unit: "g",    color: .yellow)
                PlanMacroChip(label: "Fat",      value: "\(Int(plan.fatG))",     unit: "g",    color: .blue)
            }

            if let reason = plan.adjustmentReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct PlanMacroChip: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Day strip

private struct PlanDayStrip: View {
    let days: [MealPlanDay]
    @Binding var selectedDay: Int
    let isoToday: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { iso in
                        PlanDayPill(
                            iso: iso,
                            isToday: iso == isoToday,
                            isSelected: iso == selectedDay,
                            hasData: days.contains(where: { $0.dayOfWeek == iso })
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedDay = iso
                            }
                        }
                        .id(iso)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(selectedDay, anchor: .center)
                }
            }
        }
    }
}

private struct PlanDayPill: View {
    let iso: Int
    let isToday: Bool
    let isSelected: Bool
    let hasData: Bool
    let action: () -> Void

    private var shortName: String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][max(0, min(iso - 1, 6))]
    }

    private var calendarDay: Int {
        guard let monday = CheckInService.dateFormatter.date(from: CheckInService.mondayString()) else { return iso }
        let date = Calendar.current.date(byAdding: .day, value: iso - 1, to: monday) ?? monday
        return Calendar.current.component(.day, from: date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(shortName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        isSelected ? .white
                        : isToday  ? Color.orange
                        : Color.secondary
                    )
                Text("\(calendarDay)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)
                Circle()
                    .fill(hasData
                          ? (isSelected ? Color.white.opacity(0.7) : Color.orange)
                          : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(width: 48, height: 70)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange, lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day macro bar

private struct PlanDayMacroBar: View {
    let day: MealPlanDay
    let targets: WeeklyPlan

    private var calorieRatio: Double {
        guard targets.calories > 0 else { return 0 }
        return min(day.totalCalories / targets.calories, 1.0)
    }

    private var barColor: Color {
        let r = day.totalCalories / max(targets.calories, 1)
        if r > 1.05 { return .red }
        if r > 0.9  { return .green }
        return .orange
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Day Total")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(day.totalCalories)) / \(Int(targets.calories)) kcal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * calorieRatio, height: 8)
                }
            }
            .frame(height: 8)

            HStack(spacing: 0) {
                PlanMacroStatCell(label: "Protein", value: "\(Int(day.totalProtein))g", target: "\(Int(targets.proteinG))g", color: .red)
                Divider().frame(height: 30)
                PlanMacroStatCell(label: "Carbs",   value: "\(Int(day.totalCarbs))g",   target: "\(Int(targets.carbsG))g",   color: .yellow)
                Divider().frame(height: 30)
                PlanMacroStatCell(label: "Fat",     value: "\(Int(day.totalFat))g",     target: "\(Int(targets.fatG))g",     color: .blue)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PlanMacroStatCell: View {
    let label: String
    let value: String
    let target: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text("of \(target)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Needs AI card

private struct PlanNeedsAICard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundStyle(.orange)
            Text("Generating your plan…")
                .font(.headline)
            Text("Pull down to refresh. This usually takes just a moment.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Meal card

private struct PlanMealCard: View {
    @Binding var meal: MealPlanMeal
    let isExpanded: Bool
    let onToggle: () -> Void
    let onAddFood: () -> Void
    let onDeleteItem: (MealPlanItem) -> Void

    private var primaryItems: [MealPlanItem] { meal.items.filter { !$0.isAlternative } }
    private var altItems:     [MealPlanItem] { meal.items.filter {  $0.isAlternative } }

    private var iconColor: Color {
        switch meal.mealType {
        case .breakfast: return .orange
        case .lunch:     return .yellow
        case .dinner:    return .indigo
        case .snack:     return .green
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row — always visible
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: meal.mealType.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(iconColor, in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.mealType.label)
                            .font(.subheadline.weight(.semibold))
                        if primaryItems.isEmpty {
                            Text("Tap to add foods")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(primaryItems.prefix(2).map { $0.name }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if !primaryItems.isEmpty {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Int(meal.primaryCalories))")
                                .font(.subheadline.weight(.bold))
                            Text("kcal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 14)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Expanded items
            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(spacing: 0) {
                    ForEach(primaryItems) { item in
                        PlanItemRow(item: item, isAlt: false) { onDeleteItem(item) }
                    }

                    if !altItems.isEmpty {
                        HStack {
                            Text("Alternatives")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                        ForEach(altItems) { item in
                            PlanItemRow(item: item, isAlt: true) { onDeleteItem(item) }
                        }
                    }

                    Button(action: onAddFood) {
                        Label("Add Food", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .clipped()
    }
}

// MARK: - Item row

private struct PlanItemRow: View {
    let item: MealPlanItem
    let isAlt: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if item.isFamiliar {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .padding(.top, 3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(isAlt ? .secondary : .primary)
                Text("\(Int(item.quantityGrams))g · P\(Int(item.proteinG)) C\(Int(item.carbsG)) F\(Int(item.fatG))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(Int(item.calories)) kcal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isAlt ? .tertiary : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    WeeklyPlanView()
}
