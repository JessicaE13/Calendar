//
//  Enhanced Recipe Selector with Dropdown Search and Browse All
//  Replace the RecipeSelector in AddMealView.swift with this enhanced version
//

import SwiftUI

// MARK: - Enhanced Recipe Selector
struct EnhancedRecipeSelector: View {
    @Binding var selectedRecipe: Recipe?
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var showingRecipeDetail: Recipe?
    @State private var showingAllRecipes = false
    
    @FocusState private var searchFieldFocused: Bool
    
    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty {
            return mealManager.recipes.prefix(8).map { $0 } // Show first 8 when no search
        } else {
            return mealManager.searchRecipes(query: searchText).prefix(10).map { $0 }
        }
    }
    
    private var shouldShowDropdown: Bool {
        (isSearchFocused || !searchText.isEmpty) && !filteredRecipes.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Browse All button
            HStack {
                Text("Recipe")
                    .font(.headline)
                
                Spacer()
                
                Button("Browse All") {
                    showingAllRecipes = true
                }
                .font(.system(size: 14))
                .foregroundColor(Color("Accent1"))
            }
            
            if let selected = selectedRecipe {
                // Selected recipe display
                SelectedRecipeCard(
                    recipe: selected,
                    categoryManager: categoryManager
                ) {
                    selectedRecipe = nil
                    searchText = ""
                }
            } else {
                // Search interface
                VStack(spacing: 0) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                        
                        TextField("Search recipes...", text: $searchText)
                            .focused($searchFieldFocused)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onTapGesture {
                                isSearchFocused = true
                            }
                            .onChange(of: searchFieldFocused) { oldValue, newValue in
                                isSearchFocused = newValue
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchFieldFocused = false
                                isSearchFocused = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSearchFocused ? Color("Accent1") : Color.clear, lineWidth: 1)
                            )
                    )
                    
                    // Dropdown results
                    if shouldShowDropdown {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredRecipes.enumerated()), id: \.element.id) { index, recipe in
                                DropdownRecipeRow(
                                    recipe: recipe,
                                    categoryManager: categoryManager,
                                    searchText: searchText
                                ) {
                                    selectRecipe(recipe)
                                } onInfo: {
                                    showingRecipeDetail = recipe
                                }
                                
                                if index < filteredRecipes.count - 1 {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                            
                            // Show more results indicator
                            if searchText.isEmpty && mealManager.recipes.count > 8 {
                                Button(action: {
                                    showingAllRecipes = true
                                }) {
                                    HStack {
                                        Text("See all \(mealManager.recipes.count) recipes")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color("Accent1"))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color("Accent1"))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .background(Color.gray.opacity(0.05))
                            } else if !searchText.isEmpty && mealManager.searchRecipes(query: searchText).count > 10 {
                                Button(action: {
                                    showingAllRecipes = true
                                }) {
                                    HStack {
                                        Text("See more results...")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color("Accent1"))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color("Accent1"))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .background(Color.gray.opacity(0.05))
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.top, 4)
                    }
                    
                    // Quick access buttons when not searching
                    if !isSearchFocused && searchText.isEmpty {
                        HStack(spacing: 8) {
                            QuickAccessButton(
                                title: "Favorites",
                                icon: "heart.fill",
                                count: mealManager.favoriteRecipes().count
                            ) {
                                showingAllRecipes = true
                            }
                            
                            QuickAccessButton(
                                title: "Quick",
                                icon: "clock.fill",
                                count: mealManager.recipes.filter { $0.totalTime <= 30 }.count
                            ) {
                                searchText = "quick"
                                searchFieldFocused = true
                            }
                            
                            QuickAccessButton(
                                title: "Healthy",
                                icon: "leaf.fill",
                                count: mealManager.recipes.filter { $0.tags.contains("healthy") }.count
                            ) {
                                searchText = "healthy"
                                searchFieldFocused = true
                            }
                        }
                        .padding(.top, 8)
                    }
                }
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
        .sheet(isPresented: $showingAllRecipes) {
            RecipeBrowserView(
                mealManager: mealManager,
                categoryManager: categoryManager,
                initialSearchText: searchText,
                onRecipeSelected: { recipe in
                    selectRecipe(recipe)
                    showingAllRecipes = false
                },
                isPresented: $showingAllRecipes
            )
        }
    }
    
    private func selectRecipe(_ recipe: Recipe) {
        selectedRecipe = recipe
        searchText = ""
        searchFieldFocused = false
        isSearchFocused = false
    }
}



