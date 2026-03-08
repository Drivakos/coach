//
//  ContentView.swift
//  coach
//
//  Created by Vagelis Drivakos on 2/3/26.
//

import SwiftUI

struct ContentView: View {
    @State private var logs: [FoodLog] = []
    @State private var showSearch = false
    @State private var logToEdit: FoodLog?
    @State private var selectedDate = Date()
    @State private var errorMessage: String?

    private let service = FoodLogService()
    private var navigationTitle: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : CheckInService.shortDateFormatter.string(from: selectedDate)
    }

    private var totalCalories: Double {
        logs.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("\(Int(totalCalories)) kcal")) {
                    ForEach(logs) { log in
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
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    WeekStrip(selectedDate: $selectedDate)
                    Divider()
                }
                .background(.bar)
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSearch = true
                    } label: {
                        Label("Add Food", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                FoodSearchSheet(logDate: selectedDate) { insert in
                    Task { await addLog(insert) }
                    showSearch = false
                }
            }
            .sheet(item: $logToEdit) { log in
                EditServingSheet(log: log) { updated in
                    Task { await updateLog(updated) }
                }
            }
            .task(id: selectedDate) {
                await fetchLogs()
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
}

#Preview {
    ContentView()
}
