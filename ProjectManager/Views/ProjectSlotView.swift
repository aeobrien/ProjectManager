import SwiftUI
import ProjectManagerCore

struct ProjectSlotView: View {
    let slot: ProjectManagerCore.ProjectSlot
    let slotNumber: Int
    @ObservedObject var focusManager: FocusManager
    @ObservedObject var projectsManager: ProjectsManager
    let onEditTags: () -> Void
    
    var occupiedProject: FocusedProject? {
        guard let projectId = slot.occupiedBy else { return nil }
        return focusManager.focusedProjects.first { $0.projectId == projectId }
    }
    
    var projectName: String {
        guard let project = occupiedProject,
              let proj = focusManager.getProject(for: project) else {
            return "Empty"
        }
        return proj.name
    }
    
    var incompleteTaskCount: Int {
        guard let projectId = slot.occupiedBy else { return 0 }
        return focusManager.getIncompleteTaskCount(for: projectId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Slot \(slotNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !slot.requiredTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(slot.requiredTags).sorted(), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Text("No requirements")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Configure") {
                    onEditTags()
                }
                .font(.caption)
            }
            
            HStack {
                if let _ = occupiedProject {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(projectName)
                            .font(.headline)
                        Text("\(incompleteTaskCount) incomplete tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Deactivate") {
                        if let project = occupiedProject {
                            focusManager.deactivateProject(project)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                } else {
                    Text("Empty slot")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                    
                    Spacer()
                    
                    if !slot.requiredTags.isEmpty {
                        Text("Waiting for project with matching tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(slot.isEmpty ? Color.secondary.opacity(0.1) : Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct AvailableProjectRowView: View {
    let project: FocusedProject
    @ObservedObject var focusManager: FocusManager
    @ObservedObject var projectsManager: ProjectsManager
    
    var projectName: String {
        focusManager.getProject(for: project)?.name ?? "Unknown Project"
    }
    
    var projectTags: Set<String> {
        guard let proj = focusManager.getProject(for: project) else { return [] }
        let viewModel = OverviewEditorViewModel(project: proj)
        viewModel.loadOverview()
        let tags = Set(projectsManager.tagManager.extractTags(from: viewModel.projectOverview.tags))
        print("Project \(projectName) has tags: \(tags)")
        return tags
    }
    
    var availableSlots: [ProjectManagerCore.ProjectSlot] {
        focusManager.getAvailableSlots(for: projectTags)
    }
    
    var incompleteTaskCount: Int {
        focusManager.getIncompleteTaskCount(for: project.projectId)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(projectName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("(\(incompleteTaskCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !projectTags.isEmpty {
                        ForEach(Array(projectTags).sorted(), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Spacer()
            
            if availableSlots.isEmpty {
                Text("No matching slots")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if availableSlots.count == 1 {
                Button("Activate") {
                    focusManager.activateProject(project, inSlot: availableSlots[0].id)
                }
                .font(.caption)
                .foregroundColor(.blue)
            } else {
                Menu("Activate in...") {
                    ForEach(Array(focusManager.projectSlots.enumerated()), id: \.element.id) { index, slot in
                        if availableSlots.contains(where: { $0.id == slot.id }) {
                            Button("Slot \(index + 1)") {
                                focusManager.activateProject(project, inSlot: slot.id)
                            }
                        }
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .cornerRadius(4)
    }
}

struct SlotTagEditor: View {
    let slot: ProjectManagerCore.ProjectSlot
    @ObservedObject var tagManager: TagManager
    let onSave: (Set<String>) -> Void
    @State private var selectedTags: Set<String>
    @Environment(\.dismiss) private var dismiss
    
    init(slot: ProjectManagerCore.ProjectSlot, tagManager: TagManager, onSave: @escaping (Set<String>) -> Void) {
        self.slot = slot
        self.tagManager = tagManager
        self.onSave = onSave
        self._selectedTags = State(initialValue: slot.requiredTags)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Configure Slot Requirements")
                .font(.headline)
            
            Text("Select tags that projects must have to occupy this slot. Projects need at least ONE of the selected tags.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if tagManager.allTags.isEmpty {
                        Text("No tags available. Create tags in your projects first.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(Array(tagManager.allTags).sorted(), id: \.self) { tag in
                                TagSelectionChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Clear All") {
                    selectedTags.removeAll()
                }
                .disabled(selectedTags.isEmpty)
                
                Button("Save") {
                    onSave(selectedTags)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}