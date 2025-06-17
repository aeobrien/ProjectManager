import Foundation
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadData()
    }
    
    // MARK: - Project Management
    
    func syncWithProjects(_ allProjects: [Project]) {
        self.projects = allProjects
        
        // Add new projects to focus system as inactive
        for project in allProjects {
            if !focusedProjects.contains(where: { $0.projectId == project.id }) {
                let focusedProject = FocusedProject(projectId: project.id, status: .inactive)
                focusedProjects.append(focusedProject)
            }
        }
        
        // Remove projects that no longer exist
        focusedProjects.removeAll { focusedProject in
            !allProjects.contains { $0.id == focusedProject.projectId }
        }
        
        // Refresh tasks from active projects
        refreshTasksFromActiveProjects()
        
        // Check if any active projects need replacement
        checkForCompletedProjects()
        
        saveData()
    }
    
    func activateProject(_ project: FocusedProject) {
        guard let index = focusedProjects.firstIndex(where: { $0.id == project.id }) else { return }
        
        // Check if we're at the limit
        if activeProjects.count >= maxActiveProjects {
            print("Cannot activate: Already at maximum of \(maxActiveProjects) active projects")
            return
        }
        
        // Create a copy to trigger @Published
        var updatedProjects = focusedProjects
        updatedProjects[index].activate()
        focusedProjects = updatedProjects
        
        refreshTasksForProject(getProject(for: focusedProjects[index]))
        saveData()
    }
    
    func deactivateProject(_ project: FocusedProject) {
        guard let index = focusedProjects.firstIndex(where: { $0.id == project.id }) else { return }
        
        // Create a copy to trigger @Published
        var updatedProjects = focusedProjects
        updatedProjects[index].deactivate()
        focusedProjects = updatedProjects
        
        // Remove tasks for this project from the task list
        allTasks.removeAll { $0.projectId == project.projectId }
        
        saveData()
    }
    
    func markProjectAsWorkedOn(_ project: FocusedProject) {
        guard let index = focusedProjects.firstIndex(where: { $0.id == project.id }) else { return }
        focusedProjects[index].markAsWorkedOn()
        saveData()
    }
    
    // MARK: - Task Management
    
    func updateTaskStatus(_ task: FocusTask, newStatus: TaskStatus) {
        // Update in allTasks
        if let taskIndex = allTasks.firstIndex(where: { $0.id == task.id }) {
            allTasks[taskIndex].updateStatus(newStatus)
            
            // Mark the project as worked on
            if let project = focusedProjects.first(where: { $0.projectId == task.projectId }) {
                markProjectAsWorkedOn(project)
            }
            
            // Update the source project's next steps if task completed
            if newStatus == .completed {
                updateTaskInSourceProject(task, isCompleted: true)
            }
            
            saveData()
            
            // Check if this project now has no remaining tasks
            checkForCompletedProjects()
        }
    }
    
    func addTask(to project: FocusedProject, text: String) {
        guard let proj = getProject(for: project) else { return }
        
        let newTask = FocusTask(text: text, status: .todo, projectId: project.projectId)
        allTasks.append(newTask)
        
        // Also add to the project's next steps
        addTaskToProjectNextSteps(proj, taskText: text)
        
        markProjectAsWorkedOn(project)
        saveData()
    }
    
    private func refreshTasksFromActiveProjects() {
        // Store existing task statuses before refreshing
        let existingTaskStatuses = allTasks.reduce(into: [String: (TaskStatus, UUID)]()) { result, task in
            result[task.displayText] = (task.status, task.projectId)
        }
        
        allTasks.removeAll()
        
        for focusedProject in activeProjects {
            if let project = getProject(for: focusedProject) {
                var tasks = extractTasksFromProject(project)
                
                // Restore in-progress status for matching tasks
                for i in 0..<tasks.count {
                    if let existingData = existingTaskStatuses[tasks[i].displayText],
                       existingData.1 == tasks[i].projectId,
                       existingData.0 == .inProgress {
                        tasks[i].status = .inProgress
                    }
                }
                
                allTasks.append(contentsOf: tasks)
            }
        }
    }
    
    func refreshTasksForProject(_ project: Project?) {
        guard let project = project else { return }
        
        // Store existing tasks with their statuses before removing
        let existingTaskStatuses = allTasks.filter { $0.projectId == project.id }
            .reduce(into: [String: TaskStatus]()) { result, task in
                result[task.displayText] = task.status
            }
        
        // Remove existing tasks for this project
        allTasks.removeAll { $0.projectId == project.id }
        
        // Add updated tasks
        var tasks = extractTasksFromProject(project)
        
        // Restore in-progress status for matching tasks
        for i in 0..<tasks.count {
            if let existingStatus = existingTaskStatuses[tasks[i].displayText],
               existingStatus == .inProgress {
                tasks[i].status = .inProgress
            }
        }
        
        allTasks.append(contentsOf: tasks)
        
        saveData()
    }
    
    // MARK: - Computed Properties
    
    var activeProjects: [FocusedProject] {
        focusedProjects.filter { $0.status == .active }.sorted { 
            let name1 = getProject(for: $0)?.name ?? ""
            let name2 = getProject(for: $1)?.name ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    var inactiveProjects: [FocusedProject] {
        focusedProjects.filter { $0.status == .inactive }.sorted { 
            let name1 = getProject(for: $0)?.name ?? ""
            let name2 = getProject(for: $1)?.name ?? ""
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    var todoTasks: [FocusTask] {
        allTasks.filter { $0.status == .todo }.sorted { $0.createdDate < $1.createdDate }
    }
    
    var inProgressTasks: [FocusTask] {
        allTasks.filter { $0.status == .inProgress }.sorted { $0.lastModified > $1.lastModified }
    }
    
    var completedTasks: [FocusTask] {
        allTasks.filter { $0.status == .completed }.sorted { $0.lastModified > $1.lastModified }
    }
    
    var isOverActiveLimit: Bool {
        activeProjects.count > maxActiveProjects
    }
    
    var isUnderActiveMinimum: Bool {
        activeProjects.count < minActiveProjects
    }
    
    var staleActiveProjects: [FocusedProject] {
        activeProjects.filter { $0.isStale }
    }
    
    var projectsWithNoActiveTasks: [FocusedProject] {
        activeProjects.filter { project in
            !allTasks.contains { $0.projectId == project.projectId && $0.status != .completed }
        }
    }
    
    // MARK: - Project Replacement Logic
    
    private func checkForCompletedProjects() {
        let completedProjects = projectsWithNoActiveTasks
        
        if let firstCompleted = completedProjects.first {
            // Suggest replacement if there are inactive projects available
            if !inactiveProjects.isEmpty && projectNeedingReplacement == nil {
                projectNeedingReplacement = firstCompleted
                showingProjectSelector = true
            }
        }
    }
    
    func replaceProject(_ oldProject: FocusedProject, with newProject: FocusedProject) {
        deactivateProject(oldProject)
        activateProject(newProject)
        
        projectNeedingReplacement = nil
        showingProjectSelector = false
    }
    
    func keepProject(_ project: FocusedProject) {
        projectNeedingReplacement = nil
        showingProjectSelector = false
    }
    
    // MARK: - Private Methods
    
    private func extractTasksFromProject(_ project: Project) -> [FocusTask] {
        let viewModel = OverviewEditorViewModel(project: project)
        viewModel.loadOverview()
        
        let nextSteps = viewModel.projectOverview.nextSteps
        let lines = nextSteps.split(separator: "\n")
        
        var tasks: [FocusTask] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [") {
                let isCompleted = trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
                let text = String(trimmed)
                
                // Check if we already have this task in our allTasks array to preserve its status
                if let existingTask = allTasks.first(where: { 
                    $0.projectId == project.id && $0.displayText == text.replacingOccurrences(of: "- [ ] ", with: "").replacingOccurrences(of: "- [x] ", with: "").replacingOccurrences(of: "- [X] ", with: "")
                }) {
                    // Preserve the existing task's status if it's in progress
                    tasks.append(existingTask)
                } else {
                    // New task, set status based on checkbox
                    let status: TaskStatus = isCompleted ? .completed : .todo
                    let task = FocusTask(text: text, status: status, projectId: project.id)
                    tasks.append(task)
                }
            }
        }
        
        return tasks
    }
    
    private func updateTaskInSourceProject(_ task: FocusTask, isCompleted: Bool) {
        guard let project = projects.first(where: { $0.id == task.projectId }) else { return }
        
        let viewModel = OverviewEditorViewModel(project: project)
        viewModel.loadOverview()
        
        let lines = viewModel.projectOverview.nextSteps.split(separator: "\n", omittingEmptySubsequences: false)
        var updatedLines: [String] = []
        
        for line in lines {
            let lineStr = String(line)
            if lineStr.contains(task.displayText) {
                // Update this line
                if isCompleted {
                    let updatedLine = lineStr
                        .replacingOccurrences(of: "- [ ]", with: "- [x]")
                    updatedLines.append(updatedLine)
                } else {
                    let updatedLine = lineStr
                        .replacingOccurrences(of: "- [x]", with: "- [ ]")
                        .replacingOccurrences(of: "- [X]", with: "- [ ]")
                    updatedLines.append(updatedLine)
                }
            } else {
                updatedLines.append(lineStr)
            }
        }
        
        viewModel.projectOverview.nextSteps = updatedLines.joined(separator: "\n")
        viewModel.saveOverview()
    }
    
    private func addTaskToProjectNextSteps(_ project: Project, taskText: String) {
        let viewModel = OverviewEditorViewModel(project: project)
        viewModel.loadOverview()
        
        let newTaskLine = "- [ ] \(taskText)"
        
        if viewModel.projectOverview.nextSteps.isEmpty {
            viewModel.projectOverview.nextSteps = newTaskLine
        } else {
            viewModel.projectOverview.nextSteps = newTaskLine + "\n" + viewModel.projectOverview.nextSteps
        }
        
        viewModel.saveOverview()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        do {
            let projectsData = try JSONEncoder().encode(focusedProjects)
            UserDefaults.standard.set(projectsData, forKey: "focusedProjects")
            
            let tasksData = try JSONEncoder().encode(allTasks)
            UserDefaults.standard.set(tasksData, forKey: "focusTasks")
        } catch {
            print("Failed to save focus data: \(error)")
        }
    }
    
    private func loadData() {
        // Load projects
        if let projectsData = UserDefaults.standard.data(forKey: "focusedProjects") {
            do {
                focusedProjects = try JSONDecoder().decode([FocusedProject].self, from: projectsData)
            } catch {
                print("Failed to load focused projects: \(error)")
                focusedProjects = []
            }
        }
        
        // Load tasks
        if let tasksData = UserDefaults.standard.data(forKey: "focusTasks") {
            do {
                allTasks = try JSONDecoder().decode([FocusTask].self, from: tasksData)
            } catch {
                print("Failed to load focus tasks: \(error)")
                allTasks = []
            }
        }
    }
    
    // MARK: - Utility
    
    func getProject(for focusedProject: FocusedProject) -> Project? {
        return projects.first { $0.id == focusedProject.projectId }
    }
    
    func getProjectName(for task: FocusTask) -> String {
        return projects.first { $0.id == task.projectId }?.name ?? "Unknown Project"
    }
    
    func getFocusedProject(for task: FocusTask) -> FocusedProject? {
        return focusedProjects.first { $0.projectId == task.projectId }
    }
    
    func getProjectColor(for projectId: UUID) -> String {
        // Find the index of this project in the active projects list
        guard let index = activeProjects.firstIndex(where: { $0.projectId == projectId }) else {
            return "gray"
        }
        
        // Color palette for up to 5 projects
        let colors = ["blue", "green", "orange", "purple", "pink"]
        return colors[index % colors.count]
    }
}
