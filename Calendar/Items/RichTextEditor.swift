//
//  RichTextEditor.swift
//  Calendar
//
//  Rich text editor component for item descriptions with formatting support
//

import SwiftUI

// MARK: - Rich Text Line Types
enum RichTextLineType: Codable, CaseIterable {
    case text
    case bullet
    case checkbox
    
    var prefix: String {
        switch self {
        case .text: return ""
        case .bullet: return "• "
        case .checkbox: return "☐ "
        }
    }
    
    var completedPrefix: String {
        switch self {
        case .checkbox: return "☑ "
        default: return prefix
        }
    }
}

// MARK: - Rich Text Line Model
struct RichTextLine: Identifiable, Codable {
    let id = UUID()
    var content: String
    var type: RichTextLineType
    var isCompleted: Bool = false
    
    var displayText: String {
        let prefixToUse = (type == .checkbox && isCompleted) ? type.completedPrefix : type.prefix
        return prefixToUse + content
    }
    
    init(content: String, type: RichTextLineType = .text) {
        self.content = content
        self.type = type
    }
}

// MARK: - Rich Text Editor View
struct RichTextEditor: View {
    @Binding var lines: [RichTextLine]
    @State private var selectedLineIDs: Set<UUID> = []
    @State private var editingLineID: UUID?
    @State private var editingText: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                // Edit Mode
                VStack(alignment: .leading, spacing: 8) {
                    // Formatting toolbar
                    formatToolbar
                    
                    // Editable lines
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(lines.indices, id: \.self) { index in
                                    EditableLineView(
                                        line: $lines[index],
                                        isSelected: selectedLineIDs.contains(lines[index].id),
                                        isEditing: editingLineID == lines[index].id,
                                        editingText: $editingText,
                                        onTap: {
                                            handleLineTap(lines[index].id)
                                        },
                                        onEdit: {
                                            startEditing(lines[index].id)
                                        },
                                        onSave: { newContent in
                                            saveLineEdit(index: index, content: newContent)
                                        },
                                        onNewLine: {
                                            createNewLine(after: index)
                                        },
                                        onDelete: {
                                            deleteLine(at: index)
                                        }
                                    )
                                }
                            }
                            
