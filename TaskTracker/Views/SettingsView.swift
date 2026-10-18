import SwiftUI

struct SettingsView: View {
    @Environment(TeamStore.self) private var store
    @AppStorage("userName") private var userName = ""

    @State private var editingMember: TeamMember?
    @State private var addingMember = false
    @State private var editingBrand: Brand?
    @State private var addingBrandKind: BrandKind?
    @State private var confirmingReset = false
    @State private var confirmingLeave = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("ชื่อทีม", value: store.teamName)
                    LabeledContent("รหัสทีม") {
                        Text(store.teamCode)
                            .font(.body.monospaced().bold())
                            .textSelection(.enabled)
                    }
                    ShareLink(
                        item: "เข้าร่วมทีม \"\(store.teamName)\" ในแอพ Team Tasks ด้วยรหัส: \(store.teamCode)"
                    ) {
                        Label("แชร์รหัสทีมให้เพื่อนร่วมทีม", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("ทีม")
                } footer: {
                    Text("ใครมีรหัสทีมจะเห็นและแก้ไขงานของทีมได้ แชร์ให้เฉพาะคนในทีม")
                }

                Section("โปรไฟล์") {
                    TextField("ชื่อของคุณ (ใช้แสดงในความคิดเห็น)", text: $userName)
                }

                Section("สมาชิกทีม") {
                    ForEach(store.members) { member in
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
                        offsets.map { store.members[$0] }.forEach { store.delete($0) }
                    }
                    Button {
                        addingMember = true
                    } label: {
                        Label("เพิ่มสมาชิก", systemImage: "person.badge.plus")
                    }
                }

                ForEach(BrandKind.allCases) { kind in
                    let list = store.brands.filter { $0.kind == kind }
                    Section(kind.title) {
                        ForEach(list) { brand in
                            Button {
                                editingBrand = brand
                            } label: {
                                HStack {
                                    Circle().fill(Palette.color(brand.colorIndex)).frame(width: 10, height: 10)
                                    Text(brand.name).foregroundStyle(.primary)
                                    Spacer()
                                    let count = store.tasks.filter { $0.brandID == brand.id }.count
                                    Text("\(count) งาน").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { list[$0] }.forEach { store.delete($0) }
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
                        store.loadSampleData()
                    }
                    Button("ลบงาน สมาชิก และแบรนด์ทั้งหมดของทีม", role: .destructive) {
                        confirmingReset = true
                    }
                    Button("ออกจากทีมนี้", role: .destructive) {
                        confirmingLeave = true
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
                "ลบข้อมูลทั้งหมดของทีม? ทุกคนในทีมจะไม่เห็นข้อมูลนี้อีก",
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button("ลบทั้งหมด", role: .destructive) {
                    store.deleteAllTeamData()
                }
            }
            .confirmationDialog(
                "ออกจากทีม? ข้อมูลของทีมจะยังอยู่ และกลับเข้ามาได้ด้วยรหัสทีม \(store.teamCode)",
                isPresented: $confirmingLeave,
                titleVisibility: .visible
            ) {
                Button("ออกจากทีม", role: .destructive) {
                    store.leaveTeam()
                }
            }
        }
    }
}

struct MemberEditorView: View {
    @Environment(TeamStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: TeamMember
    private let isNew: Bool

    init(member: TeamMember?) {
        isNew = member == nil
        _draft = State(initialValue: member ?? TeamMember(name: "", colorIndex: Int.random(in: 0..<Palette.colors.count)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AvatarView(name: draft.name.isEmpty ? "?" : draft.name, colorIndex: draft.colorIndex, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("ชื่อ", text: $draft.name)
                    TextField("ตำแหน่ง", text: $draft.role)
                }
                Section("สี") {
                    ColorDotPicker(selection: $draft.colorIndex)
                }
            }
            .navigationTitle(isNew ? "สมาชิกใหม่" : "แก้ไขสมาชิก")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        var member = draft
                        member.name = member.name.trimmingCharacters(in: .whitespaces)
                        member.role = member.role.trimmingCharacters(in: .whitespaces)
                        store.save(member)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct BrandEditorView: View {
    @Environment(TeamStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Brand
    private let isNew: Bool

    init(brand: Brand?, kind: BrandKind) {
        isNew = brand == nil
        _draft = State(initialValue: brand ?? Brand(name: "", kind: kind, colorIndex: Int.random(in: 0..<Palette.colors.count)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ชื่อแบรนด์ / ลูกค้า", text: $draft.name)
                    Picker("ประเภท", selection: $draft.kind) {
                        ForEach(BrandKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("สี") {
                    ColorDotPicker(selection: $draft.colorIndex)
                }
            }
            .navigationTitle(isNew ? "เพิ่มใหม่" : "แก้ไข")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        var brand = draft
                        brand.name = brand.name.trimmingCharacters(in: .whitespaces)
                        store.save(brand)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
