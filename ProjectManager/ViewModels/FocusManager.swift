import Foundation
import Combine
import ProjectManagerCore

class FocusManager: ObservableObject {
    @Published var focusedProjects: [FocusedProject] = []
    @Published var allTasks: [FocusTask] = []
    @Published var projects: [Project] = []
    @Published var showingProjectSelector = false
    @Published var projectNeedingReplacement: FocusedProject?
    @Published var showAddTaskDialog = false
    @Published var projectSlots: [ProjectManagerCore.ProjectSlot] = []
    
    private let maxActiveProjects = 5
    private let minActiveProjects = 3
    
    var maxActive: Int { maxActiveProjects }
    var minActive: Int { minActiveProjects }
    var cancellables = Set<AnyCancellable>()
    
    @Published var syncStatus: String = ""
    @Published var isSyncing: Bool = false
    private var syncInProgress = false
    
    init() {
        print("=== FocusManager init() ===")
        loadData()
        initializeSlots()
        
        // Store the initial active project IDs before any sync
        let initialActiveProjectIds = Set(focusedProjects.filter { $0.status == .active }.map { $0.projectId })
        if !initialActiveProjectIds.isEmpty {
            print("Found \(initialActiveProjectIds.count) initially active projects")
        }
        
        // TEMPORARILY DISABLED AUTO SYNC
        // setupCloudKitSync()
        
        // Ensure data is saved to shared storage on init
        // This handles the case where we have UserDefaults data but not shared storage data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Restore active status if it was lost during init
            if !initialActiveProjectIds.isEmpty {
                var restored = false
                for i in 0..<self.focusedProjects.count {
                    if initialActiveProjectIds.contains(self.focusedProjects[i].projectId) && 
                       self.focusedProjects[i].status == .inactive {
                        self.focusedProjects[i].status = .active
                        restored = true
                        print("Restored active status for project \(self.focusedProjects[i].projectId)")
                    }
                }
                if restored {
                    print("Active projects were restored")
                }
            }
            
            self.saveData()
        }
    }
    
    // MARK: - Slot Management
    
    private func initializeSlots() {
        // If slots already exist, keep them
        if !projectSlots.isEmpty {
            return
        }
        
        // Initialize with 5 empty slots
        for _ in 0..<maxActiveProjects {
            projectSlots.append(ProjectManagerCore.ProjectSlot())
        }
        
        // Migrate existing active projects to slots
        let activeProjects = focusedProjects.filter { $0.status == .active }
        for (index, project) in activeProjects.prefix(maxActiveProjects).enumerated() {
            projectSlots[index].occupiedBy = project.projectId
        }
    }
    
    func getAvailableSlots(for projectTags: Set<String>) -> [ProjectManagerCore.ProjectSlot] {
        let available = projectSlots.filter { slot in
            slot.isEmpty && slot.canAcceptProject(withTags: projectTags)
        }
        print("Checking slots for tags \(projectTags): found \(available.count) available")
        for slot in projectSlots {
            print("Slot \(slot.id): isEmpty=\(slot.isEmpty), requiredTags=\(slot.requiredTags), canAccept=\(slot.canAcceptProject(withTags: projectTags))")
        }
        return available
    }
    
    func updateSlotRequirements(_ slotId: UUID, requiredTags: Set<String>) {
        if let index = projectSlots.firstIndex(where: { $0.id == slotId }) {
            projectSlots[index].requiredTags = requiredTags
            saveData()
        }
    }
    
    // MARK: - Project Management
    
    func syncWithProjects(_ allProjects: [Project]) {
        print("=== FocusManager syncWithProjects() ===")
        print("Syncing with \(allProjects.count) projects")
        print("Current focused projects: \(focusedProjects.count)")
        print("  - Active: \(focusedProjects.filter { $0.status == .active }.count)")
        print("  - Inactive: \(focusedProjects.filter { $0.status == .inactive }.count)")
        
        self.projects = allProjects
        
        // Add new projects to focus system as inactive
        for project in allProjects {
            if !focusedProjects.contains(where: { $0.projectId == project.id }) {
                let focusedProject = FocusedProject(projectId: project.id, status: .inactive)
                focusedProjects.append(focusedProject)
                print("Added new project as inactive: \(project.name)")
            }
        }
        
        // Remove projects that no longer exist
        let removedCount = focusedProjects.filter { focusedProject in
            !allProjects.contains { $0.id == focusedProject.projectId }
        }.count
        
        focusedProjects.removeAll { focusedProject in
            !allProjects.contains { $0.id == focusedProject.projectId }
        }
        
        if removedCount > 0 {
            print("Removed \(removedCount) projects that no longer exist")
        }
        
        print("After sync:")
        print("  - Total focused projects: \(focusedProjects.count)")
        print("  - Active: \(focusedProjects.filter { $0.status == .active }.count)")
        print("  - Inactive: \(focusedProjects.filter { $0.status == .inactive }.count)")
        
        // Refresh tasks from active projects
        refreshTasksFromActiveProjects()
        
        // Check if any active projects need replacement
        checkForCompletedProjects()
        
        saveData()
    }
    
    func activateProject(_ project: FocusedProject, inSlot slotId: UUID? = nil) {
        guard let index = focusedProjects.firstIndex(where: { $0.id == project.id }) else { return }
        
        // Get project tags
        var projectTags = Set<String>()
        if let proj = getProject(for: project) {
            let viewModel = OverviewEditorViewModel(project: proj)
            viewModel.loadOverview()
            projectTags = Set(TagManager().extractTags(from: viewModel.projectOverview.tags))
        }
        
        // Find available slot
        var targetSlot: ProjectManagerCore.ProjectSlot?
        if let slotId = slotId {
            // Use specific slot if provided
            targetSlot = projectSlots.first { $0.id == slotId && $0.isEmpty }
        } else {
            // Find any available slot that can accept this project
            targetSlot = getAvailableSlots(for: projectTags).first
        }
        
        guard let slot = targetSlot else {
            print("Cannot activate: No available slots for this project")
            return
        }
        
        // Update slot
        if let slotIndex = projectSlots.firstIndex(where: { $0.id == slot.id }) {
            projectSlots[slotIndex].occupiedBy = project.projectId
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
        
        // Clear the slot
        if let slotIndex = projectSlots.firstIndex(where: { $0.occupiedBy == project.projectId }) {
            projectSlots[slotIndex].occupiedBy = nil
        }
        
        // Create a copy to trigger @Published
        var updatedProjects = focusedProjects
        updatedProjects[index].deactivate()
        focusedProjects = updatedProjects
        
        // Remove tasks for this project from the task list
        allTasks.removeAll { $0.projectId == project.projectId }
        
        // Clean up the filter if this project was filtered
        cleanupFilterForRemovedProject(project.projectId)
        
        saveData()
    }
    
    private func cleanupFilterForRemovedProject(_ projectId: UUID) {
        // Load current filter
        if let data = UserDefaults.standard.data(forKey: "focusBoardFilteredProjects"),
           var filteredProjects = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            // Remove the project from filter if it exists
            if filteredProjects.contains(projectId) {
                filteredProjects.remove(projectId)
                // Save updated filter
                if let updatedData = try? JSONEncoder().encode(filteredProjects) {
                    UserDefaults.standard.set(updatedData, forKey: "focusBoardFilteredProjects")
                }
            }
        }
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
            let oldStatus = allTasks[taskIndex].status
            allTasks[taskIndex].updateStatus(newStatus)
            
            // Mark the project as worked on
            if let project = focusedProjects.first(where: { $0.projectId == task.projectId }) {
                markProjectAsWorkedOn(project)
            }
            
            // Update the source project's next steps based on status change
            if newStatus == .completed && oldStatus != .completed {
                updateTaskInSourceProject(allTasks[taskIndex], isCompleted: true)
            } else if newStatus != .completed && oldStatus == .completed {
                updateTaskInSourceProject(allTasks[taskIndex], isCompleted: false)
            }
            
            saveData()
            
            // Check if this project now has no remaining tasks
            checkForCompletedProjects()
        } else {
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
    
    func updateTaskText(_ task: FocusTask, newText: String) {
        // Update in allTasks
        if let taskIndex = allTasks.firstIndex(where: { $0.id == task.id }) {
            let oldText = allTasks[taskIndex].displayText
            let existingTask = allTasks[taskIndex]
            
            // Create a new task with the updated text
            let updatedTask = FocusTask(
                text: newText,
                status: existingTask.status,
                projectId: existingTask.projectId,
                dueDate: existingTask.dueDate
            )
            
            // Replace the old task with the new one
            allTasks[taskIndex] = updatedTask
            
            // Update in the source project's markdown file
            if let project = getProject(for: FocusedProject(projectId: task.projectId, status: .active)) {
                updateTaskTextInProject(project, oldText: oldText, newText: newText)
            }
            
            // Mark the project as worked on
            if let focusedProject = focusedProjects.first(where: { $0.projectId == task.projectId }) {
                markProjectAsWorkedOn(focusedProject)
            }
            
            saveData()
        }
    }
    
    func refreshTasksFromActiveProjects() {
        // Store existing task statuses before refreshing
        let existingTaskStatuses = allTasks.reduce(into: [String: (TaskStatus, UUID)]()) { result, task in
            result[task.displayText] = (task.status, task.projectId)
        }
        
        var newTasks: [FocusTask] = []
        
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
                
                newTasks.append(contentsOf: tasks)
            }
        }
        
        // Update allTasks in one operation to ensure proper change notification
        allTasks = newTasks
    }
    
    func refreshTasksForProject(_ project: Project?) {
        guard let project = project else { return }
        
        // Store existing tasks with their statuses before removing
        let existingTaskStatuses = allTasks.filter { $0.projectId == project.id }
            .reduce(into: [String: TaskStatus]()) { result, task in
                result[task.displayText] = task.status
            }
        
        // Get all tasks except for this project
        var updatedTasks = allTasks.filter { $0.projectId != project.id }
        
        // Add updated tasks for this project
        var tasks = extractTasksFromProject(project)
        
        // Restore in-progress status for matching tasks
        for i in 0..<tasks.count {
            if let existingStatus = existingTaskStatuses[tasks[i].displayText],
               existingStatus == .inProgress {
                tasks[i].status = .inProgress
            }
        }
        
        updatedTasks.append(contentsOf: tasks)
        
        // Update allTasks in one operation to ensure proper change notification
        allTasks = updatedTasks
        
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
    
    func removeProjectWithoutReplacement(_ project: FocusedProject) {
        deactivateProject(project)
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [") {
                let isCompleted = trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
                var text = String(trimmed)
                var completedDate: Date? = nil
                
                // Extract completion date if present
                if isCompleted, let dateMatch = text.range(of: #" \((\d{4}-\d{2}-\d{2})\)"#, options: .regularExpression) {
                    let dateStr = String(text[dateMatch]).trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
                    completedDate = dateFormatter.date(from: dateStr)
                    // Remove date from text for display
                    text.removeSubrange(dateMatch)
                }
                
                // Check if we already have this task in our allTasks array to preserve its status
                let cleanDisplayText = text.replacingOccurrences(of: "- [ ] ", with: "")
                    .replacingOccurrences(of: "- [x] ", with: "")
                    .replacingOccurrences(of: "- [X] ", with: "")
                
                if let existingTask = allTasks.first(where: { 
                    $0.projectId == project.id && $0.displayText == cleanDisplayText
                }) {
                    // Preserve the existing task's status if it's in progress
                    var updatedTask = existingTask
                    if isCompleted && existingTask.status != .completed {
                        updatedTask.status = .completed
                        updatedTask.completedDate = completedDate
                    }
                    tasks.append(updatedTask)
                } else {
                    // New task, set status based on checkbox
                    let status: TaskStatus = isCompleted ? .completed : .todo
                    let task = FocusTask(text: text, status: status, projectId: project.id, completedDate: completedDate)
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
            // Check if this line contains the task (without date suffix)
            let taskTextToFind = task.displayText
            // Extract the text content from the line for comparison
            let lineTextContent = lineStr
                .replacingOccurrences(of: "- [ ] ", with: "")
                .replacingOccurrences(of: "- [x] ", with: "")
                .replacingOccurrences(of: "- [X] ", with: "")
                .replacingOccurrences(of: #" \(\d{4}-\d{2}-\d{2}\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            if lineTextContent == taskTextToFind && (lineStr.contains("- [ ]") || lineStr.contains("- [x]") || lineStr.contains("- [X]")) {
                // Update this line
                if isCompleted {
                    // Remove any existing date before adding new one
                    var cleanLine = lineStr
                    if let dateRange = cleanLine.range(of: #" \(\d{4}-\d{2}-\d{2}\)"#, options: .regularExpression) {
                        cleanLine.removeSubrange(dateRange)
                    }
                    
                    // Add completion date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let dateString = dateFormatter.string(from: Date())
                    
                    let updatedLine = cleanLine
                        .replacingOccurrences(of: "- [ ]", with: "- [x]")
                    updatedLines.append("\(updatedLine) (\(dateString))")
                } else {
                    // Remove completion date when unchecking
                    var updatedLine = lineStr
                    if let dateRange = updatedLine.range(of: #" \(\d{4}-\d{2}-\d{2}\)"#, options: .regularExpression) {
                        updatedLine.removeSubrange(dateRange)
                    }
                    updatedLine = updatedLine
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
    
    private func updateTaskTextInProject(_ project: Project, oldText: String, newText: String) {
        let viewModel = OverviewEditorViewModel(project: project)
        viewModel.loadOverview()
        
        let lines = viewModel.projectOverview.nextSteps.split(separator: "\n", omittingEmptySubsequences: false)
        var updatedLines: [String] = []
        
        for line in lines {
            let lineStr = String(line)
            if lineStr.contains(oldText) {
                // Replace the old text with new text while preserving checkbox state
                let updatedLine = lineStr.replacingOccurrences(of: oldText, with: newText)
                updatedLines.append(updatedLine)
            } else {
                updatedLines.append(lineStr)
            }
        }
        
        viewModel.projectOverview.nextSteps = updatedLines.joined(separator: "\n")
        viewModel.saveOverview()
    }
    
    // MARK: - CloudKit Sync
    
    private func setupCloudKitSync() {
        if #available(macOS 10.15, *) {
            // Observe sync status
            SimpleSyncManager.shared.$syncStatusText
                .sink { [weak self] status in
                    self?.syncStatus = status
                }
                .store(in: &cancellables)
            
            SimpleSyncManager.shared.$isSyncing
                .sink { [weak self] syncing in
                    self?.isSyncing = syncing
                }
                .store(in: &cancellables)
            
            // Initial sync from CloudKit
            Task {
                await syncFromCloudKit()
            }
            
            // Force save current data to shared storage for syncing
            saveData()
        }
    }
    
    private func syncFromCloudKit() async {
        guard #available(macOS 10.15, *) else { return }
        
        print("=== FocusManager syncFromCloudKit() ===")
        
        do {
            // Simulate fetch from cloud
            try await SimpleSyncManager.shared.syncNow()
            
            // Load updated data from shared storage
            await MainActor.run {
                let sharedProjects = SimpleStorageManager.shared.load([Project].self, forKey: "shared_projects") ?? []
                let sharedFocusedProjects = SimpleStorageManager.shared.load([FocusedProject].self, forKey: "shared_focusedProjects") ?? []
                let sharedTasks = SimpleStorageManager.shared.load([FocusTask].self, forKey: "shared_focusTasks") ?? []
                
                print("Loaded from CloudKit sync:")
                print("  - Projects: \(sharedProjects.count)")
                print("  - Focused Projects: \(sharedFocusedProjects.count)")
                if !sharedFocusedProjects.isEmpty {
                    print("    - Active: \(sharedFocusedProjects.filter { $0.status == .active }.count)")
                    print("    - Inactive: \(sharedFocusedProjects.filter { $0.status == .inactive }.count)")
                }
                print("  - Tasks: \(sharedTasks.count)")
                
                if !sharedProjects.isEmpty {
                    self.projects = sharedProjects
                }
                if !sharedFocusedProjects.isEmpty {
                    // Before replacing, check if we're about to lose active projects
                    let currentActiveIds = Set(self.focusedProjects.filter { $0.status == .active }.map { $0.projectId })
                    let cloudActiveIds = Set(sharedFocusedProjects.filter { $0.status == .active }.map { $0.projectId })
                    
                    if !currentActiveIds.isEmpty && cloudActiveIds.isEmpty {
                        print("WARNING: CloudKit has no active projects but local has \(currentActiveIds.count)")
                        print("Preserving local active status")
                        
                        // Merge: use cloud data but preserve local active status
                        var mergedProjects = sharedFocusedProjects
                        for i in 0..<mergedProjects.count {
                            if currentActiveIds.contains(mergedProjects[i].projectId) {
                                mergedProjects[i].status = .active
                                if let currentProject = self.focusedProjects.first(where: { $0.projectId == mergedProjects[i].projectId }) {
                                    mergedProjects[i].lastWorkedOn = currentProject.lastWorkedOn
                                    mergedProjects[i].activatedDate = currentProject.activatedDate
                                }
                            }
                        }
                        self.focusedProjects = mergedProjects
                        
                        // Force save the corrected data back
                        DispatchQueue.main.async { [weak self] in
                            self?.saveData()
                        }
                    } else {
                        print("Replacing local focused projects with CloudKit data")
                        self.focusedProjects = sharedFocusedProjects
                    }
                }
                if !sharedTasks.isEmpty {
                    self.allTasks = sharedTasks
                }
            }
        } catch {
            print("Failed to sync from cloud: \(error)")
        }
    }
    
    private func syncToCloudKit() async {
        guard #available(macOS 10.15, *) else { return }
        guard !syncInProgress else { return }
        
        syncInProgress = true
        defer { syncInProgress = false }
        
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
    
    // MARK: - Force Sync
    
    func forceSync() async {
        guard #available(macOS 10.15, *) else { return }
        
        print("=== FocusManager forceSync() ===")
        Task {
            await MainActor.run {
                isSyncing = true
            }
            
            do {
                // First save current data
                saveData()
                
                // Then do a regular sync to ensure everything is up to date
                try await SimpleSyncManager.shared.syncNow()
                
                print("Force sync completed successfully")
            } catch {
                print("Force sync failed: \(error)")
            }
            
            await MainActor.run {
                isSyncing = false
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        print("=== FocusManager saveData() ===")
        print("Saving focused projects: \(focusedProjects.count)")
        print("  - Active: \(focusedProjects.filter { $0.status == .active }.count)")
        print("  - Inactive: \(focusedProjects.filter { $0.status == .inactive }.count)")
        
        // List active projects by name
        let activeProjects = focusedProjects.filter { $0.status == .active }
        if !activeProjects.isEmpty {
            print("Active projects being saved:")
            for fp in activeProjects {
                if let project = projects.first(where: { $0.id == fp.projectId }) {
                    print("  - \(project.name)")
                }
            }
        }
        
        // Save to local UserDefaults
        do {
            let projectsData = try JSONEncoder().encode(focusedProjects)
            UserDefaults.standard.set(projectsData, forKey: "focusedProjects")
            
            let tasksData = try JSONEncoder().encode(allTasks)
            UserDefaults.standard.set(tasksData, forKey: "focusTasks")
            
            let slotsData = try JSONEncoder().encode(projectSlots)
            UserDefaults.standard.set(slotsData, forKey: "projectSlots")
        } catch {
            print("Failed to save focus data: \(error)")
        }
        
        // Save to shared storage
        print("Saving to shared storage:")
        print("  - Projects: \(projects.count)")
        print("  - Focused Projects: \(focusedProjects.count)")
        print("  - Tasks: \(allTasks.count)")
        
        SimpleStorageManager.shared.save(projects, forKey: "shared_projects")
        SimpleStorageManager.shared.save(focusedProjects, forKey: "shared_focusedProjects")
        SimpleStorageManager.shared.save(allTasks, forKey: "shared_focusTasks")
        
        // Sync to CloudKit only if not already syncing
        if !syncInProgress {
            Task {
                await syncToCloudKit()
            }
        }
    }
    
    private func loadData() {
        // First try to load from shared storage
        let sharedProjects = SimpleStorageManager.shared.load([Project].self, forKey: "shared_projects") ?? []
        let sharedFocusedProjects = SimpleStorageManager.shared.load([FocusedProject].self, forKey: "shared_focusedProjects") ?? []
        let sharedTasks = SimpleStorageManager.shared.load([FocusTask].self, forKey: "shared_focusTasks") ?? []
        
        print("=== FocusManager loadData() ===")
        print("Loaded from shared storage:")
        print("  - Projects: \(sharedProjects.count)")
        print("  - Focused Projects: \(sharedFocusedProjects.count)")
        if !sharedFocusedProjects.isEmpty {
            for fp in sharedFocusedProjects {
                if let project = sharedProjects.first(where: { $0.id == fp.projectId }) {
                    print("    - \(project.name): \(fp.status.rawValue)")
                }
            }
        }
        print("  - Tasks: \(sharedTasks.count)")
        
        if !sharedProjects.isEmpty {
            projects = sharedProjects
        }
        
        // Check shared storage first, then fall back to UserDefaults
        if !sharedFocusedProjects.isEmpty {
            focusedProjects = sharedFocusedProjects
            print("Using \(focusedProjects.count) focused projects from shared storage")
            print("  - Active: \(focusedProjects.filter { $0.status == .active }.count)")
            print("  - Inactive: \(focusedProjects.filter { $0.status == .inactive }.count)")
        } else if let projectsData = UserDefaults.standard.data(forKey: "focusedProjects") {
            do {
                focusedProjects = try JSONDecoder().decode([FocusedProject].self, from: projectsData)
                print("Loaded \(focusedProjects.count) focused projects from UserDefaults")
                print("  - Active: \(focusedProjects.filter { $0.status == .active }.count)")
                print("  - Inactive: \(focusedProjects.filter { $0.status == .inactive }.count)")
                // Save to shared storage for syncing
                SimpleStorageManager.shared.save(focusedProjects, forKey: "shared_focusedProjects")
                print("Migrated focused projects to shared storage")
            } catch {
                print("Failed to load focused projects: \(error)")
                focusedProjects = []
            }
        } else {
            print("No focused projects found in storage")
        }
        
        if !sharedTasks.isEmpty {
            allTasks = sharedTasks
        } else if let tasksData = UserDefaults.standard.data(forKey: "focusTasks") {
            do {
                allTasks = try JSONDecoder().decode([FocusTask].self, from: tasksData)
                // Save to shared storage for syncing
                SimpleStorageManager.shared.save(allTasks, forKey: "shared_focusTasks")
            } catch {
                print("Failed to load focus tasks: \(error)")
                allTasks = []
            }
        }
        
        // Load project slots
        if let slotsData = UserDefaults.standard.data(forKey: "projectSlots") {
            do {
                projectSlots = try JSONDecoder().decode([ProjectManagerCore.ProjectSlot].self, from: slotsData)
                print("Loaded \(projectSlots.count) project slots")
            } catch {
                print("Failed to load project slots: \(error)")
                projectSlots = []
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
        // Check if this project is in a slot
        guard let slotIndex = projectSlots.firstIndex(where: { $0.occupiedBy == projectId }) else {
            return "gray"
        }
        
        // Color palette for projects - one color per slot
        let colors = ["blue", "green", "orange", "purple", "pink"]
        
        // Use the slot index for stable color assignment
        // This ensures the same slot always gets the same color
        let colorIndex = slotIndex % colors.count
        
        return colors[colorIndex]
    }
    
    func getIncompleteTaskCount(for projectId: UUID) -> Int {
        // First check if we have tasks loaded for active projects
        if activeProjects.contains(where: { $0.projectId == projectId }) {
            return allTasks.filter { 
                $0.projectId == projectId && $0.status != .completed 
            }.count
        }
        
        // For inactive projects, load from the project overview file
        guard let project = projects.first(where: { $0.id == projectId }) else { return 0 }
        
        let viewModel = OverviewEditorViewModel(project: project)
        viewModel.loadOverview()
        
        let nextSteps = viewModel.projectOverview.nextSteps
        let lines = nextSteps.split(separator: "\n")
        
        var incompleteCount = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") {
                incompleteCount += 1
            }
        }
        
        return incompleteCount
    }
}
