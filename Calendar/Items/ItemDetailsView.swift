//
//  ItemDetailsView.swift
//  Calendar
//
//  Complete version with category selection support
//

import SwiftUI

struct ItemDetailsView: View {
    let item: Item
    @ObservedObject var itemManager: ItemManager
    @Binding var isPresented: Bool
    
    // Category manager
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingCategoryManagement = false
    
    // Individual field editing states
    @State private var isEditingTitle = false
    @State private var isEditingDescription = false
    @State private var isEditingTime = false
    @State private var isEditingRecurrence = false
    @State private var isEditingCategory = false
    
    @State private var editedTitle = ""
    @State private var editedDescriptionLines: [RichTextLine] = []
    @State private var editedTime = Date()
    @State private var hasTime = false
    @State private var showingAddChecklistItem = false
    @State private var newChecklistItemTitle = ""
    @State private var editedChecklist: [ChecklistItem] = []
    @State private var editedCategory: Category? = nil
    
    // Recurring pattern editing states
    @State private var editedRecurrencePattern = RecurrencePattern()
    @State private var showingRecurrenceOptions = false
    
    // Add focus states for better control
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var timeFieldFocused: Bool
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let dateToFormat = item.assignedDate
        
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
    
    private var categoryDisplayText: String {
        if isEditingCategory {
            return editedCategory?.name ?? "None"
        } else {
            return item.getCategory(from: categoryManager)?.name ?? "None"
        }
    }
    
    private var categoryDisplayColor: Color {
        if isEditingCategory {
            return editedCategory?.color.swiftUIColor ?? Color.gray
        } else {
            return item.getCategory(from: categoryManager)?.color.swiftUIColor ?? Color.gray
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
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
                        }
                        
                        // Item Name Section
                        if isEditingTitle {
                            HStack(spacing: 12) {
                                TextField("Item name", text: $editedTitle)
                                    .font(.system(size: 20))
                                    .fontWeight(.medium)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($titleFieldFocused)
                                    .onSubmit {
                                        saveTitle()
                                    }
                                
                                // Save/Cancel buttons on the right
                                HStack(spacing: 8) {
                                    Button(action: saveTitle) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: cancelTitleEdit) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.red)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        } else {
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
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    startEditingTitle()
                                }
                        }
                        
                        // Category Section
                        if isEditingCategory {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Category")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Button("Manage") {
                                        showingCategoryManagement = true
                                    }
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("Accent1"))
                                    
                                    Button(action: saveCategory) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: cancelCategoryEdit) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.red)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                CategoryPickerView(
                                    selectedCategory: $editedCategory,
                                    categoryManager: categoryManager
                                )
                            }
                        } else {
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(categoryDisplayColor)
                                        .frame(width: 12, height: 12)
                                        .opacity(item.categoryID != nil ? 1.0 : 0.3)
                                    
                                    Text(categoryDisplayText)
                                        .font(.system(size: 18))
                                        .foregroundColor(item.categoryID != nil ? .primary : .secondary)
                                }
                                
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
                                startEditingCategory()
                            }
                        }
                        
                        // Description Section
                        if isEditingDescription {
                            VStack(alignment: .leading, spacing: 12) {
                                RichTextEditor(
                                    lines: $editedDescriptionLines,
                                    onSave: saveDescription,
                                    onCancel: cancelDescriptionEdit
                                )
                            }
                        } else {
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
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.5))
                                .cornerRadius(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Legacy Checklist Section (for backward compatibility)
                        if !item.checklist.isEmpty {
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
                        }
                        
                        // Date Section - Direct DatePicker
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { item.assignedDate },
                                    set: { newDate in
                                        itemManager.updateItemDate(item, newDate: newDate)
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .font(.system(size: 18))
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .accentColor(.clear)
                            .colorScheme(.light)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        
                        // Time Section
                        if isEditingTime {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Toggle("Assign Time", isOn: $hasTime)
                                        .font(.system(size: 16))
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Button(action: saveTime) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: cancelTimeEdit) {
                                        Image(systemName: "xmark")
                                            .foregroundColor(.red)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                if hasTime {
                                    DatePicker("Time", selection: $editedTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .font(.system(size: 18))
                                        .focused($timeFieldFocused)
                                }
                            }
                        } else {
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
                        }
                        
                        // Recurrence Section (only show for non-instances or when editing)
                        if !item.isRecurringInstance {
                            if isEditingRecurrence {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Spacer()
                                        
                                        Button(action: saveRecurrence) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: cancelRecurrenceEdit) {
                                            Image(systemName: "xmark")
                                                .foregroundColor(.red)
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    
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
                                }
                            } else {
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
                            }
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
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(
                categoryManager: categoryManager,
                isPresented: $showingCategoryManagement
            )
        }
    }
    
    // MARK: - Individual Field Editing Methods
    
    private func setupEditableValues() {
        editedTitle = item.title
        editedTime = item.assignedTime ?? Date()
        hasTime = item.assignedTime != nil
        editedChecklist = item.checklist
        editedRecurrencePattern = item.recurrencePattern
        editedCategory = item.getCategory(from: categoryManager)
        
        // Convert description to rich text lines
        if item.description.isEmpty {
            editedDescriptionLines = []
        } else {
            editedDescriptionLines = [RichTextLine].fromDescriptionString(item.description)
        }
    }
    
    private func startEditingTitle() {
        editedTitle = item.title
        isEditingTitle = true
        
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
    
    private func startEditingCategory() {
        editedCategory = item.getCategory(from: categoryManager)
        isEditingCategory = true
    }
    
    private func saveCategory() {
        itemManager.updateItemCategory(item, category: editedCategory)
        isEditingCategory = false
    }
    
    private func cancelCategoryEdit() {
        editedCategory = item.getCategory(from: categoryManager)
        isEditingCategory = false
    }
    
    private func startEditingDescription() {
        if item.description.isEmpty {
            editedDescriptionLines = []
        } else {
            editedDescriptionLines = [RichTextLine].fromDescriptionString(item.description)
        }
        
        withAnimation(.none) {
            isEditingDescription = true
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

// MARK: - Preview
#Preview {
    @Previewable @State var isPresented = true
    
    // Create a sample item with various content
    let sampleItem = {
        var item = Item(
            title: "Team Meeting",
            description: "• Review quarterly goals\n☐ Prepare presentation\n☑ Send meeting notes",
            assignedDate: Date(),
            assignedTime: Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date()),
            sortOrder: 0
        )
        item.recurrencePattern = RecurrencePattern(frequency: .weekly, interval: 1)
        return item
    }()
    
    // Create a sample ItemManager
    let sampleManager = ItemManager()
    
    return ItemDetailsView(
        item: sampleItem,
        itemManager: sampleManager,
        isPresented: $isPresented
    )
}
