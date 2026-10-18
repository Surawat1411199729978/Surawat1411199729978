import Foundation
import SwiftData

enum SampleData {
    /// A demo team, brands and tasks for the current month.
    static func teamData() -> (members: [TeamMember], brands: [Brand], tasks: [TaskItem]) {
        let hannah = TeamMember(name: "Hannah", role: "Digital Marketing Manager", colorIndex: 2)
        let erianne = TeamMember(name: "Erianne", role: "Graphic Designer", colorIndex: 1)
        let donald = TeamMember(name: "Donald", role: "Content Creator", colorIndex: 0)
        let patrick = TeamMember(name: "Patrick", role: "Video Editor", colorIndex: 3)

        let jysigma = Brand(name: "JYSigma Business Consultancy", kind: .inHouse, colorIndex: 0)
        let jca = Brand(name: "JCA", kind: .inHouse, colorIndex: 2)
        let gthRise = Brand(name: "GTH Rise", kind: .inHouse, colorIndex: 5)
        let gthAsia = Brand(name: "GTH Asia", kind: .inHouse, colorIndex: 6)
        let jbc = Brand(name: "JBC", kind: .inHouse, colorIndex: 4)
        let jackYang = Brand(name: "Jack Yang", kind: .inHouse, colorIndex: 8)
        let seah = Brand(name: "Seah Engineering", kind: .client, colorIndex: 6)
        let eclipse = Brand(name: "Eclipse Steakhouse", kind: .client, colorIndex: 8)

        func day(_ d: Int) -> Date {
            let cal = AppCalendar.shared
            var comps = cal.dateComponents([.year, .month], from: .now)
            comps.day = d
            comps.hour = 10
            return cal.date(from: comps) ?? .now
        }

        func task(
            _ title: String, _ d: Int, _ status: TaskStatus, _ action: TaskAction, _ material: MaterialType,
            _ member: TeamMember, _ brand: Brand, output: Bool = false,
            checklist: [String] = [], comments: [String] = []
        ) -> TaskItem {
            var item = TaskItem(title: title, dueDate: day(d))
            item.status = status
            item.action = action
            item.material = material
            item.assigneeID = member.id
            item.brandID = brand.id
            item.materialsURL = "https://drive.google.com"
            item.outputURL = output ? "https://drive.google.com" : ""
            item.checklist = checklist.enumerated().map { ChecklistItem(title: $1, isDone: $0 == 0) }
            item.comments = comments.map { TaskComment(text: $0, author: member.name) }
            return item
        }

        let tasks: [TaskItem] = [
            task("Launch announcement copy", 1, .posted, .create, .copywriting, hannah, gthRise, output: true,
                 checklist: ["ร่างข้อความ", "ส่งให้ลูกค้าตรวจ"], comments: ["ลูกค้าอนุมัติแล้ว"]),
            task("Private dinner ad visual", 1, .forReview, .create, .staticDesign, erianne, jbc, output: true,
                 checklist: ["ทำ 2 เวอร์ชัน", "ปรับสีตาม CI"], comments: ["ขอปรับโทนสี", "แก้ไขแล้ว", "รอลูกค้าดู"]),
            task("Aircon tips carousel", 2, .scheduled, .schedule, .carousel, donald, seah, output: true,
                 comments: ["ตั้งเวลาโพสต์ 18:00", "โอเค"]),
            task("Founder story reel", 2, .inProgress, .create, .reel, patrick, jackYang,
                 checklist: ["ตัดต่อ", "ใส่ซับไตเติล", "ใส่เพลง"], comments: ["รอฟุตเทจเพิ่ม"]),
            task("Services carousel", 5, .inProgress, .create, .carousel, erianne, jca,
                 checklist: ["วางเลย์เอาต์", "ใส่ไอคอน"]),
            task("Q4 update post", 6, .posted, .post, .staticDesign, donald, gthAsia, output: true),
            task("Investor explainer slides", 8, .inProgress, .create, .slides, hannah, jbc,
                 checklist: ["โครงเรื่อง", "ออกแบบสไลด์", "ตรวจตัวเลข"]),
            task("Steakhouse weekend promo", 14, .forReview, .create, .staticDesign, erianne, eclipse),
            task("Consultancy LinkedIn article", 20, .inProgress, .create, .copywriting, hannah, jysigma,
                 checklist: ["หาข้อมูล", "เขียนร่างแรก"]),
            task("Halloween reel", 27, .scheduled, .schedule, .reel, patrick, gthRise, output: true),
        ]

        return (
            [hannah, erianne, donald, patrick],
            [jysigma, jca, gthRise, gthAsia, jbc, jackYang, seah, eclipse],
            tasks
        )
    }

    /// Inserts a few personal to-dos into the on-device store.
    @MainActor
    static func loadTodos(into context: ModelContext) {
        let todos = [
            TodoItem(title: "สรุป KPI รายสัปดาห์ส่งหัวหน้า", dueDate: nextWeekday(6), priority: .high),
            TodoItem(title: "ประชุมทีมเช้าวันจันทร์", dueDate: nextWeekday(2), priority: .normal),
            TodoItem(title: "ขอไฟล์โลโก้ใหม่จาก Seah Engineering", priority: .normal),
            TodoItem(title: "อัปเดตปฏิทินคอนเทนต์เดือนหน้า", priority: .low),
        ]
        todos.forEach { context.insert($0) }
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
