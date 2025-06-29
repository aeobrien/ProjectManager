import SwiftUI
import ProjectManagerCore

struct OverviewTabView: View {
    @EnvironmentObject var projectsManager: ProjectsManager
    
    var body: some View {
        NavigationStack {
            List(projectsManager.projects) { project in
                NavigationLink(destination: ProjectOverviewDetailView(project: project)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        if project.hasOverview {
                            Text("Has overview document")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Overview")
        }
    }
}

struct ProjectOverviewDetailView: View {
    let project: Project
    @StateObject private var viewModel: OverviewEditorViewModel
    
    init(project: Project) {
        self.project = project
        _viewModel = StateObject(wrappedValue: OverviewEditorViewModel(project: project))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Project info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Status")
                        .font(.headline)
                    Text(viewModel.projectOverview.currentStatus)
                        .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Next steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Steps")
                        .font(.headline)
                    Text(viewModel.projectOverview.nextSteps)
                        .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadOverview()
        }
    }
}