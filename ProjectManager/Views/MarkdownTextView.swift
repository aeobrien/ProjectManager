import SwiftUI
import ProjectManagerCore

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension NSBezierPath {
    convenience init(roundedRect rect: CGRect, byRoundingCorners corners: UIRectCorner, cornerRadii: CGSize) {
        self.init()
        
        let topLeft = corners.contains(.topLeft)
        let topRight = corners.contains(.topRight)
        let bottomLeft = corners.contains(.bottomLeft)
        let bottomRight = corners.contains(.bottomRight)
        
        let minX = rect.minX
        let minY = rect.minY
        let maxX = rect.maxX
        let maxY = rect.maxY
        
        let radius = min(cornerRadii.width, cornerRadii.height)
        
        move(to: CGPoint(x: minX + (topLeft ? radius : 0), y: minY))
        
        if topRight {
            line(to: CGPoint(x: maxX - radius, y: minY))
            curve(to: CGPoint(x: maxX, y: minY + radius),
                  controlPoint1: CGPoint(x: maxX - radius * 0.5, y: minY),
                  controlPoint2: CGPoint(x: maxX, y: minY + radius * 0.5))
        } else {
            line(to: CGPoint(x: maxX, y: minY))
        }
        
        if bottomRight {
            line(to: CGPoint(x: maxX, y: maxY - radius))
            curve(to: CGPoint(x: maxX - radius, y: maxY),
                  controlPoint1: CGPoint(x: maxX, y: maxY - radius * 0.5),
                  controlPoint2: CGPoint(x: maxX - radius * 0.5, y: maxY))
        } else {
            line(to: CGPoint(x: maxX, y: maxY))
        }
        
        if bottomLeft {
            line(to: CGPoint(x: minX + radius, y: maxY))
            curve(to: CGPoint(x: minX, y: maxY - radius),
                  controlPoint1: CGPoint(x: minX + radius * 0.5, y: maxY),
                  controlPoint2: CGPoint(x: minX, y: maxY - radius * 0.5))
        } else {
            line(to: CGPoint(x: minX, y: maxY))
        }
        
        if topLeft {
            line(to: CGPoint(x: minX, y: minY + radius))
            curve(to: CGPoint(x: minX + radius, y: minY),
                  controlPoint1: CGPoint(x: minX, y: minY + radius * 0.5),
                  controlPoint2: CGPoint(x: minX + radius * 0.5, y: minY))
        } else {
            line(to: CGPoint(x: minX, y: minY))
        }
        
        close()
    }
    
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        
        return path
    }
}

