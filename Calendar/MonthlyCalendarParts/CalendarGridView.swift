//
//  CalendarGridView.swift
//  Calendar
//
//  Updated with Coverflow carousel appearance
//

import SwiftUI

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    @State private var dragOffset: CGFloat = 0
    @State private var isAnimating = false
    
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
    }
    
    // Generate months for carousel (previous, current, next)
    private var carouselMonths: [Date] {
        let calendar = Calendar.current
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        return [previousMonth, currentMonth, nextMonth]
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth: CGFloat = min(280, geometry.size.width - 60)
            let sideCardOffset: CGFloat = cardWidth * 0.4 // Reduced from 0.6
            
            HStack(spacing: 0) {
                Spacer()
                
                ZStack {
                    ForEach(Array(carouselMonths.enumerated()), id: \.offset) { index, month in
                        CalendarCard(
                            month: month,
                            selectedDate: $selectedDate,
                            dayHeaders: dayHeaders
                        )
                        .frame(width: cardWidth)
                        .scaleEffect(scaleForIndex(index))
                        .opacity(opacityForIndex(index))
                        .offset(x: offsetForIndex(index, sideOffset: sideCardOffset) + dragOffset)
                        .rotation3DEffect(
                            .degrees(rotationForIndex(index)),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .zIndex(zIndexForIndex(index))
                    }
                }
                .frame(width: cardWidth)
                
                Spacer()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isAnimating {
                            dragOffset = value.translation.width * 0.3 // Dampen the drag more
                        }
                    }
                    .onEnded { value in
                        if !isAnimating {
                            handleSwipeGesture(translation: value.translation.width)
                        }
                    }
            )
        }
        .frame(height: 350)
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: dragOffset)
        .animation(.easeInOut(duration: 0.3), value: isAnimating)
    }
    
    // MARK: - Carousel Position Calculations
    
    private func offsetForIndex(_ index: Int, sideOffset: CGFloat) -> CGFloat {
        let centerIndex = 1 // Current month is at index 1
        return CGFloat(index - centerIndex) * sideOffset
    }
    
    private func scaleForIndex(_ index: Int) -> CGFloat {
        let centerIndex = 1
        let distance = abs(index - centerIndex)
        
        switch distance {
        case 0: return 1.0      // Center card (current month)
        case 1: return 0.85     // Side cards
        default: return 0.7     // Far cards
        }
    }
    
    private func opacityForIndex(_ index: Int) -> Double {
        let centerIndex = 1
        let distance = abs(index - centerIndex)
        
        switch distance {
        case 0: return 1.0      // Center card
        case 1: return 0.7      // Side cards
        default: return 0.4     // Far cards
        }
    }
    
    private func rotationForIndex(_ index: Int) -> Double {
        let centerIndex = 1
        let offset = index - centerIndex
        return Double(offset) * -25 // Rotate side cards for 3D effect
    }
    
    private func zIndexForIndex(_ index: Int) -> Double {
        let centerIndex = 1
        let distance = abs(index - centerIndex)
        return Double(2 - distance) // Center card has highest z-index
    }
    
    // MARK: - Gesture Handling
    
    private func handleSwipeGesture(translation: CGFloat) {
        let swipeThreshold: CGFloat = 60
        
        guard abs(translation) > swipeThreshold else {
            // Return to center if swipe wasn't strong enough
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                dragOffset = 0
            }
            return
        }
        
        isAnimating = true
        
        // Determine direction
        let direction: SwipeDirection = translation > 0 ? .previous : .next
        
        // Animate the transition
        withAnimation(.easeInOut(duration: 0.4)) {
            dragOffset = translation > 0 ? 400 : -400
        }
        
        // Change month after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onMonthChange(direction)
            
            // Reset position
            dragOffset = 0
            
            // End animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isAnimating = false
            }
        }
    }
}

// MARK: - Individual Calendar Card

struct CalendarCard: View {
    let month: Date
    @Binding var selectedDate: Date
    let dayHeaders: [(id: Int, letter: String)]
    
    private let calendar = Calendar.current
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }
    
    private var weeks: [[Date?]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
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
            let dateToAdd: Date? = calendar.isDate(date, equalTo: month, toGranularity: .month) ? date : nil
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
            // Month/Year header
            Text(monthYearString)
                .font(.system(.title2, design: .serif))
                .fontWeight(.bold)
                .foregroundColor(.primary)
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
            .padding(.bottom, 8)
            
            Divider()
                .padding(.bottom, 8)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 7), spacing: 8) {
                ForEach(weeks, id: \.self) { week in
                    ForEach(Array(week.enumerated()), id: \.offset) { index, date in
                        if let date = date {
                            CalendarDayView(
                                date: date,
                                currentMonth: month,
                                selectedDate: $selectedDate
                            )
                        } else {
                            Color.clear
                                .frame(width: 32, height: 32)
                        }
                    }
                }
            }
            .padding(.bottom, 16)
            
            // Navigation dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.gray.opacity(index == 1 ? 0.8 : 0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 24)
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
    }
}

// Extension for the SwipeDirection enum
extension CalendarGridView.SwipeDirection {
    var monthIncrement: Int {
        switch self {
        case .next: return 1
        case .previous: return -1
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
            }
        )
    }
}
