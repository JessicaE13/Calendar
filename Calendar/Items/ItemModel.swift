//
//  ItemModel.swift
//  Calendar
//
//  Enhanced with recurring task functionality
//

import Foundation
import CloudKit
import Combine

// MARK: - Recurrence Pattern

enum RecurrenceFrequency: String, CaseIterable, Codable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

struct RecurrencePattern: Codable {
    var frequency: RecurrenceFrequency = .none
    var interval: Int = 1 // Every X days/weeks/months/years
    var endDate: Date? = nil // When to stop recurring (optional)
    var maxOccurrences: Int? = nil // Max number of occurrences (optional)
    
    var isRecurring: Bool {
        return frequency != .none
    }
    
    init(frequency: RecurrenceFrequency = .none, interval: Int = 1, endDate: Date? = nil, maxOccurrences: Int? = nil) {
        self.frequency = frequency
        self.interval = interval
        self.endDate = endDate
        self.maxOccurrences = maxOccurrences
    }
}

// MARK: - ChecklistItem Model

struct ChecklistItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var recordID: CKRecord.ID?
    var parentItemRecordID: CKRecord.ID?
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, sortOrder
        // recordID and parentItemRecordID are not encoded/decoded
    }
}

// MARK: - Item Model (with recurring support)

struct Item: Identifiable, Codable {
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
    
    // Recurring task properties
    var recurrencePattern: RecurrencePattern = RecurrencePattern()
    var parentRecurringID: UUID? = nil // Links to the original recurring task
    var isRecurringParent: Bool = false // True for the original recurring task template
    var occurrenceDate: Date? = nil // For individual occurrences, which date they represent
    
    // Track if this item's order has been manually set for this date
    var hasCustomOrderForDate: [String: Bool] = [:] // dateString -> hasCustomOrder
    
    init(title: String, description: String = "", assignedDate: Date = Date(), assignedTime: Date? = nil, sortOrder: Int = 0) {
        self.title = title
        self.description = description
        self.assignedDate = Calendar.current.startOfDay(for: assignedDate)
        self.assignedTime = assignedTime
        self.sortOrder = sortOrder
        self.lastModified = Date()
    }
    
    // Helper properties for recurring tasks
    var isRecurring: Bool {
        return recurrencePattern.isRecurring
    }
    
    var isRecurringInstance: Bool {
        return parentRecurringID != nil
    }
    
    // Helper to get/set custom order flag for a specific date
    func hasCustomOrder(for date: Date) -> Bool {
        let dateKey = dateKey(for: date)
        return hasCustomOrderForDate[dateKey] ?? false
    }
    
    mutating func setCustomOrder(for date: Date, hasCustomOrder: Bool) {
        let dateKey = dateKey(for: date)
        hasCustomOrderForDate[dateKey] = hasCustomOrder
    }
    
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, title, description, isCompleted, assignedDate, assignedTime, sortOrder, checklist, lastModified, hasCustomOrderForDate
        case recurrencePattern, parentRecurringID, isRecurringParent, occurrenceDate
        // recordID is not encoded/decoded
    }
}

// MARK: - CloudKit Extensions

extension Item {
    // Convert to CloudKit record
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Item", recordID: recordID ?? CKRecord.ID())
        record["title"] = title
        record["itemDescription"] = description
        record["isCompleted"] = isCompleted ? 1 : 0
        record["assignedDate"] = assignedDate
        record["assignedTime"] = assignedTime
        record["sortOrder"] = sortOrder
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        
        // Recurring task fields
        record["isRecurringParent"] = isRecurringParent ? 1 : 0
        record["parentRecurringID"] = parentRecurringID?.uuidString
        record["occurrenceDate"] = occurrenceDate
        
        // Convert checklist to JSON data for storage
        if !checklist.isEmpty {
            do {
                let checklistData = try JSONEncoder().encode(checklist)
                record["checklist"] = checklistData
            } catch {
                print("Failed to encode checklist: \(error)")
            }
        }
        
