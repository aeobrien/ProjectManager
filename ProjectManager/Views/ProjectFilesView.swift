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
                List(files, children: \.children) { file in
                    FileRowView(file: file, selectedFile: $selectedFile)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
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
            print("Error scanning directory: \(error)")
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
        .onHover { hovering in
            isHovering = hovering
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