//
//  CalendarGridView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//

import SwiftUI

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    // Use an array of tuples with unique identifiers
    private let dayHeaders = [
        (id: 0, letter: "S"), // Sunday
        (id: 1, letter: "M"), // Monday
        (id: 2, letter: "T"), // Tuesday
        (id: 3, letter: "W"), // Wednesday
        (id: 4, letter: "T"), // Thursday
        (id: 5, letter: "F"), // Friday
        (id: 6, letter: "S")  // Saturday
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
        VStack(spacing: 0) {
            
            HStack {
                ForEach(dayHeaders, id: \.id) { dayHeader in
                    Text(dayHeader.letter)
                        .font(.system(size: 14))
                        .textCase(.uppercase)
                        .fontWeight(.bold)
                        .tracking(1.0)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)
            
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
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
                                .frame(width: 36, height: 36)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 64)
    }
}


#Preview {
    @Previewable @State var selectedDate = Date()
    CalendarGridView(currentMonth: Date(),
                     selectedDate: $selectedDate)
}
