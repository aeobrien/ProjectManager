import SwiftUI

struct NewProjectForm: View {
    @ObservedObject var projectsManager: ProjectsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName = ""
    @State private var coreConcept = ""
    @State private var guidingPrinciples = ""
    @State private var keyFeatures = ""
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
                    
                    Section("Core Concept") {
                        TextEditor(text: $coreConcept)
                            .frame(minHeight: 80)
                            .overlay(
                                Group {
                                    if coreConcept.isEmpty {
                                        Text("What is this project and its primary purpose?")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    Section("Guiding Principles") {
                        TextEditor(text: $guidingPrinciples)
                            .frame(minHeight: 60)
                            .overlay(
                                Group {
                                    if guidingPrinciples.isEmpty {
                                        Text("Philosophy, values, and goals driving the project")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    Section("Key Features") {
                        TextEditor(text: $keyFeatures)
                            .frame(minHeight: 80)
                            .overlay(
                                Group {
                                    if keyFeatures.isEmpty {
                                        Text("List the main features or components...")
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
        projectOverview.coreConcept = coreConcept.isEmpty ? "[Comprehensive overview of what the project is and its primary purpose]" : coreConcept
        projectOverview.guidingPrinciples = guidingPrinciples.isEmpty ? "[The underlying philosophy, values, and goals driving the project]" : guidingPrinciples
        projectOverview.keyFeatures = keyFeatures.isEmpty ? "[Detailed list of all features/components with descriptions]" : keyFeatures
        
        // The template will handle creating the rest of the structure
        
        do {
            try projectsManager.createProject(name: trimmedName, overview: projectOverview)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}