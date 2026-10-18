import SwiftUI

struct TasksView: View {
    @Environment(TeamStore.self) private var store

    @State private var month = AppCalendar.startOfMonth(.now)
    @State private var memberFilter: String?
    @State private var brandFilter: String?
    @State private var materialFilter: MaterialType?
    @State private var statusFilter: TaskStatus?
    @State private var searchText = ""
    @State private var showingNewTask = false

    /// Tasks in the selected month matching every filter except status (used for the summary counts).
    private var monthTasks: [TaskItem] {
        store.tasks.filter { task in
            AppCalendar.isSameMonth(task.dueDate, month)
                && (memberFilter == nil || task.assigneeID == memberFilter)
                && (brandFilter == nil || task.brandID == brandFilter)
                && (materialFilter == nil || task.material == materialFilter)
                && (searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var visibleTasks: [TaskItem] {
        guard let statusFilter else { return monthTasks }
        return monthTasks.filter { $0.status == statusFilter }
    }

    private var hasFilters: Bool {
        memberFilter != nil || brandFilter != nil || materialFilter != nil || statusFilter != nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryGrid
                    filterBar
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)

                let weeks = WeekGroup.groups(for: visibleTasks, inMonth: month)
                if weeks.isEmpty {
                    ContentUnavailableView(
                        "ไม่มีงาน",
                        systemImage: "tray",
                        description: Text("ไม่พบงานในเดือนนี้ตามตัวกรองที่เลือก")
                    )
                    .listRowBackground(Color.clear)
                }
                ForEach(weeks) { week in
                    Section {
                        ForEach(week.tasks) { task in
                            NavigationLink(value: TaskRoute(id: task.id)) {
                                TaskRowView(task: task)
                            }
                            .swipeActions(edge: .leading) {
                                if let next = task.status.next {
                                    Button {
                                        store.setStatus(next, for: task)
                                    } label: {
                                        Label(next.title, systemImage: next.icon)
                                    }
                                    .tint(next.color)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(task)
                                } label: {
                                    Label("ลบ", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text(week.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: visibleTasks)
            .navigationTitle("งานของทีม")
            .searchable(text: $searchText, prompt: "ค้นหาชื่องาน")
            .navigationDestination(for: TaskRoute.self) { route in
                TaskDetailView(taskID: route.id)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewTask = true
                    } label: {
                        Label("งานใหม่", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingNewTask) {
                TaskEditorView(defaultDate: defaultNewTaskDate)
            }
        }
    }

    private var defaultNewTaskDate: Date {
        AppCalendar.isSameMonth(month, .now) ? .now : month
    }

    // MARK: - Header pieces

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(TaskStatus.allCases) { status in
                StatusSummaryCard(
                    status: status,
                    count: monthTasks.filter { $0.status == status }.count,
                    isSelected: statusFilter == status
                )
                .onTapGesture {
                    withAnimation { statusFilter = statusFilter == status ? nil : status }
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                monthStepper

                FilterChip(title: store.member(memberFilter)?.name ?? "ทั้งทีม", isActive: memberFilter != nil) {
                    Button("ทั้งทีม") { memberFilter = nil }
                    ForEach(store.members) { member in
                        Button(member.name) { memberFilter = member.id }
                    }
                }

                FilterChip(title: store.brand(brandFilter)?.name ?? "แบรนด์: ทั้งหมด", isActive: brandFilter != nil) {
                    Button("ทั้งหมด") { brandFilter = nil }
                    ForEach(BrandKind.allCases) { kind in
                        Section(kind.title) {
                            ForEach(store.brands.filter { $0.kind == kind }) { brand in
                                Button(brand.name) { brandFilter = brand.id }
                            }
                        }
                    }
                }

                FilterChip(title: materialFilter?.title ?? "ประเภท: ทั้งหมด", isActive: materialFilter != nil) {
                    Button("ทั้งหมด") { materialFilter = nil }
                    ForEach(MaterialType.allCases) { type in
                        Button(type.title) { materialFilter = type }
                    }
                }

                FilterChip(title: statusFilter?.title ?? "สถานะ: ทั้งหมด", isActive: statusFilter != nil) {
                    Button("ทั้งหมด") { statusFilter = nil }
                    ForEach(TaskStatus.allCases) { status in
                        Button(status.title) { statusFilter = status }
                    }
                }

                if hasFilters {
                    Button("ล้าง") {
                        withAnimation {
                            memberFilter = nil
                            brandFilter = nil
                            materialFilter = nil
                            statusFilter = nil
                        }
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var monthStepper: some View {
        HStack(spacing: 6) {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            Text(month.formatted(.dateTime.month(.wide).year()))
                .lineLimit(1)
            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.borderless)
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }

    private func shiftMonth(_ value: Int) {
        if let newMonth = AppCalendar.shared.date(byAdding: .month, value: value, to: month) {
            withAnimation { month = newMonth }
        }
    }
}

struct TaskRowView: View {
    @Environment(TeamStore.self) private var store
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(task.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                StatusPill(status: task.status)
            }

            HStack(spacing: 6) {
                if let member = store.member(task.assigneeID) {
                    AvatarView(name: member.name, colorIndex: member.colorIndex, size: 22)
                    Text(member.name)
                } else {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                    Text("ยังไม่มอบหมาย")
                }
                Text("·")
                Text(task.material.title)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            HStack(spacing: 12) {
                Label(task.dueDate.formatted(.dateTime.day().month(.abbreviated)), systemImage: "calendar")
                    .foregroundStyle(task.isOverdue ? Color.red : Color.secondary)
                if let brand = store.brand(task.brandID) {
                    HStack(spacing: 4) {
                        Circle().fill(Palette.color(brand.colorIndex)).frame(width: 7, height: 7)
                        Text(brand.name).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if !task.checklist.isEmpty {
                    let done = task.checklist.filter(\.isDone).count
                    Label("\(done)/\(task.checklist.count)", systemImage: "checklist")
                }
                if !task.comments.isEmpty {
                    Label("\(task.comments.count)", systemImage: "bubble.left")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(CompactLabelStyle())
        }
        .padding(.vertical, 4)
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
