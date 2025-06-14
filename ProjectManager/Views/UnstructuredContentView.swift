import SwiftUI

struct UnstructuredContentView: View {
    @ObservedObject var viewModel: OverviewEditorViewModel
    @State private var showingMigrationAlert = false
    
    var body: some View {
        let _ = print("UnstructuredContentView - rawContent length: \(viewModel.rawContent.count)")
        let _ = print("UnstructuredContentView - hasUnstructuredContent: \(viewModel.hasUnstructuredContent)")
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
            
            GeometryReader { geometry in
                HStack(spacing: 16) {
                    // Original content - left half
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Original Content")
                            .font(.headline)
                        
                        ScrollView {
                            if viewModel.rawContent.isEmpty {
                                Text("No content loaded")
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                Text(viewModel.rawContent)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    }
                    .frame(width: geometry.size.width * 0.48)
                    
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
                                    title: "Overview",
                                    content: $viewModel.projectOverview.overview,
                                    placeholder: "Copy and paste the overview content here"
                                )
                                
                                StructuredSectionEditor(
                                    title: "Current Status",
                                    content: $viewModel.projectOverview.currentStatus,
                                    placeholder: "Copy and paste the current status here"
                                )
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("To-Do List")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Add todo items in the structured view after migration")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                
                                StructuredSectionEditor(
                                    title: "Log",
                                    content: $viewModel.projectOverview.log,
                                    placeholder: "Copy and paste log entries here"
                                )
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Related Projects")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Add related projects in the structured view after migration")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                
                                StructuredSectionEditor(
                                    title: "Notes",
                                    content: $viewModel.projectOverview.notes,
                                    placeholder: "Copy and paste notes here"
                                )
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .frame(width: geometry.size.width * 0.48)
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