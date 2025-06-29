import Foundation
import Combine
import SwiftUI
import ProjectManagerCore

@MainActor
class FocusManager: ObservableObject {
    @Published var focusedProjects: [FocusedProject] = []
    @Published var allTasks: [FocusTask] = []
    @Published var projects: [Project] = []
    @Published var showingProjectSelector = false
    @Published var projectNeedingReplacement: FocusedProject?
    
    private let maxActiveProjects = 5
    private let minActiveProjects = 3
    
    var maxActive: Int { maxActiveProjects }
    var minActive: Int { minActiveProjects }
    
    @Published var syncStatus: String = ""
    @Published var isSyncing: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadData()
        setupCloudKitSync()
        
        // Sync with available projects after loading
        syncWithLoadedProjects()
    }
    
    // MARK: - Computed Properties
    
    var activeProjects: [FocusedProject] {
        focusedProjects.filter { $0.status == .active }
            .sorted { 
                let name1 = getProject(for: $0)?.name ?? ""
                let name2 = getProject(for: $1)?.name ?? ""
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
    }
    
    var inactiveProjects: [FocusedProject] {
        focusedProjects.filter { $0.status == .inactive }
            .sorted { 
                let name1 = getProject(for: $0)?.name ?? ""
                let name2 = getProject(for: $1)?.name ?? ""
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
    }
    
    var todoTasks: [FocusTask] {
        allTasks.filter { $0.status == .todo }
            .sorted { $0.createdDate < $1.createdDate }
    }
    
    var inProgressTasks: [FocusTask] {
        allTasks.filter { $0.status == .inProgress }
            .sorted { $0.lastModified > $1.lastModified }
    }
    
    var completedTasks: [FocusTask] {
        allTasks.filter { $0.status == .completed }
            .sorted { $0.lastModified > $1.lastModified }
    }
    
    // MARK: - Task Management
    
    func updateTaskStatus(_ task: FocusTask, newStatus: TaskStatus) {
        if let taskIndex = allTasks.firstIndex(where: { $0.id == task.id }) {
            allTasks[taskIndex].updateStatus(newStatus)
            saveData()
            
            // Sync with CloudKit
            Task {
                await syncTaskUpdate(allTasks[taskIndex])
            }
        }
    }
    
    func addTask(to project: FocusedProject, text: String) {
        let newTask = FocusTask(
            text: text,
            status: .todo,
            projectId: project.projectId
        )
        allTasks.append(newTask)
        saveData()
        
        // Sync with CloudKit
        Task {
            await syncTaskUpdate(newTask)
        }
    }
    
    func updateTaskText(_ task: FocusTask, newText: String) {
        if let taskIndex = allTasks.firstIndex(where: { $0.id == task.id }) {
            let existingTask = allTasks[taskIndex]
            
            // Create updated task
            let updatedTask = FocusTask(
                text: newText,
                status: existingTask.status,
                projectId: existingTask.projectId,
                dueDate: existingTask.dueDate
            )
            
            allTasks[taskIndex] = updatedTask
            saveData()
            
            // Sync with CloudKit
            Task {
                await syncTaskUpdate(updatedTask)
            }
        }
    }
    
    // MARK: - Project Management
    
    func syncWithProjects(_ allProjects: [Project]) {
        self.projects = allProjects
        
        // iOS should NOT create focused projects - only sync what exists from macOS
        // Just remove any focused projects that no longer have matching projects
        focusedProjects.removeAll { focusedProject in
            !allProjects.contains { $0.id == focusedProject.projectId }
        }
        
        // Don't save here - we're just cleaning up orphaned entries
        // The actual focused projects data should come from CloudKit sync
    }
    
    private func syncWithLoadedProjects() {
        // After loading data, ensure we have the correct focused projects
        syncWithProjects(projects)
    }
    
    private func refreshTasksFromActiveProjects() {
        // For iOS, we don't extract tasks from project files
        // Tasks are managed separately in the focus board
        // This is a no-op but kept for compatibility
    }
    
    func activateProject(_ project: FocusedProject) {
        guard activeProjects.count < maxActiveProjects else { return }
        
        if let index = focusedProjects.firstIndex(where: { $0.id == project.id }) {
            focusedProjects[index].activate()
            saveData()
        }
    }
    
    func deactivateProject(_ project: FocusedProject) {
        if let index = focusedProjects.firstIndex(where: { $0.id == project.id }) {
            focusedProjects[index].deactivate()
            
            // Remove tasks for this project
            allTasks.removeAll { $0.projectId == project.projectId }
            saveData()
        }
    }
    
    // MARK: - Utilities
    
    func getProject(for focusedProject: FocusedProject) -> Project? {
        projects.first { $0.id == focusedProject.projectId }
    }
    
    func getProjectName(for task: FocusTask) -> String {
        projects.first { $0.id == task.projectId }?.name ?? "Unknown Project"
    }
    
    func getProjectColor(for projectId: UUID) -> String {
        // Check if this project is active
        guard activeProjects.contains(where: { $0.projectId == projectId }) else {
            return "gray"
        }
        
        // Color palette for projects
        let colors = ["blue", "green", "orange", "purple", "pink"]
        
        // Use a stable hash of the project ID to assign colors consistently
        let hashValue = projectId.hashValue
        let colorIndex = abs(hashValue) % colors.count
        
        return colors[colorIndex]
    }
    
    // MARK: - CloudKit Sync
    
    private func setupCloudKitSync() {
        if #available(iOS 13.0, *) {
            // Observe sync status
            SimpleSyncManager.shared.$syncStatusText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    self?.syncStatus = status
                }
                .store(in: &cancellables)
            
            SimpleSyncManager.shared.$isSyncing
                .receive(on: DispatchQueue.main)
                .sink { [weak self] syncing in
                    self?.isSyncing = syncing
                }
                .store(in: &cancellables)
            
            // Initial sync from CloudKit
            Task {
                await syncFromCloudKit()
            }
        }
    }
    
    func syncFromCloudKit() async {
        guard #available(iOS 13.0, *) else { return }
        
        print("=== iOS FocusManager syncFromCloudKit() ===")
        
        do {
            // Simulate fetch from cloud
            try await SimpleSyncManager.shared.syncNow()
            
            // Load updated data from shared storage
            let sharedProjects = SimpleStorageManager.shared.load([Project].self, forKey: "shared_projects") ?? []
            let sharedFocusedProjects = SimpleStorageManager.shared.load([FocusedProject].self, forKey: "shared_focusedProjects") ?? []
            let sharedTasks = SimpleStorageManager.shared.load([FocusTask].self, forKey: "shared_focusTasks") ?? []
            
            print("Loaded from shared storage after sync:")
            print("  - Projects: \(sharedProjects.count)")
            print("  - Focused Projects: \(sharedFocusedProjects.count)")
            
            // Update local data
            if !sharedProjects.isEmpty {
                self.projects = sharedProjects
            }
            if !sharedFocusedProjects.isEmpty {
                self.focusedProjects = sharedFocusedProjects
                print("Loaded \(sharedFocusedProjects.count) focused projects from sync")
                print("  - Active: \(sharedFocusedProjects.filter { $0.status == .active }.count)")
                print("  - Inactive: \(sharedFocusedProjects.filter { $0.status == .inactive }.count)")
                
                // Debug: List active projects
                let activeProjects = sharedFocusedProjects.filter { $0.status == .active }
                for fp in activeProjects {
                    if let project = sharedProjects.first(where: { $0.id == fp.projectId }) {
                        print("    Active project: \(project.name) (ID: \(fp.projectId))")
                    }
                }
            }
            if !sharedTasks.isEmpty {
                self.allTasks = sharedTasks
                print("Loaded \(sharedTasks.count) tasks from sync")
            }
            
            // After loading all data, clean up any orphaned focused projects
            syncWithProjects(self.projects)
            
        } catch {
            print("Failed to sync from cloud: \(error)")
        }
    }
    
    private func syncToCloudKit() async {
        guard #available(iOS 13.0, *) else { return }
        
        do {
            // Save data to shared storage first
            SimpleStorageManager.shared.save(projects, forKey: "shared_projects")
            SimpleStorageManager.shared.save(focusedProjects, forKey: "shared_focusedProjects")
            SimpleStorageManager.shared.save(allTasks, forKey: "shared_focusTasks")
            
            // Sync to cloud
            try await SimpleSyncManager.shared.syncNow()
        } catch {
            print("Failed to sync to cloud: \(error)")
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        // Save to UserDefaults for local cache
        if let projectsData = try? JSONEncoder().encode(focusedProjects) {
            UserDefaults.standard.set(projectsData, forKey: "ios_focusedProjects")
        }
        
        if let tasksData = try? JSONEncoder().encode(allTasks) {
            UserDefaults.standard.set(tasksData, forKey: "ios_focusTasks")
        }
        
        // Save to shared storage
        SimpleStorageManager.shared.save(projects, forKey: "shared_projects")
        SimpleStorageManager.shared.save(focusedProjects, forKey: "shared_focusedProjects")
        SimpleStorageManager.shared.save(allTasks, forKey: "shared_focusTasks")
        
        // Sync to CloudKit
        Task {
            await syncToCloudKit()
        }
    }
    
    private func loadData() {
        // First try to load from shared storage
        let sharedProjects = SimpleStorageManager.shared.load([Project].self, forKey: "shared_projects") ?? []
        let sharedFocusedProjects = SimpleStorageManager.shared.load([FocusedProject].self, forKey: "shared_focusedProjects") ?? []
        let sharedTasks = SimpleStorageManager.shared.load([FocusTask].self, forKey: "shared_focusTasks") ?? []
        
        print("Loading focus data from shared storage:")
        print("  - Projects: \(sharedProjects.count)")
        print("  - Focused Projects: \(sharedFocusedProjects.count)")
        print("  - Tasks: \(sharedTasks.count)")
        
        if !sharedProjects.isEmpty {
            projects = sharedProjects
        }
        if !sharedFocusedProjects.isEmpty {
            focusedProjects = sharedFocusedProjects
            print("  - Active: \(focusedProjects.filter { $0.status == .active }.count)")
            print("  - Inactive: \(focusedProjects.filter { $0.status == .inactive }.count)")
        }
        if !sharedTasks.isEmpty {
            allTasks = sharedTasks
        } else {
            // Fall back to local UserDefaults
            if let projectsData = UserDefaults.standard.data(forKey: "ios_focusedProjects"),
               let projects = try? JSONDecoder().decode([FocusedProject].self, from: projectsData) {
                focusedProjects = projects
            }
            
            if let tasksData = UserDefaults.standard.data(forKey: "ios_focusTasks"),
               let tasks = try? JSONDecoder().decode([FocusTask].self, from: tasksData) {
                allTasks = tasks
            }
        }
    }
    
    private func syncTaskUpdate(_ task: FocusTask) async {
        // Tasks are synced as part of the general sync process
        await syncToCloudKit()
    }
    
    private func syncProjectUpdate(_ project: FocusedProject) async {
        // Projects are synced as part of the general sync process
        await syncToCloudKit()
    }
}