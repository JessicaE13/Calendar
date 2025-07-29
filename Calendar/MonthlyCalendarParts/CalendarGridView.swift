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
    
    private var weeks: [[Date]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end) else {
            return []
        }
        
        var weeks: [[Date]] = []
        var currentWeek: [Date] = []
        
        let startDate = monthFirstWeek.start
        let endDate = monthLastWeek.end
        
        var date = startDate
        while date < endDate {
            currentWeek.append(date)
            
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
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.custom("Mulish", size: 10)) // Adjus
                      .textCase(.uppercase)
                      .fontWeight(.ultraLight)
                      .tracking(1.0)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
            
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
                ForEach(weeks, id: \.self) { week in
                    ForEach(week, id: \.self) { date in
                        CalendarDayView(
                            date: date,
                            currentMonth: currentMonth,
                            selectedDate: $selectedDate
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 36)
    }
}


#Preview {
    @Previewable @State var selectedDate = Date()
    CalendarGridView(         currentMonth: Date(),
                              selectedDate: $selectedDate)
}
