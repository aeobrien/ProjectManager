import SwiftUI

struct RenameProjectSheet: View {
    let project: Project
    @ObservedObject var projectsManager: ProjectsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var newName: String
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(project: Project, projectsManager: ProjectsManager) {
        self.project = project
        self.projectsManager = projectsManager
        self._newName = State(initialValue: project.name)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Project")
                .font(.headline)
            
            Text("This will rename both the folder and the overview markdown file.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("New name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    renameProject()
                }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Rename") {
                    renameProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newName == project.name)
            }
        }
        .padding()
        .frame(width: 400)
        .alert("Error Renaming Project", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func renameProject() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty && trimmedName != project.name else { return }
        
        do {
            try projectsManager.renameProject(project, to: trimmedName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}