//
//  MealModel.swift
//  Calendar
//
//  Complete meal planning system with recipes, ingredients, and nutrition tracking
//

import Foundation
import CloudKit
import SwiftUI

// MARK: - Nutrition Data
struct NutritionData: Codable, Equatable {
    var calories: Double = 0
    var protein: Double = 0      // grams
    var carbs: Double = 0        // grams
    var fat: Double = 0          // grams
    var fiber: Double = 0        // grams
    var sugar: Double = 0        // grams
    var sodium: Double = 0       // milligrams
    var vitaminC: Double = 0     // milligrams
    var calcium: Double = 0      // milligrams
    var iron: Double = 0         // milligrams
    
    // Per 100g serving
    static let empty = NutritionData()
    
    // Scale nutrition data by amount
    func scaled(by factor: Double) -> NutritionData {
        return NutritionData(
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor,
            fiber: fiber * factor,
            sugar: sugar * factor,
            sodium: sodium * factor,
            vitaminC: vitaminC * factor,
            calcium: calcium * factor,
            iron: iron * factor
        )
    }
    
    // Add nutrition data together
    static func + (lhs: NutritionData, rhs: NutritionData) -> NutritionData {
        return NutritionData(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat,
            fiber: lhs.fiber + rhs.fiber,
            sugar: lhs.sugar + rhs.sugar,
            sodium: lhs.sodium + rhs.sodium,
            vitaminC: lhs.vitaminC + rhs.vitaminC,
            calcium: lhs.calcium + rhs.calcium,
            iron: lhs.iron + rhs.iron
        )
    }
}

// MARK: - Meal Type
enum MealType: String, CaseIterable, Codable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "cup.and.saucer.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "fork.knife.circle.fill"
        case .snack: return "carrot.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .green
        case .dinner: return .blue
        case .snack: return .purple
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        case .snack: return 3
        }
    }
}

// MARK: - Ingredient Model with Nutrition Support
struct Ingredient: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var amount: String // e.g., "2 cups", "1 tbsp", "500g"
    var category: String = "" // e.g., "Vegetables", "Proteins", "Grains"
    var isOptional: Bool = false
    var nutritionData: NutritionData = NutritionData.empty
    var fdcId: Int? = nil // USDA Food Data Central ID
    
    init(name: String, amount: String, category: String = "", isOptional: Bool = false) {
        self.name = name
        self.amount = amount
        self.category = category
        self.isOptional = isOptional
    }
    
    /// Calculate nutrition data for this ingredient's specific amount
    func calculatedNutrition() -> NutritionData {
        guard nutritionData != NutritionData.empty else { return NutritionData.empty }
        
        let gramsAmount = parseAmountToGrams(amount, for: name)
        let scaleFactor = gramsAmount / 100.0 // Nutrition data is per 100g
        
        return nutritionData.scaled(by: scaleFactor)
    }
    
    /// Parse amount string like "2 cups", "1 tbsp", "500g" and convert to grams
    private func parseAmountToGrams(_ amountString: String, for ingredient: String) -> Double {
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
    
    static func == (lhs: Ingredient, rhs: Ingredient) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.amount == rhs.amount &&
               lhs.category == rhs.category &&
               lhs.isOptional == rhs.isOptional &&
               lhs.nutritionData == rhs.nutritionData &&
               lhs.fdcId == rhs.fdcId
    }
}

// MARK: - Recipe Model
struct Recipe: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var description: String = ""
    var ingredients: [Ingredient] = []
    var instructions: [String] = []
    var prepTime: Int = 0 // minutes
    var cookTime: Int = 0 // minutes
    var servings: Int = 1
    var tags: [String] = [] // e.g., "vegetarian", "quick", "healthy"
    var categoryID: UUID? = nil
    var isFavorite: Bool = false
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    var totalTime: Int {
        return prepTime + cookTime
    }
    
    /// Calculate total nutrition for the entire recipe based on ingredient nutrition data
    var totalNutrition: NutritionData {
        return ingredients.reduce(NutritionData.empty) { total, ingredient in
            return total + ingredient.calculatedNutrition()
        }
    }
    
    /// Calculate nutrition per serving
    var nutritionPerServing: NutritionData {
        guard servings > 0 else { return totalNutrition }
        return totalNutrition.scaled(by: 1.0 / Double(servings))
    }
    
    init(name: String, description: String = "", prepTime: Int = 0, cookTime: Int = 0, servings: Int = 1) {
        self.name = name
        self.description = description
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.lastModified = Date()
    }
    
    @MainActor
    func getCategory(from categoryManager: CategoryManager) -> Category? {
        guard let categoryID = categoryID else { return nil }
        return categoryManager.categories.first { $0.id == categoryID }
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, name, description, ingredients, instructions, prepTime, cookTime, servings, tags, categoryID, isFavorite, lastModified
        // recordID is not encoded/decoded
    }
    
    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.description == rhs.description &&
               lhs.ingredients == rhs.ingredients &&
               lhs.instructions == rhs.instructions &&
               lhs.prepTime == rhs.prepTime &&
               lhs.cookTime == rhs.cookTime &&
               lhs.servings == rhs.servings &&
               lhs.tags == rhs.tags &&
               lhs.categoryID == rhs.categoryID &&
               lhs.isFavorite == rhs.isFavorite
    }
}

