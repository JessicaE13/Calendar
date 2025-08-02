//
//  NutritionSearchView.swift
//  Calendar
//
//  Search and select foods with nutrition data from USDA API
//

import SwiftUI

// MARK: - Nutrition Search View
struct NutritionSearchView: View {
    @Binding var selectedIngredient: Ingredient?
    @Binding var isPresented: Bool
    
    @StateObject private var nutritionService = NutritionService.shared
    @State private var searchText = ""
    @State private var searchResults: [USDAFood] = []
    @State private var isSearching = false
    @State private var amount = "1 cup"
    @State private var category = ""
    @State private var showingNutritionDetail: USDAFood?
    
    // Debounced search
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Search section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search for Food")
                        .font(.headline)
                    
                    TextField("Search foods (e.g., 'banana', 'chicken breast')", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) {
                            performSearch()
                        }
                    
                    if isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Amount and category inputs
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredient Details")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("e.g., 2 cups, 100g", text: $amount)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Category")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Optional", text: $category)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                // Search results
                if !searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search Results")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(searchResults) { food in
                                    FoodResultRow(
                                        food: food,
                                        amount: amount,
                                        category: category
                                    ) {
                                        selectFood(food)
                                    } onNutritionTap: {
                                        showingNutritionDetail = food
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                } else if !searchText.isEmpty && !isSearching {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No foods found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: 100)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manual") {
                        // Create ingredient without nutrition data
                        if !searchText.isEmpty {
                            selectedIngredient = Ingredient(
                                name: searchText,
                                amount: amount,
                                category: category
                            )
                            isPresented = false
                        }
                    }
                    .disabled(searchText.isEmpty)
                }
            }
        }
        .sheet(item: $showingNutritionDetail) { food in
            NutritionDetailView(
                food: food,
                amount: amount,
                isPresented: .init(
                    get: { showingNutritionDetail != nil },
                    set: { _ in showingNutritionDetail = nil }
                )
            )
        }
        .alert("Search Error", isPresented: .init(
            get: { nutritionService.errorMessage != nil },
            set: { _ in nutritionService.errorMessage = nil }
        )) {
            Button("OK") {
                nutritionService.errorMessage = nil
            }
        } message: {
            Text(nutritionService.errorMessage ?? "Unknown error occurred")
        }
    }
    
    private func performSearch() {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        // Debounce search by 500ms
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isSearching = true
            }
            
            do {
                let results = try await nutritionService.searchFoods(query: searchText)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.isSearching = false
                    self.nutritionService.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func selectFood(_ food: USDAFood) {
        Task {
            do {
                let nutritionData = try await nutritionService.getNutritionData(for: food.fdcId)
                
                await MainActor.run {
                    var ingredient = Ingredient(
                        name: food.description,
                        amount: amount,
                        category: category
                    )
                    ingredient.nutritionData = nutritionData
                    ingredient.fdcId = food.fdcId
                    
                    selectedIngredient = ingredient
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    nutritionService.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Food Result Row
struct FoodResultRow: View {
    let food: USDAFood
    let amount: String
    let category: String
    let onSelect: () -> Void
    let onNutritionTap: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.description)
                        .font(.system(size: 15))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let brandOwner = food.brandOwner {
                        Text(brandOwner)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Amount: \(amount)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: onNutritionTap) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Nutrition Detail View
struct NutritionDetailView: View {
    let food: USDAFood
    let amount: String
    @Binding var isPresented: Bool
    
    @StateObject private var nutritionService = NutritionService.shared
    @State private var nutritionData: NutritionData?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading nutrition data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let nutrition = nutritionData {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Food info
                            VStack(alignment: .leading, spacing: 8) {
                                Text(food.description)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if let brandOwner = food.brandOwner {
                                    Text(brandOwner)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Amount: \(amount)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Divider()
                            
                            // Calculate nutrition for the specified amount
                            let gramsAmount = nutritionService.parseAmountToGrams(amount, for: food.description)
                            let scaleFactor = gramsAmount / 100.0
                            let scaledNutrition = nutrition.scaled(by: scaleFactor)
                            
                            NutritionFactsView(nutrition: scaledNutrition)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Could not load nutrition data")
                            .font(.headline)
                        Text("Please try again later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Nutrition Facts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .task {
            await loadNutritionData()
        }
    }
    
    private func loadNutritionData() async {
        do {
            let data = try await nutritionService.getNutritionData(for: food.fdcId)
            await MainActor.run {
                self.nutritionData = data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.nutritionService.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Nutrition Facts View
struct NutritionFactsView: View {
    let nutrition: NutritionData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition Facts")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                // Calories (prominent)
                HStack {
                    Text("Calories")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(nutrition.calories))")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                
                Divider()
                
                // Macronutrients
                NutritionRow(label: "Total Fat", value: nutrition.fat, unit: "g")
                NutritionRow(label: "Carbohydrates", value: nutrition.carbs, unit: "g")
                NutritionRow(label: "Dietary Fiber", value: nutrition.fiber, unit: "g", indent: true)
                NutritionRow(label: "Total Sugars", value: nutrition.sugar, unit: "g", indent: true)
                NutritionRow(label: "Protein", value: nutrition.protein, unit: "g")
                
                Divider()
                
                // Micronutrients
                NutritionRow(label: "Sodium", value: nutrition.sodium, unit: "mg")
                NutritionRow(label: "Calcium", value: nutrition.calcium, unit: "mg")
                NutritionRow(label: "Iron", value: nutrition.iron, unit: "mg")
                NutritionRow(label: "Vitamin C", value: nutrition.vitaminC, unit: "mg")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct NutritionRow: View {
    let label: String
    let value: Double
    let unit: String
    let indent: Bool
    
    init(label: String, value: Double, unit: String, indent: Bool = false) {
        self.label = label
        self.value = value
        self.unit = unit
        self.indent = indent
    }
    
    var body: some View {
        HStack {
            if indent {
                Text("    \(label)")
                    .font(.system(size: 14))
            } else {
                Text(label)
                    .font(.system(size: 15))
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Text("\(value.formatted(.number.precision(.fractionLength(1))))\(unit)")
                .font(.system(size: 14))
                .fontWeight(indent ? .regular : .medium)
        }
    }
}

#Preview {
    @Previewable @State var selectedIngredient: Ingredient? = nil
    @Previewable @State var isPresented = true
    
    NutritionSearchView(
        selectedIngredient: $selectedIngredient,
        isPresented: $isPresented
    )
}