struct UIRectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct MarkdownTextView: View {
    let markdown: String
    var onCheckboxToggle: ((Int, Bool) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseMarkdown(markdown).enumerated()), id: \.element.id) { index, element in
                elementView(for: element, at: index)
            }
        }
    }
    
    @ViewBuilder
    private func elementView(for element: MarkdownElement, at index: Int) -> some View {
        switch element.type {
        case .heading(let level):
            Text(element.content)
                .font(headingFont(for: level))
                .fontWeight(.bold)
                .padding(.top, level == 1 ? 12 : 8)
                .padding(.bottom, 4)
        case .paragraph:
            Text(attributedString(from: element.content))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        case .codeBlock:
            Text(element.content)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.quaternaryLabelColor).opacity(0.3))
                .cornerRadius(4)
        case .listItem(let isOrdered, let number):
            HStack(alignment: .top, spacing: 8) {
                Text(isOrdered ? "\(number)." : "•")
                    .font(.body)
                    .frame(width: 20, alignment: .trailing)
                Text(attributedString(from: element.content))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .checkbox(let isChecked, let content):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .accentColor : .secondary)
                    .font(.body)
                    .onTapGesture {
                        if let lineIndex = findLineIndex(for: element) {
                            onCheckboxToggle?(lineIndex, !isChecked)
                        }
                    }
                Text(attributedString(from: content))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(isChecked ? .secondary : .primary)
            }
        case .emptyLine:
            Spacer().frame(height: 8)
        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)
        }
    }
    
    @ViewBuilder
    private func tableView(headers: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    Text(attributedString(from: header))
                        .font(.body.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                    
                    if header != headers.last {
                        Divider()
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4, corners: [.topLeft, .topRight])
            
            Divider()
            
            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        Text(attributedString(from: cell))
                            .font(.body)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if colIndex < row.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(index % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
    
    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .system(size: 24, weight: .regular, design: .default)  // H1 - Largest
        case 2: return .system(size: 20, weight: .regular, design: .default)  // H2
        case 3: return .system(size: 18, weight: .regular, design: .default)  // H3
        case 4: return .system(size: 16, weight: .regular, design: .default)  // H4
        case 5: return .system(size: 15, weight: .regular, design: .default)  // H5
        case 6: return .system(size: 14, weight: .regular, design: .default)  // H6 - Smallest
        default: return .system(size: 16, weight: .regular, design: .default)
        }
    }
    
    private func attributedString(from text: String) -> AttributedString {
        var result = AttributedString()
        
        // Regex patterns for inline formatting - order matters!
        let patterns: [(pattern: String, style: (inout AttributedString) -> Void)] = [
            // Bold italic (must come before bold and italic)
            ("\\*\\*\\*(.+?)\\*\\*\\*", { str in
                str.font = .body.bold().italic()
            }),
            // Bold
            ("\\*\\*(.+?)\\*\\*", { str in
                str.font = .body.bold()
            }),
            // Bold with underscores
            ("__(.+?)__", { str in
                str.font = .body.bold()
            }),
            // Italic with underscores
            ("_(.+?)_", { str in
                str.font = .body.italic()
            }),
            // Italic with asterisks (must come after bold)
            ("(?<!\\*)\\*([^*]+?)\\*(?!\\*)", { str in
                str.font = .body.italic()
            }),
            // Code
            ("`(.+?)`", { str in
                str.font = .system(.body, design: .monospaced)
                str.backgroundColor = Color(NSColor.quaternaryLabelColor).opacity(0.3)
            })
        ]
        
        var workingText = text
        var segments: [(String, Bool, (inout AttributedString) -> Void?)] = []
        
        // Extract formatted segments
        for (pattern, style) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: workingText, range: NSRange(workingText.startIndex..., in: workingText))
                
                for match in matches.reversed() {
                    if let range = Range(match.range(at: 1), in: workingText) {
                        let content = String(workingText[range])
                        let fullRange = Range(match.range, in: workingText)!
                        
                        // Replace the matched text with a placeholder
                        let placeholder = "[[[\(segments.count)]]]"
                        segments.append((content, true, style))
                        workingText.replaceSubrange(fullRange, with: placeholder)
                    }
                }
            }
        }
        
        // Build the attributed string
        let parts = workingText.split(separator: "[[[", omittingEmptySubsequences: false)
        
        for part in parts {
            if part.contains("]]]") {
                let components = part.split(separator: "]]]", maxSplits: 1)
                if let indexStr = components.first,
                   let index = Int(indexStr),
                   index < segments.count {
                    var styled = AttributedString(segments[index].0)
                    segments[index].2(&styled)
                    result += styled
                    
                    if components.count > 1 {
                        result += AttributedString(components[1])
                    }
                }
            } else {
                result += AttributedString(part)
            }
        }
        
        // Handle URLs
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)") {
            let text = String(result.characters)
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches.reversed() {
                if let textRange = Range(match.range(at: 1), in: text),
                   let urlRange = Range(match.range(at: 2), in: text),
                   let fullRange = Range(match.range, in: text),
                   let url = URL(string: String(text[urlRange])) {
                    
                    let linkText = String(text[textRange])
                    var link = AttributedString(linkText)
                    link.link = url
                    link.foregroundColor = .accentColor
                    link.underlineStyle = .single
                    
                    if let rangeInResult = result.range(of: String(text[fullRange])) {
                        result.replaceSubrange(rangeInResult, with: link)
                    }
                }
            }
        }
        
        return result.characters.isEmpty ? AttributedString(text) : result
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: .newlines)
        var inCodeBlock = false
        var codeBlockLines: [String] = []
        var listCounter = 1
        var tableLines: [String] = []
        var inTable = false
        
        for (index, line) in lines.enumerated() {
            // Code blocks
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCodeBlock {
                    elements.append(MarkdownElement(type: .codeBlock, content: codeBlockLines.joined(separator: "\n")))
                    codeBlockLines = []
                }
                inCodeBlock.toggle()
                continue
            }
            
            if inCodeBlock {
                codeBlockLines.append(line)
                continue
            }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for table
            if trimmed.contains("|") && !inTable {
                // Check if this looks like a table header
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    if isTableSeparator(nextLine) {
                        // Start of a table
                        inTable = true
                        tableLines = [line]
                        continue
                    }
                }
            }
            
            // Continue collecting table lines
            if inTable {
                if trimmed.contains("|") || isTableSeparator(trimmed) {
                    tableLines.append(line)
                    continue
                } else {
                    // End of table
                    if let table = parseTable(from: tableLines) {
                        elements.append(table)
                    }
                    tableLines = []
                    inTable = false
                    // Process the current line normally
                }
            }
            
            // Empty lines
            if trimmed.isEmpty {
                elements.append(MarkdownElement(type: .emptyLine, content: ""))
                listCounter = 1
                continue
            }
            
            // Headings
            if let level = headingLevel(for: line) {
                let content = line.dropFirst(level + 1).trimmingCharacters(in: .whitespaces)
                elements.append(MarkdownElement(type: .heading(level: level), content: content))
                listCounter = 1
                continue
            }
            
            // Checkboxes
            if trimmed.hasPrefix("- [ ]") {
                let content = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                elements.append(MarkdownElement(type: .checkbox(isChecked: false, content: content), content: content))
                continue
            }
            if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                let content = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                elements.append(MarkdownElement(type: .checkbox(isChecked: true, content: content), content: content))
                continue
            }
            
            // List items
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                elements.append(MarkdownElement(type: .listItem(isOrdered: false, number: 0), content: content))
                continue
            }
            
            // Ordered list items
            if let match = trimmed.firstMatch(of: /^(\d+)\.\s+(.*)$/) {
                let content = String(match.2)
                elements.append(MarkdownElement(type: .listItem(isOrdered: true, number: listCounter), content: content))
                listCounter += 1
                continue
            }
            
            // Paragraphs
            elements.append(MarkdownElement(type: .paragraph, content: line))
            listCounter = 1
        }
        
        // Handle any remaining code block
        if inCodeBlock && !codeBlockLines.isEmpty {
            elements.append(MarkdownElement(type: .codeBlock, content: codeBlockLines.joined(separator: "\n")))
        }
        
        // Handle any remaining table
        if inTable && !tableLines.isEmpty {
            if let table = parseTable(from: tableLines) {
                elements.append(table)
            }
        }
        
        return elements
    }
    
    private func headingLevel(for line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Check for heading levels up to 6
        for level in (1...6).reversed() {
            let prefix = String(repeating: "#", count: level) + " "
            if trimmed.hasPrefix(prefix) {
                return level
            }
        }
        return nil
    }
    
    private func findLineIndex(for element: MarkdownElement) -> Int? {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if case .checkbox(let isChecked, let content) = element.type {
                if (isChecked && (trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]"))) ||
                   (!isChecked && trimmed.hasPrefix("- [ ]")) {
                    let lineContent = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                    if lineContent == content {
                        return index
                    }
                }
            }
        }
        return nil
    }
    
    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Check if line contains only |, -, :, and spaces
        let pattern = "^\\|?[\\s\\-:]+\\|[\\s\\-:|]+\\|?$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func parseTable(from lines: [String]) -> MarkdownElement? {
        guard lines.count >= 2 else { return nil }
        
        // Parse header
        let headerLine = lines[0]
        let headers = parseTableRow(headerLine)
        
        // Skip separator line
        guard lines.count > 2 else {
            return MarkdownElement(type: .table(headers: headers, rows: []), content: "")
        }
        
        // Parse data rows
        var rows: [[String]] = []
        for i in 2..<lines.count {
            let row = parseTableRow(lines[i])
            if !row.isEmpty {
                // Ensure row has same number of columns as headers
                var adjustedRow = row
                while adjustedRow.count < headers.count {
                    adjustedRow.append("")
                }
                if adjustedRow.count > headers.count {
                    adjustedRow = Array(adjustedRow.prefix(headers.count))
                }
                rows.append(adjustedRow)
            }
        }
        
        return MarkdownElement(type: .table(headers: headers, rows: rows), content: "")
    }
    
    private func parseTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Remove leading and trailing pipes if present
        var content = trimmed
        if content.hasPrefix("|") {
            content = String(content.dropFirst())
        }
        if content.hasSuffix("|") {
            content = String(content.dropLast())
        }
        
        // Split by pipes and trim each cell
        return content.split(separator: "|").map { cell in
            cell.trimmingCharacters(in: .whitespaces)
        }
    }
}

private struct MarkdownElement {
    let id = UUID()
    let type: ElementType
    let content: String
    
    enum ElementType {
        case heading(level: Int)
        case paragraph
        case codeBlock
        case listItem(isOrdered: Bool, number: Int)
        case checkbox(isChecked: Bool, content: String)
        case emptyLine
        case table(headers: [String], rows: [[String]])
    }
}