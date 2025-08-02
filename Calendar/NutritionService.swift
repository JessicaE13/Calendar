//
//  NutritionService.swift
//  Calendar
//
//  Simple USDA API integration - no conflicts
//

import Foundation

// MARK: - USDA API Models
struct USDASearchResponse: Codable {
    let foods: [USDAFood]
    let totalHits: Int
}

struct USDAFood: Codable, Identifiable {
    let fdcId: Int
    let description: String
    let brandOwner: String?
    let ingredients: String?
    let foodNutrients: [USDANutrient]?
    
    var id: Int { fdcId }
    
    var displayName: String {
        if let brandOwner = brandOwner {
            return "\(description) (\(brandOwner))"
        }
        return description
    }
}

struct USDANutrient: Codable {
    let nutrientId: Int
    let nutrientName: String
    let value: Double
    let unitName: String
}

struct USDADetailResponse: Codable {
    let fdcId: Int
    let description: String
    let foodNutrients: [USDANutrient]
}

// MARK: - Nutrition Service
@MainActor
class NutritionService: ObservableObject {
    static let shared = NutritionService()
    
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Nutrient ID mappings from USDA database
    private let nutrientIDs: [String: Int] = [
        "calories": 1008,      // Energy (kcal)
        "protein": 1003,       // Protein
        "carbs": 1005,         // Carbohydrate, by difference
        "fat": 1004,           // Total lipid (fat)
        "fiber": 1079,         // Fiber, total dietary
        "sugar": 2000,         // Total sugars
        "sodium": 1093,        // Sodium, Na
        "vitaminC": 1162,      // Vitamin C, total ascorbic acid
        "calcium": 1087,       // Calcium, Ca
        "iron": 1089           // Iron, Fe
    ]
    
    // MARK: - Search Foods
    
    func searchFoods(query: String) async throws -> [USDAFood] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/foods/search?query=\(encodedQuery)&pageSize=10&dataType=Foundation,SR%20Legacy,Branded"
        
        guard let url = URL(string: urlString) else {
            throw NutritionError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NutritionError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NutritionError.apiError(httpResponse.statusCode)
            }
            
            let searchResponse = try JSONDecoder().decode(USDASearchResponse.self, from: data)
            return searchResponse.foods
            
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw NutritionError.decodingError
        } catch {
            print("Network error: \(error)")
            throw NutritionError.networkError
        }
    }
    
    // MARK: - Get Nutrition Data
    
    func getNutritionData(for fdcId: Int) async throws -> NutritionData {
        isLoading = true
        defer { isLoading = false }
        
        let urlString = "\(baseURL)/food/\(fdcId)"
        
        guard let url = URL(string: urlString) else {
            throw NutritionError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NutritionError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw NutritionError.apiError(httpResponse.statusCode)
            }
            
            let detailResponse = try JSONDecoder().decode(USDADetailResponse.self, from: data)
            return parseNutritionData(from: detailResponse.foodNutrients)
            
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw NutritionError.decodingError
        } catch {
            print("Network error: \(error)")
            throw NutritionError.networkError
        }
    }
    
    // MARK: - Parse Amount to Grams (Public)
    
    func parseAmountToGrams(_ amountString: String, for ingredient: String) -> Double {
        let amount = amountString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract number
        let components = amount.components(separatedBy: .whitespaces)
        guard let firstComponent = components.first,
              let number = Double(firstComponent.filter { $0.isNumber || $0 == "." }) else {
            return 100.0 // Default to 100g if can't parse
        }
        
        // Common conversions to grams (approximate)
        if amount.contains("cup") || amount.contains("c") {
            return number * 240 // 1 cup ≈ 240ml ≈ 240g for liquids
        } else if amount.contains("tbsp") || amount.contains("tablespoon") {
            return number * 15 // 1 tbsp ≈ 15g
        } else if amount.contains("tsp") || amount.contains("teaspoon") {
            return number * 5 // 1 tsp ≈ 5g
        } else if amount.contains("oz") {
            return number * 28.35 // 1 oz = 28.35g
        } else if amount.contains("lb") || amount.contains("pound") {
            return number * 453.592 // 1 lb = 453.592g
        } else if amount.contains("kg") {
            return number * 1000 // 1 kg = 1000g
        } else if amount.contains("g") {
            return number // Already in grams
        } else if amount.contains("ml") || amount.contains("l") {
            return number // Approximate ml as grams for liquids
        } else {
            // No unit specified, assume it's a reasonable portion
            return number * 100 // Multiply by 100g as default portion
        }
    }
    
    // MARK: - Parse Nutrition Data
    
    private func parseNutritionData(from nutrients: [USDANutrient]) -> NutritionData {
        var nutritionData = NutritionData()
        
        for nutrient in nutrients {
            switch nutrient.nutrientId {
            case nutrientIDs["calories"]:
                nutritionData.calories = nutrient.value
            case nutrientIDs["protein"]:
                nutritionData.protein = nutrient.value
            case nutrientIDs["carbs"]:
                nutritionData.carbs = nutrient.value
            case nutrientIDs["fat"]:
                nutritionData.fat = nutrient.value
            case nutrientIDs["fiber"]:
                nutritionData.fiber = nutrient.value
            case nutrientIDs["sugar"]:
                nutritionData.sugar = nutrient.value
            case nutrientIDs["sodium"]:
                nutritionData.sodium = nutrient.value
            case nutrientIDs["vitaminC"]:
                nutritionData.vitaminC = nutrient.value
            case nutrientIDs["calcium"]:
                nutritionData.calcium = nutrient.value
            case nutrientIDs["iron"]:
                nutritionData.iron = nutrient.value
            default:
                break
            }
        }
        
        return nutritionData
    }
}

// MARK: - Nutrition Errors
enum NutritionError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    case decodingError
    case apiError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for nutrition data"
        case .invalidResponse:
            return "Invalid response from nutrition service"
        case .networkError:
            return "Network error while fetching nutrition data"
        case .decodingError:
            return "Failed to decode nutrition data"
        case .apiError(let code):
            return "API error with code: \(code)"
        }
    }
}
