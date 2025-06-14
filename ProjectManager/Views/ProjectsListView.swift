import SwiftUI

struct ProjectsListView: View {
    @StateObject private var projectsManager = ProjectsManager()
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var showingFolderPicker = false
    @State private var showingNewProjectForm = false
    @State private var selectedProject: Project?
    @State private var projectToRename: Project?
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $selectedProject) {
                ForEach(projectsManager.projects) { project in
                    NavigationLink(value: project) {
                        ProjectRowView(project: project)
                    }
                    .contextMenu {
                        Button("Rename") {
                            projectToRename = project
                        }
                        Button("Delete", role: .destructive) {
                            deleteProject(project)
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewProjectForm = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigation) {
                    Button(action: { showingFolderPicker = true }) {
                        Image(systemName: "folder")
                    }
                }
            }
            .overlay {
                if preferencesManager.projectsFolder == nil {
                    ContentUnavailableView {
                        Label("No Projects Folder", systemImage: "folder.badge.questionmark")
                    } description: {
                        Text("Select a folder to store your projects")
                    } actions: {
                        Button("Select Folder") {
                            showingFolderPicker = true
                        }
                    }
                } else if projectsManager.projects.isEmpty {
                    ContentUnavailableView {
                        Label("No Projects", systemImage: "doc.text")
                    } description: {
                        Text("Create your first project to get started")
                    } actions: {
                        Button("New Project") {
                            showingNewProjectForm = true
                        }
                    }
                }
            }
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
                    .frame(minWidth: 800)
            } else {
                ContentUnavailableView {
                    Label("Select a Project", systemImage: "sidebar.left")
                } description: {
                    Text("Choose a project from the sidebar")
                }
            }
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    preferencesManager.projectsFolder = url
                }
            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
        .sheet(isPresented: $showingNewProjectForm) {
            NewProjectForm(projectsManager: projectsManager)
        }
        .sheet(item: $projectToRename) { project in
            RenameProjectSheet(project: project, projectsManager: projectsManager)
        }
        .onChange(of: selectedProject) { newValue in
            projectsManager.selectedProject = newValue
        }
    }
    
    private func deleteProject(_ project: Project) {
        do {
            try projectsManager.deleteProject(project)
            if selectedProject == project {
                selectedProject = nil
            }
        } catch {
            print("Error deleting project: \(error)")
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    @State private var needsMigration = false
    
    var body: some View {
        HStack {
            if needsMigration {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else {
                Image(systemName: project.hasOverview ? "doc.text.fill" : "folder.fill")
                    .foregroundColor(project.hasOverview ? .accentColor : .secondary)
            }
            
            VStack(alignment: .leading) {
                Text(project.name)
                    .font(.headline)
                
                Text(project.folderPath.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            checkIfNeedsMigration()
        }
    }
    
    private func checkIfNeedsMigration() {
        guard project.hasOverview else {
            needsMigration = false
            return
        }
        
        do {
            let content = try String(contentsOf: project.overviewPath, encoding: .utf8)
            let hasExpectedStructure = ProjectOverview.sectionHeaders.allSatisfy { header in
                content.contains(header)
            }
            needsMigration = !hasExpectedStructure
        } catch {
            needsMigration = false
        }
    }
}