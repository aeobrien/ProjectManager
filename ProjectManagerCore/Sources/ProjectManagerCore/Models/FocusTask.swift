import Foundation

public struct FocusTask: Identifiable, Codable, Hashable {
    public let id: UUID
    public let text: String
    public var status: TaskStatus
    public let projectId: UUID
    public var dueDate: Date?
    public var completedDate: Date?
    public var createdDate: Date
    public var lastModified: Date
    
    public init(text: String, status: TaskStatus = .todo, projectId: UUID, dueDate: Date? = nil, completedDate: Date? = nil) {
        self.id = UUID()
        self.text = text
        self.status = status
        self.projectId = projectId
        self.dueDate = dueDate
        self.completedDate = completedDate
        self.createdDate = Date()
        self.lastModified = Date()
    }
    
    // Legacy compatibility
    public var isCompleted: Bool {
        get { status == .completed }
        set { 
            status = newValue ? .completed : .todo
            lastModified = Date()
        }
    }
    
    public var displayText: String {
        // Remove markdown checkbox formatting if present
        let cleanText = text
            .replacingOccurrences(of: "- [ ] ", with: "")
            .replacingOccurrences(of: "- [x] ", with: "")
            .replacingOccurrences(of: "- [X] ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanText
    }
    
    public mutating func updateStatus(_ newStatus: TaskStatus) {
        status = newStatus
        lastModified = Date()
        
        // Set or clear completed date based on status
        if newStatus == .completed && completedDate == nil {
            completedDate = Date()
        } else if newStatus != .completed {
            completedDate = nil
        }
    }
}