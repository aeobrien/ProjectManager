import SwiftUI
import ProjectManagerCore

struct TagFilterView: View {
    @ObservedObject var tagManager: TagManager
    @ObservedObject var focusManager: FocusManager
    @Binding var selectedTagsForFilter: Set<String>
    @State private var showingTagPicker = false
    
    var availableTags: [String] {
        // Get all tags from active projects
        var tags = Set<String>()
        for project in focusManager.activeProjects {
            if let proj = focusManager.getProject(for: project) {
                let viewModel = OverviewEditorViewModel(project: proj)
                viewModel.loadOverview()
                let projectTags = tagManager.extractTags(from: viewModel.projectOverview.tags)
                tags.formUnion(projectTags)
            }
        }
        return Array(tags).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !availableTags.isEmpty {
                HStack {
                    Menu {
                        ForEach(availableTags, id: \.self) { tag in
                            Button {
                                if selectedTagsForFilter.contains(tag) {
                                    selectedTagsForFilter.remove(tag)
                                } else {
                                    selectedTagsForFilter.insert(tag)
                                }
                            } label: {
                                HStack {
                                    Text("#\(tag)")
                                    if selectedTagsForFilter.contains(tag) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        if !selectedTagsForFilter.isEmpty {
                            Divider()
                            Button("Clear All") {
                                selectedTagsForFilter.removeAll()
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill")
                                .font(.caption)
                            
                            if selectedTagsForFilter.isEmpty {
                                Text("Filter by Tags")
                                    .font(.caption)
                            } else {
                                Text("\(selectedTagsForFilter.count) tag\(selectedTagsForFilter.count == 1 ? "" : "s") selected")
                                    .font(.caption)
                            }
                            
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTagsForFilter.isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.2))
                        .foregroundColor(selectedTagsForFilter.isEmpty ? .primary : .accentColor)
                        .cornerRadius(15)
                    }
                    
                    // Show selected tags
                    if !selectedTagsForFilter.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(selectedTagsForFilter).sorted(), id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text("#\(tag)")
                                            .font(.caption)
                                        
                                        Button {
                                            selectedTagsForFilter.remove(tag)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
            } else {
                // Show message when no tags available
                HStack {
                    Text("No tags available - add tags to active projects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                Divider()
            }
        }
    }
}
