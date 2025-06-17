import SwiftUI

struct FullDocumentView: View {
    @ObservedObject var viewModel: OverviewEditorViewModel
    @Binding var scrollToSection: String?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text(viewModel.project.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .id("title")
                    
                    // Version History
                    if !viewModel.projectOverview.versionHistory.isEmpty {
                        SectionView(
                            title: "Version History",
                            content: viewModel.projectOverview.versionHistory,
                            id: "version",
                            viewModel: viewModel
                        )
                    }
                    
                    // Core Concept
                    if !viewModel.projectOverview.coreConcept.isEmpty {
                        SectionView(
                            title: "Core Concept",
                            content: viewModel.projectOverview.coreConcept,
                            id: "concept",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Guiding Principles
                    if !viewModel.projectOverview.guidingPrinciples.isEmpty {
                        SectionView(
                            title: "Guiding Principles & Intentions",
                            content: viewModel.projectOverview.guidingPrinciples,
                            id: "principles",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Key Features
                    if !viewModel.projectOverview.keyFeatures.isEmpty {
                        SectionView(
                            title: "Key Features & Functionality",
                            content: viewModel.projectOverview.keyFeatures,
                            id: "features",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Architecture
                    if !viewModel.projectOverview.architecture.isEmpty {
                        SectionView(
                            title: "Architecture & Structure",
                            content: viewModel.projectOverview.architecture,
                            id: "architecture",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Implementation Roadmap
                    if !viewModel.projectOverview.implementationRoadmap.isEmpty {
                        SectionView(
                            title: "Implementation Roadmap",
                            content: viewModel.projectOverview.implementationRoadmap,
                            id: "roadmap",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Current Status
                    if !viewModel.projectOverview.currentStatus.isEmpty {
                        SectionView(
                            title: "Current Status & Progress",
                            content: viewModel.projectOverview.currentStatus,
                            id: "status",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Next Steps
                    if !viewModel.projectOverview.nextSteps.isEmpty {
                        SectionView(
                            title: "Next Steps",
                            content: viewModel.projectOverview.nextSteps,
                            id: "next",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Challenges
                    if !viewModel.projectOverview.challenges.isEmpty {
                        SectionView(
                            title: "Challenges & Solutions",
                            content: viewModel.projectOverview.challenges,
                            id: "challenges",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // User Experience
                    if !viewModel.projectOverview.userExperience.isEmpty {
                        SectionView(
                            title: "User/Audience Experience",
                            content: viewModel.projectOverview.userExperience,
                            id: "experience",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Success Metrics
                    if !viewModel.projectOverview.successMetrics.isEmpty {
                        SectionView(
                            title: "Success Metrics",
                            content: viewModel.projectOverview.successMetrics,
                            id: "metrics",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Research
                    if !viewModel.projectOverview.research.isEmpty {
                        SectionView(
                            title: "Research & References",
                            content: viewModel.projectOverview.research,
                            id: "research",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Open Questions & Considerations
                    if !viewModel.projectOverview.openQuestions.isEmpty {
                        SectionView(
                            title: "Open Questions & Considerations",
                            content: viewModel.projectOverview.openQuestions,
                            id: "notes",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Project Log
                    if !viewModel.projectOverview.projectLog.isEmpty {
                        SectionView(
                            title: "Project Log",
                            content: viewModel.projectOverview.projectLog,
                            id: "log",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // External Files
                    if !viewModel.projectOverview.externalFiles.isEmpty {
                        SectionView(
                            title: "External Files",
                            content: viewModel.projectOverview.externalFiles,
                            id: "external",
                            isMarkdown: true,
                            viewModel: viewModel
                        )
                    }
                    
                    // Repositories
                    if !viewModel.projectOverview.repositories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionView(
                                title: "Repositories",
                                content: viewModel.projectOverview.repositories,
                                id: "repos",
                                isMarkdown: true,
                                viewModel: viewModel
                            )
                            
                            HStack {
                                Button("Sync GitHub Commits") {
                                    viewModel.updateProjectLogWithGitHubCommits()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Spacer()
                                
                                Text("Fetches recent commits and adds them to the project log")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: scrollToSection) { section in
                if let section = section {
                    withAnimation {
                        proxy.scrollTo(section, anchor: .top)
                    }
                }
            }
        }
    }
}

struct SectionView: View {
    let title: String
    let content: String
    let id: String
    var isMarkdown: Bool = false
    @ObservedObject var viewModel: OverviewEditorViewModel
    @State private var isEditing = false
    @State private var editableContent: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title)
                    .fontWeight(.semibold)
                    .id(id)
                
                Spacer()
                
                Button(action: {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                        .foregroundColor(isEditing ? .green : .accentColor)
                }
                .buttonStyle(.plain)
                .help(isEditing ? "Save changes" : "Edit section")
            }
            
            if isEditing {
                TextEditor(text: $editableContent)
                    .font(.body)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .frame(minHeight: 150)
            } else {
                if isMarkdown {
                    MarkdownTextView(markdown: content) { lineIndex, isChecked in
                        handleCheckboxToggle(lineIndex: lineIndex, isChecked: isChecked)
                    }
                    .textSelection(.enabled)
                } else {
                    Text(content)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(12)
        .padding(.bottom, 8)
    }
    
    private func startEditing() {
        editableContent = content
        isEditing = true
    }
    
    private func saveChanges() {
        // Update the appropriate section in the view model
        updateViewModelContent(with: editableContent)
        viewModel.saveOverview()
        isEditing = false
    }
    
    private func updateViewModelContent(with newContent: String) {
        switch id {
        case "version":
            viewModel.projectOverview.versionHistory = newContent
        case "concept":
            viewModel.projectOverview.coreConcept = newContent
        case "principles":
            viewModel.projectOverview.guidingPrinciples = newContent
        case "features":
            viewModel.projectOverview.keyFeatures = newContent
        case "architecture":
            viewModel.projectOverview.architecture = newContent
        case "roadmap":
            viewModel.projectOverview.implementationRoadmap = newContent
        case "status":
            viewModel.projectOverview.currentStatus = newContent
        case "next":
            viewModel.projectOverview.nextSteps = newContent
        case "challenges":
            viewModel.projectOverview.challenges = newContent
        case "experience":
            viewModel.projectOverview.userExperience = newContent
        case "metrics":
            viewModel.projectOverview.successMetrics = newContent
        case "research":
            viewModel.projectOverview.research = newContent
        case "notes":
            viewModel.projectOverview.openQuestions = newContent
        case "log":
            viewModel.projectOverview.projectLog = newContent
        case "external":
            viewModel.projectOverview.externalFiles = newContent
        case "repos":
            viewModel.projectOverview.repositories = newContent
        default:
            break
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
        let updatedContent = lines.joined(separator: "\n")
        
        // Update the appropriate section in the view model
        switch id {
        case "roadmap":
            viewModel.projectOverview.implementationRoadmap = updatedContent
        case "next":
            viewModel.projectOverview.nextSteps = updatedContent
        case "log":
            viewModel.projectOverview.projectLog = updatedContent
        default:
            break
        }
        
        // Save the changes
        viewModel.saveOverview()
    }
}