//
//  ItemRowView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
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
    
    @State private var showingNameEditor = false
    @State private var showingDescriptionEditor = false
    @State private var showingDateEditor = false
    @State private var showingTimeEditor = false
    @State private var showingAddChecklistItem = false
    @State private var newChecklistItemTitle = ""
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(item.assignedDate) {
            return "Today"
        } else if calendar.isDate(item.assignedDate, equalTo: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(), toGranularity: .day) {
            return "Tomorrow"
        } else if calendar.isDate(item.assignedDate, equalTo: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date(), toGranularity: .day) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: item.assignedDate)
        }
    }
    
    private var formattedTime: String {
        guard let time = item.assignedTime else { return "No time set" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Item completion toggle at the top
                HStack {
                    Button(action: {
                        itemManager.toggleItemCompletion(item)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(item.isCompleted ? .green : .gray)
                            
                            Text(item.isCompleted ? "Completed" : "Mark as complete")
                                .font(.system(size: 16))
                                .foregroundColor(item.isCompleted ? .green : .primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.5))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Item Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Name")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Spacer()
                                
                                Button("Edit") {
                                    showingNameEditor = true
                                }
                                .font(.system(size: 14))
                                .foregroundColor(Color("Accent1"))
                            }
                            
                            Text(item.title)
                                .font(.system(size: 20))
                                .fontWeight(.medium)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Divider()
                        
                        // Description Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Description")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Spacer()
                                
                                Button("Edit") {
                                    showingDescriptionEditor = true
                                }
                                .font(.system(size: 14))
                                .foregroundColor(Color("Accent1"))
                            }
                            
                            if item.description.isEmpty {
                                Text("No description")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                Text(item.description)
                                    .font(.system(size: 16))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        Divider()
                        
                        // Date Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Date")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Spacer()
                                
                                Button("Edit") {
                                    showingDateEditor = true
                                }
                                .font(.system(size: 14))
                                .foregroundColor(Color("Accent1"))
                            }
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                
                                Text(formattedDate)
                                    .font(.system(size: 18))
                                
                                Spacer()
                            }
                        }
                        
                        Divider()
                        
                        // Time Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Time")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Spacer()
                                
                                Button("Edit") {
                                    showingTimeEditor = true
                                }
                                .font(.system(size: 14))
                                .foregroundColor(Color("Accent1"))
                            }
                            
                            HStack {
                                Image(systemName: item.assignedTime != nil ? "clock" : "clock.badge.xmark")
                                    .foregroundColor(.secondary)
                                
                                Text(formattedTime)
                                    .font(.system(size: 18))
                                    .foregroundColor(item.assignedTime != nil ? .primary : .secondary)
                                
                                Spacer()
                            }
                        }
                        
                        Divider()
                        
                        // Checklist Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Checklist")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Spacer()
                                
                                Button("Add Item") {
                                    showingAddChecklistItem = true
                                }
                                .font(.system(size: 14))
                                .foregroundColor(Color("Accent1"))
                            }
                            
                            if item.checklist.isEmpty {
                                Text("No checklist items")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(item.checklist.sorted { $0.sortOrder < $1.sortOrder }) { item in
                                        ChecklistItemRow(
                                            item: item,
                                            item: item,
                                            itemManager: itemManager
                                        )
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Delete button at bottom
                        Button(action: {
                            itemManager.deleteItem(item)
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Item")
                            }
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
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
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.height(600), .large])
        .sheet(isPresented: $showingNameEditor) {
            EditNameView(
                currentName: item.title,
                onSave: { newName in
                    updateItemName(newName)
                }
            )
        }
        .sheet(isPresented: $showingDescriptionEditor) {
            EditDescriptionView(
                currentDescription: item.description,
                onSave: { newDescription in
                    updateItemDescription(newDescription)
                }
            )
        }
        .sheet(isPresented: $showingDateEditor) {
            EditDateView(
                currentDate: item.assignedDate,
                onSave: { newDate in
                    updateItemDate(newDate)
                }
            )
        }
        .sheet(isPresented: $showingTimeEditor) {
            EditTimeView(
                currentTime: item.assignedTime,
                hasTime: item.assignedTime != nil,
                onSave: { newTime, hasTimeValue in
                    updateItemTime(hasTimeValue ? newTime : nil)
                }
            )
        }
        .alert("Add Checklist Item", isPresented: $showingAddChecklistItem) {
            TextField("Item title", text: $newChecklistItemTitle)
            Button("Add") {
                if !newChecklistItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    itemManager.addChecklistItem(item, title: newChecklistItemTitle)
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
    
    // Update these methods in your ItemDetailsView within ItemRowView.swift

    private func updateItemName(_ newName: String) {
        itemManager.updateItemName(item, newName: newName)
    }

    private func updateItemDescription(_ newDescription: String) {
        itemManager.updateItemDescription(item, newDescription: newDescription)
    }

    private func updateItemDate(_ newDate: Date) {
        itemManager.updateItemDate(item, newDate: newDate)
    }

    private func updateItemTime(_ newTime: Date?) {
        itemManager.updateItemTime(item, time: newTime)
    }
}

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let item: Item
    @ObservedObject var itemManager: ItemManager
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                itemManager.toggleChecklistItemCompletion(item, item: item)
            }) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.isCompleted ? .green : .gray)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(item.title)
                .font(.system(size: 16))
                .strikethrough(item.isCompleted)
                .foregroundColor(item.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            Button(action: {
                itemManager.deleteChecklistItem(item, item: item)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.6))
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.3))
        )
    }
}

