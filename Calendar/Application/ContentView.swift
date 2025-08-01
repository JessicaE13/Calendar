import SwiftUI
import CloudKit

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var calendarOffset: CGFloat = 0
    @State private var isAnimatingMonthChange = false
    @StateObject private var itemManager = ItemManager()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var showingCloudKitTest = false
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            VStack(spacing: 0) {
                
                HStack {
                    // CloudKit Status Indicator
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
                        } else {
                            showingCloudKitTest = true
                        }
                    }
                    
                    // CloudKit Test Button (keep for debugging)
                    Button("CloudKit Test") {
                        showingCloudKitTest = true
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(monthYearString(from: currentMonth))
                        .font(.system(.title, design: .serif))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding()
                
                CalendarGridView(
                    currentMonth: currentMonth,
                    selectedDate: $selectedDate
                )
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width < -50 {
                                animateMonthChange(direction: .next)
                            } else if value.translation.width > 50 {
                                animateMonthChange(direction: .previous)
                            }
                        }
                )
                
                Text("Entitlements container: \(CKContainer.default().containerIdentifier ?? "nil")")
                Text("Explicit container: \(CKContainer(identifier: "iCloud.com.estes.Dev").containerIdentifier ?? "nil")")

                
                HStack {
                    Text(selectedDateString())
                        .font(.system(.title3, design: .serif))
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    Spacer()
                    
                    // Last sync indicator
                    if let lastSync = itemManager.lastSyncDate {
                        Text("Synced \(timeAgoString(from: lastSync))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
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
    
    // MARK: - Existing Methods
    
    private func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    private func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func selectedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
    
    enum SwipeDirection {
        case next, previous
    }
    
    private func animateMonthChange(direction: SwipeDirection) {
        guard !isAnimatingMonthChange else { return }
        isAnimatingMonthChange = true
        
        let directionMultiplier: CGFloat = (direction == .next) ? -1 : 1
        
        // Move out
        withAnimation(.easeInOut(duration: 0.25)) {
            calendarOffset = directionMultiplier * UIScreen.main.bounds.width
            isAnimatingMonthChange = true
        }
        
        // Wait for animation, then switch month and animate back in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if direction == .next {
                nextMonth()
            } else {
                previousMonth()
            }
            calendarOffset = -directionMultiplier * UIScreen.main.bounds.width
            
            // Animate back in
            withAnimation(.easeInOut(duration: 0.25)) {
                calendarOffset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isAnimatingMonthChange = false
            }
        }
    }
}

#Preview {
    ContentView()
}
