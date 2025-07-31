//
//  CloudKitTestView.swift
//  Add this file to your project to test CloudKit connection
//

import SwiftUI
import CloudKit

struct CloudKitTestView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var testResults: [String] = []
    @State private var isRunningTest = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Account Status Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("CloudKit Status")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        Text(statusText)
                            .font(.body)
                    }
                    
                    Text("Container: \(CKContainer.default().containerIdentifier ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Test Results Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Results")
                        .font(.headline)
                    
                    if testResults.isEmpty {
                        Text("Tap 'Run CloudKit Test' to check connection")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                                    Text("\(index + 1). \(result)")
                                        .font(.caption)
                                        .foregroundColor(result.contains("✅") ? .green :
                                                       result.contains("❌") ? .red : .primary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 200)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Test Buttons
                VStack(spacing: 12) {
                    Button(action: runBasicTest) {
                        HStack {
                            if isRunningTest {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "play.circle")
                            }
                            Text("Run CloudKit Test")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isRunningTest)
                    
                    Button(action: createSchema) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create CloudKit Schema")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isRunningTest || !cloudKitManager.isAccountAvailable)
                    
                    Button(action: clearResults) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Results")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("CloudKit Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            cloudKitManager.checkAccountStatus()
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusIcon: String {
        switch cloudKitManager.accountStatus {
        case .available:
            return "checkmark.circle.fill"
        case .noAccount:
            return "xmark.circle.fill"
        case .restricted:
            return "exclamationmark.triangle.fill"
        case .couldNotDetermine, .temporarilyUnavailable:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch cloudKitManager.accountStatus {
        case .available:
            return .green
        case .noAccount, .restricted:
            return .red
        case .couldNotDetermine, .temporarilyUnavailable:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var statusText: String {
        switch cloudKitManager.accountStatus {
        case .available:
            return "✅ iCloud Available"
        case .noAccount:
            return "❌ No iCloud Account"
        case .restricted:
            return "⚠️ iCloud Restricted"
        case .couldNotDetermine:
            return "❓ Could Not Determine"
        case .temporarilyUnavailable:
            return "🔄 Temporarily Unavailable"
        @unknown default:
            return "❓ Unknown Status"
        }
    }
    
    // MARK: - Test Functions
    
    private func runBasicTest() {
        isRunningTest = true
        testResults.removeAll()
        
        Task {
            await performCloudKitTests()
            await MainActor.run {
                isRunningTest = false
            }
        }
    }
    
    private func performCloudKitTests() async {
        // Test 1: Account Status
        addResult("Checking iCloud account status...")
        cloudKitManager.checkAccountStatus()
        
        // Wait a moment for account status to update
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        } catch {
            // Sleep was cancelled, continue anyway
        }
        
        addResult(cloudKitManager.isAccountAvailable ?
                 "✅ iCloud account is available" :
                 "❌ iCloud account not available")
        
        // Test 2: Container Access
        addResult("Testing CloudKit container access...")
        let container = CKContainer.default()
        addResult("✅ CloudKit container accessible: \(container.containerIdentifier ?? "Unknown")")
        
        // Test 3: Database Access (only if account is available)
        if cloudKitManager.isAccountAvailable {
            addResult("Testing private database access...")
            do {
                let database = CKContainer.default().privateCloudDatabase
                
                // Try a simple query that should work even with no records
                let query = CKQuery(recordType: "Item", predicate: NSPredicate(value: false))
                let _ = try await database.records(matching: query)
                addResult("✅ Private database accessible")
            } catch {
                addResult("❌ Database access error: \(error.localizedDescription)")
                addResult("ℹ️ This might be normal if schema isn't set up yet")
            }
        } else {
            addResult("⏩ Skipping database test (no iCloud account)")
        }
        
        // Test 4: CloudKit Manager Functions
        addResult("Testing CloudKitManager functions...")
        do {
            // This should fail gracefully if no account or schema
            let _ = try await cloudKitManager.fetchAllItems()
            addResult("✅ CloudKitManager.fetchAllItems() executed")
        } catch {
            addResult("⚠️ CloudKitManager error: \(error.localizedDescription)")
            addResult("ℹ️ This is expected if CloudKit schema isn't set up yet")
        }
        
        addResult("🎉 Test completed!")
    }
    
    private func addResult(_ result: String) {
        testResults.append(result)
    }
    
    private func clearResults() {
        testResults.removeAll()
    }
    
    private func createSchema() {
        isRunningTest = true
        testResults.removeAll()
        
        Task {
            await createCloudKitSchema()
            await MainActor.run {
                isRunningTest = false
            }
        }
    }
    
    private func createCloudKitSchema() async {
        addResult("🚀 Creating CloudKit schema...")
        
        // Create a sample item to establish the schema
        let sampleItem = Item(
            title: "Schema Test Item",
            description: "This item creates the CloudKit schema",
            assignedDate: Date(),
            sortOrder: 0
        )
        
        addResult("📝 Creating sample item record...")
        
        do {
            _ = try await cloudKitManager.saveItem(sampleItem)
            addResult("✅ Successfully created Item record type!")
            addResult("✅ CloudKit schema is now set up!")
            addResult("🗑️ You can delete the test item from CloudKit Console if you want")
            addResult("🎉 Your app can now sync items to iCloud!")
        } catch {
            addResult("❌ Schema creation failed: \(error.localizedDescription)")
            if error.localizedDescription.contains("UnknownItem") {
                addResult("ℹ️ This means the record type doesn't exist yet")
                addResult("💡 Try going to CloudKit Console to set up manually")
            }
        }
    }
}

#Preview {
    CloudKitTestView()
}
