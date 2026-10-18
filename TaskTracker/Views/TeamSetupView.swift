import SwiftUI

struct TeamSetupView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case join, create
        var id: String { rawValue }
        var title: String {
            switch self {
            case .join: "เข้าร่วมทีม"
            case .create: "สร้างทีมใหม่"
            }
        }
    }

    @Environment(TeamStore.self) private var store
    @AppStorage("userName") private var userName = ""

    @State private var mode: Mode = .join
    @State private var teamCode = ""
    @State private var teamName = "Digital Marketing Team"
    @State private var withSampleData = true
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var trimmedName: String {
        userName.trimmingCharacters(in: .whitespaces)
    }

    private var canSubmit: Bool {
        guard !trimmedName.isEmpty, !isWorking else { return false }
        switch mode {
        case .join: return !teamCode.trimmingCharacters(in: .whitespaces).isEmpty
        case .create: return !teamName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                        Text("ติดตามงานร่วมกับทีม")
                            .font(.title2.bold())
                        Text("ทุกคนในทีมจะเห็นงานชุดเดียวกันแบบ real-time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("ชื่อของคุณ") {
                    TextField("เช่น Hannah", text: $userName)
                        .textContentType(.givenName)
                }

                Section {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                switch mode {
                case .join:
                    Section {
                        TextField("รหัสทีม 8 ตัวอักษร", text: $teamCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.title3.monospaced())
                    } header: {
                        Text("รหัสทีม")
                    } footer: {
                        Text("ขอรหัสจากคนที่สร้างทีม (อยู่ในแท็บตั้งค่าของเขา)")
                    }
                case .create:
                    Section {
                        TextField("ชื่อทีม", text: $teamName)
                        Toggle("เริ่มด้วยข้อมูลตัวอย่าง", isOn: $withSampleData)
                    } header: {
                        Text("ทีมใหม่")
                    } footer: {
                        Text("หลังสร้างทีม จะได้รหัสทีมไว้แชร์ให้เพื่อนร่วมทีม")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView()
                            } else {
                                Text(mode.title).bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Team Tasks")
        }
    }

    private func submit() {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                switch mode {
                case .join:
                    try await store.joinTeam(code: teamCode, yourName: trimmedName)
                case .create:
                    try await store.createTeam(
                        name: teamName.trimmingCharacters(in: .whitespaces),
                        yourName: trimmedName,
                        withSampleData: withSampleData
                    )
                }
                userName = trimmedName
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
