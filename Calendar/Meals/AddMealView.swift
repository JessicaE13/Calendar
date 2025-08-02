//
//  Updated AddMealView.swift with Enhanced Recipe Selector
//  Replace the RecipeSelector usage in AddMealView with this version
//

import SwiftUI

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
            ScrollView {
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
                        Text("Notes (Optional)")
                            .font(.headline)
                        
                        TextField("Any special notes or modifications", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    .disabled(!isValidMeal)
                }
            }
            .onAppear {
                // Set default meal type to first available
                if let firstAvailable = availableMealTypes.first {
                    selectedMealType = firstAvailable
                }
            }
        }
        .presentationDetents([.height(700), .large])
    }
    
    private var isValidMeal: Bool {
        if useCustomMeal {
            return !customMealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return selectedRecipe != nil
        }
    }
}

// Keep the existing MealTypeButton component
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

#Preview {
    @Previewable @State var isPresented = true
    
    AddMealView(
        selectedDate: Date(),
        mealManager: MealManager.shared,
        categoryManager: CategoryManager.shared,
        isPresented: $isPresented
    )
}
