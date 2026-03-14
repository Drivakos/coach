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
    @State private var logToCopy: FoodLog?
    @State private var mealTypeToCopy: MealType?
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
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if !items.isEmpty {
                                Button {
                                    mealTypeToCopy = meal
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
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
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    logToCopy = log
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
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
            .sheet(item: $logToCopy) { log in
                CopyMealSheet(title: "Copy \(log.name)", currentDate: selectedDate) { dates in
                    Task { await copyLogs([log], to: dates) }
                }
            }
            .sheet(item: $mealTypeToCopy) { meal in
                CopyMealSheet(title: "Copy \(meal.label)", currentDate: selectedDate) { dates in
                    let items = logsByMeal[meal] ?? []
                    Task { await copyLogs(items, to: dates) }
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
        let nt = appState.nutritionTarget
        let target = nt?.calories ?? 0
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
                    let proteinKcal = t.protein * 4
                    let carbsKcal   = t.carbs * 4
                    let fatKcal     = t.fat * 9
                    let totalKcal   = proteinKcal + carbsKcal + fatKcal
                    let scale       = min(totalKcal / target, 1.0)
                    let barW        = geo.size.width * scale
                    let factor      = totalKcal > 0 ? barW / totalKcal : 0
                    let pW          = factor * proteinKcal
                    let cW          = factor * carbsKcal
                    let fW          = factor * fatKcal

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemFill))
                            .frame(height: 8)
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.blue)   .frame(width: pW, height: 8)
                            Rectangle().fill(Color.orange) .frame(width: cW, height: 8)
                            Rectangle().fill(Color.yellow) .frame(width: fW, height: 8)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(height: 8)
            }

            HStack {
                macroChip("P", value: t.protein, target: nt?.proteinG, color: .blue)
                macroChip("C", value: t.carbs,   target: nt?.carbsG,   color: .orange)
                macroChip("F", value: t.fat,     target: nt?.fatG,     color: .yellow)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func macroChip(_ label: String, value: Double, target: Double?, color: Color) -> some View {
        let isOver = target.map { value > $0 } ?? false
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Group {
                if let t = target {
                    Text("\(label) \(Int(value))/\(Int(t))g")
                } else {
                    Text("\(label) \(Int(value))g")
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(isOver ? color : .secondary)
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

    private func copyLogs(_ sourceLogs: [FoodLog], to dates: [Date]) async {
        let cal = Calendar.current
        do {
            for date in dates {
                for log in sourceLogs {
                    let timeComponents = cal.dateComponents([.hour, .minute, .second], from: log.loggedAt)
                    let targetDate = cal.date(
                        bySettingHour: timeComponents.hour ?? 12,
                        minute: timeComponents.minute ?? 0,
                        second: timeComponents.second ?? 0,
                        of: date
                    ) ?? date
                    let payload = FoodLogInsert(copying: log, loggedAt: targetDate)
                    let inserted = try await service.insert(payload)
                    if cal.isDate(date, inSameDayAs: selectedDate) {
                        logs.append(inserted)
                    }
                }
            }
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
