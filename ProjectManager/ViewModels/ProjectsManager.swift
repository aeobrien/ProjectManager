import Foundation
import Combine
import ProjectManagerCore

class ProjectsManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    
    let tagManager = TagManager()
    private let preferencesManager = PreferencesManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let fileMonitor = FileMonitor()
    
    init() {
        setupBindings()
        scanProjects()
    }
    
    private func setupBindings() {
        preferencesManager.$projectsFolder
            .dropFirst() // Skip the initial value to avoid double scanning
            .sink { [weak self] folder in
                self?.scanProjects()
                if let folder = folder {
                    self?.fileMonitor.startMonitoring(url: folder)
                } else {
                    self?.fileMonitor.stopMonitoring()
                }
            }
            .store(in: &cancellables)
        
        fileMonitor.$lastUpdate
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.scanProjects()
            }
            .store(in: &cancellables)
    }
    
    func scanProjects() {
        guard let folder = preferencesManager.projectsFolder else {
            projects = []
            return
        }
        
        // Ensure we have access to the folder
        let accessing = folder.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isDirectoryKey, .isReadableKey],
                options: [.skipsHiddenFiles]
            )
            
            projects = contents.compactMap { url in
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    return nil
                }
                
                // Check if the folder is ignored
                let folderName = url.lastPathComponent
                if preferencesManager.isIgnored(folderName) {
                    return nil
                }
                
                return Project(folderPath: url)
            }
            
            sortProjects()
            
            // Sync tags from all projects
            tagManager.syncTagsFromProjects(projects)
            
            // Check for first run and migrate projects if needed
            checkAndMigrateProjects()
            
            // Save projects to shared app group for syncing
            saveProjectsToSharedStorage()
        } catch {
            print("Error scanning projects: \(error)")
            print("Folder path: \(folder.path)")
            print("Can read: \(FileManager.default.isReadableFile(atPath: folder.path))")
            projects = []
        }
    }
    
    private func saveProjectsToSharedStorage() {
        // Save projects to shared app group for CloudKit sync
        SimpleStorageManager.shared.save(projects, forKey: "shared_projects")
        print("Saved \(projects.count) projects to shared storage")
    }
    
    private func checkAndMigrateProjects() {
        // Check if migration has already been done
        let migrationKey = "project_migration_v1_completed"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }
        
        // Migrate all projects
        for project in projects {
            if project.hasOverview {
                migrateProjectOverview(project)
            }
        }
        
        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("Project migration completed for \(projects.count) projects")
    }
    
    private func migrateProjectOverview(_ project: Project) {
        do {
            let content = try String(contentsOf: project.overviewPath, encoding: .utf8)
            
            // Check if the new fields already exist
            if content.contains("## External Files") && content.contains("## Repositories") {
                return // Already migrated
            }
            
            // Add the new sections to the end
            let newSections = """
            
            ## External Files
            [Any files related to the project outside of the Obsidian folder and their locations]
            
            ## Repositories
            ### Local Repositories
            [Local repository paths and descriptions]
            
            ### GitHub Repositories
            [GitHub repository URLs and descriptions]
            """
            
            let updatedContent = content + newSections
            try updatedContent.write(to: project.overviewPath, atomically: true, encoding: .utf8)
            
            print("Migrated project: \(project.name)")
        } catch {
            print("Failed to migrate project \(project.name): \(error)")
        }
    }
    
    func loadProjects() {
        scanProjects()
    }
    
    private func sortProjects() {
        switch preferencesManager.sortOption {
        case .name:
            projects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .dateModified:
            projects.sort { project1, project2 in
                let date1 = getModificationDate(for: project1.folderPath) ?? Date.distantPast
                let date2 = getModificationDate(for: project2.folderPath) ?? Date.distantPast
                return date1 > date2
            }
        case .dateCreated:
            projects.sort { project1, project2 in
                let date1 = getCreationDate(for: project1.folderPath) ?? Date.distantPast
                let date2 = getCreationDate(for: project2.folderPath) ?? Date.distantPast
                return date1 > date2
            }
        }
    }
    
    private func getModificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
    
    private func getCreationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date
    }
    
    func createProject(name: String, overview: ProjectOverview) throws {
        guard let folder = preferencesManager.projectsFolder else {
            throw ProjectError.noProjectsFolderSet
        }
        
        let projectFolder = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)
        
        let overviewFile = projectFolder.appendingPathComponent("\(name).md")
        
        // Create content using the provided overview data
        let content = createMarkdownContent(projectName: name, overview: overview)
        try content.write(to: overviewFile, atomically: true, encoding: .utf8)
        
        scanProjects()
    }
    
    private func createMarkdownContent(projectName: String, overview: ProjectOverview) -> String {
        let date = Date().formatted(date: .abbreviated, time: .omitted)
        return """
        # \(projectName)
        
        ## Version History
        - v0.1 - \(date) - Initial project creation
        
        ## Core Concept
        \(overview.coreConcept)
        
        ## Guiding Principles & Intentions
        \(overview.guidingPrinciples)
        
        ## Key Features & Functionality
        \(overview.keyFeatures)
        
        ## Architecture & Structure
        \(overview.architecture)
        
        ## Implementation Roadmap
        \(overview.implementationRoadmap)
        
        ## Current Status & Progress
        \(overview.currentStatus)
        
        ## Next Steps
        \(overview.nextSteps)
        
        ## Challenges & Solutions
        \(overview.challenges)
        
        ## User/Audience Experience
        \(overview.userExperience)
        
        ## Success Metrics
        \(overview.successMetrics)
        
        ## Research & References
        \(overview.research)
        
        ## Open Questions & Considerations
        \(overview.openQuestions)
        
        ## Project Log
        ### \(date)
        Project created
        
        ## External Files
        \(overview.externalFiles)
        
        ## Repositories
        \(overview.repositories)
        """
    }
    
    func renameProject(_ project: Project, to newName: String) throws {
        let newFolderPath = project.folderPath.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: project.folderPath, to: newFolderPath)
        
        if project.hasOverview {
            let oldOverviewPath = project.overviewPath
            let newOverviewPath = newFolderPath.appendingPathComponent("\(newName).md")
            try FileManager.default.moveItem(at: oldOverviewPath, to: newOverviewPath)
        }
        
        scanProjects()
    }
    
    func deleteProject(_ project: Project) throws {
        try FileManager.default.removeItem(at: project.folderPath)
        scanProjects()
    }
}

enum ProjectError: LocalizedError {
    case noProjectsFolderSet
    case fileNotFound
    case invalidMarkdown
    
    var errorDescription: String? {
        switch self {
        case .noProjectsFolderSet:
            return "No projects folder has been set. Please select a folder in preferences."
        case .fileNotFound:
            return "The project overview file was not found."
        case .invalidMarkdown:
            return "The markdown file could not be parsed."
        }
    }
}