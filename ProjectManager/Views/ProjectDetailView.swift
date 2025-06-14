import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @StateObject private var viewModel: OverviewEditorViewModel
    @State private var selectedSection: String? = "overview"
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: OverviewEditorViewModel(project: project))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar - 25% of remaining space after project list
                List(selection: $selectedSection) {
                    if viewModel.hasUnstructuredContent {
                        Section("Migration Required") {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Migrate Overview")
                                    .foregroundColor(.primary)
                            }
                            .tag("migrate")
                        }
                    } else {
                        Section("Overview") {
                            SidebarItem(id: "overview", icon: "doc.text", title: "Overview")
                            SidebarItem(id: "status", icon: "info.circle", title: "Current Status")
                            SidebarItem(id: "todo", icon: "checklist", title: "To-Do List")
                            SidebarItem(id: "log", icon: "clock", title: "Log")
                            SidebarItem(id: "related", icon: "link", title: "Related Projects")
                            SidebarItem(id: "notes", icon: "note.text", title: "Notes")
                        }
                    }
                    
                    Section("Files") {
                        SidebarItem(id: "files", icon: "folder", title: "Project Files")
                    }
                }
                .listStyle(SidebarListStyle())
                .frame(width: geometry.size.width * 0.25)
                
                Divider()
                
                // Content area - 75% of remaining space
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if viewModel.hasUnstructuredContent && (selectedSection == nil || selectedSection == "migrate") {
                            UnstructuredContentView(viewModel: viewModel)
                        } else if !viewModel.hasUnstructuredContent {
                            switch selectedSection {
                            case "overview":
                                OverviewSectionView(
                                    title: "Overview",
                                    content: $viewModel.projectOverview.overview,
                                    onSave: viewModel.saveOverview
                                )
                            case "status":
                                OverviewSectionView(
                                    title: "Current Status",
                                    content: $viewModel.projectOverview.currentStatus,
                                    onSave: viewModel.saveOverview
                                )
                            case "todo":
                                TodoListView(viewModel: viewModel)
                            case "log":
                                OverviewSectionView(
                                    title: "Log",
                                    content: $viewModel.projectOverview.log,
                                    onSave: viewModel.saveOverview
                                )
                            case "related":
                                RelatedProjectsView(
                                    relatedProjects: $viewModel.projectOverview.relatedProjects,
                                    onSave: viewModel.saveOverview
                                )
                            case "notes":
                                OverviewSectionView(
                                    title: "Notes",
                                    content: $viewModel.projectOverview.notes,
                                    onSave: viewModel.saveOverview
                                )
                            case "files":
                                ProjectFilesView(project: project)
                            default:
                                EmptyView()
                            }
                        } else if selectedSection == "files" {
                            ProjectFilesView(project: project)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: geometry.size.width * 0.75)
            }
        }
        .navigationTitle(project.name)
        .onAppear {
            viewModel.loadOverview()
        }
        .onReceive(viewModel.$hasUnstructuredContent) { hasUnstructured in
            // Set selection after content is loaded
            if hasUnstructured && (selectedSection == nil || selectedSection == "overview") {
                selectedSection = "migrate"
            } else if !hasUnstructured && selectedSection == nil {
                selectedSection = "overview"
            }
        }
        .onChange(of: viewModel.hasUnstructuredContent) { hasUnstructured in
            if hasUnstructured {
                selectedSection = "migrate"
            }
        }
    }
}

struct SidebarItem: View {
    let id: String
    let icon: String
    let title: String
    
    var body: some View {
        Label(title, systemImage: icon)
            .tag(id)
    }
}

struct OverviewSectionView: View {
    let title: String
    @Binding var content: String
    let onSave: () -> Void
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { isEditing.toggle() }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                }
                .buttonStyle(.plain)
            }
            
            if isEditing {
                TextEditor(text: $content)
                    .font(.body)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .frame(minHeight: 200)
                    .onChange(of: content) { _ in
                        onSave()
                    }
            } else {
                if content.isEmpty {
                    Text("No content yet. Click the edit button to add content.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    Text(content)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
    }
}