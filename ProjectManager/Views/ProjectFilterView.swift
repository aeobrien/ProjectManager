import SwiftUI
import ProjectManagerCore

struct ProjectFilterView: View {
    @ObservedObject var focusManager: FocusManager
    @Binding var selectedProjectsForFilter: Set<UUID>
    
    var body: some View {
        if !focusManager.activeProjects.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(focusManager.activeProjects) { project in
                        ProjectFilterChip(
                            project: project,
                            focusManager: focusManager,
                            selectedProjects: $selectedProjectsForFilter
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 40)
            
            Divider()
        }
    }
}
