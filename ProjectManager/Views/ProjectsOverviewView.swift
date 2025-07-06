import SwiftUI
import ProjectManagerCore

struct ProjectsOverviewView: View {
    @EnvironmentObject var projectsManager: ProjectsManager
    @State private var searchText = ""
    @State private var showOnlyMissingFields = false
    @State private var selectedSearchFields: Set<SearchField> = [.name, .coreConcept]
    @State private var showSearchOptions = false
    @State private var editingProjects: Set<UUID> = []
    @State private var showingNewProjectForm = false
    @State private var showingProjectsList = false
    @State private var showingFocusBoard = false
    @State private var selectedProject: Project?
    @State private var projectToRename: Project?
    
    var filteredProjects: [Project] {
        let projects = showOnlyMissingFields
            ? projectsManager.projects.filter { project in
                let vm = OverviewEditorViewModel(project: project)
                return vm.projectOverview.currentStatus.isEmpty || vm.projectOverview.nextSteps.isEmpty
            }
            : projectsManager.projects
        
        if searchText.isEmpty {
            return projects
        } else {
            return projects.filter { project in
                searchInProject(project, searchText: searchText, fields: selectedSearchFields)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Projects Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Toggle("Show only missing fields", isOn: $showOnlyMissingFields)
                        .toggleStyle(.checkbox)
                    
                    Button("Migrate Status") {
                        migrateExistingStatusToLog()
                    }
                    .help("Migrate existing current status entries to project logs")
                    
                    Button(action: { showingFocusBoard = true }) {
                        Label("Focus Board", systemImage: "square.3.stack.3d")
                    }
                    
                    Button(action: { showingProjectsList = true }) {
                        Label("Projects List", systemImage: "folder")
                    }
                    
                    Button(action: { showingNewProjectForm = true }) {
                        Label("New Project", systemImage: "plus")
                    }
                }
                
                // Search bar
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search projects...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        Button(action: { showSearchOptions.toggle() }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Search options")
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    if showSearchOptions {
                        SearchFieldSelector(selectedFields: $selectedSearchFields)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Column Headers
            HStack(spacing: 16) {
                Text("Project / Core Concept")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxWidth: .infinity * 0.4)
                    .padding(.leading, 16)
                
                Text("Current Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 400, alignment: .leading)
                
                Text("Next Steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 350, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Projects List
            if filteredProjects.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "No Projects" : "No Results", 
                          systemImage: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                } description: {
                    Text(searchText.isEmpty ? "Create your first project to get started" : "No projects match your search")
                } actions: {
                    if searchText.isEmpty {
                        Button("New Project") {
                            showingNewProjectForm = true
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredProjects) { project in
                            ProjectOverviewRow(
                                project: project,
                                isEditing: editingProjects.contains(project.id),
                                onToggleEdit: {
                                    if editingProjects.contains(project.id) {
                                        editingProjects.remove(project.id)
                                    } else {
                                        editingProjects.insert(project.id)
                                    }
                                }
                            )
                            .contextMenu {
                                Button("Open in Projects List") {
                                    selectedProject = project
                                    showingProjectsList = true
                                }
                                Divider()
                                Button("Rename") {
                                    projectToRename = project
                                }
                                Button("Ignore Project") {
                                    ignoreProject(project)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    deleteProject(project)
                                }
                            }
                            
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 600)
        .sheet(isPresented: $showingNewProjectForm) {
            NewProjectForm(projectsManager: projectsManager)
        }
        .sheet(isPresented: $showingProjectsList) {
            ProjectsListView()
                .environmentObject(projectsManager)
                .frame(minWidth: 1200, minHeight: 700)
                .onAppear {
                    if let selected = selectedProject {
                        projectsManager.selectedProject = selected
                    }
                }
        }
        .sheet(isPresented: $showingFocusBoard, onDismiss: {
            // Force reload projects when Focus Board is closed
            // This ensures task completion status is reflected
            projectsManager.loadProjects()
        }) {
            FocusBoardView()
                .environmentObject(projectsManager)
                .frame(minWidth: 1200, minHeight: 700)
        }
        .sheet(item: $projectToRename) { project in
            RenameProjectSheet(project: project, projectsManager: projectsManager)
        }
    }
    
    private func ignoreProject(_ project: Project) {
        PreferencesManager.shared.addIgnoredFolder(project.name)
        projectsManager.loadProjects()
    }
    
    private func deleteProject(_ project: Project) {
        do {
            try projectsManager.deleteProject(project)
        } catch {
            print("Error deleting project: \(error)")
        }
    }
    
    private func migrateExistingStatusToLog() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let today = dateFormatter.string(from: Date())
        
        for project in projectsManager.projects {
            let viewModel = OverviewEditorViewModel(project: project)
            viewModel.loadOverview()
            
            // Check if there's a current status that's not already in the log
            if !viewModel.projectOverview.currentStatus.isEmpty {
                let newEntry = "### \(today)\n\(viewModel.projectOverview.currentStatus)"
                
                if viewModel.projectOverview.projectLog.isEmpty {
                    viewModel.projectOverview.projectLog = newEntry
                } else {
                    // Only add if the current status isn't already at the top of the log
                    let logEntries = parseLogEntries(viewModel.projectOverview.projectLog, for: project)
                    if logEntries.isEmpty || logEntries.first?.content != viewModel.projectOverview.currentStatus {
                        viewModel.projectOverview.projectLog = newEntry + "\n\n" + viewModel.projectOverview.projectLog
                    }
                }
                
                // Clear the current status field since it's now in the log
                viewModel.projectOverview.currentStatus = ""
                viewModel.saveOverview()
            }
        }
    }
    
    private func parseLogEntries(_ log: String, for project: Project) -> [(date: String, content: String)] {
        let lines = log.split(separator: "\n", omittingEmptySubsequences: false)
        var entries: [(date: String, content: String)] = []
        var currentDate = ""
        var currentContent: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") {
                // Save previous entry if exists
                if !currentDate.isEmpty && !currentContent.isEmpty {
                    entries.append((date: currentDate, content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)))
                }
                // Start new entry
                currentDate = String(trimmed.dropFirst(4))
                currentContent = []
            } else if !trimmed.isEmpty {
                currentContent.append(String(line))
            }
        }
        
        // Add last entry
        if !currentDate.isEmpty && !currentContent.isEmpty {
            entries.append((date: currentDate, content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)))
        }
        
        return entries // Keep original order - first entry is most recent
    }
    
    private func searchInProject(_ project: Project, searchText: String, fields: Set<SearchField>) -> Bool {
        let vm = OverviewEditorViewModel(project: project)
        vm.loadOverview()
        
        for field in fields {
            let content: String
            switch field {
            case .name:
                content = project.name
            case .coreConcept:
                content = vm.projectOverview.coreConcept
            case .versionHistory:
                content = vm.projectOverview.versionHistory
            case .guidingPrinciples:
                content = vm.projectOverview.guidingPrinciples
            case .keyFeatures:
                content = vm.projectOverview.keyFeatures
            case .architecture:
                content = vm.projectOverview.architecture
            case .implementationRoadmap:
                content = vm.projectOverview.implementationRoadmap
            case .currentStatus:
                content = vm.projectOverview.currentStatus
            case .nextSteps:
                content = vm.projectOverview.nextSteps
            case .challenges:
                content = vm.projectOverview.challenges
            case .userExperience:
                content = vm.projectOverview.userExperience
            case .successMetrics:
                content = vm.projectOverview.successMetrics
            case .research:
                content = vm.projectOverview.research
            case .openQuestions:
                content = vm.projectOverview.openQuestions
            case .projectLog:
                content = vm.projectOverview.projectLog
            case .externalFiles:
                content = vm.projectOverview.externalFiles
            case .repositories:
                content = vm.projectOverview.repositories
            }
            
            if content.localizedCaseInsensitiveContains(searchText) {
                return true
            }
        }
        
        return false
    }
}

struct ProjectOverviewRow: View {
    let project: Project
    let isEditing: Bool
    let onToggleEdit: () -> Void
    @StateObject private var viewModel: OverviewEditorViewModel
    @EnvironmentObject var projectsManager: ProjectsManager
    @State private var editedStatus: String = ""
    @State private var editedNextSteps: String = ""
    @State private var showAddStatusDialog = false
    @State private var showAddNextStepDialog = false
    @State private var showEditStatusDialog = false
    @State private var showEditNextStepsDialog = false
    @State private var newStatusText = ""
    @State private var newNextStepText = ""
    @State private var editStatusText = ""
    @State private var editNextStepsText = ""
    @State private var projectTags: [String] = []
    
