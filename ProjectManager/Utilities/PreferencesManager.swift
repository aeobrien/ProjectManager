import Foundation

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @Published var projectsFolder: URL? {
        didSet {
            if oldValue != projectsFolder {
                saveBookmark()
            }
        }
    }
    
    @Published var sortOption: SortOption = .name {
        didSet {
            UserDefaults.standard.set(sortOption.rawValue, forKey: "sortOption")
        }
    }
    
    @Published var ignoredFolders: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(ignoredFolders), forKey: "ignoredFolders")
        }
    }
    
    private init() {
        loadBookmark()
        
        if let rawValue = UserDefaults.standard.string(forKey: "sortOption"),
           let option = SortOption(rawValue: rawValue) {
            self.sortOption = option
        }
        
        if let ignoredArray = UserDefaults.standard.array(forKey: "ignoredFolders") as? [String] {
            self.ignoredFolders = Set(ignoredArray)
        }
    }
    
    private func saveBookmark() {
        guard let folder = projectsFolder else {
            UserDefaults.standard.removeObject(forKey: "projectsFolderBookmark")
            return
        }
        
        do {
            let bookmarkData = try folder.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "projectsFolderBookmark")
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }
    
    private func loadBookmark() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "projectsFolderBookmark") else {
            return
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("Bookmark is stale, need to re-select folder")
                return
            }
            
            if url.startAccessingSecurityScopedResource() {
                self.projectsFolder = url
            }
        } catch {
            print("Failed to resolve bookmark: \(error)")
        }
    }
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case dateModified = "Date Modified"
        case dateCreated = "Date Created"
    }
    
    // MARK: - Ignored Folders Management
    
    func addIgnoredFolder(_ folderName: String) {
        ignoredFolders.insert(folderName)
    }
    
    func removeIgnoredFolder(_ folderName: String) {
        ignoredFolders.remove(folderName)
    }
    
    func isIgnored(_ folderName: String) -> Bool {
        ignoredFolders.contains(folderName)
    }
    
    func clearIgnoredFolders() {
        ignoredFolders.removeAll()
    }
}