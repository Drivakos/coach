import Foundation
import Supabase

// MARK: - Supabase row → FoodItem

private struct FoodCatalogRow: Decodable {
    let id: UUID
    let name: String
    let brand: String?
    let category: String?
    let barcodes: [String]
    let servingSizeG: Double?
    let servingDescription: String?
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fiberG: Double?
    let sugarsG: Double?
    let addedSugarsG: Double?
    let fatG: Double
    let saturatedFatG: Double?
    let monounsatFatG: Double?
    let polyunsatFatG: Double?
    let transFatG: Double?
    let sodiumMg: Double?
    let cholesterolMg: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, brand, category, barcodes
        case servingSizeG       = "serving_size_g"
        case servingDescription = "serving_description"
        case calories
        case proteinG           = "protein_g"
        case carbsG             = "carbs_g"
        case fiberG             = "fiber_g"
        case sugarsG            = "sugars_g"
        case addedSugarsG       = "added_sugars_g"
        case fatG               = "fat_g"
        case saturatedFatG      = "saturated_fat_g"
        case monounsatFatG      = "monounsat_fat_g"
        case polyunsatFatG      = "polyunsat_fat_g"
        case transFatG          = "trans_fat_g"
        case sodiumMg           = "sodium_mg"
        case cholesterolMg      = "cholesterol_mg"
    }

    func toFoodItem() -> FoodItem {
        FoodItem(
            id: id.uuidString,
            name: name,
            brand: brand,
            category: category,
            barcodes: barcodes,
            serving: servingSizeG.map {
                FoodItem.ServingInfo(sizeG: $0, description: servingDescription)
            },
            nutritionPer100g: FoodItem.Nutrition(
                calories: calories,
                proteinG: proteinG,
                carbs: .init(totalG: carbsG, fiberG: fiberG, sugarsG: sugarsG, addedSugarsG: addedSugarsG),
                fat: .init(totalG: fatG, saturatedG: saturatedFatG, monounsaturatedG: monounsatFatG, polyunsaturatedG: polyunsatFatG, transG: transFatG),
                sodiumMg: sodiumMg,
                cholesterolMg: cholesterolMg
            )
        )
    }
}

// MARK: - FoodItem → Supabase insert

struct FoodCatalogInsert: Encodable {
    let name: String
    let brand: String?
    let category: String?
    let barcodes: [String]
    let servingSizeG: Double?
    let servingDescription: String?
    let calories: Double
    let proteinG: Double
    let carbsG: Double
    let fiberG: Double?
    let sugarsG: Double?
    let addedSugarsG: Double?
    let fatG: Double
    let saturatedFatG: Double?
    let monounsatFatG: Double?
    let polyunsatFatG: Double?
    let transFatG: Double?
    let sodiumMg: Double?
    let cholesterolMg: Double?
    let source: String

    enum CodingKeys: String, CodingKey {
        case name, brand, category, barcodes
        case servingSizeG       = "serving_size_g"
        case servingDescription = "serving_description"
        case calories
        case proteinG           = "protein_g"
        case carbsG             = "carbs_g"
        case fiberG             = "fiber_g"
        case sugarsG            = "sugars_g"
        case addedSugarsG       = "added_sugars_g"
        case fatG               = "fat_g"
        case saturatedFatG      = "saturated_fat_g"
        case monounsatFatG      = "monounsat_fat_g"
        case polyunsatFatG      = "polyunsat_fat_g"
        case transFatG          = "trans_fat_g"
        case sodiumMg           = "sodium_mg"
        case cholesterolMg      = "cholesterol_mg"
        case source
    }

    init(from item: FoodItem, source: String = "perplexity") {
        let n = item.nutritionPer100g
        self.name            = item.name
        self.brand           = item.brand
        self.category        = item.category
        self.barcodes        = item.barcodes
        self.servingSizeG    = item.serving?.sizeG
        self.servingDescription = item.serving?.description
        self.calories        = n.calories
        self.proteinG        = n.proteinG
        self.carbsG          = n.carbs.totalG
        self.fiberG          = n.carbs.fiberG
        self.sugarsG         = n.carbs.sugarsG
        self.addedSugarsG    = n.carbs.addedSugarsG
        self.fatG            = n.fat.totalG
        self.saturatedFatG   = n.fat.saturatedG
        self.monounsatFatG   = n.fat.monounsaturatedG
        self.polyunsatFatG   = n.fat.polyunsaturatedG
        self.transFatG       = n.fat.transG
        self.sodiumMg        = n.sodiumMg
        self.cholesterolMg   = n.cholesterolMg
        self.source          = source
    }
}

// MARK: - Service

struct FoodCatalogService {

    /// Search the local catalog before hitting Perplexity.
    func search(query: String) async throws -> [FoodItem] {
        let rows: [FoodCatalogRow] = try await supabase
            .from("foods")
            .select()
            .or("name.ilike.%\(query)%,brand.ilike.%\(query)%")
            .limit(10)
            .execute()
            .value
        return rows.map { $0.toFoodItem() }
    }

    /// Persist a food item to the catalog. Silently ignores duplicates.
    func save(_ item: FoodItem, source: String = "perplexity") async {
        let insert = FoodCatalogInsert(from: item, source: source)
        _ = try? await supabase
            .from("foods")
            .insert(insert)
            .execute()
    }
}