        // Store custom order data
        do {
            let customOrderData = try JSONEncoder().encode(hasCustomOrderForDate)
            record["customOrderData"] = customOrderData
        } catch {
            print("Failed to encode custom order data: \(error)")
        }
        
        // Store recurrence pattern
        do {
            let recurrenceData = try JSONEncoder().encode(recurrencePattern)
            record["recurrencePattern"] = recurrenceData
        } catch {
            print("Failed to encode recurrence pattern: \(error)")
        }
        
        return record
    }
    
    // Create from CloudKit record
    static func fromCKRecord(_ record: CKRecord) -> Item? {
        guard let title = record["title"] as? String,
              let assignedDate = record["assignedDate"] as? Date else {
            return nil
        }
        
        var item = Item(
            title: title,
            description: record["itemDescription"] as? String ?? "",
            assignedDate: assignedDate,
            assignedTime: record["assignedTime"] as? Date,
            sortOrder: record["sortOrder"] as? Int ?? 0
        )
        
        let isCompletedValue = record["isCompleted"] as? Int ?? 0
        item.isCompleted = isCompletedValue == 1
        item.recordID = record.recordID
        item.lastModified = record["lastModified"] as? Date ?? Date()
        
        // Recurring task fields
        let isRecurringParentValue = record["isRecurringParent"] as? Int ?? 0
        item.isRecurringParent = isRecurringParentValue == 1
        
        if let parentIDString = record["parentRecurringID"] as? String {
            item.parentRecurringID = UUID(uuidString: parentIDString)
        }
        
        item.occurrenceDate = record["occurrenceDate"] as? Date
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            item.id = userID
        }
        
        // Decode checklist from JSON data
        if let checklistData = record["checklist"] as? Data {
            do {
                item.checklist = try JSONDecoder().decode([ChecklistItem].self, from: checklistData)
            } catch {
                print("Failed to decode checklist: \(error)")
                item.checklist = []
            }
        }
        
        // Decode custom order data
        if let customOrderData = record["customOrderData"] as? Data {
            do {
                item.hasCustomOrderForDate = try JSONDecoder().decode([String: Bool].self, from: customOrderData)
            } catch {
                print("Failed to decode custom order data: \(error)")
                item.hasCustomOrderForDate = [:]
            }
        }
        
        // Decode recurrence pattern
        if let recurrenceData = record["recurrencePattern"] as? Data {
            do {
                item.recurrencePattern = try JSONDecoder().decode(RecurrencePattern.self, from: recurrenceData)
            } catch {
                print("Failed to decode recurrence pattern: \(error)")
                item.recurrencePattern = RecurrencePattern()
            }
        }
        
        return item
    }
}

extension ChecklistItem {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "ChecklistItem", recordID: recordID ?? CKRecord.ID())
        record["title"] = title
        record["isCompleted"] = isCompleted ? 1 : 0
        record["sortOrder"] = sortOrder
        record["userID"] = id.uuidString
        
        if let parentRecordID = parentItemRecordID {
            record["parentItem"] = CKRecord.Reference(recordID: parentRecordID, action: .deleteSelf)
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> ChecklistItem? {
        guard let title = record["title"] as? String else {
            return nil
        }
        
        var checklistItem = ChecklistItem(
            title: title,
            sortOrder: record["sortOrder"] as? Int ?? 0
        )
        
        let isCompletedValue = record["isCompleted"] as? Int ?? 0
        checklistItem.isCompleted = isCompletedValue == 1
        checklistItem.recordID = record.recordID
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            checklistItem.id = userID
        }
        
        if let parentReference = record["parentItem"] as? CKRecord.Reference {
            checklistItem.parentItemRecordID = parentReference.recordID
        }
        
        return checklistItem
    }
}

// MARK: - Recurrence Helper Extensions

