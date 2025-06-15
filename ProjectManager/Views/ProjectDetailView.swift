import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @StateObject private var viewModel: OverviewEditorViewModel
    @State private var selectedSection: String?
    @State private var showFullDocument = true
    @State private var scrollToSection: String?
    
    init(project: Project) {
        self.project = project
        self._viewModel = StateObject(wrappedValue: OverviewEditorViewModel(project: project))
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Sidebar - 25% of remaining space after project list
                VStack(spacing: 0) {
                    if !viewModel.hasUnstructuredContent {
                        Toggle(isOn: $showFullDocument) {
                            Label("Full Document", systemImage: "doc.text")
                        }
                        .toggleStyle(.button)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        Divider()
                    }
                    
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
                            Section("Project Info") {
                                SidebarItem(id: "version", icon: "clock.arrow.circlepath", title: "Version History")
                                SidebarItem(id: "concept", icon: "lightbulb", title: "Core Concept")
                                SidebarItem(id: "principles", icon: "flag", title: "Guiding Principles")
                                SidebarItem(id: "features", icon: "star", title: "Key Features")
                                SidebarItem(id: "architecture", icon: "building.2", title: "Architecture")
                            }
                            
                            Section("Progress") {
                                SidebarItem(id: "roadmap", icon: "map", title: "Implementation Roadmap")
                                SidebarItem(id: "status", icon: "chart.line.uptrend.xyaxis", title: "Current Status")
                                SidebarItem(id: "next", icon: "arrow.right.circle", title: "Next Steps")
                            }
                            
                            Section("Details") {
                                SidebarItem(id: "challenges", icon: "exclamationmark.triangle", title: "Challenges")
                                SidebarItem(id: "experience", icon: "person.2", title: "User Experience")
                                SidebarItem(id: "metrics", icon: "chart.bar", title: "Success Metrics")
                            }
                            
                            Section("Documentation") {
                                SidebarItem(id: "research", icon: "book", title: "Research")
                                SidebarItem(id: "notes", icon: "questionmark.circle", title: "Open Questions")
                                SidebarItem(id: "log", icon: "calendar", title: "Project Log")
                            }
                        }
                        
                        Section("Files") {
                            SidebarItem(id: "files", icon: "folder", title: "Project Files")
                        }
                    }
                    .listStyle(SidebarListStyle())
                    .onChange(of: selectedSection) { newSection in
                        if showFullDocument && newSection != "files" {
                            scrollToSection = newSection
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.25)
                
                Divider()
                
                // Content area - 75% of remaining space
                Group {
                    if viewModel.hasUnstructuredContent && (selectedSection == nil || selectedSection == "migrate") {
                        ScrollView {
                            UnstructuredContentView(viewModel: viewModel)
                                .padding()
                        }
                    } else if !viewModel.hasUnstructuredContent && showFullDocument && selectedSection != "files" {
                        FullDocumentView(viewModel: viewModel, scrollToSection: $scrollToSection)
                    } else if !viewModel.hasUnstructuredContent && selectedSection == "files" {
                        ScrollView {
                            ProjectFilesView(project: project)
                                .padding()
                        }
                    } else if !viewModel.hasUnstructuredContent {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                switch selectedSection {
                                // Project Info
                                case "version":
                                    OverviewSectionView(
                                        title: "Version History",
                                        content: $viewModel.projectOverview.versionHistory,
                                        onSave: viewModel.saveOverview
                                    )
                                case "concept":
                                    OverviewSectionView(
                                        title: "Core Concept",
                                        content: $viewModel.projectOverview.coreConcept,
                                        onSave: viewModel.saveOverview
                                    )
                                case "principles":
                                    OverviewSectionView(
                                        title: "Guiding Principles & Intentions",
                                        content: $viewModel.projectOverview.guidingPrinciples,
                                        onSave: viewModel.saveOverview
                                    )
                                case "features":
                                    OverviewSectionView(
                                        title: "Key Features & Functionality",
                                        content: $viewModel.projectOverview.keyFeatures,
                                        onSave: viewModel.saveOverview
                                    )
                                case "architecture":
                                    OverviewSectionView(
                                        title: "Architecture & Structure",
                                        content: $viewModel.projectOverview.architecture,
                                        onSave: viewModel.saveOverview
                                    )
                                // Progress
                                case "roadmap":
                                    OverviewSectionView(
                                        title: "Implementation Roadmap",
                                        content: $viewModel.projectOverview.implementationRoadmap,
                                        onSave: viewModel.saveOverview,
                                        isMarkdown: true
                                    )
                                case "status":
                                    OverviewSectionView(
                                        title: "Current Status & Progress",
                                        content: $viewModel.projectOverview.currentStatus,
                                        onSave: viewModel.saveOverview
                                    )
                                case "next":
                                    OverviewSectionView(
                                        title: "Next Steps",
                                        content: $viewModel.projectOverview.nextSteps,
                                        onSave: viewModel.saveOverview
                                    )
                                // Details
                                case "challenges":
                                    OverviewSectionView(
                                        title: "Challenges & Solutions",
                                        content: $viewModel.projectOverview.challenges,
                                        onSave: viewModel.saveOverview
                                    )
                                case "experience":
                                    OverviewSectionView(
                                        title: "User/Audience Experience",
                                        content: $viewModel.projectOverview.userExperience,
                                        onSave: viewModel.saveOverview
                                    )
                                case "metrics":
                                    OverviewSectionView(
                                        title: "Success Metrics",
                                        content: $viewModel.projectOverview.successMetrics,
                                        onSave: viewModel.saveOverview
                                    )
                                // Documentation
                                case "research":
                                    OverviewSectionView(
                                        title: "Research & References",
                                        content: $viewModel.projectOverview.research,
                                        onSave: viewModel.saveOverview
                                    )
                                case "notes":
                                    OverviewSectionView(
                                        title: "Open Questions & Considerations",
                                        content: $viewModel.projectOverview.openQuestions,
                                        onSave: viewModel.saveOverview
                                    )
                                case "log":
                                    OverviewSectionView(
                                        title: "Project Log",
                                        content: $viewModel.projectOverview.projectLog,
                                        onSave: viewModel.saveOverview,
                                        isMarkdown: true
                                    )
                                default:
                                    EmptyView()
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
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
            if hasUnstructured {
                selectedSection = "migrate"
            }
            // For structured content, leave selection as nil to show full document
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
    var isMarkdown: Bool = false
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
                } else if isMarkdown {
                    ScrollView {
                        MarkdownTextView(markdown: content) { lineIndex, isChecked in
                            handleCheckboxToggle(lineIndex: lineIndex, isChecked: isChecked)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text(content)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private func handleCheckboxToggle(lineIndex: Int, isChecked: Bool) {
        // Update the content with toggled checkbox
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard lineIndex < lines.count else { return }
        
        let line = String(lines[lineIndex])
        let newLine: String
        
        if line.contains("- [ ]") {
            newLine = line.replacingOccurrences(of: "- [ ]", with: "- [x]")
        } else if line.contains("- [x]") || line.contains("- [X]") {
            newLine = line.replacingOccurrences(of: "- [x]", with: "- [ ]")
                         .replacingOccurrences(of: "- [X]", with: "- [ ]")
        } else {
            newLine = line
        }
        
        lines[lineIndex] = Substring(newLine)
        content = lines.joined(separator: "\n")
        onSave()
    }
}
