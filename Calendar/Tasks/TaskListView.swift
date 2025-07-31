//
//  ItemListView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//  Minimal fix - keep using Item type
//

import SwiftUI

struct ItemListView: View {
    @ObservedObject var itemManager: ItemManager
    let selectedDate: Date
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    
    private var itemsForSelectedDate: [Item] {
        itemManager.itemsForDate(selectedDate)
    }
    
    private var selectedDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDate(selectedDate, equalTo: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date(), toGranularity: .day) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                
                if itemsForSelectedDate.isEmpty {
                    
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.square")
                            .font(.title)
                            .foregroundColor(.black.opacity(0.6))
                        
                        Text("No items for this day")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Text("Tap + to add a item")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .padding(.horizontal, 20)
                } else {
                    
                    HStack {
                        
                        LazyVStack(spacing: 4) {
                            ZStack (alignment: .leading) {
                                Rectangle()
                                    .fill(.gray)
                                    .frame(width: 2)
                                    .padding(.leading, 3)
                                VStack {
                                    ForEach(Array(itemsForSelectedDate.enumerated()), id: \.element.id) { index, item in
                                        HStack(alignment: .center, spacing: 28) {
                                            Circle()
                                                .fill(.gray)
                                                .frame(width: 8, height: 8)
                                            
                                            ItemRowView(itemManager: itemManager, item: item)
                                            
                                            Spacer()
                                        }
                            
                       
                                    }
                                    .onDelete(perform: deleteItems)
                       
                                }
                       
                            }
                            .padding(.leading, 48)
                       
                        }
                       
                    }
                }
                
                Spacer()
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showingAddItem = true
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color("Accent1"))
                                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: showingAddItem)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(itemManager: itemManager, selectedDate: selectedDate, isPresented: $showingAddItem)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let item = itemsForSelectedDate[index]
            itemManager.deleteItem(item)
        }
    }
}

struct AddItemView: View {
    @ObservedObject var itemManager: ItemManager
    let selectedDate: Date // Add selectedDate parameter
    @Binding var isPresented: Bool
    @State private var itemTitle = ""
    @State private var hasTime = false
    @State private var selectedTime = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Title")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    TextField("Enter item description", text: $itemTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Assign Time", isOn: $hasTime)
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                    
                    if hasTime {
                        DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Add Item") {
                        let newItem = Item(
                            title: itemTitle,
                            assignedDate: selectedDate, // Use the selected date
                            assignedTime: hasTime ? selectedTime : nil,
                            sortOrder: itemManager.items.count
                        )
                        itemManager.addItem(newItem)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .disabled(itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .padding()
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(400)])
    }
}

#Preview {
    let itemManager = ItemManager()
    ItemListView(itemManager: itemManager, selectedDate: Date())
}