extension RecurrencePattern {
    func nextOccurrence(after date: Date) -> Date? {
        let calendar = Calendar.current
        
        switch frequency {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date)
        }
    }
    
    func shouldStopRecurring(currentOccurrences: Int, currentDate: Date) -> Bool {
        // Check max occurrences
        if let maxOccurrences = maxOccurrences, currentOccurrences >= maxOccurrences {
            return true
        }
        
        // Check end date
        if let endDate = endDate, currentDate > endDate {
            return true
        }
        
        return false
    }
}

extension Item {
    func generateRecurringInstances(upTo endDate: Date) -> [Item] {
        guard isRecurring else { return [] }
        
        var instances: [Item] = []
        var currentDate = assignedDate
        var occurrenceCount = 0
        let calendar = Calendar.current
        
        while currentDate <= endDate {
            // Check if we should stop recurring
            if recurrencePattern.shouldStopRecurring(currentOccurrences: occurrenceCount, currentDate: currentDate) {
                break
            }
            
            // Skip the original date (don't create instance for parent)
            if !calendar.isDate(currentDate, equalTo: assignedDate, toGranularity: .day) {
                var instance = self
                instance.id = UUID() // New unique ID for instance
                instance.assignedDate = calendar.startOfDay(for: currentDate)
                instance.parentRecurringID = self.id
                instance.isRecurringParent = false
                instance.occurrenceDate = currentDate
                instance.recordID = nil // Will get new CloudKit ID when saved
                instance.isCompleted = false // Reset completion for new instance
                instance.lastModified = Date()
                
                // Adjust assigned time to the new date if present
                if let originalTime = assignedTime {
                    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalTime)
                    instance.assignedTime = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                        minute: timeComponents.minute ?? 0,
                                                        second: timeComponents.second ?? 0,
                                                        of: currentDate)
                }
                
                instances.append(instance)
            }
            
            // Move to next occurrence
            guard let nextDate = recurrencePattern.nextOccurrence(after: currentDate) else {
                break
            }
            currentDate = nextDate
            occurrenceCount += 1
        }
        
        return instances
    }
}

