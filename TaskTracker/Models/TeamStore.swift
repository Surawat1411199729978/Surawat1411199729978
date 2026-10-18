import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import Observation

/// Live, shared team data backed by Firestore.
///
/// Layout: `teams/{code}` holds the team name; `members`, `brands` and `tasks` are subcollections.
/// Anyone signed in who knows the team code can read and write it (see firestore.rules).
/// Writes are applied locally first, so the UI updates instantly and works offline.
@Observable
final class TeamStore {
    enum Phase: Equatable {
        case starting
        case needsTeam
        case ready
        case failed(String)
    }

    enum StoreError: LocalizedError {
        case teamNotFound

        var errorDescription: String? {
            switch self {
            case .teamNotFound: "ไม่พบทีมนี้ ตรวจสอบรหัสทีมอีกครั้ง"
            }
        }
    }

    static var isFirebaseConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    private static let teamCodeKey = "teamCode"

    var phase: Phase = .starting
    var teamName = ""
    var members: [TeamMember] = []
    var brands: [Brand] = []
    var tasks: [TaskItem] = []
    var lastError: String?
    private(set) var teamCode: String

    @ObservationIgnored private var listeners: [ListenerRegistration] = []

    private var db: Firestore { Firestore.firestore() }

    init() {
        teamCode = UserDefaults.standard.string(forKey: Self.teamCodeKey) ?? ""
    }

    // MARK: - Lifecycle

