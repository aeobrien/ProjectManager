import SwiftUI

struct PreferencesView: View {
    @StateObject private var preferencesManager = PreferencesManager.shared
    @State private var showingFolderPicker = false
    
    var body: some View {
        TabView {
            GeneralPreferencesView(
                preferencesManager: preferencesManager,
                showingFolderPicker: $showingFolderPicker
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            IgnoredFoldersView(preferencesManager: preferencesManager)
            .tabItem {
                Label("Ignored Folders", systemImage: "eye.slash")
            }
            
            AppearancePreferencesView()
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
            
            GitHubPreferencesView()
            .tabItem {
                Label("GitHub", systemImage: "cloud")
            }
        }
        .frame(width: 550, height: 450)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    preferencesManager.projectsFolder = url
                }
            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
    }
}

struct GeneralPreferencesView: View {
    @ObservedObject var preferencesManager: PreferencesManager
    @Binding var showingFolderPicker: Bool
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Projects Folder:")
                        .frame(width: 120, alignment: .trailing)
                    
                    if let folder = preferencesManager.projectsFolder {
                        Text(folder.path)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No folder selected")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button("Choose...") {
                        showingFolderPicker = true
                    }
                }
                
                HStack {
                    Text("Sort Projects By:")
                        .frame(width: 120, alignment: .trailing)
                    
                    Picker("", selection: $preferencesManager.sortOption) {
                        ForEach(PreferencesManager.SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                    
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AppearancePreferencesView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Appearance:")
                        .frame(width: 120, alignment: .trailing)
                    
                    Picker("", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                    
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct IgnoredFoldersView: View {
    @ObservedObject var preferencesManager: PreferencesManager
    @State private var selectedFolders: Set<String> = []
    @State private var newFolderName = ""
    @State private var showingAddField = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Ignored Folders")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddField.toggle() }) {
                    Image(systemName: "plus")
                }
                .disabled(showingAddField)
            }
            .padding()
            
            Divider()
            
            // List of ignored folders
            if preferencesManager.ignoredFolders.isEmpty && !showingAddField {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No ignored folders")
                        .foregroundColor(.secondary)
                    Text("Ignored folders won't appear in the projects list")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedFolders) {
                    if showingAddField {
                        HStack {
                            TextField("Folder name", text: $newFolderName)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    addFolder()
                                }
                            
                            Button("Add") {
                                addFolder()
                            }
                            .disabled(newFolderName.isEmpty)
                            
                            Button("Cancel") {
                                newFolderName = ""
                                showingAddField = false
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    ForEach(Array(preferencesManager.ignoredFolders).sorted(), id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.secondary)
                            Text(folder)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
            
            Divider()
            
            // Footer buttons
            HStack {
                Button("Remove Selected") {
                    for folder in selectedFolders {
                        preferencesManager.removeIgnoredFolder(folder)
                    }
                    selectedFolders.removeAll()
                }
                .disabled(selectedFolders.isEmpty)
                
                Spacer()
                
                if !preferencesManager.ignoredFolders.isEmpty {
                    Button("Clear All") {
                        preferencesManager.clearIgnoredFolders()
                        selectedFolders.removeAll()
                    }
                }
            }
            .padding()
        }
    }
    
    private func addFolder() {
        guard !newFolderName.isEmpty else { return }
        preferencesManager.addIgnoredFolder(newFolderName)
        newFolderName = ""
        showingAddField = false
    }
}

struct GitHubPreferencesView: View {
    @State private var tokenInput = ""
    @State private var showingToken = false
    @State private var hasToken = GitHubService.shared.hasAccessToken()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("GitHub Personal Access Token")
                        .font(.headline)
                    
                    Text("A GitHub personal access token is required to fetch commit information from your repositories.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        if hasToken {
                            if showingToken {
                                Text(KeychainManager.shared.getToken() ?? "")
                                    .textSelection(.enabled)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("••••••••••••••••••••••••••••••••")
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            Button(showingToken ? "Hide" : "Show") {
                                showingToken.toggle()
                            }
                            
                            Button("Remove") {
                                removeToken()
                            }
                            .foregroundColor(.red)
                        } else {
                            SecureField("Enter your GitHub token", text: $tokenInput)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Save") {
                                saveToken()
                            }
                            .disabled(tokenInput.isEmpty)
                        }
                    }
                }
                .padding(.vertical, 5)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How to get a GitHub Personal Access Token:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("1. Go to GitHub.com and sign in")
                        Text("2. Click your profile picture → Settings")
                        Text("3. Scroll down and click 'Developer settings'")
                        Text("4. Click 'Personal access tokens' → 'Tokens (classic)'")
                        Text("5. Click 'Generate new token' → 'Generate new token (classic)'")
                        Text("6. Give it a name and select the 'repo' scope")
                        Text("7. Click 'Generate token' and copy it")
                    }
                    .font(.caption)
                    
                    Link("Open GitHub Token Settings", 
                         destination: URL(string: "https://github.com/settings/tokens")!)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("GitHub Token", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func saveToken() {
        guard !tokenInput.isEmpty else { return }
        
        if KeychainManager.shared.saveToken(tokenInput) {
            hasToken = true
            tokenInput = ""
            alertMessage = "Token saved successfully!"
        } else {
            alertMessage = "Failed to save token. Please try again."
        }
        showingAlert = true
    }
    
    private func removeToken() {
        if KeychainManager.shared.deleteToken() {
            hasToken = false
            showingToken = false
            alertMessage = "Token removed successfully!"
        } else {
            alertMessage = "Failed to remove token. Please try again."
        }
        showingAlert = true
    }
}