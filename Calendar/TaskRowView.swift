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
    @State private var showingTimePicker = false
    
    private var timeString: String {
        guard let time = task.assignedTime else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkmark button
            Button(action: {
                taskManager.toggleTaskCompletion(task)
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.custom("Mulish", size: 16))
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                if let _ = task.assignedTime {
                    Text(timeString)
                        .font(.custom("Mulish", size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Text("No time set")
                        .font(.custom("Mulish", size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            // Time assignment button
            Button(action: {
                showingTimePicker = true
            }) {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingTimePicker) {
            TimePickerView(
                task: task,
                taskManager: taskManager,
                isPresented: $showingTimePicker
            )
        }
    }
}

struct TimePickerView: View {
    let task: Task
    @ObservedObject var taskManager: TaskManager
    @Binding var isPresented: Bool
    @State private var selectedTime: Date
    
    init(task: Task, taskManager: TaskManager, isPresented: Binding<Bool>) {
        self.task = task
        self.taskManager = taskManager
        self._isPresented = isPresented
        self._selectedTime = State(initialValue: task.assignedTime ?? Date())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Set Time for Task")
                    .font(.title2)
                    .padding()
                
                DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                
                HStack(spacing: 16) {
                    Button("Remove Time") {
                        taskManager.updateTaskTime(task, time: nil)
                        isPresented = false
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    
                    Button("Save") {
                        taskManager.updateTaskTime(task, time: selectedTime)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
                .padding()
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(300)])
    }
}

#Preview {
    let taskManager = TaskManager()
    TaskRowView(taskManager: taskManager, task: taskManager.tasks[0])
}
