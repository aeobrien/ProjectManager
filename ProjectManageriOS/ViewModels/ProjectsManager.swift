import Foundation
import SwiftUI
import Combine
import ProjectManagerCore

@MainActor
class ProjectsManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedProject: Project?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var focusManager: FocusManager?
    
    private let fileSystem: FileSystemProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // For iOS, we'll use Dropbox API for the base path
    private var basePath: URL {
        // This will be configured from settings
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ObsidianVault")
    }
    
    init(fileSystem: FileSystemProtocol = LocalFileSystem()) {
        self.fileSystem = fileSystem
        Task {
            await loadProjects()
        }
        
        // Listen for sync completion to reload projects
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncCompleted),
            name: Notification.Name("CloudKitSyncCompleted"),
            object: nil
        )
    }
    
    @objc private func handleSyncCompleted() {
        Task {
            await loadProjects()
        }
    }
    
    func loadProjects() async {
        isLoading = true
        errorMessage = nil
        
        // Load projects from shared storage (synced from CloudKit)
        await MainActor.run {
            if let sharedProjects = SimpleStorageManager.shared.load([Project].self, forKey: "shared_projects") {
                self.projects = sharedProjects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                print("Loaded \(projects.count) projects from shared storage")
                
                // Sync with FocusManager if available
                if let focusManager = self.focusManager {
                    focusManager.syncWithProjects(self.projects)
                }
            } else {
                self.projects = []
                print("No projects found in shared storage")
            }
            self.isLoading = false
        }
    }
    
    func refreshProjects() async {
        await loadProjects()
    }
    
    func createProject(named name: String) async throws {
        let projectPath = basePath.appendingPathComponent(name)
        
        // Check if project already exists
        if fileSystem.fileExists(at: projectPath) {
            throw ProjectError.alreadyExists
        }
        
        // Create project directory
        try fileSystem.createDirectory(at: projectPath)
        
        // Create initial overview file
        let overviewPath = projectPath.appendingPathComponent("\(name).md")
        let initialContent = """
        # \(name)
        
        ## Description
        [Add project description here]
        
        ## Next Steps
        - [ ] Define project goals
        - [ ] Set up initial structure
        - [ ] Create first milestone
        """
        
        try fileSystem.writeFile(contents: initialContent, to: overviewPath)
        
        // Reload projects
        await loadProjects()
    }
    
    func deleteProject(_ project: Project) {
        Task {
            do {
                try fileSystem.removeItem(at: project.folderPath)
                await loadProjects()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete project: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func renameProject(_ project: Project, to newName: String) async throws {
        let newPath = project.folderPath.deletingLastPathComponent().appendingPathComponent(newName)
        
        // Check if new name already exists
        if fileSystem.fileExists(at: newPath) {
            throw ProjectError.alreadyExists
        }
        
        // Move the project folder
        try fileSystem.moveItem(from: project.folderPath, to: newPath)
        
        // Update overview file if it exists
        let oldOverviewPath = project.folderPath.appendingPathComponent("\(project.name).md")
        let newOverviewPath = newPath.appendingPathComponent("\(newName).md")
        
        if fileSystem.fileExists(at: oldOverviewPath) {
            try fileSystem.moveItem(from: oldOverviewPath, to: newOverviewPath)
        }
        
        await loadProjects()
    }
}

enum ProjectError: LocalizedError {
    case alreadyExists
    case invalidName
    case syncError(String)
    
    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            return "A project with this name already exists"
        case .invalidName:
            return "Invalid project name"
        case .syncError(let message):
            return "Sync error: \(message)"
        }
    }
}