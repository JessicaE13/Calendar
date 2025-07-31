//
//  ItemModel.swift
//  Calendar
//
//  Clean final version - no compilation errors
//

import Foundation
import CloudKit
import Combine

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

// MARK: - Item Model

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
        
        // Convert checklist to JSON data for storage
        if !checklist.isEmpty {
            do {
                let checklistData = try JSONEncoder().encode(checklist)
                record["checklist"] = checklistData
            } catch {
                print("Failed to encode checklist: \(error)")
            }
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
        
        if let parentReference = record["parentItem"] as? CKRecord.Reference {
            item.parentItemRecordID = parentReference.recordID
        }
        
        return item
    }
}

// MARK: - ItemManager Class
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
        
        self.items = [
            Item(
                title: "Team Meeting",
                description: "Weekly standup with the product team to discuss project progress and upcoming deadlines.",
                assignedDate: today,
                assignedTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today),
                sortOrder: 0
            ),
            Item(
                title: "Yoga Class",
                description: "Beginner's yoga session at the local studio",
                assignedDate: today,
                assignedTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today),
                sortOrder: 1
            ),
            Item(
                title: "Groceries",
                description: "Weekly grocery shopping",
                assignedDate: tomorrow,
                sortOrder: 2
            ),
            Item(
                title: "Email and Inbox DMx",
                assignedDate: today,
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
    
    // MARK: - CloudKit Sync Methods
    
    private func syncFromCloudKit() {
        _Concurrency.Item { [weak self] in
            guard let self = self else { return }
            
            // Check if CloudKit is available
            let isAvailable = await self.cloudKitManager.isAccountAvailable
            guard isAvailable else { return }
            
            do {
                let cloudItems = try await self.cloudKitManager.fetchAllItems()
                await MainActor.run {
                    self.mergeItems(cloudItems)
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
    
    // MARK: - Item Management Methods
    
    func addItem(_ item: Item) {
        var newItem = item
        newItem.sortOrder = items.count
        newItem.lastModified = Date()
        
        // Add locally first for immediate UI update
        items.append(newItem)
        
        // Sync to CloudKit in background
        _Concurrency.Item { [weak self] in
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
        // Remove locally first
        items.removeAll { $0.id == item.id }
        reorderItems()
        
        // Delete from CloudKit in background
        if let recordID = item.recordID {
            _Concurrency.Item { [weak self] in
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
            _Concurrency.Item { [weak self] in
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
            _Concurrency.Item { [weak self] in
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
            let newItem = ChecklistItem(
                title: title,
                sortOrder: items[index].checklist.count
            )
            items[index].checklist.append(newItem)
            items[index].lastModified = Date()
            
            let updatedItem = items[index]
            
            // Sync to CloudKit
            _Concurrency.Item { [weak self] in
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
    
    func deleteChecklistItem(_ item: Item, item: ChecklistItem) {
        if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
            items[itemIndex].checklist.removeAll { $0.id == item.id }
            items[itemIndex].lastModified = Date()
            
            // Reorder remaining items
            for (index, _) in items[itemIndex].checklist.enumerated() {
                items[itemIndex].checklist[index].sortOrder = index
            }
            
            let updatedItem = items[itemIndex]
            
            // Sync to CloudKit
            _Concurrency.Item { [weak self] in
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
    
    func toggleChecklistItemCompletion(_ item: Item, item: ChecklistItem) {
        if let itemIndex = items.firstIndex(where: { $0.id == item.id }),
           let itemIndex = items[itemIndex].checklist.firstIndex(where: { $0.id == item.id }) {
            items[itemIndex].checklist[itemIndex].isCompleted.toggle()
            items[itemIndex].lastModified = Date()
            
            let updatedItem = items[itemIndex]
            
            // Sync to CloudKit
            _Concurrency.Item { [weak self] in
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
        _Concurrency.Item { [weak self] in
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
    
    private func reorderItems() {
        for (index, _) in items.enumerated() {
            items[index].sortOrder = index
            items[index].lastModified = Date()
        }
    }
    
    func itemsForDate(_ date: Date) -> [Item] {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        return items.filter { item in
            calendar.isDate(item.assignedDate, equalTo: targetDate, toGranularity: .day)
        }.sorted { item1, item2 in
            if let time1 = item1.assignedTime, let time2 = item2.assignedTime {
                return time1 < time2
            } else if item1.assignedTime != nil && item2.assignedTime == nil {
                return true
            } else if item1.assignedTime == nil && item2.assignedTime != nil {
                return false
            } else {
                return item1.sortOrder < item2.sortOrder
            }
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
            _Concurrency.Item { [weak self] in
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
            _Concurrency.Item { [weak self] in
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
            _Concurrency.Item { [weak self] in
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
