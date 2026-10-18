import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(TeamStore.self) private var store
    @Query private var todos: [TodoItem]
    @AppStorage("userName") private var userName = ""

    private var tasks: [TaskItem] { store.tasks }
    private var members: [TeamMember] { store.members }

    @State private var showingNewTask = false

    private var monthTasks: [TaskItem] {
        tasks.filter { AppCalendar.isSameMonth($0.dueDate, .now) }
    }

    private var weekTasks: [TaskItem] {
        tasks.filter { AppCalendar.isThisWeek($0.dueDate) }
    }

    private var needsAttention: [TaskItem] {
        let endOfToday = AppCalendar.shared.date(byAdding: .day, value: 1, to: AppCalendar.shared.startOfDay(for: .now)) ?? .now
        return tasks.filter { $0.status != .posted && $0.dueDate < endOfToday }
    }

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let member: String
        let status: TaskStatus
        let count: Int
    }

    private var chartData: [ChartPoint] {
        members.flatMap { member in
            TaskStatus.allCases.compactMap { status in
                let count = monthTasks.filter { $0.assigneeID == member.id && $0.status == status }.count
                return count > 0 ? ChartPoint(member: member.name, status: status, count: count) : nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summaryGrid
                    attentionCard
                    weeklyProgressCard
                    workloadCard
                    teamCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ภาพรวม")
            .navigationBarTitleDisplayMode(.inline)
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
                TaskEditorView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.teamName.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("ยินดีต้อนรับกลับ, \(userName)!")
                .font(.largeTitle.bold())
            Text("นี่คือสถานะงานของทีมในเดือนนี้")
                .foregroundStyle(.secondary)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(TaskStatus.allCases) { status in
                StatusSummaryCard(status: status, count: monthTasks.filter { $0.status == status }.count)
            }
        }
    }

    private var attentionCard: some View {
        CardContainer(title: "ต้องทำวันนี้ / เลยกำหนด", systemImage: "exclamationmark.circle") {
            if needsAttention.isEmpty {
                Label("ไม่มีงานค้าง เยี่ยมมาก!", systemImage: "party.popper")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(needsAttention.prefix(5)) { task in
                    NavigationLink(value: TaskRoute(id: task.id)) {
                        HStack {
                            if let member = store.member(task.assigneeID) {
                                AvatarView(name: member.name, colorIndex: member.colorIndex, size: 26)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(.subheadline.weight(.semibold))
                                Text(task.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption)
                                    .foregroundStyle(task.isOverdue ? Color.red : Color.secondary)
                            }
                            Spacer()
                            StatusPill(status: task.status)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weeklyProgressCard: some View {
        let posted = weekTasks.filter { $0.status == .posted }.count
        let total = weekTasks.count
        let todosDone = todos.filter(\.isDone).count
        let progress = total == 0 ? 0 : Double(posted) / Double(total)

        return VStack(alignment: .leading, spacing: 10) {
            Text("KPI สัปดาห์นี้")
                .font(.title3.bold())
            Text("โพสต์แล้ว \(posted) จาก \(total) งาน")
                .font(.subheadline)
                .opacity(0.9)
            ProgressView(value: progress)
                .tint(.white)
            HStack {
                Label("\(Int(progress * 100))%", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                Label("To-Do เสร็จ \(todosDone)/\(todos.count)", systemImage: "checklist")
            }
            .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var workloadCard: some View {
        CardContainer(title: "งานของแต่ละคน (เดือนนี้)", systemImage: "chart.bar.xaxis") {
            if chartData.isEmpty {
                Text("ยังไม่มีงานในเดือนนี้").foregroundStyle(.secondary)
            } else {
                Chart(chartData) { point in
                    BarMark(
                        x: .value("จำนวน", point.count),
                        y: .value("สมาชิก", point.member)
                    )
                    .foregroundStyle(by: .value("สถานะ", point.status.title))
                }
                .chartForegroundStyleScale(
                    domain: TaskStatus.allCases.map(\.title),
                    range: TaskStatus.allCases.map(\.color)
                )
                .chartLegend(position: .bottom)
                .frame(height: CGFloat(max(members.count, 1)) * 40 + 50)
            }
        }
    }

    private var teamCard: some View {
        CardContainer(title: "ทีม", systemImage: "person.3") {
            ForEach(members) { member in
                let active = tasks.filter { $0.assigneeID == member.id && $0.status != .posted }.count
                HStack {
                    AvatarView(name: member.name, colorIndex: member.colorIndex, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name).font(.subheadline.weight(.semibold))
                        if !member.role.isEmpty {
                            Text(member.role).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("\(active) งานค้าง")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(active > 0 ? Color.accentColor : Color.secondary)
                }
            }
            if members.isEmpty {
                Text("ยังไม่มีสมาชิก เพิ่มได้ที่แท็บตั้งค่า").foregroundStyle(.secondary)
            }
        }
    }
}
