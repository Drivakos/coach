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
    // Extended macros — nil for entries logged before the migration
    var fiberG: Double?
    var sugarsG: Double?
    var addedSugarsG: Double?
    var saturatedFatG: Double?
    var monounsatFatG: Double?
    var polyunsatFatG: Double?
    var transFatG: Double?
    var sodiumMg: Double?
    var cholesterolMg: Double?
    var servingSize: String?
    var quantityGrams: Double
    var mealType: MealType
    var loggedAt: Date
    var createdAt: Date
    var foodDbId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, brand
        case calories
        case protein = "protein_g"
        case carbs = "carbs_g"
        case fat = "fat_g"
        case fiberG = "fiber_g"
        case sugarsG = "sugars_g"
        case addedSugarsG = "added_sugars_g"
        case saturatedFatG = "saturated_fat_g"
        case monounsatFatG = "monounsat_fat_g"
        case polyunsatFatG = "polyunsat_fat_g"
        case transFatG = "trans_fat_g"
        case sodiumMg = "sodium_mg"
        case cholesterolMg = "cholesterol_mg"
        case servingSize = "serving_size"
        case quantityGrams = "quantity_grams"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case createdAt = "created_at"
        case foodDbId = "food_db_id"
    }
}

struct FoodLogInsert: Encodable {
    var name: String
    var brand: String?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiberG: Double?
    var sugarsG: Double?
    var addedSugarsG: Double?
    var saturatedFatG: Double?
    var monounsatFatG: Double?
    var polyunsatFatG: Double?
    var transFatG: Double?
    var sodiumMg: Double?
    var cholesterolMg: Double?
    var servingSize: String?
    var quantityGrams: Double
    var mealType: MealType
    var loggedAt: Date
    var foodDbId: String?

    enum CodingKeys: String, CodingKey {
        case name, brand
        case calories
        case protein = "protein_g"
        case carbs = "carbs_g"
        case fat = "fat_g"
        case fiberG = "fiber_g"
        case sugarsG = "sugars_g"
        case addedSugarsG = "added_sugars_g"
        case saturatedFatG = "saturated_fat_g"
        case monounsatFatG = "monounsat_fat_g"
        case polyunsatFatG = "polyunsat_fat_g"
        case transFatG = "trans_fat_g"
        case sodiumMg = "sodium_mg"
        case cholesterolMg = "cholesterol_mg"
        case servingSize = "serving_size"
        case quantityGrams = "quantity_grams"
        case mealType = "meal_type"
        case loggedAt = "logged_at"
        case foodDbId = "food_db_id"
    }
}

// MARK: - Food catalog item (from our MongoDB / food-api)

