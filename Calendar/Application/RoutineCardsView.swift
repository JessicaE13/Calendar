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
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
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

struct RoutineDetailView: View {
    let progress: DailyRoutineProgress
    @ObservedObject var routineManager: RoutineManager
    @Binding var isPresented: Bool
    
    @State private var showingTemplateEditor = false
    
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
        NavigationView {
            VStack(spacing: 0) {
                // Header with progress
                VStack(spacing: 16) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: progress.routineType.gradientColors),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: progress.routineType.icon)
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(progress.routineType.displayName)
                                .font(.system(size: 24))
                                .fontWeight(.bold)
                            
                            Text(timeInfo)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Progress overview
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
                .padding(20)
                .background(Color.gray.opacity(0.05))
                
                // Checklist
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(progress.items.sorted { $0.sortOrder < $1.sortOrder }) { item in
                            RoutineItemRow(
                                item: item,
                                progress: progress,
                                routineManager: routineManager
                            )
                            
                            if item.id != progress.items.last?.id {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Spacer()
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
}

struct RoutineItemRow: View {
    let item: RoutineItem
    let progress: DailyRoutineProgress
    @ObservedObject var routineManager: RoutineManager
    
    var body: some View {
        Button(action: {
            routineManager.toggleRoutineItem(progress.id, itemID: item.id)
        }) {
            HStack(spacing: 16) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(item.isCompleted ? Color.green : Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                    
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted)
                    
                    Text("\(item.estimatedMinutes) min")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if item.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RoutineTemplateEditor: View {
    @State private var template: RoutineTemplate
    @ObservedObject var routineManager: RoutineManager
    @Binding var isPresented: Bool
    
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    @State private var newItemMinutes = 5
    
    init(template: RoutineTemplate, routineManager: RoutineManager, isPresented: Binding<Bool>) {
        self._template = State(initialValue: template)
        self.routineManager = routineManager
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    ForEach(template.items.sorted { $0.sortOrder < $1.sortOrder }) { item in
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
                    .onDelete(perform: deleteItems)
                    .onMove(perform: moveItems)
                }
                .listStyle(PlainListStyle())
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
        .alert("Add Routine Item", isPresented: $showingAddItem) {
            TextField("Item title", text: $newItemTitle)
            TextField("Minutes", value: $newItemMinutes, format: .number)
            Button("Add") {
                if !newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let newItem = RoutineItem(
                        title: newItemTitle,
                        estimatedMinutes: newItemMinutes,
                        sortOrder: template.items.count
                    )
                    template.items.append(newItem)
                    routineManager.updateTemplate(template)
                    newItemTitle = ""
                    newItemMinutes = 5
                }
            }
            Button("Cancel", role: .cancel) {
                newItemTitle = ""
                newItemMinutes = 5
            }
        } message: {
            Text("Enter the details for the new routine item")
        }
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
