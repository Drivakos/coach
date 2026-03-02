//
//  FoodLogRow.swift
//  coach
//

import SwiftUI

struct FoodLogRow: View {
    let log: FoodLog

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(log.name)
                .font(.body)
            HStack(spacing: 12) {
                if let brand = log.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(Int(log.calories)) kcal · \(Int(log.quantityGrams))g · P \(Int(log.protein))g · C \(Int(log.carbs))g · F \(Int(log.fat))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
