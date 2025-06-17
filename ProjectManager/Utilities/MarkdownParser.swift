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
            
            // Handle exact matches and common variations
            if headerLine == "Version History" {
                overview.versionHistory = content
            } else if headerLine == "Core Concept" {
                overview.coreConcept = content
            } else if headerLine == "Guiding Principles & Intentions" || headerLine == "Guiding Principles" {
                overview.guidingPrinciples = content
            } else if headerLine == "Key Features & Functionality" || headerLine == "Key Features" {
                overview.keyFeatures = content
            } else if headerLine == "Architecture & Structure" || headerLine == "Architecture" {
                overview.architecture = content
            } else if headerLine == "Implementation Roadmap" || headerLine == "Roadmap" {
                overview.implementationRoadmap = content
            } else if headerLine == "Current Status & Progress" || headerLine == "Current Status" || headerLine == "Status" {
                overview.currentStatus = content
            } else if headerLine == "Next Steps" {
                overview.nextSteps = content
            } else if headerLine.contains("Challenges") {
                // Catches "Challenges & Solutions", "Challenges and Proposed Solutions", etc.
                overview.challenges = content
            } else if headerLine == "User/Audience Experience" || headerLine == "User Experience" || headerLine == "Audience Experience" {
                overview.userExperience = content
            } else if headerLine == "Success Metrics" || headerLine == "Metrics" {
                overview.successMetrics = content
            } else if headerLine == "Research & References" || headerLine == "Research" || headerLine == "References" {
                overview.research = content
            } else if headerLine == "Open Questions & Considerations" || headerLine == "Open Questions" || headerLine == "Questions" || headerLine == "Notes & Ideas" || headerLine == "Notes" || headerLine == "Ideas" {
                overview.openQuestions = content
            } else if headerLine == "Project Log" || headerLine == "Log" {
                overview.projectLog = content
            } else if headerLine == "External Files" {
                overview.externalFiles = content
            } else if headerLine == "Repositories" {
                overview.repositories = content
            }
        }
        
        return overview
    }
    
    
    static func updateSection(in content: String, sectionName: String, newContent: String) -> String {
        var lines = content.components(separatedBy: "\n")
        
        // Try to find exact match first
        var sectionStart = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## \(sectionName)" })
        
        // If not found, try common alternatives
        if sectionStart == nil {
            let alternatives: [String: [String]] = [
                "Current Status & Progress": ["Current Status", "Status"],
                "Next Steps": ["Next Steps"]
            ]
            
            if let alts = alternatives[sectionName] {
                for alt in alts {
                    if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "## \(alt)" }) {
                        sectionStart = index
                        break
                    }
                }
            }
        }
        
        guard let sectionStartIndex = sectionStart else {
            return content
        }
        
        var sectionEnd = sectionStartIndex + 1
        while sectionEnd < lines.count {
            let line = lines[sectionEnd].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("##") && !line.hasPrefix("###") {
                break
            }
            sectionEnd += 1
        }
        
        let newContentLines = newContent.isEmpty ? [""] : newContent.components(separatedBy: "\n")
        let section = ["## \(sectionName)"] + newContentLines
        
        lines.removeSubrange((sectionStartIndex..<sectionEnd))
        lines.insert(contentsOf: section, at: sectionStartIndex)
        
        return lines.joined(separator: "\n")
    }
}