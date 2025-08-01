//
//  ItemRowView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//  Updated with inline editing and edit mode functionality
//

import SwiftUI

struct ItemRowView: View {
    @ObservedObject var itemManager: ItemManager
    let item: Item
    @State private var showingItemDetails = false
    
    private var timeComponents: (time: String, period: String) {
        guard let time = item.assignedTime else { return ("", "") }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: time)
        
        let timeString: String
        if minutes == 0 {
            formatter.dateFormat = "h" // Just the hour
            timeString = formatter.string(from: time)
        } else {
            formatter.dateFormat = "h:mm" // Hour and minutes
            timeString = formatter.string(from: time)
        }
        
        formatter.dateFormat = "a" // Just AM/PM
        let period = formatter.string(from: time).uppercased()
        
        return (timeString, period)
    }
    
    var body: some View {
        Button(action: {
            showingItemDetails = true
        }) {
            HStack(spacing: 12) {
                // Checkmark button (only when no time is assigned)
                if item.assignedTime == nil {
                    Button(action: {
                        itemManager.toggleItemCompletion(item)
                    }) {
                        Image(systemName: item.isCompleted ? "checkmark.square" : "square")
                            .foregroundColor(item.isCompleted ? .green : .gray)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Item content - different styling based on whether it has time
                VStack(alignment: .leading, spacing: 4) {
                    if let _ = item.assignedTime {
                        // Item with time - add background with rounded corners
                        HStack(spacing: 0) {
                            Text(timeComponents.time)
                                .font(.system(size: 16))
                            Text(timeComponents.period)
                                .font(.system(size: 10))
                                .baselineOffset(-5) // Align with the bottom of the numbers
                            Text(" \(item.title)")
                                .font(.system(size: 16))
                        }
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color("Accent1").opacity(0.3))
                        )
                    } else {
                        // Item without time - no background
                        Text(item.title)
                            .font(.system(size: 16))
                            .padding(.vertical, 8)
                            .strikethrough(item.isCompleted)
                            .foregroundColor(item.isCompleted ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 8)
        .sheet(isPresented: $showingItemDetails) {
            ItemDetailsView(
                item: item,
                itemManager: itemManager,
                isPresented: $showingItemDetails
            )
            .presentationCornerRadius(30)
            .presentationBackground(Color(red: 0.96, green: 0.94, blue: 0.89))
        }
    }
}

struct ItemDetailsView: View {
    let item: Item
    @ObservedObject var itemManager: ItemManager
    @Binding var isPresented: Bool
    
    @State private var isEditMode = false
    @State private var editedTitle = ""
    @State private var editedDescription = ""
    @State private var editedDate = Date()
    @State private var editedTime = Date()
    @State private var hasTime = false
    @State private var showingAddChecklistItem = false
    @State private var newChecklistItemTitle = ""
    @State private var editedChecklist: [ChecklistItem] = []
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let dateToFormat = isEditMode ? editedDate : item.assignedDate
        
        if calendar.isDateInToday(dateToFormat) {
            return "Today"
        } else if calendar.isDate(dateToFormat, equalTo: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(), toGranularity: .day) {
            return "Tomorrow"
        } else if calendar.isDate(dateToFormat, equalTo: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(), toGranularity: .day) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: dateToFormat)
        }
    }
    
    private var formattedTime: String {
        if isEditMode {
            if hasTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return formatter.string(from: editedTime)
            } else {
                return "No time set"
            }
        } else {
            guard let time = item.assignedTime else { return "No time set" }
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: time)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Item Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Name")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            if isEditMode {
                                TextField("Item name", text: $editedTitle)
                                    .font(.system(size: 20))
                                    .fontWeight(.medium)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                Text(item.title)
                                    .font(.system(size: 20))
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        enterEditMode()
                                    }
                            }
                        }
                        
                        Divider()
                        
                        // Description & Checklist Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description & Checklist")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            if isEditMode {
                                // Edit mode view
                                VStack(spacing: 0) {
                                    // Add Subtask button
                                    Button("Add Subtask") {
                                        showingAddChecklistItem = true
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                                    
                                    // Description and subtasks
                                    VStack(alignment: .leading, spacing: 12) {
                                        TextField("Add notes, meeting links or phone numbers...", text: $editedDescription, axis: .vertical)
                                            .font(.system(size: 16))
                                            .lineLimit(2...6)
                                        
                                        ForEach(editedChecklist.sorted { $0.sortOrder < $1.sortOrder }) { checklistItem in
                                            HStack(spacing: 8) {
                                                Button(action: {
                                                    toggleEditedChecklistItem(checklistItem)
                                                }) {
                                                    Image(systemName: checklistItem.isCompleted ? "checkmark.square.fill" : "square")
                                                        .foregroundColor(checklistItem.isCompleted ? .green : .gray)
                                                }
                                                
                                                Text(checklistItem.title)
                                                    .strikethrough(checklistItem.isCompleted)
                                                    .foregroundColor(checklistItem.isCompleted ? .secondary : .primary)
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    deleteEditedChecklistItem(checklistItem)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red.opacity(0.6))
                                                }
                                            }
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(0.8))
                                }
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            } else {
                                // Read-only view
                                Button(action: { enterEditMode() }) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        if !item.description.isEmpty {
                                            Text(item.description)
                                                .font(.system(size: 16))
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        
                                        ForEach(item.checklist.sorted { $0.sortOrder < $1.sortOrder }) { checklistItem in
                                            HStack(spacing: 8) {
                                                Image(systemName: checklistItem.isCompleted ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(checklistItem.isCompleted ? .green : .gray)
                                                
                                                Text(checklistItem.title)
                                                    .strikethrough(checklistItem.isCompleted)
                                                    .foregroundColor(checklistItem.isCompleted ? .secondary : .primary)
                                                
                                                Spacer()
                                            }
                                        }
                                        
                                        if item.description.isEmpty && item.checklist.isEmpty {
                                            Text("No description or subtasks")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                                .italic()
                                        }
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(0.5))
                                    .cornerRadius(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Divider()
                        
                        // Date Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Date")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                
                                if isEditMode {
                                    DatePicker("Date", selection: $editedDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .font(.system(size: 18))
                                } else {
                                    Text(formattedDate)
                                        .font(.system(size: 18))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            enterEditMode()
                                        }
                                }
                                
                                Spacer()
                            }
                        }
                        
                        Divider()
                        
                        // Time Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Time")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                if isEditMode {
                                    Toggle("Assign Time", isOn: $hasTime)
                                        .font(.system(size: 16))
                                        .fontWeight(.medium)
                                    
                                    if hasTime {
                                        DatePicker("Time", selection: $editedTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .font(.system(size: 18))
                                    }
                                } else {
                                    HStack {
                                        Image(systemName: item.assignedTime != nil ? "clock" : "clock.badge.xmark")
                                            .foregroundColor(.secondary)
                                        
                                        Text(formattedTime)
                                            .font(.system(size: 18))
                                            .foregroundColor(item.assignedTime != nil ? .primary : .secondary)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                enterEditMode()
                                            }
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Edit/Save button at bottom
                        Button(action: {
                            if isEditMode {
                                saveChanges()
                            } else {
                                enterEditMode()
                            }
                        }) {
                            HStack {
                                Image(systemName: isEditMode ? "checkmark" : "pencil")
                                Text(isEditMode ? "Save Item" : "Edit Item")
                            }
                            .font(.system(size: 16))
                            .foregroundColor(isEditMode ? .white : Color("Accent1"))
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isEditMode ? Color("Accent1") : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("Accent1"), lineWidth: isEditMode ? 0 : 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if isEditMode {
                            saveChanges()
                        }
                        isPresented = false
                    }
                }
            }
            .onAppear {
                setupEditableValues()
            }
        }
        .presentationDetents([.height(600), .large])
        .alert("Add Checklist Item", isPresented: $showingAddChecklistItem) {
            TextField("Item title", text: $newChecklistItemTitle)
            Button("Add") {
                if !newChecklistItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let newChecklistItem = ChecklistItem(
                        title: newChecklistItemTitle,
                        sortOrder: editedChecklist.count
                    )
                    editedChecklist.append(newChecklistItem)
                    newChecklistItemTitle = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newChecklistItemTitle = ""
            }
        } message: {
            Text("Enter the title for the new checklist item")
        }
    }
    
    private func setupEditableValues() {
        editedTitle = item.title
        editedDescription = item.description
        editedDate = item.assignedDate
        editedTime = item.assignedTime ?? Date()
        hasTime = item.assignedTime != nil
        editedChecklist = item.checklist
    }
    
    private func enterEditMode() {
        setupEditableValues()
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditMode = true
        }
    }
    
    private func saveChanges() {
        // Update the item with edited values
        itemManager.updateItemName(item, newName: editedTitle)
        itemManager.updateItemDescription(item, newDescription: editedDescription)
        itemManager.updateItemDate(item, newDate: editedDate)
        itemManager.updateItemTime(item, time: hasTime ? editedTime : nil)
        
        // Update checklist with proper sync
        updateItemChecklist()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isEditMode = false
        }
    }
    
    private func updateItemChecklist() {
        guard let itemIndex = itemManager.items.firstIndex(where: { $0.id == item.id }) else { return }
        
        // Update the checklist
        itemManager.items[itemIndex].checklist = editedChecklist
        itemManager.items[itemIndex].lastModified = Date()
        
        let updatedItem = itemManager.items[itemIndex]
        
        // Sync to CloudKit using the same pattern as other update methods
        Task {
            do {
                let savedItem = try await CloudKitManager.shared.saveItem(updatedItem)
                await MainActor.run {
                    if let idx = itemManager.items.firstIndex(where: { $0.id == savedItem.id }) {
                        itemManager.items[idx] = savedItem
                    }
                }
            } catch {
                await MainActor.run {
                    itemManager.errorMessage = "Failed to sync checklist: \(error.localizedDescription)"
                    itemManager.showingError = true
                }
            }
        }
    }
    private func toggleEditedChecklistItem(_ checklistItem: ChecklistItem) {
        if let index = editedChecklist.firstIndex(where: { $0.id == checklistItem.id }) {
            editedChecklist[index].isCompleted.toggle()
        }
    }
    
    private func deleteEditedChecklistItem(_ checklistItem: ChecklistItem) {
        editedChecklist.removeAll { $0.id == checklistItem.id }
        // Reorder remaining items
        for (index, _) in editedChecklist.enumerated() {
            editedChecklist[index].sortOrder = index
        }
    }
}

struct ChecklistItemRow: View {
    let checklistItem: ChecklistItem
    let parentItem: Item
    @ObservedObject var itemManager: ItemManager
    let isEditMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                itemManager.toggleChecklistItemCompletion(parentItem, checklistItem: checklistItem)
            }) {
                Image(systemName: checklistItem.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(checklistItem.isCompleted ? .green : .gray)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(checklistItem.title)
                .font(.system(size: 16))
                .strikethrough(checklistItem.isCompleted)
                .foregroundColor(checklistItem.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if isEditMode {
                Button(action: {
                    itemManager.deleteChecklistItem(parentItem, checklistItem: checklistItem)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.6))
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.3))
        )
    }
}

#Preview {
    let itemManager = ItemManager()
    ItemRowView(itemManager: itemManager, item: itemManager.items[0])
}