                            // Invisible tappable area below all lines
                            Rectangle()
                                .fill(Color.clear)
                                .frame(minHeight: 60)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    tapBelowLines()
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .frame(minHeight: 200)
                }
                .background(Color.white.opacity(0.8))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Read-only Mode
                Button(action: enterEditMode) {
                    VStack(alignment: .leading, spacing: 8) {
                        if lines.isEmpty {
                            Text("Add notes, meeting links, or create checklists...")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(lines.indices, id: \.self) { index in
                                ReadOnlyLineView(line: lines[index]) {
                                    // Toggle checkbox callback
                                    lines[index].isCompleted.toggle()
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formatToolbar: some View {
        HStack(spacing: 12) {
            if selectedLineIDs.isEmpty && editingLineID == nil {
                defaultFormatIcons
            } else if editingLineID != nil {
                activeFormatIcons
            } else {
                selectionFormatOptions
            }
            
            Spacer()
            
            Button("Done") {
                saveAndExit()
            }
            .fontWeight(.semibold)
            .foregroundColor(.green)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var defaultFormatIcons: some View {
        HStack(spacing: 16) {
            Button(action: { convertToFormat(.text) }) {
                Image(systemName: "textformat")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { convertToFormat(.bullet) }) {
                Image(systemName: "list.bullet")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { convertToFormat(.checkbox) }) {
                Image(systemName: "checkmark.square")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var activeFormatIcons: some View {
        HStack(spacing: 16) {
            Button(action: { convertToFormat(.text) }) {
                Image(systemName: "textformat")
                    .foregroundColor(getCurrentEditingLineType() == .text ? .blue : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { convertToFormat(.bullet) }) {
                Image(systemName: "list.bullet")
                    .foregroundColor(getCurrentEditingLineType() == .bullet ? .blue : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { convertToFormat(.checkbox) }) {
                Image(systemName: "checkmark.square")
                    .foregroundColor(getCurrentEditingLineType() == .checkbox ? .blue : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var selectionFormatOptions: some View {
        HStack {
            Text("Convert \(selectedLineIDs.count) selected:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Text") {
                convertSelectedLines(to: .text)
            }
            .foregroundColor(.blue)
            
            Button("• Bullet") {
                convertSelectedLines(to: .bullet)
            }
            .foregroundColor(.blue)
            
            Button("☐ Checkbox") {
                convertSelectedLines(to: .checkbox)
            }
            .foregroundColor(.blue)
        }
    }
    
    // MARK: - Helper Methods
    
    private func enterEditMode() {
        isEditing = true
        selectedLineIDs.removeAll()
        
        // If no lines exist, create a default text line
        if lines.isEmpty {
            lines.append(RichTextLine(content: "", type: .text))
        }
    }
    
    private func saveAndExit() {
        // Save any currently editing line first
        if let editingID = editingLineID,
           let index = lines.firstIndex(where: { $0.id == editingID }) {
            lines[index].content = editingText
        }
        
        // More intelligent cleanup that preserves intentional blank lines
        var cleanedLines: [RichTextLine] = []
        
        for (index, line) in lines.enumerated() {
            let trimmedContent = line.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let isEmpty = trimmedContent.isEmpty
            
            if !isEmpty {
                // Always keep lines with content
                cleanedLines.append(line)
            } else {
                // For empty lines, be more selective about what to keep
                let isLastLine = index == lines.count - 1
                let hasContentAfter = lines.indices.contains(index + 1) &&
                                    lines[(index + 1)...].contains { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                let hasContentBefore = index > 0 &&
                                     lines[0..<index].contains { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                // Keep empty line if:
                // 1. It's between content (intentional spacing), OR
                // 2. It's the first line and there's content after, OR
                // 3. There's content before and after (paragraph break)
                if (hasContentBefore && hasContentAfter) ||
                   (index == 0 && hasContentAfter) ||
                   (hasContentBefore && !isLastLine && hasContentAfter) {
                    cleanedLines.append(line)
                }
                // Remove trailing empty lines and orphaned empty lines
            }
        }
        
        // If all lines are empty, keep just one empty text line
        if cleanedLines.allSatisfy({ $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            lines = []
        } else {
            lines = cleanedLines
        }
        
        isEditing = false
        selectedLineIDs.removeAll()
        editingLineID = nil
        editingText = ""
    }
    
    private func handleLineTap(_ lineID: UUID) {
        if selectedLineIDs.contains(lineID) {
            selectedLineIDs.remove(lineID)
        } else {
            selectedLineIDs.insert(lineID)
        }
    }
    
    private func startEditing(_ lineID: UUID) {
        if let line = lines.first(where: { $0.id == lineID }) {
            editingLineID = lineID
            editingText = line.content
        }
    }
    
    private func saveLineEdit(index: Int, content: String) {
        guard index < lines.count else { return }
        lines[index].content = content
        editingLineID = nil
        editingText = ""
    }
    
    private func createNewLine(after index: Int) {
        // Get the formatting type from the current line
        let currentLineType = lines[index].type
        
        let newLine = RichTextLine(content: "", type: currentLineType)
        lines.insert(newLine, at: index + 1)
        
        // Automatically start editing the new line
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            editingLineID = newLine.id
            editingText = ""
        }
    }
    
    private func addNewLine() {
        // Get the formatting type from the last line, or default to text
        let lastLineType = lines.last?.type ?? .text
        
        let newLine = RichTextLine(content: "", type: lastLineType)
        lines.append(newLine)
        
        // Automatically start editing the new line
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            editingLineID = newLine.id
            editingText = ""
        }
    }
    
    private func deleteLine(at index: Int) {
        guard index < lines.count && lines.count > 1 else { return }
        let lineID = lines[index].id
        lines.remove(at: index)
        selectedLineIDs.remove(lineID)
        if editingLineID == lineID {
            editingLineID = nil
        }
    }
    
    private func convertSelectedLines(to newType: RichTextLineType) {
        for lineID in selectedLineIDs {
            if let index = lines.firstIndex(where: { $0.id == lineID }) {
                lines[index].type = newType
                // Reset completion status when converting
                if newType != .checkbox {
                    lines[index].isCompleted = false
                }
            }
        }
        selectedLineIDs.removeAll()
    }
    
    // MARK: - New helper methods for format conversion
    
    private func convertToFormat(_ newType: RichTextLineType) {
        if let editingID = editingLineID {
            // Convert the currently editing line
            if let index = lines.firstIndex(where: { $0.id == editingID }) {
                lines[index].type = newType
                // Reset completion status when converting away from checkbox
                if newType != .checkbox {
                    lines[index].isCompleted = false
                }
            }
        } else if !selectedLineIDs.isEmpty {
            // Convert selected lines
            convertSelectedLines(to: newType)
        }
    }
    
    private func getCurrentEditingLineType() -> RichTextLineType {
        guard let editingID = editingLineID,
              let line = lines.first(where: { $0.id == editingID }) else {
            return .text
        }
        return line.type
    }
    
    // MARK: - Tap Below Lines Handler
    
    private func tapBelowLines() {
        // Clear any current selections
        selectedLineIDs.removeAll()
        
        if lines.isEmpty {
            // If no lines exist, create the first one
            let newLine = RichTextLine(content: "", type: .text)
            lines.append(newLine)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                editingLineID = newLine.id
                editingText = ""
            }
        } else {
            // Check if the last line is empty and not being edited
            let lastLine = lines.last!
            if lastLine.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && editingLineID != lastLine.id {
                // Start editing the existing empty last line
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    editingLineID = lastLine.id
                    editingText = lastLine.content
                }
            } else {
                // Create a new line at the end with the same format as the last line
                let lastLineType = lastLine.type
                let newLine = RichTextLine(content: "", type: lastLineType)
                lines.append(newLine)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    editingLineID = newLine.id
                    editingText = ""
                }
            }
        }
    }
}

// MARK: - Editable Line View
struct EditableLineView: View {
    @Binding var line: RichTextLine
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingText: String
    let onTap: () -> Void
    let onEdit: () -> Void
    let onSave: (String) -> Void
    let onNewLine: () -> Void
    let onDelete: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Line content (full width)
            VStack(alignment: .leading, spacing: 0) {
                if isEditing {
                    HStack(alignment: .top, spacing: 4) {
                        // Type prefix
                        if line.type != .text {
                            Text(line.type.prefix)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        // Editable text field
                        TextField("Enter text...", text: $editingText, axis: .vertical)
                            .font(.system(size: 16))
                            .lineLimit(1...5)
                            .focused($isFocused)
                            .onSubmit {
                                // Save current line
                                onSave(editingText)
                                // Create new line automatically
                                onNewLine()
                            }
                            .onAppear {
                                isFocused = true
                            }
                    }
                } else {
                    HStack(alignment: .top, spacing: 4) {
                        // Interactive type prefix for checkboxes
                        if line.type == .checkbox {
                            Button(action: {
                                line.isCompleted.toggle()
                            }) {
                                Text(line.isCompleted ? "☑" : "☐")
                                    .font(.system(size: 16))
                                    .foregroundColor(line.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if line.type == .bullet {
                            Text("•")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        // Line content - tappable anywhere to edit
                        Button(action: onEdit) {
                            Text(line.content.isEmpty ? "" : line.content)
                                .font(.system(size: 16))
                                .foregroundColor(line.content.isEmpty ? .clear : .primary)
                                .italic(line.content.isEmpty)
                                .strikethrough(line.type == .checkbox && line.isCompleted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: line.content.isEmpty ? 20 : nil) // Maintain tappable area
                                .contentShape(Rectangle()) // Makes entire area tappable
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Delete button
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .simultaneousGesture(
            // Long press gesture for selection (multi-select mode)
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if !isEditing {
                        onTap() // Select the line for formatting
                    }
                }
        )
    }
}

// MARK: - Read-Only Line View
struct ReadOnlyLineView: View {
    let line: RichTextLine
    let onToggleCheckbox: (() -> Void)?
    
    init(line: RichTextLine, onToggleCheckbox: (() -> Void)? = nil) {
        self.line = line
        self.onToggleCheckbox = onToggleCheckbox
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if line.type == .checkbox {
                Button(action: {
                    onToggleCheckbox?()
                }) {
                    Text(line.isCompleted ? "☑" : "☐")
                        .font(.system(size: 16))
                        .foregroundColor(line.isCompleted ? .green : .gray)
                }
                .buttonStyle(PlainButtonStyle())
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

// MARK: - Extension for converting between string and RichTextLine array
extension Array where Element == RichTextLine {
    func toDescriptionString() -> String {
        return self.map { line in
            let prefix = line.type == .checkbox && line.isCompleted ? line.type.completedPrefix : line.type.prefix
            return prefix + line.content
        }.joined(separator: "\n")
    }
    
    static func fromDescriptionString(_ description: String) -> [RichTextLine] {
        let lines = description.components(separatedBy: .newlines)
        
        return lines.compactMap { lineText in
            let trimmed = lineText.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("☑ ") {
                let content = String(trimmed.dropFirst(2))
                var line = RichTextLine(content: content, type: .checkbox)
                line.isCompleted = true
                return line
            } else if trimmed.hasPrefix("☐ ") {
                let content = String(trimmed.dropFirst(2))
                return RichTextLine(content: content, type: .checkbox)
            } else if trimmed.hasPrefix("• ") {
                let content = String(trimmed.dropFirst(2))
                return RichTextLine(content: content, type: .bullet)
            } else if !trimmed.isEmpty {
                return RichTextLine(content: trimmed, type: .text)
            }
            
            return nil
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var sampleLines: [RichTextLine] = [
        RichTextLine(content: "This is a regular text line", type: .text),
        RichTextLine(content: "This is a bullet point", type: .bullet),
        RichTextLine(content: "This is an unchecked item", type: .checkbox),
        RichTextLine(content: "This is a completed item", type: .checkbox)
    ]
    
    // Set the last item as completed
    sampleLines[3].isCompleted = true
    
    return VStack {
        Text("Rich Text Editor Preview")
            .font(.headline)
        
        RichTextEditor(lines: $sampleLines)
            .padding()
        
        Spacer()
    }
    .padding()
}
