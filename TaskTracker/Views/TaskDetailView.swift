import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName = "Hannah"

    @State private var showingEditor = false
    @State private var confirmingDelete = false
    @State private var newChecklistTitle = ""
    @State private var newComment = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.title2.bold())
                    HStack {
                        StatusPill(status: task.status)
                        if task.isOverdue {
                            Label("เลยกำหนด", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.vertical, 4)

                Picker("สถานะ", selection: $task.status) {
                    ForEach(TaskStatus.allCases) { status in
                        Label(status.title, systemImage: status.icon).tag(status)
                    }
                }

                if let next = task.status.next {
                    Button {
                        withAnimation { task.status = next }
                    } label: {
                        Label("ย้ายไป \"\(next.title)\"", systemImage: "arrow.right.circle.fill")
                    }
                }
            }

            Section("รายละเอียด") {
                LabeledContent("ผู้รับผิดชอบ") {
                    if let member = task.assignee {
                        HStack(spacing: 6) {
                            AvatarView(name: member.name, colorIndex: member.colorIndex, size: 24)
                            Text(member.name)
                        }
                    } else {
                        Text("ยังไม่มอบหมาย")
                    }
                }
                LabeledContent("กำหนดส่ง", value: task.dueDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("ประเภทงาน", value: task.material.title)
                LabeledContent("ขั้นตอน", value: task.action.title)
                LabeledContent("แบรนด์ / ลูกค้า", value: task.brand?.name ?? "-")
            }

            Section("ไฟล์งาน") {
                linkRow(title: "Materials", urlString: task.materialsURL)
                linkRow(title: "Output", urlString: task.outputURL)
            }

            Section("จำนวนครั้งที่แก้ไข") {
                Stepper("ลูกค้า: \(task.clientRevisions)", value: $task.clientRevisions, in: 0...99)
                Stepper("ภายใน: \(task.internalRevisions)", value: $task.internalRevisions, in: 0...99)
            }

            checklistSection
            commentsSection

            if !task.notes.isEmpty {
                Section("โน้ต") {
                    Text(task.notes)
                }
            }

            Section {
                Button("ลบงานนี้", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .navigationTitle("รายละเอียดงาน")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("แก้ไข") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            TaskEditorView(task: task)
        }
        .confirmationDialog("ลบงานนี้?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("ลบ", role: .destructive) {
                context.delete(task)
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func linkRow(title: String, urlString: String) -> some View {
        if let url = urlString.asWebURL {
            Link(destination: url) {
                LabeledContent(title) {
                    Label("เปิด", systemImage: "arrow.up.right")
                        .labelStyle(CompactLabelStyle())
                        .foregroundStyle(Color.accentColor)
                }
            }
            .foregroundStyle(.primary)
        } else {
            LabeledContent(title) {
                Button("+ เพิ่มลิงก์") { showingEditor = true }
            }
        }
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        Section {
            ForEach(task.sortedChecklist) { item in
                Button {
                    withAnimation { item.isDone.toggle() }
                } label: {
                    HStack {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isDone ? Color.green : Color.secondary)
                            .font(.title3)
                        Text(item.title)
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
                    }
                }
            }
            .onDelete { offsets in
                let items = task.sortedChecklist
                for index in offsets {
                    context.delete(items[index])
                }
            }

            HStack {
                TextField("เพิ่มขั้นตอน...", text: $newChecklistTitle)
                    .onSubmit(addChecklistItem)
                Button(action: addChecklistItem) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newChecklistTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            let done = task.checklist.filter(\.isDone).count
            Text("เช็กลิสต์ (\(done)/\(task.checklist.count))")
        }
    }

    private func addChecklistItem() {
        let title = newChecklistTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let item = ChecklistItem(title: title, order: (task.checklist.map(\.order).max() ?? -1) + 1)
        context.insert(item)
        item.task = task
        newChecklistTitle = ""
    }

    // MARK: - Comments

    private var commentsSection: some View {
        Section("ความคิดเห็น (\(task.comments.count))") {
            ForEach(task.sortedComments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.author).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(comment.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(comment.text)
                }
                .padding(.vertical, 2)
            }
            .onDelete { offsets in
                let comments = task.sortedComments
                for index in offsets {
                    context.delete(comments[index])
                }
            }

            HStack {
                TextField("เขียนความคิดเห็น...", text: $newComment, axis: .vertical)
                Button(action: addComment) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addComment() {
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let comment = TaskComment(text: text, author: userName)
        context.insert(comment)
        comment.task = task
        newComment = ""
    }
}

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TeamMember.name) private var members: [TeamMember]
    @Query(sort: \Brand.name) private var brands: [Brand]

    private let task: TaskItem?

    @State private var title: String
    @State private var dueDate: Date
    @State private var status: TaskStatus
    @State private var action: TaskAction
    @State private var material: MaterialType
    @State private var assignee: TeamMember?
    @State private var brand: Brand?
    @State private var materialsURL: String
    @State private var outputURL: String
    @State private var notes: String

    init(task: TaskItem? = nil, defaultDate: Date = .now) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _dueDate = State(initialValue: task?.dueDate ?? defaultDate)
        _status = State(initialValue: task?.status ?? .inProgress)
        _action = State(initialValue: task?.action ?? .create)
        _material = State(initialValue: task?.material ?? .copywriting)
        _assignee = State(initialValue: task?.assignee)
        _brand = State(initialValue: task?.brand)
        _materialsURL = State(initialValue: task?.materialsURL ?? "")
        _outputURL = State(initialValue: task?.outputURL ?? "")
        _notes = State(initialValue: task?.notes ?? "")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ชื่องาน", text: $title)
                    DatePicker("กำหนดส่ง", selection: $dueDate, displayedComponents: .date)
                }

                Section {
                    Picker("ผู้รับผิดชอบ", selection: $assignee) {
                        Text("ยังไม่มอบหมาย").tag(nil as TeamMember?)
                        ForEach(members) { member in
                            Text(member.name).tag(member as TeamMember?)
                        }
                    }
                    Picker("แบรนด์ / ลูกค้า", selection: $brand) {
                        Text("ไม่ระบุ").tag(nil as Brand?)
                        ForEach(BrandKind.allCases) { kind in
                            Section(kind.title) {
                                ForEach(brands.filter { $0.kind == kind }) { brand in
                                    Text(brand.name).tag(brand as Brand?)
                                }
                            }
                        }
                    }
                }

                Section {
                    Picker("ประเภทงาน", selection: $material) {
                        ForEach(MaterialType.allCases) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }
                    Picker("ขั้นตอน", selection: $action) {
                        ForEach(TaskAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("สถานะ", selection: $status) {
                        ForEach(TaskStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }

                Section("ลิงก์ไฟล์") {
                    TextField("ลิงก์ Materials", text: $materialsURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("ลิงก์ Output", text: $outputURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("โน้ต") {
                    TextField("รายละเอียดเพิ่มเติม", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(task == nil ? "งานใหม่" : "แก้ไขงาน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let target: TaskItem
        if let task {
            target = task
        } else {
            // Insert before setting relationships so SwiftData tracks them.
            target = TaskItem(title: "", dueDate: dueDate)
            context.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.dueDate = dueDate
        target.status = status
        target.action = action
        target.material = material
        target.assignee = assignee
        target.brand = brand
        target.materialsURL = materialsURL.trimmingCharacters(in: .whitespaces)
        target.outputURL = outputURL.trimmingCharacters(in: .whitespaces)
        target.notes = notes
        target.updatedAt = .now
        dismiss()
    }
}
