//
//  CalendarGridView.swift
//  Calendar
//
//  Updated with card wrapper styling
//

import SwiftUI

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
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
            // Only include the date if it's in the current month, otherwise nil
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
        // Card wrapper with fixed width
        VStack(spacing: 0) {
            
            HStack {
                ForEach(dayHeaders, id: \.id) { dayHeader in
                    Text(dayHeader.letter)
                        .font(.system(size: 9))
                        .fontWeight(.semibold)
                        .tracking(0.8)
                        .foregroundColor(.primary)
                        .frame(width: 32) // Smaller width for each day header
                }
            }
            .padding(.bottom, 6)
            .padding(.top, 3)
            
            Divider()
                .padding(.bottom, 6)
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 7), spacing: 6) {
                ForEach(weeks, id: \.self) { week in
                    ForEach(Array(week.enumerated()), id: \.offset) { index, date in
                        if let date = date {
                            CalendarDayView(
                                date: date,
                                currentMonth: currentMonth,
                                selectedDate: $selectedDate
                            )
                        } else {
                            // Empty space for dates not in current month
                            Color.clear
                                .frame(width: 32, height: 32)
                        }
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .frame(width: 266) // Fixed total width: (32 * 7) + (6 * 6) + (16 * 2) = 292
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.8))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
    }
}

#Preview {
    @Previewable @State var selectedDate = Date()
    ZStack {
        
 BackgroundView()
        CalendarGridView(currentMonth: Date(),
                         selectedDate: $selectedDate)
    }
}
