//
//  ManualFoodEntrySheet.swift
//  coach
//

import SwiftUI

struct ManualFoodEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    let logDate: Date
    let mealType: MealType
    let onLog: (FoodLogInsert) -> Void

    // Required
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var gramsText: String = "100"
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""

    // Optional extended macros
    @State private var showExtended: Bool = false
    @State private var fiberText: String = ""
    @State private var sugarsText: String = ""
    @State private var saturatedFatText: String = ""
    @State private var sodiumText: String = ""

    private var grams: Double { Double(gramsText) ?? 0 }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        grams > 0 &&
        (Double(caloriesText) ?? 0) >= 0 &&
        (Double(proteinText) ?? -1) >= 0 &&
        (Double(carbsText) ?? -1) >= 0 &&
        (Double(fatText) ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name (required)", text: $name)
                    TextField("Brand (optional)", text: $brand)
                }

                Section {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("100", text: $gramsText)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            #endif
                            .frame(width: 80)
                        Text("g").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Enter macros for the quantity above.")
                }

                Section("Macros for \(gramsText.isEmpty ? "?" : gramsText)g") {
                    macroField("Calories", text: $caloriesText, unit: "kcal", required: true)
                    macroField("Protein",  text: $proteinText,  unit: "g",    required: true)
                    macroField("Carbs",    text: $carbsText,    unit: "g",    required: true)
                    macroField("Fat",      text: $fatText,      unit: "g",    required: true)
                }

                Section {
                    Button(showExtended ? "Hide details" : "Add fiber, sugars, sodium…") {
                        withAnimation { showExtended.toggle() }
                    }
                    .tint(.accentColor)

                    if showExtended {
                        macroField("Fiber",         text: $fiberText,        unit: "g")
                        macroField("Sugars",        text: $sugarsText,       unit: "g")
                        macroField("Saturated fat", text: $saturatedFatText, unit: "g")
                        macroField("Sodium",        text: $sodiumText,       unit: "mg")
                    }
                }

                Section {
                    Button("Log Food") { submit() }
                        .frame(maxWidth: .infinity)
                        .disabled(!isValid)
                }
            }
            .navigationTitle("Add Manually")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func macroField(_ label: String, text: Binding<String>, unit: String, required: Bool = false) -> some View {
        HStack {
            Text(label + (required ? "" : ""))
                .foregroundStyle(required ? .primary : .secondary)
            Spacer()
            TextField("0", text: text)
                #if os(iOS)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                #endif
                .frame(width: 80)
            Text(unit).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
        }
    }

    private func submit() {
        let g = grams
        guard g > 0 else { return }

        // Values entered are for the given quantity — store as-is in the log
        let calories = Double(caloriesText) ?? 0
        let protein  = Double(proteinText)  ?? 0
        let carbs    = Double(carbsText)    ?? 0
        let fat      = Double(fatText)      ?? 0

        let entry = FoodLogInsert(
            name:           name.trimmingCharacters(in: .whitespaces),
            brand:          brand.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            calories:       calories,
            protein:        protein,
            carbs:          carbs,
            fat:            fat,
            fiberG:         Double(fiberText),
            sugarsG:        Double(sugarsText),
            addedSugarsG:   nil,
            saturatedFatG:  Double(saturatedFatText),
            monounsatFatG:  nil,
            polyunsatFatG:  nil,
            transFatG:      nil,
            sodiumMg:       Double(sodiumText),
            cholesterolMg:  nil,
            servingSize:    "\(Int(g))g",
            quantityGrams:  g,
            mealType:       mealType,
            loggedAt:       logDate,
            foodDbId:       nil
        )

        // Build a per-100g FoodItem and save to catalog so it appears in future searches
        let factor = 100.0 / g
        let foodItem = FoodItem(
            name:     name.trimmingCharacters(in: .whitespaces),
            brand:    brand.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            category: nil,
            serving:  FoodItem.ServingInfo(sizeG: g, description: "\(Int(g))g"),
            nutritionPer100g: FoodItem.Nutrition(
                calories:      calories  * factor,
                proteinG:      protein   * factor,
                carbs: .init(
                    totalG:        carbs        * factor,
                    fiberG:        Double(fiberText).map        { $0 * factor },
                    sugarsG:       Double(sugarsText).map       { $0 * factor },
                    addedSugarsG:  nil
                ),
                fat: .init(
                    totalG:        fat            * factor,
                    saturatedG:    Double(saturatedFatText).map { $0 * factor },
                    monounsaturatedG: nil,
                    polyunsaturatedG: nil,
                    transG:        nil
                ),
                sodiumMg:      Double(sodiumText).map { $0 * factor },
                cholesterolMg: nil
            )
        )
        Task { await FoodCatalogService().save(foodItem, source: "user") }

        onLog(entry)
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}
