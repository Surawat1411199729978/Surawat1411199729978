import Foundation
import SwiftData

enum SampleData {
    /// Inserts a demo team, brands, tasks for the current month and a few to-dos.
    @MainActor
    static func load(into context: ModelContext) {
        let hannah = TeamMember(name: "Hannah", role: "Digital Marketing Manager", colorIndex: 2)
        let erianne = TeamMember(name: "Erianne", role: "Graphic Designer", colorIndex: 1)
        let donald = TeamMember(name: "Donald", role: "Content Creator", colorIndex: 0)
        let patrick = TeamMember(name: "Patrick", role: "Video Editor", colorIndex: 3)
        [hannah, erianne, donald, patrick].forEach { context.insert($0) }

        let jysigma = Brand(name: "JYSigma Business Consultancy", kind: .inHouse, colorIndex: 0)
        let jca = Brand(name: "JCA", kind: .inHouse, colorIndex: 2)
        let gthRise = Brand(name: "GTH Rise", kind: .inHouse, colorIndex: 5)
        let gthAsia = Brand(name: "GTH Asia", kind: .inHouse, colorIndex: 6)
        let jbc = Brand(name: "JBC", kind: .inHouse, colorIndex: 4)
        let jackYang = Brand(name: "Jack Yang", kind: .inHouse, colorIndex: 8)
        let seah = Brand(name: "Seah Engineering", kind: .client, colorIndex: 6)
        let eclipse = Brand(name: "Eclipse Steakhouse", kind: .client, colorIndex: 8)
        [jysigma, jca, gthRise, gthAsia, jbc, jackYang, seah, eclipse].forEach { context.insert($0) }

        func day(_ d: Int) -> Date {
            let cal = AppCalendar.shared
            var comps = cal.dateComponents([.year, .month], from: .now)
            comps.day = d
            comps.hour = 10
            return cal.date(from: comps) ?? .now
        }

        let link = "https://drive.google.com"

        let tasks: [(TaskItem, [String], [String])] = [
            (TaskItem(title: "Launch announcement copy", dueDate: day(1), status: .posted, action: .create,
                      material: .copywriting, assignee: hannah, brand: gthRise, materialsURL: link, outputURL: link),
             ["ร่างข้อความ", "ส่งให้ลูกค้าตรวจ"], ["ลูกค้าอนุมัติแล้ว"]),
            (TaskItem(title: "Private dinner ad visual", dueDate: day(1), status: .forReview, action: .create,
                      material: .staticDesign, assignee: erianne, brand: jbc, materialsURL: link, outputURL: link),
             ["ทำ 2 เวอร์ชัน", "ปรับสีตาม CI"], ["ขอปรับโทนสี", "แก้ไขแล้ว", "รอลูกค้าดู"]),
            (TaskItem(title: "Aircon tips carousel", dueDate: day(2), status: .scheduled, action: .schedule,
                      material: .carousel, assignee: donald, brand: seah, materialsURL: link, outputURL: link),
             [], ["ตั้งเวลาโพสต์ 18:00", "โอเค"]),
            (TaskItem(title: "Founder story reel", dueDate: day(2), status: .inProgress, action: .create,
                      material: .reel, assignee: patrick, brand: jackYang, materialsURL: link),
             ["ตัดต่อ", "ใส่ซับไตเติล", "ใส่เพลง"], ["รอฟุตเทจเพิ่ม"]),
            (TaskItem(title: "Services carousel", dueDate: day(5), status: .inProgress, action: .create,
                      material: .carousel, assignee: erianne, brand: jca, materialsURL: link),
             ["วางเลย์เอาต์", "ใส่ไอคอน"], []),
            (TaskItem(title: "Q4 update post", dueDate: day(6), status: .posted, action: .post,
                      material: .staticDesign, assignee: donald, brand: gthAsia, materialsURL: link, outputURL: link),
             [], []),
            (TaskItem(title: "Investor explainer slides", dueDate: day(8), status: .inProgress, action: .create,
                      material: .slides, assignee: hannah, brand: jbc, materialsURL: link),
             ["โครงเรื่อง", "ออกแบบสไลด์", "ตรวจตัวเลข"], []),
            (TaskItem(title: "Steakhouse weekend promo", dueDate: day(14), status: .forReview, action: .create,
                      material: .staticDesign, assignee: erianne, brand: eclipse, materialsURL: link),
             [], []),
            (TaskItem(title: "Consultancy LinkedIn article", dueDate: day(20), status: .inProgress, action: .create,
                      material: .copywriting, assignee: hannah, brand: jysigma),
             ["หาข้อมูล", "เขียนร่างแรก"], []),
            (TaskItem(title: "Halloween reel", dueDate: day(27), status: .scheduled, action: .schedule,
                      material: .reel, assignee: patrick, brand: gthRise, materialsURL: link, outputURL: link),
             [], []),
        ]

        for (task, checklist, comments) in tasks {
            context.insert(task)
            for (index, title) in checklist.enumerated() {
                let item = ChecklistItem(title: title, order: index)
                item.isDone = index == 0
                context.insert(item)
                item.task = task
            }
            for text in comments {
                let comment = TaskComment(text: text, author: task.assignee?.name ?? "ทีม")
                context.insert(comment)
                comment.task = task
            }
        }

        let todos = [
            TodoItem(title: "สรุป KPI รายสัปดาห์ส่งหัวหน้า", dueDate: nextWeekday(6), priority: .high),
            TodoItem(title: "ประชุมทีมเช้าวันจันทร์", dueDate: nextWeekday(2), priority: .normal),
            TodoItem(title: "ขอไฟล์โลโก้ใหม่จาก Seah Engineering", priority: .normal),
            TodoItem(title: "อัปเดตปฏิทินคอนเทนต์เดือนหน้า", priority: .low),
        ]
        todos.forEach { context.insert($0) }

        try? context.save()
    }

    /// Removes every record from the store.
    @MainActor
    static func deleteAll(in context: ModelContext) {
        try? context.delete(model: ChecklistItem.self)
        try? context.delete(model: TaskComment.self)
        try? context.delete(model: TaskItem.self)
        try? context.delete(model: TodoItem.self)
        try? context.delete(model: TeamMember.self)
        try? context.delete(model: Brand.self)
        try? context.save()
    }

    /// The next date (today included) that falls on the given weekday (1 = Sunday).
    private static func nextWeekday(_ weekday: Int) -> Date {
        let cal = AppCalendar.shared
        let today = cal.startOfDay(for: .now)
        if cal.component(.weekday, from: today) == weekday { return today }
        return cal.nextDate(after: today, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime) ?? today
    }
}
