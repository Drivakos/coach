//
//  FoodSearchSheet.swift
//  coach
//

import SwiftUI

struct FoodSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SearchViewModel()
    @State private var selectedItem: FoodItem?
    @State private var showingManualEntry = false
    let logDate: Date
    let mealType: MealType
    let onLog: (FoodLogInsert) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Searching…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.hasSearched && viewModel.results.isEmpty {
                    ContentUnavailableView.search(text: viewModel.query)
                } else {
                    List(viewModel.results) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .foregroundStyle(.primary)
                                if let brand = item.brand, !brand.isEmpty {
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(Int(item.nutritionPer100g.calories)) kcal · \(Int(item.nutritionPer100g.proteinG))g P · \(Int(item.nutritionPer100g.carbs.totalG))g C · \(Int(item.nutritionPer100g.fat.totalG))g F  /100g")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Search Food")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $viewModel.query, prompt: "Search food…")
            .onSubmit(of: .search) {
                viewModel.performSearch()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add manually") { showingManualEntry = true }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualFoodEntrySheet(logDate: logDate, mealType: mealType) { insert in
                    onLog(insert)
                    dismiss()
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                ServingPickerView(item: item, logDate: logDate, mealType: mealType) { insert in
                    onLog(insert)
                    dismiss()
                }
            }
        }
    }
}
