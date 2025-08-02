//
//  HabitModel.swift
//  Calendar
//
//  Minimalistic habit tracking with true/false completion
//

import Foundation
import CloudKit
import SwiftUI

// MARK: - Habit Model
struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var categoryID: UUID? = nil
    var isActive: Bool = true
    var sortOrder: Int = 0
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    init(name: String, categoryID: UUID? = nil, sortOrder: Int = 0) {
        self.name = name
        self.categoryID = categoryID
        self.sortOrder = sortOrder
        self.lastModified = Date()
    }
    
    @MainActor
    func getCategory(from categoryManager: CategoryManager) -> Category? {
        guard let categoryID = categoryID else { return nil }
        return categoryManager.categories.first { $0.id == categoryID }
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, name, categoryID, isActive, sortOrder, lastModified
        // recordID is not encoded/decoded
    }
    
    static func == (lhs: Habit, rhs: Habit) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.categoryID == rhs.categoryID &&
               lhs.isActive == rhs.isActive &&
               lhs.sortOrder == rhs.sortOrder
    }
}

// MARK: - Daily Habit Completion
struct DailyHabitCompletion: Identifiable, Codable, Equatable {
    var id = UUID()
    var habitID: UUID
    var date: Date
    var isCompleted: Bool = false
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    init(habitID: UUID, date: Date, isCompleted: Bool = false) {
        self.habitID = habitID
        self.date = Calendar.current.startOfDay(for: date)
        self.isCompleted = isCompleted
        self.lastModified = Date()
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, habitID, date, isCompleted, lastModified
        // recordID is not encoded/decoded
    }
    
    static func == (lhs: DailyHabitCompletion, rhs: DailyHabitCompletion) -> Bool {
        return lhs.id == rhs.id &&
               lhs.habitID == rhs.habitID &&
               lhs.date == rhs.date &&
               lhs.isCompleted == rhs.isCompleted
    }
}

// MARK: - CloudKit Extensions
extension Habit {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Habit", recordID: recordID ?? CKRecord.ID())
        record["name"] = name
        record["categoryID"] = categoryID?.uuidString
        record["isActive"] = isActive ? 1 : 0
        record["sortOrder"] = sortOrder
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> Habit? {
        guard let name = record["name"] as? String else {
            return nil
        }
        
        var categoryID: UUID? = nil
        if let categoryIDString = record["categoryID"] as? String {
            categoryID = UUID(uuidString: categoryIDString)
        }
        
        var habit = Habit(
            name: name,
            categoryID: categoryID,
            sortOrder: record["sortOrder"] as? Int ?? 0
        )
        
        habit.recordID = record.recordID
        habit.isActive = (record["isActive"] as? Int ?? 1) == 1
        habit.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            habit.id = userID
        }
        
        return habit
    }
}

extension DailyHabitCompletion {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "DailyHabitCompletion", recordID: recordID ?? CKRecord.ID())
        record["habitID"] = habitID.uuidString
        record["date"] = date
        record["isCompleted"] = isCompleted ? 1 : 0
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> DailyHabitCompletion? {
        guard let habitIDString = record["habitID"] as? String,
              let habitID = UUID(uuidString: habitIDString),
              let date = record["date"] as? Date else {
            return nil
        }
        
        var completion = DailyHabitCompletion(
            habitID: habitID,
            date: date,
            isCompleted: (record["isCompleted"] as? Int ?? 0) == 1
        )
        
        completion.recordID = record.recordID
        completion.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            completion.id = userID
        }
        
        return completion
    }
}