// MARK: - Planned Meal Model
struct PlannedMeal: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var mealType: MealType
    var recipeID: UUID?
    var customMealName: String? // For simple meals without full recipes
    var notes: String = ""
    var isCompleted: Bool = false // Did they actually eat this meal?
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    var displayName: String {
        if let customMealName = customMealName, !customMealName.isEmpty {
            return customMealName
        }
        return "Planned \(mealType.displayName)"
    }
    
    init(date: Date, mealType: MealType, recipeID: UUID? = nil, customMealName: String? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.mealType = mealType
        self.recipeID = recipeID
        self.customMealName = customMealName
        self.lastModified = Date()
    }
    
    @MainActor
    func getRecipe(from mealManager: MealManager) -> Recipe? {
        guard let recipeID = recipeID else { return nil }
        return mealManager.recipes.first { $0.id == recipeID }
    }
    
    @MainActor
    func getNutritionData(from mealManager: MealManager) -> NutritionData {
        guard let recipe = getRecipe(from: mealManager) else {
            return NutritionData.empty
        }
        return recipe.nutritionPerServing
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, date, mealType, recipeID, customMealName, notes, isCompleted, lastModified
        // recordID is not encoded/decoded
    }
    
    static func == (lhs: PlannedMeal, rhs: PlannedMeal) -> Bool {
        return lhs.id == rhs.id &&
               lhs.date == rhs.date &&
               lhs.mealType == rhs.mealType &&
               lhs.recipeID == rhs.recipeID &&
               lhs.customMealName == rhs.customMealName &&
               lhs.notes == rhs.notes &&
               lhs.isCompleted == rhs.isCompleted
    }
}

// MARK: - Shopping List Item
struct ShoppingListItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var amount: String = ""
    var category: String = ""
    var isCompleted: Bool = false
    var fromRecipeID: UUID? = nil // Track which recipe this came from
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    init(name: String, amount: String = "", category: String = "", fromRecipeID: UUID? = nil) {
        self.name = name
        self.amount = amount
        self.category = category
        self.fromRecipeID = fromRecipeID
        self.lastModified = Date()
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, name, amount, category, isCompleted, fromRecipeID, lastModified
        // recordID is not encoded/decoded
    }
    
    static func == (lhs: ShoppingListItem, rhs: ShoppingListItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.amount == rhs.amount &&
               lhs.category == rhs.category &&
               lhs.isCompleted == rhs.isCompleted &&
               lhs.fromRecipeID == rhs.fromRecipeID
    }
}

// MARK: - CloudKit Extensions
extension Recipe {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Recipe", recordID: recordID ?? CKRecord.ID())
        record["name"] = name
        record["recipeDescription"] = description
        record["prepTime"] = prepTime
        record["cookTime"] = cookTime
        record["servings"] = servings
        record["isFavorite"] = isFavorite ? 1 : 0
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        record["categoryID"] = categoryID?.uuidString
        
