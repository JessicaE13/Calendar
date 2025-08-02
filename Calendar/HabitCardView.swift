//
//  HabitCardView.swift
//  Calendar
//
//  Minimalistic habit tracking card for the main calendar view
//

import SwiftUI

struct HabitCardView: View {
    let selectedDate: Date
    @StateObject private var habitManager = HabitManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @State private var showingHabitManagement = false
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    private var completedCount: Int {
        habitManager.habits.filter { habit in
            habitManager.isHabitCompleted(habit, on: selectedDate)
        }.count
    }
    
    private var totalCount: Int {
        habitManager.habits.filter { $0.isActive }.count
    }
    
    private var progressPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    var body: some View {
        if !habitManager.habits.isEmpty {
            VStack(spacing: 0) {
                // Header with progress
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Habits")
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("\(completedCount) of \(totalCount) completed")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .trim(from: 0, to: progressPercentage)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green, Color.blue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(progressPercentage * 100))%")
                            .font(.system(size: 10))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .animation(.easeInOut(duration: 0.3), value: progressPercentage)
                    
                    // Manage button
                    Button(action: {
                        showingHabitManagement = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                            .foregroundColor(Color("Accent1"))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Habits list - one line each
                VStack(spacing: 0) {
                    ForEach(habitManager.habits.filter { $0.isActive }.sorted { $0.sortOrder < $1.sortOrder }) { habit in
                        HabitRowView(
                            habit: habit,
                            selectedDate: selectedDate,
                            habitManager: habitManager,
                            categoryManager: categoryManager
                        )
                        
                        if habit.id != habitManager.habits.filter({ $0.isActive }).last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .sheet(isPresented: $showingHabitManagement) {
                HabitManagementView(
                    habitManager: habitManager,
                    categoryManager: categoryManager,
                    isPresented: $showingHabitManagement
                )
            }
        }
    }
}

struct HabitRowView: View {
    let habit: Habit
    let selectedDate: Date
    @ObservedObject var habitManager: HabitManager
    @ObservedObject var categoryManager: CategoryManager
    
    private var isCompleted: Bool {
        habitManager.isHabitCompleted(habit, on: selectedDate)
    }
    
    private var categoryColor: Color {
        if let category = habit.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray.opacity(0.6)
    }
    
    private var currentStreak: Int {
        habitManager.getCurrentStreak(habit, as: selectedDate)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                habitManager.toggleHabitCompletion(habit, for: selectedDate)
            }
        }) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(isCompleted ? categoryColor : Color.gray.opacity(0.2))
                        .frame(width: 20, height: 20)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(isCompleted ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isCompleted)
                
                // Habit name
                Text(habit.name)
                    .font(.system(size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Streak indicator (only show if > 0)
                if currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        
                        Text("\(currentStreak)")
                            .font(.system(size: 10))
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Habit Management View
struct HabitManagementView: View {
    @ObservedObject var habitManager: HabitManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var showingAddHabit = false
    @State private var editingHabit: Habit?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if habitManager.habits.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.badge.xmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Habits")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create daily habits to track your progress")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Create Your First Habit") {
                            showingAddHabit = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("Accent1"))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Habits list
                    List {
                        ForEach(habitManager.habits.sorted { $0.sortOrder < $1.sortOrder }) { habit in
                            HabitManagementRowView(habit: habit, categoryManager: categoryManager) {
                                editingHabit = habit
                            }
                        }
                        .onDelete(perform: deleteHabits)
                        .onMove(perform: moveHabits)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Manage Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !habitManager.habits.isEmpty {
                            EditButton()
                        }
                        
                        Button(action: {
                            showingAddHabit = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView(
                habitManager: habitManager,
                categoryManager: categoryManager,
                isPresented: $showingAddHabit
            )
        }
        .sheet(item: $editingHabit) { habit in
            EditHabitView(
                habit: habit,
                habitManager: habitManager,
                categoryManager: categoryManager,
                isPresented: .init(
                    get: { editingHabit != nil },
                    set: { _ in editingHabit = nil }
                )
            )
        }
    }
    
    private func deleteHabits(offsets: IndexSet) {
        let sortedHabits = habitManager.habits.sorted { $0.sortOrder < $1.sortOrder }
        for index in offsets {
            let habit = sortedHabits[index]
            habitManager.deleteHabit(habit)
        }
    }
    
    private func moveHabits(from source: IndexSet, to destination: Int) {
        var sortedHabits = habitManager.habits.sorted { $0.sortOrder < $1.sortOrder }
        sortedHabits.move(fromOffsets: source, toOffset: destination)
        
        // Update sort orders
        for (index, habit) in sortedHabits.enumerated() {
            if let originalIndex = habitManager.habits.firstIndex(where: { $0.id == habit.id }) {
                habitManager.habits[originalIndex].sortOrder = index
                habitManager.updateHabit(habitManager.habits[originalIndex])
            }
        }
    }
}

struct HabitManagementRowView: View {
    let habit: Habit
    @ObservedObject var categoryManager: CategoryManager
    let onEdit: () -> Void
    
    private var categoryColor: Color {
        if let category = habit.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray
    }
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Category color indicator
                Circle()
                    .fill(categoryColor)
                    .frame(width: 16, height: 16)
                
                // Habit name
                Text(habit.name)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Active indicator
                if !habit.isActive {
                    Text("Inactive")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
                
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

// MARK: - Add/Edit Habit Views
struct AddHabitView: View {
    @ObservedObject var habitManager: HabitManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var habitName = ""
    @State private var selectedCategory: Category? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Habit Name")
                        .font(.headline)
                    
                    TextField("e.g., Drink 8 glasses of water", text: $habitName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                }
                
                CategoryPickerView(
                    selectedCategory: $selectedCategory,
                    categoryManager: categoryManager
                )
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add Habit") {
                        let newHabit = Habit(
                            name: habitName.trimmingCharacters(in: .whitespacesAndNewlines),
                            categoryID: selectedCategory?.id
                        )
                        habitManager.addHabit(newHabit)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("Accent1"))
                    .cornerRadius(8)
                    .disabled(habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(400)])
    }
}

struct EditHabitView: View {
    let habit: Habit
    @ObservedObject var habitManager: HabitManager
    @ObservedObject var categoryManager: CategoryManager
    @Binding var isPresented: Bool
    
    @State private var habitName: String
    @State private var selectedCategory: Category?
    @State private var isActive: Bool
    
    init(habit: Habit, habitManager: HabitManager, categoryManager: CategoryManager, isPresented: Binding<Bool>) {
        self.habit = habit
        self.habitManager = habitManager
        self.categoryManager = categoryManager
        self._isPresented = isPresented
        self._habitName = State(initialValue: habit.name)
        self._selectedCategory = State(initialValue: habit.getCategory(from: categoryManager))
        self._isActive = State(initialValue: habit.isActive)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Habit Name")
                        .font(.headline)
                    
                    TextField("Habit name", text: $habitName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                }
                
                CategoryPickerView(
                    selectedCategory: $selectedCategory,
                    categoryManager: categoryManager
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Active", isOn: $isActive)
                        .font(.headline)
                    
                    Text("Inactive habits won't appear in your daily list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Save Changes") {
                        var updatedHabit = habit
                        updatedHabit.name = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
                        updatedHabit.categoryID = selectedCategory?.id
                        updatedHabit.isActive = isActive
                        habitManager.updateHabit(updatedHabit)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color("Accent1"))
                    .cornerRadius(8)
                    .disabled(habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(450)])
    }
}

#Preview {
    @Previewable @State var selectedDate = Date()
    
    ZStack {
        BackgroundView()
        
        VStack {
            HabitCardView(selectedDate: selectedDate)
                .padding()
            Spacer()
        }
    }
}
