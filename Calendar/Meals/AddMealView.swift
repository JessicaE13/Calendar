//
//  Meal Management Views
//  Supporting views for adding/editing meals and managing recipes
//

import SwiftUI

// MARK: - Add Meal View
struct AddMealView: View {
    let selectedDate: Date
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var selectedMealType: MealType = .breakfast
    @State private var selectedRecipe: Recipe? = nil
    @State private var customMealName = ""
    @State private var notes = ""
    @State private var useCustomMeal = false
    
    private var existingMealTypes: Set<MealType> {
        Set(mealManager.mealsForDate(selectedDate).map { $0.mealType })
    }
    
    private var availableMealTypes: [MealType] {
        MealType.allCases.filter { !existingMealTypes.contains($0) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Meal Type Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meal Type")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            MealTypeButton(
                                mealType: mealType,
                                isSelected: selectedMealType == mealType,
                                isDisabled: existingMealTypes.contains(mealType)
                            ) {
                                selectedMealType = mealType
                            }
                        }
                    }
                }
                
                // Recipe or Custom Meal Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meal Content")
                        .font(.headline)
                    
                    HStack {
                        Button(action: { useCustomMeal = false }) {
                            HStack {
                                Image(systemName: !useCustomMeal ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(!useCustomMeal ? .blue : .gray)
                                Text("Use Recipe")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Button(action: { useCustomMeal = true }) {
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
                        RecipeSelector(
                            selectedRecipe: $selectedRecipe,
                            mealManager: mealManager,
                            categoryManager: categoryManager
                        )
                    }
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.headline)
                    
                    TextField("Any special notes or modifications", text: $notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(2...4)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add Meal") {
                        let plannedMeal = PlannedMeal(
                            date: selectedDate,
                            mealType: selectedMealType,
                            recipeID: useCustomMeal ? nil : selectedRecipe?.id,
                            customMealName: useCustomMeal ? customMealName : nil
                        )
                        var newMeal = plannedMeal
                        newMeal.notes = notes
                        
                        mealManager.addPlannedMeal(newMeal)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("Accent1"))
                    .cornerRadius(8)
                    .disabled(!isValidMeal)
                }
            }
            .padding()
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Set default meal type to first available
                if let firstAvailable = availableMealTypes.first {
                    selectedMealType = firstAvailable
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
        
        self._selectedRecipe = State(initialValue: meal.getRecipe(from: mealManager))
        self._customMealName = State(initialValue: meal.customMealName ?? "")
        self._notes = State(initialValue: meal.notes)
        self._useCustomMeal = State(initialValue: meal.recipeID == nil)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Meal Type (read-only)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Recipe or Custom Meal Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meal Content")
                        .font(.headline)
                    
                    HStack {
                        Button(action: { useCustomMeal = false }) {
                            HStack {
                                Image(systemName: !useCustomMeal ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(!useCustomMeal ? .blue : .gray)
                                Text("Use Recipe")
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Button(action: { useCustomMeal = true }) {
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
                        RecipeSelector(
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
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Delete") {
                        mealManager.deletePlannedMeal(meal)
                        isPresented = false
                    }
                    .foregroundColor(.red)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        var updatedMeal = meal
                        updatedMeal.recipeID = useCustomMeal ? nil : selectedRecipe?.id
                        updatedMeal.customMealName = useCustomMeal ? customMealName : nil
                        updatedMeal.notes = notes
                        
                        mealManager.updatePlannedMeal(updatedMeal)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("Accent1"))
                    .cornerRadius(8)
                    .disabled(!isValidMeal)
                }
            }
            .padding()
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Recipe Selector
struct RecipeSelector: View {
    @Binding var selectedRecipe: Recipe?
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    
    @State private var searchText = ""
    @State private var showingRecipeDetail: Recipe?
    
    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return mealManager.recipes.sorted { $0.name < $1.name }
        } else {
            return mealManager.searchRecipes(query: searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search
            TextField("Search recipes...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Selected recipe display
            if let selected = selectedRecipe {
                SelectedRecipeCard(recipe: selected, categoryManager: categoryManager) {
                    selectedRecipe = nil
                }
            } else {
                // Recipe list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRecipes.prefix(5)) { recipe in
                            RecipeSelectionRow(
                                recipe: recipe,
                                categoryManager: categoryManager
                            ) {
                                selectedRecipe = recipe
                            } onInfo: {
                                showingRecipeDetail = recipe
                            }
                        }
                        
                        if filteredRecipes.count > 5 {
                            Text("+ \(filteredRecipes.count - 5) more recipes...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .sheet(item: $showingRecipeDetail) { recipe in
            RecipeDetailView(
                recipe: recipe,
                mealManager: mealManager,
                categoryManager: categoryManager,
                isPresented: .init(
                    get: { showingRecipeDetail != nil },
                    set: { _ in showingRecipeDetail = nil }
                )
            )
        }
    }
}

// MARK: - Supporting Components
struct MealTypeButton: View {
    let mealType: MealType
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mealType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : mealType.color)
                
                Text(mealType.displayName)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mealType.color : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? mealType.color : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

struct SelectedRecipeCard: View {
    let recipe: Recipe
    @ObservedObject var categoryManager: CategoryManager
    let onRemove: () -> Void
    
    private var categoryColor: Color {
        if let category = recipe.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                
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
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(categoryColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(categoryColor, lineWidth: 1)
                )
        )
    }
}

struct RecipeSelectionRow: View {
    let recipe: Recipe
    @ObservedObject var categoryManager: CategoryManager
    let onSelect: () -> Void
    let onInfo: () -> Void
    
    private var categoryColor: Color {
        if let category = recipe.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.system(size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if recipe.totalTime > 0 {
                        Text("\(recipe.totalTime) min")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var selectedDate = Date()
    
    AddMealView(
        selectedDate: selectedDate,
        mealManager: MealManager.shared,
        categoryManager: CategoryManager.shared,
        isPresented: $isPresented
    )
}
