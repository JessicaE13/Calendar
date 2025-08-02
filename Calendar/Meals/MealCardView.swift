//
//  MealCardView.swift
//  Calendar
//
//  Simple meal planning card showing meal types vertically with icons
//

import SwiftUI

struct MealCardView: View {
    let selectedDate: Date
    @StateObject private var mealManager = MealManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingMealManagement = false
    @State private var showNutritionSummary = false
    
    private var mealsForToday: [PlannedMeal] {
        mealManager.mealsForDate(selectedDate)
    }
    
    private var hasMealsWithNutrition: Bool {
        mealsForToday.contains { meal in
            meal.getNutritionData(from: mealManager).calories > 0
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Meals")
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Nutrition toggle (only show if there's nutrition data)
                if hasMealsWithNutrition {
                    Button(action: {
                        showNutritionSummary.toggle()
                    }) {
                        Image(systemName: showNutritionSummary ? "chart.bar.fill" : "chart.bar")
                            .font(.system(size: 14))
                            .foregroundColor(Color("Accent1"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Manage button
                Button(action: {
                    showingMealManagement = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundColor(Color("Accent1"))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Optional nutrition summary
            if showNutritionSummary && hasMealsWithNutrition {
                DailyNutritionSummary(
                    selectedDate: selectedDate,
                    mealManager: mealManager
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // Meal types list - vertical stack
            VStack(spacing: 0) {
                ForEach(Array(MealType.allCases.enumerated()), id: \.element) { index, mealType in
                    MealTypeRow(
                        mealType: mealType,
                        selectedDate: selectedDate,
                        mealManager: mealManager,
                        categoryManager: categoryManager
                    )
                    
                    if index < MealType.allCases.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingMealManagement) {
            MealPlanningView(
                selectedDate: selectedDate,
                mealManager: mealManager,
                categoryManager: categoryManager,
                isPresented: $showingMealManagement
            )
        }
    }
}

struct MealTypeRow: View {
    let mealType: MealType
    let selectedDate: Date
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    
    private var plannedMeal: PlannedMeal? {
        mealManager.mealForDate(selectedDate, type: mealType)
    }
    
    private var recipe: Recipe? {
        plannedMeal?.getRecipe(from: mealManager)
    }
    
    private var displayName: String {
        if let plannedMeal = plannedMeal {
            if let recipe = recipe {
                return recipe.name
            } else if let customName = plannedMeal.customMealName, !customName.isEmpty {
                return customName
            }
        }
        return "Not planned"
    }
    
    private var isPlanned: Bool {
        return plannedMeal != nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Meal type icon
            ZStack {
                Circle()
                    .fill(mealType.color.opacity(isPlanned ? 0.8 : 0.3))
                    .frame(width: 20, height: 20)
                
                Image(systemName: mealType.icon)
                    .font(.system(size: 8))
                    .foregroundColor(.white)
            }
            
            // Meal info
            VStack(alignment: .leading, spacing: 2) {
                Text(mealType.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(displayName)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(isPlanned ? .primary : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Time and nutrition info
            VStack(alignment: .trailing, spacing: 2) {
                if let recipe = recipe, recipe.totalTime > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text("\(recipe.totalTime)m")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
                
                // Nutrition badge for planned meals
                if isPlanned {
                    let nutrition = plannedMeal?.getNutritionData(from: mealManager) ?? NutritionData.empty
                    if nutrition.calories > 0 {
                        MealNutritionBadge(nutrition: nutrition, isCompact: true)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Meal Planning View (Simplified)
struct MealPlanningView: View {
    let selectedDate: Date
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var showingAddMeal = false
    @State private var showingRecipeManagement = false
    @State private var showingShoppingList = false
    @State private var editingMeal: PlannedMeal?
    
    private var mealsForDate: [PlannedMeal] {
        mealManager.mealsForDate(selectedDate)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Date header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meal Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(dateFormatter.string(from: selectedDate))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                if mealsForDate.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Meals Planned")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Plan your meals for this day")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Plan First Meal") {
                            showingAddMeal = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Accent1"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Meals list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(MealType.allCases, id: \.self) { mealType in
                                MealTypeSection(
                                    mealType: mealType,
                                    selectedDate: selectedDate,
                                    mealManager: mealManager,
                                    categoryManager: categoryManager,
                                    onAddMeal: {
                                        showingAddMeal = true
                                    },
                                    onEditMeal: { meal in
                                        editingMeal = meal
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showingShoppingList = true
                        }) {
                            Image(systemName: "cart")
                        }
                        
                        Button(action: {
                            showingRecipeManagement = true
                        }) {
                            Image(systemName: "book")
                        }
                        
                        Menu {
                            Button("Add Meal", action: { showingAddMeal = true })
                            Button("Generate Shopping List") {
                                mealManager.generateShoppingListFromPlannedMeals(for: [selectedDate])
                                showingShoppingList = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMeal) {
            AddMealView(
                selectedDate: selectedDate,
                mealManager: mealManager,
                categoryManager: categoryManager,
                isPresented: $showingAddMeal
            )
        }
        .sheet(isPresented: $showingRecipeManagement) {
            RecipeManagementView(
                mealManager: mealManager,
                categoryManager: categoryManager,
                isPresented: $showingRecipeManagement
            )
        }
        .sheet(isPresented: $showingShoppingList) {
            ShoppingListView(
                mealManager: mealManager,
                isPresented: $showingShoppingList
            )
        }
        .sheet(item: $editingMeal) { meal in
            EditMealView(
                meal: meal,
                mealManager: mealManager,
                categoryManager: categoryManager,
                isPresented: .init(
                    get: { editingMeal != nil },
                    set: { _ in editingMeal = nil }
                )
            )
        }
    }
}

struct MealTypeSection: View {
    let mealType: MealType
    let selectedDate: Date
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    let onAddMeal: () -> Void
    let onEditMeal: (PlannedMeal) -> Void
    
    private var mealForType: PlannedMeal? {
        mealManager.mealForDate(selectedDate, type: mealType)
    }
    
    private var recipe: Recipe? {
        mealForType?.getRecipe(from: mealManager)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: mealType.icon)
                        .font(.system(size: 16))
                        .foregroundColor(mealType.color)
                    
                    Text(mealType.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if mealForType != nil {
                    Button("Edit") {
                        if let meal = mealForType {
                            onEditMeal(meal)
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color("Accent1"))
                } else {
                    Button("Add") {
                        onAddMeal()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color("Accent1"))
                }
            }
            
            if let meal = mealForType {
                SimplePlannedMealCard(
                    meal: meal,
                    mealManager: mealManager,
                    categoryManager: categoryManager
                )
            } else {
                Button(action: onAddMeal) {
                    HStack {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        
                        Text("Add \(mealType.displayName.lowercased())")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct SimplePlannedMealCard: View {
    let meal: PlannedMeal
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    
    private var recipe: Recipe? {
        meal.getRecipe(from: mealManager)
    }
    
    private var displayName: String {
        if let recipe = recipe {
            return recipe.name
        } else if let customName = meal.customMealName, !customName.isEmpty {
            return customName
        } else {
            return "Planned \(meal.mealType.displayName)"
        }
    }
    
    private var categoryColor: Color {
        if let recipe = recipe,
           let category = recipe.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return meal.mealType.color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let recipe = recipe {
                        HStack(spacing: 12) {
                            if recipe.totalTime > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text("\(recipe.totalTime) min")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            if recipe.servings > 1 {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 10))
                                    Text("\(recipe.servings) servings")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            
            if !meal.notes.isEmpty {
                Text(meal.notes)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(categoryColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    @Previewable @State var selectedDate = Date()
    
    ZStack {
        BackgroundView()
        
        VStack {
            MealCardView(selectedDate: selectedDate)
                .padding()
            Spacer()
        }
    }
}
