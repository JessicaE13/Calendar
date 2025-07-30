//
//  TaskModel.swift
//  Calendar
//
//  Updated with CloudKit support - Fixed version
//

import Foundation
import CloudKit

struct ChecklistItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var recordID: CKRecord.ID?
    var parentTaskRecordID: CKRecord.ID?
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, sortOrder
        // recordID and parentTaskRecordID are not encoded/decoded
    }
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
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    init(title: String, description: String = "", assignedDate: Date = Date(), assignedTime: Date? = nil, sortOrder: Int = 0) {
        self.title = title
        self.description = description
        self.assignedDate = Calendar.current.startOfDay(for: assignedDate)
        self.assignedTime = assignedTime
        self.sortOrder = sortOrder
        self.lastModified = Date()
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, title, description, isCompleted, assignedDate, assignedTime, sortOrder, checklist, lastModified
        // recordID is not encoded/decoded
    }
}

// CloudKit extensions
extension Task {
    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Task", recordID: recordID ?? CKRecord.ID())
        record["title"] = title
        record["taskDescription"] = description
        record["isCompleted"] = isCompleted ? 1 : 0
        record["assignedDate"] = assignedDate
        record["assignedTime"] = assignedTime
        record["sortOrder"] = sortOrder
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        return record
    }
    
    // Create from CloudKit record
    static func fromCKRecord(_ record: CKRecord) -> Task? {
        guard let title = record["title"] as? String,
              let assignedDate = record["assignedDate"] as? Date else {
            return nil
        }
        
        var task = Task(
            title: title,
            description: record["taskDescription"] as? String ?? "",
            assignedDate: assignedDate,
            assignedTime: record["assignedTime"] as? Date,
            sortOrder: record["sortOrder"] as? Int ?? 0
        )
        
        let isCompletedValue = record["isCompleted"] as? Int ?? 0
        task.isCompleted = isCompletedValue == 1
        task.recordID = record.recordID
        task.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            task.id = userID
        }
        
        return task
    }
}

extension ChecklistItem {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "ChecklistItem", recordID: recordID ?? CKRecord.ID())
        record["title"] = title
        record["isCompleted"] = isCompleted ? 1 : 0
        record["sortOrder"] = sortOrder
        record["userID"] = id.uuidString
        
        if let parentRecordID = parentTaskRecordID {
            record["parentTask"] = CKRecord.Reference(recordID: parentRecordID, action: .deleteSelf)
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> ChecklistItem? {
        guard let title = record["title"] as? String else {
            return nil
        }
        
        var item = ChecklistItem(
            title: title,
            sortOrder: record["sortOrder"] as? Int ?? 0
        )
        
        let isCompletedValue = record["isCompleted"] as? Int ?? 0
        item.isCompleted = isCompletedValue == 1
        item.recordID = record.recordID
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            item.id = userID
        }
        
        if let parentReference = record["parentTask"] as? CKRecord.Reference {
            item.parentTaskRecordID = parentReference.recordID
        }
        
        return item
    }
}

class TaskManager: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    private let cloudKitManager = CloudKitManager.shared
    
    init() {
        loadSampleTasks()
        setupCloudKitObservers()
    }
    
    private func setupCloudKitObservers() {
        // We'll implement CloudKit sync after fixing the basic structure
    }
    
    private func loadSampleTasks() {
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
