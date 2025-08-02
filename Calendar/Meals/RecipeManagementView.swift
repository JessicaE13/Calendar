//
//  Recipe Management and Shopping List Views
//  Complete recipe browser and shopping list functionality
//

import SwiftUI

// MARK: - Recipe Management View
struct RecipeManagementView: View {
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var showingAddRecipe = false
    @State private var selectedCategory: Category?
    @State private var showFavoritesOnly = false
    @State private var showingRecipeDetail: Recipe?
    
    private var filteredRecipes: [Recipe] {
        var recipes = mealManager.recipes
        
        if showFavoritesOnly {
            recipes = recipes.filter { $0.isFavorite }
        }
        
        if let category = selectedCategory {
            recipes = recipes.filter { $0.categoryID == category.id }
        }
        
        if !searchText.isEmpty {
            recipes = mealManager.searchRecipes(query: searchText)
        }
        
        return recipes.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 12) {
                    // Search bar
                    TextField("Search recipes...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    // Filter buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Show all button
                            FilterButton(
                                title: "All",
                                isSelected: selectedCategory == nil && !showFavoritesOnly
                            ) {
                                selectedCategory = nil
                                showFavoritesOnly = false
                            }
                            
                            // Favorites button
                            FilterButton(
                                title: "Favorites",
                                isSelected: showFavoritesOnly
                            ) {
                                showFavoritesOnly.toggle()
                                selectedCategory = nil
                            }
                            
                            // Category buttons
                            ForEach(categoryManager.categories) { category in
                                FilterButton(
                                    title: category.name,
                                    isSelected: selectedCategory?.id == category.id,
                                    color: category.color.swiftUIColor
                                ) {
                                    selectedCategory = selectedCategory?.id == category.id ? nil : category
                                    showFavoritesOnly = false
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                if filteredRecipes.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Recipes Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if searchText.isEmpty {
                            Text("Create your first recipe to get started")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Add Recipe") {
                                showingAddRecipe = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color("Accent1"))
                        } else {
                            Text("Try adjusting your search or filters")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Recipes grid
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                            ForEach(filteredRecipes) { recipe in
                                RecipeCard(
                                    recipe: recipe,
                                    categoryManager: categoryManager
                                ) {
                                    showingRecipeDetail = recipe
                                } onToggleFavorite: {
                                    var updatedRecipe = recipe
                                    updatedRecipe.isFavorite.toggle()
                                    mealManager.updateRecipe(updatedRecipe)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddRecipe = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRecipe) {
            AddRecipeView(
                mealManager: mealManager,
                categoryManager: categoryManager,
                isPresented: $showingAddRecipe
            )
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

// MARK: - Recipe Card
struct RecipeCard: View {
    let recipe: Recipe
    @ObservedObject var categoryManager: CategoryManager
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    
    private var categoryColor: Color {
        if let category = recipe.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with favorite button
                HStack {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 12, height: 12)
                    
                    Spacer()
                    
                    Button(action: onToggleFavorite) {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(recipe.isFavorite ? .red : .gray)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Recipe info
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.name)
                        .font(.system(size: 16))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !recipe.description.isEmpty {
                        Text(recipe.description)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        if recipe.totalTime > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("\(recipe.totalTime)m")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if recipe.servings > 1 {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 10))
                                Text("\(recipe.servings)")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recipe Detail View
struct RecipeDetailView: View {
    let recipe: Recipe
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var showingEditRecipe = false
    
    private var categoryColor: Color {
        if let category = recipe.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(recipe.name)
                                .font(.system(.title, design: .serif))
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: {
                                var updatedRecipe = recipe
                                updatedRecipe.isFavorite.toggle()
                                mealManager.updateRecipe(updatedRecipe)
                            }) {
                                Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                                    .foregroundColor(recipe.isFavorite ? .red : .gray)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if !recipe.description.isEmpty {
                            Text(recipe.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        // Recipe metadata
                        HStack(spacing: 20) {
                            if recipe.prepTime > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Prep")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(recipe.prepTime)m")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if recipe.cookTime > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cook")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(recipe.cookTime)m")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if recipe.servings > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Serves")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(recipe.servings)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        
                        // Tags
                        if !recipe.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recipe.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(categoryColor.opacity(0.2))
                                            .foregroundColor(categoryColor)
                                            .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.horizontal, -20)
                        }
                    }
                    
                    Divider()
                    
                    // Ingredients
                    if !recipe.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ingredients")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(recipe.ingredients.indices, id: \.self) { index in
                                    let ingredient = recipe.ingredients[index]
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("•")
                                            .foregroundColor(categoryColor)
                                            .fontWeight(.bold)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(ingredient.amount)
                                                    .fontWeight(.medium)
                                                Text(ingredient.name)
                                                    .foregroundColor(ingredient.isOptional ? .secondary : .primary)
                                                
                                                if ingredient.isOptional {
                                                    Text("(optional)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .italic()
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    // Instructions
                    if !recipe.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Instructions")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(recipe.instructions.indices, id: \.self) { index in
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(categoryColor)
                                                .frame(width: 24, height: 24)
                                            
                                            Text("\(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text(recipe.instructions[index])
                                            .font(.body)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
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
                    Menu {
                        Button("Edit Recipe") {
                            showingEditRecipe = true
                        }
                        
                        Button("Add to Shopping List") {
                            for ingredient in recipe.ingredients {
                                let shoppingItem = ShoppingListItem(
                                    name: ingredient.name,
                                    amount: ingredient.amount,
                                    category: ingredient.category,
                                    fromRecipeID: recipe.id
                                )
                                mealManager.addShoppingListItem(shoppingItem)
                            }
                        }
                        
                        Button("Delete Recipe", role: .destructive) {
                            mealManager.deleteRecipe(recipe)
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditRecipe) {
            EditRecipeView(
                recipe: recipe,
                mealManager: mealManager,
                categoryManager: categoryManager,
                isPresented: $showingEditRecipe
            )
        }
    }
}

// MARK: - Shopping List View
struct ShoppingListView: View {
    @ObservedObject var mealManager: MealManager
    @Binding var isPresented: Bool
    
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var newItemAmount = ""
    @State private var newItemCategory = ""
    
    private var groupedItems: [(String, [ShoppingListItem])] {
        let items = mealManager.shoppingList
        let grouped = Dictionary(grouping: items) { item in
            item.category.isEmpty ? "Other" : item.category
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    private var completedItems: [ShoppingListItem] {
        mealManager.shoppingList.filter { $0.isCompleted }
    }
    
    private var pendingItems: [ShoppingListItem] {
        mealManager.shoppingList.filter { !$0.isCompleted }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if mealManager.shoppingList.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Shopping List Empty")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add items manually or generate from your meal plans")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Add First Item") {
                            showingAddItem = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Accent1"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        // Pending items by category
                        ForEach(groupedItems.filter { !$0.1.allSatisfy { $0.isCompleted } }, id: \.0) { category, items in
                            let pendingInCategory = items.filter { !$0.isCompleted }
                            if !pendingInCategory.isEmpty {
                                Section(category) {
                                    ForEach(pendingInCategory) { item in
                                        ShoppingListItemRow(
                                            item: item,
                                            mealManager: mealManager
                                        )
                                    }
                                    .onDelete { offsets in
                                        for index in offsets {
                                            mealManager.deleteShoppingListItem(pendingInCategory[index])
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Completed items section
                        if !completedItems.isEmpty {
                            Section("Completed") {
                                ForEach(completedItems) { item in
                                    ShoppingListItemRow(
                                        item: item,
                                        mealManager: mealManager
                                    )
                                }
                                .onDelete { offsets in
                                    for index in offsets {
                                        mealManager.deleteShoppingListItem(completedItems[index])
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !completedItems.isEmpty {
                            Button("Clear Completed") {
                                for item in completedItems {
                                    mealManager.deleteShoppingListItem(item)
                                }
                            }
                            .font(.system(size: 14))
                        }
                        
                        Button(action: {
                            showingAddItem = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .alert("Add Shopping Item", isPresented: $showingAddItem) {
            TextField("Item name", text: $newItemName)
            TextField("Amount (optional)", text: $newItemAmount)
            TextField("Category (optional)", text: $newItemCategory)
            Button("Add") {
                if !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let item = ShoppingListItem(
                        name: newItemName,
                        amount: newItemAmount,
                        category: newItemCategory
                    )
                    mealManager.addShoppingListItem(item)
                    newItemName = ""
                    newItemAmount = ""
                    newItemCategory = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newItemName = ""
                newItemAmount = ""
                newItemCategory = ""
            }
        } message: {
            Text("Enter the details for the new shopping item")
        }
    }
}

struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    @ObservedObject var mealManager: MealManager
    
    var body: some View {
        Button(action: {
            mealManager.toggleShoppingItemCompletion(item)
        }) {
            HStack {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.isCompleted ? .green : .gray)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.name)
                            .strikethrough(item.isCompleted)
                            .foregroundColor(item.isCompleted ? .secondary : .primary)
                        
                        if !item.amount.isEmpty {
                            Text("(\(item.amount))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let recipeID = item.fromRecipeID,
                       let recipe = mealManager.recipes.first(where: { $0.id == recipeID }) {
                        Text("From: \(recipe.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Components
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    var color: Color = Color("Accent1")
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? color : color.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(color, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Recipe View (Placeholder)
struct AddRecipeView: View {
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    // This would be a more complex view for adding recipes
    // For now, showing a simple placeholder
    var body: some View {
        NavigationView {
            VStack {
                Text("Recipe creation form would go here")
                    .foregroundColor(.secondary)
                Text("This would include fields for name, ingredients, instructions, etc.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct EditRecipeView: View {
    let recipe: Recipe
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    // This would be a more complex view for editing recipes
    var body: some View {
        NavigationView {
            VStack {
                Text("Recipe editing form would go here")
                    .foregroundColor(.secondary)
                Text("Pre-populated with current recipe data")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    RecipeManagementView(
        mealManager: MealManager.shared,
        categoryManager: CategoryManager.shared,
        isPresented: $isPresented
    )
}
