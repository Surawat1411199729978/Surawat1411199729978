import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum TaskStatus: String, CaseIterable, Identifiable, Codable {
    case inProgress, forReview, scheduled, posted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inProgress: "กำลังทำ"
        case .forReview: "รอตรวจ"
        case .scheduled: "ตั้งเวลาแล้ว"
        case .posted: "โพสต์แล้ว"
        }
    }

    var icon: String {
        switch self {
        case .inProgress: "hammer.fill"
        case .forReview: "eye.fill"
        case .scheduled: "clock.fill"
        case .posted: "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .inProgress: .blue
        case .forReview: .orange
        case .scheduled: .purple
        case .posted: .green
        }
    }

    /// The next step in the workflow, or nil when the task is already posted.
    var next: TaskStatus? {
        switch self {
        case .inProgress: .forReview
        case .forReview: .scheduled
        case .scheduled: .posted
        case .posted: nil
        }
    }
}

enum TaskAction: String, CaseIterable, Identifiable, Codable {
    case create, schedule, post

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create: "สร้าง"
        case .schedule: "ตั้งเวลา"
        case .post: "โพสต์"
        }
    }
}

enum MaterialType: String, CaseIterable, Identifiable, Codable {
    case copywriting, staticDesign, carousel, reel, slides, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copywriting: "Copywriting"
        case .staticDesign: "Static design"
        case .carousel: "Carousel design"
        case .reel: "Reel / video"
        case .slides: "Slides"
        case .other: "อื่นๆ"
        }
    }

    var icon: String {
        switch self {
        case .copywriting: "text.alignleft"
        case .staticDesign: "photo"
        case .carousel: "square.stack.3d.forward.dottedline"
        case .reel: "play.rectangle"
        case .slides: "rectangle.on.rectangle"
        case .other: "doc"
        }
    }
}

enum BrandKind: String, CaseIterable, Identifiable, Codable {
    case inHouse, client

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inHouse: "แบรนด์ในเครือ"
        case .client: "ลูกค้า"
        }
    }
}

enum TodoPriority: Int, CaseIterable, Identifiable, Codable {
    case low = 0, normal = 1, high = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: "ต่ำ"
        case .normal: "ปกติ"
        case .high: "สูง"
        }
    }

    var color: Color {
        switch self {
        case .low: .gray
        case .normal: .blue
        case .high: .red
        }
    }
}

// MARK: - Shared team data (stored in Firestore under teams/{code}/...)

struct TeamMember: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var role = ""
    var colorIndex = 0
}

struct Brand: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var kind: BrandKind
    var colorIndex = 0
}

struct ChecklistItem: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var isDone = false
}

struct TaskComment: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var text: String
    var author: String
    var createdAt = Date.now
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var notes = ""
    var dueDate: Date
    var status: TaskStatus = .inProgress
    var action: TaskAction = .create
    var material: MaterialType = .other
    var assigneeID: String?
    var brandID: String?
    var materialsURL = ""
    var outputURL = ""
    var clientRevisions = 0
    var internalRevisions = 0
    var checklist: [ChecklistItem] = []
    var comments: [TaskComment] = []
    var createdAt = Date.now
    var updatedAt = Date.now

    var isOverdue: Bool {
        status != .posted && dueDate < AppCalendar.shared.startOfDay(for: .now)
    }

    var sortedComments: [TaskComment] {
        comments.sorted { $0.createdAt < $1.createdAt }
    }
}

/// Navigation value for opening a task; the screen looks the task up live from the store.
struct TaskRoute: Hashable {
    let id: String
}

// MARK: - Personal to-dos (stored on this device only)

@Model
final class TodoItem {
    var title: String = ""
    var notes: String = ""
    var isDone: Bool = false
    var dueDate: Date?
    var priorityRaw: Int = TodoPriority.normal.rawValue
    var createdAt: Date = Date.now
    var completedAt: Date?

    var priority: TodoPriority {
        get { TodoPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        guard !isDone, let dueDate else { return false }
        return dueDate < AppCalendar.shared.startOfDay(for: .now)
    }

    init(title: String, dueDate: Date? = nil, priority: TodoPriority = .normal) {
        self.title = title
        self.dueDate = dueDate
        self.priorityRaw = priority.rawValue
        self.createdAt = .now
    }

    func toggle() {
        isDone.toggle()
        completedAt = isDone ? .now : nil
    }
}

// MARK: - Calendar helpers

enum AppCalendar {
    /// Gregorian calendar with weeks starting on Monday, used for all date math.
    static let shared: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }()

    static func startOfMonth(_ date: Date) -> Date {
        shared.dateInterval(of: .month, for: date)?.start ?? date
    }

    static func isSameMonth(_ a: Date, _ b: Date) -> Bool {
        shared.isDate(a, equalTo: b, toGranularity: .month)
    }

    static func isThisWeek(_ date: Date) -> Bool {
        shared.isDate(date, equalTo: .now, toGranularity: .weekOfYear)
    }
}

struct WeekGroup: Identifiable {
    let id: Date
    let number: Int
    let start: Date
    let end: Date
    let tasks: [TaskItem]

    var title: String {
        let startText = start.formatted(.dateTime.day().month(.abbreviated))
        let endText = end.formatted(.dateTime.day().month(.abbreviated))
        return "สัปดาห์ \(number) | \(startText) – \(endText)"
    }

    /// Groups tasks of one month into Monday-based weeks, clipped to the month's bounds.
    static func groups(for tasks: [TaskItem], inMonth month: Date) -> [WeekGroup] {
        let cal = AppCalendar.shared
        guard let monthInterval = cal.dateInterval(of: .month, for: month) else { return [] }
        let monthLastDay = cal.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end

        let grouped = Dictionary(grouping: tasks) { task in
            cal.dateInterval(of: .weekOfYear, for: task.dueDate)?.start ?? task.dueDate
        }

        return grouped.keys.sorted().map { weekStart in
            let start = max(weekStart, monthInterval.start)
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let end = min(weekEnd, monthLastDay)
            let number = cal.component(.weekOfMonth, from: start)
            let items = (grouped[weekStart] ?? []).sorted { $0.dueDate < $1.dueDate }
            return WeekGroup(id: weekStart, number: number, start: start, end: end, tasks: items)
        }
    }
}
