import Foundation

public struct FocusedProject: Identifiable, Codable, Hashable {
    public let id: UUID
    public let projectId: UUID
    public var status: ProjectStatus
    public var priority: Int
    public var lastWorkedOn: Date?
    public var activatedDate: Date?
    
    // Non-codable computed properties
    public var project: Project? {
        // This will be resolved by FocusManager when loading
        return nil
    }
    
    public init(projectId: UUID, status: ProjectStatus = .inactive, priority: Int = 0) {
        self.id = UUID()
        self.projectId = projectId
        self.status = status
        self.priority = priority
        self.lastWorkedOn = nil
        self.activatedDate = status == .active ? Date() : nil
    }
    
    public mutating func activate() {
        status = .active
        activatedDate = Date()
        lastWorkedOn = Date()
    }
    
    public mutating func deactivate() {
        status = .inactive
        activatedDate = nil
    }
    
    public mutating func markAsWorkedOn() {
        lastWorkedOn = Date()
    }
    
    public var isStale: Bool {
        guard status == .active, let lastWorked = lastWorkedOn else { return false }
        let daysSinceLastWork = Calendar.current.dateComponents([.day], from: lastWorked, to: Date()).day ?? 0
        return daysSinceLastWork >= 7
    }
    
    public static func == (lhs: FocusedProject, rhs: FocusedProject) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}