    init(project: Project, isEditing: Bool, onToggleEdit: @escaping () -> Void) {
        self.project = project
        self.isEditing = isEditing
        self.onToggleEdit = onToggleEdit
        self._viewModel = StateObject(wrappedValue: OverviewEditorViewModel(project: project))
    }
    
    var hasMissingFields: Bool {
        currentStatusFromLog.isEmpty || viewModel.projectOverview.nextSteps.isEmpty
    }
    
    var currentStatusFromLog: String {
        let logEntries = parseLogEntries(viewModel.projectOverview.projectLog)
        return logEntries.first?.content ?? ""
    }
    
    private func parseLogEntries(_ log: String) -> [(date: String, content: String)] {
        let lines = log.split(separator: "\n", omittingEmptySubsequences: false)
        var entries: [(date: String, content: String)] = []
        var currentDate = ""
        var currentContent: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("### ") {
                // Save previous entry if exists
                if !currentDate.isEmpty && !currentContent.isEmpty {
                    entries.append((date: currentDate, content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)))
                }
                // Start new entry
                currentDate = String(trimmed.dropFirst(4))
                currentContent = []
            } else if !trimmed.isEmpty {
                currentContent.append(String(line))
            }
        }
        
        // Add last entry
        if !currentDate.isEmpty && !currentContent.isEmpty {
            entries.append((date: currentDate, content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespaces)))
        }
        
        return entries // Keep original order - first entry is most recent
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Project Name & Core Concept (40% of width)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if hasMissingFields {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                            .help("Missing current status or next steps")
                    }
                }
                
                if !viewModel.projectOverview.coreConcept.isEmpty {
                    MarkdownTextView(markdown: viewModel.projectOverview.coreConcept)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Tags
                TagEditor(tags: $projectTags, tagManager: projectsManager.tagManager)
                    .onChange(of: projectTags) { newTags in
                        // Save tags to overview
                        let formattedTags = projectsManager.tagManager.formatTags(newTags)
                        print("Saving tags for \(project.name): \(formattedTags)")
                        viewModel.projectOverview.tags = formattedTags
                        viewModel.saveOverview()
                        
                        // Verify it was saved
                        viewModel.loadOverview()
                        print("After save, tags are: \(viewModel.projectOverview.tags)")
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxWidth: .infinity * 0.4)
            
            // Current Status (expanded width)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if currentStatusFromLog.isEmpty {
                            Text("No status set")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .italic()
                        } else {
                            MarkdownTextView(markdown: currentStatusFromLog)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 4) {
                        Button(action: {
                            showEditStatusDialog = true
                        }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 20, height: 20)
                        .disabled(currentStatusFromLog.isEmpty)
                        
                        Button(action: {
                            showAddStatusDialog = true
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 20, height: 20)
                    }
                }
            }
            .frame(width: 400, alignment: .leading)
            
            // Next Steps
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if viewModel.projectOverview.nextSteps.isEmpty {
                            Text("No next steps defined")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                                .italic()
                        } else {
                            let filteredNextSteps = filterOutCompletedTasks(viewModel.projectOverview.nextSteps)
                            MarkdownTextView(
                                markdown: filteredNextSteps,
                                onCheckboxToggle: { lineIndex, isChecked in
                                    handleCheckboxToggleWithFiltered(lineIndex: lineIndex, isChecked: isChecked, originalText: viewModel.projectOverview.nextSteps)
                                }
                            )
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 4) {
                        Button(action: {
                            showEditNextStepsDialog = true
                        }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 20, height: 20)
                        .disabled(viewModel.projectOverview.nextSteps.isEmpty)
                        
                        Button(action: {
                            showAddNextStepDialog = true
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 20, height: 20)
                    }
                }
            }
            .frame(width: 350, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(hasMissingFields ? Color.orange.opacity(0.1) : Color.clear)
        .onAppear {
            // Always reload overview data when view appears
            // This ensures changes from Focus Board are reflected
            viewModel.loadOverview()
            editedStatus = viewModel.projectOverview.currentStatus
            editedNextSteps = viewModel.projectOverview.nextSteps
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Also reload when app becomes active (e.g., switching back from Focus Board)
            viewModel.loadOverview()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // Reload when window becomes key (e.g., after closing a sheet)
            viewModel.loadOverview()
        }
        .onChange(of: isEditing) { editing in
            if editing {
                editedStatus = viewModel.projectOverview.currentStatus
                editedNextSteps = convertToCheckboxFormat(viewModel.projectOverview.nextSteps)
            }
        }
        .sheet(isPresented: $showAddStatusDialog) {
            AddStatusDialog(
                newStatusText: $newStatusText,
                onSave: {
                    addToProjectLog(newStatusText)
                    newStatusText = ""
                    showAddStatusDialog = false
                },
                onCancel: {
                    newStatusText = ""
                    showAddStatusDialog = false
                }
            )
        }
        .sheet(isPresented: $showAddNextStepDialog) {
            AddNextStepDialog(
                newNextStepText: $newNextStepText,
                onSave: {
                    addToNextSteps(newNextStepText)
                    newNextStepText = ""
                    showAddNextStepDialog = false
                },
                onCancel: {
                    newNextStepText = ""
                    showAddNextStepDialog = false
                }
            )
        }
        .sheet(isPresented: $showEditStatusDialog) {
            EditStatusDialog(
                editStatusText: $editStatusText,
                onSave: {
                    updateLatestLogEntry(editStatusText)
                    editStatusText = ""
                    showEditStatusDialog = false
                },
                onCancel: {
                    editStatusText = ""
                    showEditStatusDialog = false
                }
            )
            .onAppear {
                editStatusText = currentStatusFromLog
            }
        }
        .sheet(isPresented: $showEditNextStepsDialog) {
            EditNextStepsDialog(
                editNextStepsText: $editNextStepsText,
                onSave: {
                    viewModel.projectOverview.nextSteps = editNextStepsText
                    viewModel.saveOverview()
                    editNextStepsText = ""
                    showEditNextStepsDialog = false
                },
                onCancel: {
                    editNextStepsText = ""
                    showEditNextStepsDialog = false
                }
            )
            .onAppear {
                editNextStepsText = viewModel.projectOverview.nextSteps
            }
        }
        .onAppear {
            // Ensure overview is loaded
            viewModel.loadOverview()
            // Load tags from overview
            projectTags = projectsManager.tagManager.extractTags(from: viewModel.projectOverview.tags)
        }
    }
    
    private func convertToCheckboxFormat(_ text: String) -> String {
        let lines = text.split(separator: "\n")
        return lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
                return String(line)
            } else if trimmed.hasPrefix("- ") {
                return "- [ ] " + trimmed.dropFirst(2)
            } else if !trimmed.isEmpty {
                return "- [ ] " + trimmed
            }
            return String(line)
        }.joined(separator: "\n")
    }
    
    private func saveChanges() {
        viewModel.projectOverview.currentStatus = editedStatus
        viewModel.projectOverview.nextSteps = editedNextSteps
        viewModel.saveOverview()
    }
    
    private func filterOutCompletedTasks(_ nextSteps: String) -> String {
        let lines = nextSteps.split(separator: "\n", omittingEmptySubsequences: false)
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Keep non-checkbox lines and uncompleted checkbox lines
            return !trimmed.hasPrefix("- [x]") && !trimmed.hasPrefix("- [X]")
        }
        return filteredLines.joined(separator: "\n")
    }
    
    private func handleCheckboxToggleWithFiltered(lineIndex: Int, isChecked: Bool, originalText: String) {
        // Get the filtered lines to find which task was toggled
        let filteredLines = filterOutCompletedTasks(originalText).split(separator: "\n", omittingEmptySubsequences: false)
        guard lineIndex < filteredLines.count else { return }
        
        let toggledLine = String(filteredLines[lineIndex])
        
        // Find this line in the original text and toggle it
        var originalLines = originalText.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in originalLines.enumerated() {
            if line == toggledLine {
                let newLine: String
                if line.contains("- [ ]") {
                    newLine = String(line).replacingOccurrences(of: "- [ ]", with: "- [x]")
                } else {
                    newLine = String(line)
                }
                originalLines[index] = Substring(newLine)
                break
            }
        }
        
        viewModel.projectOverview.nextSteps = originalLines.joined(separator: "\n")
        viewModel.saveOverview()
    }
    
    private func handleCheckboxToggle(lineIndex: Int, isChecked: Bool) {
        var lines = viewModel.projectOverview.nextSteps.split(separator: "\n", omittingEmptySubsequences: false)
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
        viewModel.projectOverview.nextSteps = lines.joined(separator: "\n")
        viewModel.saveOverview()
    }
    
    private func addToProjectLog(_ text: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        let today = dateFormatter.string(from: Date())
        
        let newEntry = "### \(today)\n\(text)"
        
        if viewModel.projectOverview.projectLog.isEmpty {
            viewModel.projectOverview.projectLog = newEntry
        } else {
            viewModel.projectOverview.projectLog = newEntry + "\n\n" + viewModel.projectOverview.projectLog
        }
        
        viewModel.saveOverview()
    }
    
    private func addToNextSteps(_ text: String) {
        let newItem = "- [ ] \(text)"
        
        if viewModel.projectOverview.nextSteps.isEmpty {
            viewModel.projectOverview.nextSteps = newItem
        } else {
            viewModel.projectOverview.nextSteps = newItem + "\n" + viewModel.projectOverview.nextSteps
        }
        
        viewModel.saveOverview()
    }
    
    private func updateLatestLogEntry(_ newText: String) {
        let logEntries = parseLogEntries(viewModel.projectOverview.projectLog)
        guard !logEntries.isEmpty else { return }
        
        // Update the first (most recent) entry
        let updatedEntry = "### \(logEntries[0].date)\n\(newText)"
        
        // Rebuild the log with the updated first entry
        var newLog = updatedEntry
        for i in 1..<logEntries.count {
            newLog += "\n\n### \(logEntries[i].date)\n\(logEntries[i].content)"
        }
        
        viewModel.projectOverview.projectLog = newLog
        viewModel.saveOverview()
    }
}

