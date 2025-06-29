import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @StateObject private var cloudKitViewModel = CloudKitViewModel()
    @State private var obsidianPath = ""
    @State private var showingDropboxAuth = false
    @State private var showingCloudKitStatus = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Sync Settings") {
                    HStack {
                        Label("CloudKit", systemImage: "icloud")
                        Spacer()
                        cloudKitStatusView
                    }
                    
                    if cloudKitViewModel.syncStatus != "Not Signed In" {
                        Button(action: {
                            Task {
                                await cloudKitViewModel.syncNow()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync Now")
                            }
                        }
                        .disabled(cloudKitViewModel.isSyncing)
                    }
                    
                    Button(action: {
                        showingDropboxAuth = true
                    }) {
                        HStack {
                            Label("Dropbox", systemImage: "tray.full")
                            Spacer()
                            Text("Not Connected")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
                
                Section("Obsidian Vault") {
                    TextField("Vault Path", text: $obsidianPath)
                        .autocorrectionDisabled()
                    
                    Text("Enter the path to your Obsidian vault in Dropbox")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Preferences") {
                    Toggle("Enable Notifications", isOn: .constant(true))
                    Toggle("Background Sync", isOn: .constant(true))
                    
                    Picker("Sync Frequency", selection: .constant("15 minutes")) {
                        Text("5 minutes").tag("5 minutes")
                        Text("15 minutes").tag("15 minutes")
                        Text("30 minutes").tag("30 minutes")
                        Text("Hourly").tag("Hourly")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingDropboxAuth) {
            DropboxAuthView()
        }
    }
    
    private var cloudKitStatusView: some View {
        Group {
            switch cloudKitViewModel.syncStatus {
            case "Synced":
                HStack(spacing: 4) {
                    if let lastSync = cloudKitViewModel.lastSyncDate {
                        Text("Synced")
                            .foregroundColor(.green)
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Connected")
                            .foregroundColor(.green)
                    }
                }
                .font(.caption)
            case "Syncing":
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Syncing...")
                        .foregroundColor(.orange)
                }
                .font(.caption)
            case "Not Signed In":
                Text("Not Signed In")
                    .foregroundColor(.orange)
                    .font(.caption)
            case let status where status.starts(with: "Error"):
                Text("Error")
                    .foregroundColor(.red)
                    .font(.caption)
            default:
                Text(cloudKitViewModel.syncStatus)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}

struct DropboxAuthView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "tray.full")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Connect to Dropbox")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("ProjectManager needs access to your Dropbox to sync with your Obsidian vault")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Connect Dropbox") {
                    // Implement Dropbox OAuth flow
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}