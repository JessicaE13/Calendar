//
//  MealCardView.swift
//  Calendar
//
//  Compact meal planning card for the main calendar view
//

import SwiftUI

struct MealCardView: View {
    let selectedDate: Date
    @StateObject private var mealManager = MealManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingMealManagement = false
    
    private var mealsForToday: [PlannedMeal] {
        mealManager.mealsForDate(selectedDate)
    }
    
    private var completedMealsCount: Int {
        mealsForToday.filter { $0.isCompleted }.count
    }
    
    private var totalMealsCount: Int {
        mealsForToday.count
    }
    
    private var progressPercentage: Double {
        guard totalMealsCount > 0 else { return 0 }
        return Double(completedMealsCount) / Double(totalMealsCount)
    }
    
    private var nextMeal: PlannedMeal? {
        let now = Date()
        let calendar = Calendar.current
        
        // If it's a different day, show first meal
        if !calendar.isDate(selectedDate, equalTo: now, toGranularity: .day) {
            return mealsForToday.first
        }
        
        // For today, show next upcoming meal
        let currentHour = calendar.component(.hour, from: now)
        
        if currentHour < 10 { // Before 10 AM - show breakfast
            return mealsForToday.first { $0.mealType == .breakfast }
        } else if currentHour < 14 { // Before 2 PM - show lunch
            return mealsForToday.first { $0.mealType == .lunch }
        } else if currentHour < 20 { // Before 8 PM - show dinner
            return mealsForToday.first { $0.mealType == .dinner }
        } else { // Evening - show tomorrow's breakfast or today's snack
            return mealsForToday.first { $0.mealType == .snack } ?? mealsForToday.first
        }
    }
    
    var body: some View {
        if !mealsForToday.isEmpty || Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .day) {
            VStack(spacing: 0) {
                // Header with progress
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Meals")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if totalMealsCount > 0 {
                            Text("\(completedMealsCount) of \(totalMealsCount) completed")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        } else {
                            Text("No meals planned")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Progress circle or add button
                    if totalMealsCount > 0 {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                                .frame(width: 32, height: 32)
                            
                            Circle()
                                .trim(from: 0, to: progressPercentage)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.red]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(Int(progressPercentage * 100))%")
                                .font(.system(size: 10))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        .animation(.easeInOut(duration: 0.3), value: progressPercentage)
                    } else {
                        Button(action: {
                            showingMealManagement = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
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
                
                // Meals list or next meal preview
                if totalMealsCount > 0 {
                    if mealsForToday.count <= 2 {
                        // Show all meals if 2 or fewer
                        VStack(spacing: 0) {
                            ForEach(Array(mealsForToday.enumerated()), id: \.element.id) { index, meal in
                                MealRowView(
                                    meal: meal,
                                    mealManager: mealManager,
                                    categoryManager: categoryManager
                                )
                                
                                if index < mealsForToday.count - 1 {
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                    } else {
                        // Show next meal + count of others
                        VStack(spacing: 4) {
                            if let next = nextMeal {
                                MealRowView(
                                    meal: next,
                                    mealManager: mealManager,
                                    categoryManager: categoryManager
                                )
                            }
                            
                            if mealsForToday.count > 1 {
                                HStack {
                                    Text("+ \(mealsForToday.count - 1) more meals")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                } else {
                    // Empty state
                    HStack {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Tap + to plan meals")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                Spacer(minLength: 8)
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
}

struct MealRowView: View {
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
            return meal.mealType.displayName
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
        Button(action: {
            mealManager.toggleMealCompletion(meal)
        }) {
            HStack(spacing: 12) {
                // Meal type icon with color
                ZStack {
                    Circle()
                        .fill(meal.isCompleted ? categoryColor : categoryColor.opacity(0.3))
                        .frame(width: 20, height: 20)
                    
                    if meal.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: meal.mealType.icon)
                            .font(.system(size: 8))
                            .foregroundColor(categoryColor)
                    }
                }
                
                // Meal info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(meal.mealType.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        Spacer()
                        
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
                    
                    Text(displayName)
                        .font(.system(size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(meal.isCompleted ? .secondary : .primary)
                        .strikethrough(meal.isCompleted)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Meal Planning View
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
                PlannedMealCard(
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

struct PlannedMealCard: View {
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
        Button(action: {
            mealManager.toggleMealCompletion(meal)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // Completion checkbox
                    ZStack {
                        Circle()
                            .fill(meal.isCompleted ? categoryColor : categoryColor.opacity(0.2))
                            .frame(width: 24, height: 24)
                        
                        if meal.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.system(size: 16))
                            .fontWeight(.medium)
                            .foregroundColor(meal.isCompleted ? .secondary : .primary)
                            .strikethrough(meal.isCompleted)
                        
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
                    
                    if meal.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    }
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
        .buttonStyle(PlainButtonStyle())
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
