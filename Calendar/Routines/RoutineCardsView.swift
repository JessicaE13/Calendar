//
//  RoutineCardsView.swift
//  Calendar
//
//  Morning and Evening routine cards with progress tracking
//

import SwiftUI

struct RoutineCardsView: View {
    let selectedDate: Date
    @StateObject private var routineManager = RoutineManager.shared
    @State private var showingRoutineDetail: DailyRoutineProgress?
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(RoutineType.allCases, id: \.self) { routineType in
                RoutineCardView(
                    routineType: routineType,
                    selectedDate: selectedDate,
                    routineManager: routineManager
                ) {
                    showingRoutineDetail = routineManager.getProgress(for: selectedDate, type: routineType)
                }
                .frame(maxWidth: .infinity) // Equal width for both cards
            }
        }
        .onAppear {
            // Create today's progress if needed
            for routineType in RoutineType.allCases {
                routineManager.createProgressIfNeeded(for: selectedDate, type: routineType)
            }
        }
        .onChange(of: selectedDate) {
            // Create progress for new date if needed
            for routineType in RoutineType.allCases {
                routineManager.createProgressIfNeeded(for: selectedDate, type: routineType)
            }
        }
        .sheet(item: $showingRoutineDetail) { progress in
            RoutineDetailView(
                progress: progress,
                routineManager: routineManager,
                isPresented: .init(
                    get: { showingRoutineDetail != nil },
                    set: { _ in showingRoutineDetail = nil }
                )
            )
        }
    }
}

struct RoutineCardView: View {
    let routineType: RoutineType
    let selectedDate: Date
    @ObservedObject var routineManager: RoutineManager
    let onTap: () -> Void
    