struct AddStatusDialog: View {
    @Binding var newStatusText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Status Update")
                .font(.headline)
            
            TextEditor(text: $newStatusText)
                .frame(height: 100)
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add", action: onSave)
                    .keyboardShortcut(.return)
                    .disabled(newStatusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct AddNextStepDialog: View {
    @Binding var newNextStepText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Next Step")
                .font(.headline)
            
            TextField("Enter next step...", text: $newNextStepText)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add", action: onSave)
                    .keyboardShortcut(.return)
                    .disabled(newNextStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct EditStatusDialog: View {
    @Binding var editStatusText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Current Status")
                .font(.headline)
            
            TextEditor(text: $editStatusText)
                .frame(height: 100)
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save", action: onSave)
                    .keyboardShortcut(.return)
                    .disabled(editStatusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct EditNextStepsDialog: View {
    @Binding var editNextStepsText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Next Steps")
                .font(.headline)
            
            TextEditor(text: $editNextStepsText)
                .frame(height: 150)
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save", action: onSave)
                    .keyboardShortcut(.return)
                    .disabled(editNextStepsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 250)
    }
}

enum SearchField: String, CaseIterable, Identifiable {
    case name = "Project Name"
    case coreConcept = "Core Concept"
    case versionHistory = "Version History"
    case guidingPrinciples = "Guiding Principles"
    case keyFeatures = "Key Features"
    case architecture = "Architecture"
    case implementationRoadmap = "Implementation Roadmap"
    case currentStatus = "Current Status"
    case nextSteps = "Next Steps"
    case challenges = "Challenges"
    case userExperience = "User Experience"
    case successMetrics = "Success Metrics"
    case research = "Research"
    case openQuestions = "Open Questions"
    case projectLog = "Project Log"
    case externalFiles = "External Files"
    case repositories = "Repositories"
    
    var id: String { rawValue }
}

struct SearchFieldSelector: View {
    @Binding var selectedFields: Set<SearchField>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Search in:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("All") {
                    selectedFields = Set(SearchField.allCases)
                }
                .font(.caption)
                
                Button("None") {
                    selectedFields.removeAll()
                }
                .font(.caption)
                
                Button("Default") {
                    selectedFields = [.name, .coreConcept]
                }
                .font(.caption)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 4) {
                ForEach(SearchField.allCases) { field in
                    Toggle(field.rawValue, isOn: Binding(
                        get: { selectedFields.contains(field) },
                        set: { isSelected in
                            if isSelected {
                                selectedFields.insert(field)
                            } else {
                                selectedFields.remove(field)
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}