        // Encode complex fields as JSON
        do {
            let ingredientsData = try JSONEncoder().encode(ingredients)
            record["ingredients"] = ingredientsData
            
            let instructionsData = try JSONEncoder().encode(instructions)
            record["instructions"] = instructionsData
            
            let tagsData = try JSONEncoder().encode(tags)
            record["tags"] = tagsData
        } catch {
            print("Failed to encode recipe data: \(error)")
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> Recipe? {
        guard let name = record["name"] as? String else {
            return nil
        }
        
        var categoryID: UUID? = nil
        if let categoryIDString = record["categoryID"] as? String {
            categoryID = UUID(uuidString: categoryIDString)
        }
        
        var recipe = Recipe(
            name: name,
            description: record["recipeDescription"] as? String ?? "",
            prepTime: record["prepTime"] as? Int ?? 0,
            cookTime: record["cookTime"] as? Int ?? 0,
            servings: record["servings"] as? Int ?? 1
        )
        
        recipe.recordID = record.recordID
        recipe.categoryID = categoryID
        recipe.isFavorite = (record["isFavorite"] as? Int ?? 0) == 1
        recipe.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            recipe.id = userID
        }
        
        // Decode complex fields from JSON
        if let ingredientsData = record["ingredients"] as? Data {
            do {
                recipe.ingredients = try JSONDecoder().decode([Ingredient].self, from: ingredientsData)
            } catch {
                print("Failed to decode ingredients: \(error)")
            }
        }
        
        if let instructionsData = record["instructions"] as? Data {
            do {
                recipe.instructions = try JSONDecoder().decode([String].self, from: instructionsData)
            } catch {
                print("Failed to decode instructions: \(error)")
            }
        }
        
        if let tagsData = record["tags"] as? Data {
            do {
                recipe.tags = try JSONDecoder().decode([String].self, from: tagsData)
            } catch {
                print("Failed to decode tags: \(error)")
            }
        }
        
        return recipe
    }
}

extension PlannedMeal {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "PlannedMeal", recordID: recordID ?? CKRecord.ID())
        record["date"] = date
        record["mealType"] = mealType.rawValue
        record["recipeID"] = recipeID?.uuidString
        record["customMealName"] = customMealName
        record["notes"] = notes
        record["isCompleted"] = isCompleted ? 1 : 0
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> PlannedMeal? {
        guard let date = record["date"] as? Date,
              let mealTypeRaw = record["mealType"] as? String,
              let mealType = MealType(rawValue: mealTypeRaw) else {
            return nil
        }
        
        var recipeID: UUID? = nil
        if let recipeIDString = record["recipeID"] as? String {
            recipeID = UUID(uuidString: recipeIDString)
        }
        
        var plannedMeal = PlannedMeal(
            date: date,
            mealType: mealType,
            recipeID: recipeID,
            customMealName: record["customMealName"] as? String
        )
        
        plannedMeal.recordID = record.recordID
        plannedMeal.notes = record["notes"] as? String ?? ""
        plannedMeal.isCompleted = (record["isCompleted"] as? Int ?? 0) == 1
        plannedMeal.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            plannedMeal.id = userID
        }
        
        return plannedMeal
    }
}

extension ShoppingListItem {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "ShoppingListItem", recordID: recordID ?? CKRecord.ID())
        record["name"] = name
        record["amount"] = amount
        record["category"] = category
        record["isCompleted"] = isCompleted ? 1 : 0
        record["fromRecipeID"] = fromRecipeID?.uuidString
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> ShoppingListItem? {
        guard let name = record["name"] as? String else {
            return nil
        }
        
        var fromRecipeID: UUID? = nil
        if let recipeIDString = record["fromRecipeID"] as? String {
            fromRecipeID = UUID(uuidString: recipeIDString)
        }
        
        var shoppingItem = ShoppingListItem(
            name: name,
            amount: record["amount"] as? String ?? "",
            category: record["category"] as? String ?? "",
            fromRecipeID: fromRecipeID
        )
        
        shoppingItem.recordID = record.recordID
        shoppingItem.isCompleted = (record["isCompleted"] as? Int ?? 0) == 1
        shoppingItem.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            shoppingItem.id = userID
        }
        
        return shoppingItem
    }
}

