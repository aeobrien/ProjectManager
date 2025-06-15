import SwiftUI

struct FocusBoardView: View {
    @EnvironmentObject var projectsManager: ProjectsManager
    @StateObject private var focusManager = FocusManager()
    @State private var showingNewTaskDialog = false
    @State private var showingProjectSelector = false
    @State private var selectedProjectForNewTask: FocusedProject?
    @State private var newTaskText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Focus Board")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Active project count and warnings
                    HStack {
                        if focusManager.isOverActiveLimit {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("\(focusManager.activeProjects.count) active projects (max \(5))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        } else if focusManager.isUnderActiveMinimum {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("\(focusManager.activeProjects.count) active projects (min \(3) recommended)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            Text("\(focusManager.activeProjects.count) active projects")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Manage Projects") {
                        showingProjectSelector = true
                    }
                    
                    Button("Refresh") {
                        focusManager.syncWithProjects(projectsManager.projects)
                    }
                }
                
                // Insights row
                HStack {
                    if !focusManager.staleActiveProjects.isEmpty {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("\(focusManager.staleActiveProjects.count) stale project(s)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if !focusManager.projectsWithNoActiveTasks.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("\(focusManager.projectsWithNoActiveTasks.count) project(s) with no tasks")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding()
            
            Divider()
            
            // Task Board - 3 columns for task statuses
            HStack(alignment: .top, spacing: 1) {
                // To Do Column
                TaskColumnView(
                    title: "To Do",
                    subtitle: TaskStatus.todo.description,
                    tasks: focusManager.todoTasks,
                    taskStatus: .todo,
                    focusManager: focusManager,
                    projectsManager: projectsManager
                )
                
                Divider()
                
                // In Progress Column
                TaskColumnView(
                    title: "In Progress",
                    subtitle: TaskStatus.inProgress.description,
                    tasks: focusManager.inProgressTasks,
                    taskStatus: .inProgress,
                    focusManager: focusManager,
                    projectsManager: projectsManager
                )
                
                Divider()
                
                // Completed Column
                TaskColumnView(
                    title: "Completed",
                    subtitle: TaskStatus.completed.description,
                    tasks: focusManager.completedTasks,
                    taskStatus: .completed,
                    focusManager: focusManager,
                    projectsManager: projectsManager
                )
            }
        }
        .frame(minWidth: 1200, minHeight: 600, maxHeight: .infinity)
        .onAppear {
            focusManager.syncWithProjects(projectsManager.projects)
        }
        .onChange(of: projectsManager.projects) { newProjects in
            focusManager.syncWithProjects(newProjects)
        }
        .sheet(isPresented: $showingProjectSelector) {
            ProjectSelectorView(focusManager: focusManager)
        }
        .sheet(isPresented: $focusManager.showingProjectSelector) {
            ProjectReplacementDialog(focusManager: focusManager)
        }
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
                    ForEach(tasks) { task in
                        TaskCardView(
                            task: task,
                            focusManager: focusManager,
                            projectsManager: projectsManager
                        )
                    }
                    
                    // Add task button for To Do column
                    if taskStatus == .todo {
                        AddTaskButton(focusManager: focusManager)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
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
    
    var projectName: String {
        focusManager.getProjectName(for: task)
    }
    
    var project: Project? {
        focusManager.projects.first { $0.id == task.projectId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Project name (small, at top)
            HStack {
                Text(projectName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
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
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Task text (main content)
            Text(task.displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
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
        .shadow(radius: 1)
        .sheet(isPresented: $showingProjectDetail) {
            if let proj = project {
                ProjectDetailView(project: proj)
                    .environmentObject(projectsManager)
            }
        }
    }
}

struct AddTaskButton: View {
    let focusManager: FocusManager
    @State private var showingTaskDialog = false
    @State private var showingProjectPicker = false
    @State private var newTaskText = ""
    @State private var selectedProject: FocusedProject?
    
    var body: some View {
        Button(action: {
            if focusManager.activeProjects.count == 1 {
                selectedProject = focusManager.activeProjects.first
                showingTaskDialog = true
            } else {
                showingProjectPicker = true
            }
        }) {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundColor(.accentColor)
                Text("Add Task")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
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
        .sheet(isPresented: $showingProjectPicker) {
            ProjectPickerDialog(
                activeProjects: focusManager.activeProjects,
                onSelect: { project in
                    selectedProject = project
                    showingProjectPicker = false
                    showingTaskDialog = true
                },
                onCancel: {
                    showingProjectPicker = false
                }
            )
        }
        .sheet(isPresented: $showingTaskDialog) {
            AddTaskDialog(
                newTaskText: $newTaskText,
                projectName: {
                    if let project = selectedProject {
                        return focusManager.getProject(for: project)?.name ?? "Unknown"
                    }
                    return "Unknown"
                }(),
                onSave: {
                    if let project = selectedProject {
                        focusManager.addTask(to: project, text: newTaskText)
                    }
                    newTaskText = ""
                    showingTaskDialog = false
                    selectedProject = nil
                },
                onCancel: {
                    newTaskText = ""
                    showingTaskDialog = false
                    selectedProject = nil
                }
            )
        }
    }
}

struct ProjectSelectorView: View {
    let focusManager: FocusManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Manage Active Projects")
                .font(.headline)
            
            Text("Select 3-5 projects to focus on. Only tasks from active projects will appear in the focus board.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Projects (\(focusManager.activeProjects.count)/5)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(focusManager.activeProjects) { project in
                            FocusProjectRowView(project: project, focusManager: focusManager, isActive: true)
                        }
                    }
                    
                    if !focusManager.inactiveProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Inactive Projects")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(focusManager.inactiveProjects) { project in
                                FocusProjectRowView(project: project, focusManager: focusManager, isActive: false)
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
    }
}

struct FocusProjectRowView: View {
    let project: FocusedProject
    let focusManager: FocusManager
    let isActive: Bool
    
    var projectName: String {
        focusManager.getProject(for: project)?.name ?? "Unknown Project"
    }
    
    var body: some View {
        HStack {
            Text(projectName)
                .font(.subheadline)
            
            Spacer()
            
            if isActive {
                Button("Deactivate") {
                    focusManager.deactivateProject(project)
                }
                .font(.caption)
                .foregroundColor(.red)
            } else {
                Button("Activate") {
                    focusManager.activateProject(project)
                }
                .font(.caption)
                .foregroundColor(.blue)
                .disabled(focusManager.activeProjects.count >= 5)
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
                            Text(project.project?.name ?? "Unknown Project")
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
                    
                    ForEach(focusManager.inactiveProjects.prefix(5)) { inactiveProject in
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
                
                HStack {
                    Button("Keep Current Project") {
                        focusManager.keepProject(project)
                    }
                    
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
        .frame(width: 400)
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