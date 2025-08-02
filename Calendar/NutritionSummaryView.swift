//
//  NutritionSummaryView.swift
//  Calendar
//
//  Daily nutrition summary and meal nutrition displays
//

import SwiftUI

// MARK: - Daily Nutrition Summary
struct DailyNutritionSummary: View {
    let selectedDate: Date
    @ObservedObject var mealManager: MealManager
    
    private var totalNutrition: NutritionData {
        let meals = mealManager.mealsForDate(selectedDate)
        return meals.reduce(NutritionData.empty) { total, meal in
            return total + meal.getNutritionData(from: mealManager)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Daily Nutrition")
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(totalNutrition.calories)) cal")
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
            
            // Macronutrient breakdown
            HStack(spacing: 16) {
                MacroView(
                    label: "Carbs",
                    value: totalNutrition.carbs,
                    unit: "g",
                    color: .blue
                )
                
                MacroView(
                    label: "Protein",
                    value: totalNutrition.protein,
                    unit: "g",
                    color: .red
                )
                
                MacroView(
                    label: "Fat",
                    value: totalNutrition.fat,
                    unit: "g",
                    color: .green
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct MacroView: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))\(unit)")
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meal Nutrition Badge
struct MealNutritionBadge: View {
    let nutrition: NutritionData
    let isCompact: Bool
    
    init(nutrition: NutritionData, isCompact: Bool = true) {
        self.nutrition = nutrition
        self.isCompact = isCompact
    }
    
    var body: some View {
        if isCompact {
            // Compact view for meal cards
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 8))
                Text("\(Int(nutrition.calories)) cal")
                    .font(.system(size: 10))
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )
        } else {
            // Expanded view for recipe details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text("Nutrition per serving")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(nutrition.calories)) calories")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                HStack(spacing: 12) {
                    Text("C: \(Int(nutrition.carbs))g")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("P: \(Int(nutrition.protein))g")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Text("F: \(Int(nutrition.fat))g")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if nutrition.fiber > 0 {
                        Text("Fiber: \(Int(nutrition.fiber))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Recipe Nutrition Editor
struct RecipeNutritionView: View {
    @Binding var recipe: Recipe
    @State private var showingIngredientSearch = false
    @State private var selectedIngredient: Ingredient?
    @State private var editingIngredientIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Ingredients & Nutrition")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showingIngredientSearch = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Ingredients list
            if recipe.ingredients.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "leaf")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No ingredients added")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Add First Ingredient") {
                        showingIngredientSearch = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    IngredientRowView(
                        ingredient: ingredient,
                        onEdit: {
                            editingIngredientIndex = index
                        },
                        onDelete: {
                            recipe.ingredients.remove(at: index)
                        }
                    )
                }
            }
            
            // Nutrition summary for recipe
            if !recipe.ingredients.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recipe Nutrition")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Recipe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            MealNutritionBadge(nutrition: recipe.totalNutrition, isCompact: false)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Per Serving (\(recipe.servings) servings)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            MealNutritionBadge(nutrition: recipe.nutritionPerServing, isCompact: false)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingIngredientSearch) {
            NutritionSearchView(
                selectedIngredient: $selectedIngredient,
                isPresented: $showingIngredientSearch
            )
        }
        .sheet(item: .init(
            get: {
                guard let index = editingIngredientIndex else { return nil }
                return EditableIngredient(ingredient: recipe.ingredients[index], index: index)
            },
            set: { _ in editingIngredientIndex = nil }
        )) { editableIngredient in
            IngredientEditView(
                ingredient: editableIngredient.ingredient,
                onSave: { updatedIngredient in
                    recipe.ingredients[editableIngredient.index] = updatedIngredient
                    editingIngredientIndex = nil
                },
                onCancel: {
                    editingIngredientIndex = nil
                }
            )
        }
        .onChange(of: selectedIngredient) { _, newValue in
            if let ingredient = newValue {
                recipe.ingredients.append(ingredient)
                selectedIngredient = nil
            }
        }
    }
}

// Helper struct for sheet binding
struct EditableIngredient: Identifiable {
    let id = UUID()
    let ingredient: Ingredient
    let index: Int
}

struct IngredientRowView: View {
    let ingredient: Ingredient
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ingredient.amount)
                        .font(.system(size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text(ingredient.name)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                    
                    if ingredient.isOptional {
                        Text("(optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                if ingredient.nutritionData != NutritionData.empty {
                    let calculatedNutrition = ingredient.calculatedNutrition()
                    MealNutritionBadge(nutrition: calculatedNutrition, isCompact: true)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

struct IngredientEditView: View {
    @State private var ingredient: Ingredient
    let onSave: (Ingredient) -> Void
    let onCancel: () -> Void
    
    @State private var showingNutritionSearch = false
    
    init(ingredient: Ingredient, onSave: @escaping (Ingredient) -> Void, onCancel: @escaping () -> Void) {
        self._ingredient = State(initialValue: ingredient)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredient Details")
                        .font(.headline)
                    
                    TextField("Name", text: $ingredient.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Amount (e.g., 2 cups, 100g)", text: $ingredient.amount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Category (optional)", text: $ingredient.category)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Optional ingredient", isOn: $ingredient.isOptional)
                }
                
                if ingredient.nutritionData != NutritionData.empty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutrition Data")
                            .font(.headline)
                        
                        MealNutritionBadge(nutrition: ingredient.calculatedNutrition(), isCompact: false)
                        
                        Button("Update Nutrition Data") {
                            showingNutritionSearch = true
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    Button("Add Nutrition Data") {
                        showingNutritionSearch = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(ingredient)
                    }
                    .disabled(ingredient.name.isEmpty || ingredient.amount.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingNutritionSearch) {
            NutritionSearchView(
                selectedIngredient: .init(
                    get: { nil },
                    set: { newIngredient in
                        if let newIngredient = newIngredient {
                            ingredient.nutritionData = newIngredient.nutritionData
                            ingredient.fdcId = newIngredient.fdcId
                        }
                    }
                ),
                isPresented: $showingNutritionSearch
            )
        }
        .presentationDetents([.height(500), .large])
    }
}

#Preview {
    @Previewable @State var selectedDate = Date()
    
    VStack(spacing: 20) {
        DailyNutritionSummary(
            selectedDate: selectedDate,
            mealManager: MealManager.shared
        )
        .padding()
        
        MealNutritionBadge(
            nutrition: NutritionData(
                calories: 250,
                protein: 12,
                carbs: 30,
                fat: 8,
                fiber: 5
            ),
            isCompact: false
        )
        .padding()
        
        Spacer()
    }
}
