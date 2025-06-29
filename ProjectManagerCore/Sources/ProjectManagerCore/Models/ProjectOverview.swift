import Foundation

public struct ProjectOverview: Equatable {
    public var versionHistory: String = ""
    public var coreConcept: String = ""
    public var tags: String = ""
    public var guidingPrinciples: String = ""
    public var keyFeatures: String = ""
    public var architecture: String = ""
    public var implementationRoadmap: String = ""
    public var currentStatus: String = ""
    public var nextSteps: String = ""
    public var challenges: String = ""
    public var userExperience: String = ""
    public var successMetrics: String = ""
    public var research: String = ""
    public var openQuestions: String = ""
    public var projectLog: String = ""
    public var externalFiles: String = ""
    public var repositories: String = ""
    
    public init() {}
    
    public static let sectionHeaders = [
        "## Version History",
        "## Core Concept",
        "## Tags",
        "## Guiding Principles & Intentions",
        "## Key Features & Functionality",
        "## Architecture & Structure",
        "## Implementation Roadmap",
        "## Current Status & Progress",
        "## Next Steps",
        "## Challenges & Solutions",
        "## User/Audience Experience",
        "## Success Metrics",
        "## Research & References",
        "## Open Questions & Considerations",
        "## Project Log",
        "## External Files",
        "## Repositories"
    ]
    
    public static func createTemplate(projectName: String) -> String {
        let date = Date().formatted(date: .abbreviated, time: .omitted)
        return """
        # \(projectName)
        
        ## Version History
        - v0.1 - \(date) - Initial project creation
        
        ## Core Concept
        [Comprehensive overview of what the project is and its primary purpose]
        
        ## Tags
        [Add tags to categorize this project]
        
        ## Guiding Principles & Intentions
        [The underlying philosophy, values, and goals driving the project]
        
        ## Key Features & Functionality
        [Detailed list of all features/components with descriptions]
        
        ## Architecture & Structure
        [Technical architecture for tech projects / Content structure for books / Design framework for installations / etc.]
        
        ## Implementation Roadmap
        ### Phase 1: Foundation
        - [ ] Define project scope
        - [ ] Set up initial structure
        [Timeline if applicable]
        
        ### Phase 2: Development
        - [ ] Core implementation
        - [ ] Testing and refinement
        
        ## Current Status & Progress
        [Summary of where the project stands]
        - Phase 1: 0% complete
        - Phase 2: Not started
        
        ## Next Steps
        [Immediate actionable items, pulled from uncompleted roadmap tasks]
        
        ## Challenges & Solutions
        [Technical, creative, or logistical challenges with proposed/implemented solutions]
        
        ## User/Audience Experience
        [How the end user will interact with or experience the project]
        
        ## Success Metrics
        [Project-specific criteria for measuring success]
        
        ## Research & References
        [Supporting materials, inspiration sources, technical documentation, etc.]
        
        ## Open Questions & Considerations
        [Ongoing thoughts, future possibilities, parking lot for ideas]
        
        ## Project Log
        ### \(date)
        Project created
        
        ## External Files
        [Any files related to the project outside of the Obsidian folder and their locations]
        
        ## Repositories
        ### Local Repositories
        [Local repository paths and descriptions]
        
        ### GitHub Repositories
        [GitHub repository URLs and descriptions]
        """
    }
}