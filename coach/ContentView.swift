//
//  ContentView.swift
//  coach
//
//  Created by Vagelis Drivakos on 2/3/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodLog.loggedAt) private var allLogs: [FoodLog]
    @State private var showSearch = false
    @State private var logToEdit: FoodLog?
    @State private var selectedDate = Date()

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
                                modelContext.delete(log)
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
                FoodSearchSheet(logDate: selectedDate) { entry in
                    modelContext.insert(entry)
                    showSearch = false
                }
            }
            .sheet(item: $logToEdit) { log in
                EditServingSheet(log: log)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FoodLog.self, inMemory: true)
}
