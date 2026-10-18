import SwiftUI

struct TaskDetailView: View {
    let taskID: String

    @Environment(TeamStore.self) private var store

    var body: some View {
        if let task = store.task(taskID) {
            TaskDetailContent(task: task)
        } else {
            ContentUnavailableView("ไม่พบงานนี้", systemImage: "trash", description: Text("งานอาจถูกลบไปแล้ว"))
        }
    }
}

/// Shows one task. `task` is a fresh snapshot each time the store updates, so edits from teammates appear live.
private struct TaskDetailContent: View {
    let task: TaskItem

    @Environment(TeamStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var userName = ""

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
                    Text("อัปเดตล่าสุด \(task.updatedAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Picker("สถานะ", selection: Binding(
                    get: { task.status },
                    set: { store.setStatus($0, for: task) }
                )) {
                    ForEach(TaskStatus.allCases) { status in
                        Label(status.title, systemImage: status.icon).tag(status)
                    }
                }

                if let next = task.status.next {
                    Button {
                        store.setStatus(next, for: task)
                    } label: {
                        Label("ย้ายไป \"\(next.title)\"", systemImage: "arrow.right.circle.fill")
                    }
                }
            }

            Section("รายละเอียด") {
                LabeledContent("ผู้รับผิดชอบ") {
                    if let member = store.member(task.assigneeID) {
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
                LabeledContent("แบรนด์ / ลูกค้า", value: store.brand(task.brandID)?.name ?? "-")
            }

            Section("ไฟล์งาน") {
                linkRow(title: "Materials", urlString: task.materialsURL)
                linkRow(title: "Output", urlString: task.outputURL)
            }

            Section("จำนวนครั้งที่แก้ไข") {
                Stepper("ลูกค้า: \(task.clientRevisions)", value: Binding(
                    get: { task.clientRevisions },
                    set: { store.setRevisions(client: $0, internal: task.internalRevisions, for: task) }
                ), in: 0...99)
                Stepper("ภายใน: \(task.internalRevisions)", value: Binding(
                    get: { task.internalRevisions },
                    set: { store.setRevisions(client: task.clientRevisions, internal: $0, for: task) }
                ), in: 0...99)
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
                store.delete(task)
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
            ForEach(task.checklist) { item in
                Button {
                    var checklist = task.checklist
                    if let index = checklist.firstIndex(where: { $0.id == item.id }) {
                        checklist[index].isDone.toggle()
                        store.setChecklist(checklist, for: task)
                    }
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
                var checklist = task.checklist
                checklist.remove(atOffsets: offsets)
                store.setChecklist(checklist, for: task)
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
        store.setChecklist(task.checklist + [ChecklistItem(title: title)], for: task)
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
                let removed = Set(offsets.map { task.sortedComments[$0].id })
                store.setComments(task.comments.filter { !removed.contains($0.id) }, for: task)
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
        store.addComment(TaskComment(text: text, author: userName.isEmpty ? "ไม่ระบุชื่อ" : userName), to: task)
        newComment = ""
    }
}

struct TaskEditorView: View {
    @Environment(TeamStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TaskItem
    private let isNew: Bool

    init(task: TaskItem? = nil, defaultDate: Date = .now) {
        isNew = task == nil
        var draft = task ?? TaskItem(title: "", dueDate: defaultDate)
        if task == nil {
            draft.material = .copywriting
        }
        _draft = State(initialValue: draft)
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ชื่องาน", text: $draft.title)
                    DatePicker("กำหนดส่ง", selection: $draft.dueDate, displayedComponents: .date)
                }

                Section {
                    Picker("ผู้รับผิดชอบ", selection: $draft.assigneeID) {
                        Text("ยังไม่มอบหมาย").tag(nil as String?)
                        ForEach(store.members) { member in
                            Text(member.name).tag(member.id as String?)
                        }
                    }
                    Picker("แบรนด์ / ลูกค้า", selection: $draft.brandID) {
                        Text("ไม่ระบุ").tag(nil as String?)
                        ForEach(BrandKind.allCases) { kind in
                            Section(kind.title) {
                                ForEach(store.brands.filter { $0.kind == kind }) { brand in
                                    Text(brand.name).tag(brand.id as String?)
                                }
                            }
                        }
                    }
                }

                Section {
                    Picker("ประเภทงาน", selection: $draft.material) {
                        ForEach(MaterialType.allCases) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }
                    Picker("ขั้นตอน", selection: $draft.action) {
                        ForEach(TaskAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("สถานะ", selection: $draft.status) {
                        ForEach(TaskStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }

                Section("ลิงก์ไฟล์") {
                    TextField("ลิงก์ Materials", text: $draft.materialsURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("ลิงก์ Output", text: $draft.outputURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("โน้ต") {
                    TextField("รายละเอียดเพิ่มเติม", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(isNew ? "งานใหม่" : "แก้ไขงาน")
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
        var task = draft
        task.title = task.title.trimmingCharacters(in: .whitespaces)
        task.materialsURL = task.materialsURL.trimmingCharacters(in: .whitespaces)
        task.outputURL = task.outputURL.trimmingCharacters(in: .whitespaces)
        if !isNew, let latest = store.task(task.id) {
            // Keep checklist/comments a teammate may have changed while this form was open.
            task.checklist = latest.checklist
            task.comments = latest.comments
            task.clientRevisions = latest.clientRevisions
            task.internalRevisions = latest.internalRevisions
        }
        store.save(task)
        dismiss()
    }
}
