//
//  CloudKitManager.swift
//  Calendar
//
//  Simple CloudKit sync manager
//

import Foundation
import CloudKit
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container = CKContainer.default()
    private let privateDatabase: CKDatabase
    
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
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedTask.recordID = savedRecord.recordID
            return updatedTask
        } catch {
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
        
        do {
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            var tasks: [Task] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let task = Task.fromCKRecord(record) {
                        tasks.append(task)
                    }
                case .failure(let error):
                    print("Failed to fetch task record: \(error)")
                }
            }
            
            return tasks
        } catch {
            throw CloudKitError.fetchFailed(error)
        }
    }
    
    // MARK: - Delete Operations
    
    func deleteTask(recordID: CKRecord.ID) async throws {
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
            return "Failed to save to iCloud: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch from iCloud: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete from iCloud: \(error.localizedDescription)"
        }
    }
}
