import SwiftUI

private struct ClubOpsTimeFactoryKey: EnvironmentKey {
    static let defaultValue: ((Int) -> ClubOpsTimeCoordinator?)? = nil
}
extension EnvironmentValues {
    var clubOpsTimeFactory: ((Int) -> ClubOpsTimeCoordinator?)? {
        get { self[ClubOpsTimeFactoryKey.self] }
        set { self[ClubOpsTimeFactoryKey.self] = newValue }
    }
}
struct ClubOperatingRulesView: View {
    private let sections: [(String, [String])] = [
        ("leaveClub", ["owner", "membership", "chat"]),
        ("leaveTeam", ["last", "captain", "member"]),
        ("refund", ["redeemed", "deadline", "window", "missing"]),
        ("pause", ["reason", "backup", "blocked", "scope", "fallback", "resume"]),
        ("cancel", ["whole"])]
    var body: some View {
        List {
            Section {
                Label("context.rules.notice", systemImage: "info.circle")
            }
            ForEach(sections, id: \.0) { section in
                Section {
                    ForEach(section.1, id: \.self) { row in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(LocalizedStringKey("context.rules." + section.0 + "." + row + ".title"))
                                .font(.headline)
                            Text(LocalizedStringKey("context.rules." + section.0 + "." + row + ".body"))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("context.rules." + section.0))
                }
            }
        }
        .navigationTitle(Text("context.rules.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("club.context.rules")
        .cyDomainScreen(.player)
    }
}

@MainActor struct ClubOpsTimeView: View {
    let activityID: Int
    let original: String
    let owner: ClubOpsTimeCoordinator?
    let onReadback: () -> Void
    @State private var date: Date
    @State private var review: ClubOpsTimeRequest?
    @State private var captured: ClubOpsTimeSession?
    @State private var busy = false
    @State private var revision = 0
    @State private var serverDate: String?
    @State private var readFailed = false
    init(activityID: Int, original: String, owner: ClubOpsTimeCoordinator?, onReadback: @escaping () -> Void) {
        self.activityID = activityID; self.original = original; self.owner = owner; self.onReadback = onReadback
        _date = State(initialValue: ClubOpsTimeRequest.date(original) ?? Date())
    }
    private var state: ClubOpsTimeState { let _ = revision; return owner?.state ?? .idle }
    private var canPreview: Bool { !busy && state != .unknown && ClubOpsTimeRequest.date(original) != nil }
    var body: some View {
        Form {
            Section {
                Text("context.ops.policy")
                DatePicker("context.ops.time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!)
                    .disabled(busy || state == .unknown)
                if let serverDate {
                    LabeledContent("context.ops.serverTime") {
                        Text(verbatim: serverDate).monospacedDigit()
                    }
                }
            } footer: {
                Text("context.ops.timezone")
            }
            if owner?.service.isConfigured != true || state == .unknown || state == .acknowledged || state == .rejected || readFailed {
                Section {
                    if owner?.service.isConfigured != true {
                        Label("context.ops.disabled", systemImage: "nosign").foregroundStyle(.secondary)
                    }
                    if state == .unknown {
                        Label("context.ops.unknown", systemImage: "clock").foregroundStyle(.orange)
                    }
                    if state == .acknowledged {
                        Label("context.ops.acknowledged", systemImage: "checkmark.circle").foregroundStyle(.green)
                    }
                    if state == .rejected {
                        Label("context.ops.rejected", systemImage: "exclamationmark.circle").foregroundStyle(.red)
                    }
                    if readFailed {
                        Label("context.ops.readFailed", systemImage: "arrow.clockwise").foregroundStyle(.orange)
                    }
                }
            }
            Section {
                if busy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("club.loading"))
                }
                Button {
                    review = try? ClubOpsTimeRequest(activityID: activityID, startDate: ClubOpsTimeRequest.submissionTime(date))
                    captured = owner?.service.session
                } label: {
                    Label("context.review.preview", systemImage: "eye")
                }
                .disabled(!canPreview)
                if owner?.service.isConfigured == true {
                    Button {
                        Task { await readback() }
                    } label: {
                        Label("context.ops.readback", systemImage: "arrow.clockwise")
                    }
                    .disabled(busy)
                }
            }
        }
        .navigationTitle(Text("context.ops.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(Text("context.ops.confirm"),
               isPresented: Binding(get: { review != nil }, set: { if !$0 { review = nil; captured = nil } }),
               presenting: review) { pending in
            Button("action.cancel", role: .cancel) {
                self.review = nil
                captured = nil
            }
            Button("context.ops.save") {
                // The alert clears `review` as it closes: hand the reviewed request and session to the save.
                let session = captured
                Task { await save(pending, captured: session) }
            }
            .disabled(owner?.canSave != true)
        } message: { pending in
            Text(verbatim: pending.startDate)
        }
        .onChange(of: owner?.service.session) { _, _ in review = nil; captured = nil; serverDate = nil; revision += 1 }
        .cyHaptic(.success, trigger: state) { _, new in new == .acknowledged }
        .cyHaptic(.warning, trigger: state) { _, new in new == .rejected }
        .cyDomainScreen(.player)
    }
    private func save(_ review: ClubOpsTimeRequest, captured: ClubOpsTimeSession?) async {
        guard let owner, owner.canSave, let captured, owner.service.session == captured else { return }
        busy = true; await owner.save(review, expected: captured); busy = false; self.review = nil; revision += 1
        guard owner.service.session == captured else { return }
        if state == .acknowledged || state == .unknown { await readback(); onReadback() }
    }
    private func readback() async {
        guard let owner, let session = owner.service.session else { return }
        busy = true; readFailed = false
        defer { busy = false }
        do {
            let value = try await owner.service.read(activityID: activityID, session: session)
            guard owner.service.session == session, !Task.isCancelled else { return }; serverDate = value
        } catch { if owner.service.session == session { readFailed = true } }
    }
}
