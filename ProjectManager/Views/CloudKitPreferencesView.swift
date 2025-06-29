import SwiftUI

struct CloudKitPreferencesView: View {
    @StateObject private var viewModel = CloudKitViewModel()
    @State private var showingManualSync = false
    @State private var syncError: String?
    
    var body: some View {
        Form {
            // Status Section
            Section {
                HStack {
                    Text("iCloud Status")
                    Spacer()
                    statusView
                }
                
                if let lastSync = viewModel.lastSyncDate {
                    HStack {
                        Text("Last Synced")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Sync Actions
            Section {
                Button("Sync Now") {
                    syncNow()
                }
                .disabled(viewModel.isSyncing)
                
                if showingManualSync {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.vertical, 4)
                }
            }
            
            // Error Display
            if let error = syncError {
                Section("Sync Error") {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // Sync Info
            Section("About CloudKit Sync") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CloudKit automatically syncs your projects, tasks, and focus status across all your devices signed in with the same Apple ID.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Data synced includes:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Project metadata", systemImage: "folder")
                        Label("Focus status and priority", systemImage: "star")
                        Label("Tasks and completion status", systemImage: "checklist")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
    
    private var statusView: some View {
        Group {
            switch viewModel.syncStatus {
            case "Synced":
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Connected")
                        .foregroundColor(.green)
                }
            case "Syncing":
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing...")
                        .foregroundColor(.orange)
                }
            case "Not Signed In":
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Not Signed In")
                        .foregroundColor(.orange)
                }
            case let status where status.starts(with: "Error"):
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Error")
                        .foregroundColor(.red)
                }
                .help(status)
            default:
                Text(viewModel.syncStatus)
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
    }
    
    private func syncNow() {
        showingManualSync = true
        syncError = nil
        
        Task {
            do {
                if #available(macOS 10.15, *) {
                    try await viewModel.syncNow()
                }
                
                await MainActor.run {
                    showingManualSync = false
                }
            } catch {
                await MainActor.run {
                    showingManualSync = false
                    syncError = error.localizedDescription
                }
            }
        }
    }
}
