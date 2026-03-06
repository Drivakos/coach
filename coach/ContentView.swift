//
//  ContentView.swift
//  coach
//
//  Created by Vagelis Drivakos on 2/3/26.
//

import SwiftUI
import Supabase

struct ContentView: View {
    @State private var allLogs: [FoodLog] = []
    @State private var showSearch = false
    @State private var logToEdit: FoodLog?
    @State private var selectedDate = Date()
    @State private var isLoading = false

    private var selectedDayLogs: [FoodLog] {
        let start = Calendar.current.startOfDay(for: selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return allLogs.filter { $0.loggedAt >= start && $0.loggedAt < end }
    }

    private var totalCalories: Double {
        selectedDayLogs.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("\(Int(totalCalories)) kcal")) {
                    ForEach(selectedDayLogs) { log in
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
            .navigationTitle("Today")
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
        }
    }

    // MARK: - Data operations

    private func fetchLogs() async {
        isLoading = true
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let logs: [FoodLog] = try await supabase
                .from("food_logs")
                .select()
                .order("logged_at", ascending: false)
                .execute()
                .value
            allLogs = logs
        } catch {
            print("fetchLogs error:", error)
        }
        isLoading = false
    }

    private func addLog(_ insert: FoodLogInsert) async {
        do {
            let log: FoodLog = try await supabase
                .from("food_logs")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value
            allLogs.append(log)
        } catch {
            print("addLog error:", error)
        }
    }

    private func updateLog(_ log: FoodLog) async {
        do {
            let updated: FoodLog = try await supabase
                .from("food_logs")
                .update(log)
                .eq("id", value: log.id)
                .select()
                .single()
                .execute()
                .value
            if let idx = allLogs.firstIndex(where: { $0.id == log.id }) {
                allLogs[idx] = updated
            }
        } catch {
            print("updateLog error:", error)
        }
    }

    private func deleteLog(_ log: FoodLog) async {
        do {
            try await supabase
                .from("food_logs")
                .delete()
                .eq("id", value: log.id)
                .execute()
            allLogs.removeAll { $0.id == log.id }
        } catch {
            print("deleteLog error:", error)
        }
    }
}

#Preview {
    ContentView()
}