// MARK: - Habit Manager
@MainActor
class HabitManager: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var completions: [DailyHabitCompletion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    static let shared = HabitManager()
    
    private var cloudKitManager: CloudKitManager {
        CloudKitManager.shared
    }
    
    init() {
        loadDefaultHabits()
    }
    
    private func loadDefaultHabits() {
        // Only load defaults if no habits exist
        guard habits.isEmpty else { return }
        
        // Get some sample categories (assuming they exist from CategoryManager)
        let categoryManager = CategoryManager.shared
        let healthCategory = categoryManager.categories.first { $0.name == "Health" }
        let personalCategory = categoryManager.categories.first { $0.name == "Personal" }
        let learningCategory = categoryManager.categories.first { $0.name == "Learning" }
        
        habits = [
            Habit(name: "Drink 8 glasses of water", categoryID: healthCategory?.id, sortOrder: 0),
            Habit(name: "Exercise for 30 minutes", categoryID: healthCategory?.id, sortOrder: 1),
            Habit(name: "Read for 20 minutes", categoryID: learningCategory?.id, sortOrder: 2),
            Habit(name: "Practice gratitude", categoryID: personalCategory?.id, sortOrder: 3),
            Habit(name: "Take vitamins", categoryID: healthCategory?.id, sortOrder: 4)
        ]
    }
    
    // MARK: - Habit Management
    
    func addHabit(_ habit: Habit) {
        var newHabit = habit
        newHabit.sortOrder = habits.count
        newHabit.lastModified = Date()
        
        habits.append(newHabit)
        habits.sort { $0.sortOrder < $1.sortOrder }
        
        // Sync to CloudKit
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let savedHabit = try await self.cloudKitManager.saveHabit(newHabit)
                await MainActor.run {
                    if let index = self.habits.firstIndex(where: { $0.id == newHabit.id }) {
                        self.habits[index] = savedHabit
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to sync habit: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            habits[index].lastModified = Date()
            
            let updatedHabit = habits[index]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveHabit(updatedHabit)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync habit: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func deleteHabit(_ habit: Habit) {
        // Remove habit and all its completions
        habits.removeAll { $0.id == habit.id }
        completions.removeAll { $0.habitID == habit.id }
        reorderHabits()
        
        // Delete from CloudKit
        if let recordID = habit.recordID {
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    try await self.cloudKitManager.deleteHabit(recordID: recordID)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to delete habit from iCloud: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    private func reorderHabits() {
        for (index, _) in habits.enumerated() {
            habits[index].sortOrder = index
            habits[index].lastModified = Date()
        }
    }
    
    // MARK: - Completion Management
    
    func toggleHabitCompletion(_ habit: Habit, for date: Date) {
        let targetDate = Calendar.current.startOfDay(for: date)
        
        if let existingIndex = completions.firstIndex(where: {
            $0.habitID == habit.id && Calendar.current.isDate($0.date, equalTo: targetDate, toGranularity: .day)
        }) {
            // Toggle existing completion
            completions[existingIndex].isCompleted.toggle()
            completions[existingIndex].lastModified = Date()
            
            let updatedCompletion = completions[existingIndex]
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    _ = try await self.cloudKitManager.saveHabitCompletion(updatedCompletion)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync habit completion: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        } else {
            // Create new completion
            let newCompletion = DailyHabitCompletion(habitID: habit.id, date: targetDate, isCompleted: true)
            completions.append(newCompletion)
            
            // Sync to CloudKit
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    let savedCompletion = try await self.cloudKitManager.saveHabitCompletion(newCompletion)
                    await MainActor.run {
                        if let index = self.completions.firstIndex(where: { $0.id == newCompletion.id }) {
                            self.completions[index] = savedCompletion
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync habit completion: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func isHabitCompleted(_ habit: Habit, on date: Date) -> Bool {
        let targetDate = Calendar.current.startOfDay(for: date)
        return completions.first {
            $0.habitID == habit.id && Calendar.current.isDate($0.date, equalTo: targetDate, toGranularity: .day)
        }?.isCompleted ?? false
    }
    
    func getCurrentStreak(_ habit: Habit, as date: Date = Date()) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: date)
        
        // Count backwards from today
        while true {
            let isCompleted = isHabitCompleted(habit, on: checkDate)
            if isCompleted {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else {
                break
            }
        }
        
        return streak
    }
    
    func getCompletionRate(_ habit: Habit, days: Int = 30) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days + 1, to: endDate) else { return 0 }
        
        var completedDays = 0
        var currentDate = startDate
        
        while currentDate <= endDate {
            if isHabitCompleted(habit, on: currentDate) {
                completedDays += 1
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }
        
        return Double(completedDays) / Double(days)
    }
    
    // MARK: - CloudKit Sync
    
    func syncFromCloudKit() {
        Task { [weak self] in
            guard let self = self else { return }
            guard self.cloudKitManager.isAccountAvailable else { return }
            
            do {
                async let cloudHabits = self.cloudKitManager.fetchAllHabits()
                async let cloudCompletions = self.cloudKitManager.fetchAllHabitCompletions()
                
                let (habits, completions) = try await (cloudHabits, cloudCompletions)
                
                await MainActor.run {
                    self.mergeHabits(habits)
                    self.mergeCompletions(completions)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func mergeHabits(_ cloudHabits: [Habit]) {
        var mergedHabits: [Habit] = []
        var localHabitsDict = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
        
        for cloudHabit in cloudHabits {
            if let localHabit = localHabitsDict[cloudHabit.id] {
                mergedHabits.append(cloudHabit.lastModified > localHabit.lastModified ? cloudHabit : localHabit)
                localHabitsDict.removeValue(forKey: cloudHabit.id)
            } else {
                mergedHabits.append(cloudHabit)
            }
        }
        
        for (_, localHabit) in localHabitsDict {
            mergedHabits.append(localHabit)
        }
        
        self.habits = mergedHabits.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    private func mergeCompletions(_ cloudCompletions: [DailyHabitCompletion]) {
        var mergedCompletions: [DailyHabitCompletion] = []
        var localCompletionsDict = Dictionary(uniqueKeysWithValues: completions.map { ($0.id, $0) })
        
        for cloudCompletion in cloudCompletions {
            if let localCompletion = localCompletionsDict[cloudCompletion.id] {
                mergedCompletions.append(cloudCompletion.lastModified > localCompletion.lastModified ? cloudCompletion : localCompletion)
                localCompletionsDict.removeValue(forKey: cloudCompletion.id)
            } else {
                mergedCompletions.append(cloudCompletion)
            }
        }
        
        for (_, localCompletion) in localCompletionsDict {
            mergedCompletions.append(localCompletion)
        }
        
        self.completions = mergedCompletions
    }
    
    func forceSyncWithCloudKit() {
        syncFromCloudKit()
    }
}

// MARK: - CloudKit Manager Extensions for Habits
extension CloudKitManager {
    func saveHabit(_ habit: Habit) async throws -> Habit {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        var updatedHabit = habit
        updatedHabit.lastModified = Date()
        
        let record = updatedHabit.toCKRecord()
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedHabit.recordID = savedRecord.recordID
            return updatedHabit
        } catch {
            throw CloudKitError.saveFailed(error)
        }
    }
    
    func saveHabitCompletion(_ completion: DailyHabitCompletion) async throws -> DailyHabitCompletion {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        var updatedCompletion = completion
        updatedCompletion.lastModified = Date()
        
        let record = updatedCompletion.toCKRecord()
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedCompletion.recordID = savedRecord.recordID
            return updatedCompletion
        } catch {
            throw CloudKitError.saveFailed(error)
        }
    }
    
    func fetchAllHabits() async throws -> [Habit] {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Habit", predicate: predicate)
        
        let records = try await privateDatabase.records(matching: query)
        
        var habits: [Habit] = []
        for (_, result) in records.matchResults {
            switch result {
            case .success(let record):
                if let habit = Habit.fromCKRecord(record) {
                    habits.append(habit)
                }
            case .failure(let error):
                print("Failed to fetch habit: \(error)")
            }
        }
        
        return habits.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    func fetchAllHabitCompletions() async throws -> [DailyHabitCompletion] {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "DailyHabitCompletion", predicate: predicate)
        
        let records = try await privateDatabase.records(matching: query)
        
        var completions: [DailyHabitCompletion] = []
        for (_, result) in records.matchResults {
            switch result {
            case .success(let record):
                if let completion = DailyHabitCompletion.fromCKRecord(record) {
                    completions.append(completion)
                }
            case .failure(let error):
                print("Failed to fetch habit completion: \(error)")
            }
        }
        
        return completions
    }
    
    func deleteHabit(recordID: CKRecord.ID) async throws {
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
