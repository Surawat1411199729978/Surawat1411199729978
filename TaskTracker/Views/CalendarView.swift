import SwiftData
import SwiftUI

struct CalendarView: View {
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @Query private var todos: [TodoItem]

    @State private var selectedDate = Date.now
    @State private var showingNewTask = false

    private var dayTasks: [TaskItem] {
        tasks.filter { AppCalendar.shared.isDate($0.dueDate, inSameDayAs: selectedDate) }
    }

    private var dayTodos: [TodoItem] {
        todos.filter { todo in
            guard let due = todo.dueDate else { return false }
            return AppCalendar.shared.isDate(due, inSameDayAs: selectedDate)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("เลือกวัน", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                Section(selectedDate.formatted(date: .complete, time: .omitted)) {
                    if dayTasks.isEmpty && dayTodos.isEmpty {
                        Text("ไม่มีงานในวันนี้").foregroundStyle(.secondary)
                    }
                    ForEach(dayTasks) { task in
                        NavigationLink(value: task) {
                            TaskRowView(task: task)
                        }
                    }
                    ForEach(dayTodos) { todo in
                        Label {
                            Text(todo.title).strikethrough(todo.isDone)
                        } icon: {
                            Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(todo.isDone ? Color.green : todo.priority.color)
                        }
                        .onTapGesture { withAnimation { todo.toggle() } }
                    }
                }
            }
            .navigationTitle("ปฏิทิน")
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("วันนี้") { withAnimation { selectedDate = .now } }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTask = true
                    } label: {
                        Label("งานใหม่", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNewTask) {
                TaskEditorView(defaultDate: selectedDate)
            }
        }
    }
}