// MARK: - ItemManager Class (Updated with Recurring Support)
@MainActor
class ItemManager: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var lastSyncDate: Date?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupCloudKitObservers()
        loadSampleItems()
        generateRecurringInstances()
    }
    
    // Access CloudKit manager - standard singleton pattern
    private var cloudKitManager: CloudKitManager {
        CloudKitManager.shared
    }
    
    private func setupCloudKitObservers() {
        // Listen for CloudKit data changes
        NotificationCenter.default.publisher(for: .cloudKitDataChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncFromCloudKit()
            }
            .store(in: &cancellables)
    }
    
    private func loadSampleItems() {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        
        // Only load sample items if we have no items yet
        guard items.isEmpty else { return }
        
        // Create a recurring daily standup
        var dailyStandup = Item(
            title: "Daily Standup",
            description: "Team standup meeting",
            assignedDate: today,
            assignedTime: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today),
            sortOrder: 0
        )
        dailyStandup.recurrencePattern = RecurrencePattern(frequency: .daily, interval: 1)
        dailyStandup.isRecurringParent = true
        
        // Create a weekly team meeting
        var weeklyMeeting = Item(
            title: "Weekly Team Meeting",
            description: "Weekly team sync and planning",
            assignedDate: today,
            assignedTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today),
            sortOrder: 1
        )
        weeklyMeeting.recurrencePattern = RecurrencePattern(frequency: .weekly, interval: 1)
        weeklyMeeting.isRecurringParent = true
        
        self.items = [
            dailyStandup,
            weeklyMeeting,
            Item(
                title: "Yoga Class",
                description: "Beginner's yoga session at the local studio",
                assignedDate: today,
                assignedTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today),
                sortOrder: 2
            ),
            Item(
                title: "Groceries",
                description: "Weekly grocery shopping",
                assignedDate: tomorrow,
                sortOrder: 3
            ),
            Item(
                title: "Doctor Appointment",
                description: "Annual checkup with Dr. Smith",
                assignedDate: dayAfterTomorrow,
                assignedTime: calendar.date(bySettingHour: 14, minute: 30, second: 0, of: dayAfterTomorrow),
                sortOrder: 4
            )
        ]
        
        // Add sample checklist to groceries item
        if let groceryIndex = items.firstIndex(where: { $0.title == "Groceries" }) {
            items[groceryIndex].checklist = [
                ChecklistItem(title: "Milk", sortOrder: 0),
                ChecklistItem(title: "Bread", sortOrder: 1),
                ChecklistItem(title: "Eggs", sortOrder: 2),
                ChecklistItem(title: "Apples", isCompleted: true, sortOrder: 3)
            ]
        }
    }
    
    // MARK: - Recurring Task Management
    
    private func generateRecurringInstances() {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 3, to: Date()) ?? Date() // Generate 3 months ahead
        
        let recurringTasks = items.filter { $0.isRecurringParent }
        
        for recurringTask in recurringTasks {
            let instances = recurringTask.generateRecurringInstances(upTo: endDate)
            
            // Only add instances that don't already exist
            for instance in instances {
                let existsAlready = items.contains { existingItem in
                    existingItem.parentRecurringID == recurringTask.id &&
                    calendar.isDate(existingItem.assignedDate, equalTo: instance.assignedDate, toGranularity: .day)
                }
                
                if !existsAlready {
                    items.append(instance)
                }
            }
        }
        
        // Sort items by sort order
        items.sort { $0.sortOrder < $1.sortOrder }
    }
    
    func updateRecurringPattern(_ item: Item, pattern: RecurrencePattern) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].recurrencePattern = pattern
            items[index].isRecurringParent = pattern.isRecurring
            items[index].lastModified = Date()
            
            let updatedItem = items[index]
            
            // If this is now a recurring task, generate future instances
            if pattern.isRecurring {
                generateRecurringInstances()
            } else if !pattern.isRecurring {
                // If recurrence was removed, clean up existing instances
                items.removeAll { $0.parentRecurringID == item.id }
            }
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync recurring pattern: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    // MARK: - CloudKit Sync Methods
    
    private func syncFromCloudKit() {
        Task { [weak self] in
            guard let self = self else { return }
            
            // Check if CloudKit is available
            let isAvailable = self.cloudKitManager.isAccountAvailable
            guard isAvailable else { return }
            
            do {
                let cloudItems = try await self.cloudKitManager.fetchAllItems()
                await MainActor.run {
                    self.mergeItems(cloudItems)
                    self.generateRecurringInstances() // Regenerate after sync
                    self.lastSyncDate = Date()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func mergeItems(_ cloudItems: [Item]) {
        // Simple merge strategy: use cloud version if it's newer, otherwise keep local
        var mergedItems: [Item] = []
        
        // Create dictionaries for quick lookup
        var localItemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        
        // Add all cloud items (they're either new or updates)
        for cloudItem in cloudItems {
            if let localItem = localItemsDict[cloudItem.id] {
                // Use the version with the latest modification date
                mergedItems.append(cloudItem.lastModified > localItem.lastModified ? cloudItem : localItem)
                localItemsDict.removeValue(forKey: cloudItem.id)
            } else {
                // New item from cloud
                mergedItems.append(cloudItem)
            }
        }
        
        // Add remaining local items (not in cloud yet)
        for (_, localItem) in localItemsDict {
            mergedItems.append(localItem)
        }
        
        self.items = mergedItems.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // MARK: - Smart Ordering Methods
    
    func itemsForDate(_ date: Date) -> [Item] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        let itemsForDate = items.filter { item in
            calendar.isDate(item.assignedDate, equalTo: targetDate, toGranularity: .day)
        }
        
        print("📋 ItemsForDate called for \(targetDate)")
        print("📋 Found \(itemsForDate.count) items for date")
        
        // Check if ANY item for this date has been manually reordered
        let hasAnyCustomOrder = itemsForDate.contains { $0.hasCustomOrder(for: date) }
        
        print("📋 Has custom order: \(hasAnyCustomOrder)")
        
        if hasAnyCustomOrder {
            // Use manual ordering (sort by sortOrder)
            let sortedItems = itemsForDate.sorted { $0.sortOrder < $1.sortOrder }
            print("📋 Using manual order - sorted by sortOrder")
            for (index, item) in sortedItems.enumerated() {
                print("📋 Item \(index): '\(item.title)' (sortOrder: \(item.sortOrder))")
            }
            return sortedItems
        } else {
            // Use chronological ordering (time first, then sort order)
            let sortedItems = itemsForDate.sorted { item1, item2 in
                if let time1 = item1.assignedTime, let time2 = item2.assignedTime {
                    return time1 < time2
                } else if item1.assignedTime != nil && item2.assignedTime == nil {
                    return true // Timed items come first
                } else if item1.assignedTime == nil && item2.assignedTime != nil {
                    return false // Timed items come first
                } else {
                    // Both have no time, sort by creation order (sortOrder)
                    return item1.sortOrder < item2.sortOrder
                }
            }
            print("📋 Using chronological order")
            for (index, item) in sortedItems.enumerated() {
                print("📋 Item \(index): '\(item.title)' (time: \(item.assignedTime?.description ?? "none"))")
            }
            return sortedItems
        }
    }
    
    // Handle manual reordering
    func handleManualReorder(for date: Date, reorderedItems: [Item]) {
        // Update sort orders and mark as manually ordered
        for (newIndex, item) in reorderedItems.enumerated() {
            if let globalIndex = items.firstIndex(where: { $0.id == item.id }) {
                items[globalIndex].sortOrder = newIndex
                items[globalIndex].setCustomOrder(for: date, hasCustomOrder: true)
                items[globalIndex].lastModified = Date()
            }
        }
        
        // Sync to CloudKit in background
        Task { [weak self] in
            guard let self = self else { return }
            
            // Create a snapshot of the items to sync
            let itemsToSync = await MainActor.run {
                return reorderedItems.compactMap { reorderedItem in
                    return self.items.first(where: { $0.id == reorderedItem.id })
                }
            }
            
            // Sync each item individually
            for item in itemsToSync {
                do {
                    let savedItem = try await self.cloudKitManager.saveItem(item)
                    await MainActor.run {
                        if let idx = self.items.firstIndex(where: { $0.id == savedItem.id }) {
                            self.items[idx] = savedItem
                        }
                    }
                } catch {
                    await MainActor.run {
                        print("Failed to sync reordered item: \(error)")
                    }
                }
            }
            
            await MainActor.run {
                self.lastSyncDate = Date()
            }
        }
    }
    
    // Reset to chronological order
    func resetToChronologicalOrder(for date: Date) {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        // Find all items for this date and reset their custom order flag
        for index in items.indices {
            if calendar.isDate(items[index].assignedDate, equalTo: targetDate, toGranularity: .day) {
                items[index].setCustomOrder(for: date, hasCustomOrder: false)
                items[index].lastModified = Date()
            }
        }
        
        // Trigger UI update
        objectWillChange.send()
        
        // Sync to CloudKit
        let itemsToSync = items.filter { calendar.isDate($0.assignedDate, equalTo: targetDate, toGranularity: .day) }
        Task { [weak self] in
            guard let self = self else { return }
            
            for item in itemsToSync {
                do {
                    _ = try await self.cloudKitManager.saveItem(item)
                } catch {
                    print("Failed to sync chronological reset: \(error)")
                }
            }
        }
    }
    
    // MARK: - Item Management Methods
    
    func addItem(_ item: Item) {
        var newItem = item
        newItem.sortOrder = items.count
        newItem.lastModified = Date()
        
        // Add locally first for immediate UI update
        items.append(newItem)
        
        // If this is a recurring task, generate future instances
        if newItem.isRecurring {
            generateRecurringInstances()
        }
        
        // Sync to CloudKit in background
        Task { [weak self] in
            guard let self = self else { return }
            let itemToSave = newItem // Capture the item value
            
            do {
                let savedItem = try await self.cloudKitManager.saveItem(itemToSave)
                await MainActor.run {
                    if let index = self.items.firstIndex(where: { $0.id == itemToSave.id }) {
                        self.items[index] = savedItem
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to sync item: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    func deleteItem(_ item: Item) {
        // If deleting a recurring parent, also delete all instances
        if item.isRecurringParent {
            items.removeAll { $0.parentRecurringID == item.id }
        }
        
        // Remove the item itself
        items.removeAll { $0.id == item.id }
        reorderItems()
        
        // Delete from CloudKit in background
        if let recordID = item.recordID {
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    try await self.cloudKitManager.deleteItem(recordID: recordID)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to delete from iCloud: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func toggleItemCompletion(_ item: Item) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isCompleted.toggle()
            items[index].lastModified = Date()
            
            let updatedItem = items[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    let savedItem = try await self.cloudKitManager.saveItem(updatedItem)
                    await MainActor.run {
                        if let idx = self.items.firstIndex(where: { $0.id == updatedItem.id }) {
                            self.items[idx] = savedItem
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync item completion: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func updateItemTime(_ item: Item, time: Date?) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].assignedTime = time
            items[index].lastModified = Date()
            
            let updatedItem = items[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync item time: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func addChecklistItem(_ item: Item, title: String) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let newChecklistItem = ChecklistItem(
                title: title,
                sortOrder: items[index].checklist.count
            )
            items[index].checklist.append(newChecklistItem)
            items[index].lastModified = Date()
            
            let updatedItem = items[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync checklist: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func deleteChecklistItem(_ item: Item, checklistItem: ChecklistItem) {
        if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
            items[itemIndex].checklist.removeAll { $0.id == checklistItem.id }
            items[itemIndex].lastModified = Date()
            
            // Reorder remaining items
            for (index, _) in items[itemIndex].checklist.enumerated() {
                items[itemIndex].checklist[index].sortOrder = index
            }
            
            let updatedItem = items[itemIndex]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync checklist: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func toggleChecklistItemCompletion(_ item: Item, checklistItem: ChecklistItem) {
        if let itemIndex = items.firstIndex(where: { $0.id == item.id }),
           let checklistIndex = items[itemIndex].checklist.firstIndex(where: { $0.id == checklistItem.id }) {
            items[itemIndex].checklist[checklistIndex].isCompleted.toggle()
            items[itemIndex].lastModified = Date()
            
            let updatedItem = items[itemIndex]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync checklist: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        reorderItems()
        
        // Sync all affected items to CloudKit
        Task { [weak self] in
            guard let self = self else { return }
            let itemsToSync = await MainActor.run { self.items }
            
            for item in itemsToSync {
                do {
                    _ = try await self.cloudKitManager.saveItem(item)
                } catch {
                    print("Failed to sync item order: \(error)")
                }
            }
        }
    }
    
    // MARK: - Reorder Sync Method
    func syncReorderedItems(_ reorderedItems: [Item]) {
        // This method is now replaced by handleManualReorder
        // Keeping for compatibility, but redirecting to new method
        if let firstItem = reorderedItems.first {
            handleManualReorder(for: firstItem.assignedDate, reorderedItems: reorderedItems)
        }
    }
    
    private func reorderItems() {
        for (index, _) in items.enumerated() {
            items[index].sortOrder = index
            items[index].lastModified = Date()
        }
    }
    
    // MARK: - Manual Sync
    
    func forceSyncWithCloudKit() {
        syncFromCloudKit()
    }
    
    // MARK: - Item Update Methods for ItemDetailsView
    
    func updateItemName(_ item: Item, newName: String) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].title = newName
            items[index].lastModified = Date()
            
            let updatedItem = items[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync item name: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func updateItemDescription(_ item: Item, newDescription: String) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].description = newDescription
            items[index].lastModified = Date()
            
            let updatedItem = items[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync item description: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func updateItemDate(_ item: Item, newDate: Date) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].assignedDate = Calendar.current.startOfDay(for: newDate)
            items[index].lastModified = Date()
            
            let updatedItem = items[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveItem(updatedItem)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync item date: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
}
