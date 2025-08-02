//
//  ContentView.swift
//  Calendar
//
//  Week view only - clean and focused
//

import SwiftUI
import CloudKit

struct ContentView: View {
    @State private var selectedDate = Date()
    @StateObject private var itemManager = ItemManager()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var routineManager = RoutineManager.shared
    @StateObject private var habitManager = HabitManager.shared
    @StateObject private var mealManager = MealManager.shared
    @State private var showingCloudKitTest = false
    @State private var showingCategoryManagement = false
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            VStack(spacing: 0) {
                
                VStack(spacing: 12) {
                    HStack {
                        Text(weekTitle)
                            .font(.system(.title2, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                navigateWeek(.previous)
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title3)
                                    .foregroundColor(Color("Accent1"))
                            }
                            
                            Button(action: {
                                navigateWeek(.next)
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .foregroundColor(Color("Accent1"))
                            }
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                        
                        Button("Today") {
                            selectedDate = Date()
                        }
                        .font(.system(size: 12))
                     //   .fontWeight(.medium)
                        .foregroundColor(Color("Accent1"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color("Accent1"), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 32)
                    
                    // Week View
                    WeekCalendarView(selectedDate: $selectedDate)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
                .background(Color("Background").opacity(0.95))
                
                // Main Content Area
                ScrollView {
                    VStack(spacing: 16) {
                        // Content Cards for selected date
                        VStack(spacing: 16) {
                            // Date display
                            HStack {
                                Text(selectedDateString())
                                    .font(.system(.title3, design: .default))
                                  //  .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            
                            // Routine Cards - only show for today or future dates
                            if !selectedDate.isInPast {
                                RoutineCardsView(selectedDate: selectedDate)
                                    .padding(.horizontal, 20)
                            }
                            
                            // Habit Card
                            HabitCardView(selectedDate: selectedDate)
                                .padding(.horizontal, 20)
                            
                            // Meal Card
                            MealCardView(selectedDate: selectedDate)
                                .padding(.horizontal, 20)
                            
                            // Items List
                            ItemListView(itemManager: itemManager, selectedDate: selectedDate)
                            
                            // Extra space at bottom
                            Color.clear
                                .frame(height: 100)
                        }
                    }
                }
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
        .alert("Habit Sync Error", isPresented: $habitManager.showingError) {
            Button("OK") {
                habitManager.showingError = false
            }
            Button("Retry") {
                habitManager.forceSyncWithCloudKit()
                habitManager.showingError = false
            }
        } message: {
            Text(habitManager.errorMessage ?? "An unknown error occurred")
        }
        .alert("Meal Sync Error", isPresented: $mealManager.showingError) {
            Button("OK") {
                mealManager.showingError = false
            }
            Button("Retry") {
                mealManager.forceSyncWithCloudKit()
                mealManager.showingError = false
            }
        } message: {
            Text(mealManager.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            cloudKitManager.checkAccountStatus()
            categoryManager.forceSyncWithCloudKit()
            routineManager.forceSyncWithCloudKit()
            habitManager.forceSyncWithCloudKit()
            mealManager.forceSyncWithCloudKit()
        }
    }
    
    // MARK: - Week Navigation
    
    private var weekTitle: String {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate)
        
        guard let startOfWeek = weekInterval?.start,
              let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) else {
            return "This Week"
        }
        
        let formatter = DateFormatter()
        
        // If the week spans different months
        if !calendar.isDate(startOfWeek, equalTo: endOfWeek, toGranularity: .month) {
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: startOfWeek)
            formatter.dateFormat = "MMM d, yyyy"
            let endString = formatter.string(from: endOfWeek)
            return "\(startString) - \(endString)"
        } else {
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: startOfWeek)
            let endDay = calendar.component(.day, from: endOfWeek)
            formatter.dateFormat = "yyyy"
            let year = formatter.string(from: endOfWeek)
            return "\(startString) - \(endDay), \(year)"
        }
    }
    
    private func navigateWeek(_ direction: CalendarSwipeDirection) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .weekOfYear, value: direction.monthIncrement, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    // MARK: - CloudKit Status Helpers (removed from UI but keeping for functionality)
    
    private var cloudKitStatusIcon: String {
        if itemManager.isLoading || habitManager.isLoading || mealManager.isLoading {
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
        if itemManager.isLoading || habitManager.isLoading || mealManager.isLoading {
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
    
    // MARK: - Helper Methods
    
    private func selectedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
}

// MARK: - Week Calendar View
struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    
    private var weekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        
        var dates: [Date] = []
        var date = weekInterval.start
        
        for _ in 0..<7 {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        return dates
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDates, id: \.self) { date in
                WeekDayView(
                    date: date,
                    selectedDate: $selectedDate,
                    isSelected: calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
                )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if abs(value.translation.width) > threshold && abs(value.translation.height) < 30 {
                        if value.translation.width > threshold {
                            // Swipe right - previous week
                            if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
                                selectedDate = newDate
                            }
                        } else if value.translation.width < -threshold {
                            // Swipe left - next week
                            if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
                                selectedDate = newDate
                            }
                        }
                    }
                }
        )
    }
}

// MARK: - Week Day View
struct WeekDayView: View {
    let date: Date
    @Binding var selectedDate: Date
    let isSelected: Bool
    
    private let calendar = Calendar.current
    
    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    private var dayNumber: String {
        return "\(calendar.component(.day, from: date))"
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = date
            }
        }) {
            VStack(spacing: 6) {
                Text(dayLetter)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(dayNumber)
                    .font(.system(size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color("Accent1") : (isToday ? Color("Accent1").opacity(0.15) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isToday && !isSelected ? Color("Accent1").opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Calendar Swipe Direction (for week navigation)
enum CalendarSwipeDirection {
    case next, previous
    
    var monthIncrement: Int {
        switch self {
        case .next: return 1
        case .previous: return -1
        }
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
