import SwiftUI
import ProjectManagerCore

struct FocusBoardTabView: View {
    @EnvironmentObject var focusManager: FocusManager
    @State private var selectedStatus: TaskStatus = .todo
    @State private var showingProjectManagement = false
    
    var syncIconName: String {
        switch focusManager.syncStatus {
        case "Ready", "Synced":
            return "icloud"
        case "Not Signed In":
            return "icloud.slash"
        case "Syncing...":
            return "icloud"
        default:
            return "exclamationmark.icloud"
        }
    }
    
    var syncIconColor: Color {
        switch focusManager.syncStatus {
        case "Ready", "Synced":
            return .blue
        case "Not Signed In":
            return .orange
        case "Syncing...":
            return .green
        default:
            return .red
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom segment control
                Picker("Task Status", selection: $selectedStatus) {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected status
                Group {
                    switch selectedStatus {
                    case .todo:
                        FocusTaskListView(tasks: focusManager.todoTasks, status: .todo)
                    case .inProgress:
                        FocusTaskListView(tasks: focusManager.inProgressTasks, status: .inProgress)
                    case .completed:
                        FocusTaskListView(tasks: focusManager.completedTasks, status: .completed)
                    }
                }
                .environmentObject(focusManager)
            }
            .navigationTitle("Focus Board")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if focusManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Menu {
                            Button(action: {
                                Task {
                                    await focusManager.syncFromCloudKit()
                                }
                            }) {
                                Label("Sync Now", systemImage: "arrow.clockwise")
                            }
                            
                            Text("Status: \(focusManager.syncStatus)")
                                .font(.caption)
                            
                            if let lastSync = SimpleSyncManager.shared.lastSyncDate {
                                Text("Last sync: \(RelativeDateTimeFormatter().localizedString(for: lastSync, relativeTo: Date()))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        } label: {
                            Image(systemName: syncIconName)
                                .foregroundColor(syncIconColor)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manage") {
                        showingProjectManagement = true
                    }
                }
            }
            .sheet(isPresented: $showingProjectManagement) {
                ProjectManagementSheet()
                    .environmentObject(focusManager)
            }
        }
    }
}

struct FocusTaskListView: View {
    let tasks: [FocusTask]
    let status: TaskStatus
    @EnvironmentObject var focusManager: FocusManager
    @State private var showingAddTask = false
    
    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskCardView(task: task)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
            
