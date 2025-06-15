import Foundation

struct FocusedProject: Identifiable, Codable, Hashable {
    let id: UUID
    let projectId: UUID
    var status: ProjectStatus
    var priority: Int
    var lastWorkedOn: Date?
    var activatedDate: Date?
    
    // Non-codable computed properties
    var project: Project? {
        // This will be resolved by FocusManager when loading
        return nil
    }
    
    init(projectId: UUID, status: ProjectStatus = .inactive, priority: Int = 0) {
        self.id = UUID()
        self.projectId = projectId
        self.status = status
        self.priority = priority
        self.lastWorkedOn = nil
        self.activatedDate = status == .active ? Date() : nil
    }
    
    mutating func activate() {
        status = .active
        activatedDate = Date()
        lastWorkedOn = Date()
    }
    
    mutating func deactivate() {
        status = .inactive
        activatedDate = nil
    }
    
    mutating func markAsWorkedOn() {
        lastWorkedOn = Date()
    }
    
    var isStale: Bool {
        guard status == .active, let lastWorked = lastWorkedOn else { return false }
        let daysSinceLastWork = Calendar.current.dateComponents([.day], from: lastWorked, to: Date()).day ?? 0
        return daysSinceLastWork >= 7
    }
    
    static func == (lhs: FocusedProject, rhs: FocusedProject) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}