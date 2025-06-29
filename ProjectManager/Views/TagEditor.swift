import SwiftUI

struct TagEditor: View {
    @Binding var tags: [String]
    @ObservedObject var tagManager: TagManager
    @State private var showingTagPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    showingTagPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
            }
            
            if tags.isEmpty {
                Text("No tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                FlowLayout(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(tag: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPicker(selectedTags: $tags, tagManager: tagManager)
        }
    }
}

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
            
            Button(action: onRemove) {
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

struct TagPicker: View {
    @Binding var selectedTags: [String]
    @ObservedObject var tagManager: TagManager
    @State private var newTagName = ""
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    var filteredTags: [String] {
        let allTagsArray = Array(tagManager.allTags).sorted()
        if searchText.isEmpty {
            return allTagsArray
        }
        return allTagsArray.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Tags")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            // Search and Add New
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tags...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                HStack {
                    TextField("Create new tag...", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            createNewTag()
                        }
                    
                    Button("Create") {
                        createNewTag()
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            
            Divider()
            
            // Existing Tags
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if filteredTags.isEmpty && !searchText.isEmpty {
                        Text("No tags found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(filteredTags, id: \.self) { tag in
                                TagSelectionChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.removeAll { $0 == tag }
                                    } else {
                                        selectedTags.append(tag)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
    
    private func createNewTag() {
        let cleanTag = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTag.isEmpty {
            tagManager.addTag(cleanTag)
            if !selectedTags.contains(cleanTag) {
                selectedTags.append(cleanTag)
            }
            newTagName = ""
        }
    }
}

struct TagSelectionChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
                Text("#\(tag)")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX,
                                     y: result.positions[index].y + bounds.minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                maxX = max(maxX, currentX)
            }
            
            self.size = CGSize(width: maxX - spacing, height: currentY + lineHeight)
        }
    }
}