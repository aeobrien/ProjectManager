import Foundation

class MarkdownParser {
    static func parseProjectOverview(from content: String) -> ProjectOverview {
        var overview = ProjectOverview()
        
        let sections = content.components(separatedBy: "\n## ")
        
        for section in sections {
            let lines = section.split(separator: "\n", omittingEmptySubsequences: false)
            guard !lines.isEmpty else { continue }
            
            let headerLine = lines[0].trimmingCharacters(in: .whitespaces)
            let contentLines = Array(lines.dropFirst())
            let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch headerLine {
            case "Overview":
                overview.overview = content
            case "Current Status":
                overview.currentStatus = content
            case "To-Do List":
                overview.todoItems = parseTodoItems(from: contentLines)
            case "Log":
                overview.log = content
            case "Related Projects":
                overview.relatedProjects = parseRelatedProjects(from: content)
            case "Notes":
                overview.notes = content
            default:
                break
            }
        }
        
        return overview
    }
    
    private static func parseTodoItems(from lines: [String.SubSequence]) -> [TodoItem] {
        var items: [TodoItem] = []
        
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("- [ ]") {
                let text = String(trimmedLine.dropFirst(6))
                items.append(TodoItem(text: text, isCompleted: false, lineNumber: index))
            } else if trimmedLine.hasPrefix("- [x]") || trimmedLine.hasPrefix("- [X]") {
                let text = String(trimmedLine.dropFirst(6))
                items.append(TodoItem(text: text, isCompleted: true, lineNumber: index))
            }
        }
        
        return items
    }
    
    private static func parseRelatedProjects(from content: String) -> [String] {
        let lines = content.split(separator: "\n")
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                return String(trimmed.dropFirst(2))
            }
            return nil
        }
    }
    
    static func updateTodoSection(in content: String, with todoItems: [TodoItem]) -> String {
        var lines = content.components(separatedBy: "\n")
        
        guard let todoSectionStart = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## To-Do List" }) else {
            return content
        }
        
        var todoSectionEnd = todoSectionStart + 1
        while todoSectionEnd < lines.count {
            let line = lines[todoSectionEnd].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("##") && !line.hasPrefix("###") {
                break
            }
            todoSectionEnd += 1
        }
        
        let newTodoLines = todoItems.map { $0.markdownLine }
        let todoSection = ["## To-Do List"] + (newTodoLines.isEmpty ? [""] : newTodoLines)
        
        lines.removeSubrange((todoSectionStart..<todoSectionEnd))
        lines.insert(contentsOf: todoSection, at: todoSectionStart)
        
        return lines.joined(separator: "\n")
    }
    
    static func updateSection(in content: String, sectionName: String, newContent: String) -> String {
        var lines = content.components(separatedBy: "\n")
        
        guard let sectionStart = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## \(sectionName)" }) else {
            return content
        }
        
        var sectionEnd = sectionStart + 1
        while sectionEnd < lines.count {
            let line = lines[sectionEnd].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("##") && !line.hasPrefix("###") {
                break
            }
            sectionEnd += 1
        }
        
        let newContentLines = newContent.isEmpty ? [""] : newContent.components(separatedBy: "\n")
        let section = ["## \(sectionName)"] + newContentLines
        
        lines.removeSubrange((sectionStart..<sectionEnd))
        lines.insert(contentsOf: section, at: sectionStart)
        
        return lines.joined(separator: "\n")
    }
}