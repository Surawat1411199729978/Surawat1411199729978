import FirebaseCore
import SwiftData
import SwiftUI

@main
struct TaskTrackerApp: App {
    @State private var store = TeamStore()

    init() {
        if TeamStore.isFirebaseConfigured {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if TeamStore.isFirebaseConfigured {
                    RootView()
                } else {
                    FirebaseMissingView()
                }
            }
            .environment(store)
        }
        .modelContainer(for: TodoItem.self)
    }
}

struct RootView: View {
    @Environment(TeamStore.self) private var store
    @Environment(\.modelContext) private var context
    @AppStorage("didSeedSampleTodos") private var didSeedTodos = false

    var body: some View {
        Group {
            switch store.phase {
            case .starting:
                ProgressView("กำลังเชื่อมต่อ...")
            case .needsTeam:
                TeamSetupView()
            case .failed(let message):
                ContentUnavailableView {
                    Label("เชื่อมต่อไม่สำเร็จ", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("ลองอีกครั้ง") {
                        Task { await store.start() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .ready:
                MainTabView()
            }
        }
        .task {
            await store.start()
            if !didSeedTodos {
                SampleData.loadTodos(into: context)
                didSeedTodos = true
            }
        }
        .alert("เกิดข้อผิดพลาด", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

struct MainTabView: View {
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
    }
}

struct FirebaseMissingView: View {
    var body: some View {
        ContentUnavailableView {
            Label("ยังไม่ได้ตั้งค่า Firebase", systemImage: "flame")
        } description: {
            Text("เพิ่มไฟล์ GoogleService-Info.plist ลงในโฟลเดอร์ TaskTracker แล้ว build ใหม่ ดูขั้นตอนใน README.md")
        }
    }
}
