//
//  EditServingSheet.swift
//  coach
//

import SwiftUI

struct EditServingSheet: View {
    @Bindable var log: FoodLog
    @Environment(\.dismiss) private var dismiss
    @State private var gramsText: String = ""

    private var newGrams: Double { Double(gramsText) ?? 0 }

    private var ratio: Double {
        guard log.quantityGrams > 0, newGrams > 0 else { return 1 }
        return newGrams / log.quantityGrams
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                }

                Section("Updated nutrition") {
                    NutritionPreview(
                        calories: log.calories * ratio,
                        protein: log.protein * ratio,
                        carbs: log.carbs * ratio,
                        fat: log.fat * ratio
                    )
                }
            }
            .navigationTitle(log.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard newGrams > 0 else { dismiss(); return }
                        log.calories *= ratio
                        log.protein *= ratio
                        log.carbs *= ratio
                        log.fat *= ratio
                        log.quantityGrams = newGrams
                        dismiss()
                    }
                    .disabled(newGrams <= 0)
                }
            }
            .onAppear {
                gramsText = String(Int(log.quantityGrams))
            }
        }
    }
}