    @MainActor
    func start() async {
        phase = .starting
        do {
            if Auth.auth().currentUser == nil {
                _ = try await Auth.auth().signInAnonymously()
            }
            if teamCode.isEmpty {
                phase = .needsTeam
            } else {
                attachListeners()
                phase = .ready
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func createTeam(name: String, yourName: String, withSampleData: Bool) async throws {
        let code = Self.makeTeamCode()
        try await db.collection("teams").document(code).setData([
            "name": name,
            "createdAt": Timestamp(date: .now),
        ])
        useTeam(code)
        var takenNames: [String] = []
        if withSampleData {
            takenNames = loadSampleData().map(\.name)
        }
        if !takenNames.contains(yourName) {
            save(TeamMember(name: yourName, colorIndex: Int.random(in: 0..<Palette.colors.count)))
        }
    }

    @MainActor
    func joinTeam(code rawCode: String, yourName: String) async throws {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { throw StoreError.teamNotFound }
        let snapshot = try await db.collection("teams").document(code).getDocument()
        guard snapshot.exists else { throw StoreError.teamNotFound }

        let existing = try await db.collection("teams").document(code).collection("members")
            .whereField("name", isEqualTo: yourName)
            .getDocuments()
        useTeam(code)
        if existing.documents.isEmpty {
            save(TeamMember(name: yourName, colorIndex: Int.random(in: 0..<Palette.colors.count)))
        }
    }

    func leaveTeam() {
        detachListeners()
        teamCode = ""
        teamName = ""
        members = []
        brands = []
        tasks = []
        UserDefaults.standard.removeObject(forKey: Self.teamCodeKey)
        phase = .needsTeam
    }

    private func useTeam(_ code: String) {
        teamCode = code
        UserDefaults.standard.set(code, forKey: Self.teamCodeKey)
        attachListeners()
        phase = .ready
    }

    private func attachListeners() {
        detachListeners()
        let team = db.collection("teams").document(teamCode)

        listeners.append(team.addSnapshotListener { [weak self] snapshot, error in
            if let error { self?.report(error) }
            self?.teamName = snapshot?.data()?["name"] as? String ?? ""
        })
        listeners.append(listen(team.collection("members")) { [weak self] (items: [TeamMember]) in
            self?.members = items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        })
        listeners.append(listen(team.collection("brands")) { [weak self] (items: [Brand]) in
            self?.brands = items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        })
        listeners.append(listen(team.collection("tasks")) { [weak self] (items: [TaskItem]) in
            self?.tasks = items.sorted { $0.dueDate < $1.dueDate }
        })
    }

    private func detachListeners() {
        listeners.forEach { $0.remove() }
        listeners = []
    }

    /// Snapshot listener callbacks are delivered on the main queue.
    private func listen<T: Decodable>(
        _ query: Query,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        query.addSnapshotListener { [weak self] snapshot, error in
            if let error { self?.report(error) }
            guard let snapshot else { return }
            onChange(snapshot.documents.compactMap { try? $0.data(as: T.self) })
        }
    }

    private func report(_ error: Error?) {
        guard let error else { return }
        lastError = error.localizedDescription
    }

    private func collection(_ name: String) -> CollectionReference {
        db.collection("teams").document(teamCode).collection(name)
    }

    private func write<T: Encodable & Identifiable>(_ value: T, to name: String) where T.ID == String {
        do {
            try collection(name).document(value.id).setData(from: value) { [weak self] in self?.report($0) }
        } catch {
            report(error)
        }
    }

    private func remove(_ id: String, from name: String) {
        collection(name).document(id).delete { [weak self] in self?.report($0) }
    }

    // MARK: - Lookups

    func member(_ id: String?) -> TeamMember? {
        guard let id else { return nil }
        return members.first { $0.id == id }
    }

    func brand(_ id: String?) -> Brand? {
        guard let id else { return nil }
        return brands.first { $0.id == id }
    }

    func task(_ id: String) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    // MARK: - Tasks

    func save(_ task: TaskItem) {
        var task = task
        task.updatedAt = .now
        write(task, to: "tasks")
    }

    func delete(_ task: TaskItem) {
        remove(task.id, from: "tasks")
    }

    /// Updates only the given fields, so teammates editing other fields at the same time are not overwritten.
    private func update(_ task: TaskItem, _ fields: [String: Any]) {
        var fields = fields
        fields["updatedAt"] = Timestamp(date: .now)
        collection("tasks").document(task.id).updateData(fields) { [weak self] in self?.report($0) }
    }

    func setStatus(_ status: TaskStatus, for task: TaskItem) {
        update(task, ["status": status.rawValue])
    }

    func setRevisions(client: Int, internal internalCount: Int, for task: TaskItem) {
        update(task, ["clientRevisions": client, "internalRevisions": internalCount])
    }

    func setChecklist(_ checklist: [ChecklistItem], for task: TaskItem) {
        do {
            let encoded = try checklist.map { try Firestore.Encoder().encode($0) }
            update(task, ["checklist": encoded])
        } catch {
            report(error)
        }
    }

    func addComment(_ comment: TaskComment, to task: TaskItem) {
        do {
            let encoded = try Firestore.Encoder().encode(comment)
            update(task, ["comments": FieldValue.arrayUnion([encoded])])
        } catch {
            report(error)
        }
    }

    func setComments(_ comments: [TaskComment], for task: TaskItem) {
        do {
            let encoded = try comments.map { try Firestore.Encoder().encode($0) }
            update(task, ["comments": encoded])
        } catch {
            report(error)
        }
    }

    // MARK: - Members & brands

    func save(_ member: TeamMember) {
        write(member, to: "members")
    }

    func delete(_ member: TeamMember) {
        remove(member.id, from: "members")
    }

    func save(_ brand: Brand) {
        write(brand, to: "brands")
    }

    func delete(_ brand: Brand) {
        remove(brand.id, from: "brands")
    }

    // MARK: - Bulk

    /// Writes the demo data to the team and returns the members it added.
    @discardableResult
    func loadSampleData() -> [TeamMember] {
        let data = SampleData.teamData()
        let batch = db.batch()
        do {
            for member in data.members {
                _ = try batch.setData(from: member, forDocument: collection("members").document(member.id))
            }
            for brand in data.brands {
                _ = try batch.setData(from: brand, forDocument: collection("brands").document(brand.id))
            }
            for task in data.tasks {
                _ = try batch.setData(from: task, forDocument: collection("tasks").document(task.id))
            }
        } catch {
            report(error)
            return []
        }
        batch.commit { [weak self] in self?.report($0) }
        return data.members
    }

    func deleteAllTeamData() {
        let batch = db.batch()
        for task in tasks {
            _ = batch.deleteDocument(collection("tasks").document(task.id))
        }
        for member in members {
            _ = batch.deleteDocument(collection("members").document(member.id))
        }
        for brand in brands {
            _ = batch.deleteDocument(collection("brands").document(brand.id))
        }
        batch.commit { [weak self] in self?.report($0) }
    }

    /// Eight characters without look-alikes (0/O, 1/I), easy to read out to teammates.
    private static func makeTeamCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }
}