// Separate edit views for each field
struct EditNameView: View {
    let currentName: String
    let onSave: (String) -> Void
    @State private var editedName: String
    @Environment(\.dismiss) private var dismiss
    
    init(currentName: String, onSave: @escaping (String) -> Void) {
        self.currentName = currentName
        self.onSave = onSave
        self._editedName = State(initialValue: currentName)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Name")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    TextField("Enter item name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedName)
                        dismiss()
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

struct EditDescriptionView: View {
    let currentDescription: String
    let onSave: (String) -> Void
    @State private var editedDescription: String
    @Environment(\.dismiss) private var dismiss
    
    init(currentDescription: String, onSave: @escaping (String) -> Void) {
        self.currentDescription = currentDescription
        self.onSave = onSave
        self._editedDescription = State(initialValue: currentDescription)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    TextField("Enter description", text: $editedDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                        .lineLimit(3...6)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedDescription)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}

struct EditDateView: View {
    let currentDate: Date
    let onSave: (Date) -> Void
    @State private var editedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    init(currentDate: Date, onSave: @escaping (Date) -> Void) {
        self.currentDate = currentDate
        self.onSave = onSave
        self._editedDate = State(initialValue: currentDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker("Date", selection: $editedDate, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedDate)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

struct EditTimeView: View {
    let currentTime: Date?
    let hasTime: Bool
    let onSave: (Date, Bool) -> Void
    @State private var editedTime: Date
    @State private var hasTimeToggle: Bool
    @Environment(\.dismiss) private var dismiss
    
    init(currentTime: Date?, hasTime: Bool, onSave: @escaping (Date, Bool) -> Void) {
        self.currentTime = currentTime
        self.hasTime = hasTime
        self.onSave = onSave
        self._editedTime = State(initialValue: currentTime ?? Date())
        self._hasTimeToggle = State(initialValue: hasTime)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Toggle("Assign Time", isOn: $hasTimeToggle)
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                
                if hasTimeToggle {
                    DatePicker("Time", selection: $editedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedTime, hasTimeToggle)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

#Preview {
    let itemManager = ItemManager()
    ItemRowView(itemManager: itemManager, item: itemManager.items[0])
}
