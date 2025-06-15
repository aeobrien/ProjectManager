import Foundation

struct FocusTask: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    var status: TaskStatus
    let projectId: UUID
    var dueDate: Date?
    var createdDate: Date
    var lastModified: Date
    
    init(text: String, status: TaskStatus = .todo, projectId: UUID, dueDate: Date? = nil) {
        self.id = UUID()
        self.text = text
        self.status = status
        self.projectId = projectId
        self.dueDate = dueDate
        self.createdDate = Date()
        self.lastModified = Date()
    }
    
    // Legacy compatibility
    var isCompleted: Bool {
        get { status == .completed }
        set { 
            status = newValue ? .completed : .todo
            lastModified = Date()
        }
    }
    
    var displayText: String {
        // Remove markdown checkbox formatting if present
        let cleanText = text
            .replacingOccurrences(of: "- [ ] ", with: "")
            .replacingOccurrences(of: "- [x] ", with: "")
            .replacingOccurrences(of: "- [X] ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanText
    }
    
    mutating func updateStatus(_ newStatus: TaskStatus) {
        status = newStatus
        lastModified = Date()
    }
}