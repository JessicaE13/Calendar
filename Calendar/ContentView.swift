import SwiftUI

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    var body: some View {

            VStack(spacing: 0) {
         
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(monthYearString(from: currentMonth))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
        
                CalendarGridView(
                    currentMonth: currentMonth,
                    selectedDate: $selectedDate
                )
                
       
                VStack(spacing: 16) {
                    Text("Selected Date")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(selectedDateString())
                        .font(.title3)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
         
        }
    }
    
    private func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    private func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func selectedDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
}


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
                .font(.system(size: 16, weight: .medium))
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
    ContentView()
}

