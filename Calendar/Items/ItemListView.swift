//
//  ItemListView.swift
//  Calendar
//
//  EXPLICIT DRAG AND DROP IMPLEMENTATION WITH RECURRING TASK SUPPORT
//

import SwiftUI

struct ItemListView: View {
    @ObservedObject var itemManager: ItemManager
    let selectedDate: Date
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    
    // Our display items that we fully control
    @State private var displayItems: [Item] = []
    @State private var draggedItem: Item?
    
    private var selectedDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDate(selectedDate, equalTo: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(), toGranularity: .day) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                
                if displayItems.isEmpty {
                    
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.square")
                            .font(.title)
                            .foregroundColor(.black.opacity(0.6))
                        
                        Text("No items for this day")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Text("Tap + to add a item")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .padding(.horizontal, 20)
                } else {
                    
                    // Custom scrollable list with explicit drag and drop
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayItems, id: \.id) { item in
                                DraggableItemRow(
                                    item: item,
                                    itemManager: itemManager,
                                    isBeingDragged: draggedItem?.id == item.id,
                                    onDragChanged: { isDragging in
                                        if isDragging {
                                            draggedItem = item
                                        } else {
                                            draggedItem = nil
                                        }
                                    },
                                    onMove: { draggedItem, targetItem in
                                        moveItem(draggedItem, to: targetItem)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .background(
                        // Timeline line
                        HStack {
                            Rectangle()
                                .fill(.gray)
                                .frame(width: 2)
                                .padding(.leading, 51)
                            Spacer()
                        }
                    )
                }
                
                Spacer()
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showingAddItem = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color("Accent1"))
                                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: showingAddItem)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            loadDisplayItems()
        }
        .onChange(of: selectedDate) {
            loadDisplayItems()
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(itemManager: itemManager, selectedDate: selectedDate, isPresented: $showingAddItem) {
                loadDisplayItems()
            }
        }
    }
    
    private func loadDisplayItems() {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)
        
        let itemsForThisDate = itemManager.items.filter { item in
            calendar.isDate(item.assignedDate, equalTo: targetDate, toGranularity: .day)
        }
        
        let sortedItems = itemsForThisDate.sorted { item1, item2 in
            let hasCustomOrder = itemsForThisDate.contains { $0.hasCustomOrder(for: selectedDate) }
            
            if hasCustomOrder {
                return item1.sortOrder < item2.sortOrder
            } else {
                if let time1 = item1.assignedTime, let time2 = item2.assignedTime {
                    return time1 < time2
                } else if item1.assignedTime != nil && item2.assignedTime == nil {
                    return true
                } else if item1.assignedTime == nil && item2.assignedTime != nil {
                    return false
                } else {
                    return item1.sortOrder < item2.sortOrder
                }
            }
        }
        
        displayItems = sortedItems
        print("📋 Loaded \(displayItems.count) items for display")
    }
    
    private func moveItem(_ draggedItem: Item, to targetItem: Item) {
        print("🔄 Moving '\(draggedItem.title)' to position of '\(targetItem.title)'")
        
        guard let fromIndex = displayItems.firstIndex(where: { $0.id == draggedItem.id }),
              let toIndex = displayItems.firstIndex(where: { $0.id == targetItem.id }) else {
            print("❌ Could not find item indices")
            return
        }
        
        // Move the item in the display array
        withAnimation(.easeInOut(duration: 0.3)) {
            let movedItem = displayItems.remove(at: fromIndex)
            displayItems.insert(movedItem, at: toIndex)
        }
        
        // Update sort orders
        for (index, item) in displayItems.enumerated() {
            if let globalIndex = itemManager.items.firstIndex(where: { $0.id == item.id }) {
                itemManager.items[globalIndex].sortOrder = index
                itemManager.items[globalIndex].lastModified = Date()
                itemManager.items[globalIndex].setCustomOrder(for: selectedDate, hasCustomOrder: true)
            }
        }
        
        // Background sync
        Task {
            for item in displayItems {
                if let globalItem = itemManager.items.first(where: { $0.id == item.id }) {
                    do {
                        _ = try await CloudKitManager.shared.saveItem(globalItem)
                    } catch {
                        print("❌ Failed to sync '\(item.title)': \(error)")
                    }
                }
            }
        }
        
        print("✅ Move completed")
    }
}

struct DraggableItemRow: View {
    let item: Item
    @ObservedObject var itemManager: ItemManager
    let isBeingDragged: Bool
    let onDragChanged: (Bool) -> Void
    let onMove: (Item, Item) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            Circle()
                .fill(.gray)
                .frame(width: 8, height: 8)
            
