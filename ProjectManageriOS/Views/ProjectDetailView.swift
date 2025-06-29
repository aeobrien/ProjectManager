import SwiftUI
import ProjectManagerCore

struct ProjectDetailView: View {
    let project: Project
    @StateObject private var viewModel: OverviewEditorViewModel
    @State private var selectedTab = 0
    
    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: OverviewEditorViewModel(project: project))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom segment control
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Files").tag(1)
                Text("Tasks").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    OverviewView(viewModel: viewModel)
                case 1:
                    FilesView(project: project)
                case 2:
                    ProjectTasksView(project: project)
                default:
                    EmptyView()
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadOverview()
        }
    }
}

struct OverviewView: View {
    @ObservedObject var viewModel: OverviewEditorViewModel
    @State private var isEditing = false
    @State private var editedDescription: String = ""
    @State private var editedNextSteps: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Description Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Description")
                            .font(.headline)
                        Spacer()
                        Button(isEditing ? "Done" : "Edit") {
                            if isEditing {
                                viewModel.updateDescription(editedDescription)
                                viewModel.updateNextSteps(editedNextSteps)
                                Task {
                                    try? await viewModel.saveOverview()
                                }
                            } else {
                                editedDescription = viewModel.projectOverview.currentStatus
                                editedNextSteps = viewModel.projectOverview.nextSteps
                            }
                            isEditing.toggle()
                        }
                    }
                    
                    if isEditing {
                        TextEditor(text: $editedDescription)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        Text(viewModel.projectOverview.currentStatus)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                
                Divider()
                
                // Next Steps Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next Steps")
                        .font(.headline)
                    
                    if isEditing {
                        TextEditor(text: $editedNextSteps)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        TaskListView(markdownText: viewModel.projectOverview.nextSteps)
                    }
                }
            }
            .padding()
        }
    }
}

struct TaskListView: View {
    let markdownText: String
    
    var tasks: [(text: String, isCompleted: Bool)] {
        markdownText.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") {
                return (String(trimmed.dropFirst(5)), false)
            } else if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                return (String(trimmed.dropFirst(5)), true)
            }
            return nil
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                HStack(spacing: 12) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .green : .gray)
                        .font(.system(size: 20))
                    
                    Text(task.text)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct FilesView: View {
    let project: Project
    @State private var files: [URL] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if files.isEmpty {
                ContentUnavailableView(
                    "No Files",
                    systemImage: "doc",
                    description: Text("This project doesn't have any files yet")
                )
            } else {
                List(files, id: \.self) { file in
                    FileRowView(file: file)
                }
            }
        }
        .onAppear {
            loadFiles()
        }
    }
    
    private func loadFiles() {
        // TODO: Implement file loading from Dropbox
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
        }
    }
}

struct FileRowView: View {
    let file: URL
    
    var fileIcon: String {
        switch file.pathExtension.lowercased() {
        case "md":
            return "doc.text"
        case "png", "jpg", "jpeg", "gif":
            return "photo"
        case "pdf":
            return "doc.fill"
        default:
            return "doc"
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: fileIcon)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading) {
                Text(file.lastPathComponent)
                    .font(.body)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ProjectTasksView: View {
    let project: Project
    @EnvironmentObject var focusManager: FocusManager
    
    var projectTasks: [FocusTask] {
        focusManager.allTasks.filter { $0.projectId == project.id }
    }
    
    var body: some View {
        List {
            ForEach(TaskStatus.allCases, id: \.self) { status in
                let tasks = projectTasks.filter { $0.status == status }
                if !tasks.isEmpty {
                    Section(status.rawValue) {
                        ForEach(tasks) { task in
                            TaskRowView(task: task)
                        }
                    }
                }
            }
        }
        .overlay {
            if projectTasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks",
                    systemImage: "checklist",
                    description: Text("Add tasks from the Focus Board")
                )
            }
        }
    }
}

struct TaskRowView: View {
    let task: FocusTask
    
    var statusIcon: String {
        switch task.status {
        case .todo:
            return "circle"
        case .inProgress:
            return "timer"
        case .completed:
            return "checkmark.circle.fill"
        }
    }
    
    var statusColor: Color {
        switch task.status {
        case .todo:
            return .gray
        case .inProgress:
            return .orange
        case .completed:
            return .green
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            Text(task.displayText)
                .strikethrough(task.status == .completed)
                .foregroundColor(task.status == .completed ? .secondary : .primary)
        }
        .padding(.vertical, 4)
    }
}