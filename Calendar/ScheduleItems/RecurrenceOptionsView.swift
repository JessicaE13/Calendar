//
//  RecurrenceOptionsView.swift
//  Calendar
//
//  Shared component for configuring recurring task patterns
//

import SwiftUI

struct RecurrenceOptionsView: View {
    @Binding var recurrencePattern: RecurrencePattern
    @Binding var isPresented: Bool
    
    @State private var selectedFrequency: RecurrenceFrequency
    @State private var selectedInterval: Int
    @State private var hasEndDate: Bool
    @State private var selectedEndDate: Date
    @State private var hasMaxOccurrences: Bool
    @State private var maxOccurrences: Int
    
    init(recurrencePattern: Binding<RecurrencePattern>, isPresented: Binding<Bool>) {
        self._recurrencePattern = recurrencePattern
        self._isPresented = isPresented
        
        // Initialize state from the current pattern
        self._selectedFrequency = State(initialValue: recurrencePattern.wrappedValue.frequency)
        self._selectedInterval = State(initialValue: recurrencePattern.wrappedValue.interval)
        self._hasEndDate = State(initialValue: recurrencePattern.wrappedValue.endDate != nil)
        self._selectedEndDate = State(initialValue: recurrencePattern.wrappedValue.endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date())
        self._hasMaxOccurrences = State(initialValue: recurrencePattern.wrappedValue.maxOccurrences != nil)
        self._maxOccurrences = State(initialValue: recurrencePattern.wrappedValue.maxOccurrences ?? 10)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Frequency Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Frequency")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Picker("Frequency", selection: $selectedFrequency) {
                        ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Interval Section (only show if not "Never")
                if selectedFrequency != .none {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Every")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Picker("Interval", selection: $selectedInterval) {
                                ForEach(1...30, id: \.self) { number in
                                    Text("\(number)").tag(number)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(maxWidth: 100)
                            
                            Text(intervalLabel)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .frame(height: 120)
                    }
                    
                    Divider()
                    
                    // End Conditions Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("End Condition")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Never ends option
                            HStack {
                                Button(action: {
                                    hasEndDate = false
                                    hasMaxOccurrences = false
                                }) {
                                    HStack {
                                        Image(systemName: (!hasEndDate && !hasMaxOccurrences) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor((!hasEndDate && !hasMaxOccurrences) ? .blue : .gray)
                                        Text("Never")
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // End date option
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button(action: {
                                        hasEndDate = true
                                        hasMaxOccurrences = false
                                    }) {
                                        HStack {
                                            Image(systemName: hasEndDate ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(hasEndDate ? .blue : .gray)
                                            Text("On date")
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                if hasEndDate {
                                    DatePicker("End Date", selection: $selectedEndDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .padding(.leading, 32)
                                }
                            }
                            
                            // Max occurrences option
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Button(action: {
                                        hasEndDate = false
                                        hasMaxOccurrences = true
                                    }) {
                                        HStack {
                                            Image(systemName: hasMaxOccurrences ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(hasMaxOccurrences ? .blue : .gray)
                                            Text("After")
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                if hasMaxOccurrences {
                                    HStack {
                                        Picker("Max Occurrences", selection: $maxOccurrences) {
                                            ForEach(1...100, id: \.self) { number in
                                                Text("\(number)").tag(number)
                                            }
                                        }
                                        .pickerStyle(WheelPickerStyle())
                                        .frame(maxWidth: 100)
                                        
                                        Text("occurrences")
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.leading, 32)
                                    .frame(height: 120)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecurrencePattern()
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.height(600), .large])
    }
    
    private var intervalLabel: String {
        let base = selectedFrequency.rawValue
        if selectedInterval == 1 {
            return base
        } else {
            return base + "s"
        }
    }
    
    private func saveRecurrencePattern() {
        recurrencePattern.frequency = selectedFrequency
        recurrencePattern.interval = selectedInterval
        recurrencePattern.endDate = hasEndDate ? selectedEndDate : nil
        recurrencePattern.maxOccurrences = hasMaxOccurrences ? maxOccurrences : nil
    }
}

#Preview {
    @Previewable @State var samplePattern = RecurrencePattern(frequency: .daily, interval: 1)
    @Previewable @State var isPresented = true
    
    RecurrenceOptionsView(
        recurrencePattern: $samplePattern,
        isPresented: $isPresented
    )
}
