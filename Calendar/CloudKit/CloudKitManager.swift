//
//  CloudKitManager.swift
//  Calendar
//
//  Enhanced CloudKit sync manager with proper database access
//

import Foundation
import CloudKit
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container = CKContainer.default()
    let privateDatabase: CKDatabase  // Make this accessible for subscriptions
    
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isAccountAvailable = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    init() {
        self.privateDatabase = container.privateCloudDatabase
        checkAccountStatus()
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() {
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.accountStatus = status
                self?.isAccountAvailable = status == .available
                
                if let error = error {
                    print("CloudKit account error: \(error.localizedDescription)")
                }
                
                print("CloudKit account status: \(status)")
            }
        }
    }
    
    // MARK: - Save Operations
    
    func saveItem(_ item: Item) async throws -> Item {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        var updatedItem = item
        updatedItem.lastModified = Date()
        
        let record = updatedItem.toCKRecord()
        
        print("Saving item to CloudKit: \(item.title)")
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedItem.recordID = savedRecord.recordID
            print("Successfully saved item: \(item.title)")
            return updatedItem
        } catch {
            print("Failed to save item: \(error)")
            throw CloudKitError.saveFailed(error)
        }
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllItems() async throws -> [Item] {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        // Set syncing state directly since we're @MainActor
        isSyncing = true
        
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }
        
        let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
        
        print("Fetching items from CloudKit...")
        
        do {
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            var items: [Item] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let item = Item.fromCKRecord(record) {
                        items.append(item)
                        print("Fetched item: \(item.title)")
                    }
                case .failure(let error):
                    print("Failed to fetch item record: \(error)")
                }
            }
            
            print("Successfully fetched \(items.count) items from CloudKit")
            return items
        } catch let error as CKError {
            print("CloudKit fetch error: \(error)")
            // Handle specific CloudKit errors
            if error.code == .unknownItem {
                print("Schema not set up yet - returning empty array")
                return []
            }
            throw CloudKitError.fetchFailed(error)
        } catch {
            print("General fetch error: \(error)")
            throw CloudKitError.fetchFailed(error)
        }
    }
    
    // MARK: - Delete Operations
    
    func deleteItem(recordID: CKRecord.ID) async throws {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        print("Deleting item from CloudKit: \(recordID)")
        
        do {
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            print("Successfully deleted item from CloudKit")
        } catch {
            print("Failed to delete item: \(error)")
            throw CloudKitError.deleteFailed(error)
        }
    }
    
    // MARK: - Schema Setup Helper
    
    func setupSchema() async throws {
        print("Setting up CloudKit schema...")
        
        // Create a test item to establish the schema
        let testItem = Item(
            title: "CloudKit Schema Setup Item",
            description: "This item establishes the CloudKit schema",
            assignedDate: Date(),
            sortOrder: 0
        )
        
        do {
            let savedItem = try await saveItem(testItem)
            print("Schema setup successful!")
            
            // Optionally delete the test item
            if let recordID = savedItem.recordID {
                try await deleteItem(recordID: recordID)
                print("Test item deleted")
            }
        } catch {
            print("Schema setup failed: \(error)")
            throw error
        }
    }
}

// MARK: - CloudKit Errors

enum CloudKitError: LocalizedError {
    case accountNotAvailable
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud in Settings."
        case .saveFailed(let error):
            return "Failed to save to iCloud: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch from iCloud: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete from iCloud: \(error.localizedDescription)"
        }
    }
}
