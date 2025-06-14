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
            
            AppearancePreferencesView()
            .tabItem {
                Label("Appearance", systemImage: "paintbrush")
            }
        }
        .frame(width: 500, height: 300)
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