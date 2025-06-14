import Foundation

struct Project: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let folderPath: URL
    var overviewPath: URL {
        folderPath.appendingPathComponent("\(name).md")
    }
    var hasOverview: Bool {
        FileManager.default.fileExists(atPath: overviewPath.path)
    }
    
    init(folderPath: URL) {
        self.folderPath = folderPath
        self.name = folderPath.lastPathComponent
    }
}