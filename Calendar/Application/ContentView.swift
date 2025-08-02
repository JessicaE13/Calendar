import SwiftUI
import CloudKit

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @StateObject private var itemManager = ItemManager()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var routineManager = RoutineManager.shared
    @State private var showingCloudKitTest = false
    @State private var showingCategoryManagement = false
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            VStack(spacing: 0) {
                
                // Top toolbar with category management
                HStack {
                    Button(action: {
                        showingCategoryManagement = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 16))
                            Text("Categories")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(Color("Accent1"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color("Accent1"), lineWidth: 1)
                                .fill(Color("Accent1").opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // CloudKit status indicator (optional - keep if you want it)
                    HStack(spacing: 4) {
                        Image(systemName: cloudKitStatusIcon)
                            .foregroundColor(cloudKitStatusColor)
                            .font(.caption)
                        
                        if itemManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                    .onTapGesture {
                        if cloudKitManager.isAccountAvailable {
                            itemManager.forceSyncWithCloudKit()
                            categoryManager.forceSyncWithCloudKit()
                            routineManager.forceSyncWithCloudKit()
                        } else {
                            showingCloudKitTest = true
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
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
                .padding(.top, 12)

                // Selected date display
                HStack {
                    Text(selectedDateString())
                        .font(.system(.title3, design: .serif))
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Main content area with scroll
                ScrollView {
                    VStack(spacing: 16) {
                        // Routine Cards - only show for today or future dates
                        if !selectedDate.isInPast {
                            RoutineCardsView(selectedDate: selectedDate)
                                .padding(.horizontal, 20)
                        }
                        
                        // Items List
                        ItemListView(itemManager: itemManager, selectedDate: selectedDate)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingCloudKitTest) {
            CloudKitTestView()
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(
                categoryManager: categoryManager,
                isPresented: $showingCategoryManagement
            )
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
            // Sync all managers
            categoryManager.forceSyncWithCloudKit()
            routineManager.forceSyncWithCloudKit()
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

// MARK: - Date Extension for Past Check
extension Date {
    var isInPast: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let thisDate = calendar.startOfDay(for: self)
        return thisDate < today
    }
}

#Preview {
    ContentView()
}
