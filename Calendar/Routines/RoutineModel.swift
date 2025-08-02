//
//  RoutineModel.swift
//  Calendar
//
//  Routine system with checklist progress tracking
//

import Foundation
import CloudKit
import SwiftUI

// MARK: - Routine Type
enum RoutineType: String, CaseIterable, Codable {
    case morning = "morning"
    case evening = "evening"
    
    var displayName: String {
        switch self {
        case .morning: return "Morning Routine"
        case .evening: return "Evening Routine"
        }
    }
    
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .evening: return "moon.stars.fill"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .morning: return [Color("Accent3")]
        case .evening: return [Color("Accent4")]
        }
    }
}

// MARK: - Routine Item
struct RoutineItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var sortOrder: Int = 0
    var estimatedMinutes: Int = 5 // Estimated time to complete
    
    init(title: String, estimatedMinutes: Int = 5, sortOrder: Int = 0) {
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.sortOrder = sortOrder
    }
}

// MARK: - Daily Routine Progress
struct DailyRoutineProgress: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var routineType: RoutineType
    var items: [RoutineItem]
    var startTime: Date?
    var completionTime: Date?
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    var completedItemsCount: Int {
        return items.filter { $0.isCompleted }.count
    }
    
    var totalItemsCount: Int {
        return items.count
    }
    
    var progressPercentage: Double {
        guard totalItemsCount > 0 else { return 0 }
        return Double(completedItemsCount) / Double(totalItemsCount)
    }
    
    var isCompleted: Bool {
        return completedItemsCount == totalItemsCount && totalItemsCount > 0
    }
    
    var estimatedTotalMinutes: Int {
        return items.reduce(0) { $0 + $1.estimatedMinutes }
    }
    
    var completedMinutes: Int {
        return items.filter { $0.isCompleted }.reduce(0) { $0 + $1.estimatedMinutes }
    }
    
    init(date: Date, routineType: RoutineType, templateItems: [RoutineItem]) {
        self.date = Calendar.current.startOfDay(for: date)
        self.routineType = routineType
        self.items = templateItems.map { templateItem in
            var item = templateItem
            item.id = UUID() // New ID for daily instance
            item.isCompleted = false // Reset completion
            return item
        }
        self.lastModified = Date()
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, date, routineType, items, startTime, completionTime, lastModified
        // recordID is not encoded/decoded
    }
}

// MARK: - Routine Template
struct RoutineTemplate: Identifiable, Codable {
    var id = UUID()
    var routineType: RoutineType
    var items: [RoutineItem]
    var isEnabled: Bool = true
    var recordID: CKRecord.ID?
    var lastModified: Date = Date()
    
    init(routineType: RoutineType, items: [RoutineItem] = []) {
        self.routineType = routineType
        self.items = items
        self.lastModified = Date()
    }
    
    // Custom coding keys to handle CloudKit fields
    enum CodingKeys: String, CodingKey {
        case id, routineType, items, isEnabled, lastModified
        // recordID is not encoded/decoded
    }
}

// MARK: - CloudKit Extensions
extension DailyRoutineProgress {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "DailyRoutineProgress", recordID: recordID ?? CKRecord.ID())
        record["date"] = date
        record["routineType"] = routineType.rawValue
        record["startTime"] = startTime
        record["completionTime"] = completionTime
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        
        // Encode items as JSON
        do {
            let itemsData = try JSONEncoder().encode(items)
            record["items"] = itemsData
        } catch {
            print("Failed to encode routine items: \(error)")
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> DailyRoutineProgress? {
        guard let date = record["date"] as? Date,
              let routineTypeRaw = record["routineType"] as? String,
              let routineType = RoutineType(rawValue: routineTypeRaw) else {
            return nil
        }
        
        var progress = DailyRoutineProgress(date: date, routineType: routineType, templateItems: [])
        progress.recordID = record.recordID
        progress.startTime = record["startTime"] as? Date
        progress.completionTime = record["completionTime"] as? Date
        progress.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            progress.id = userID
        }
        
        // Decode items from JSON
        if let itemsData = record["items"] as? Data {
            do {
                progress.items = try JSONDecoder().decode([RoutineItem].self, from: itemsData)
            } catch {
                print("Failed to decode routine items: \(error)")
                progress.items = []
            }
        }
        
        return progress
    }
}

