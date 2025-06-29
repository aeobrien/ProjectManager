import SwiftUI

@main
struct ProjectManagerApp: App {
    @StateObject private var projectsManager = ProjectsManager()
    @StateObject private var preferencesManager = PreferencesManager()
    @StateObject private var focusManager = FocusManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectsManager)
                .environmentObject(preferencesManager)
                .environmentObject(focusManager)
                .onAppear {
                    // Connect the managers
                    projectsManager.focusManager = focusManager
                }
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProjectsListView()
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }
                .tag(0)
            
            FocusBoardTabView()
                .tabItem {
                    Label("Focus", systemImage: "target")
                }
                .tag(1)
            
            OverviewTabView()
                .tabItem {
                    Label("Overview", systemImage: "doc.text")
                }
                .tag(2)
            
            GitHubTabView()
                .tabItem {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}