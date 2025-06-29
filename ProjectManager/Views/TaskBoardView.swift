import SwiftUI
import ProjectManagerCore

struct TaskBoardView: View {
    @ObservedObject var focusManager: FocusManager
    @ObservedObject var projectsManager: ProjectsManager
    @Binding var selectedProjectsForFilter: Set<UUID>
    
    private var isFilterActive: Bool {
        !selectedProjectsForFilter.isEmpty
    }
    
    private var filteredTodoTasks: [FocusTask] {
        guard isFilterActive else { return focusManager.todoTasks }
        return focusManager.todoTasks.filter { task in
            selectedProjectsForFilter.contains(task.projectId)
        }
    }
    
    private var filteredInProgressTasks: [FocusTask] {
        guard isFilterActive else { return focusManager.inProgressTasks }
        return focusManager.inProgressTasks.filter { task in
            selectedProjectsForFilter.contains(task.projectId)
        }
    }
    
    private var filteredCompletedTasks: [FocusTask] {
        guard isFilterActive else { return focusManager.completedTasks }
        return focusManager.completedTasks.filter { task in
            selectedProjectsForFilter.contains(task.projectId)
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 1) {
            // To Do Column
            TaskColumnView(
                title: "To Do",
                subtitle: TaskStatus.todo.description,
                tasks: filteredTodoTasks,
                taskStatus: .todo,
                focusManager: focusManager,
                projectsManager: projectsManager
            )
            
            Divider()
            
            // In Progress Column
            TaskColumnView(
                title: "In Progress",
                subtitle: TaskStatus.inProgress.description,
                tasks: filteredInProgressTasks,
                taskStatus: .inProgress,
                focusManager: focusManager,
                projectsManager: projectsManager
            )
            
            Divider()
            
            // Completed Column
            TaskColumnView(
                title: "Completed",
                subtitle: TaskStatus.completed.description,
                tasks: filteredCompletedTasks,
                taskStatus: .completed,
                focusManager: focusManager,
                projectsManager: projectsManager
            )
        }
    }
}
