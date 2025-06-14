import Foundation

struct ProjectOverview {
    var overview: String = ""
    var currentStatus: String = ""
    var todoItems: [TodoItem] = []
    var log: String = ""
    var relatedProjects: [String] = []
    var notes: String = ""
    
    static let sectionHeaders = [
        "## Overview",
        "## Current Status",
        "## To-Do List",
        "## Log",
        "## Related Projects",
        "## Notes"
    ]
    
    static func createTemplate(projectName: String) -> String {
        return """
        # \(projectName)
        
        ## Overview
        [Short description]
        
        ## Current Status
        [Where the project stands now]
        
        ## To-Do List
        - [ ] Example task
        
        ## Log
        - \(Date().formatted(date: .numeric, time: .omitted)): Created project
        
        ## Related Projects
        
        ## Notes
        [Any extra context or ideas]
        """
    }
}