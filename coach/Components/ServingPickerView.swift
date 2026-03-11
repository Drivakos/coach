//
//  ServingPickerView.swift
//  coach
//

import SwiftUI

private enum ServingMode: CaseIterable {
    case grams, servings
}

struct ServingPickerView: View {
    let item: FoodItem
    let logDate: Date
    let mealType: MealType
    let onLog: (FoodLogInsert) -> Void

    @State private var mode: ServingMode = .grams
    @State private var gramsText: String = "100"
    @State private var servingCount: Double = 1.0

    private var hasServing: Bool { (item.serving?.sizeG ?? 0) > 0 }

    private var effectiveGrams: Double {
        if mode == .grams || !hasServing {
            return Double(gramsText) ?? 0
        } else {
            return (item.serving?.sizeG ?? 0) * servingCount
        }
    }

    private func scale(_ value: Double?) -> Double {
        ((value ?? 0) * effectiveGrams) / 100
    }

    private var n: FoodItem.Nutrition { item.nutritionPer100g }

    var body: some View {
        Form {
            if hasServing {
                Section {
                    Picker("Mode", selection: $mode) {
                        Text("Grams").tag(ServingMode.grams)
                        Text("Servings").tag(ServingMode.servings)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                if mode == .grams || !hasServing {
                    HStack {
                        Text("Amount (g)")
                        Spacer()
                        TextField("100", text: $gramsText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            #endif
                            .frame(width: 80)
                    }
                } else {
                    let label = item.serving?.description.map { " (\($0))" } ?? ""
                    Stepper(value: $servingCount, in: 0.5...20, step: 0.5) {
                        Text("Servings: \(servingCount, specifier: "%.1f")\(label)")
                    }
                    Text("\(Int(effectiveGrams))g total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Nutrition preview") {
                NutritionPreview(
                    calories: scale(n.calories),
                    protein:  scale(n.proteinG),
                    carbs:    scale(n.carbs.totalG),
                    fat:      scale(n.fat.totalG)
                )
                // Extended breakdown (shown when data is available)
                if n.carbs.fiberG != nil || n.carbs.sugarsG != nil {
                    Divider()
                    if let fiber = n.carbs.fiberG {
                        macroRow("Fiber", value: scale(fiber), unit: "g")
                    }
                    if let sugars = n.carbs.sugarsG {
                        macroRow("Sugars", value: scale(sugars), unit: "g")
                    }
                }
                if n.fat.saturatedG != nil {
                    Divider()
                    if let sat = n.fat.saturatedG {
                        macroRow("Saturated fat", value: scale(sat), unit: "g")
                    }
                    if let mono = n.fat.monounsaturatedG {
                        macroRow("Monounsaturated", value: scale(mono), unit: "g")
                    }
                    if let poly = n.fat.polyunsaturatedG {
                        macroRow("Polyunsaturated", value: scale(poly), unit: "g")
                    }
                }
                if let sodium = n.sodiumMg {
                    Divider()
                    macroRow("Sodium", value: scale(sodium), unit: "mg")
                }
            }

            Section {
                Button("Log") { logEntry() }
                    .frame(maxWidth: .infinity)
                    .disabled(effectiveGrams <= 0)
            }
        }
        .navigationTitle(item.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func macroRow(_ label: String, value: Double, unit: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func logEntry() {
        // Persist to food catalog in the background — best-effort, doesn't block the log
        Task { await FoodCatalogService().save(item) }

        let entry = FoodLogInsert(
            name:           item.name,
            brand:          item.brand,
            calories:       scale(n.calories),
            protein:        scale(n.proteinG),
            carbs:          scale(n.carbs.totalG),
            fat:            scale(n.fat.totalG),
            fiberG:         n.carbs.fiberG.map       { scale($0) },
            sugarsG:        n.carbs.sugarsG.map      { scale($0) },
            addedSugarsG:   n.carbs.addedSugarsG.map { scale($0) },
            saturatedFatG:  n.fat.saturatedG.map     { scale($0) },
            monounsatFatG:  n.fat.monounsaturatedG.map { scale($0) },
            polyunsatFatG:  n.fat.polyunsaturatedG.map { scale($0) },
            transFatG:      n.fat.transG.map         { scale($0) },
            sodiumMg:       n.sodiumMg.map           { scale($0) },
            cholesterolMg:  n.cholesterolMg.map      { scale($0) },
            servingSize:    item.serving?.description,
            quantityGrams:  effectiveGrams,
            mealType:       mealType,
            loggedAt:       logDate,
            foodDbId:       item.id
        )
        onLog(entry)
    }
}
