//
//  Updated ContentView.swift
//  Simple progressive scroll-based calendar collapse
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
    
    // Scroll-to-collapse state
    @State private var scrollOffset: CGFloat = 0
    
    // Calculate collapse state based on scroll position
    private var isCalendarCollapsed: Bool {
        return scrollOffset < -100 // Collapse when scrolled up 100 points
    }
    
    // Calculate progressive collapse amount (0.0 = fully expanded, 1.0 = fully collapsed)
    private var collapseProgress: CGFloat {
        let startCollapse: CGFloat = -50  // Start collapsing at 50 points up
        let fullyCollapsed: CGFloat = -150 // Fully collapsed at 150 points up
        
        if scrollOffset > startCollapse {
            return 0.0 // Not collapsed at all
        } else if scrollOffset < fullyCollapsed {
            return 1.0 // Fully collapsed
        } else {
            // Progressive collapse between start and end points
            let progress = (startCollapse - scrollOffset) / (startCollapse - fullyCollapsed)
            return min(max(progress, 0.0), 1.0)
        }
    }
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            VStack(spacing: 0) {
                
                // Top toolbar - FIXED AT TOP
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
                .zIndex(1000)
                
                // EVERYTHING ELSE IS SCROLLABLE
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        
                        // Calendar - SCROLLS AND COLLAPSES PROGRESSIVELY
                        ProgressiveCalendarView(
                            currentMonth: currentMonth,
                            selectedDate: $selectedDate,
                            collapseProgress: collapseProgress,
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
                            
                            // Habit Card - show for all dates (past habits are read-only)
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
                    // Debug output
                    print("📍 Scroll offset: \(value), collapse progress: \(collapseProgress)")
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

// MARK: - Progressive Calendar View
struct ProgressiveCalendarView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let collapseProgress: CGFloat
    let onMonthChange: (CalendarGridView.SwipeDirection) -> Void
    let onDateJump: ((Date) -> Void)?
    
    // State for date picker
    @State private var showingDatePicker = false
    @State private var pickerDate: Date
    
    private let calendar = Calendar.current
    private let daySize: CGFloat = 36
    private let gridSpacing: CGFloat = 4
    private let horizontalPadding: CGFloat = 16
    
    init(currentMonth: Date, selectedDate: Binding<Date>, collapseProgress: CGFloat, onMonthChange: @escaping (CalendarGridView.SwipeDirection) -> Void, onDateJump: ((Date) -> Void)? = nil) {
        self.currentMonth = currentMonth
        self._selectedDate = selectedDate
        self.collapseProgress = collapseProgress
        self.onMonthChange = onMonthChange
        self.onDateJump = onDateJump
        self._pickerDate = State(initialValue: currentMonth)
    }
    
    // Day headers
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
    
    // Get current week for collapsed view
    private var currentWeek: [Date?] {
        let selectedWeekIndex = weeks.firstIndex { week in
            week.contains { date in
                guard let date = date else { return false }
                return calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
            }
        } ?? 0
        
        return selectedWeekIndex < weeks.count ? weeks[selectedWeekIndex] : []
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
            
            // Header - scales down as we collapse
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
                .scaleEffect(1.0 - (collapseProgress * 0.3)) // Shrink header as we collapse
                
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
                    .scaleEffect(1.0 - (collapseProgress * 0.5)) // Shrink more aggressively
                    .opacity(1.0 - collapseProgress) // Fade out completely
                    
                    Button(action: { onMonthChange(.next) }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(Color("Accent1"))
                    }
                }
                .padding(.horizontal, horizontalPadding)
            }
            .padding(.bottom, 12 * (1.0 - collapseProgress)) // Reduce bottom padding
            .opacity(1.0 - (collapseProgress * 0.3)) // Slight fade
            
            // Day headers - fade out as we collapse
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
            .padding(.bottom, 6 * (1.0 - collapseProgress))
            .opacity(1.0 - (collapseProgress * 0.5))
            
            // Divider - fade out
            Divider()
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 6 * (1.0 - collapseProgress))
                .opacity(1.0 - collapseProgress)
            
            // Calendar grid with progressive collapse
            Group {
                if collapseProgress < 0.5 {
                    // Show full month, progressively hiding rows
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
                                    .opacity(getWeekOpacity(weekIndex: weekIndex))
                                    .scaleEffect(getWeekScale(weekIndex: weekIndex))
                                } else {
                                    Color.clear
                                        .frame(width: daySize, height: daySize)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                } else {
                    // Show only current week when heavily collapsed
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(daySize)), count: 7), spacing: gridSpacing) {
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
            }
            .animation(.easeInOut(duration: 0.3), value: collapseProgress)
        }
        .background(Color("Background").opacity(0.7))
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
            // Date picker sheet (same as before)
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
    
    // Calculate opacity for each week row based on collapse progress
    private func getWeekOpacity(weekIndex: Int) -> Double {
        let selectedWeekIndex = weeks.firstIndex { week in
            week.contains { date in
                guard let date = date else { return false }
                return calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
            }
        } ?? 0
        
        // Keep selected week fully visible, fade others based on distance
        let distance = abs(weekIndex - selectedWeekIndex)
        let maxDistance = max(selectedWeekIndex, weeks.count - 1 - selectedWeekIndex)
        
        if distance == 0 {
            return 1.0 // Selected week always visible
        } else {
            let fadeAmount = collapseProgress * Double(distance) / Double(max(maxDistance, 1))
            return 1.0 - min(fadeAmount, 1.0)
        }
    }
    
    // Calculate scale for each week row
    private func getWeekScale(weekIndex: Int) -> Double {
        let selectedWeekIndex = weeks.firstIndex { week in
            week.contains { date in
                guard let date = date else { return false }
                return calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
            }
        } ?? 0
        
        let distance = abs(weekIndex - selectedWeekIndex)
        
        if distance == 0 {
            return 1.0 // Selected week maintains size
        } else {
            let scaleReduction = collapseProgress * 0.3 * Double(distance)
            return 1.0 - min(scaleReduction, 0.8)
        }
    }
}

// Note: CompactCalendarDayView is already defined in CalendarGridView.swift

// MARK: - Scroll Offset Preference Key
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
