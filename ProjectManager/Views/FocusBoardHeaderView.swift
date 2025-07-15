import SwiftUI
import ProjectManagerCore

struct FocusBoardHeaderView: View {
    @ObservedObject var focusManager: FocusManager
    @Binding var showingProjectSelector: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Focus Board")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Active project count and warnings
                HStack {
                    if focusManager.isOverActiveLimit {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("\(focusManager.activeProjects.count) active projects (max \(focusManager.maxActive))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    } else if focusManager.isUnderActiveMinimum {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("\(focusManager.activeProjects.count) active projects (min \(focusManager.minActive) recommended)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    } else {
                        Text("\(focusManager.activeProjects.count) active projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button("Add Task") {
                    focusManager.showAddTaskDialog = true
                }
                .disabled(focusManager.activeProjects.isEmpty)
                
                Button("Manage Projects") {
                    showingProjectSelector = true
                }
                
                Button("Refresh") {
                    // This action will be handled by the parent view
                }
                
                // Force sync button for testing
                if focusManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Menu {
                        Button("Force Sync") {
                            Task {
                                await focusManager.forceSync()
                            }
                        }
                        .keyboardShortcut("f", modifiers: [.command, .shift])
                        
                        Button("Force Push Active Projects") {
                            Task {
                                await focusManager.forcePushActiveProjects()
                            }
                        }
                        
                        Button("Force Sync All Projects") {
                            Task {
                                await focusManager.forceSyncAllProjects()
                            }
                        }
                        
                        Divider()
                        
                        Button("Clean Up Project Duplicates") {
                            Task {
                                await focusManager.cleanupCloudKitDuplicates()
                            }
                        }
                        
                        Button("Clean Up Active Project Tasks") {
                            Task {
                                await focusManager.cleanupActiveProjectTasks()
                            }
                        }
                        
                        Button("Clean Up All Task Duplicates") {
                            Task {
                                await focusManager.cleanupTaskDuplicates()
                            }
                        }
                        
                        if !focusManager.syncStatus.isEmpty {
                            Divider()
                            Text("Status: \(focusManager.syncStatus)")
                                .font(.caption)
                        }
                    } label: {
                        Label("Sync", systemImage: "arrow.clockwise.icloud")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Insights row and filter indicators
            HStack {
                // Filter indicator will be handled by the parent view
                
                if !focusManager.staleActiveProjects.isEmpty {
                    Menu {
                        ForEach(focusManager.staleActiveProjects) { project in
                            if let proj = focusManager.getProject(for: project) {
                                Label(proj.name, systemImage: "clock")
                                    .foregroundColor(.orange)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("\(focusManager.staleActiveProjects.count) stale project(s)")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .menuStyle(.borderlessButton)
                }
                
                if !focusManager.projectsWithNoActiveTasks.isEmpty {
                    Menu {
                        ForEach(focusManager.projectsWithNoActiveTasks) { project in
                            if let proj = focusManager.getProject(for: project) {
                                Label(proj.name, systemImage: "checkmark.circle")
                                    .foregroundColor(.green)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("\(focusManager.projectsWithNoActiveTasks.count) project(s) with no tasks")
                                .font(.caption)
                                .foregroundColor(.green)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .menuStyle(.borderlessButton)
                }
                
                Spacer()
            }
        }
        .padding()
    }
}