            if status == .todo && !focusManager.activeProjects.isEmpty {
                Button(action: {
                    showingAddTask = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Task")
                        Spacer()
                    }
                    .foregroundColor(.accentColor)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(12)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .overlay {
            if tasks.isEmpty && status != .todo {
                ContentUnavailableView(
                    "No \(status.rawValue) Tasks",
                    systemImage: status == .inProgress ? "timer" : "checkmark.circle",
                    description: Text(status.description)
                )
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet()
                .environmentObject(focusManager)
        }
    }
}

struct TaskCardView: View {
    let task: FocusTask
    @EnvironmentObject var focusManager: FocusManager
    @State private var offset: CGSize = .zero
    @State private var showingEditSheet = false
    
    var projectName: String {
        focusManager.getProjectName(for: task)
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
        VStack(alignment: .leading, spacing: 12) {
            // Project badge
            Text(projectName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(projectColor)
                .cornerRadius(6)
            
            // Task text
            Text(task.displayText)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Metadata and actions
            HStack {
                Text(RelativeDateTimeFormatter().localizedString(for: task.lastModified, relativeTo: Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Quick action buttons
                if task.status == .todo {
                    Button("Start") {
                        withAnimation {
                            focusManager.updateTaskStatus(task, newStatus: .inProgress)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                } else if task.status == .inProgress {
                    Button("Complete") {
                        withAnimation {
                            focusManager.updateTaskStatus(task, newStatus: .completed)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .offset(x: offset.width)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    // Only allow horizontal swipes
                    if abs(value.translation.width) > abs(value.translation.height) {
                        offset = CGSize(width: value.translation.width, height: 0)
                    }
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        // Swipe threshold
                        if value.translation.width > 100 {
                            // Swipe right - change status forward
                            changeStatusForward()
                        } else if value.translation.width < -100 {
                            // Swipe left - change status backward
                            changeStatusBackward()
                        }
                        offset = .zero
                    }
                }
        )
        .onTapGesture {
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTaskSheet(task: task)
                .environmentObject(focusManager)
        }
    }
    
    private func changeStatusForward() {
        switch task.status {
        case .todo:
            focusManager.updateTaskStatus(task, newStatus: .inProgress)
        case .inProgress:
            focusManager.updateTaskStatus(task, newStatus: .completed)
        case .completed:
            break
        }
    }
    
    private func changeStatusBackward() {
        switch task.status {
        case .todo:
            break
        case .inProgress:
            focusManager.updateTaskStatus(task, newStatus: .todo)
        case .completed:
            focusManager.updateTaskStatus(task, newStatus: .inProgress)
        }
    }
}

struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @State private var taskText = ""
    @State private var selectedProject: FocusedProject?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Description") {
                    TextField("What needs to be done?", text: $taskText, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Project") {
                    Picker("Select Project", selection: $selectedProject) {
                        ForEach(focusManager.activeProjects) { project in
                            Text(focusManager.getProject(for: project)?.name ?? "Unknown")
                                .tag(project as FocusedProject?)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let project = selectedProject {
                            focusManager.addTask(to: project, text: taskText)
                            dismiss()
                        }
                    }
                    .disabled(taskText.isEmpty || selectedProject == nil)
                }
            }
        }
        .onAppear {
            if focusManager.activeProjects.count == 1 {
                selectedProject = focusManager.activeProjects.first
            }
        }
    }
}

struct EditTaskSheet: View {
    let task: FocusTask
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @State private var editedText: String
    
    init(task: FocusTask) {
        self.task = task
        _editedText = State(initialValue: task.displayText)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Description") {
                    TextField("Task", text: $editedText, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Status") {
                    Picker("Status", selection: .constant(task.status)) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Label(status.rawValue, systemImage: statusIcon(for: status))
                                .tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        focusManager.updateTaskText(task, newText: editedText)
                        dismiss()
                    }
                    .disabled(editedText == task.displayText || editedText.isEmpty)
                }
            }
        }
    }
    
    private func statusIcon(for status: TaskStatus) -> String {
        switch status {
        case .todo:
            return "circle"
        case .inProgress:
            return "timer"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
}

struct ProjectManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var focusManager: FocusManager
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Projects", selection: $selectedTab) {
                    Text("Active (\(focusManager.activeProjects.count))").tag(0)
                    Text("Inactive (\(focusManager.inactiveProjects.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                Group {
                    if selectedTab == 0 {
                        ActiveProjectsList()
                    } else {
                        InactiveProjectsList()
                    }
                }
                .environmentObject(focusManager)
            }
            .navigationTitle("Manage Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ActiveProjectsList: View {
    @EnvironmentObject var focusManager: FocusManager
    
    var body: some View {
        List {
            ForEach(focusManager.activeProjects) { project in
                HStack {
                    VStack(alignment: .leading) {
                        Text(focusManager.getProject(for: project)?.name ?? "Unknown")
                            .font(.headline)
                        if let lastWorked = project.lastWorkedOn {
                            Text("Last worked: \(RelativeDateTimeFormatter().localizedString(for: lastWorked, relativeTo: Date()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Deactivate") {
                        withAnimation {
                            focusManager.deactivateProject(project)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding(.vertical, 4)
            }
        }
        .overlay {
            if focusManager.activeProjects.isEmpty {
                ContentUnavailableView(
                    "No Active Projects",
                    systemImage: "target",
                    description: Text("Activate projects to start focusing on them")
                )
            }
        }
    }
}

struct InactiveProjectsList: View {
    @EnvironmentObject var focusManager: FocusManager
    
    var body: some View {
        List {
            ForEach(focusManager.inactiveProjects) { project in
                HStack {
                    Text(focusManager.getProject(for: project)?.name ?? "Unknown")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button("Activate") {
                        withAnimation {
                            focusManager.activateProject(project)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .disabled(focusManager.activeProjects.count >= focusManager.maxActive)
                }
                .padding(.vertical, 4)
            }
        }
        .overlay {
            if focusManager.inactiveProjects.isEmpty {
                ContentUnavailableView(
                    "No Inactive Projects",
                    systemImage: "moon",
                    description: Text("All projects are currently active")
                )
            }
        }
    }
}