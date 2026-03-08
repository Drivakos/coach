//
//  ContentView.swift
//  coach
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var logs: [FoodLog] = []
    @State private var selectedDate = Date()
    @State private var addingMeal: MealType?
    @State private var logToEdit: FoodLog?
    @State private var mealToClear: MealType?
    @State private var errorMessage: String?

    private let service = FoodLogService()

    private var navigationTitle: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : CheckInService.shortDateFormatter.string(from: selectedDate)
    }

    private var logsByMeal: [MealType: [FoodLog]] { Dictionary(grouping: logs, by: \.mealType) }
    private var totals: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        logs.reduce((0, 0, 0, 0)) { acc, log in
            (acc.0 + log.calories, acc.1 + log.protein, acc.2 + log.carbs, acc.3 + log.fat)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Calorie summary
                Section {
                    calorieSummaryCard
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // Meal sections
                ForEach(MealType.allCases) { meal in
                    let items = logsByMeal[meal] ?? []
                    let kcal = items.reduce(0) { $0 + $1.calories }

                    Section {
                        // Header row — swipe left to clear whole meal
                        HStack {
                            Image(systemName: meal.icon)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                            Text(meal.label)
                                .font(.headline)
                            Spacer()
                            if !items.isEmpty {
                                Text("\(Int(kcal)) kcal")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                addingMeal = meal
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !items.isEmpty {
                                Button(role: .destructive) {
                                    mealToClear = meal
                                } label: {
                                    Label("Clear", systemImage: "trash")
                                }
                            }
                        }

                        // Food item rows
                        ForEach(items) { log in
                            Button {
                                logToEdit = log
                            } label: {
                                FoodLogRow(log: log)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await deleteLog(log) }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    WeekStrip(selectedDate: $selectedDate)
                    Divider()
                }
                .background(.bar)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $addingMeal) { meal in
                FoodSearchSheet(logDate: selectedDate, mealType: meal) { insert in
                    Task { await addLog(insert) }
                }
            }
            .sheet(item: $logToEdit) { log in
                EditServingSheet(log: log) { updated in
                    Task { await updateLog(updated) }
                }
            }
            .task(id: selectedDate) { await fetchLogs() }
            .alert("Clear \(mealToClear?.label ?? "")?", isPresented: .init(
                get: { mealToClear != nil },
                set: { if !$0 { mealToClear = nil } }
            )) {
                Button("Clear All", role: .destructive) {
                    if let meal = mealToClear {
                        mealToClear = nil
                        Task { await clearMeal(meal) }
                    }
                }
                Button("Cancel", role: .cancel) { mealToClear = nil }
            } message: {
                let day = Calendar.current.isDateInToday(selectedDate) ? "today" : "this day"
                Text("This will permanently delete all \(mealToClear?.label ?? "") entries for \(day).")
            }
            .alert("Something went wrong", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Calorie Summary Card

    private var calorieSummaryCard: some View {
        let t = totals
        let target = appState.nutritionTarget?.calories ?? 0
        let remaining = max(0, target - t.calories)
        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(t.calories))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("kcal eaten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if target > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(remaining))")
                            .font(.title2.bold())
                        Text("remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if target > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemFill))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(t.calories >= target ? Color.red : Color.accentColor)
                            .frame(width: min(geo.size.width, geo.size.width * t.calories / target), height: 8)
                    }
                }
                .frame(height: 8)
            }

            HStack {
                macroChip("P", value: t.protein, color: .blue)
                macroChip("C", value: t.carbs, color: .orange)
                macroChip("F", value: t.fat, color: .yellow)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func macroChip(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(Int(value))g")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data operations

    private func fetchLogs() async {
        do {
            logs = try await service.fetch(for: selectedDate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addLog(_ insert: FoodLogInsert) async {
        do {
            let log = try await service.insert(insert)
            logs.append(log)
            NotificationCenter.default.post(name: .foodLogChanged, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateLog(_ log: FoodLog) async {
        do {
            let updated = try await service.update(log)
            if let idx = logs.firstIndex(where: { $0.id == log.id }) {
                logs[idx] = updated
            }
            NotificationCenter.default.post(name: .foodLogChanged, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteLog(_ log: FoodLog) async {
        do {
            try await service.delete(log)
            logs.removeAll { $0.id == log.id }
            NotificationCenter.default.post(name: .foodLogChanged, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearMeal(_ meal: MealType) async {
        do {
            try await service.deleteMeal(meal, on: selectedDate)
            logs.removeAll { $0.mealType == meal }
            NotificationCenter.default.post(name: .foodLogChanged, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
