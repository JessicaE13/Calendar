import SwiftUI

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var calendarOffset: CGFloat = 0
    @State private var isAnimatingMonthChange = false
    
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
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width < -50 {
                                animateMonthChange(direction: .next)
                            } else if value.translation.width > 50 {
                                animateMonthChange(direction: .previous)
                            }
                        }
                )
                
       
                VStack(spacing: 16) {
                    Text("Selected Date")
                
                        .foregroundColor(.secondary)
                    
                    Text(selectedDateString())
                        .font(.title3)
                
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
    
    enum SwipeDirection {
        case next, previous
    }

    private func animateMonthChange(direction: SwipeDirection) {
        guard !isAnimatingMonthChange else { return }
        isAnimatingMonthChange = true
        
        let directionMultiplier: CGFloat = (direction == .next) ? -1 : 1
        
        // Move out
        withAnimation(.easeInOut(duration: 0.25)) {
            calendarOffset = directionMultiplier * UIScreen.main.bounds.width
            isAnimatingMonthChange = true
        }
        
        // Wait for animation, then switch month and animate back in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if direction == .next {
                nextMonth()
            } else {
                previousMonth()
            }
            calendarOffset = -directionMultiplier * UIScreen.main.bounds.width
            
            // Animate back in
            withAnimation(.easeInOut(duration: 0.25)) {
                calendarOffset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isAnimatingMonthChange = false
            }
        }
    }

}




#Preview {
    ContentView()
}

