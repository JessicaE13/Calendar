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
    
    func saveTask(_ task: Task) async throws -> Task {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        var updatedTask = task
        updatedTask.lastModified = Date()
        
        let record = updatedTask.toCKRecord()
        
        print("Saving task to CloudKit: \(task.title)")
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedTask.recordID = savedRecord.recordID
            print("Successfully saved task: \(task.title)")
            return updatedTask
        } catch {
            print("Failed to save task: \(error)")
            throw CloudKitError.saveFailed(error)
        }
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllTasks() async throws -> [Task] {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        // Set syncing state directly since we're @MainActor
        isSyncing = true
        
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }
        
        let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
        
        print("Fetching tasks from CloudKit...")
        
        do {
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            var tasks: [Task] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let task = Task.fromCKRecord(record) {
                        tasks.append(task)
                        print("Fetched task: \(task.title)")
                    }
                case .failure(let error):
                    print("Failed to fetch task record: \(error)")
                }
            }
            
            print("Successfully fetched \(tasks.count) tasks from CloudKit")
            return tasks
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
    
    func deleteTask(recordID: CKRecord.ID) async throws {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        print("Deleting task from CloudKit: \(recordID)")
        
        do {
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            print("Successfully deleted task from CloudKit")
        } catch {
            print("Failed to delete task: \(error)")
            throw CloudKitError.deleteFailed(error)
        }
    }
    
    // MARK: - Schema Setup Helper
    
    func setupSchema() async throws {
        print("Setting up CloudKit schema...")
        
        // Create a test task to establish the schema
        let testTask = Task(
            title: "CloudKit Schema Setup Task",
            description: "This task establishes the CloudKit schema",
            assignedDate: Date(),
            sortOrder: 0
        )
        
        do {
            let savedTask = try await saveTask(testTask)
            print("Schema setup successful!")
            
            // Optionally delete the test task
            if let recordID = savedTask.recordID {
                try await deleteTask(recordID: recordID)
                print("Test task deleted")
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
