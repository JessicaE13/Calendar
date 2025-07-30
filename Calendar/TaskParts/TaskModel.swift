//
//  Task.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//

import Foundation

struct ChecklistItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var sortOrder: Int = 0
}

struct Task: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String = ""
    var isCompleted: Bool = false
    var assignedDate: Date
    var assignedTime: Date? = nil
    var sortOrder: Int = 0
    var checklist: [ChecklistItem] = []
    
    init(title: String, description: String = "", assignedDate: Date = Date(), assignedTime: Date? = nil, sortOrder: Int = 0) {
        self.title = title
        self.description = description
        self.assignedDate = Calendar.current.startOfDay(for: assignedDate)
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
                description: "Weekly standup with the product team to discuss project progress and upcoming deadlines.",
                assignedDate: today,
                assignedTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today),
                sortOrder: 0
            ),
            Task(
                title: "Yoga Class",
                description: "Beginner's yoga session at the local studio",
                assignedDate: today,
                assignedTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today),
                sortOrder: 1
            ),
            Task(
                title: "Groceries",
                description: "Weekly grocery shopping",
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
                description: "Annual checkup with Dr. Smith",
                assignedDate: dayAfterTomorrow,
                assignedTime: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: dayAfterTomorrow),
                sortOrder: 4
            )
        ]
        
        // Add sample checklist to groceries task
        if let groceryIndex = tasks.firstIndex(where: { $0.title == "Groceries" }) {
            tasks[groceryIndex].checklist = [
                ChecklistItem(title: "Milk", sortOrder: 0),
                ChecklistItem(title: "Bread", sortOrder: 1),
                ChecklistItem(title: "Eggs", sortOrder: 2),
                ChecklistItem(title: "Apples", isCompleted: true, sortOrder: 3)
            ]
        }
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
    
    func addChecklistItem(_ task: Task, title: String) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let newItem = ChecklistItem(
                title: title,
                sortOrder: tasks[index].checklist.count
            )
            tasks[index].checklist.append(newItem)
        }
    }
    
    func deleteChecklistItem(_ task: Task, item: ChecklistItem) {
        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[taskIndex].checklist.removeAll { $0.id == item.id }
            // Reorder remaining items
            for (index, _) in tasks[taskIndex].checklist.enumerated() {
                tasks[taskIndex].checklist[index].sortOrder = index
            }
        }
    }
    
    func toggleChecklistItemCompletion(_ task: Task, item: ChecklistItem) {
        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }),
           let itemIndex = tasks[taskIndex].checklist.firstIndex(where: { $0.id == item.id }) {
            tasks[taskIndex].checklist[itemIndex].isCompleted.toggle()
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
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        return tasks.filter { task in
            calendar.isDate(task.assignedDate, equalTo: targetDate, toGranularity: .day)
        }.sorted { task1, task2 in
            if let time1 = task1.assignedTime, let time2 = task2.assignedTime {
                return time1 < time2
            } else if task1.assignedTime != nil && task2.assignedTime == nil {
                return true
            } else if task1.assignedTime == nil && task2.assignedTime != nil {
                return false
            } else {
                return task1.sortOrder < task2.sortOrder
            }
        }
    }
}
