import SwiftUI
import CloudKit

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @StateObject private var itemManager = ItemManager()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var showingCloudKitTest = false
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            VStack(spacing: 0) {
                
//                // Top status bar
//                HStack {
////                    // CloudKit Status Indicator
////                    HStack(spacing: 4) {
////                        Image(systemName: cloudKitStatusIcon)
////                            .foregroundColor(cloudKitStatusColor)
////                            .font(.caption)
////
////                        if itemManager.isLoading {
////                            ProgressView()
////                                .scaleEffect(0.6)
////                        }
////                    }
////                    .onTapGesture {
////                        if cloudKitManager.isAccountAvailable {
////                            itemManager.forceSyncWithCloudKit()
////                        } else {
////                            showingCloudKitTest = true
////                        }
////                    }
////
////                    // CloudKit Test Button (keep for debugging)
////                    Button("CloudKit Test") {
////                        showingCloudKitTest = true
////                    }
////                    .font(.caption)
////                    .padding(.horizontal, 8)
////                    .padding(.vertical, 4)
////                    .background(Color.blue.opacity(0.2))
////                    .cornerRadius(4)
//
//                    Spacer()
//
//                    // Last sync indicator
//                    if let lastSync = itemManager.lastSyncDate {
//                        Text("Synced \(timeAgoString(from: lastSync))")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                }
//                .padding(.horizontal)
//                .padding(.top)
//
                // Calendar with carousel functionality
                CalendarGridView(
                    currentMonth: currentMonth,
                    selectedDate: $selectedDate,
                    onMonthChange: { direction in
                        handleMonthChange(direction: direction)
                    },
                    onDateJump: { date in
                        handleDateJump(to: date)
                    }
                )
                .padding(.top, 20)
            
//                Text("Active container: \(CKContainer(identifier: "iCloud.com.estes.Dev").containerIdentifier ?? "nil")")
//                Text("Environment: Development")
//                    .font(.caption)
//                    .foregroundColor(.secondary)

                // Selected date display
                HStack {
                    Text(selectedDateString())
                        .font(.system(.title3, design: .serif))
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    Spacer()
                }
                .padding()
                
                ItemListView(itemManager: itemManager, selectedDate: selectedDate)
                    .frame(maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingCloudKitTest) {
            CloudKitTestView()
        }
        .alert("Sync Error", isPresented: $itemManager.showingError) {
            Button("OK") {
                itemManager.showingError = false
            }
            Button("Retry") {
                itemManager.forceSyncWithCloudKit()
                itemManager.showingError = false
            }
        } message: {
            Text(itemManager.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            // Check CloudKit status when app appears
            cloudKitManager.checkAccountStatus()
        }
    }
    
    // MARK: - Month Navigation
    
    private func handleMonthChange(direction: CalendarGridView.SwipeDirection) {
        let increment = direction.monthIncrement
        if let newMonth = Calendar.current.date(byAdding: .month, value: increment, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    // MARK: - Date Jump Navigation
    
    private func handleDateJump(to date: Date) {
        currentMonth = Calendar.current.startOfDay(for: date)
        selectedDate = date
    }
    
    // MARK: - CloudKit Status Helpers
    
    private var cloudKitStatusIcon: String {
        if itemManager.isLoading {
            return "arrow.clockwise"
        }
        
        switch cloudKitManager.accountStatus {
        case .available:
            return "icloud"
        case .noAccount:
            return "icloud.slash"
        case .restricted:
            return "exclamationmark.icloud"
        default:
            return "questionmark.circle"
        }
    }
    
    private var cloudKitStatusColor: Color {
        if itemManager.isLoading {
            return .blue
        }
        
        switch cloudKitManager.accountStatus {
        case .available:
            return .green
        case .noAccount:
            return .red
        case .restricted:
            return .orange
        default:
            return .gray
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Helper Methods
    
    private func selectedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
}

#Preview {
    ContentView()
}
