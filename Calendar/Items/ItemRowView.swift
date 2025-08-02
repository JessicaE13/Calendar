//
//  ItemRowView.swift
//  Calendar
//
//  Complete file with Rich Text Editor integration, recurring task support, and category colors
//

import SwiftUI

struct ItemRowView: View {
    @ObservedObject var itemManager: ItemManager
    let item: Item
    @State private var showingItemDetails = false
    
    // Category manager for getting category info
    @StateObject private var categoryManager = CategoryManager.shared
    
    private var timeComponents: (time: String, period: String) {
        guard let time = item.assignedTime else { return ("", "") }
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: time)
        
        let timeString: String
        if minutes == 0 {
            formatter.dateFormat = "h" // Just the hour
            timeString = formatter.string(from: time)
        } else {
            formatter.dateFormat = "h:mm" // Hour and minutes
            timeString = formatter.string(from: time)
        }
        
        formatter.dateFormat = "a" // Just AM/PM
        let period = formatter.string(from: time).uppercased()
        
        return (timeString, period)
    }
    
    private var showsRecurringIndicator: Bool {
        return item.isRecurringParent || item.isRecurringInstance
    }
    
    private var categoryColor: Color {
        if let category = item.getCategory(from: categoryManager) {
            return category.color.swiftUIColor
        }
        return Color.gray.opacity(0.3)
    }
    
    private var hasCategory: Bool {
        return item.categoryID != nil
    }
    
    var body: some View {
        Button(action: {
            showingItemDetails = true
        }) {
            HStack(spacing: 12) {
                // Category color indicator (replaces the gray circle)
                Circle()
                    .fill(categoryColor)
                    .frame(width: hasCategory ? 8 : 6, height: hasCategory ? 8 : 6)
                    .opacity(hasCategory ? 1.0 : 0.7)
                
                // Checkmark button (only when no time is assigned)
                if item.assignedTime == nil {
                    Button(action: {
                        itemManager.toggleItemCompletion(item)
                    }) {
                        Image(systemName: item.isCompleted ? "checkmark.square" : "square")
                            .foregroundColor(item.isCompleted ? .green : .gray)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Item content - different styling based on whether it has time
                VStack(alignment: .leading, spacing: 4) {
                    if let _ = item.assignedTime {
                        // Item with time - add background with rounded corners
                        HStack(spacing: 0) {
                            Text(timeComponents.time)
                                .font(.system(size: 16))
                            Text(timeComponents.period)
                                .font(.system(size: 10))
                                .baselineOffset(-5) // Align with the bottom of the numbers
                            Text(" \(item.title)")
                                .font(.system(size: 16))
                            
                            // Recurring indicator
                            if showsRecurringIndicator {
                                Image(systemName: "repeat")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(hasCategory ? categoryColor.opacity(0.15) : Color("Accent1").opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(hasCategory ? categoryColor.opacity(0.3) : Color.clear, lineWidth: hasCategory ? 1 : 0)
                                )
                        )
                    } else {
                        // Item without time - no background, but add subtle category accent
                        HStack(spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 16))
                                .padding(.vertical, 8)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .secondary : .primary)
                                .multilineTextAlignment(.leading)
                            
                            // Recurring indicator
                            if showsRecurringIndicator {
                                Image(systemName: "repeat")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Subtle category indicator for non-timed items
                            if hasCategory {
                                Rectangle()
                                    .fill(categoryColor)
                                    .frame(width: 3, height: 16)
                                    .cornerRadius(1.5)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.vertical, 8)
        .sheet(isPresented: $showingItemDetails) {
            ItemDetailsView(
                item: item,
                itemManager: itemManager,
                isPresented: $showingItemDetails
            )
            .presentationCornerRadius(30)
            .presentationBackground(Color(red: 0.96, green: 0.94, blue: 0.89))
        }
    }
}

// MARK: - Read-Only Rich Text Line View (unchanged)
struct ReadOnlyRichTextLineView: View {
    let line: RichTextLine
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if line.type == .checkbox {
                Text(line.isCompleted ? "☑" : "☐")
                    .font(.system(size: 16))
                    .foregroundColor(line.isCompleted ? .green : .gray)
            } else if line.type == .bullet {
                Text("•")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Text(line.content)
                .font(.system(size: 16))
                .strikethrough(line.type == .checkbox && line.isCompleted)
                .foregroundColor(line.type == .checkbox && line.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Checklist Item Row (unchanged)
struct ChecklistItemRow: View {
    let checklistItem: ChecklistItem
    let parentItem: Item
    @ObservedObject var itemManager: ItemManager
    let isEditMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                itemManager.toggleChecklistItemCompletion(parentItem, checklistItem: checklistItem)
            }) {
                Image(systemName: checklistItem.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(checklistItem.isCompleted ? .green : .gray)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(checklistItem.title)
                .font(.system(size: 16))
                .strikethrough(checklistItem.isCompleted)
                .foregroundColor(checklistItem.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if isEditMode {
                Button(action: {
                    itemManager.deleteChecklistItem(parentItem, checklistItem: checklistItem)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.6))
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.3))
        )
    }
}

#Preview {
    let itemManager = ItemManager()
    ItemRowView(itemManager: itemManager, item: itemManager.items[0])
}
