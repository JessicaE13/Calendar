//
//  CalendarGridView.swift
//  Calendar
//
//  Simplified version - shows only the current month without carousel
//

import SwiftUI

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    
    // Callback for month changes
    let onMonthChange: (SwipeDirection) -> Void
    
    private let calendar = Calendar.current
    
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
                
                Text(monthYearString)
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
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
            .padding(.bottom, 16)
        }
        .padding(.vertical, 24)
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
        .padding(.horizontal, 30)
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
            }
        )
    }
}
