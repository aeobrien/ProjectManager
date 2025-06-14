import Foundation
import Combine

class OverviewEditorViewModel: ObservableObject {
    @Published var projectOverview = ProjectOverview()
    @Published var hasChanges = false
    @Published var rawContent: String = ""
    @Published var hasUnstructuredContent = false
    
    private let project: Project
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
            
            print("Loaded content (\(content.count) characters)")
            print("First 200 chars: \(String(content.prefix(200)))")
            
            // Check if file has the expected structure
            let hasExpectedStructure = ProjectOverview.sectionHeaders.allSatisfy { header in
                content.contains(header)
            }
            
            print("Has expected structure: \(hasExpectedStructure)")
            
            if hasExpectedStructure {
                projectOverview = MarkdownParser.parseProjectOverview(from: content)
                hasUnstructuredContent = false
            } else {
                // File exists but doesn't have the expected structure
                hasUnstructuredContent = true
                projectOverview = ProjectOverview() // Empty structured content
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
    
    func saveOverview() {
        var content = originalContent
        
        content = MarkdownParser.updateSection(in: content, sectionName: "Overview", newContent: projectOverview.overview)
        content = MarkdownParser.updateSection(in: content, sectionName: "Current Status", newContent: projectOverview.currentStatus)
        content = MarkdownParser.updateTodoSection(in: content, with: projectOverview.todoItems)
        content = MarkdownParser.updateSection(in: content, sectionName: "Log", newContent: projectOverview.log)
        
        let relatedProjectsContent = projectOverview.relatedProjects.map { "- \($0)" }.joined(separator: "\n")
        content = MarkdownParser.updateSection(in: content, sectionName: "Related Projects", newContent: relatedProjectsContent)
        
        content = MarkdownParser.updateSection(in: content, sectionName: "Notes", newContent: projectOverview.notes)
        
        do {
            lastSaveTime = Date()
            try content.write(to: project.overviewPath, atomically: true, encoding: .utf8)
            originalContent = content
            hasChanges = false
        } catch {
            print("Error saving overview: \(error)")
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
            
            for header in ProjectOverview.sectionHeaders {
                structuredContent += "\(header)\n"
                
                switch header {
                case "## Overview":
                    structuredContent += projectOverview.overview.isEmpty ? "[Short description]" : projectOverview.overview
                case "## Current Status":
                    structuredContent += projectOverview.currentStatus.isEmpty ? "[Where the project stands now]" : projectOverview.currentStatus
                case "## To-Do List":
                    if projectOverview.todoItems.isEmpty {
                        structuredContent += "- [ ] Example task"
                    } else {
                        structuredContent += projectOverview.todoItems.map { $0.markdownLine }.joined(separator: "\n")
                    }
                case "## Log":
                    if projectOverview.log.isEmpty {
                        structuredContent += "- \(Date().formatted(date: .numeric, time: .omitted)): Migrated to structured format"
                    } else {
                        structuredContent += projectOverview.log
                    }
                case "## Related Projects":
                    if !projectOverview.relatedProjects.isEmpty {
                        structuredContent += projectOverview.relatedProjects.map { "- \($0)" }.joined(separator: "\n")
                    }
                case "## Notes":
                    structuredContent += projectOverview.notes.isEmpty ? "[Any extra context or ideas]" : projectOverview.notes
                default:
                    break
                }
                structuredContent += "\n\n"
            }
            
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
    
    func addTodoItem(_ text: String) {
        let newItem = TodoItem(text: text, isCompleted: false)
        projectOverview.todoItems.append(newItem)
        hasChanges = true
        saveOverview()
    }
    
    func toggleTodoItem(_ item: TodoItem) {
        if let index = projectOverview.todoItems.firstIndex(where: { $0.id == item.id }) {
            projectOverview.todoItems[index].isCompleted.toggle()
            hasChanges = true
            saveOverview()
        }
    }
    
    func deleteTodoItem(_ item: TodoItem) {
        projectOverview.todoItems.removeAll { $0.id == item.id }
        hasChanges = true
        saveOverview()
    }
    
    func updateTodoText(_ item: TodoItem, newText: String) {
        if let index = projectOverview.todoItems.firstIndex(where: { $0.id == item.id }) {
            projectOverview.todoItems[index].text = newText
            hasChanges = true
            saveOverview()
        }
    }
}