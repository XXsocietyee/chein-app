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
    @Environment(\.cyPalette) private var palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader("context.rules.title")
                CYNoteBanner(text: Text("context.rules.notice"), symbol: "info.circle", tone: .info)
                ForEach(sections, id: \.0) { section in
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CYSectionHeader(LocalizedStringKey("context.rules." + section.0))
                        ForEach(section.1, id: \.self) { row in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(LocalizedStringKey("context.rules." + section.0 + "." + row + ".title"))
                                    .font(CYTypography.cardTitle)
                                    .foregroundStyle(palette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(LocalizedStringKey("context.rules." + section.0 + "." + row + ".body"))
                                    .font(CYTypography.body)
                                    .foregroundStyle(palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cyDomainCard()
                        }
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .accessibilityIdentifier("club.context.rules")
        .cyDomainScreen(.player)
    }
}

@MainActor struct ClubOpsTimeView: View {
    @Environment(\.cyPalette) private var palette
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
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                CYHeroHeader("context.ops.title")
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Text("context.ops.policy")
                        .font(CYTypography.body)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("context.ops.timezone")
                        .font(CYTypography.meta)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    DatePicker("context.ops.time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!)
                        .disabled(busy || state == .unknown)
                    if let serverDate {
                        LabeledContent("context.ops.serverTime") {
                            Text(verbatim: serverDate).monospacedDigit()
                        }
                    }
                }
                .cyDomainCard()
                if owner?.service.isConfigured != true {
                    CYNoteBanner(text: Text("context.ops.disabled"), symbol: "nosign", tone: .neutral)
                }
                if state == .unknown {
                    CYNoteBanner(text: Text("context.ops.unknown"), symbol: "clock", tone: .warning)
                }
                if state == .acknowledged {
                    CYNoteBanner(text: Text("context.ops.acknowledged"), symbol: "checkmark.circle", tone: .success)
                }
                if state == .rejected {
                    CYNoteBanner(text: Text("context.ops.rejected"), symbol: "exclamationmark.circle", tone: .danger)
                }
                if readFailed {
                    CYNoteBanner(text: Text("context.ops.readFailed"), symbol: "arrow.clockwise", tone: .warning)
                }
                if busy {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        .accessibilityLabel(Text("club.loading"))
                }
                CYPillButton("context.review.preview", systemImage: "eye") {
                    review = try? ClubOpsTimeRequest(activityID: activityID, startDate: ClubOpsTimeRequest.submissionTime(date))
                    captured = owner?.service.session
                }
                .disabled(!canPreview)
                if owner?.service.isConfigured == true {
                    CYPillButton("context.ops.readback", style: .secondary, systemImage: "arrow.clockwise") {
                        Task { await readback() }
                    }
                    .disabled(busy)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .cyDomainPageBackground()
        .confirmationDialog("context.ops.confirm", isPresented: Binding(get: { review != nil }, set: { if !$0 { review = nil; captured = nil } })) {
            Button("context.ops.save") { Task { await save() } }.disabled(owner?.canSave != true)
            Button("action.cancel", role: .cancel) { review = nil; captured = nil }
        } message: { if let review { Text(verbatim: review.startDate) } }
        .onChange(of: owner?.service.session) { _, _ in review = nil; captured = nil; serverDate = nil; revision += 1 }
        .cyHaptic(.success, trigger: state) { _, new in new == .acknowledged }
        .cyHaptic(.warning, trigger: state) { _, new in new == .rejected }
        .cyDomainScreen(.player)
    }
    private func save() async {
        guard let owner, let review, let captured, owner.service.session == captured else { return }
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
