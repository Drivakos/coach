import SwiftUI

struct WeeklyPlanView: View {
    @Environment(AppState.self) private var appState
    @State private var plan: WeeklyPlan?        = nil
    @State private var days: [MealPlanDay]      = []
    @State private var isLoading                = true
    @State private var isRegenerating           = false
    @State private var errorMessage: String?    = nil
    @State private var addingToMeal: MealPlanMeal? = nil

    private let service = WeeklyPlanService()

    private var weekLabel: String {
        guard let monday = CheckInService.dateFormatter.date(from: CheckInService.mondayString())
        else { return "" }
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday)!
        return "\(CheckInService.shortDateFormatter.string(from: monday)) – \(CheckInService.shortDateFormatter.string(from: sunday))"
    }

    // ISO weekday for today: 1 = Monday, 7 = Sunday
    private var isoToday: Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return w == 1 ? 7 : w - 1
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
                } else if let plan {
                    planList(plan)
                } else {
                    emptyState
                }
            }
            .navigationTitle("This Week's Plan")
            .task        { await load() }
            .refreshable { await regenerate() }
            .toolbar {
                if isRegenerating {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .sheet(item: $addingToMeal) { meal in
                FoodSearchSheet(logDate: Date()) { logInsert in
                    addingToMeal = nil
                    Task { await addFood(logInsert, toMeal: meal) }
                }
            }
        }
    }

    // MARK: - Plan list

    private func planList(_ plan: WeeklyPlan) -> some View {
        List {
            adjustmentSection(plan)
            targetsSection(plan)

            if plan.needsAIPlan || days.isEmpty {
                needsAISection
            } else {
                mealPlanHeader
                mealPlanDays
            }
        }
    }

    // MARK: - Adjustment banner

    @ViewBuilder
    private func adjustmentSection(_ plan: WeeklyPlan) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(weekLabel).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    if plan.adjustmentKcal != 0 {
                        Text(plan.adjustmentKcal > 0
                             ? "+\(Int(plan.adjustmentKcal)) kcal"
                             : "\(Int(plan.adjustmentKcal)) kcal")
                            .font(.subheadline.bold())
                            .foregroundStyle(plan.adjustmentKcal > 0 ? .green : .orange)
                    } else {
                        Text("No change").font(.subheadline.bold()).foregroundStyle(.secondary)
                    }
                }
                if let reason = plan.adjustmentReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
        } header: {
            Label("Weekly Adjustment", systemImage: "wand.and.stars")
        }
    }

    // MARK: - Adjusted targets

    @ViewBuilder
    private func targetsSection(_ plan: WeeklyPlan) -> some View {
        Section("Adjusted Targets") {
            LabeledContent("Calories") { Text("\(Int(plan.calories)) kcal").fontWeight(.medium) }
            LabeledContent("Protein")  { Text("\(Int(plan.proteinG))g").fontWeight(.medium) }
            LabeledContent("Carbs")    { Text("\(Int(plan.carbsG))g").fontWeight(.medium) }
            LabeledContent("Fat")      { Text("\(Int(plan.fatG))g").fontWeight(.medium) }
        }
    }

    // MARK: - Meal plan header

    @ViewBuilder
    private var mealPlanHeader: some View {
        Section {
            Label("Based on your recent food history", systemImage: "fork.knife.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } header: {
            Label("7-Day Meal Plan", systemImage: "calendar")
        }
    }

    // MARK: - Meal plan days

    @ViewBuilder
    private var mealPlanDays: some View {
        ForEach($days) { $day in
            Section {
                ForEach($day.meals) { $meal in
                    mealRow(meal: $meal, day: $day)
                }
            } header: {
                HStack {
                    Text(dayLabel(day.dayOfWeek))
                    Spacer()
                    Text("\(Int(day.totalCalories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Meal row (expandable, with add + delete)

    @ViewBuilder
    private func mealRow(meal: Binding<MealPlanMeal>, day: Binding<MealPlanDay>) -> some View {
        let m = meal.wrappedValue
        DisclosureGroup {
            ForEach(m.items) { item in
                itemRow(item: item, meal: meal, day: day)
            }
            // Add food button
            Button {
                addingToMeal = m
            } label: {
                Label("Add Food", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        } label: {
            HStack {
                Label(m.mealType.label, systemImage: m.mealType.icon)
                    .font(.subheadline)
                Spacer()
                if !m.items.isEmpty {
                    Text("\(Int(m.totalCalories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Item row (swipe to delete)

    @ViewBuilder
    private func itemRow(item: MealPlanItem, meal: Binding<MealPlanMeal>, day: Binding<MealPlanDay>) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline)
                Text("\(Int(item.quantityGrams))g · P \(Int(item.proteinG))g · C \(Int(item.carbsG))g · F \(Int(item.fatG))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(item.calories)) kcal")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await deleteItem(item, from: meal, inDay: day) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Needs AI placeholder

    @ViewBuilder
    private var needsAISection: some View {
        Section("Meal Plan") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Not enough data yet", systemImage: "clock.badge.questionmark")
                    .font(.subheadline.bold())
                Text("Log your food for at least 7 days to get a personalised meal plan built from your eating habits. AI-generated plans are coming soon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
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
            Button("Generate Now") { Task { await regenerate() } }
                .buttonStyle(.borderedProminent)
                .disabled(isRegenerating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func deleteItem(
        _ item: MealPlanItem,
        from meal: Binding<MealPlanMeal>,
        inDay day: Binding<MealPlanDay>
    ) async {
        do {
            try await service.deleteItem(item.id)
            // Update local state immediately
            meal.wrappedValue.items.removeAll { $0.id == item.id }
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
                sortOrder:      meal.items.count
            ))
            // Append to the correct meal in local state
            if let di = days.firstIndex(where: { $0.meals.contains { $0.id == meal.id } }),
               let mi = days[di].meals.firstIndex(where: { $0.id == meal.id }) {
                days[di].meals[mi].items.append(newItem)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Data loading

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

    private func regenerate() async {
        guard let target = appState.nutritionTarget else { return }
        isRegenerating = true
        errorMessage   = nil
        do {
            let generated = try await service.generateForWeek(
                CheckInService.mondayString(),
                goal: appState.goal,
                currentTarget: target
            )
            plan = generated
            days = try await service.fetchDays(forPlan: generated.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRegenerating = false
    }

    // MARK: - Helpers

    private func dayLabel(_ dayOfWeek: Int) -> String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let name  = names[max(0, min(dayOfWeek - 1, 6))]
        return dayOfWeek == isoToday ? "\(name) — Today" : name
    }
}

#Preview {
    WeeklyPlanView()
}
