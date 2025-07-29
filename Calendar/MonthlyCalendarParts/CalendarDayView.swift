//
//  CalendarDayView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//

import SwiftUI

struct CalendarDayView: View {
    let date: Date
    let currentMonth: Date
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var isInCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
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
            Text(dayString)
                .font(.custom("Mulish", size: 14))
                .foregroundColor(textColor)
                .frame(width: 40, height: 40)
                .background(backgroundColor)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(borderColor, lineWidth: isToday ? 2 : 0)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isInCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue
        } else {
            return .clear
        }
    }
    
    private var borderColor: Color {
        return isToday ? .blue : .clear
    }
}

#Preview {
    @Previewable @State var selectedDate = Date()
    CalendarDayView( date: Date(),
                     currentMonth: Date(),
                     selectedDate: $selectedDate)
}
