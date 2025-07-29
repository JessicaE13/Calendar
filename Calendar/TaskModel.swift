//
//  Task.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//

import Foundation

struct Task: Identifiable, Codable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
    var assignedDate: Date // Changed to store the full date
    var assignedTime: Date? = nil // This will store just the time component
    var sortOrder: Int = 0
    
    init(title: String, assignedDate: Date = Date(), assignedTime: Date? = nil, sortOrder: Int = 0) {
        self.title = title
        self.assignedDate = Calendar.current.startOfDay(for: assignedDate) // Normalize to start of day
        self.assignedTime = assignedTime
        self.sortOrder = sortOrder
    }
}

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    
    init() {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        
        // Sample tasks for demonstration with different dates
        self.tasks = [
            Task(
                title: "Team Meeting",
                assignedDate: today,
                assignedTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today),
                sortOrder: 0
            ),
            Task(
                title: "Yoga Class",
                assignedDate: today,
                assignedTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today),
                sortOrder: 1
            ),
            Task(
                title: "Groceries",
                assignedDate: tomorrow,
                sortOrder: 2
            ),
            Task(
                title: "Email and Inbox DMx",
                assignedDate: today,
                sortOrder: 3
            ),
            Task(
                title: "Doctor Appointment",
                assignedDate: dayAfterTomorrow,
                assignedTime: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: dayAfterTomorrow),
                sortOrder: 4
            )
        ]
    }
    
    func addTask(_ task: Task) {
        var newTask = task
        newTask.sortOrder = tasks.count
        tasks.append(newTask)
    }
    
    func deleteTask(_ task: Task) {
        tasks.removeAll { $0.id == task.id }
        reorderTasks()
    }
    
    func toggleTaskCompletion(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
        }
    }
    
    func updateTaskTime(_ task: Task, time: Date?) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].assignedTime = time
        }
    }
    
    func moveTask(from source: IndexSet, to destination: Int) {
        // Get the currently selected date to filter tasks properly
        // This method will need to be updated to work with the current date context
        tasks.move(fromOffsets: source, toOffset: destination)
        reorderTasks()
    }
    
    private func reorderTasks() {
        for (index, _) in tasks.enumerated() {
            tasks[index].sortOrder = index
        }
    }
    
    func tasksForDate(_ date: Date) -> [Task] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        return tasks.filter { task in
            calendar.isDate(task.assignedDate, equalTo: targetDate, toGranularity: .day)
        }.sorted { task1, task2 in
            // Sort by time first (if both have times), then by sort order
            if let time1 = task1.assignedTime, let time2 = task2.assignedTime {
                return time1 < time2
            } else if task1.assignedTime != nil && task2.assignedTime == nil {
                return true // Tasks with times come first
            } else if task1.assignedTime == nil && task2.assignedTime != nil {
                return false // Tasks without times come after
            } else {
                return task1.sortOrder < task2.sortOrder
            }
        }
    }
}
