import SwiftUI

struct TodoListView: View {
    @ObservedObject var viewModel: OverviewEditorViewModel
    @State private var newTodoText = ""
    @State private var editingItem: TodoItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("To-Do List")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.projectOverview.todoItems.filter { $0.isCompleted }.count) of \(viewModel.projectOverview.todoItems.count) completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(viewModel.projectOverview.todoItems) { item in
                    TodoItemView(
                        item: item,
                        isEditing: editingItem?.id == item.id,
                        onToggle: { viewModel.toggleTodoItem(item) },
                        onDelete: { viewModel.deleteTodoItem(item) },
                        onEdit: { editingItem = item },
                        onSave: { newText in
                            viewModel.updateTodoText(item, newText: newText)
                            editingItem = nil
                        },
                        onCancel: { editingItem = nil }
                    )
                }
                
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.secondary)
                    
                    TextField("Add new task", text: $newTodoText, onCommit: addNewTodo)
                        .textFieldStyle(.plain)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            
            if !viewModel.projectOverview.todoItems.isEmpty {
                Divider()
                
                HStack {
                    Button("Clear Completed") {
                        clearCompleted()
                    }
                    .disabled(viewModel.projectOverview.todoItems.filter { $0.isCompleted }.isEmpty)
                    
                    Spacer()
                }
                .font(.caption)
            }
        }
    }
    
    private func addNewTodo() {
        guard !newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.addTodoItem(newTodoText)
        newTodoText = ""
    }
    
    private func clearCompleted() {
        let completedItems = viewModel.projectOverview.todoItems.filter { $0.isCompleted }
        completedItems.forEach { viewModel.deleteTodoItem($0) }
    }
}

struct TodoItemView: View {
    let item: TodoItem
    let isEditing: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editText: String = ""
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.isCompleted ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            if isEditing {
                TextField("Task", text: $editText, onCommit: {
                    onSave(editText)
                })
                .textFieldStyle(.roundedBorder)
                .onAppear {
                    editText = item.text
                }
                
                Button("Save") {
                    onSave(editText)
                }
                .buttonStyle(.link)
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.link)
            } else {
                Text(item.text)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        onEdit()
                    }
                
                if isHovering {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color(NSColor.controlBackgroundColor) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}