//
//  CalendarGridView.swift
//  Calendar
//
//  Updated to fit background frame to calendar content
//

import SwiftUI

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    
    // Callbacks
    let onMonthChange: (SwipeDirection) -> Void
    let onDateJump: ((Date) -> Void)?
    
    // State for date picker
    @State private var showingDatePicker = false
    @State private var pickerDate: Date
    
    private let calendar = Calendar.current
    
    init(currentMonth: Date, selectedDate: Binding<Date>, onMonthChange: @escaping (SwipeDirection) -> Void, onDateJump: ((Date) -> Void)? = nil) {
        self.currentMonth = currentMonth
        self._selectedDate = selectedDate
        self.onMonthChange = onMonthChange
        self.onDateJump = onDateJump
        self._pickerDate = State(initialValue: currentMonth)
    }
    
    // Use an array of tuples with unique identifiers
    private let dayHeaders = [
        (id: 0, letter: "Sun"), // Sunday
        (id: 1, letter: "Mon"), // Monday
        (id: 2, letter: "Tue"), // Tuesday
        (id: 3, letter: "Wed"), // Wednesday
        (id: 4, letter: "Thu"), // Thursday
        (id: 5, letter: "Fri"), // Friday
        (id: 6, letter: "Sat")  // Saturday
    ]
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Month/Year header with navigation
            HStack {
                Button(action: {
                    onMonthChange(.previous)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(Color("Accent1"))
                }
                
                Spacer()
                
                Button(action: {
                    pickerDate = currentMonth
                    showingDatePicker = true
                }) {
                    Text(monthYearString)
                        .font(.system(.title2, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: {
                    onMonthChange(.next)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(Color("Accent1"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Day headers
            HStack {
                ForEach(dayHeaders, id: \.id) { dayHeader in
                    Text(dayHeader.letter)
                        .font(.system(size: 10))
                        .fontWeight(.semibold)
                        .tracking(0.8)
                        .foregroundColor(.secondary)
                        .frame(width: 32)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 7), spacing: 8) {
                ForEach(weeks, id: \.self) { week in
                    ForEach(Array(week.enumerated()), id: \.offset) { index, date in
                        if let date = date {
                            CalendarDayView(
                                date: date,
                                currentMonth: currentMonth,
                                selectedDate: $selectedDate
                            )
                        } else {
                            Color.clear
                                .frame(width: 32, height: 32)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
        .gesture(
            DragGesture()
                .onEnded { value in
                    let swipeThreshold: CGFloat = 50
                    
                    if value.translation.width > swipeThreshold {
                        // Swipe right - go to previous month
                        onMonthChange(.previous)
                    } else if value.translation.width < -swipeThreshold {
                        // Swipe left - go to next month
                        onMonthChange(.next)
                    }
                }
        )
        .sheet(isPresented: $showingDatePicker) {
            VStack(spacing: 30) {
                // Close button
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                HStack(spacing: 20) {
                    // Month Picker
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
                    
                    // Year Picker
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
                    
                    // Apply the month changes
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

#Preview {
    @Previewable @State var selectedDate = Date()
    ZStack {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        CalendarGridView(
            currentMonth: Date(),
            selectedDate: $selectedDate,
            onMonthChange: { direction in
                print("Month changed: \(direction)")
            },
            onDateJump: { date in
                print("Date jumped to: \(date)")
            }
        )
    }
}
