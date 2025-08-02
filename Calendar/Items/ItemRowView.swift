//
//  ItemRowView.swift
//  Calendar
//
//  Complete file with Rich Text Editor integration
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

// MARK: - Item Details View with Rich Text Editor
struct ItemDetailsView: View {
    let item: Item
    @ObservedObject var itemManager: ItemManager
    @Binding var isPresented: Bool
    
    @State private var isEditMode = false
    @State private var editedTitle = ""
    @State private var editedDescriptionLines: [RichTextLine] = []
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
                        
                        // Rich Text Description Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description & Notes")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            if isEditMode {
                                RichTextEditor(lines: $editedDescriptionLines)
                            } else {
                                // Read-only rich text display
                                if editedDescriptionLines.isEmpty {
                                    Button(action: { enterEditMode() }) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Add notes, meeting links, or create checklists...")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                                .italic()
                                        }
                                        .padding(16)
                                        .background(Color.white.opacity(0.5))
                                        .cornerRadius(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else {
                                    Button(action: { enterEditMode() }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(editedDescriptionLines) { line in
                                                ReadOnlyRichTextLineView(line: line)
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
                        }
                        
                        Divider()
                        
                        // Legacy Checklist Section (for backward compatibility)
                        if !item.checklist.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Legacy Checklist")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                if isEditMode {
                                    VStack(spacing: 0) {
                                        Button("Add Subtask") {
                                            showingAddChecklistItem = true
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .medium))
                                        
                                        VStack(alignment: .leading, spacing: 12) {
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
                                    Button(action: { enterEditMode() }) {
                                        VStack(alignment: .leading, spacing: 12) {
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
                                        }
                                        .padding(16)
                                        .background(Color.white.opacity(0.5))
                                        .cornerRadius(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                Divider()
                            }
                        }
                        
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
    
    // MARK: - Helper Methods
    
    private func setupEditableValues() {
        editedTitle = item.title
        editedDate = item.assignedDate
        editedTime = item.assignedTime ?? Date()
        hasTime = item.assignedTime != nil
        editedChecklist = item.checklist
        
        // Convert description to rich text lines
        if item.description.isEmpty {
            editedDescriptionLines = []
        } else {
            editedDescriptionLines = [RichTextLine].fromDescriptionString(item.description)
        }
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
        itemManager.updateItemDate(item, newDate: editedDate)
        itemManager.updateItemTime(item, time: hasTime ? editedTime : nil)
        
        // Convert rich text lines back to description string
        let newDescription = editedDescriptionLines.toDescriptionString()
        itemManager.updateItemDescription(item, newDescription: newDescription)
        
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

// MARK: - Read-Only Rich Text Line View
struct ReadOnlyRichTextLineView: View {
    let line: RichTextLine
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if line.type == .checkbox {
                Text(line.isCompleted ? "☑" : "☐")
                    .font(.system(size: 16))
                    .foregroundColor(line.isCompleted ? .green : .gray)
            } else if line.type == .bullet {
                Text("•")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Text(line.content)
                .font(.system(size: 16))
                .strikethrough(line.type == .checkbox && line.isCompleted)
                .foregroundColor(line.type == .checkbox && line.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Checklist Item Row
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
