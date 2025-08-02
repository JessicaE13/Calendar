//
//  ItemRowView.swift
//  Calendar
//
//  Complete file with Rich Text Editor integration and recurring task support
//  FIXED VERSION - Improved field editing behavior to prevent double-tap issues
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
    
    private var showsRecurringIndicator: Bool {
        return item.isRecurringParent || item.isRecurringInstance
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
                            
                            // Recurring indicator
                            if showsRecurringIndicator {
                                Image(systemName: "repeat")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
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
                        HStack(spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 16))
                                .padding(.vertical, 8)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            
                            // Recurring indicator
                            if showsRecurringIndicator {
                                Image(systemName: "repeat")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
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

// MARK: - Item Details View with Rich Text Editor and Recurring Support

struct ItemDetailsView: View {
    let item: Item
    @ObservedObject var itemManager: ItemManager
    @Binding var isPresented: Bool
    
    // Individual field editing states
    @State private var isEditingTitle = false
    @State private var isEditingDescription = false
    @State private var isEditingDate = false
    @State private var isEditingTime = false
    @State private var isEditingRecurrence = false
    
    @State private var editedTitle = ""
    @State private var editedDescriptionLines: [RichTextLine] = []
    @State private var editedDate = Date()
    @State private var editedTime = Date()
    @State private var hasTime = false
    @State private var showingAddChecklistItem = false
    @State private var newChecklistItemTitle = ""
    @State private var editedChecklist: [ChecklistItem] = []
    
    // Recurring pattern editing states
    @State private var editedRecurrencePattern = RecurrencePattern()
    @State private var showingRecurrenceOptions = false
    
    // Add focus states for better control
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var timeFieldFocused: Bool
    @FocusState private var dateFieldFocused: Bool
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let dateToFormat = isEditingDate ? editedDate : item.assignedDate
        
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
        if isEditingTime {
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
    
    private var recurrenceDescription: String {
        let pattern = isEditingRecurrence ? editedRecurrencePattern : item.recurrencePattern
        
        if !pattern.isRecurring {
            return "Never"
        }
        
        let baseDescription = pattern.interval == 1 ? pattern.frequency.displayName : "Every \(pattern.interval) \(pattern.frequency.rawValue)s"
        
        var description = baseDescription
        
        if let endDate = pattern.endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            description += " until \(formatter.string(from: endDate))"
        } else if let maxOccurrences = pattern.maxOccurrences {
            description += " for \(maxOccurrences) times"
        }
        
        return description
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Recurring Task Info Banner (if applicable)
                        if item.isRecurringInstance {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.blue)
                                    Text("This is part of a recurring series")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                    Spacer()
                                }
                                Text("Changes will only affect this occurrence")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            
                            Divider()
                        }
                        
                        // FIXED: Item Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Name")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            if isEditingTitle {
                                VStack(spacing: 8) {
                                    TextField("Item name", text: $editedTitle)
                                        .font(.system(size: 20))
                                        .fontWeight(.medium)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .focused($titleFieldFocused)
                                        .onSubmit {
                                            saveTitle()
                                        }
                                    
                                    HStack {
                                        Button("Save") {
                                            saveTitle()
                                        }
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                        
                                        Button("Cancel") {
                                            cancelTitleEdit()
                                        }
                                        .foregroundColor(.secondary)
                                        
                                        Spacer()
                                    }
                                }
                            } else {
                                // Simplified button with better tap handling
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .font(.system(size: 20))
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.1))
                                        )
                                        .contentShape(Rectangle()) // Ensures entire area is tappable
                                        .onTapGesture {
                                            startEditingTitle()
                                        }
                                    
                                    Text("Tap to edit")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .opacity(0.7)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // FIXED: Description Section - Single tap to edit
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Description & Notes")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            if isEditingDescription {
                                VStack(alignment: .leading, spacing: 12) {
                                    RichTextEditor(lines: $editedDescriptionLines)
                                    
                                    HStack {
                                        Button("Save") {
                                            saveDescription()
                                        }
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                        
                                        Button("Cancel") {
                                            cancelDescriptionEdit()
                                        }
                                        .foregroundColor(.secondary)
                                        
                                        Spacer()
                                    }
                                }
                            } else {
                                // Simplified single-tap area for description
                                Button(action: {
                                    startEditingDescription()
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if editedDescriptionLines.isEmpty {
                                            Text("Add notes, meeting links, or create checklists...")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                                .italic()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            ForEach(editedDescriptionLines) { line in
                                                ReadOnlyRichTextLineView(line: line)
                                            }
                                        }
                                        
                                        Text("Tap to edit")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .opacity(0.7)
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
                        
                        // Legacy Checklist Section (for backward compatibility)
                        if !item.checklist.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Legacy Checklist")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(item.checklist.sorted { $0.sortOrder < $1.sortOrder }) { checklistItem in
                                        HStack(spacing: 8) {
                                            Button(action: {
                                                itemManager.toggleChecklistItemCompletion(item, checklistItem: checklistItem)
                                            }) {
                                                Image(systemName: checklistItem.isCompleted ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(checklistItem.isCompleted ? .green : .gray)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
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
                                
                                Divider()
                            }
                        }
                        
                        // FIXED: Date Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Date")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            if isEditingDate {
                                VStack(spacing: 8) {
                                    DatePicker("Date", selection: $editedDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .font(.system(size: 18))
                                        .focused($dateFieldFocused)
                                    
                                    HStack {
                                        Button("Save") {
                                            saveDate()
                                        }
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                        
                                        Button("Cancel") {
                                            cancelDateEdit()
                                        }
                                        .foregroundColor(.secondary)
                                        
                                        Spacer()
                                    }
                                }
                            } else {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.secondary)
                                        
                                        Text(formattedDate)
                                            .font(.system(size: 18))
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        startEditingDate()
                                    }
                                    
                                    Text("Tap to edit")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .opacity(0.7)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // FIXED: Time Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Time")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            
                            if isEditingTime {
                                VStack(alignment: .leading, spacing: 12) {
                                    Toggle("Assign Time", isOn: $hasTime)
                                        .font(.system(size: 16))
                                        .fontWeight(.medium)
                                    
                                    if hasTime {
                                        DatePicker("Time", selection: $editedTime, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .font(.system(size: 18))
                                            .focused($timeFieldFocused)
                                    }
                                    
                                    HStack {
                                        Button("Save") {
                                            saveTime()
                                        }
                                        .foregroundColor(.green)
                                        .fontWeight(.semibold)
                                        
                                        Button("Cancel") {
                                            cancelTimeEdit()
                                        }
                                        .foregroundColor(.secondary)
                                        
                                        Spacer()
                                    }
                                }
                            } else {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Image(systemName: item.assignedTime != nil ? "clock" : "clock.badge.xmark")
                                            .foregroundColor(.secondary)
                                        
                                        Text(formattedTime)
                                            .font(.system(size: 18))
                                            .foregroundColor(item.assignedTime != nil ? .primary : .secondary)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        startEditingTime()
                                    }
                                    
                                    Text("Tap to edit")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .opacity(0.7)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // FIXED: Recurrence Section (only show for non-instances or when editing)
                        if !item.isRecurringInstance {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Repeat")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                if isEditingRecurrence {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Button(action: {
                                            showingRecurrenceOptions = true
                                        }) {
                                            HStack {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .foregroundColor(.secondary)
                                                
                                                Text(recurrenceDescription)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.secondary)
                                                    .font(.system(size: 14))
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        HStack {
                                            Button("Save") {
                                                saveRecurrence()
                                            }
                                            .foregroundColor(.green)
                                            .fontWeight(.semibold)
                                            
                                            Button("Cancel") {
                                                cancelRecurrenceEdit()
                                            }
                                            .foregroundColor(.secondary)
                                            
                                            Spacer()
                                        }
                                    }
                                } else {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .foregroundColor(.secondary)
                                            
                                            Text(recurrenceDescription)
                                                .font(.system(size: 18))
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.1))
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            startEditingRecurrence()
                                        }
                                        
                                        Text("Tap to edit")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .opacity(0.7)
                                    }
                                }
                            }
                            
                            Divider()
                        }
                        
                        Spacer(minLength: 40)
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
            .onAppear {
                setupEditableValues()
            }
        }
        .presentationDetents([.height(700), .large])
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
        .sheet(isPresented: $showingRecurrenceOptions) {
            RecurrenceOptionsView(
                recurrencePattern: $editedRecurrencePattern,
                isPresented: $showingRecurrenceOptions
            )
        }
    }
    
    // MARK: - FIXED: Individual Field Editing Methods
    
    private func setupEditableValues() {
        editedTitle = item.title
        editedDate = item.assignedDate
        editedTime = item.assignedTime ?? Date()
        hasTime = item.assignedTime != nil
        editedChecklist = item.checklist
        editedRecurrencePattern = item.recurrencePattern
        
        // Convert description to rich text lines
        if item.description.isEmpty {
            editedDescriptionLines = []
        } else {
            editedDescriptionLines = [RichTextLine].fromDescriptionString(item.description)
        }
    }
    
    // FIXED: Title editing with immediate state change and focus
    private func startEditingTitle() {
        editedTitle = item.title
        isEditingTitle = true
        
        // Use a small delay to ensure the TextField appears before focusing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            titleFieldFocused = true
        }
    }
    
    private func saveTitle() {
        itemManager.updateItemName(item, newName: editedTitle)
        isEditingTitle = false
        titleFieldFocused = false
    }
    
    private func cancelTitleEdit() {
        editedTitle = item.title
        isEditingTitle = false
        titleFieldFocused = false
    }
    
    // FIXED: Description editing - more aggressive state change
    private func startEditingDescription() {
        // Immediately setup the description lines
        if item.description.isEmpty {
            editedDescriptionLines = []
        } else {
            editedDescriptionLines = [RichTextLine].fromDescriptionString(item.description)
        }
        
        // Force the state change immediately
        withAnimation(.none) {
            isEditingDescription = true
        }
        
        // Force a UI update
        DispatchQueue.main.async {
            // This ensures the view hierarchy updates
        }
    }
    
    private func saveDescription() {
        let newDescription = editedDescriptionLines.toDescriptionString()
        itemManager.updateItemDescription(item, newDescription: newDescription)
        isEditingDescription = false
    }
    
    private func cancelDescriptionEdit() {
        if item.description.isEmpty {
            editedDescriptionLines = []
        } else {
            editedDescriptionLines = [RichTextLine].fromDescriptionString(item.description)
        }
        isEditingDescription = false
    }
    
    // FIXED: Date editing with focus management
    private func startEditingDate() {
        editedDate = item.assignedDate
        isEditingDate = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            dateFieldFocused = true
        }
    }
    
    private func saveDate() {
        itemManager.updateItemDate(item, newDate: editedDate)
        isEditingDate = false
        dateFieldFocused = false
    }
    
    private func cancelDateEdit() {
        editedDate = item.assignedDate
        isEditingDate = false
        dateFieldFocused = false
    }
    
    // FIXED: Time editing with focus management
    private func startEditingTime() {
        editedTime = item.assignedTime ?? Date()
        hasTime = item.assignedTime != nil
        isEditingTime = true
        
        if hasTime {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                timeFieldFocused = true
            }
        }
    }
    
    private func saveTime() {
        itemManager.updateItemTime(item, time: hasTime ? editedTime : nil)
        isEditingTime = false
        timeFieldFocused = false
    }
    
    private func cancelTimeEdit() {
        editedTime = item.assignedTime ?? Date()
        hasTime = item.assignedTime != nil
        isEditingTime = false
        timeFieldFocused = false
    }
    
    // FIXED: Recurrence editing
    private func startEditingRecurrence() {
        editedRecurrencePattern = item.recurrencePattern
        isEditingRecurrence = true
    }
    
    private func saveRecurrence() {
        itemManager.updateRecurringPattern(item, pattern: editedRecurrencePattern)
        isEditingRecurrence = false
    }
    
    private func cancelRecurrenceEdit() {
        editedRecurrencePattern = item.recurrencePattern
        isEditingRecurrence = false
    }
}
