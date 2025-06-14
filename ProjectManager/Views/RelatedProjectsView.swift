import SwiftUI

struct RelatedProjectsView: View {
    @Binding var relatedProjects: [String]
    let onSave: () -> Void
    @State private var newProjectName = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Related Projects")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { isEditing.toggle() }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                }
                .buttonStyle(.plain)
            }
            
            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(relatedProjects.indices, id: \.self) { index in
                        HStack {
                            TextField("Project name", text: $relatedProjects[index])
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: relatedProjects[index]) { _ in
                                    onSave()
                                }
                            
                            Button(action: {
                                relatedProjects.remove(at: index)
                                onSave()
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    HStack {
                        TextField("Add related project", text: $newProjectName, onCommit: addNewProject)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(action: addNewProject) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                if relatedProjects.isEmpty {
                    Text("No related projects. Click the edit button to add projects.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(relatedProjects, id: \.self) { project in
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(project)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func addNewProject() {
        guard !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        relatedProjects.append(newProjectName)
        newProjectName = ""
        onSave()
    }
}