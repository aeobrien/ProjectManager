import Foundation
import Combine

class OverviewEditorViewModel: ObservableObject {
    @Published var projectOverview = ProjectOverview()
    @Published var hasChanges = false
    @Published var rawContent: String = ""
    @Published var hasUnstructuredContent = false
    
    let project: Project
    private var originalContent: String = ""
    private let fileMonitor = FileMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var lastSaveTime: Date?
    
    init(project: Project) {
        self.project = project
        loadOverview()
        setupFileMonitoring()
    }
    
    private func setupFileMonitoring() {
        if project.hasOverview {
            fileMonitor.startMonitoring(url: project.overviewPath)
            
            fileMonitor.$lastUpdate
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    if let lastSave = self.lastSaveTime,
                       Date().timeIntervalSince(lastSave) < 1.0 {
                        return
                    }
                    self.loadOverview()
                }
                .store(in: &cancellables)
        }
    }
    
    func loadOverview() {
        guard project.hasOverview else {
            createOverviewFile()
            return
        }
        
        // Ensure we have access to the file
        let accessing = project.overviewPath.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                project.overviewPath.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let content = try String(contentsOf: project.overviewPath, encoding: .utf8)
            originalContent = content
            rawContent = content
            
            // Check if file has the expected structure
            let hasExpectedStructure = ProjectOverview.sectionHeaders.allSatisfy { header in
                content.contains(header)
            }
            
            if hasExpectedStructure {
                projectOverview = MarkdownParser.parseProjectOverview(from: content)
                hasUnstructuredContent = false
            } else {
                // File exists but doesn't have the expected structure
                hasUnstructuredContent = true
                projectOverview = MarkdownParser.parseProjectOverview(from: content)
            }
            
            hasChanges = false
        } catch {
            print("Error loading overview: \(error)")
            print("File path: \(project.overviewPath)")
        }
    }
    
    private func createOverviewFile() {
        let content = ProjectOverview.createTemplate(projectName: project.name)
        do {
            try content.write(to: project.overviewPath, atomically: true, encoding: .utf8)
            originalContent = content
            projectOverview = MarkdownParser.parseProjectOverview(from: content)
            hasChanges = false
        } catch {
            print("Error creating overview file: \(error)")
        }
    }
    
    private func formatNextSteps(_ nextSteps: String) -> String {
        let lines = nextSteps.split(separator: "\n", omittingEmptySubsequences: false)
        var formattedLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }
            
            // Check if line already has checkbox formatting
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                formattedLines.append(String(line))
            } else if trimmed.hasPrefix("- ") {
                // Line starts with dash but no checkbox, add checkbox
                formattedLines.append("- [ ] " + trimmed.dropFirst(2))
            } else {
                // Plain text, convert to checkbox
                formattedLines.append("- [ ] " + trimmed)
            }
        }
        
        return formattedLines.joined(separator: "\n")
    }
    
    func saveOverview() {
        var content = originalContent
        
        // Format next steps before saving
        projectOverview.nextSteps = formatNextSteps(projectOverview.nextSteps)
        
        content = MarkdownParser.updateSection(in: content, sectionName: "Version History", newContent: projectOverview.versionHistory)
        content = MarkdownParser.updateSection(in: content, sectionName: "Core Concept", newContent: projectOverview.coreConcept)
        content = MarkdownParser.updateSection(in: content, sectionName: "Guiding Principles & Intentions", newContent: projectOverview.guidingPrinciples)
        content = MarkdownParser.updateSection(in: content, sectionName: "Key Features & Functionality", newContent: projectOverview.keyFeatures)
        content = MarkdownParser.updateSection(in: content, sectionName: "Architecture & Structure", newContent: projectOverview.architecture)
        content = MarkdownParser.updateSection(in: content, sectionName: "Implementation Roadmap", newContent: projectOverview.implementationRoadmap)
        content = MarkdownParser.updateSection(in: content, sectionName: "Current Status & Progress", newContent: projectOverview.currentStatus)
        content = MarkdownParser.updateSection(in: content, sectionName: "Next Steps", newContent: projectOverview.nextSteps)
        content = MarkdownParser.updateSection(in: content, sectionName: "Challenges & Solutions", newContent: projectOverview.challenges)
        content = MarkdownParser.updateSection(in: content, sectionName: "User/Audience Experience", newContent: projectOverview.userExperience)
        content = MarkdownParser.updateSection(in: content, sectionName: "Success Metrics", newContent: projectOverview.successMetrics)
        content = MarkdownParser.updateSection(in: content, sectionName: "Research & References", newContent: projectOverview.research)
        content = MarkdownParser.updateSection(in: content, sectionName: "Open Questions & Considerations", newContent: projectOverview.openQuestions)
        content = MarkdownParser.updateSection(in: content, sectionName: "Project Log", newContent: projectOverview.projectLog)
        content = MarkdownParser.updateSection(in: content, sectionName: "External Files", newContent: projectOverview.externalFiles)
        content = MarkdownParser.updateSection(in: content, sectionName: "Repositories", newContent: projectOverview.repositories)
        
        do {
            lastSaveTime = Date()
            try content.write(to: project.overviewPath, atomically: true, encoding: .utf8)
            originalContent = content
            hasChanges = false
        } catch {
            print("Error saving overview: \(error)")
        }
    }
    
    func updateProjectLogWithGitHubCommits() {
        let repositories = GitHubService.shared.extractRepositoriesFromText(projectOverview.repositories)
        
        guard !repositories.isEmpty else {
            print("No GitHub repositories found in project")
            return
        }
        
        print("Found \(repositories.count) GitHub repositories")
        
        GitHubService.shared.fetchRecentCommits(for: repositories) { [weak self] commits in
            guard let self = self, !commits.isEmpty else {
                print("No commits found")
                return
            }
            
            DispatchQueue.main.async {
                self.insertCommitsIntoLog(commits, repositories: repositories)
            }
        }
    }
    
    private func insertCommitsIntoLog(_ commits: [GitHubCommit], repositories: [GitHubRepository]) {
        var logEntries: [String] = []
        
        for commit in commits.prefix(10) { // Limit to 10 most recent commits
            // Find which repository this commit belongs to by matching commit to repo
            let repoName = repositories.first?.repo ?? "Unknown"
            let formattedCommit = GitHubService.shared.formatCommitForLog(commit, repositoryName: repoName)
            if !formattedCommit.isEmpty {
                logEntries.append(formattedCommit)
            }
        }
        
        if !logEntries.isEmpty {
            let currentLog = projectOverview.projectLog
            
            // Insert commits as individual log entries at the beginning
            if currentLog.isEmpty {
                projectOverview.projectLog = logEntries.joined(separator: "\n\n")
            } else {
                // Add new commits at the beginning of the log
                projectOverview.projectLog = logEntries.joined(separator: "\n\n") + "\n\n" + currentLog
            }
            
            saveOverview()
            print("Updated project log with \(logEntries.count) GitHub commits")
        }
    }
    
    func migrateToStructuredFormat() {
        // Create backup first
        let backupPath = project.folderPath.appendingPathComponent("overviewbackup.md")
        
        do {
            // Backup the original file
            try originalContent.write(to: backupPath, atomically: true, encoding: .utf8)
            
            // Create structured content
            var structuredContent = "# \(project.name)\n\n"
            
            // Add all sections with their content
            structuredContent += "## Version History\n"
            if projectOverview.versionHistory.isEmpty {
                structuredContent += "- v0.1 - \(Date().formatted(date: .abbreviated, time: .omitted)) - Migrated to structured format"
            } else {
                structuredContent += projectOverview.versionHistory
            }
            structuredContent += "\n\n"
            
            // Add all sections with empty content if not provided
            structuredContent += "## Core Concept\n"
            structuredContent += projectOverview.coreConcept
            structuredContent += "\n\n"
            
            structuredContent += "## Guiding Principles & Intentions\n"
            structuredContent += projectOverview.guidingPrinciples
            structuredContent += "\n\n"
            
            structuredContent += "## Key Features & Functionality\n"
            structuredContent += projectOverview.keyFeatures
            structuredContent += "\n\n"
            
            structuredContent += "## Architecture & Structure\n"
            structuredContent += projectOverview.architecture
            structuredContent += "\n\n"
            
            structuredContent += "## Implementation Roadmap\n"
            structuredContent += projectOverview.implementationRoadmap
            structuredContent += "\n\n"
            
            structuredContent += "## Current Status & Progress\n"
            structuredContent += projectOverview.currentStatus
            structuredContent += "\n\n"
            
            structuredContent += "## Next Steps\n"
            if !projectOverview.nextSteps.isEmpty {
                // Convert lines to checkboxes if not already
                let lines = projectOverview.nextSteps.split(separator: "\n")
                let checkboxLines = lines.map { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                        return String(line)
                    } else if trimmed.hasPrefix("- ") {
                        return "- [ ] " + trimmed.dropFirst(2)
                    } else if !trimmed.isEmpty {
                        return "- [ ] " + trimmed
                    }
                    return String(line)
                }
                structuredContent += checkboxLines.joined(separator: "\n")
            }
            structuredContent += "\n\n"
            
            structuredContent += "## Challenges & Solutions\n"
            structuredContent += projectOverview.challenges
            structuredContent += "\n\n"
            
            structuredContent += "## User/Audience Experience\n"
            structuredContent += projectOverview.userExperience
            structuredContent += "\n\n"
            
            structuredContent += "## Success Metrics\n"
            structuredContent += projectOverview.successMetrics
            structuredContent += "\n\n"
            
            structuredContent += "## Research & References\n"
            structuredContent += projectOverview.research
            structuredContent += "\n\n"
            
            structuredContent += "## Open Questions & Considerations\n"
            structuredContent += projectOverview.openQuestions
            structuredContent += "\n\n"
            
            structuredContent += "## Project Log\n"
            if projectOverview.projectLog.isEmpty {
                structuredContent += "### \(Date().formatted(date: .abbreviated, time: .omitted))\nMigrated to structured format"
            } else {
                structuredContent += projectOverview.projectLog
            }
            structuredContent += "\n\n"
            
            structuredContent += "## External Files\n"
            structuredContent += projectOverview.externalFiles
            structuredContent += "\n\n"
            
            structuredContent += "## Repositories\n"
            structuredContent += projectOverview.repositories
            
            // Save the structured content
            try structuredContent.write(to: project.overviewPath, atomically: true, encoding: .utf8)
            
            // Update state
            originalContent = structuredContent
            rawContent = structuredContent
            hasUnstructuredContent = false
            projectOverview = MarkdownParser.parseProjectOverview(from: structuredContent)
            hasChanges = false
            
        } catch {
            print("Error migrating to structured format: \(error)")
        }
    }
    
}
