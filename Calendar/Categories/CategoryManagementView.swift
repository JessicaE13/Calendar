//
//  CategoryManagementView.swift
//  Calendar
//
//  Views for managing categories and colors
//

import SwiftUI

// MARK: - Category Management View
struct CategoryManagementView: View {
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if categoryManager.categories.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Categories")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create categories to organize your items")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Create Your First Category") {
                            showingAddCategory = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Accent1"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Categories list
                    List {
                        ForEach(categoryManager.categories) { category in
                            CategoryRowView(category: category) {
                                editingCategory = category
                            }
                        }
                        .onDelete(perform: deleteCategories)
                        .onMove(perform: moveCategories)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !categoryManager.categories.isEmpty {
                            EditButton()
                        }
                        
                        Button(action: {
                            showingAddCategory = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(categoryManager: categoryManager, isPresented: $showingAddCategory)
        }
        .sheet(item: $editingCategory) { category in
            EditCategoryView(
                category: category,
                categoryManager: categoryManager,
                isPresented: .init(
                    get: { editingCategory != nil },
                    set: { _ in editingCategory = nil }
                )
            )
        }
        .alert("Delete Error", isPresented: $categoryManager.showingError) {
            Button("OK") {
                categoryManager.showingError = false
            }
        } message: {
            Text(categoryManager.errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            let category = categoryManager.categories[index]
            categoryManager.deleteCategory(category)
        }
    }
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        categoryManager.moveCategory(from: source, to: destination)
    }
}

// MARK: - Category Row View
struct CategoryRowView: View {
    let category: Category
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Color indicator
                Circle()
                    .fill(category.color.swiftUIColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                
                // Category name
                Text(category.name)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Edit indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Category View
struct AddCategoryView: View {
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var categoryName = ""
    @State private var selectedColor: CategoryColor = .accent1
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Name")
                        .font(.headline)
                    
                    TextField("Enter category name", text: $categoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.headline)
                    
                    ColorSelectionGrid(selectedColor: $selectedColor)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add Category") {
                        let newCategory = Category(
                            name: categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                            color: selectedColor
                        )
                        categoryManager.addCategory(newCategory)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("Accent1"))
                    .cornerRadius(8)
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(400)])
    }
}

// MARK: - Edit Category View
struct EditCategoryView: View {
    let category: Category
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var categoryName: String
    @State private var selectedColor: CategoryColor
    
    init(category: Category, categoryManager: CategoryManager, isPresented: Binding<Bool>) {
        self.category = category
        self.categoryManager = categoryManager
        self._isPresented = isPresented
        self._categoryName = State(initialValue: category.name)
        self._selectedColor = State(initialValue: category.color)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Name")
                        .font(.headline)
                    
                    TextField("Enter category name", text: $categoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color")
                        .font(.headline)
                    
                    ColorSelectionGrid(selectedColor: $selectedColor)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        var updatedCategory = category
                        updatedCategory.name = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        updatedCategory.color = selectedColor
                        categoryManager.updateCategory(updatedCategory)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("Accent1"))
                    .cornerRadius(8)
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(400)])
    }
}

// MARK: - Color Selection Grid
struct ColorSelectionGrid: View {
    @Binding var selectedColor: CategoryColor
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 5)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CategoryColor.allCases, id: \.self) { color in
                Button(action: {
                    selectedColor = color
                }) {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: selectedColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Category Picker for Items
struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    @ObservedObject var categoryManager: CategoryManager
    let allowNone: Bool
    
    init(selectedCategory: Binding<Category?>, categoryManager: CategoryManager, allowNone: Bool = true) {
        self._selectedCategory = selectedCategory
        self.categoryManager = categoryManager
        self.allowNone = allowNone
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // None option
                    if allowNone {
                        CategoryOptionView(
                            category: nil,
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }
                    }
                    
                    // Category options
                    ForEach(categoryManager.categories) { category in
                        CategoryOptionView(
                            category: category,
                            isSelected: selectedCategory?.id == category.id
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct CategoryOptionView: View {
    let category: Category?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(category?.color.swiftUIColor ?? Color.gray)
                    .frame(width: 16, height: 16)
                
                Text(category?.name ?? "None")
                    .font(.system(size: 14))
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color("Accent1").opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color("Accent1") : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? Color("Accent1") : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @Previewable @State var isPresented = true
    let categoryManager = CategoryManager.shared
    
    CategoryManagementView(
        categoryManager: categoryManager,
        isPresented: $isPresented
    )
}
