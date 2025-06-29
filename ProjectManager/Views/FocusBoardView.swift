import SwiftUI
import ProjectManagerCore

struct FocusBoardView: View {
    @EnvironmentObject var projectsManager: ProjectsManager
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingNewTaskDialog = false
    @State private var showingProjectSelector = false
    @State private var selectedProjectForNewTask: FocusedProject?
    @State private var newTaskText = ""
    @State private var activeAddTaskSheet: AddTaskButton.ActiveSheet?
    @State private var selectedProjectsForFilter: Set<UUID> = {
        if let data = UserDefaults.standard.data(forKey: "focusBoardFilteredProjects"),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            return ids
        }
        return []
    }()
    @State private var selectedTagsForFilter: Set<String> = {
        if let data = UserDefaults.standard.data(forKey: "focusBoardFilteredTags"),
           let tags = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return tags
        }
        return []
    }()
    
    // Computed properties for filtered tasks
    private var isFilterActive: Bool {
        !selectedProjectsForFilter.isEmpty || !selectedTagsForFilter.isEmpty
    }
    
    private func taskMatchesFilters(_ task: FocusTask) -> Bool {
        // Check project filter
        if !selectedProjectsForFilter.isEmpty && !selectedProjectsForFilter.contains(task.projectId) {
            return false
        }
        
        // Check tag filter
        if !selectedTagsForFilter.isEmpty {
            // Get project tags
            guard let project = focusManager.getProject(for: FocusedProject(projectId: task.projectId, status: .active)) else {
                return false
            }
            let viewModel = OverviewEditorViewModel(project: project)
            viewModel.loadOverview()
            let projectTags = projectsManager.tagManager.extractTags(from: viewModel.projectOverview.tags)
            
            // Check if project has any of the selected tags (OR logic)
            let hasMatchingTag = selectedTagsForFilter.contains { tag in
                projectTags.contains(tag)
            }
            if !hasMatchingTag {
                return false
            }
        }
        
        return true
    }
    
    private var filteredTodoTasks: [FocusTask] {
        guard isFilterActive else { return focusManager.todoTasks }
        return focusManager.todoTasks.filter(taskMatchesFilters)
    }
    
    private var filteredInProgressTasks: [FocusTask] {
        guard isFilterActive else { return focusManager.inProgressTasks }
        return focusManager.inProgressTasks.filter(taskMatchesFilters)
    }
    
    private var filteredCompletedTasks: [FocusTask] {
        guard isFilterActive else { return focusManager.completedTasks }
        return focusManager.completedTasks.filter(taskMatchesFilters)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            FocusBoardHeaderView(focusManager: focusManager, showingProjectSelector: $showingProjectSelector)
            
            Divider()
            
            ProjectFilterView(focusManager: focusManager, selectedProjectsForFilter: $selectedProjectsForFilter)
            
            TagFilterView(tagManager: projectsManager.tagManager, focusManager: focusManager, selectedTagsForFilter: $selectedTagsForFilter)
            
            TaskBoardView(focusManager: focusManager, projectsManager: projectsManager, selectedProjectsForFilter: $selectedProjectsForFilter)
        }
        .frame(minWidth: 1200, minHeight: 600, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // Refresh when window becomes active
            focusManager.refreshTasksFromActiveProjects()
            // Clean up filter for removed projects
            cleanupFilterForInactiveProjects()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Also refresh when the app becomes active
            focusManager.syncWithProjects(projectsManager.projects)
        }
        .onChange(of: projectsManager.projects) { newProjects in
            focusManager.syncWithProjects(newProjects)
            // Clean up filter for removed projects
            cleanupFilterForInactiveProjects()
        }
        .onChange(of: focusManager.activeProjects) { _ in
            // Clean up filter when active projects change
            cleanupFilterForInactiveProjects()
        }
        .onChange(of: selectedProjectsForFilter) { newFilter in
            // Save filter to UserDefaults
            if let data = try? JSONEncoder().encode(newFilter) {
                UserDefaults.standard.set(data, forKey: "focusBoardFilteredProjects")
            }
        }
        .onChange(of: selectedTagsForFilter) { newFilter in
            // Save tag filter to UserDefaults
            if let data = try? JSONEncoder().encode(newFilter) {
                UserDefaults.standard.set(data, forKey: "focusBoardFilteredTags")
            }
        }
        .sheet(isPresented: $showingProjectSelector) {
            ProjectSelectorView(focusManager: focusManager)
                .environmentObject(projectsManager)
        }
        .sheet(isPresented: $focusManager.showingProjectSelector) {
            ProjectReplacementDialog(focusManager: focusManager)
        }
        .onChange(of: focusManager.showAddTaskDialog) { showDialog in
            if showDialog {
                // Determine which sheet to show based on active projects and filter
                if focusManager.activeProjects.count == 1 {
                    activeAddTaskSheet = .add(project: focusManager.activeProjects[0])
                } else if selectedProjectsForFilter.count == 1,
                          let projectId = selectedProjectsForFilter.first,
                          let project = focusManager.activeProjects.first(where: { $0.projectId == projectId }) {
                    // If filtered to one project, pre-select it
                    activeAddTaskSheet = .add(project: project)
                } else {
                    activeAddTaskSheet = .picker
                }
                focusManager.showAddTaskDialog = false
            }
        }
        .sheet(item: $activeAddTaskSheet) { sheet in
            switch sheet {
            case .picker:
                ProjectPickerDialog(
                    activeProjects: focusManager.activeProjects,
                    focusManager: focusManager,
                    onSelect: { project in
                        activeAddTaskSheet = .add(project: project)
                    },
                    onCancel: {
                        activeAddTaskSheet = nil
                    }
                )
                .environmentObject(projectsManager)
                
            case .add(let project):
                AddTaskDialog(
                    newTaskText: $newTaskText,
                    projectName: focusManager.getProject(for: project)?.name ?? "Unknown",
                    onSave: {
                        focusManager.addTask(to: project, text: newTaskText)
                        newTaskText = ""
                        activeAddTaskSheet = nil
                    },
                    onCancel: {
                        newTaskText = ""
                        activeAddTaskSheet = nil
                    }
                )
                .environmentObject(projectsManager)
            }
        }
    }
    
    private func cleanupFilterForInactiveProjects() {
        let activeProjectIds = Set(focusManager.activeProjects.map { $0.projectId })
        // Remove any filtered projects that are no longer active
        selectedProjectsForFilter = selectedProjectsForFilter.intersection(activeProjectIds)
    }
}

