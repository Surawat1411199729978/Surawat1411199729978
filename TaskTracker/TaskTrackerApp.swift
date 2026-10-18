import SwiftData
import SwiftUI

@main
struct TaskTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            TeamMember.self,
            Brand.self,
            TaskItem.self,
            ChecklistItem.self,
            TaskComment.self,
            TodoItem.self,
        ])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("didSeedSampleData") private var didSeed = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("ภาพรวม", systemImage: "square.grid.2x2") }
            TasksView()
                .tabItem { Label("งานทีม", systemImage: "list.bullet.rectangle") }
            TodoView()
                .tabItem { Label("To-Do", systemImage: "checklist") }
            CalendarView()
                .tabItem { Label("ปฏิทิน", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("ตั้งค่า", systemImage: "gearshape") }
        }
        .task {
            guard !didSeed else { return }
            SampleData.load(into: context)
            didSeed = true
        }
    }
}
