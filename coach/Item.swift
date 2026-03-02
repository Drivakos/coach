//
//  Item.swift
//  coach
//
//  Created by Vagelis Drivakos on 2/3/26.
//

import Foundation
import SwiftData

// MARK: - SwiftData Model

@Model
final class FoodLog {
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingSize: String?
    var quantityGrams: Double = 100
    var loggedAt: Date

    init(name: String, brand: String?, calories: Double, protein: Double,
         carbs: Double, fat: Double, servingSize: String?, quantityGrams: Double = 100, loggedAt: Date) {
        self.name = name
        self.brand = brand
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingSize = servingSize
        self.quantityGrams = quantityGrams
        self.loggedAt = loggedAt
    }
}

// MARK: - OpenFoodFacts Decodables

struct FoodSearchResponse: Decodable {
    let products: [FoodProduct]
}

struct FoodProduct: Decodable, Identifiable, Hashable {
    let id = UUID()
    let product_name: String?
    let brands: String?
    let serving_size: String?
    let serving_quantity: Double?
    let nutriments: Nutriments?

    enum CodingKeys: String, CodingKey {
        case product_name, brands, serving_size, serving_quantity, nutriments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        product_name = try c.decodeIfPresent(String.self, forKey: .product_name)
        brands = try c.decodeIfPresent(String.self, forKey: .brands)
        serving_size = try c.decodeIfPresent(String.self, forKey: .serving_size)
        nutriments = try c.decodeIfPresent(Nutriments.self, forKey: .nutriments)
        // OFF returns serving_quantity as a number OR a string depending on the product
        if let d = try? c.decodeIfPresent(Double.self, forKey: .serving_quantity) {
            serving_quantity = d
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .serving_quantity) {
            serving_quantity = Double(s)
        } else {
            serving_quantity = nil
        }
    }
}

struct Nutriments: Decodable, Hashable {
    let calories: Double?
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?

    enum CodingKeys: String, CodingKey {
        case calories = "energy-kcal_100g"
        case protein = "proteins_100g"
        case carbohydrates = "carbohydrates_100g"
        case fat = "fat_100g"
    }
}

// MARK: - Search Service

struct FoodSearchService {
    func search(query: String) async throws -> [FoodProduct] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "product_name,brands,serving_size,serving_quantity,nutriments")
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(FoodSearchResponse.self, from: data)
        return response.products
    }
}

// MARK: - View Model

@Observable
class SearchViewModel {
    var query: String = ""
    var results: [FoodProduct] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let service = FoodSearchService()

    func performSearch() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            results = try await service.search(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
