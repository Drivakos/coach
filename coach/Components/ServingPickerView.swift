//
//  ServingPickerView.swift
//  coach
//

import SwiftUI

struct ServingPickerView: View {
    let product: FoodProduct
    let logDate: Date
    let onLog: (FoodLogInsert) -> Void

    @State private var mode: Int = 0
    @State private var gramsText: String = "100"
    @State private var servingCount: Double = 1.0

    private var hasServingQuantity: Bool {
        (product.serving_quantity ?? 0) > 0
    }

    private var effectiveGrams: Double {
        if mode == 0 || !hasServingQuantity {
            return Double(gramsText) ?? 0
        } else {
            return (product.serving_quantity ?? 0) * servingCount
        }
    }

    private func scale(_ value: Double?) -> Double {
        ((value ?? 0) * effectiveGrams) / 100
    }

    private var scaledCalories: Double { scale(product.nutriments?.calories) }
    private var scaledProtein: Double  { scale(product.nutriments?.protein) }
    private var scaledCarbs: Double    { scale(product.nutriments?.carbohydrates) }
    private var scaledFat: Double      { scale(product.nutriments?.fat) }

    var body: some View {
        Form {
            if hasServingQuantity {
                Section {
                    Picker("Mode", selection: $mode) {
                        Text("Grams").tag(0)
                        Text("Servings").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                if mode == 0 || !hasServingQuantity {
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
                    let servingLabel = product.serving_size.map { " (\($0))" } ?? ""
                    Stepper(value: $servingCount, in: 0.5...20, step: 0.5) {
                        Text("Servings: \(servingCount, specifier: "%.1f")\(servingLabel)")
                    }
                    Text("\(Int(effectiveGrams))g total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Nutrition preview") {
                NutritionPreview(
                    calories: scaledCalories,
                    protein: scaledProtein,
                    carbs: scaledCarbs,
                    fat: scaledFat
                )
            }

            Section {
                Button("Log") {
                    let entry = FoodLogInsert(
                        name: product.product_name ?? "Unknown",
                        brand: product.brands?.isEmpty == false ? product.brands : nil,
                        calories: scaledCalories,
                        protein: scaledProtein,
                        carbs: scaledCarbs,
                        fat: scaledFat,
                        servingSize: product.serving_size,
                        quantityGrams: effectiveGrams,
                        loggedAt: logDate
                    )
                    onLog(entry)
                }
                .frame(maxWidth: .infinity)
                .disabled(effectiveGrams <= 0)
            }
        }
        .navigationTitle(product.product_name ?? "Unknown")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
