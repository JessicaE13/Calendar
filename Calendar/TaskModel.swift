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
    var assignedTime: Date? = nil
    var sortOrder: Int = 0
    
    init(title: String, assignedTime: Date? = nil, sortOrder: Int = 0) {
        self.title = title
        self.assignedTime = assignedTime
        self.sortOrder = sortOrder
    }
}

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    
    init() {
        // Sample tasks for demonstration
        self.tasks = [
            Task(title: "Team Meeting", assignedTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()), sortOrder: 0),
            Task(title: "Yoga Class", assignedTime: Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date()), sortOrder: 1),
            Task(title: "Groceries", sortOrder: 2),
            Task(title: "Email and Inbox DMx", sortOrder: 3)
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
        tasks.move(fromOffsets: source, toOffset: destination)
        reorderTasks()
    }
    
    private func reorderTasks() {
        for (index, _) in tasks.enumerated() {
            tasks[index].sortOrder = index
        }
    }
    
    func tasksForDate(_ date: Date) -> [Task] {
        // For now, return all tasks. You can modify this to filter by date
        return tasks.sorted { $0.sortOrder < $1.sortOrder }
    }
}
