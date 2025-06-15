import Foundation

enum ProjectStatus: String, CaseIterable, Codable {
    case inactive = "Inactive"
    case active = "Active"
    
    var color: String {
        switch self {
        case .inactive:
            return "gray"
        case .active:
            return "blue"
        }
    }
    
    var description: String {
        switch self {
        case .inactive:
            return "Projects not currently in focus"
        case .active:
            return "Projects you're actively working on (3-5 max)"
        }
    }
}

enum TaskStatus: String, CaseIterable, Codable {
    case todo = "To Do"
    case inProgress = "In Progress"
    case completed = "Completed"
    
    var color: String {
        switch self {
        case .todo:
            return "gray"
        case .inProgress:
            return "orange"
        case .completed:
            return "green"
        }
    }
    
    var description: String {
        switch self {
        case .todo:
            return "Tasks waiting to be started"
        case .inProgress:
            return "Tasks currently being worked on"
        case .completed:
            return "Finished tasks"
        }
    }
}