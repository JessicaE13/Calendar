//
//  Enhanced MealCardView.swift
//  Replace your existing MealCardView with this version for better nutrition visibility
//

import SwiftUI

struct MealCardView: View {
    let selectedDate: Date
    @StateObject private var mealManager = MealManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingMealManagement = false
    @State private var showNutritionSummary = true // Default to showing nutrition
    
    private var mealsForToday: [PlannedMeal] {
        mealManager.mealsForDate(selectedDate)
    }
    
    private var hasMealsWithNutrition: Bool {
        mealsForToday.contains { meal in
            meal.getNutritionData(from: mealManager).calories > 0
        }
    }
    
    // Calculate total daily nutrition
    private var totalNutrition: NutritionData {
        mealsForToday.reduce(NutritionData.empty) { total, meal in
            return total + meal.getNutritionData(from: mealManager)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with nutrition toggle
            HStack {
                Text("Meals")
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Always show nutrition info if any meals exist
                if !mealsForToday.isEmpty {
                    // Daily calories indicator
                    if totalNutrition.calories > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("\(Int(totalNutrition.calories))")
                                .font(.system(size: 12))
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Nutrition toggle button
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
            
            // Nutrition summary (show by default if data exists)
            if showNutritionSummary && totalNutrition.calories > 0 {
                EnhancedNutritionSummary(
                    selectedDate: selectedDate,
                    mealManager: mealManager,
                    totalNutrition: totalNutrition
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // Meal types list - vertical stack
            VStack(spacing: 0) {
                ForEach(Array(MealType.allCases.enumerated()), id: \.element) { index, mealType in
                    EnhancedMealTypeRow(
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

// MARK: - Edit Meal View
struct EditMealView: View {
    let meal: PlannedMeal
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var selectedRecipe: Recipe?
    @State private var customMealName: String
    @State private var notes: String
    @State private var useCustomMeal: Bool
    
    init(meal: PlannedMeal, mealManager: MealManager, categoryManager: CategoryManager, isPresented: Binding<Bool>) {
        self.meal = meal
        self.mealManager = mealManager
        self.categoryManager = categoryManager
        self._isPresented = isPresented
        
        // Initialize state from the meal
        self._selectedRecipe = State(initialValue: meal.getRecipe(from: mealManager))
        self._customMealName = State(initialValue: meal.customMealName ?? "")
        self._notes = State(initialValue: meal.notes)
        self._useCustomMeal = State(initialValue: meal.recipeID == nil)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Meal Type Display (read-only)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal Type")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: meal.mealType.icon)
                                .foregroundColor(meal.mealType.color)
                            Text(meal.mealType.displayName)
                                .font(.system(size: 16))
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(meal.mealType.color.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(meal.mealType.color.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    
                    // Recipe or Custom Meal Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meal Content")
                            .font(.headline)
                        
                        HStack {
                            Button(action: {
                                useCustomMeal = false
                                customMealName = ""
                            }) {
                                HStack {
                                    Image(systemName: !useCustomMeal ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(!useCustomMeal ? .blue : .gray)
                                    Text("Use Recipe")
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            Button(action: {
                                useCustomMeal = true
                                selectedRecipe = nil
                            }) {
                                HStack {
                                    Image(systemName: useCustomMeal ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(useCustomMeal ? .blue : .gray)
                                    Text("Custom Meal")
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if useCustomMeal {
                            TextField("Enter meal name", text: $customMealName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            EnhancedRecipeSelector(
                                selectedRecipe: $selectedRecipe,
                                mealManager: mealManager,
                                categoryManager: categoryManager
                            )
                        }
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        
                        TextField("Any special notes or modifications", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updatedMeal = meal
                        updatedMeal.recipeID = useCustomMeal ? nil : selectedRecipe?.id
                        updatedMeal.customMealName = useCustomMeal ? customMealName : nil
                        updatedMeal.notes = notes
                        
                        mealManager.updatePlannedMeal(updatedMeal)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidMeal)
                }
            }
        }
        .presentationDetents([.height(600), .large])
    }
    
    private var isValidMeal: Bool {
        if useCustomMeal {
            return !customMealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return selectedRecipe != nil
        }
    }
}

// Enhanced nutrition summary with better styling
struct EnhancedNutritionSummary: View {
    let selectedDate: Date
    @ObservedObject var mealManager: MealManager
    let totalNutrition: NutritionData
    
    var body: some View {
        VStack(spacing: 10) {
            // Main calories display
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Nutrition")
                        .font(.system(size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("\(Int(totalNutrition.calories)) calories")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                // Quick macro breakdown
                HStack(spacing: 8) {
                    MacroIndicator(
                        label: "C",
                        value: Int(totalNutrition.carbs),
                        color: .blue
                    )
                    MacroIndicator(
                        label: "P",
                        value: Int(totalNutrition.protein),
                        color: .red
                    )
                    MacroIndicator(
                        label: "F",
                        value: Int(totalNutrition.fat),
                        color: .green
                    )
                }
            }
            
            // Progress bars for macros
            MacroProgressBars(nutrition: totalNutrition)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct MacroIndicator: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text("\(value)g")
                .font(.system(size: 11))
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct MacroProgressBars: View {
    let nutrition: NutritionData
    
    // Rough daily targets for reference (you could make these user-configurable)
    private let dailyTargets = (carbs: 250.0, protein: 150.0, fat: 80.0)
    
    var body: some View {
        VStack(spacing: 4) {
            MacroProgressBar(
                label: "Carbs",
                current: nutrition.carbs,
                target: dailyTargets.carbs,
                color: .blue
            )
            MacroProgressBar(
                label: "Protein",
                current: nutrition.protein,
                target: dailyTargets.protein,
                color: .red
            )
            MacroProgressBar(
                label: "Fat",
                current: nutrition.fat,
                target: dailyTargets.fat,
                color: .green
            )
        }
    }
}

struct MacroProgressBar: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color
    
    private var progress: Double {
        min(current / target, 1.0)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            
            Text("\(Int(current))g")
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(width: 25, alignment: .trailing)
        }
    }
}

struct EnhancedMealTypeRow: View {
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
    
    private var mealNutrition: NutritionData {
        plannedMeal?.getNutritionData(from: mealManager) ?? NutritionData.empty
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
            
            // Nutrition and time info
            VStack(alignment: .trailing, spacing: 2) {
                // Show calories prominently if available
                if mealNutrition.calories > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text("\(Int(mealNutrition.calories))")
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }
                
                // Time info
                if let recipe = recipe, recipe.totalTime > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text("\(recipe.totalTime)m")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Meal Planning View (Simplified)
// Updated MealPlanningView with fixed toolbar syntax
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
