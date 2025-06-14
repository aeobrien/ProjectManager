import SwiftUI

struct NewProjectForm: View {
    @ObservedObject var projectsManager: ProjectsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName = ""
    @State private var overview = ""
    @State private var currentStatus = ""
    @State private var initialTodos = ""
    @State private var notes = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Text("New Project")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Form {
                    Section {
                        TextField("Project Name", text: $projectName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Section("Overview") {
                        TextEditor(text: $overview)
                            .frame(minHeight: 80)
                            .overlay(
                                Group {
                                    if overview.isEmpty {
                                        Text("Describe what this project is about...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    Section("Current Status") {
                        TextEditor(text: $currentStatus)
                            .frame(minHeight: 60)
                            .overlay(
                                Group {
                                    if currentStatus.isEmpty {
                                        Text("Where does the project stand now?")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    Section("Initial To-Do Items") {
                        TextEditor(text: $initialTodos)
                            .frame(minHeight: 80)
                            .overlay(
                                Group {
                                    if initialTodos.isEmpty {
                                        Text("Enter tasks, one per line...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Section("Notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                            .overlay(
                                Group {
                                    if notes.isEmpty {
                                        Text("Any additional context or ideas...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                }
                .formStyle(.grouped)
            }
            .padding()
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Create Project") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
        .alert("Error Creating Project", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        var projectOverview = ProjectOverview()
        projectOverview.overview = overview.isEmpty ? "[Short description]" : overview
        projectOverview.currentStatus = currentStatus.isEmpty ? "[Where the project stands now]" : currentStatus
        projectOverview.notes = notes.isEmpty ? "[Any extra context or ideas]" : notes
        
        if !initialTodos.isEmpty {
            let todos = initialTodos.split(separator: "\n").map { line in
                TodoItem(text: String(line).trimmingCharacters(in: .whitespacesAndNewlines), isCompleted: false)
            }
            projectOverview.todoItems = todos.filter { !$0.text.isEmpty }
        }
        
        do {
            try projectsManager.createProject(name: trimmedName, overview: projectOverview)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}