struct FoodItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String?
    let category: String?
    let barcodes: [String]
    let serving: ServingInfo?
    let nutritionPer100g: Nutrition

    struct ServingInfo: Decodable, Hashable {
        let sizeG: Double
        let description: String?

        enum CodingKeys: String, CodingKey {
            case sizeG        = "size_g"
            case description
        }
    }

    struct Nutrition: Decodable, Hashable {
        let calories: Double
        let proteinG: Double
        let carbs: Carbs
        let fat: Fat
        let sodiumMg: Double?
        let cholesterolMg: Double?

        struct Carbs: Decodable, Hashable {
            let totalG: Double
            let fiberG: Double?
            let sugarsG: Double?
            let addedSugarsG: Double?

            enum CodingKeys: String, CodingKey {
                case totalG       = "total_g"
                case fiberG       = "fiber_g"
                case sugarsG      = "sugars_g"
                case addedSugarsG = "added_sugars_g"
            }

            init(totalG: Double, fiberG: Double? = nil, sugarsG: Double? = nil, addedSugarsG: Double? = nil) {
                self.totalG       = totalG
                self.fiberG       = fiberG
                self.sugarsG      = sugarsG
                self.addedSugarsG = addedSugarsG
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                totalG       = (try? c.decodeIfPresent(Double.self, forKey: .totalG)) ?? 0
                fiberG       = try? c.decodeIfPresent(Double.self, forKey: .fiberG)
                sugarsG      = try? c.decodeIfPresent(Double.self, forKey: .sugarsG)
                addedSugarsG = try? c.decodeIfPresent(Double.self, forKey: .addedSugarsG)
            }
        }

        struct Fat: Decodable, Hashable {
            let totalG: Double
            let saturatedG: Double?
            let monounsaturatedG: Double?
            let polyunsaturatedG: Double?
            let transG: Double?

            enum CodingKeys: String, CodingKey {
                case totalG           = "total_g"
                case saturatedG       = "saturated_g"
                case monounsaturatedG = "monounsaturated_g"
                case polyunsaturatedG = "polyunsaturated_g"
                case transG           = "trans_g"
            }

            init(totalG: Double, saturatedG: Double? = nil, monounsaturatedG: Double? = nil, polyunsaturatedG: Double? = nil, transG: Double? = nil) {
                self.totalG           = totalG
                self.saturatedG       = saturatedG
                self.monounsaturatedG = monounsaturatedG
                self.polyunsaturatedG = polyunsaturatedG
                self.transG           = transG
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                totalG           = (try? c.decodeIfPresent(Double.self, forKey: .totalG)) ?? 0
                saturatedG       = try? c.decodeIfPresent(Double.self, forKey: .saturatedG)
                monounsaturatedG = try? c.decodeIfPresent(Double.self, forKey: .monounsaturatedG)
                polyunsaturatedG = try? c.decodeIfPresent(Double.self, forKey: .polyunsaturatedG)
                transG           = try? c.decodeIfPresent(Double.self, forKey: .transG)
            }
        }

        enum CodingKeys: String, CodingKey {
            case calories
            case proteinG     = "protein_g"
            case carbs, fat
            case sodiumMg     = "sodium_mg"
            case cholesterolMg = "cholesterol_mg"
        }

        init(calories: Double, proteinG: Double, carbs: Carbs, fat: Fat, sodiumMg: Double? = nil, cholesterolMg: Double? = nil) {
            self.calories      = calories
            self.proteinG      = proteinG
            self.carbs         = carbs
            self.fat           = fat
            self.sodiumMg      = sodiumMg
            self.cholesterolMg = cholesterolMg
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            calories      = (try? c.decodeIfPresent(Double.self, forKey: .calories)) ?? 0
            proteinG      = (try? c.decodeIfPresent(Double.self, forKey: .proteinG)) ?? 0
            carbs         = (try? c.decode(Carbs.self, forKey: .carbs)) ?? Carbs(totalG: 0)
            fat           = (try? c.decode(Fat.self, forKey: .fat)) ?? Fat(totalG: 0)
            sodiumMg      = try? c.decodeIfPresent(Double.self, forKey: .sodiumMg)
            cholesterolMg = try? c.decodeIfPresent(Double.self, forKey: .cholesterolMg)
        }
    }

    enum CodingKeys: String, CodingKey {
        case id               = "_id"
        case name, brand, category, barcodes, serving
        case nutritionPer100g = "nutrition_per_100g"
    }

    /// Memberwise init — used when constructing from catalog rows or manual entry.
    init(id: String = UUID().uuidString,
         name: String,
         brand: String?,
         category: String?,
         barcodes: [String] = [],
         serving: ServingInfo?,
         nutritionPer100g: Nutrition) {
        self.id               = id
        self.name             = name
        self.brand            = brand
        self.category         = category
        self.barcodes         = barcodes
        self.serving          = serving
        self.nutritionPer100g = nutritionPer100g
    }

    /// Decodable init — used when decoding Perplexity JSON responses.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        name             = try c.decode(String.self, forKey: .name)
        brand            = try c.decodeIfPresent(String.self, forKey: .brand)
        category         = try c.decodeIfPresent(String.self, forKey: .category)
        barcodes         = (try? c.decodeIfPresent([String].self, forKey: .barcodes)) ?? []
        serving          = try c.decodeIfPresent(ServingInfo.self, forKey: .serving)
        nutritionPer100g = try c.decode(Nutrition.self, forKey: .nutritionPer100g)
    }
}

// MARK: - Food search service (local catalog → Perplexity)

enum FoodSearchError: LocalizedError {
    case apiKeyMissing
    case httpError(statusCode: Int, body: String)
    case emptyResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:    return "Food search is not configured."
        case .httpError(let code, _): return "Search service unavailable (HTTP \(code))."
        case .emptyResponse:    return "No results returned from search."
        case .decodingFailed:   return "Could not read search results."
        }
    }
}

// Hoisted so they aren't redefined on every call to callPerplexity
private struct PerplexityResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