struct TaskColumnView: View {
    let title: String
    let subtitle: String
    let tasks: [FocusTask]
    let taskStatus: TaskStatus
    let focusManager: FocusManager
    let projectsManager: ProjectsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Column Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(tasks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Tasks List
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Group tasks by project
                    let groupedTasks = Dictionary(grouping: tasks) { $0.projectId }
                    let sortedProjectIds = groupedTasks.keys.sorted { id1, id2 in
                        // Sort by project name for consistent ordering
                        let name1 = focusManager.getProject(for: FocusedProject(projectId: id1, status: .active))?.name ?? ""
                        let name2 = focusManager.getProject(for: FocusedProject(projectId: id2, status: .active))?.name ?? ""
                        return name1.localizedStandardCompare(name2) == .orderedAscending
                    }
                    
                    ForEach(sortedProjectIds, id: \.self) { projectId in
                        ForEach(groupedTasks[projectId] ?? []) { task in
                            TaskCardView(
                                task: task,
                                focusManager: focusManager,
                                projectsManager: projectsManager
                            )
                        }
                    }
                    
                    // Add task button for To Do column
                    if taskStatus == .todo {
                        AddTaskButton(focusManager: focusManager)
                            .environmentObject(projectsManager)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}

struct TaskCardView: View {
    let task: FocusTask
    let focusManager: FocusManager
    let projectsManager: ProjectsManager
    
    @State private var showingProjectDetail = false
    @State private var showingEditDialog = false
    @State private var editedTaskText = ""
    
    var projectName: String {
        if let project = focusManager.projects.first(where: { $0.id == task.projectId }) {
            return project.name
        }
        // Fallback: try to get from projectsManager if focusManager not synced yet
        if let project = projectsManager.projects.first(where: { $0.id == task.projectId }) {
            return project.name
        }
        return "Unknown Project"
    }
    
    var project: Project? {
        focusManager.projects.first { $0.id == task.projectId } ??
        projectsManager.projects.first { $0.id == task.projectId }
    }
    
    var projectColor: Color {
        let colorName = focusManager.getProjectColor(for: task.projectId)
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Project name (small, at top)
            HStack {
                Text(projectName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(projectColor)
                    .cornerRadius(4)
                
                Spacer()
                
                // Status change menu
                Menu {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Button(status.rawValue) {
                            focusManager.updateTaskStatus(task, newStatus: status)
                        }
                        .disabled(status == task.status)
                    }
                    
                    Divider()
                    
                    Button("Edit Task") {
                        editedTaskText = task.displayText
                        showingEditDialog = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Task text (main content) with completion date if applicable
            HStack(alignment: .top, spacing: 4) {
                Text(task.displayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                if task.status == .completed, let completedDate = task.completedDate {
                    Text("(\(completedDate.formatted(date: .abbreviated, time: .omitted)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 0)
            }
            
            // Task metadata
            VStack(alignment: .leading, spacing: 4) {
                Text("Updated \(RelativeDateTimeFormatter().localizedString(for: task.lastModified, relativeTo: Date()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Action buttons
            HStack {
                Button("View Project") {
                    if let proj = project {
                        projectsManager.selectedProject = proj
                        showingProjectDetail = true
                    }
                }
                .font(.caption)
                
                Spacer()
                
                // Quick status change buttons
                if task.status == .todo {
                    Button("Start") {
                        focusManager.updateTaskStatus(task, newStatus: .inProgress)
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                } else if task.status == .inProgress {
                    Button("Complete") {
                        focusManager.updateTaskStatus(task, newStatus: .completed)
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                }
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(projectColor.opacity(0.3), lineWidth: 2)
        )
        .shadow(radius: 1)
        .sheet(isPresented: $showingProjectDetail) {
            if let proj = project {
                ProjectDetailView(project: proj)
                    .environmentObject(projectsManager)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .sheet(isPresented: $showingEditDialog) {
            EditTaskDialog(
                taskText: $editedTaskText,
                originalText: task.displayText,
                projectName: projectName,
                onSave: {
                    focusManager.updateTaskText(task, newText: editedTaskText)
                    showingEditDialog = false
                },
                onCancel: {
                    showingEditDialog = false
                }
            )
        }
    }
}

/// Button that lets the user add a task to the Focus Board.
/// Uses a single `.sheet(item:)` to avoid SwiftUI’s “only the last sheet wins” rule.
struct AddTaskButton: View {
    
    // MARK: – Sheet routing
    
    /// Identifies which sheet (if any) is showing.
    /// Conforming to `Identifiable` lets us drive `.sheet(item:)`.
    enum ActiveSheet: Identifiable, Equatable {
        case picker                     // choose a project first
        case add(project: FocusedProject) // enter task text for the chosen project
        
        var id: String {                // simple stable ID
            switch self {
            case .picker:          return "picker"
            case .add(let p):      return p.id.uuidString
            }
        }
    }
    
    // MARK: – Dependencies
    
    let focusManager: FocusManager          // injected from parent
    @EnvironmentObject var projectsManager: ProjectsManager // still available for downstream views if needed
    
    // MARK: – State
    
    @State private var activeSheet: ActiveSheet? = nil      // current sheet
    @State private var newTaskText = ""                     // text being typed
    
    // MARK: – View
    
    var body: some View {
        // The tappable button
        Button {
            // Decide which sheet to show
            switch focusManager.activeProjects.count {
            case 0:   break                                  // button is disabled in this case
            case 1:   activeSheet = .add(project: focusManager.activeProjects[0])
            default:  activeSheet = .picker
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundColor(focusManager.activeProjects.isEmpty ? .secondary : .accentColor)
                Text(focusManager.activeProjects.isEmpty ? "No Active Projects" : "Add Task")
                    .font(.subheadline)
                    .foregroundColor(focusManager.activeProjects.isEmpty ? .secondary : .accentColor)
                Spacer()
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
        .buttonStyle(.plain)
        .disabled(focusManager.activeProjects.isEmpty)
        .help(focusManager.activeProjects.isEmpty
              ? "No active projects. Click “Manage Projects” to activate projects."
              : "Add a new task")
        
        // MARK: – Single sheet presenter
        
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
                
            // 1️⃣ Project picker
            case .picker:
                ProjectPickerDialog(
                    activeProjects: focusManager.activeProjects,
                    focusManager: focusManager,
                    onSelect: { project in
                        activeSheet = .add(project: project)   // chain to next sheet
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
                .environmentObject(projectsManager)           // propagate env-object if your dialogs need it
                
            // 2️⃣ Add-task dialog
            case .add(let project):
                AddTaskDialog(
                    newTaskText: $newTaskText,
                    projectName: focusManager.getProject(for: project)?.name ?? "Unknown",
                    onSave: {
                        focusManager.addTask(to: project, text: newTaskText)
                        newTaskText = ""
                        activeSheet = nil
                    },
                    onCancel: {
                        newTaskText = ""
                        activeSheet = nil
                    }
                )
                .environmentObject(projectsManager)
            }
        }
    }
}

struct ProjectSelectorView: View {
    @ObservedObject var focusManager: FocusManager
    @EnvironmentObject var projectsManager: ProjectsManager
    @Environment(\.dismiss) private var dismiss
    @State private var editingSlot: ProjectManagerCore.ProjectSlot?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Manage Active Projects")
                .font(.headline)
            
            Text("Assign projects to slots based on tag requirements. Only projects with matching tags can occupy each slot.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Project Slots
                    Text("Project Slots")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(focusManager.projectSlots.enumerated()), id: \.element.id) { index, slot in
                        ProjectSlotView(
                            slot: slot,
                            slotNumber: index + 1,
                            focusManager: focusManager,
                            projectsManager: projectsManager,
                            onEditTags: {
                                editingSlot = slot
                            }
                        )
                    }
                    
                    Divider()
                    
                    // Available Projects
                    if !focusManager.inactiveProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available Projects")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(focusManager.inactiveProjects) { project in
                                AvailableProjectRowView(
                                    project: project,
                                    focusManager: focusManager,
                                    projectsManager: projectsManager
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
            
            HStack {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 500, height: 600)
        .sheet(item: $editingSlot) { slot in
            SlotTagEditor(
                slot: slot,
                tagManager: projectsManager.tagManager,
                onSave: { updatedTags in
                    focusManager.updateSlotRequirements(slot.id, requiredTags: updatedTags)
                }
            )
        }
    }
}

struct FocusProjectRowView: View {
    let project: FocusedProject
    @ObservedObject var focusManager: FocusManager
    let isActive: Bool
    
    var projectName: String {
        focusManager.getProject(for: project)?.name ?? "Unknown Project"
    }
    
    var incompleteTaskCount: Int {
        focusManager.getIncompleteTaskCount(for: project.projectId)
    }
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(projectName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text("(\(incompleteTaskCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Button("Deactivate") {
                    focusManager.deactivateProject(project)
                }
                .font(.caption)
                .foregroundColor(.red)
            } else {
                let isDisabled = focusManager.activeProjects.count >= focusManager.maxActive
                Button("Activate") {
                    focusManager.activateProject(project)
                }
                .font(.caption)
                .foregroundColor(isDisabled ? .gray : .blue)
                .disabled(isDisabled)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

struct ProjectPickerDialog: View {
    let activeProjects: [FocusedProject]
    let focusManager: FocusManager
    let onSelect: (FocusedProject) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select Project for New Task")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(activeProjects) { project in
                    Button(action: {
                        onSelect(project)
                    }) {
                        HStack {
                            Text(focusManager.getProject(for: project)?.name ?? "Unknown Project")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.escape)
        }
        .padding()
        .frame(width: 300)
    }
}

struct ProjectReplacementDialog: View {
    let focusManager: FocusManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Project Completed!")
                .font(.headline)
            
            if let project = focusManager.projectNeedingReplacement,
               let projectName = focusManager.getProject(for: project)?.name {
                Text("All tasks for \"\(projectName)\" are completed. Would you like to replace it with another project?")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Projects:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(focusManager.inactiveProjects) { inactiveProject in
                                Button(action: {
                                    focusManager.replaceProject(project, with: inactiveProject)
                                }) {
                                    HStack {
                                        Text(focusManager.getProject(for: inactiveProject)?.name ?? "Unknown")
                                            .font(.subheadline)
                                        Spacer()
                                        Text("Select")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                
                HStack {
                    Button("Keep Current Project") {
                        focusManager.keepProject(project)
                    }
                    
                    Spacer()
                    
                    Button("Remove Project") {
                        focusManager.removeProjectWithoutReplacement(project)
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Manage Projects") {
                        focusManager.keepProject(project)
                        // This will close the dialog and user can manually manage projects
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

struct AddTaskDialog: View {
    @Binding var newTaskText: String
    let projectName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Task to \(projectName)")
                .font(.headline)
            
            TextField("Enter task description...", text: $newTaskText)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add", action: onSave)
                    .keyboardShortcut(.return)
                    .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct ProjectFilterChip: View {
    let project: FocusedProject
    @ObservedObject var focusManager: FocusManager
    @Binding var selectedProjects: Set<UUID>
    @EnvironmentObject var projectsManager: ProjectsManager
    
    var projectName: String {
        if let proj = focusManager.getProject(for: project) {
            return proj.name
        }
        // Fallback to projectsManager
        if let proj = projectsManager.projects.first(where: { $0.id == project.projectId }) {
            return proj.name
        }
        return "Unknown Project"
    }
    
    var isSelected: Bool {
        selectedProjects.contains(project.projectId)
    }
    
    var uncompletedTaskCount: Int {
        focusManager.allTasks.filter { 
            $0.projectId == project.projectId && $0.status != .completed 
        }.count
    }
    
    var projectColor: Color {
        let colorName = focusManager.getProjectColor(for: project.projectId)
        switch colorName {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: {
            if selectedProjects.contains(project.projectId) {
                selectedProjects.remove(project.projectId)
            } else {
                selectedProjects.insert(project.projectId)
            }
        }) {
            HStack(spacing: 4) {
                Text(projectName)
                    .font(.caption)
                Text("(\(uncompletedTaskCount))")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? projectColor : Color.secondary.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
        }
        .buttonStyle(.plain)
    }
}

struct EditTaskDialog: View {
    @Binding var taskText: String
    let originalText: String
    let projectName: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Task")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(projectName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Task description", text: $taskText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 400)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                         taskText == originalText)
            }
        }
        .padding(30)
        .frame(width: 500)
    }
}

