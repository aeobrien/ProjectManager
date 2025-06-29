import Foundation

struct TodoItem: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var isCompleted: Bool
    var lineNumber: Int?
    
    init(text: String, isCompleted: Bool, lineNumber: Int? = nil) {
        self.text = text
        self.isCompleted = isCompleted
        self.lineNumber = lineNumber
    }
    
    var markdownLine: String {
        return "- [\(isCompleted ? "x" : " ")] \(text)"
    }
}