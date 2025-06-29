//
//  ProjectManagerApp.swift
//  ProjectManager
//
//  Created by Aidan O'Brien on 14/06/2025.
//

import SwiftUI
import Combine

@main
struct ProjectManagerApp: App {
    @StateObject private var projectsManager = ProjectsManager()
    @StateObject private var focusManager = FocusManager()
    
    var body: some Scene {
        WindowGroup {
            ProjectsOverviewView()
                .environmentObject(projectsManager)
                .environmentObject(focusManager)
                .frame(minWidth: 1200, minHeight: 700)
                .onAppear {
                    // Connect the managers and sync projects
                    focusManager.syncWithProjects(projectsManager.projects)
                    
                    // Watch for project changes
                    projectsManager.$projects
                        .sink { projects in
                            focusManager.syncWithProjects(projects)
                        }
                        .store(in: &focusManager.cancellables)
                }
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
