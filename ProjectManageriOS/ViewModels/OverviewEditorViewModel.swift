import Foundation
import SwiftUI
import Combine
import ProjectManagerCore

@MainActor
class OverviewEditorViewModel: ObservableObject {
    @Published var projectOverview: ProjectOverview
    @Published var isLoading = false
    @Published var hasChanges = false
    @Published var errorMessage: String?
    
    let project: Project
    private let fileSystem: FileSystemProtocol
    private var originalContent: ProjectOverview?
    
    init(project: Project, fileSystem: FileSystemProtocol = LocalFileSystem()) {
        self.project = project
        self.fileSystem = fileSystem
        self.projectOverview = ProjectOverview()
    }
    
    func loadOverview() {
        isLoading = true
        errorMessage = nil
        
        // Use synced content if available (iOS)
        if let overviewContent = project.overviewContent {
            parseOverview(from: overviewContent)
            originalContent = projectOverview
        } else {
            // Try to read from file system (macOS)
            do {
                if fileSystem.fileExists(at: project.overviewPath) {
                    let content = try fileSystem.readFile(at: project.overviewPath)
                    parseOverview(from: content)
                    originalContent = projectOverview
                } else {
                    // Create default overview
                    projectOverview = ProjectOverview()
                    projectOverview.currentStatus = "New project - add description here"
                    projectOverview.nextSteps = "- [ ] Define project goals\n- [ ] Set up initial structure"
                    originalContent = projectOverview
                }
            } catch {
                errorMessage = "Failed to load overview: \(error.localizedDescription)"
                projectOverview = ProjectOverview()
            }
        }
        
        isLoading = false
        hasChanges = false
    }
    
    func saveOverview() async throws {
        let content = generateMarkdown()
        
        do {
            try fileSystem.writeFile(contents: content, to: project.overviewPath)
            originalContent = projectOverview
            hasChanges = false
            
            // Sync with CloudKit/Dropbox
            await syncOverview()
        } catch {
            throw OverviewError.saveFailed(error.localizedDescription)
        }
    }
    
    func revertChanges() {
        if let original = originalContent {
            projectOverview = original
            hasChanges = false
        }
    }
    
    private func parseOverview(from content: String) {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var currentSection = ""
        var descriptionLines: [String] = []
        var nextStepsLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("# ") {
                // Project name is in the file, but not stored in ProjectOverview
            } else if trimmed == "## Description" {
                currentSection = "description"
            } else if trimmed == "## Next Steps" {
                currentSection = "nextSteps"
            } else if !trimmed.isEmpty {
                switch currentSection {
                case "description":
                    descriptionLines.append(String(line))
                case "nextSteps":
                    nextStepsLines.append(String(line))
                default:
                    break
                }
            }
        }
        
        projectOverview.currentStatus = descriptionLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        projectOverview.nextSteps = nextStepsLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func generateMarkdown() -> String {
        """
        # \(project.name)
        
        ## Current Status
        \(projectOverview.currentStatus)
        
        ## Next Steps
        \(projectOverview.nextSteps)
        """
    }
    
    private func syncOverview() async {
        // TODO: Implement sync with CloudKit/Dropbox
        print("Syncing overview for project: \(project.name)")
    }
    
    func updateDescription(_ newDescription: String) {
        projectOverview.currentStatus = newDescription
        checkForChanges()
    }
    
    func updateNextSteps(_ newNextSteps: String) {
        projectOverview.nextSteps = newNextSteps
        checkForChanges()
    }
    
    private func checkForChanges() {
        hasChanges = projectOverview != originalContent
    }
}

enum OverviewError: LocalizedError {
    case loadFailed(String)
    case saveFailed(String)
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load overview: \(message)"
        case .saveFailed(let message):
            return "Failed to save overview: \(message)"
        case .syncFailed(let message):
            return "Failed to sync overview: \(message)"
        }
    }
}