private struct ItemsWrapper: Decodable { let items: [FoodItem] }

struct FoodSearchService {

    private static let perplexityKey: String = {
        Bundle.main.infoDictionary?["PERPLEXITY_API_KEY"] as? String ?? ""
    }()
    private static let perplexityURL = URL(string: "https://api.perplexity.ai/chat/completions")!
    private static let decoder = JSONDecoder()

    func search(query: String) async throws -> [FoodItem] {
        // 1. Local catalog — fast and free
        #if DEBUG
        print("[FoodSearch] Querying local catalog for '\(query)'")
        #endif
        let cached = try await FoodCatalogService().search(query: query)
        #if DEBUG
        print("[FoodSearch] Local catalog returned \(cached.count) results for '\(query)'")
        #endif
        if !cached.isEmpty { return cached }

        try Task.checkCancellation()

        // 2. Perplexity
        guard !Self.perplexityKey.isEmpty else {
            throw FoodSearchError.apiKeyMissing
        }
        return try await callPerplexity(query: query)
    }

    // MARK: - Private

    private func callPerplexity(query: String) async throws -> [FoodItem] {
        let systemPrompt = """
        You are a nutrition database API. Respond with a JSON object only — no prose, no markdown fences.
        Use this exact structure:
        {
          "items": [
            {
              "name": "string",
              "brand": "string or null",
              "category": "dairy|meat|grain|vegetable|fruit|snack|beverage|legume|other or null",
              "barcodes": [],
              "serving": { "size_g": number, "description": "string or null" },
              "nutrition_per_100g": {
                "calories": number,
                "protein_g": number,
                "carbs": { "total_g": number, "fiber_g": number or null, "sugars_g": number or null, "added_sugars_g": number or null },
                "fat": { "total_g": number, "saturated_g": number or null, "monounsaturated_g": number or null, "polyunsaturated_g": number or null, "trans_g": number or null },
                "sodium_mg": number or null,
                "cholesterol_mg": number or null
              }
            }
          ]
        }
        All values are per 100g. calories, protein_g, carbs.total_g, and fat.total_g MUST be real numbers — never null. Only return items you have actual nutrition data for.
        """
        let userPrompt = "Return up to 5 food items matching \"\(query)\". Prefer common, well-known foods with verified nutrition data."

        let body: [String: Any] = [
            "model": "sonar",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ],
            "temperature": 0.1
        ]

        var request = URLRequest(url: Self.perplexityURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Self.perplexityKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0

        guard statusCode == 200 else {
            #if DEBUG
            let responseBody = String(data: data, encoding: .utf8) ?? "<non-UTF8>"
            print("[Perplexity] HTTP \(statusCode): \(responseBody)")
            #endif
            throw FoodSearchError.httpError(statusCode: statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        let apiResponse = try Self.decoder.decode(PerplexityResponse.self, from: data)

        guard let content = apiResponse.choices.first?.message.content else {
            throw FoodSearchError.emptyResponse
        }

        #if DEBUG
        print("[Perplexity] Content: \(content)")
        #endif

        // Extract the JSON object — handles markdown fences and any surrounding prose
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}"),
              let jsonData = String(content[start...end]).data(using: .utf8)
        else {
            throw FoodSearchError.decodingFailed
        }

        do {
            let wrapper = try Self.decoder.decode(ItemsWrapper.self, from: jsonData)
            let valid = wrapper.items.filter { $0.nutritionPer100g.calories > 0 }
            #if DEBUG
            print("[Perplexity] Decoded \(wrapper.items.count) items, \(valid.count) with calorie data.")
            #endif
            return valid
        } catch {
            #if DEBUG
            print("[Perplexity] Decode error: \(error)")
            #endif
            throw FoodSearchError.decodingFailed
        }
    }
}

// MARK: - Search view model

@Observable
class SearchViewModel {
    var query: String = ""
    var results: [FoodItem] = []
    var isLoading: Bool = false
    var hasSearched: Bool = false
    var errorMessage: String?

    private let service = FoodSearchService()
    private var searchTask: Task<Void, Never>?

    func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil
            do {
                results = try await service.search(query: query)
            } catch {
                if !(error is CancellationError) {
                    #if DEBUG
                    print("[SearchViewModel] Search failed: \(error)")
                    #endif
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
            hasSearched = true
        }
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
