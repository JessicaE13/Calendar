//
//  TaskListView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//

import SwiftUI

struct TaskListView: View {
    @ObservedObject var taskManager: TaskManager
    let selectedDate: Date
    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    
    private var tasksForSelectedDate: [Task] {
        taskManager.tasksForDate(selectedDate)
    }
    
    private var selectedDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDate(selectedDate, equalTo: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(), toGranularity: .day) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                // Task List
                if tasksForSelectedDate.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.square")
                            .font(.title)
                            .foregroundColor(.black.opacity(0.6))
                        
                        Text("No tasks for this day")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Text("Tap + to add a task")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(tasksForSelectedDate) { task in
                            TaskRowView(taskManager: taskManager, task: task)
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showingAddTask = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color("Accent1"))
                                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: showingAddTask)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(taskManager: taskManager, selectedDate: selectedDate, isPresented: $showingAddTask)
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        for index in offsets {
            let task = tasksForSelectedDate[index]
            taskManager.deleteTask(task)
        }
    }
}

struct AddTaskView: View {
    @ObservedObject var taskManager: TaskManager
    let selectedDate: Date // Add selectedDate parameter
    @Binding var isPresented: Bool
    @State private var taskTitle = ""
    @State private var hasTime = false
    @State private var selectedTime = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Title")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    TextField("Enter task description", text: $taskTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Assign Time", isOn: $hasTime)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    if hasTime {
                        DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add Task") {
                        let newTask = Task(
                            title: taskTitle,
                            assignedDate: selectedDate, // Use the selected date
                            assignedTime: hasTime ? selectedTime : nil,
                            sortOrder: taskManager.tasks.count
                        )
                        taskManager.addTask(newTask)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .padding()
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(400)])
    }
}

#Preview {
    let taskManager = TaskManager()
    TaskListView(taskManager: taskManager, selectedDate: Date())
}
