import SwiftData
import SwiftUI

struct TodoView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todos: [TodoItem]

    @State private var newTitle = ""
    @State private var editingTodo: TodoItem?
    @FocusState private var isAdding: Bool

    private var openTodos: [TodoItem] {
        todos.filter { !$0.isDone }.sorted { a, b in
            if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?): return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return a.createdAt > b.createdAt
            }
        }
    }

    private var doneTodos: [TodoItem] {
        todos.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.title3)
                        TextField("เพิ่มสิ่งที่ต้องทำ...", text: $newTitle)
                            .focused($isAdding)
                            .submitLabel(.done)
                            .onSubmit(addTodo)
                    }
                }

                Section("ต้องทำ (\(openTodos.count))") {
                    if openTodos.isEmpty {
                        Label("ทำครบหมดแล้ว!", systemImage: "checkmark.seal")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(openTodos) { todo in
                        TodoRow(todo: todo) { editingTodo = todo }
                    }
                    .onDelete { delete(openTodos, at: $0) }
                }

                if !doneTodos.isEmpty {
                    Section("เสร็จแล้ว (\(doneTodos.count))") {
                        ForEach(doneTodos) { todo in
                            TodoRow(todo: todo) { editingTodo = todo }
                        }
                        .onDelete { delete(doneTodos, at: $0) }
                    }
                }
            }
            .navigationTitle("To-Do")
            .toolbar {
                if !doneTodos.isEmpty {
                    Menu {
                        Button("ลบรายการที่เสร็จแล้ว", role: .destructive) {
                            withAnimation { doneTodos.forEach { context.delete($0) } }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $editingTodo) { todo in
                TodoEditorView(todo: todo)
            }
        }
    }

    private func addTodo() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        withAnimation {
            context.insert(TodoItem(title: title))
        }
        newTitle = ""
        isAdding = true
    }

    private func delete(_ list: [TodoItem], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                context.delete(list[index])
            }
        }
    }
}

struct TodoRow: View {
    let todo: TodoItem
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation { todo.toggle() }
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(todo.isDone ? Color.green : todo.priority.color)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 3) {
                Text(todo.title)
                    .strikethrough(todo.isDone)
                    .foregroundStyle(todo.isDone ? Color.secondary : Color.primary)
                HStack(spacing: 10) {
                    if let due = todo.dueDate {
                        Label(due.formatted(.dateTime.day().month(.abbreviated)), systemImage: "calendar")
                            .foregroundStyle(todo.isOverdue ? Color.red : Color.secondary)
                    }
                    if todo.priority == .high && !todo.isDone {
                        Label("สำคัญ", systemImage: "flag.fill")
                            .foregroundStyle(.red)
                    }
                    if !todo.notes.isEmpty {
                        Image(systemName: "note.text").foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .labelStyle(CompactLabelStyle())
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}

struct TodoEditorView: View {
    @Bindable var todo: TodoItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ชื่อรายการ", text: $todo.title)
                    Toggle("เสร็จแล้ว", isOn: Binding(
                        get: { todo.isDone },
                        set: { if $0 != todo.isDone { todo.toggle() } }
                    ))
                }
                Section {
                    Picker("ความสำคัญ", selection: $todo.priority) {
                        ForEach(TodoPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("กำหนดวัน", isOn: Binding(
                        get: { todo.dueDate != nil },
                        set: { todo.dueDate = $0 ? (todo.dueDate ?? .now) : nil }
                    ))
                    if let due = todo.dueDate {
                        DatePicker("วันที่", selection: Binding(
                            get: { due },
                            set: { todo.dueDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
                Section("โน้ต") {
                    TextField("รายละเอียด", text: $todo.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("แก้ไข To-Do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
        }
    }
}