extension RoutineTemplate {
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "RoutineTemplate", recordID: recordID ?? CKRecord.ID())
        record["routineType"] = routineType.rawValue
        record["isEnabled"] = isEnabled ? 1 : 0
        record["lastModified"] = lastModified
        record["userID"] = id.uuidString
        
        // Encode items as JSON
        do {
            let itemsData = try JSONEncoder().encode(items)
            record["items"] = itemsData
        } catch {
            print("Failed to encode routine template items: \(error)")
        }
        
        return record
    }
    
    static func fromCKRecord(_ record: CKRecord) -> RoutineTemplate? {
        guard let routineTypeRaw = record["routineType"] as? String,
              let routineType = RoutineType(rawValue: routineTypeRaw) else {
            return nil
        }
        
        var template = RoutineTemplate(routineType: routineType)
        template.recordID = record.recordID
        template.isEnabled = (record["isEnabled"] as? Int ?? 1) == 1
        template.lastModified = record["lastModified"] as? Date ?? Date()
        
        if let userIDString = record["userID"] as? String,
           let userID = UUID(uuidString: userIDString) {
            template.id = userID
        }
        
        // Decode items from JSON
        if let itemsData = record["items"] as? Data {
            do {
                template.items = try JSONDecoder().decode([RoutineItem].self, from: itemsData)
            } catch {
                print("Failed to decode routine template items: \(error)")
                template.items = []
            }
        }
        
        return template
    }
}

