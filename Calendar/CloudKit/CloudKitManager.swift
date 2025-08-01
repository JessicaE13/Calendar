//
//  CloudKitManager.swift
//  Calendar
//
//  Configurable version that can switch between containers
//

import Foundation
import CloudKit
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    // Configuration enum for different environments
    enum ContainerEnvironment {
        case production
        case development
        
        var containerIdentifier: String {
            switch self {
            case .production:
                return "iCloud.com.estes.Calendar"
            case .development:
                return "iCloud.com.estes.Dev"
            }
        }
    }
    
    // Change this to switch containers
    private let environment: ContainerEnvironment = .development
    
    private let container: CKContainer
    let privateDatabase: CKDatabase
    
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isAccountAvailable = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    init() {
        self.container = CKContainer(identifier: environment.containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        
        // Debug info
        print("=== CloudKit Debug Info ===")
        print("Environment: \(environment)")
        print("CloudKit Container ID: \(container.containerIdentifier ?? "Unknown")")
        print("App Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("========================")
        
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
                
                print("CloudKit account status: \(status) for \(self?.environment.containerIdentifier ?? "unknown")")
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
        
        print("Saving item to CloudKit (\(environment)): \(item.title)")
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedItem.recordID = savedRecord.recordID
            print("Successfully saved item to \(environment) container: \(item.title)")
            return updatedItem
        } catch {
            print("Failed to save item to \(environment) container: \(error)")
            throw CloudKitError.saveFailed(error)
        }
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllItems() async throws -> [Item] {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        isSyncing = true
        
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }
        
        let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
        
        print("Fetching items from CloudKit \(environment) container...")
        
        do {
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            var items: [Item] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let item = Item.fromCKRecord(record) {
                        items.append(item)
                        print("Fetched item from \(environment): \(item.title)")
                    }
                case .failure(let error):
                    print("Failed to fetch item record from \(environment): \(error)")
                }
            }
            
            print("Successfully fetched \(items.count) items from CloudKit \(environment) container")
            return items
        } catch let error as CKError {
            print("CloudKit \(environment) fetch error: \(error)")
            if error.code == .unknownItem {
                print("Schema not set up yet in \(environment) container - returning empty array")
                return []
            }
            throw CloudKitError.fetchFailed(error)
        } catch {
            print("General fetch error from \(environment) container: \(error)")
            throw CloudKitError.fetchFailed(error)
        }
    }
    
    // MARK: - Delete Operations
    
    func deleteItem(recordID: CKRecord.ID) async throws {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        print("Deleting item from CloudKit \(environment) container: \(recordID)")
        
        do {
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            print("Successfully deleted item from \(environment) container")
        } catch {
            print("Failed to delete item from \(environment) container: \(error)")
            throw CloudKitError.deleteFailed(error)
        }
    }
    
    // MARK: - Schema Setup Helper
    
    func setupSchema() async throws {
        print("Setting up CloudKit schema in \(environment) container...")
        
        let testItem = Item(
            title: "CloudKit \(environment) Schema Setup Item",
            description: "This item establishes the CloudKit schema in \(environment) container",
            assignedDate: Date(),
            sortOrder: 0
        )
        
        do {
            let savedItem = try await saveItem(testItem)
            print("\(environment) container schema setup successful!")
            
            if let recordID = savedItem.recordID {
                try await deleteItem(recordID: recordID)
                print("Test item deleted from \(environment) container")
            }
        } catch {
            print("\(environment) container schema setup failed: \(error)")
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
