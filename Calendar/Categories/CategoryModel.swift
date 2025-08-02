//
//  CategoryModel.swift
//  Calendar
//
//  Category system with CloudKit support
//

import Foundation
import CloudKit
import SwiftUI

// MARK: - Category Model
struct Category: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var color: CategoryColor
    var sortOrder: Int = 0
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    init(name: String, color: CategoryColor, sortOrder: Int = 0) {
        self.name = name
        self.color = color
        self.sortOrder = sortOrder
        self.lastModified = Date()
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, name, color, sortOrder, lastModified
        // recordID is not encoded/decoded
    }
}

// MARK: - Category Colors
enum CategoryColor: String, CaseIterable, Codable {
    case accent1 = "accent1"
    case accent2 = "accent2"
    case accent3 = "accent3"
    case accent4 = "accent4"
    case accent5 = "accent5"
    case accent6 = "accent6"
    case accent7 = "accent7"
    case accent8 = "accent8"
    case accent9 = "accent9"
    case accent10 = "accent10"
    
    var swiftUIColor: Color {
        switch self {
        case .accent1: return .red
        case .accent2: return .orange
        case .accent3: return .yellow
        case .accent4: return .green
        case .accent5: return .blue
        case .accent6: return .purple
        case .accent7: return .pink
        case .accent8: return .indigo
        case .accent9: return .teal
        case .accent10: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .accent1: return "Accent 1"
        case .accent2: return "Accent 2"
        case .accent3: return "Accent 3"
        case .accent4: return "Accent 4"
        case .accent5: return "Accent 5"
        case .accent6: return "Accent 6"
        case .accent7: return "Accent 7"
        case .accent8: return "Accent 8"
        case .accent9: return "Accent 9"
        case .accent10: return "Accent 10"
        }
    }
}
// MARK: - CloudKit Extensions for Category
extension Category {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Category", recordID: recordID ?? CKRecord.ID())
        record["name"] = name
        record["color"] = color.rawValue
        record["sortOrder"] = sortOrder
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> Category? {
        guard let name = record["name"] as? String,
              let colorRaw = record["color"] as? String,
              let color = CategoryColor(rawValue: colorRaw) else {
            return nil
        }
        
        var category = Category(
            name: name,
            color: color,
            sortOrder: record["sortOrder"] as? Int ?? 0
        )
        
        category.recordID = record.recordID
        category.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            category.id = userID
        }
        
        return category
    }
}

// MARK: - Category Manager
@MainActor
class CategoryManager: ObservableObject {
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    static let shared = CategoryManager()
    
    private var cloudKitManager: CloudKitManager {
        CloudKitManager.shared
    }
    
    init() {
        loadDefaultCategories()
    }
    
    private func loadDefaultCategories() {
        // Only load defaults if no categories exist
        guard categories.isEmpty else { return }
        
        categories = [
            Category(name: "Work", color: .accent1, sortOrder: 0),
            Category(name: "Personal", color: .accent2, sortOrder: 1),
            Category(name: "Health", color: .accent3, sortOrder: 2),
            Category(name: "Family", color: .accent4, sortOrder: 3),
            Category(name: "Learning", color: .accent5, sortOrder: 4)
        ]
    }
    
    // MARK: - Category Management
    
