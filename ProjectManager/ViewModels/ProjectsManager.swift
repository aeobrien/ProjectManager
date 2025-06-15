import Foundation
import Combine

class ProjectsManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    
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
        } catch {
            print("Error scanning projects: \(error)")
            print("Folder path: \(folder.path)")
            print("Can read: \(FileManager.default.isReadableFile(atPath: folder.path))")
            projects = []
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
        let content = ProjectOverview.createTemplate(projectName: name)
        try content.write(to: overviewFile, atomically: true, encoding: .utf8)
        
        scanProjects()
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