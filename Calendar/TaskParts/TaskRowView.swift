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
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: time)
        
        if minutes == 0 {
            formatter.dateFormat = "h" // Just the hour
            let hour = formatter.string(from: time)
            formatter.dateFormat = "a" // Just AM/PM
            let period = formatter.string(from: time).lowercased()
            return "\(hour) \(period)" // Regular space between hour and am/pm
        } else {
            formatter.dateFormat = "h:mm" // Hour and minutes
            let hourMin = formatter.string(from: time)
            formatter.dateFormat = "a" // Just AM/PM
            let period = formatter.string(from: time).lowercased()
            return "\(hourMin) \(period)" // Regular space between time and am/pm
        }
    }
    
    var body: some View {
        Button(action: {
            showingTaskEditor = true
        }) {
            HStack(spacing: 12) {
                // Checkmark button (only when no time is assigned)
                if task.assignedTime == nil {
                    Button(action: {
                        taskManager.toggleTaskCompletion(task)
                    }) {
                        Image(systemName: task.isCompleted ? "checkmark.square" : "square")
                            .foregroundColor(task.isCompleted ? .green : .gray)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Task content - different styling based on whether it has time
                VStack(alignment: .leading, spacing: 4) {
                    if let _ = task.assignedTime {
                        // Task with time - add background with rounded corners
                        Text("\(timeString) \(task.title)")
                            .font(.custom("Mulish", size: 16))
                            .strikethrough(task.isCompleted)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color("Accent1").opacity(0.2))
                            )
                    } else {
                        // Task without time - no background
                        Text(task.title)
                            .font(.custom("Mulish", size: 16))
                            .strikethrough(task.isCompleted)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
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
