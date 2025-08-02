//
//  CalendarGridView.swift
//  Calendar
//
//  Updated to support both full calendar and pinned week views
//

import SwiftUI

// MARK: - Swipe Direction Enum
enum CalendarSwipeDirection {
    case next, previous
    
    var monthIncrement: Int {
        switch self {
        case .next: return 1
        case .previous: return -1
        }
    }
}

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    @Binding var isCollapsed: Bool
    
    let onMonthChange: (CalendarSwipeDirection) -> Void
    let onDateJump: ((Date) -> Void)?
    
    // State for date picker
    @State private var showingDatePicker = false
    @State private var pickerDate: Date
    
    private let calendar = Calendar.current
    
    private let daySize: CGFloat = 36
    private let gridSpacing: CGFloat = 4
    private let horizontalPadding: CGFloat = 16
    
    init(currentMonth: Date, selectedDate: Binding<Date>, isCollapsed: Binding<Bool>, onMonthChange: @escaping (CalendarSwipeDirection) -> Void, onDateJump: ((Date) -> Void)? = nil) {
        self.currentMonth = currentMonth
        self._selectedDate = selectedDate
        self._isCollapsed = isCollapsed
        self.onMonthChange = onMonthChange
        self.onDateJump = onDateJump
        self._pickerDate = State(initialValue: currentMonth)
    }
    
    // Use an array of tuples with unique identifiers
    private let dayHeaders = [
        (id: 0, letter: "S"), // Sunday - shortened
        (id: 1, letter: "M"), // Monday
        (id: 2, letter: "T"), // Tuesday
        (id: 3, letter: "W"), // Wednesday
        (id: 4, letter: "T"), // Thursday
        (id: 5, letter: "F"), // Friday
        (id: 6, letter: "S")  // Saturday
    ]
    
    // Legacy SwipeDirection for compatibility
    enum SwipeDirection {
        case next, previous
        
        var monthIncrement: Int {
            switch self {
            case .next: return 1
            case .previous: return -1
            }
        }
    }
    
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
    
    // Get only the current week when collapsed
    private var currentWeek: [Date?] {
        let selectedWeekIndex = weeks.firstIndex { week in
            week.contains { date in
                guard let date = date else { return false }
                return calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
            }
        } ?? 0
        
        return selectedWeekIndex < weeks.count ? weeks[selectedWeekIndex] : []
    }
    
    private var yearRange: Range<Int> {
        let currentYear = calendar.component(.year, from: Date())
        return (currentYear - 10)..<(currentYear + 10)
    }
    
    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = calendar.date(from: DateComponents(month: month)) ?? Date()
        return formatter.string(from: date)
    }
    
    private func goToToday() {
        let today = Date()
        selectedDate = today
        
        // Navigate to today's month if we're not already there
        if !calendar.isDate(currentMonth, equalTo: today, toGranularity: .month) {
            onDateJump?(today)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header with month/year and navigation
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
                    Button(action: {
                        onMonthChange(.previous)
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(Color("Accent1"))
                    }
                    
                    // Today button
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
                    
                    Button(action: {
                        onMonthChange(.next)
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(Color("Accent1"))
                    }
                    
                }
                .padding(.horizontal, horizontalPadding)
                
            }
            .padding(.bottom, 12)
            
            // Collapse/Expand indicator
            if isCollapsed {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isCollapsed = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("Show Full Month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            
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
            
            // Calendar grid - animated between full month and current week
            Group {
                if isCollapsed {
                    // Show only current week
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                } else {
                    // Show full month
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(daySize)), count: 7), spacing: gridSpacing) {
                        ForEach(weeks, id: \.self) { week in
                            ForEach(Array(week.enumerated()), id: \.offset) { index, date in
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
            .offset(y: 0) // Remove drag offset since we're not handling drag here
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Handle month navigation swipe (horizontal only)
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
            VStack(spacing: 30) {
                
                HStack {
                    Spacer()
                    Button(action: {
                        showingDatePicker = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                HStack(spacing: 20) {
                    
                    VStack(spacing: 8) {
                        Text("Month")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Picker("Month", selection: Binding(
                            get: { calendar.component(.month, from: pickerDate) },
                            set: { newMonth in
                                let year = calendar.component(.year, from: pickerDate)
                                pickerDate = calendar.date(from: DateComponents(year: year, month: newMonth)) ?? pickerDate
                            }
                        )) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthName(for: month))
                                    .tag(month)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                    }
                    
                    
                    VStack(spacing: 8) {
                        Text("Year")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Picker("Year", selection: Binding(
                            get: { calendar.component(.year, from: pickerDate) },
                            set: { newYear in
                                let month = calendar.component(.month, from: pickerDate)
                                pickerDate = calendar.date(from: DateComponents(year: newYear, month: month)) ?? pickerDate
                            }
                        )) {
                            ForEach(yearRange, id: \.self) { year in
                                Text(String(year))
                                    .tag(year)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                    }
                }
                .frame(height: 150)
                .padding(.horizontal, 20)
                
                // Update button
                Button("Update") {
                    // Calculate the number of months to jump
                    let monthDifference = calendar.dateComponents([.month], from: currentMonth, to: pickerDate).month ?? 0

                    for _ in 0..<abs(monthDifference) {
                        if monthDifference > 0 {
                            onMonthChange(.next)
                        } else if monthDifference < 0 {
                            onMonthChange(.previous)
                        }
                    }
                    
                    // If we have a direct jump callback, use it instead
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
            .presentationDetents([.height(350)])
        }
    }
}

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

#Preview {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isCollapsed = false
    ZStack {
        BackgroundView()
        
        CalendarGridView(
            currentMonth: Date(),
            selectedDate: $selectedDate,
            isCollapsed: $isCollapsed,
            onMonthChange: { direction in
                print("Month changed: \(direction)")
            },
            onDateJump: { date in
                print("Date jumped to: \(date)")
            }
        )
    }
}
