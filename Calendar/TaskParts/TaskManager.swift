////
////  TaskManager.swift
////  Calendar
////
////  Updated with CloudKit sync support
////
//
//import Foundation
//import CloudKit
//import Combine
//
//class TaskManager: ObservableObject {
//    @Published var tasks: [Task] = []
//    @Published var isLoading = false
//    @Published var errorMessage: String?
//    @Published var showingError = false
//    
//    private let cloudKitManager = CloudKitManager.shared
//    private var cancellables = Set<AnyCancellable>()
//    
//    init() {
//        setupCloudKitObservers()
//        loadTasks()
//    }
//    
//    private func setupCloudKitObservers() {
//        // Observe CloudKit account status
//        cloudKitManager.$isAccountAvailable
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] isAvailable in
//                if isAvailable {
//                    self?.syncWithCloudKit()
//                }
//            }
//            .store(in: &cancellables)
//    }
//    
//    // MARK: - Loading and Syncing
//    
//    private func loadTasks() {
//        // Load sample data if no CloudKit account
//        if !cloudKitManager.isAccountAvailable {
//            loadSampleTasks()
//            return
//        }
//        
//        syncWithCloudKit()
//    }
//    
//    private func loadSampleTasks() {
//        let calendar = Calendar.current
//        let today = Date()
//        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
//        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today
//        
//        // Sample tasks for demonstration with different dates
//        self.tasks = [
//            Task(
//                title: "Team Meeting",
//                description: "Weekly standup with the product team to discuss project progress and upcoming deadlines.",
//                assignedDate: today,
//                assignedTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today),
//                sortOrder: 0
//            ),
//            Task(
//                title: "Yoga Class",
//                description: "Beginner's yoga session at the local studio",
//                assignedDate: today,
//                assignedTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today),
//                sortOrder: 1
//            ),
//            Task(
//                title: "Groceries",
//                description: "Weekly grocery shopping",
//                assignedDate: tomorrow,
//                sortOrder: 2
//            ),
//            Task(
//                title: "Email and Inbox DMx",
//                assignedDate: today,
//                sortOrder: 3
//            ),
//            Task(
//                title: "Doctor Appointment",
//                description: "Annual checkup with Dr. Smith",
//                assignedDate: dayAfterTomorrow,
//                assignedTime: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: dayAfterTomorrow),
//                sortOrder: 4
//            )
//        ]
//        
//        // Add sample checklist to groceries task
//        if let groceryIndex = tasks.firstIndex(where: { $0.title == "Groceries" }) {
//            tasks[groceryIndex].checklist = [
//                ChecklistItem(title: "Milk", sortOrder: 0),
//                ChecklistItem(title: "Bread", sortOrder: 1),
//                ChecklistItem(title: "Eggs", sortOrder: 2),
//                ChecklistItem(title: "Apples", isCompleted: true, sortOrder: 3)
//            ]
//        }
//    }
//    
//    func syncWithCloudKit() {
//        isLoading = true
//        errorMessage = nil
//        
//        Task {
//            do {
//                let syncedTasks = try await cloudKitManager.syncTasks(localTasks: tasks)
//                
//                await MainActor.run {
//                    self.tasks = syncedTasks
//                    self.isLoading = false
//                }
//            } catch {
//                await MainActor.run {
//                    self.errorMessage = error.localizedDescription
//                    self.showingError = true
//                    self.isLoading = false
//                }
//            }
//        }
//    }
//    
//    // MARK: - Task Operations
//    
//    func addTask(_ task: Task) {
//        var newTask = task
//        newTask.sortOrder = tasks.count
//        newTask.lastModified = Date()
//        
//        tasks.append(newTask)
//        
//        // Save to CloudKit if available
//        if cloudKitManager.isAccountAvailable {
//            Task {
//                do {
//                    let savedTask = try await cloudKitManager.saveTask(newTask)
//                    await MainActor.run {
//                        if let index = self.tasks.firstIndex(where: { $0.id == newTask.id }) {
//                            self.tasks[index] = savedTask
//                        }
//                    }
//                } catch {
//                    await MainActor.run {
//                        self.errorMessage = "Failed to save task: \(error.localizedDescription)"
//                        self.showingError = true
//                    }
//                }
//            }
//        }
//    }
//    
//    func deleteTask(_ task: Task) {
//        tasks.removeAll { $0.id == task.id }
//        reorderTasks()
//        
//        // Delete from CloudKit if available
//        if cloudKitManager.isAccountAvailable, let recordID = task.recordID {
//            Task {
//                do {
//                    try await cloudKitManager.deleteTask(recordID: recordID)
//                } catch {
//                    await MainActor.run {
//                        self.errorMessage = "Failed to delete task: \(error.localizedDescription)"
//                        self.showingError = true
//                    }
//                }
//            }
//        }
//    }
//    
//    func toggleTaskCompletion(_ task: Task) {
//        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
//            tasks[index].isCompleted.toggle()
//            tasks[index].lastModified = Date()
//            
//            let updatedTask = tasks[index]
//            
//            // Save to CloudKit if available
//            if cloudKitManager.isAccountAvailable {
//                Task {
//                    do {
//                        let savedTask = try await cloudKitManager.saveTask(updatedTask)
//                        await MainActor.run {
//                            self.tasks[index] = savedTask
//                        }
//                    } catch {
//                        await MainActor.run {
//                            self.errorMessage = "Failed to update task: \(error.localizedDescription)"
//                            self.showingError = true
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    func updateTaskTime(_ task: Task, time: Date?) {
//        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
//            tasks[index].assignedTime = time
//            tasks[index].lastModified = Date()
//            
//            let updatedTask = tasks[index]
//            
//            // Save to CloudKit if available
//            if cloudKitManager.isAccountAvailable {
//                Task {
//                    do {
//                        let savedTask = try await cloudKitManager.saveTask(updatedTask)
//                        await MainActor.run {
//                            self.tasks[index] = savedTask
//                        }
//                    } catch {
//                        await MainActor.run {
//                            self.errorMessage = "Failed to update task: \(error.localizedDescription)"
//                            self.showingError = true
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Checklist Operations
//    
//    func addChecklistItem(_ task: Task, title: String) {
//        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
//            let newItem = ChecklistItem(
//                title: title,
//                sortOrder: tasks[index].checklist.count
//            )
//            tasks[index].checklist.append(newItem)
//            tasks[index].lastModified = Date()
//            
//            let updatedTask = tasks[index]
//            
//            // Save to CloudKit if available
//            if cloudKitManager.isAccountAvailable {
//                Task {
//                    do {
//                        // First save the task to get/update its record ID
//                        let savedTask = try await cloudKitManager.saveTask(updatedTask)
//                        
//                        // Then save the checklist item
//                        let savedItem = try await cloudKitManager.saveChecklistItem(newItem, for: savedTask)
//                        
//                        await MainActor.run {
//                            self.tasks[index] = savedTask
//                            if let itemIndex = self.tasks[index].checklist.firstIndex(where: { $0.id == newItem.id }) {
//                                self.tasks[index].checklist[itemIndex] = savedItem
//                            }
//                        }
//                    } catch {
//                        await MainActor.run {
//                            self.errorMessage = "Failed to save checklist item: \(error.localizedDescription)"
//                            self.showingError = true
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    func deleteChecklistItem(_ task: Task, item: ChecklistItem) {
//        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
//            tasks[taskIndex].checklist.removeAll { $0.id == item.id }
//            tasks[taskIndex].lastModified = Date()
//            
//            // Reorder remaining items
//            for (index, _) in tasks[taskIndex].checklist.enumerated() {
//                tasks[taskIndex].checklist[index].sortOrder = index
//            }
//            
//            let updatedTask = tasks[taskIndex]
//            
//            // Delete from CloudKit if available
//            if cloudKitManager.isAccountAvailable {
//                Task {
//                    do {
//                        // Delete the checklist item if it has a record ID
//                        if let recordID = item.recordID {
//                            try await cloudKitManager.deleteChecklistItem(recordID: recordID)
//                        }
//                        
//                        // Update the task
//                        let savedTask = try await cloudKitManager.saveTask(updatedTask)
//                        await MainActor.run {
//                            self.tasks[taskIndex] = savedTask
//                        }
//                    } catch {
//                        await MainActor.run {
//                            self.errorMessage = "Failed to delete checklist item: \(error.localizedDescription)"
//                            self.showingError = true
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    func toggleChecklistItemCompletion(_ task: Task, item: ChecklistItem) {
//        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }),
//           let itemIndex = tasks[taskIndex].checklist.firstIndex(where: { $0.id == item.id }) {
//            
//            tasks[taskIndex].checklist[itemIndex].isCompleted.toggle()
//            tasks[taskIndex].lastModified = Date()
//            
//            let updatedTask = tasks[taskIndex]
//            let updatedItem = tasks[taskIndex].checklist[itemIndex]
//            
//            // Save to CloudKit if available
//            if cloudKitManager.isAccountAvailable {
//                Task {
//                    do {
//                        // Save the checklist item
//                        let savedItem = try await cloudKitManager.saveChecklistItem(updatedItem, for: updatedTask)
//                        
//                        // Update the task
//                        let savedTask = try await cloudKitManager.saveTask(updatedTask)
//                        
//                        await MainActor.run {
//                            self.tasks[taskIndex] = savedTask
//                            self.tasks[taskIndex].checklist[itemIndex] = savedItem
//                        }
//                    } catch {
//                        await MainActor.run {
//                            self.errorMessage = "Failed to update checklist item: \(error.localizedDescription)"
//                            self.showingError = true
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    // MARK: - Utility Methods
//    
//    func moveTask(from source: IndexSet, to destination: Int) {
//        tasks.move(fromOffsets: source, toOffset: destination)
//        reorderTasks()
//    }
//    
//    private func reorderTasks() {
//        for (index, _) in tasks.enumerated() {
//            tasks[index].sortOrder = index
//            tasks[index].lastModified = Date()
//        }
//        
//        // Save reordered tasks to CloudKit if available
//        if cloudKitManager.isAccountAvailable {
//            Task {
//                for task in tasks {
//                    try? await cloudKitManager.saveTask(task)
//                }
//            }
//        }
//    }
//    
//    func tasksForDate(_ date: Date) -> [Task] {
//        let calendar = Calendar.current
//        let targetDate = calendar.startOfDay(for: date)
//        
//        return tasks.filter { task in
//            calendar.isDate(task.assignedDate, equalTo: targetDate, toGranularity: .day)
//        }.sorted { task1, task2 in
//            if let time1 = task1.assignedTime, let time2 = task2.assignedTime {
//                return time1 < time2
//            } else if task1.assignedTime != nil && task2.assignedTime == nil {
//                return true
//            } else if task1.assignedTime == nil && task2.assignedTime != nil {
//                return false
//            } else {
//                return task1.sortOrder < task2.sortOrder
//            }
//        }
//    }
//    
//    // MARK: - Manual Sync
//    
//    func refreshFromCloudKit() {
//        syncWithCloudKit()
//    }
//}
