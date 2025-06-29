import SwiftUI
import ProjectManagerCore

struct ProjectsListView: View {
    @EnvironmentObject var projectsManager: ProjectsManager
    @State private var showingNewProjectSheet = false
    @State private var searchText = ""
    
    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projectsManager.projects
        } else {
            return projectsManager.projects.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredProjects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project)) {
                        ProjectRowView(project: project)
                    }
                }
                .onDelete(perform: deleteProjects)
            }
            .navigationTitle("Projects")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewProjectSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await projectsManager.refreshProjects()
            }
            .sheet(isPresented: $showingNewProjectSheet) {
                NewProjectSheet()
            }
        }
    }
    
    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            projectsManager.deleteProject(filteredProjects[index])
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    @EnvironmentObject var projectsManager: ProjectsManager
    
    var projectStatus: ProjectStatus? {
        projectsManager.focusManager?.focusedProjects
            .first(where: { $0.projectId == project.id })
            .map { $0.status }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                
                if let status = projectStatus {
                    Label(status.rawValue, systemImage: status == .active ? "target" : "moon")
                        .font(.caption)
                        .foregroundColor(status == .active ? .blue : .gray)
                }
            }
            
            Spacer()
            
            if project.hasOverview {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectsManager: ProjectsManager
    @State private var projectName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $projectName)
                        .autocorrectionDisabled()
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Project name cannot be empty"
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                try await projectsManager.createProject(named: trimmedName)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}