    private var progress: DailyRoutineProgress? {
        return routineManager.getProgress(for: selectedDate, type: routineType)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    // Shorter text for compact display
    private var shortTitle: String {
        switch routineType {
        case .morning: return "Morning"
        case .evening: return "Evening"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: routineType.gradientColors),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: routineType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                
                // Content - with more flexible layout
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(shortTitle)
                            .font(.system(size: 14))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer(minLength: 2)
                        
                        if let progress = progress {
                            // Completion status
                            if progress.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                            } else {
                                Text("\(progress.completedItemsCount)/\(progress.totalItemsCount)")
                                    .font(.system(size: 11))
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let progress = progress {
                        // Progress bar and info
                        HStack(spacing: 6) {
                            ProgressView(value: progress.progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(x: 1, y: 1.0, anchor: .center)
                                .tint(routineType.gradientColors.first)
                                .frame(maxWidth: .infinity)
                            
                            // Progress percentage and time in compact format
                            HStack(spacing: 4) {
                                Text("\(Int(progress.progressPercentage * 100))%")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                
                                // Time information
                                if progress.isCompleted, let completionTime = progress.completionTime,
                                   let startTime = progress.startTime {
                                    let duration = Int(completionTime.timeIntervalSince(startTime) / 60)
                                    Text("\(duration)m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                } else {
                                    Text("\(progress.estimatedTotalMinutes)m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        // No progress yet
                        HStack(spacing: 6) {
                            ProgressView(value: 0.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(x: 1, y: 1.0, anchor: .center)
                                .tint(Color.gray.opacity(0.3))
                                .frame(maxWidth: .infinity)
                            
                            HStack(spacing: 4) {
                                Text("0%")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                
                                if let template = routineManager.templates.first(where: { $0.routineType == routineType }) {
                                    Text("\(template.items.reduce(0) { $0 + $1.estimatedMinutes })m")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(height: 60) // Slightly reduced height
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.clear.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                progress?.isCompleted == true
                                    ? Color.green.opacity(0.3)
                                    : Color.gray.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(progress?.isCompleted == true ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: progress?.isCompleted)
    }
}

// MARK: - Main Routine Detail View (Simplified)
struct RoutineDetailView: View {
    let progress: DailyRoutineProgress
    @ObservedObject var routineManager: RoutineManager
    @Binding var isPresented: Bool
    
    @State private var showingTemplateEditor = false
    @State private var items: [RoutineItem] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with progress overview
                RoutineDetailHeader(progress: progress)
                
                // Draggable items list
                RoutineItemsList(
                    items: $items,
                    progress: progress,
                    routineManager: routineManager,
                    onItemsReordered: handleItemsReordered
                )
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingTemplateEditor = true
                    }
                }
            }
            .onAppear {
                loadItems()
            }
            .onChange(of: progress.items) {
                          loadItems()
                      }
        }
        .sheet(isPresented: $showingTemplateEditor) {
            if let template = routineManager.templates.first(where: { $0.routineType == progress.routineType }) {
                RoutineTemplateEditor(
                    template: template,
                    routineManager: routineManager,
                    isPresented: $showingTemplateEditor
                )
            }
        }
    }
    
    private func loadItems() {
        items = progress.items.sorted { $0.sortOrder < $1.sortOrder }
        print("📋 Loaded \(items.count) items for routine")
    }
    
    private func handleItemsReordered(_ reorderedItems: [RoutineItem]) {
        items = reorderedItems
        
        // Update the actual progress data
        if let progressIndex = routineManager.dailyProgress.firstIndex(where: { $0.id == progress.id }) {
            for item in items {
                if let itemIndex = routineManager.dailyProgress[progressIndex].items.firstIndex(where: { $0.id == item.id }) {
                    routineManager.dailyProgress[progressIndex].items[itemIndex].sortOrder = item.sortOrder
                }
            }
            
            routineManager.dailyProgress[progressIndex].lastModified = Date()
            routineManager.objectWillChange.send()
            
            // Update template consistency and sync to CloudKit
            syncChangesToCloudKit()
        }
    }
    
    private func syncChangesToCloudKit() {
        guard let progressIndex = routineManager.dailyProgress.firstIndex(where: { $0.id == progress.id }) else { return }
        
        let updatedProgress = routineManager.dailyProgress[progressIndex]
        
        Task {
            do {
                _ = try await CloudKitManager.shared.saveDailyRoutineProgress(updatedProgress)
                
                if let template = routineManager.templates.first(where: { $0.routineType == progress.routineType }) {
                    _ = try await CloudKitManager.shared.saveRoutineTemplate(template)
                }
                
                print("✅ Successfully synced reordered items to CloudKit")
            } catch {
                print("❌ Failed to sync to CloudKit: \(error)")
            }
        }
    }
}

// MARK: - Routine Detail Header Component
struct RoutineDetailHeader: View {
    let progress: DailyRoutineProgress
    
    private var timeInfo: String {
        if let startTime = progress.startTime, let completionTime = progress.completionTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let duration = Int(completionTime.timeIntervalSince(startTime) / 60)
            return "Completed in \(duration) minutes (\(formatter.string(from: startTime)) - \(formatter.string(from: completionTime)))"
        } else if let startTime = progress.startTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Started at \(formatter.string(from: startTime))"
        } else {
            return "Not started yet"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon and title
            RoutineHeaderTitle(
                routineType: progress.routineType,
                timeInfo: timeInfo
            )
            
            // Progress overview
            RoutineProgressOverview(progress: progress)
        }
        .padding(20)
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Routine Header Title Component
struct RoutineHeaderTitle: View {
    let routineType: RoutineType
    let timeInfo: String
    
    var body: some View {
        HStack {
            RoutineIconView(
                routineType: routineType,
                size: 60
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(routineType.displayName)
                    .font(.system(size: 24))
                    .fontWeight(.bold)
                
                Text(timeInfo)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Routine Icon Component (Reusable)
struct RoutineIconView: View {
    let routineType: RoutineType
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: routineType.gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Image(systemName: routineType.icon)
                .font(.system(size: size * 0.45))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Routine Progress Overview Component
struct RoutineProgressOverview: View {
    let progress: DailyRoutineProgress
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(progress.completedItemsCount) of \(progress.totalItemsCount) completed")
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(progress.progressPercentage * 100))%")
                    .font(.system(size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(progress.routineType.gradientColors.first)
            }
            
            ProgressView(value: progress.progressPercentage)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .tint(progress.routineType.gradientColors.first)
        }
    }
}

// MARK: - Routine Items List Component
struct RoutineItemsList: View {
    @Binding var items: [RoutineItem]
    let progress: DailyRoutineProgress
    @ObservedObject var routineManager: RoutineManager
    let onItemsReordered: ([RoutineItem]) -> Void
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                RoutineItemRowView(
                    item: item,
                    progress: progress,
                    routineManager: routineManager
                )
            }
            .onMove(perform: moveItems)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(PlainListStyle())
        .environment(\.editMode, .constant(.active)) // Always enable drag mode
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        print("🔄 Moving items from \(source) to \(destination)")
        
        // Move in local array first
        items.move(fromOffsets: source, toOffset: destination)
        
        // Update sort orders
        for (index, item) in items.enumerated() {
            items[index].sortOrder = index
            print("📝 Updated \(item.title) sortOrder to \(index)")
        }
        
        // Notify parent about the change
        onItemsReordered(items)
    }
}

// MARK: - Routine Item Row Component
struct RoutineItemRowView: View {
    let item: RoutineItem
    let progress: DailyRoutineProgress
    @ObservedObject var routineManager: RoutineManager
    
    @State private var isCompleted: Bool
    
    init(item: RoutineItem, progress: DailyRoutineProgress, routineManager: RoutineManager) {
        self.item = item
        self.progress = progress
        self.routineManager = routineManager
        self._isCompleted = State(initialValue: item.isCompleted)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompleted.toggle()
            }
            routineManager.toggleRoutineItem(progress.id, itemID: item.id)
        }) {
            HStack(spacing: 16) {
                // Checkbox
                RoutineItemCheckbox(
                    isCompleted: isCompleted,
                    size: 28
                )
                
                // Content
                RoutineItemContent(
                    title: item.title,
                    estimatedMinutes: item.estimatedMinutes,
                    isCompleted: isCompleted
                )
                
                Spacer()
                
                // Drag indicator (automatically added by List when in edit mode)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: item.isCompleted) { oldValue, newValue in
            if isCompleted != newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompleted = newValue
                }
            }
        }
        .onAppear {
            isCompleted = item.isCompleted
        }
    }
}

// MARK: - Routine Item Checkbox Component
struct RoutineItemCheckbox: View {
    let isCompleted: Bool
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green : Color.gray.opacity(0.2))
                .frame(width: size, height: size)
                .scaleEffect(isCompleted ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isCompleted)
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// MARK: - Routine Item Content Component
struct RoutineItemContent: View {
    let title: String
    let estimatedMinutes: Int
    let isCompleted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16))
                .fontWeight(.medium)
                .foregroundColor(isCompleted ? .secondary : .primary)
                .strikethrough(isCompleted)
                .animation(.easeInOut(duration: 0.2), value: isCompleted)
            
            Text("\(estimatedMinutes) min")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Simplified Template Editor Component
struct RoutineTemplateEditor: View {
    @State private var template: RoutineTemplate
    @ObservedObject var routineManager: RoutineManager
    @Binding var isPresented: Bool
    
    @State private var showingAddItem = false
    
    init(template: RoutineTemplate, routineManager: RoutineManager, isPresented: Binding<Bool>) {
        self._template = State(initialValue: template)
        self.routineManager = routineManager
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                TemplateEditorHeader(template: template)
                
                // Items list
                TemplateItemsList(
                    template: $template,
                    routineManager: routineManager
                )
            }
            .navigationTitle("Edit \(template.routineType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        EditButton()
                        
                        Button(action: {
                            showingAddItem = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddRoutineItemView(
                template: $template,
                routineManager: routineManager,
                isPresented: $showingAddItem
            )
        }
    }
}

// MARK: - Template Editor Header
struct TemplateEditorHeader: View {
    let template: RoutineTemplate
    
    private var totalTime: Int {
        template.items.reduce(0) { $0 + $1.estimatedMinutes }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                RoutineIconView(
                    routineType: template.routineType,
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.routineType.displayName)
                        .font(.headline)
                    
                    Text("\(template.items.count) items • \(totalTime) min total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Template Items List
struct TemplateItemsList: View {
    @Binding var template: RoutineTemplate
    @ObservedObject var routineManager: RoutineManager
    
    var body: some View {
        List {
            ForEach(template.items.sorted { $0.sortOrder < $1.sortOrder }) { item in
                TemplateItemRow(item: item)
            }
            .onDelete(perform: deleteItems)
            .onMove(perform: moveItems)
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let sortedItems = template.items.sorted { $0.sortOrder < $1.sortOrder }
            if index < sortedItems.count {
                let itemToDelete = sortedItems[index]
                template.items.removeAll { $0.id == itemToDelete.id }
            }
        }
        reorderItems()
        routineManager.updateTemplate(template)
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        var sortedItems = template.items.sorted { $0.sortOrder < $1.sortOrder }
        sortedItems.move(fromOffsets: source, toOffset: destination)
        
        // Update the template with reordered items
        for (index, item) in sortedItems.enumerated() {
            if let originalIndex = template.items.firstIndex(where: { $0.id == item.id }) {
                template.items[originalIndex].sortOrder = index
            }
        }
        
        routineManager.updateTemplate(template)
    }
    
    private func reorderItems() {
        let sortedItems = template.items.sorted { $0.sortOrder < $1.sortOrder }
        for (index, item) in sortedItems.enumerated() {
            if let originalIndex = template.items.firstIndex(where: { $0.id == item.id }) {
                template.items[originalIndex].sortOrder = index
            }
        }
    }
}

// MARK: - Template Item Row
struct TemplateItemRow: View {
    let item: RoutineItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16))
                
                Text("\(item.estimatedMinutes) min")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Routine Item View
struct AddRoutineItemView: View {
    @Binding var template: RoutineTemplate
    @ObservedObject var routineManager: RoutineManager
    @Binding var isPresented: Bool
    
    @State private var newItemTitle = ""
    @State private var newItemMinutes = 5
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Title")
                        .font(.headline)
                    
                    TextField("e.g., Brush teeth, Exercise", text: $newItemTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Estimated Time")
                        .font(.headline)
                    
                    HStack {
                        TextField("Minutes", value: $newItemMinutes, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        Text("minutes")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add Item") {
                        let newItem = RoutineItem(
                            title: newItemTitle,
                            estimatedMinutes: newItemMinutes,
                            sortOrder: template.items.count
                        )
                        template.items.append(newItem)
                        routineManager.updateTemplate(template)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("Accent1"))
                    .cornerRadius(8)
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Add Routine Item")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(300)])
    }
}
struct SimpleRoutineItemRow: View {
    let item: RoutineItem
    let progress: DailyRoutineProgress
    @ObservedObject var routineManager: RoutineManager
    
    @State private var isCompleted: Bool
    
    init(item: RoutineItem, progress: DailyRoutineProgress, routineManager: RoutineManager) {
        self.item = item
        self.progress = progress
        self.routineManager = routineManager
        self._isCompleted = State(initialValue: item.isCompleted)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompleted.toggle()
            }
            routineManager.toggleRoutineItem(progress.id, itemID: item.id)
        }) {
            HStack(spacing: 16) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .scaleEffect(isCompleted ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isCompleted)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)
                        .animation(.easeInOut(duration: 0.2), value: isCompleted)
                    
                    Text("\(item.estimatedMinutes) min")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Drag indicator (automatically added by List when in edit mode)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: item.isCompleted) { oldValue, newValue in
            if isCompleted != newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompleted = newValue
                }
            }
        }
        .onAppear {
            isCompleted = item.isCompleted
        }
    }
}
struct RoutineItemRow: View {
    let item: RoutineItem
    let progress: DailyRoutineProgress
    @ObservedObject var routineManager: RoutineManager
    
    // Add local state to track the completion status for immediate feedback
    @State private var isCompleted: Bool
    
    // Initialize with the current completion state
    init(item: RoutineItem, progress: DailyRoutineProgress, routineManager: RoutineManager) {
        self.item = item
        self.progress = progress
        self.routineManager = routineManager
        self._isCompleted = State(initialValue: item.isCompleted)
    }
    
    var body: some View {
        Button(action: {
            // Update local state immediately for instant visual feedback
            withAnimation(.easeInOut(duration: 0.2)) {
                isCompleted.toggle()
            }
            
            // Then update the actual data
            routineManager.toggleRoutineItem(progress.id, itemID: item.id)
        }) {
            HStack(spacing: 16) {
                // Checkbox with immediate visual feedback
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .scaleEffect(isCompleted ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isCompleted)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Content with immediate visual updates
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)
                        .animation(.easeInOut(duration: 0.2), value: isCompleted)
                    
                    Text("\(item.estimatedMinutes) min")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: item.isCompleted) { oldValue, newValue in
            // Sync local state with actual data when it changes
            if isCompleted != newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompleted = newValue
                }
            }
        }
        .onAppear {
            // Ensure local state matches item state when view appears
            isCompleted = item.isCompleted
        }
    }
}


#Preview {
    @Previewable @State var selectedDate = Date()
    
    ZStack {
        BackgroundView()
        
        VStack {
            RoutineCardsView(selectedDate: selectedDate)
                .padding()
            Spacer()
        }
    }
}