// MARK: - Routine Manager
@MainActor
class RoutineManager: ObservableObject {
    @Published var templates: [RoutineTemplate] = []
    @Published var dailyProgress: [DailyRoutineProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    static let shared = RoutineManager()
    
    private var cloudKitManager: CloudKitManager {
        CloudKitManager.shared
    }
    
    init() {
        loadDefaultTemplates()
        createTodaysProgress()
    }
    
    // MARK: - Default Templates
    
    private func loadDefaultTemplates() {
        guard templates.isEmpty else { return }
        
        let morningTemplate = RoutineTemplate(
            routineType: .morning,
            items: [
                RoutineItem(title: "Drink water", estimatedMinutes: 2, sortOrder: 0),
                RoutineItem(title: "Make bed", estimatedMinutes: 3, sortOrder: 1),
                RoutineItem(title: "Brush teeth", estimatedMinutes: 3, sortOrder: 2),
                RoutineItem(title: "Exercise/Stretch", estimatedMinutes: 15, sortOrder: 3),
                RoutineItem(title: "Shower", estimatedMinutes: 10, sortOrder: 4),
                RoutineItem(title: "Get dressed", estimatedMinutes: 5, sortOrder: 5),
                RoutineItem(title: "Healthy breakfast", estimatedMinutes: 15, sortOrder: 6)
            ]
        )
        
        let eveningTemplate = RoutineTemplate(
            routineType: .evening,
            items: [
                RoutineItem(title: "Review today's goals", estimatedMinutes: 5, sortOrder: 0),
                RoutineItem(title: "Plan tomorrow", estimatedMinutes: 10, sortOrder: 1),
                RoutineItem(title: "Tidy up workspace", estimatedMinutes: 10, sortOrder: 2),
                RoutineItem(title: "Brush teeth", estimatedMinutes: 3, sortOrder: 3),
                RoutineItem(title: "Skincare routine", estimatedMinutes: 5, sortOrder: 4),
                RoutineItem(title: "Read/Journal", estimatedMinutes: 20, sortOrder: 5),
                RoutineItem(title: "Set out clothes for tomorrow", estimatedMinutes: 3, sortOrder: 6)
            ]
        )
        
        templates = [morningTemplate, eveningTemplate]
    }
    
    // MARK: - Daily Progress Management
    
    func createTodaysProgress() {
        let today = Calendar.current.startOfDay(for: Date())
        
        for template in templates where template.isEnabled {
            let existingProgress = dailyProgress.first { progress in
                Calendar.current.isDate(progress.date, equalTo: today, toGranularity: .day) &&
                progress.routineType == template.routineType
            }
            
            if existingProgress == nil {
                let newProgress = DailyRoutineProgress(
                    date: today,
                    routineType: template.routineType,
                    templateItems: template.items
                )
                dailyProgress.append(newProgress)
            }
        }
    }
    
    func getProgress(for date: Date, type: RoutineType) -> DailyRoutineProgress? {
        let targetDate = Calendar.current.startOfDay(for: date)
        return dailyProgress.first { progress in
            Calendar.current.isDate(progress.date, equalTo: targetDate, toGranularity: .day) &&
            progress.routineType == type
        }
    }
    
    func createProgressIfNeeded(for date: Date, type: RoutineType) {
        if getProgress(for: date, type: type) == nil {
            if let template = templates.first(where: { $0.routineType == type && $0.isEnabled }) {
                let newProgress = DailyRoutineProgress(
                    date: date,
                    routineType: type,
                    templateItems: template.items
                )
                dailyProgress.append(newProgress)
                
                // Sync to CloudKit in background
                Task {
                    do {
                        _ = try await cloudKitManager.saveDailyRoutineProgress(newProgress)
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Failed to sync routine progress: \(error.localizedDescription)"
                            self.showingError = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Updates


    func toggleRoutineItem(_ progressID: UUID, itemID: UUID) {
        // Force UI update with explicit objectWillChange
        objectWillChange.send()
        
        if let progressIndex = dailyProgress.firstIndex(where: { $0.id == progressID }),
           let itemIndex = dailyProgress[progressIndex].items.firstIndex(where: { $0.id == itemID }) {
            
            // Update the completion state
            dailyProgress[progressIndex].items[itemIndex].isCompleted.toggle()
            dailyProgress[progressIndex].lastModified = Date()
            
            // Track start time when first item is completed
            if dailyProgress[progressIndex].startTime == nil &&
               dailyProgress[progressIndex].items[itemIndex].isCompleted {
                dailyProgress[progressIndex].startTime = Date()
            }
            
            // Track completion time when all items are done
            if dailyProgress[progressIndex].isCompleted &&
               dailyProgress[progressIndex].completionTime == nil {
                dailyProgress[progressIndex].completionTime = Date()
            } else if !dailyProgress[progressIndex].isCompleted {
                // Reset completion time if we unchecked something
                dailyProgress[progressIndex].completionTime = nil
            }
            
            let updatedProgress = dailyProgress[progressIndex]
            
            // Force another UI update after the change
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            
            // Sync to CloudKit in background
            Task { [weak self] in
                guard let self = self else { return }
                
                do {
                    let savedProgress = try await self.cloudKitManager.saveDailyRoutineProgress(updatedProgress)
                    await MainActor.run {
                        // Update with the saved version
                        if let index = self.dailyProgress.firstIndex(where: { $0.id == savedProgress.id }) {
                            self.dailyProgress[index] = savedProgress
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync routine progress: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    // MARK: - Template Management
    
    func updateTemplate(_ template: RoutineTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            templates[index].lastModified = Date()
            
            let updatedTemplate = templates[index]
            
            // Sync to CloudKit
            Task {
                do {
                    _ = try await cloudKitManager.saveRoutineTemplate(updatedTemplate)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync routine template: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func addTemplateItem(_ templateID: UUID, item: RoutineItem) {
        if let index = templates.firstIndex(where: { $0.id == templateID }) {
            var newItem = item
            newItem.sortOrder = templates[index].items.count
            templates[index].items.append(newItem)
            templates[index].lastModified = Date()
            
            let updatedTemplate = templates[index]
            
            // Sync to CloudKit
            Task {
                do {
                    _ = try await cloudKitManager.saveRoutineTemplate(updatedTemplate)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync routine template: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    func removeTemplateItem(_ templateID: UUID, itemID: UUID) {
        if let templateIndex = templates.firstIndex(where: { $0.id == templateID }) {
            templates[templateIndex].items.removeAll { $0.id == itemID }
            
            // Reorder remaining items
            for (index, _) in templates[templateIndex].items.enumerated() {
                templates[templateIndex].items[index].sortOrder = index
            }
            
            templates[templateIndex].lastModified = Date()
            
            let updatedTemplate = templates[templateIndex]
            
            // Sync to CloudKit
            Task {
                do {
                    _ = try await cloudKitManager.saveRoutineTemplate(updatedTemplate)
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to sync routine template: \(error.localizedDescription)"
                        self.showingError = true
                    }
                }
            }
        }
    }
    
    // MARK: - CloudKit Sync
    
    func syncFromCloudKit() {
        Task {
            guard cloudKitManager.isAccountAvailable else { return }
            
            do {
                let cloudTemplates = try await cloudKitManager.fetchAllRoutineTemplates()
                let cloudProgress = try await cloudKitManager.fetchAllDailyRoutineProgress()
                
                await MainActor.run {
                    self.mergeTemplates(cloudTemplates)
                    self.mergeDailyProgress(cloudProgress)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func mergeTemplates(_ cloudTemplates: [RoutineTemplate]) {
        var mergedTemplates: [RoutineTemplate] = []
        var localTemplatesDict = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
        
        for cloudTemplate in cloudTemplates {
            if let localTemplate = localTemplatesDict[cloudTemplate.id] {
                mergedTemplates.append(cloudTemplate.lastModified > localTemplate.lastModified ? cloudTemplate : localTemplate)
                localTemplatesDict.removeValue(forKey: cloudTemplate.id)
            } else {
                mergedTemplates.append(cloudTemplate)
            }
        }
        
        for (_, localTemplate) in localTemplatesDict {
            mergedTemplates.append(localTemplate)
        }
        
        self.templates = mergedTemplates
    }
    
    private func mergeDailyProgress(_ cloudProgress: [DailyRoutineProgress]) {
        var mergedProgress: [DailyRoutineProgress] = []
        var localProgressDict = Dictionary(uniqueKeysWithValues: dailyProgress.map { ($0.id, $0) })
        
        for cloudProgressItem in cloudProgress {
            if let localProgressItem = localProgressDict[cloudProgressItem.id] {
                mergedProgress.append(cloudProgressItem.lastModified > localProgressItem.lastModified ? cloudProgressItem : localProgressItem)
                localProgressDict.removeValue(forKey: cloudProgressItem.id)
            } else {
                mergedProgress.append(cloudProgressItem)
            }
        }
        
        for (_, localProgressItem) in localProgressDict {
            mergedProgress.append(localProgressItem)
        }
        
        self.dailyProgress = mergedProgress
    }
    
    func forceSyncWithCloudKit() {
        syncFromCloudKit()
    }
}

// MARK: - CloudKit Manager Extensions
extension CloudKitManager {
    func saveDailyRoutineProgress(_ progress: DailyRoutineProgress) async throws -> DailyRoutineProgress {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        var updatedProgress = progress
        updatedProgress.lastModified = Date()
        
        let record = updatedProgress.toCKRecord()
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedProgress.recordID = savedRecord.recordID
            return updatedProgress
        } catch {
            throw CloudKitError.saveFailed(error)
        }
    }
    
    func saveRoutineTemplate(_ template: RoutineTemplate) async throws -> RoutineTemplate {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        var updatedTemplate = template
        updatedTemplate.lastModified = Date()
        
        let record = updatedTemplate.toCKRecord()
        
        do {
            let savedRecord = try await privateDatabase.save(record)
            updatedTemplate.recordID = savedRecord.recordID
            return updatedTemplate
        } catch {
            throw CloudKitError.saveFailed(error)
        }
    }
    
    func fetchAllRoutineTemplates() async throws -> [RoutineTemplate] {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "RoutineTemplate", predicate: predicate)
        
        let records = try await privateDatabase.records(matching: query)
        
        var templates: [RoutineTemplate] = []
        for (_, result) in records.matchResults {
            switch result {
            case .success(let record):
                if let template = RoutineTemplate.fromCKRecord(record) {
                    templates.append(template)
                }
            case .failure(let error):
                print("Failed to fetch routine template: \(error)")
            }
        }
        
        return templates
    }
    
    func fetchAllDailyRoutineProgress() async throws -> [DailyRoutineProgress] {
        guard isAccountAvailable else {
            throw CloudKitError.accountNotAvailable
        }
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "DailyRoutineProgress", predicate: predicate)
        
        let records = try await privateDatabase.records(matching: query)
        
        var progressList: [DailyRoutineProgress] = []
        for (_, result) in records.matchResults {
            switch result {
            case .success(let record):
                if let progress = DailyRoutineProgress.fromCKRecord(record) {
                    progressList.append(progress)
                }
            case .failure(let error):
                print("Failed to fetch routine progress: \(error)")
            }
        }
        
        return progressList
    }
}
