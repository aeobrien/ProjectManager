import SwiftUI

struct ProjectFilesView: View {
    let project: Project
    @State private var files: [FileItem] = []
    @State private var selectedFile: FileItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Files")
                .font(.title2)
                .fontWeight(.semibold)
            
            if files.isEmpty {
                ContentUnavailableView {
                    Label("No Files", systemImage: "doc")
                } description: {
                    Text("This project doesn't contain any files yet.")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // File list with dynamic height
                    List(files, children: \.children) { file in
                        FileRowView(file: file, selectedFile: $selectedFile)
                    }
                    .listStyle(.plain)
                    .frame(height: CGFloat(min(files.count, 6)) * 28) // Dynamic height, max 6 items
                    .background(Color.clear)
                    
                    // File content viewer
                    if let selectedFile = selectedFile, !selectedFile.isDirectory {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Preview: \(selectedFile.name)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Open in Finder") {
                                    NSWorkspace.shared.selectFile(selectedFile.url.path, inFileViewerRootedAtPath: selectedFile.url.deletingLastPathComponent().path)
                                }
                                .font(.caption)
                            }
                            
                            Divider()
                            
                            ScrollView {
                                FileContentView(file: selectedFile)
                            }
                            .frame(maxHeight: 300)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadFiles()
        }
    }
    
    private func loadFiles() {
        files = scanDirectory(at: project.folderPath)
    }
    
    private func scanDirectory(at url: URL) -> [FileItem] {
        var items: [FileItem] = []
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for itemURL in contents {
                // Skip the project overview file
                if itemURL.lastPathComponent == "\(project.name).md" {
                    continue
                }
                
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDirectory)
                
                let fileItem = FileItem(
                    url: itemURL,
                    isDirectory: isDirectory.boolValue,
                    children: isDirectory.boolValue ? scanDirectory(at: itemURL) : nil
                )
                
                items.append(fileItem)
            }
            
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            print("Error scanning directory \(url.path): \(error)")
        }
        
        return items
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    let children: [FileItem]?
    
    var name: String {
        url.lastPathComponent
    }
    
    var icon: String {
        if isDirectory {
            return "folder.fill"
        }
        
        switch url.pathExtension.lowercased() {
        case "md", "markdown":
            return "doc.text"
        case "txt":
            return "doc.plaintext"
        case "swift":
            return "swift"
        case "json":
            return "doc.badge.gearshape"
        case "png", "jpg", "jpeg", "gif":
            return "photo"
        case "pdf":
            return "doc.richtext"
        default:
            return "doc"
        }
    }
}

struct FileRowView: View {
    let file: FileItem
    @Binding var selectedFile: FileItem?
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Image(systemName: file.icon)
                .foregroundColor(file.isDirectory ? .accentColor : .secondary)
                .font(.callout)
            
            Text(file.name)
                .lineLimit(1)
            
            Spacer()
            
            if !file.isDirectory && isHovering {
                Button(action: { openFile() }) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Open in Finder")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .background(selectedFile?.id == file.id ? Color.accentColor.opacity(0.2) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if !file.isDirectory {
                selectedFile = file
            }
        }
        .onTapGesture(count: 2) {
            if !file.isDirectory {
                openFile()
            }
        }
    }
    
    private func openFile() {
        NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
    }
}

struct FileContentView: View {
    let file: FileItem
    @State private var content: String = ""
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if content.isEmpty {
                Text("Unable to load file content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                if file.url.pathExtension.lowercased() == "md" || file.url.pathExtension.lowercased() == "markdown" {
                    MarkdownTextView(markdown: content) { _, _ in }
                        .padding()
                } else {
                    ScrollView {
                        Text(content)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            loadContent()
        }
        .onChange(of: file) { _ in
            loadContent()
        }
    }
    
    private func loadContent() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileContent = try String(contentsOf: file.url, encoding: .utf8)
                DispatchQueue.main.async {
                    self.content = fileContent
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.content = ""
                    self.isLoading = false
                }
            }
        }
    }
}