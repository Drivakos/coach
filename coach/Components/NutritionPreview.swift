//
//  NutritionPreview.swift
//  coach
//

import SwiftUI

struct NutritionPreview: View {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    var body: some View {
        Group {
            LabeledContent("Calories", value: "\(Int(calories)) kcal")
            LabeledContent("Protein", value: "\(Int(protein))g")
            LabeledContent("Carbs", value: "\(Int(carbs))g")
            LabeledContent("Fat", value: "\(Int(fat))g")
        }
    }
}
