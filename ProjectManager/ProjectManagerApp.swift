//
//  ProjectManagerApp.swift
//  ProjectManager
//
//  Created by Aidan O'Brien on 14/06/2025.
//

import SwiftUI

@main
struct ProjectManagerApp: App {
    @StateObject private var projectsManager = ProjectsManager()
    
    var body: some Scene {
        WindowGroup {
            ProjectsOverviewView()
                .environmentObject(projectsManager)
                .frame(minWidth: 1200, minHeight: 700)
        }
        .commands {
            SidebarCommands()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1400, height: 800)
        
        Settings {
            PreferencesView()
        }
    }
}
