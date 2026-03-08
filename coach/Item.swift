//
//  Item.swift
//  coach
//
//  Created by Vagelis Drivakos on 2/3/26.
//

import Foundation

// MARK: - Supabase Model

struct FoodLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingSize: String?
    var quantityGrams: Double
    var mealType: MealType
    var loggedAt: Date
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case brand
        case calories
        case protein = "protein_g"
        case carbs = "carbs_g"
        case fat = "fat_g"
        case servingSize = "serving_size"
        case quantityGrams = "quantity_grams"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case createdAt = "created_at"
    }

}

// MARK: - Insert payload (no id/userId/createdAt — server generates them)

struct FoodLogInsert: Encodable {
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var servingSize: String?
    var quantityGrams: Double
    var mealType: MealType
    var loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case calories
        case protein = "protein_g"
        case carbs = "carbs_g"
        case fat = "fat_g"
        case servingSize = "serving_size"
        case quantityGrams = "quantity_grams"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
    }
}

// MARK: - OpenFoodFacts Decodables

struct FoodSearchResponse: Decodable {
    let products: [FoodProduct]
}

struct FoodProduct: Decodable, Identifiable, Hashable {
    let code: String?
    let product_name: String?
    let brands: String?
    let serving_size: String?
    let serving_quantity: Double?
    let nutriments: Nutriments?

    /// Stable identity: barcode when available, otherwise content-based fallback.
    var id: String {
        if let code, !code.isEmpty { return code }
        return "\(product_name ?? "")-\(brands ?? "")"
    }

    enum CodingKeys: String, CodingKey {
        case code, product_name, brands, serving_size, serving_quantity, nutriments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(String.self, forKey: .code)
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
            URLQueryItem(name: "fields", value: "code,product_name,brands,serving_size,serving_quantity,nutriments")
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

// MARK: - Shared Supabase insert payloads

struct NutritionTargetInsert: Encodable {
    let user_id: UUID
    let calories: Double
    let protein_g: Double
    let carbs_g: Double
    let fat_g: Double
}

struct BodyMetricInsert: Encodable {
    let user_id: UUID
    let weight_kg: Double
    let body_fat_pct: Double?
}

struct FoodPreferenceInsert: Encodable {
    let user_id: UUID
    let preference: String
}

struct AllergyInsert: Encodable {
    let user_id: UUID
    let allergen: String
}
