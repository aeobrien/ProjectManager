//
//  ProjectManagerApp.swift
//  ProjectManager
//
//  Created by Aidan O'Brien on 14/06/2025.
//

import SwiftUI

@main
struct ProjectManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ProjectsListView()
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
