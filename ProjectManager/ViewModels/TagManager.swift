import Foundation
import SwiftUI
import ProjectManagerCore

class TagManager: ObservableObject {
    @Published var allTags: Set<String> = []
    
    init() {
        loadTags()
    }
    
    // Extract tags from a project's tags string (format: #tag1 #tag2 #tag3)
    func extractTags(from tagsString: String) -> [String] {
        let pattern = #"#(\w+)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let matches = regex?.matches(in: tagsString, options: [], range: NSRange(location: 0, length: tagsString.utf16.count)) ?? []
        
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: tagsString) {
                return String(tagsString[range])
            }
            return nil
        }
    }
    
    // Format tags array into string for storage
    func formatTags(_ tags: [String]) -> String {
        return tags.map { "#\($0)" }.joined(separator: " ")
    }
    
    // Add a new tag to the global list
    func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: " ", with: "_")
        
        if !cleanTag.isEmpty {
            allTags.insert(cleanTag)
            saveTags()
        }
    }
    
    // Remove a tag from the global list
    func removeTag(_ tag: String) {
        allTags.remove(tag)
        saveTags()
    }
    
    // Save tags to UserDefaults
    private func saveTags() {
        UserDefaults.standard.set(Array(allTags), forKey: "projectManagerAllTags")
    }
    
    // Load tags from UserDefaults
    private func loadTags() {
        if let savedTags = UserDefaults.standard.array(forKey: "projectManagerAllTags") as? [String] {
            allTags = Set(savedTags)
        }
    }
    
    // Scan all projects and collect all used tags
    func syncTagsFromProjects(_ projects: [Project]) {
        var foundTags = Set<String>()
        
        for project in projects {
            let viewModel = OverviewEditorViewModel(project: project)
            viewModel.loadOverview()
            
            let projectTags = extractTags(from: viewModel.projectOverview.tags)
            foundTags.formUnion(projectTags)
        }
        
        // Merge with existing tags
        allTags.formUnion(foundTags)
        saveTags()
    }
}