// MARK: - Meal Manager
@MainActor
class MealManager: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var plannedMeals: [PlannedMeal] = []
    @Published var shoppingList: [ShoppingListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    static let shared = MealManager()
    
    private var cloudKitManager: CloudKitManager {
        CloudKitManager.shared
    }
    
    init() {
        loadSampleData()
    }
    
    private func loadSampleData() {
        guard recipes.isEmpty else { return }
        
        // Sample recipes with enhanced nutrition-ready ingredients
        let categoryManager = CategoryManager.shared
        let foodCategory = categoryManager.categories.first { $0.name == "Food" } ??
                          categoryManager.categories.first { $0.name == "Personal" }
        
        var pancakeRecipe = Recipe(
            name: "Fluffy Pancakes",
            description: "Light and fluffy breakfast pancakes",
            prepTime: 10,
            cookTime: 15,
            servings: 4
        )
        pancakeRecipe.categoryID = foodCategory?.id
        pancakeRecipe.ingredients = [
            Ingredient(name: "All-purpose flour", amount: "2 cups", category: "Baking"),
            Ingredient(name: "Sugar", amount: "2 tbsp", category: "Baking"),
            Ingredient(name: "Baking powder", amount: "2 tsp", category: "Baking"),
            Ingredient(name: "Salt", amount: "1/2 tsp", category: "Baking"),
            Ingredient(name: "Milk", amount: "1 3/4 cups", category: "Dairy"),
            Ingredient(name: "Eggs", amount: "2 large", category: "Dairy"),
            Ingredient(name: "Butter", amount: "1/4 cup melted", category: "Dairy"),
            Ingredient(name: "Vanilla extract", amount: "1 tsp", category: "Baking")
        ]
        pancakeRecipe.instructions = [
            "Mix dry ingredients in a large bowl",
            "Whisk wet ingredients in another bowl",
            "Combine wet and dry ingredients until just mixed",
            "Heat griddle or pan over medium heat",
            "Pour 1/4 cup batter for each pancake",
            "Cook until bubbles form, then flip",
            "Cook until golden brown on both sides"
        ]
        pancakeRecipe.tags = ["breakfast", "family-friendly", "vegetarian"]
        
        var saladRecipe = Recipe(
            name: "Mediterranean Salad",
            description: "Fresh and healthy Mediterranean-style salad",
            prepTime: 15,
            cookTime: 0,
            servings: 2
        )
        saladRecipe.categoryID = foodCategory?.id
        saladRecipe.ingredients = [
            Ingredient(name: "Mixed greens", amount: "4 cups", category: "Vegetables"),
            Ingredient(name: "Cherry tomatoes", amount: "1 cup halved", category: "Vegetables"),
            Ingredient(name: "Cucumber", amount: "1 medium diced", category: "Vegetables"),
            Ingredient(name: "Red onion", amount: "1/4 cup sliced", category: "Vegetables"),
            Ingredient(name: "Feta cheese", amount: "1/2 cup crumbled", category: "Dairy"),
            Ingredient(name: "Kalamata olives", amount: "1/4 cup", category: "Vegetables"),
            Ingredient(name: "Olive oil", amount: "3 tbsp", category: "Pantry"),
            Ingredient(name: "Lemon juice", amount: "2 tbsp", category: "Pantry"),
            Ingredient(name: "Dried oregano", amount: "1 tsp", category: "Spices")
        ]
        saladRecipe.instructions = [
            "Wash and prepare all vegetables",
            "Combine greens, tomatoes, cucumber, and onion in a large bowl",
            "Add feta cheese and olives",
            "Whisk together olive oil, lemon juice, and oregano",
            "Drizzle dressing over salad and toss gently",
            "Serve immediately"
        ]
        saladRecipe.tags = ["healthy", "vegetarian", "quick", "lunch"]
        
        recipes = [pancakeRecipe, saladRecipe]
        
        // Sample planned meals for today
        let today = Date()
        plannedMeals = [
            PlannedMeal(date: today, mealType: .breakfast, recipeID: pancakeRecipe.id),
            PlannedMeal(date: today, mealType: .lunch, recipeID: saladRecipe.id),
            PlannedMeal(date: today, mealType: .dinner, customMealName: "Grilled Chicken & Vegetables")
        ]
    }
    
    // MARK: - Recipe Management
    
    func addRecipe(_ recipe: Recipe) {
        var newRecipe = recipe
        newRecipe.lastModified = Date()
        
        recipes.append(newRecipe)
        
        // Sync to CloudKit
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let savedRecipe = try await self.cloudKitManager.saveRecipe(newRecipe)
                await MainActor.run {
                    if let index = self.recipes.firstIndex(where: { $0.id == newRecipe.id }) {
                        self.recipes[index] = savedRecipe
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to sync recipe: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    func updateRecipe(_ recipe: Recipe) {
        if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
            recipes[index].lastModified = Date()
            
            let updatedRecipe = recipes[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveRecipe(updatedRecipe)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync recipe: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) {
        // Remove recipe and any planned meals that use it
        recipes.removeAll { $0.id == recipe.id }
        
        // Update planned meals that used this recipe
        for index in plannedMeals.indices {
            if plannedMeals[index].recipeID == recipe.id {
                plannedMeals[index].recipeID = nil
                plannedMeals[index].customMealName = recipe.name
                plannedMeals[index].lastModified = Date()
            }
        }
        
        // Delete from CloudKit
        if let recordID = recipe.recordID {
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    try await self.cloudKitManager.deleteRecipe(recordID: recordID)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to delete recipe from iCloud: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    // MARK: - Meal Planning
    
    func addPlannedMeal(_ plannedMeal: PlannedMeal) {
        var newMeal = plannedMeal
        newMeal.lastModified = Date()
        
        plannedMeals.append(newMeal)
        
        // Sync to CloudKit
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let savedMeal = try await self.cloudKitManager.savePlannedMeal(newMeal)
                await MainActor.run {
                    if let index = self.plannedMeals.firstIndex(where: { $0.id == newMeal.id }) {
                        self.plannedMeals[index] = savedMeal
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to sync planned meal: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    func updatePlannedMeal(_ plannedMeal: PlannedMeal) {
        if let index = plannedMeals.firstIndex(where: { $0.id == plannedMeal.id }) {
            plannedMeals[index] = plannedMeal
            plannedMeals[index].lastModified = Date()
            
            let updatedMeal = plannedMeals[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.savePlannedMeal(updatedMeal)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync planned meal: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func deletePlannedMeal(_ plannedMeal: PlannedMeal) {
        plannedMeals.removeAll { $0.id == plannedMeal.id }
        
        // Delete from CloudKit
        if let recordID = plannedMeal.recordID {
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    try await self.cloudKitManager.deletePlannedMeal(recordID: recordID)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to delete planned meal from iCloud: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func toggleMealCompletion(_ plannedMeal: PlannedMeal) {
        if let index = plannedMeals.firstIndex(where: { $0.id == plannedMeal.id }) {
            plannedMeals[index].isCompleted.toggle()
            plannedMeals[index].lastModified = Date()
            
            let updatedMeal = plannedMeals[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.savePlannedMeal(updatedMeal)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync meal completion: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    // MARK: - Shopping List Management
    
    func addShoppingListItem(_ item: ShoppingListItem) {
        var newItem = item
        newItem.lastModified = Date()
        
        shoppingList.append(newItem)
        
        // Sync to CloudKit
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let savedItem = try await self.cloudKitManager.saveShoppingListItem(newItem)
                await MainActor.run {
                    if let index = self.shoppingList.firstIndex(where: { $0.id == newItem.id }) {
                        self.shoppingList[index] = savedItem
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to sync shopping item: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    func toggleShoppingItemCompletion(_ item: ShoppingListItem) {
        if let index = shoppingList.firstIndex(where: { $0.id == item.id }) {
            shoppingList[index].isCompleted.toggle()
            shoppingList[index].lastModified = Date()
            
            let updatedItem = shoppingList[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveShoppingListItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync shopping item: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func deleteShoppingListItem(_ item: ShoppingListItem) {
        shoppingList.removeAll { $0.id == item.id }
        
        // Delete from CloudKit
        if let recordID = item.recordID {
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    try await self.cloudKitManager.deleteShoppingListItem(recordID: recordID)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to delete shopping item from iCloud: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func generateShoppingListFromPlannedMeals(for dates: [Date]) {
        var ingredientsToAdd: [String: ShoppingListItem] = [:]
        
        for date in dates {
            let mealsForDate = plannedMeals.filter { meal in
                Calendar.current.isDate(meal.date, equalTo: date, toGranularity: .day)
            }
            
            for meal in mealsForDate {
                if let recipe = meal.getRecipe(from: self) {
                    for ingredient in recipe.ingredients {
                        let key = ingredient.name.lowercased()
                        
                        if let existingItem = ingredientsToAdd[key] {
                            // Combine amounts if they're the same unit
                            existingItem.amount += ", \(ingredient.amount)"
                        } else {
                            let shoppingItem = ShoppingListItem(
                                name: ingredient.name,
                                amount: ingredient.amount,
                                category: ingredient.category,
                                fromRecipeID: recipe.id
                            )
                            ingredientsToAdd[key] = shoppingItem
                        }
                    }
                }
            }
        }
        
        // Add new items to shopping list
        for (_, item) in ingredientsToAdd {
            // Check if we already have this item
            if !shoppingList.contains(where: { $0.name.lowercased() == item.name.lowercased() && !$0.isCompleted }) {
                addShoppingListItem(item)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func mealsForDate(_ date: Date) -> [PlannedMeal] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        return plannedMeals.filter { meal in
            calendar.isDate(meal.date, equalTo: targetDate, toGranularity: .day)
        }.sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }
    
    func mealForDate(_ date: Date, type: MealType) -> PlannedMeal? {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        return plannedMeals.first { meal in
            calendar.isDate(meal.date, equalTo: targetDate, toGranularity: .day) && meal.mealType == type
        }
    }
    
    func favoriteRecipes() -> [Recipe] {
        return recipes.filter { $0.isFavorite }.sorted { $0.name < $1.name }
    }
    
    func recipesInCategory(_ category: Category) -> [Recipe] {
        return recipes.filter { $0.categoryID == category.id }.sorted { $0.name < $1.name }
    }
    
    func searchRecipes(query: String) -> [Recipe] {
        guard !query.isEmpty else { return recipes }
        
        let lowercaseQuery = query.lowercased()
        return recipes.filter { recipe in
            recipe.name.lowercased().contains(lowercaseQuery) ||
            recipe.description.lowercased().contains(lowercaseQuery) ||
            recipe.tags.contains { $0.lowercased().contains(lowercaseQuery) } ||
            recipe.ingredients.contains { $0.name.lowercased().contains(lowercaseQuery) }
        }
    }
    
    // MARK: - CloudKit Sync
    
    func forceSyncWithCloudKit() {
        syncFromCloudKit()
    }
    
    private func syncFromCloudKit() {
        Task { [weak self] in
            guard let self = self else { return }
            guard self.cloudKitManager.isAccountAvailable else { return }
            
            do {
                async let cloudRecipes = self.cloudKitManager.fetchAllRecipes()
                async let cloudPlannedMeals = self.cloudKitManager.fetchAllPlannedMeals()
                async let cloudShoppingItems = self.cloudKitManager.fetchAllShoppingListItems()
                
                let (recipes, plannedMeals, shoppingItems) = try await (cloudRecipes, cloudPlannedMeals, cloudShoppingItems)
                
                await MainActor.run {
                    self.mergeRecipes(recipes)
                    self.mergePlannedMeals(plannedMeals)
                    self.mergeShoppingList(shoppingItems)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func mergeRecipes(_ cloudRecipes: [Recipe]) {
        var mergedRecipes: [Recipe] = []
        var localRecipesDict = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
        
        for cloudRecipe in cloudRecipes {
            if let localRecipe = localRecipesDict[cloudRecipe.id] {
                mergedRecipes.append(cloudRecipe.lastModified > localRecipe.lastModified ? cloudRecipe : localRecipe)
                localRecipesDict.removeValue(forKey: cloudRecipe.id)
            } else {
                mergedRecipes.append(cloudRecipe)
            }
        }
        
        for (_, localRecipe) in localRecipesDict {
            mergedRecipes.append(localRecipe)
        }
        
        self.recipes = mergedRecipes.sorted { $0.name < $1.name }
    }
    
    private func mergePlannedMeals(_ cloudPlannedMeals: [PlannedMeal]) {
        var mergedMeals: [PlannedMeal] = []
        var localMealsDict = Dictionary(uniqueKeysWithValues: plannedMeals.map { ($0.id, $0) })
        
        for cloudMeal in cloudPlannedMeals {
            if let localMeal = localMealsDict[cloudMeal.id] {
                mergedMeals.append(cloudMeal.lastModified > localMeal.lastModified ? cloudMeal : localMeal)
                localMealsDict.removeValue(forKey: cloudMeal.id)
            } else {
                mergedMeals.append(cloudMeal)
            }
        }
        
        for (_, localMeal) in localMealsDict {
            mergedMeals.append(localMeal)
        }
        
        self.plannedMeals = mergedMeals
    }
    
    private func mergeShoppingList(_ cloudShoppingItems: [ShoppingListItem]) {
        var mergedItems: [ShoppingListItem] = []
        var localItemsDict = Dictionary(uniqueKeysWithValues: shoppingList.map { ($0.id, $0) })
        
        for cloudItem in cloudShoppingItems {
            if let localItem = localItemsDict[cloudItem.id] {
                mergedItems.append(cloudItem.lastModified > localItem.lastModified ? cloudItem : localItem)
                localItemsDict.removeValue(forKey: cloudItem.id)
            } else {
                mergedItems.append(cloudItem)
            }
        }
        
        for (_, localItem) in localItemsDict {
            mergedItems.append(localItem)
        }
        
        self.shoppingList = mergedItems
    }
}
