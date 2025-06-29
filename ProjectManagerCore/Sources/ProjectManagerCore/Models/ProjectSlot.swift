import Foundation

public struct ProjectSlot: Codable, Identifiable {
    public let id: UUID
    public var requiredTags: Set<String>  // Empty set means no requirements
    public var occupiedBy: UUID?          // Project ID if occupied
    
    public init(id: UUID = UUID(), requiredTags: Set<String> = [], occupiedBy: UUID? = nil) {
        self.id = id
        self.requiredTags = requiredTags
        self.occupiedBy = occupiedBy
    }
    
    public var isEmpty: Bool {
        occupiedBy == nil
    }
    
    public var hasRequirements: Bool {
        !requiredTags.isEmpty
    }
    
    public func canAcceptProject(withTags projectTags: Set<String>) -> Bool {
        // If no requirements, any project can occupy this slot
        if requiredTags.isEmpty {
            return true
        }
        
        // Project must have at least one of the required tags (OR logic)
        return !requiredTags.isDisjoint(with: projectTags)
    }
}