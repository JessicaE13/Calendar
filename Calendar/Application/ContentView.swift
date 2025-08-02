//
//  Updated ContentView.swift
//  Calendar completely outside ScrollView with proper pinning
//

import SwiftUI
import CloudKit

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @StateObject private var itemManager = ItemManager()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var routineManager = RoutineManager.shared
    @StateObject private var habitManager = HabitManager.shared
    @StateObject private var mealManager = MealManager.shared
    @State private var showingCloudKitTest = false
    @State private var showingCategoryManagement = false
    
    // Calendar state management
    @State private var scrollOffset: CGFloat = 0
    @State private var isCalendarPinned = false
    
    // Thresholds for pinning behavior
    private let pinThreshold: CGFloat = -100 // When to start pinning
    private let unpinThreshold: CGFloat = -50 // When to unpin when scrolling down
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            VStack(spacing: 0) {
                
                // Top toolbar - ALWAYS FIXED AT TOP
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
                    
                    // CloudKit status indicator
                    HStack(spacing: 4) {
                        Image(systemName: cloudKitStatusIcon)
                            .foregroundColor(cloudKitStatusColor)
                            .font(.caption)
                        
                        if itemManager.isLoading || habitManager.isLoading || mealManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                    .onTapGesture {
                        if cloudKitManager.isAccountAvailable {
                            itemManager.forceSyncWithCloudKit()
                            categoryManager.forceSyncWithCloudKit()
                            routineManager.forceSyncWithCloudKit()
                            habitManager.forceSyncWithCloudKit()
                            mealManager.forceSyncWithCloudKit()
                        } else {
                            showingCloudKitTest = true
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color("Background").opacity(0.95))
                .zIndex(1002)
                
                // Calendar - ALWAYS OUTSIDE SCROLLVIEW
                if isCalendarPinned {
                    // Pinned Week Calendar
                    PinnedWeekCalendarView(
                        currentMonth: currentMonth,
                        selectedDate: $selectedDate,
                        onMonthChange: { direction in
                            handleMonthChange(direction: direction)
                        },
                        onDateJump: { date in
                            handleDateJump(to: date)
                        },
                        onUnpin: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isCalendarPinned = false
                            }
                        }
                    )
                    .background(Color("Background").opacity(0.95))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .zIndex(1001)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                } else {
                    // Full Calendar
                    FullCalendarView(
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
                    .background(Color("Background").opacity(0.7))
                    .zIndex(1001)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // SCROLLABLE CONTENT - NO CALENDAR INSIDE
                ScrollView {
                    VStack(spacing: 0) {
                        
                        // Selected date display
                        HStack {
                            Text(selectedDateString())
                                .font(.system(.title3, design: .serif))
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                            
                            Spacer()
                        }
                        .background(Color("Background").opacity(0.7))
                        
                        // Main content cards
                        VStack(spacing: 16) {
                            // Routine Cards - only show for today or future dates
                            if !selectedDate.isInPast {
                                RoutineCardsView(selectedDate: selectedDate)
                                    .padding(.horizontal, 20)
                            }
                            
                            // Habit Card - show for all dates
                            HabitCardView(selectedDate: selectedDate)
                                .padding(.horizontal, 20)
                            
                            // Meal Card - show for all dates
                            MealCardView(selectedDate: selectedDate)
                                .padding(.horizontal, 20)
                            
                            // Items List
                            ItemListView(itemManager: itemManager, selectedDate: selectedDate)
                            
                            // Extra space at bottom for better scrolling
                            Color.clear
                                .frame(height: 200)
                        }
                        .background(Color("Background").opacity(0.7))
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self,
                                          value: geometry.frame(in: .named("scroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                    updatePinnedState()
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
    
    // MARK: - Calendar State Management
    
    private func updatePinnedState() {
        let shouldPin: Bool
        
        if isCalendarPinned {
            // Already pinned - check if we should unpin (scrolled down enough)
            shouldPin = scrollOffset < unpinThreshold
        } else {
            // Not pinned - check if we should pin (scrolled up enough)
            shouldPin = scrollOffset < pinThreshold
        }
        
        if shouldPin != isCalendarPinned {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCalendarPinned = shouldPin
            }
        }
    }
    
    // MARK: - Month Navigation
    
    private func handleMonthChange(direction: CalendarSwipeDirection) {
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

// MARK: - Full Calendar View (Normal State)
struct FullCalendarView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let onMonthChange: (CalendarSwipeDirection) -> Void
    let onDateJump: ((Date) -> Void)?
    
    // State for date picker
    @State private var showingDatePicker = false
    @State private var pickerDate: Date
    
    private let calendar = Calendar.current
    private let daySize: CGFloat = 36
    private let gridSpacing: CGFloat = 4
    private let horizontalPadding: CGFloat = 16
    
    init(currentMonth: Date, selectedDate: Binding<Date>, onMonthChange: @escaping (CalendarSwipeDirection) -> Void, onDateJump: ((Date) -> Void)? = nil) {
        self.currentMonth = currentMonth
        self._selectedDate = selectedDate
        self.onMonthChange = onMonthChange
        self.onDateJump = onDateJump
        self._pickerDate = State(initialValue: currentMonth)
    }
    
    private let dayHeaders = [
        (id: 0, letter: "S"), (id: 1, letter: "M"), (id: 2, letter: "T"),
        (id: 3, letter: "W"), (id: 4, letter: "T"), (id: 5, letter: "F"), (id: 6, letter: "S")
    ]
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var weeks: [[Date?]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end) else {
            return []
        }
        
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = []
        
        let startDate = monthFirstWeek.start
        let endDate = monthLastWeek.end
        
        var date = startDate
        while date < endDate {
            let dateToAdd: Date? = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month) ? date : nil
            currentWeek.append(dateToAdd)
            
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        return weeks
    }
    
    private func goToToday() {
        let today = Date()
        selectedDate = today
        
        if !calendar.isDate(currentMonth, equalTo: today, toGranularity: .month) {
            onDateJump?(today)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header
            HStack {
                Button(action: {
                    pickerDate = currentMonth
                    showingDatePicker = true
                }) {
                    Text(monthYearString)
                        .font(.system(.title, design: .serif))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                HStack(spacing: 0) {
                    Button(action: { onMonthChange(.previous) }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(Color("Accent1"))
                    }
                    
                    Button(action: goToToday) {
                        Text("Today")
                            .font(.system(size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(Color("Accent1"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color("Accent1"), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 4)
                    
                    Button(action: { onMonthChange(.next) }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(Color("Accent1"))
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            .padding(.bottom, 12)
            
            // Day headers
            HStack {
                ForEach(dayHeaders, id: \.id) { dayHeader in
                    Text(dayHeader.letter)
                        .font(.system(size: 12))
                        .fontWeight(.semibold)
                        .tracking(0.5)
                        .foregroundColor(.primary.opacity(0.8))
                        .frame(width: daySize)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 6)
            
            Divider()
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 6)
            
            // Full month grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(daySize)), count: 7), spacing: gridSpacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                    ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, date in
                        if let date = date {
                            CompactCalendarDayView(
                                date: date,
                                currentMonth: currentMonth,
                                selectedDate: $selectedDate,
                                daySize: daySize
                            )
                        } else {
                            Color.clear
                                .frame(width: daySize, height: daySize)
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let horizontalSwipeThreshold: CGFloat = 50
                    if abs(value.translation.width) > horizontalSwipeThreshold && abs(value.translation.height) < 30 {
                        if value.translation.width > horizontalSwipeThreshold {
                            onMonthChange(.previous)
                        } else if value.translation.width < -horizontalSwipeThreshold {
                            onMonthChange(.next)
                        }
                    }
                }
        )
        .sheet(isPresented: $showingDatePicker) {
            // Date picker sheet
            VStack(spacing: 30) {
                HStack {
                    Spacer()
                    Button("✕") { showingDatePicker = false }
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Text("Jump to Date")
                    .font(.title2)
                    .fontWeight(.bold)
                
                DatePicker("Select Date", selection: $pickerDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .padding(.horizontal, 20)
                
                Button("Go to Date") {
                    onDateJump?(pickerDate)
                    showingDatePicker = false
                }
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color("Accent1"))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .presentationDetents([.height(400)])
        }
    }
}

// MARK: - Pinned Week Calendar View (Compact State)
struct PinnedWeekCalendarView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let onMonthChange: (CalendarSwipeDirection) -> Void
    let onDateJump: ((Date) -> Void)?
    let onUnpin: () -> Void
    
    private let calendar = Calendar.current
    private let daySize: CGFloat = 32
    private let horizontalPadding: CGFloat = 16
    
    // Get current week containing selected date
    private var currentWeek: [Date?] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        
        var week: [Date?] = []
        var date = weekInterval.start
        
        for _ in 0..<7 {
            week.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        return week
    }
    
    private var weekDateRange: String {
        guard let firstDate = currentWeek.compactMap({ $0 }).first,
              let lastDate = currentWeek.compactMap({ $0 }).last else {
            return ""
        }
        
        let formatter = DateFormatter()
        
        // If the week spans different months
        if !calendar.isDate(firstDate, equalTo: lastDate, toGranularity: .month) {
            formatter.dateFormat = "MMM d"
            let firstString = formatter.string(from: firstDate)
            formatter.dateFormat = "MMM d, yyyy"
            let lastString = formatter.string(from: lastDate)
            return "\(firstString) - \(lastString)"
        } else {
            formatter.dateFormat = "MMM d"
            let firstString = formatter.string(from: firstDate)
            let lastDay = calendar.component(.day, from: lastDate)
            formatter.dateFormat = "yyyy"
            let year = formatter.string(from: lastDate)
            return "\(firstString) - \(lastDay), \(year)"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Compact header with week range
            HStack {
                Button(action: { onMonthChange(.previous) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16))
                        .foregroundColor(Color("Accent1"))
                }
                
                Text(weekDateRange)
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Expand") {
                    onUnpin()
                }
                .font(.system(size: 12))
                .foregroundColor(Color("Accent1"))
                
                Button(action: { onMonthChange(.next) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(Color("Accent1"))
                }
            }
            .padding(.horizontal, horizontalPadding)
            
            // Week view
            HStack(spacing: 4) {
                ForEach(Array(currentWeek.enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        CompactCalendarDayView(
                            date: date,
                            currentMonth: currentMonth,
                            selectedDate: $selectedDate,
                            daySize: daySize
                        )
                    } else {
                        Color.clear
                            .frame(width: daySize, height: daySize)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
        .padding(.vertical, 8)
        .gesture(
            DragGesture()
                .onEnded { value in
                    let horizontalSwipeThreshold: CGFloat = 50
                    if abs(value.translation.width) > horizontalSwipeThreshold && abs(value.translation.height) < 30 {
                        if value.translation.width > horizontalSwipeThreshold {
                            onMonthChange(.previous)
                        } else if value.translation.width < -horizontalSwipeThreshold {
                            onMonthChange(.next)
                        }
                    }
                }
        )
    }
}

// MARK: - Compact Calendar Day View
struct CompactCalendarDayView: View {
    let date: Date
    let currentMonth: Date
    @Binding var selectedDate: Date
    let daySize: CGFloat
    
    private let calendar = Calendar.current
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var isSelected: Bool {
        calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: {
            selectedDate = date
        }) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: daySize, height: daySize)
                    .overlay(
                        Circle()
                            .stroke(Color("Accent1"), lineWidth: isToday ? 1.0 : 0)
                    )
                
                Text(dayString)
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundColor(textColor)
                    .frame(width: daySize - 6)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        return isSelected ? .white :  .primary.opacity(0.7)
    }
    
    private var backgroundColor: Color {
        return isSelected ? Color("Accent1") : .clear
    }
}

// MARK: - Preference Keys
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