    func addCategory(_ category: Category) {
        var newCategory = category
        newCategory.sortOrder = categories.count
        newCategory.lastModified = Date()
        
        // Add locally first for immediate UI update
        categories.append(newCategory)
        categories.sort { $0.sortOrder < $1.sortOrder }
        
        // Sync to CloudKit in background
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let savedCategory = try await self.cloudKitManager.saveCategory(newCategory)
                await MainActor.run {
                    if let index = self.categories.firstIndex(where: { $0.id == newCategory.id }) {
                        self.categories[index] = savedCategory
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to sync category: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            categories[index].lastModified = Date()
            
            let updatedCategory = categories[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveCategory(updatedCategory)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync category: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        reorderCategories()
        
        // Delete from CloudKit in background
        if let recordID = category.recordID {
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    try await self.cloudKitManager.deleteCategory(recordID: recordID)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to delete category from iCloud: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        reorderCategories()
        
        // Sync all affected categories to CloudKit
        Task { [weak self] in
            guard let self = self else { return }
            let categoriesToSync = await MainActor.run { self.categories }
            
            for category in categoriesToSync {
                do {
                    _ = try await self.cloudKitManager.saveCategory(category)
                } catch {
                    print("Failed to sync category order: \(error)")
                }
            }
        }
    }
    
    private func reorderCategories() {
        for (index, _) in categories.enumerated() {
            categories[index].sortOrder = index
            categories[index].lastModified = Date()
        }
    }
    
    // MARK: - CloudKit Sync
    
    func syncFromCloudKit() {
        Task { [weak self] in
            guard let self = self else { return }
            
            let isAvailable = self.cloudKitManager.isAccountAvailable
            guard isAvailable else { return }
            
            do {
                let cloudCategories = try await self.cloudKitManager.fetchAllCategories()
                await MainActor.run {
                    self.mergeCategories(cloudCategories)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func mergeCategories(_ cloudCategories: [Category]) {
        // Simple merge strategy: use cloud version if it's newer, otherwise keep local
        var mergedCategories: [Category] = []
        
        // Create dictionaries for quick lookup
        var localCategoriesDict = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        
        // Add all cloud categories (they're either new or updates)
        for cloudCategory in cloudCategories {
            if let localCategory = localCategoriesDict[cloudCategory.id] {
                // Use the version with the latest modification date
                mergedCategories.append(cloudCategory.lastModified > localCategory.lastModified ? cloudCategory : localCategory)
                localCategoriesDict.removeValue(forKey: cloudCategory.id)
            } else {
                // New category from cloud
                mergedCategories.append(cloudCategory)
            }
        }
        
        // Add remaining local categories (not in cloud yet)
        for (_, localCategory) in localCategoriesDict {
            mergedCategories.append(localCategory)
        }
        
        self.categories = mergedCategories.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func forceSyncWithCloudKit() {
        syncFromCloudKit()
    }
}

// MARK: - CloudKit Manager Extensions for Categories
extension CloudKitManager {
    func saveCategory(_ category: Category) async throws -> Category {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        var updatedCategory = category
        updatedCategory.lastModified = Date()
        
        let record = updatedCategory.toCKRecord()
        
        print("Saving category to CloudKit: \(category.name)")
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedCategory.recordID = savedRecord.recordID
            print("Successfully saved category: \(category.name)")
            return updatedCategory
        } catch let error as CKError {
            print("CloudKit save category error: \(error)")
            throw CloudKitError.saveFailed(error)
        } catch {
            print("Failed to save category: \(error)")
            throw CloudKitError.saveFailed(error)
        }
    }
    
    func fetchAllCategories() async throws -> [Category] {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        print("Fetching categories from CloudKit...")
        
        // Create basic query for categories
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Category", predicate: predicate)
        
        let records = try await privateDatabase.records(matching: query)
        
        var categories: [Category] = []
        for (recordID, result) in records.matchResults {
            switch result {
            case .success(let record):
                if let category = Category.fromCKRecord(record) {
                    categories.append(category)
                    print("Successfully parsed category: \(category.name)")
                } else {
                    print("Failed to parse category record with ID: \(recordID)")
                }
            case .failure(let error):
                print("Failed to fetch category record \(recordID): \(error)")
            }
        }
        
        // Sort locally
        print("Successfully fetched \(categories.count) categories from CloudKit")
        return categories.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func deleteCategory(recordID: CKRecord.ID) async throws {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        print("Deleting category from CloudKit: \(recordID)")
        
        do {
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            print("Successfully deleted category")
        } catch {
            print("Failed to delete category: \(error)")
            throw CloudKitError.deleteFailed(error)
        }
    }
}
