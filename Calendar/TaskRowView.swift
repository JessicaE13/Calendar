//
//  TaskRowView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//

import SwiftUI

struct TaskRowView: View {
    @ObservedObject var taskManager: TaskManager
    let task: Task
    @State private var showingTaskEditor = false
    
    private var timeString: String {
        guard let time = task.assignedTime else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var body: some View {
        Button(action: {
            showingTaskEditor = true
        }) {
            HStack(spacing: 12) {
                // Left side - Checkmark (only when no time is assigned)
                if task.assignedTime == nil {
                    // Show checkmark button when no time is assigned
                    Button(action: {
                        taskManager.toggleTaskCompletion(task)
                    }) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.isCompleted ? .green : .gray)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.custom("Mulish", size: 16))
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    // Show time below task name when time is assigned
                    if let _ = task.assignedTime {
                        Text(timeString)
                            .font(.custom("Mulish", size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingTaskEditor) {
            TaskEditorView(
                task: task,
                taskManager: taskManager,
                isPresented: $showingTaskEditor
            )
        }
    }
}

struct TaskEditorView: View {
    let task: Task
    @ObservedObject var taskManager: TaskManager
    @Binding var isPresented: Bool
    @State private var taskTitle: String
    @State private var hasTime: Bool
    @State private var selectedTime: Date
    @State private var selectedDate: Date // Add date picker state
    
    init(task: Task, taskManager: TaskManager, isPresented: Binding<Bool>) {
        self.task = task
        self.taskManager = taskManager
        self._isPresented = isPresented
        self._taskTitle = State(initialValue: task.title)
        self._hasTime = State(initialValue: task.assignedTime != nil)
        self._selectedTime = State(initialValue: task.assignedTime ?? Date())
        self._selectedDate = State(initialValue: task.assignedDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Title")
                        .font(.custom("Mulish", size: 16))
                        .fontWeight(.medium)
                    
                    TextField("Enter task description", text: $taskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.custom("Mulish", size: 16))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date")
                        .font(.custom("Mulish", size: 16))
                        .fontWeight(.medium)
                    
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Assign Time", isOn: $hasTime)
                        .font(.custom("Mulish", size: 16))
                        .fontWeight(.medium)
                    
                    if hasTime {
                        DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Delete") {
                        taskManager.deleteTask(task)
                        isPresented = false
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Button("Save") {
                        updateTask()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(500)]) // Increased height for date picker
    }
    
    private func updateTask() {
        if let index = taskManager.tasks.firstIndex(where: { $0.id == task.id }) {
            taskManager.tasks[index].title = taskTitle
            taskManager.tasks[index].assignedDate = Calendar.current.startOfDay(for: selectedDate)
            taskManager.tasks[index].assignedTime = hasTime ? selectedTime : nil
        }
    }
}

#Preview {
    let taskManager = TaskManager()
    TaskRowView(taskManager: taskManager, task: taskManager.tasks[0])
}
