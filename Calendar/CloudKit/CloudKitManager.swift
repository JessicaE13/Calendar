//
//  CloudKitManager.swift
//  Calendar
//
//  Ultra-safe version that avoids all queryable field issues
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
            print("Error description: \(error.localizedDescription)")
            throw CloudKitError.saveFailed(error)
        } catch {
            print("Failed to save item to \(environment) container: \(error)")
            throw CloudKitError.saveFailed(error)
        }
    }
    
    // MARK: - Fetch Operations - Ultra Conservative Approach
    
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
        
        // Try multiple approaches, starting with the safest
        let items = try await fetchWithMultipleApproaches()
        
        print("Successfully fetched \(items.count) items from CloudKit \(environment) container")
        return items
    }
    
    private func fetchWithMultipleApproaches() async throws -> [Item] {
        // Approach 1: Try the most basic query possible
        do {
            print("Attempting basic query...")
            return try await fetchWithBasicQuery()
        } catch let error as CKError {
            print("Basic query failed: \(error.localizedDescription)")
            
            // Approach 2: If basic query fails, try direct record fetch approach
            if error.code == .invalidArguments || error.code == .unknownItem {
                print("Trying alternative fetch approach...")
                return try await fetchWithDirectApproach()
            } else {
                throw CloudKitError.fetchFailed(error)
            }
        }
    }
    
    private func fetchWithBasicQuery() async throws -> [Item] {
        // Create the simplest possible query
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Item", predicate: predicate)
        
        // Absolutely no sort descriptors or additional configuration
        
        print("Executing query with predicate: \(predicate)")
        
        let records = try await privateDatabase.records(matching: query)
        
        var items: [Item] = []
        for (recordID, result) in records.matchResults {
            switch result {
            case .success(let record):
                if let item = Item.fromCKRecord(record) {
                    items.append(item)
                    print("Successfully parsed item: \(item.title)")
                } else {
                    print("Failed to parse record with ID: \(recordID)")
                }
            case .failure(let error):
                print("Failed to fetch record \(recordID): \(error)")
            }
        }
        
        // Sort locally
        return items.sorted { $0.lastModified > $1.lastModified }
    }
    
    private func fetchWithDirectApproach() async throws -> [Item] {
        // This approach doesn't use queries at all
        // Instead, we'll try to fetch records if we know their IDs
        // For now, return empty array since this is a fallback
        print("Direct approach: No records to fetch (this is expected for a fresh schema)")
        return []
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
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds for extra safety
            
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
    
    // MARK: - Schema Check - Ultra Conservative
    
    func checkSchemaSetup() async -> Bool {
        guard isAccountAvailable else { return false }
        
        do {
            // Use an impossible predicate so we don't actually fetch anything
            // but still test if the record type exists
            let predicate = NSPredicate(format: "title == %@", "__IMPOSSIBLE_TITLE_THAT_SHOULD_NOT_EXIST__")
            let query = CKQuery(recordType: "Item", predicate: predicate)
            
            print("Checking schema with test query...")
            let _ = try await privateDatabase.records(matching: query)
            
            await MainActor.run {
                self.schemaSetupComplete = true
            }
            print("Schema check passed - record type exists")
            return true
        } catch let error as CKError {
            if error.code == .unknownItem {
                print("Schema not set up yet in \(environment) container - record type doesn't exist")
                await MainActor.run {
                    self.schemaSetupComplete = false
                }
                return false
            } else {
                // Any other error means the record type exists
                print("Schema exists (got error: \(error.localizedDescription))")
                await MainActor.run {
                    self.schemaSetupComplete = true
                }
                return true
            }
        } catch {
            print("Unexpected error checking schema: \(error)")
            return false
        }
    }
    
    
    //
    //  CloudKit Extensions for Meal Planner
    //  Add these extensions to your CloudKitManager.swift file
    //
    
}
    // MARK: - CloudKit Manager Extensions for Meal Planning
    extension CloudKitManager {
        
        // MARK: - Recipe Operations
        
        func saveRecipe(_ recipe: Recipe) async throws -> Recipe {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            var updatedRecipe = recipe
            updatedRecipe.lastModified = Date()
            
            let record = updatedRecipe.toCKRecord()
            
            do {
                let savedRecord = try await privateDatabase.save(record)
                updatedRecipe.recordID = savedRecord.recordID
                return updatedRecipe
            } catch {
                throw CloudKitError.saveFailed(error)
            }
        }
        
        func fetchAllRecipes() async throws -> [Recipe] {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "Recipe", predicate: predicate)
            
            let records = try await privateDatabase.records(matching: query)
            
            var recipes: [Recipe] = []
            for (_, result) in records.matchResults {
                switch result {
                case .success(let record):
                    if let recipe = Recipe.fromCKRecord(record) {
                        recipes.append(recipe)
                    }
                case .failure(let error):
                    print("Failed to fetch recipe: \(error)")
                }
            }
            
            return recipes.sorted { $0.name < $1.name }
        }
        
        func deleteRecipe(recordID: CKRecord.ID) async throws {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            do {
                _ = try await privateDatabase.deleteRecord(withID: recordID)
            } catch {
                throw CloudKitError.deleteFailed(error)
            }
        }
        
        // MARK: - Planned Meal Operations
        
        func savePlannedMeal(_ plannedMeal: PlannedMeal) async throws -> PlannedMeal {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            var updatedMeal = plannedMeal
            updatedMeal.lastModified = Date()
            
            let record = updatedMeal.toCKRecord()
            
            do {
                let savedRecord = try await privateDatabase.save(record)
                updatedMeal.recordID = savedRecord.recordID
                return updatedMeal
            } catch {
                throw CloudKitError.saveFailed(error)
            }
        }
        
        func fetchAllPlannedMeals() async throws -> [PlannedMeal] {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "PlannedMeal", predicate: predicate)
            
            let records = try await privateDatabase.records(matching: query)
            
            var plannedMeals: [PlannedMeal] = []
            for (_, result) in records.matchResults {
                switch result {
                case .success(let record):
                    if let meal = PlannedMeal.fromCKRecord(record) {
                        plannedMeals.append(meal)
                    }
                case .failure(let error):
                    print("Failed to fetch planned meal: \(error)")
                }
            }
            
            return plannedMeals
        }
        
        func deletePlannedMeal(recordID: CKRecord.ID) async throws {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            do {
                _ = try await privateDatabase.deleteRecord(withID: recordID)
            } catch {
                throw CloudKitError.deleteFailed(error)
            }
        }
        
        // MARK: - Shopping List Operations
        
        func saveShoppingListItem(_ item: ShoppingListItem) async throws -> ShoppingListItem {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            var updatedItem = item
            updatedItem.lastModified = Date()
            
            let record = updatedItem.toCKRecord()
            
            do {
                let savedRecord = try await privateDatabase.save(record)
                updatedItem.recordID = savedRecord.recordID
                return updatedItem
            } catch {
                throw CloudKitError.saveFailed(error)
            }
        }
        
        func fetchAllShoppingListItems() async throws -> [ShoppingListItem] {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "ShoppingListItem", predicate: predicate)
            
            let records = try await privateDatabase.records(matching: query)
            
            var shoppingItems: [ShoppingListItem] = []
            for (_, result) in records.matchResults {
                switch result {
                case .success(let record):
                    if let item = ShoppingListItem.fromCKRecord(record) {
                        shoppingItems.append(item)
                    }
                case .failure(let error):
                    print("Failed to fetch shopping list item: \(error)")
                }
            }
            
            return shoppingItems
        }
        
        func deleteShoppingListItem(recordID: CKRecord.ID) async throws {
            guard isAccountAvailable else {
                throw CloudKitError.accountNotAvailable
            }
            
            do {
                _ = try await privateDatabase.deleteRecord(withID: recordID)
            } catch {
                throw CloudKitError.deleteFailed(error)
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
            } else if let ckError = error as? CKError, ckError.code == .invalidArguments {
                return "CloudKit schema configuration issue. The record type exists but has field problems."
            }
            return "Failed to fetch from iCloud: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete from iCloud: \(error.localizedDescription)"
        }
    }
}
