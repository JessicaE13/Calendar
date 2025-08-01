//
//  CloudKitManager.swift
//  Calendar
//
//  Simplified version compatible with all iOS versions
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
    @Published var schemaSetupComplete = false
    
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
            
            // Mark schema as set up after first successful save
            if !schemaSetupComplete {
                schemaSetupComplete = true
                print("Schema setup appears to be complete!")
            }
            
            return updatedItem
        } catch let error as CKError {
            print("CloudKit save error (\(environment)): \(error)")
            print("Error code: \(error.code.rawValue)")
            throw CloudKitError.saveFailed(error)
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
        
        print("Fetching items from CloudKit \(environment) container...")
        
        // Use simple query approach that's more compatible
        let items = try await fetchWithCompatibleQuery()
        
        print("Successfully fetched \(items.count) items from CloudKit \(environment) container")
        return items
    }
    
    private func fetchWithCompatibleQuery() async throws -> [Item] {
        // Use the most basic query possible to avoid field queryable issues
        let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: true))
        
        do {
            // Try with sort first
            query.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
            return try await performQuery(query)
        } catch let error as CKError where error.code == .invalidArguments {
            print("Sort by lastModified failed, trying without sort...")
            
            // Try without sort descriptors
            query.sortDescriptors = nil
            do {
                let items = try await performQuery(query)
                // Sort locally instead
                return items.sorted { $0.lastModified > $1.lastModified }
            } catch let error as CKError where error.code == .unknownItem {
                print("Record type 'Item' doesn't exist yet - returning empty array")
                return []
            }
        } catch let error as CKError where error.code == .unknownItem {
            print("Record type 'Item' doesn't exist yet - returning empty array")
            return []
        }
    }
    
    private func performQuery(_ query: CKQuery) async throws -> [Item] {
        let records = try await privateDatabase.records(matching: query)
        
        var items: [Item] = []
        for (_, result) in records.matchResults {
            switch result {
            case .success(let record):
                if let item = Item.fromCKRecord(record) {
                    items.append(item)
                    print("Fetched item from \(environment): \(item.title)")
                }
            case .failure(let error):
                print("Failed to fetch record: \(error)")
            }
        }
        
        return items
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
            
            // Wait a moment for schema propagation
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            if let recordID = savedItem.recordID {
                try await deleteItem(recordID: recordID)
                print("Test item deleted from \(environment) container")
            }
            
            schemaSetupComplete = true
        } catch {
            print("\(environment) container schema setup failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Schema Check
    
    func checkSchemaSetup() async -> Bool {
        guard isAccountAvailable else { return false }
        
        do {
            let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: false))
            let _ = try await privateDatabase.records(matching: query)
            
            await MainActor.run {
                self.schemaSetupComplete = true
            }
            return true
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("Schema not set up yet in \(environment) container")
                await MainActor.run {
                    self.schemaSetupComplete = false
                }
                return false
            } else if error.code == .invalidArguments {
                // Schema exists but might have field issues
                print("Schema exists but has field configuration issues")
                await MainActor.run {
                    self.schemaSetupComplete = true
                }
                return true
            } else {
                print("Error checking schema: \(error)")
                return false
            }
        } catch {
            print("Unexpected error checking schema: \(error)")
            return false
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
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return "CloudKit schema not set up yet. Try 'Create CloudKit Schema' first."
            }
            return "Failed to save to iCloud: \(error.localizedDescription)"
        case .fetchFailed(let error):
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                return "CloudKit schema not set up yet. No items to fetch."
            }
            return "Failed to fetch from iCloud: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete from iCloud: \(error.localizedDescription)"
        }
    }
}
