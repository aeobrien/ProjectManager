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
                    Button("Force Sync") {
                        Task {
                            await focusManager.forceSync()
                        }
                    }
                    .foregroundColor(.orange)
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                }
            }
            
            // Insights row and filter indicators
            HStack {
                // Filter indicator will be handled by the parent view
                
                if !focusManager.staleActiveProjects.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                        Text("\(focusManager.staleActiveProjects.count) stale project(s)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if !focusManager.projectsWithNoActiveTasks.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                        Text("\(focusManager.projectsWithNoActiveTasks.count) project(s) with no tasks")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
    }
}
