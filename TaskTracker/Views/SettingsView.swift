import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TeamMember.name) private var members: [TeamMember]
    @Query(sort: \Brand.name) private var brands: [Brand]
    @AppStorage("userName") private var userName = "Hannah"
    @AppStorage("teamName") private var teamName = "Digital Marketing Team"

    @State private var editingMember: TeamMember?
    @State private var addingMember = false
    @State private var editingBrand: Brand?
    @State private var addingBrandKind: BrandKind?
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("โปรไฟล์") {
                    TextField("ชื่อของคุณ", text: $userName)
                    TextField("ชื่อทีม", text: $teamName)
                }

                Section("สมาชิกทีม") {
                    ForEach(members) { member in
                        Button {
                            editingMember = member
                        } label: {
                            HStack {
                                AvatarView(name: member.name, colorIndex: member.colorIndex, size: 30)
                                VStack(alignment: .leading) {
                                    Text(member.name).foregroundStyle(.primary)
                                    if !member.role.isEmpty {
                                        Text(member.role).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.forEach { context.delete(members[$0]) }
                    }
                    Button {
                        addingMember = true
                    } label: {
                        Label("เพิ่มสมาชิก", systemImage: "person.badge.plus")
                    }
                }

                ForEach(BrandKind.allCases) { kind in
                    let list = brands.filter { $0.kind == kind }
                    Section(kind.title) {
                        ForEach(list) { brand in
                            Button {
                                editingBrand = brand
                            } label: {
                                HStack {
                                    Circle().fill(Palette.color(brand.colorIndex)).frame(width: 10, height: 10)
                                    Text(brand.name).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(brand.tasks.count) งาน").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets.forEach { context.delete(list[$0]) }
                        }
                        Button {
                            addingBrandKind = kind
                        } label: {
                            Label("เพิ่ม\(kind.title)", systemImage: "plus")
                        }
                    }
                }

                Section("ข้อมูล") {
                    Button("โหลดข้อมูลตัวอย่าง") {
                        SampleData.load(into: context)
                    }
                    Button("ลบข้อมูลทั้งหมด", role: .destructive) {
                        confirmingReset = true
                    }
                }
            }
            .navigationTitle("ตั้งค่า")
            .sheet(item: $editingMember) { member in
                MemberEditorView(member: member)
            }
            .sheet(isPresented: $addingMember) {
                MemberEditorView(member: nil)
            }
            .sheet(item: $editingBrand) { brand in
                BrandEditorView(brand: brand, kind: brand.kind)
            }
            .sheet(item: $addingBrandKind) { kind in
                BrandEditorView(brand: nil, kind: kind)
            }
            .confirmationDialog(
                "ลบงาน, To-Do, สมาชิก และแบรนด์ทั้งหมด?",
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button("ลบทั้งหมด", role: .destructive) {
                    SampleData.deleteAll(in: context)
                }
            }
        }
    }
}

struct MemberEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let member: TeamMember?
    @State private var name: String
    @State private var role: String
    @State private var colorIndex: Int

    init(member: TeamMember?) {
        self.member = member
        _name = State(initialValue: member?.name ?? "")
        _role = State(initialValue: member?.role ?? "")
        _colorIndex = State(initialValue: member?.colorIndex ?? Int.random(in: 0..<Palette.colors.count))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AvatarView(name: name.isEmpty ? "?" : name, colorIndex: colorIndex, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("ชื่อ", text: $name)
                    TextField("ตำแหน่ง", text: $role)
                }
                Section("สี") {
                    ColorDotPicker(selection: $colorIndex)
                }
            }
            .navigationTitle(member == nil ? "สมาชิกใหม่" : "แก้ไขสมาชิก")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        let target: TeamMember
                        if let member {
                            target = member
                        } else {
                            target = TeamMember(name: "")
                            context.insert(target)
                        }
                        target.name = name.trimmingCharacters(in: .whitespaces)
                        target.role = role.trimmingCharacters(in: .whitespaces)
                        target.colorIndex = colorIndex
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct BrandEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let brand: Brand?
    @State private var name: String
    @State private var kind: BrandKind
    @State private var colorIndex: Int

    init(brand: Brand?, kind: BrandKind) {
        self.brand = brand
        _name = State(initialValue: brand?.name ?? "")
        _kind = State(initialValue: kind)
        _colorIndex = State(initialValue: brand?.colorIndex ?? Int.random(in: 0..<Palette.colors.count))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ชื่อแบรนด์ / ลูกค้า", text: $name)
                    Picker("ประเภท", selection: $kind) {
                        ForEach(BrandKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("สี") {
                    ColorDotPicker(selection: $colorIndex)
                }
            }
            .navigationTitle(brand == nil ? "เพิ่มใหม่" : "แก้ไข")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        let target: Brand
                        if let brand {
                            target = brand
                        } else {
                            target = Brand(name: "", kind: kind)
                            context.insert(target)
                        }
                        target.name = name.trimmingCharacters(in: .whitespaces)
                        target.kind = kind
                        target.colorIndex = colorIndex
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
