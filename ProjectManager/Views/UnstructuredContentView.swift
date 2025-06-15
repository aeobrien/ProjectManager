import SwiftUI

struct UnstructuredContentView: View {
    @ObservedObject var viewModel: OverviewEditorViewModel
    @State private var showingMigrationAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    Text("Unstructured Overview File")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Text("This overview file exists but doesn't have the expected structure. You can view the original content below and manually copy elements into the structured sections.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            HStack(alignment: .top, spacing: 16) {
                // Original content - left half
                VStack(alignment: .leading, spacing: 12) {
                    Text("Original Content")
                        .font(.headline)
                    
                    ScrollView {
                        MarkdownTextView(markdown: viewModel.rawContent) { checkboxContent, isChecked in
                            // For unstructured content, we don't support checkbox toggling
                            // as we can't reliably save changes back to the original format
                        }
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Structured sections - right half
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Structured Sections")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Migrate to Structured Format") {
                            showingMigrationAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            StructuredSectionEditor(
                                title: "Version History",
                                content: $viewModel.projectOverview.versionHistory,
                                placeholder: "e.g., v0.1 - Date - Initial creation"
                            )
                            
                            StructuredSectionEditor(
                                title: "Core Concept",
                                content: $viewModel.projectOverview.coreConcept,
                                placeholder: "What is this project and its primary purpose?"
                            )
                            
                            StructuredSectionEditor(
                                title: "Guiding Principles & Intentions",
                                content: $viewModel.projectOverview.guidingPrinciples,
                                placeholder: "Philosophy, values, and goals"
                            )
                            
                            StructuredSectionEditor(
                                title: "Key Features & Functionality",
                                content: $viewModel.projectOverview.keyFeatures,
                                placeholder: "List of features/components"
                            )
                            
                            StructuredSectionEditor(
                                title: "Architecture & Structure",
                                content: $viewModel.projectOverview.architecture,
                                placeholder: "Technical architecture / Content structure / Design framework"
                            )
                            
                            StructuredSectionEditor(
                                title: "Implementation Roadmap",
                                content: $viewModel.projectOverview.implementationRoadmap,
                                placeholder: "Phases and tasks with checkboxes"
                            )
                            
                            StructuredSectionEditor(
                                title: "Current Status & Progress",
                                content: $viewModel.projectOverview.currentStatus,
                                placeholder: "Where the project stands"
                            )
                            
                            StructuredSectionEditor(
                                title: "Next Steps",
                                content: $viewModel.projectOverview.nextSteps,
                                placeholder: "Immediate actionable items"
                            )
                            
                            StructuredSectionEditor(
                                title: "Challenges & Solutions",
                                content: $viewModel.projectOverview.challenges,
                                placeholder: "Technical, creative, or logistical challenges"
                            )
                            
                            StructuredSectionEditor(
                                title: "User/Audience Experience",
                                content: $viewModel.projectOverview.userExperience,
                                placeholder: "How users will interact with the project"
                            )
                            
                            StructuredSectionEditor(
                                title: "Success Metrics",
                                content: $viewModel.projectOverview.successMetrics,
                                placeholder: "Criteria for measuring success"
                            )
                            
                            StructuredSectionEditor(
                                title: "Research & References",
                                content: $viewModel.projectOverview.research,
                                placeholder: "Supporting materials, documentation"
                            )
                            
                            StructuredSectionEditor(
                                title: "Open Questions & Considerations",
                                content: $viewModel.projectOverview.openQuestions,
                                placeholder: "Ongoing thoughts, future possibilities"
                            )
                            
                            StructuredSectionEditor(
                                title: "Project Log",
                                content: $viewModel.projectOverview.projectLog,
                                placeholder: "Date-based log entries"
                            )
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .alert("Migrate to Structured Format?", isPresented: $showingMigrationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Migrate") {
                viewModel.migrateToStructuredFormat()
            }
        } message: {
            Text("This will:\n• Create a backup file (overviewbackup.md)\n• Convert the file to the structured format\n• Preserve any content you've added to the sections\n\nThe original content will be saved in the backup file.")
        }
    }
}

struct StructuredSectionEditor: View {
    let title: String
    @Binding var content: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextEditor(text: $content)
                .font(.body)
                .frame(minHeight: 60)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    Group {
                        if content.isEmpty {
                            Text(placeholder)
                                .foregroundColor(.secondary)
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
}