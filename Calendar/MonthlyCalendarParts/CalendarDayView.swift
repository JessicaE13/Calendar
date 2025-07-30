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
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color("Accent1"), lineWidth: isToday ? 1.0 : 0)
                    )
                
                Text(dayString)
                    .font(.system(size: 14))
                    .fontWeight(.semibold)
                    .monospacedDigit() // Forces consistent width for all digits
                    .foregroundColor(.primary.opacity(0.75))
                    .frame(width: 20) // Fixed width container for the text
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        return isSelected ? .white :  Color(UIColor.systemGray)
    }
    
    private var backgroundColor: Color {
        return isSelected ? Color("Accent1") : .clear
    }
    
}

#Preview {
    @Previewable @State var selectedDate = Date()
    CalendarDayView(date: Date(),
                    currentMonth: Date(),
                    selectedDate: $selectedDate)
}