// MARK: - Selected Recipe Card Component
struct SelectedRecipeCard: View {
    let recipe: Recipe
    @ObservedObject var categoryManager: CategoryManager
    let onClear: () -> Void
    
    private var categoryColor: Color {
        if let category = recipe.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Category color indicator
            Circle()
                .fill(categoryColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
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
                    
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(categoryColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}


// MARK: - Dropdown Recipe Row
struct DropdownRecipeRow: View {
    let recipe: Recipe
    @ObservedObject var categoryManager: CategoryManager
    let searchText: String
    let onSelect: () -> Void
    let onInfo: () -> Void
    
    private var categoryColor: Color {
        if let category = recipe.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray
    }
    
    private var highlightedTitle: AttributedString {
        var attributedString = AttributedString(recipe.name)
        
        if !searchText.isEmpty {
            let searchRange = recipe.name.lowercased().range(of: searchText.lowercased())
            if let range = searchRange {
                let nsRange = NSRange(range, in: recipe.name)
                let attributedRange = Range(nsRange, in: attributedString)
                if let attributedRange = attributedRange {
                    attributedString[attributedRange].backgroundColor = Color.yellow.opacity(0.3)
                    attributedString[attributedRange].foregroundColor = Color.primary
                }
            }
        }
        
        return attributedString
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Category color indicator
                Circle()
                    .fill(categoryColor)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(highlightedTitle)
                        .font(.system(size: 15))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {
                        if recipe.totalTime > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("\(recipe.totalTime)m")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if recipe.servings > 1 {
                            HStack(spacing: 3) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 10))
                                Text("\(recipe.servings)")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        if recipe.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                    }
                }
                
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Access Button
struct QuickAccessButton: View {
    let title: String
    let icon: String
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color("Accent1"))
                
                Text(title)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recipe Browser View
struct RecipeBrowserView: View {
    @ObservedObject var mealManager: MealManager
    @ObservedObject var categoryManager: CategoryManager
    let initialSearchText: String
    let onRecipeSelected: (Recipe) -> Void
    @Binding var isPresented: Bool
    
    @State private var searchText: String
    @State private var selectedCategory: Category?
    @State private var showFavoritesOnly = false
    @State private var sortBy: RecipeSortOption = .name
    @State private var showingRecipeDetail: Recipe?
    
    init(mealManager: MealManager, categoryManager: CategoryManager, initialSearchText: String = "", onRecipeSelected: @escaping (Recipe) -> Void, isPresented: Binding<Bool>) {
        self.mealManager = mealManager
        self.categoryManager = categoryManager
        self.initialSearchText = initialSearchText
        self.onRecipeSelected = onRecipeSelected
        self._isPresented = isPresented
        self._searchText = State(initialValue: initialSearchText)
    }
    
    private var filteredAndSortedRecipes: [Recipe] {
        var recipes = mealManager.recipes
        
        // Apply filters
        if showFavoritesOnly {
            recipes = recipes.filter { $0.isFavorite }
        }
        
        if let category = selectedCategory {
            recipes = recipes.filter { $0.categoryID == category.id }
        }
        
        if !searchText.isEmpty {
            recipes = recipes.filter { recipe in
                recipe.name.lowercased().contains(searchText.lowercased()) ||
                recipe.description.lowercased().contains(searchText.lowercased()) ||
                recipe.tags.contains { $0.lowercased().contains(searchText.lowercased()) } ||
                recipe.ingredients.contains { $0.name.lowercased().contains(searchText.lowercased()) }
            }
        }
        
        // Apply sorting
        switch sortBy {
        case .name:
            return recipes.sorted { $0.name < $1.name }
        case .time:
            return recipes.sorted { $0.totalTime < $1.totalTime }
        case .recent:
            return recipes.sorted { $0.lastModified > $1.lastModified }
        case .favorites:
            return recipes.sorted { $0.isFavorite && !$1.isFavorite }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 16) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search recipes...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                    )
                    
                    // Filter and sort options
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Sort picker
                            Menu {
                                Picker("Sort by", selection: $sortBy) {
                                    ForEach(RecipeSortOption.allCases, id: \.self) { option in
                                        Text(option.displayName).tag(option)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 12))
                                    Text(sortBy.displayName)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.primary)
                            }
                            
                            // Show all button
                            FilterChip(
                                title: "All",
                                isSelected: selectedCategory == nil && !showFavoritesOnly
                            ) {
                                selectedCategory = nil
                                showFavoritesOnly = false
                            }
                            
                            // Favorites button
                            FilterChip(
                                title: "Favorites",
                                isSelected: showFavoritesOnly
                            ) {
                                showFavoritesOnly.toggle()
                                selectedCategory = nil
                            }
                            
                            // Category buttons
                            ForEach(categoryManager.categories) { category in
                                FilterChip(
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
                
                // Results
                if filteredAndSortedRecipes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No recipes found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Try adjusting your search or filters")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                            ForEach(filteredAndSortedRecipes) { recipe in
                                BrowsableRecipeCard(
                                    recipe: recipe,
                                    categoryManager: categoryManager,
                                    onSelect: {
                                        onRecipeSelected(recipe)
                                    },
                                    onDetail: {
                                        showingRecipeDetail = recipe
                                    },
                                    onToggleFavorite: {
                                        var updatedRecipe = recipe
                                        updatedRecipe.isFavorite.toggle()
                                        mealManager.updateRecipe(updatedRecipe)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Browse Recipes (\(filteredAndSortedRecipes.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
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

// MARK: - Browsable Recipe Card
struct BrowsableRecipeCard: View {
    let recipe: Recipe
    @ObservedObject var categoryManager: CategoryManager
    let onSelect: () -> Void
    let onDetail: () -> Void
    let onToggleFavorite: () -> Void
    
    private var categoryColor: Color {
        if let category = recipe.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with favorite button
            HStack {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 8, height: 8)
                
                Spacer()
                
                Button(action: onToggleFavorite) {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(recipe.isFavorite ? .red : .gray)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Recipe info
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.system(size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if !recipe.description.isEmpty {
                    Text(recipe.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if recipe.totalTime > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text("\(recipe.totalTime)m")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if recipe.servings > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2")
                                .font(.system(size: 8))
                            Text("\(recipe.servings)")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button("Select") {
                    onSelect()
                }
                .font(.system(size: 12))
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color("Accent1"))
                .cornerRadius(6)
                
                Button("View") {
                    onDetail()
                }
                .font(.system(size: 12))
                .foregroundColor(Color("Accent1"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color("Accent1"), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = Color("Accent1")
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
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

// MARK: - Recipe Sort Options
enum RecipeSortOption: CaseIterable {
    case name, time, recent, favorites
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .time: return "Time"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        }
    }
}

#Preview {
    @Previewable @State var selectedRecipe: Recipe? = nil
    
    VStack {
        EnhancedRecipeSelector(
            selectedRecipe: $selectedRecipe,
            mealManager: MealManager.shared,
            categoryManager: CategoryManager.shared
        )
        .padding()
        
        Spacer()
    }
}