            ItemRowView(itemManager: itemManager, item: item)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color.clear)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .offset(dragOffset)
        .zIndex(isDragging ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        onDragChanged(true)
                        print("🎯 Started dragging '\(item.title)'")
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    print("🎯 Ended dragging '\(item.title)' at offset \(value.translation)")
                    
                    // Simple logic: if we dragged more than 30 points, move to next/previous item
                    if abs(value.translation.height) > 30 {
                        // Find target item based on drag direction
                        if let currentIndex = itemManager.itemsForDate(Date()).firstIndex(where: { $0.id == item.id }) {
                            let allItems = itemManager.itemsForDate(Date())
                            var targetIndex = currentIndex
                            
                            if value.translation.height < 0 && currentIndex > 0 {
                                // Dragged up
                                targetIndex = currentIndex - 1
                            } else if value.translation.height > 0 && currentIndex < allItems.count - 1 {
                                // Dragged down
                                targetIndex = currentIndex + 1
                            }
                            
                            if targetIndex != currentIndex && targetIndex < allItems.count {
                                onMove(item, allItems[targetIndex])
                            }
                        }
                    }
                    
                    // Reset drag state
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dragOffset = .zero
                        isDragging = false
                    }
                    onDragChanged(false)
                }
        )
    }
}

//
//  Updated AddItemView with Category Selection
//  Calendar
//

import SwiftUI

struct AddItemView: View {
    @ObservedObject var itemManager: ItemManager
    let selectedDate: Date
    @Binding var isPresented: Bool
    let onItemAdded: () -> Void
    
    @State private var itemTitle = ""
    @State private var hasTime = false
    @State private var selectedTime = Date()
    @State private var recurrencePattern = RecurrencePattern()
    @State private var showingRecurrenceOptions = false
    @State private var selectedCategory: Category? = nil
    
    // Category manager
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingCategoryManagement = false
    
    private var recurrenceDescription: String {
        if !recurrencePattern.isRecurring {
            return "Never"
        }
        
        let baseDescription = recurrencePattern.interval == 1 ? recurrencePattern.frequency.displayName : "Every \(recurrencePattern.interval) \(recurrencePattern.frequency.rawValue)s"
        
        var description = baseDescription
        
        if let endDate = recurrencePattern.endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            description += " until \(formatter.string(from: endDate))"
        } else if let maxOccurrences = recurrencePattern.maxOccurrences {
            description += " for \(maxOccurrences) times"
        }
        
        return description
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Item Title Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Title")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    TextField("Enter item description", text: $itemTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                }
                
                // Category Selection Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Category")
                            .font(.system(size: 16))
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Manage") {
                            showingCategoryManagement = true
                        }
                        .font(.system(size: 14))
                        .foregroundColor(Color("Accent1"))
                    }
                    
                    CategoryPickerView(
                        selectedCategory: $selectedCategory,
                        categoryManager: categoryManager
                    )
                }
                
                // Time Section
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Assign Time", isOn: $hasTime)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    if hasTime {
                        DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                }
                
                // Recurrence Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Repeat")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    Button(action: {
                        showingRecurrenceOptions = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.secondary)
                            
                            Text(recurrenceDescription)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add Item") {
                        var newItem = Item(
                            title: itemTitle,
                            assignedDate: selectedDate,
                            assignedTime: hasTime ? selectedTime : nil,
                            sortOrder: itemManager.items.count,
                            categoryID: selectedCategory?.id
                        )
                        
                        // Set up recurring pattern if specified
                        if recurrencePattern.isRecurring {
                            newItem.recurrencePattern = recurrencePattern
                            newItem.isRecurringParent = true
                        }
                        
                        itemManager.addItemWithCategory(newItem, category: selectedCategory)
                        onItemAdded()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                  Color.gray : Color("Accent1"))
                    )
                    .disabled(itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .padding()
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(650)])
        .sheet(isPresented: $showingRecurrenceOptions) {
            RecurrenceOptionsView(
                recurrencePattern: $recurrencePattern,
                isPresented: $showingRecurrenceOptions
            )
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(
                categoryManager: categoryManager,
                isPresented: $showingCategoryManagement
            )
        }
        .onAppear {
            // Sync categories when the view appears
            categoryManager.forceSyncWithCloudKit()
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    let itemManager = ItemManager()
    
    AddItemView(
        itemManager: itemManager,
        selectedDate: Date(),
        isPresented: $isPresented,
        onItemAdded: {}
    )
}
