import Foundation
import SwiftUI

@MainActor
class PreferencesManager: ObservableObject {
    @AppStorage("dropboxPath") var dropboxPath: String = ""
    @AppStorage("obsidianVaultPath") var obsidianVaultPath: String = ""
    @AppStorage("enableNotifications") var enableNotifications: Bool = true
    @AppStorage("backgroundSyncEnabled") var backgroundSyncEnabled: Bool = true
    @AppStorage("syncFrequency") var syncFrequency: String = "15 minutes"
    @AppStorage("useCloudKit") var useCloudKit: Bool = true
    @AppStorage("useDropbox") var useDropbox: Bool = false
    
    // GitHub settings
    @AppStorage("githubToken") var githubToken: String = ""
    @AppStorage("githubUsername") var githubUsername: String = ""
    
    // Focus board settings
    @AppStorage("maxActiveProjects") var maxActiveProjects: Int = 5
    @AppStorage("minActiveProjects") var minActiveProjects: Int = 3
    
    var isDropboxConfigured: Bool {
        !dropboxPath.isEmpty && !obsidianVaultPath.isEmpty
    }
    
    var isGitHubConfigured: Bool {
        !githubToken.isEmpty
    }
    
    func resetSettings() {
        dropboxPath = ""
        obsidianVaultPath = ""
        githubToken = ""
        githubUsername = ""
    }
}