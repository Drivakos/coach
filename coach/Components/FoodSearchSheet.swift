//
//  FoodSearchSheet.swift
//  coach
//

import SwiftUI

struct FoodSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SearchViewModel()
    @State private var selectedProduct: FoodProduct?
    let logDate: Date
    let onLog: (FoodLog) -> Void

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
                } else {
                    List(viewModel.results) { product in
                        Button {
                            selectedProduct = product
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.product_name ?? "Unknown")
                                    .foregroundStyle(.primary)
                                if let brand = product.brands, !brand.isEmpty {
                                    Text(brand)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(Int(product.nutriments?.calories ?? 0)) kcal per 100g")
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
                Task { await viewModel.performSearch() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedProduct) { product in
                ServingPickerView(product: product, logDate: logDate, onLog: onLog)
            }
        }
    }
}
