import SwiftUI

@MainActor final class TeamScreenModel: ObservableObject {
    struct RunPermit: Equatable { fileprivate let presentationID: UUID }
    struct InviteCopyPermit: Equatable {
        fileprivate let presentationID: UUID
        fileprivate let scope: UUID
        fileprivate let previewID: UUID
    }
    private var inviteCopyPermit: InviteCopyPermit?
    let coordinator: TeamCoordinator
    @Published private(set) var running = false
    private var presentationID = UUID()
    private var runID: UUID?
    init(_ coordinator: TeamCoordinator) { self.coordinator = coordinator }
    /// Capture synchronously in a button action, before creating its unstructured Task.
    func captureRun() -> RunPermit { .init(presentationID: presentationID) }
    /// Structured view tasks may omit a permit: their cancellation is checked at entry.
    @discardableResult func run(permit: RunPermit? = nil, _ operation: () async -> Void) async -> Bool {
        guard !running, !Task.isCancelled,
              permit == nil || permit?.presentationID == presentationID else { return false }
        let id = UUID(); runID = id; running = true
        defer {
            // A departed operation may finish after the returning screen starts a
            // fresh read. It must not release that read's loading/action guard.
            if runID == id { runID = nil; running = false }
        }
        await operation()
        return runID == id && !Task.isCancelled
    }
    struct RecoveryCommand: Equatable {
        let key: String
        let targetKey: String
        let fields: [String: String]
    }
    private(set) var recoveryCommand: RecoveryCommand?
    /// Original `api/team/command` input for the recovery card. Query, retry, and cancel share this key and these fields.
    func rememberRecovery(_ action: TeamAction) {
        guard let command = Self.recoveryCommand(for: action) else { return }
        recoveryCommand = command
    }
    func prepare(_ action: TeamAction) { coordinator.prepare(action); objectWillChange.send() }
    static func recoveryCommand(for action: TeamAction) -> RecoveryCommand? {
        switch action {
        case .join(let id, let code):
            guard id > 0 else { return nil }
            let invite = code.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(key: "join-\(id)", targetKey: action.targetKey, fields: ["action": "join", "targetId": String(id), "inviteCode": invite])
        case .leave(let id):
            guard id > 0 else { return nil }
            return .init(key: "quit-\(id)", targetKey: action.targetKey, fields: ["action": "quit", "targetId": String(id)])
        case .remove(let id, let member):
            guard id > 0, member > 0 else { return nil }
            return .init(key: "kick-\(id)-\(member)", targetKey: action.targetKey, fields: ["action": "kick", "targetId": String(id), "memberId": String(member)])
        case .disband(let id):
            guard id > 0 else { return nil }
            return .init(key: "disband-\(id)", targetKey: action.targetKey, fields: ["action": "disband", "targetId": String(id)])
        case .changeJoinMode(let id, let mode):
            guard id > 0, mode != .unknown else { return nil }
            return .init(key: "join-mode-\(id)", targetKey: action.targetKey, fields: ["action": "join-mode", "targetId": String(id), "joinMode": String(mode.rawValue)])
        case .create:
            return nil
        }
    }
    func refuseClosedLease() { coordinator.refuseWhenLeaseClosed(); objectWillChange.send() }
    func cancel() { coordinator.cancelReview(); objectWillChange.send() }
    func leave() {
        // The coordinator retires old results and keeps unresolved write locks.
        // Release only this screen run so re-entry need not await the old transport.
        presentationID = UUID(); runID = nil; inviteCopyPermit = nil
        coordinator.leaveScreen(); running = false; objectWillChange.send()
    }
    func beginInvitePreview() -> InviteCopyPermit {
        coordinator.synchronizeSession()
        let permit = InviteCopyPermit(presentationID: presentationID, scope: coordinator.scope, previewID: UUID())
        inviteCopyPermit = permit
        return permit
    }
    func endInvitePreview(_ permit: InviteCopyPermit?) {
        if inviteCopyPermit == permit { inviteCopyPermit = nil }
    }
    /// Synchronous user-tap boundary. The writer is injected so tests never touch the clipboard.
    func copyInvitationCode(from team: OwnedTeam, code: String, permit: InviteCopyPermit?, write: (String) -> Void) -> Bool {
        coordinator.synchronizeSession()
        objectWillChange.send()
        guard let permit, inviteCopyPermit == permit,
              permit.presentationID == presentationID, permit.scope == coordinator.scope,
              coordinator.authenticated, !actionLocked,
              let current = coordinator.detail?.team,
              current.id == team.id, current.status == .recruiting,
              team.inviteCode == code, current.inviteCode == code,
              TeamLookup.validInvite(code) else { return false }
        write(code)
        return true
    }
    var reviewBinding: Binding<TeamReview?> { Binding(get: { self.coordinator.review }, set: { if $0 == nil { self.cancel() } }) }
    var actionLocked: Bool { running || coordinator.busy || coordinator.pending != nil || coordinator.writeState == .simulated || coordinator.writeState == .acknowledged || coordinator.writeState == .blocked }
}
@MainActor struct TeamNotice: View {
    // Capture value inputs for SwiftUI's child-view diff. The coordinator is not
    // Observable, so retaining only its reference leaves notices stale after writes,
    // invalid links and sign-out even when the parent model publishes a redraw.
    let canSimulate: Bool
    let messageKey: String?
    let hasPending: Bool
    init(coordinator: TeamCoordinator) {
        canSimulate = coordinator.canSimulate
        messageKey = coordinator.messageKey
        hasPending = coordinator.pending != nil
    }
    var body: some View {
        // Only real messages (and the example-content marker) earn a box; no standing "unavailable" banner.
        if canSimulate || messageKey != nil {
        VStack(alignment: .leading, spacing: 8) {
            if canSimulate { Label("team.fixtureNotice", systemImage: "testtube.2").accessibilityIdentifier("team.fixtureNotice") }
            if let key = messageKey {
                Label(LocalizedStringKey(key), systemImage: hasPending ? "exclamationmark.triangle" : "info.circle")
                    .accessibilityIdentifier("team.message")
            }
        }.font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct TeamCard: View {
    let team: OwnedTeam
    var confirmedJoinMode: TeamJoinMode? = nil
    var body: some View {
        QuestifyImageEntityCard(imageSource: nil, title: team.title, fallbackTitle: "team.untitled", fallbackSymbol: "person.3", minimumHeight: 220) {
            Label(LocalizedStringKey(team.status.key), systemImage: "person.2")
            if let joined = team.joinedCount, let max = team.maxMembers {
                QuestifyImageEntityMetadata(label: "team.members.count", value: "\(joined) / \(max)", systemImage: "person.2.fill")
            } else { Text("team.members.unknown") }
            Text(LocalizedStringKey((confirmedJoinMode ?? team.joinMode).key))
        }
    }
}
struct TeamMemberRow: View {
    let member: TeamMember
    var remove: (() -> Void)?
    private var memberAvatarURL: URL? {
        guard let raw = member.memberAvatar?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }
    var body: some View {
        // Mini `.team-member`: 32pt avatar, name (600) over role caption, trailing 移出 in danger text.
        HStack(alignment: .center, spacing: 12) {
            // MP team/detail wxml:102: `memberAvatar || /images/d_profile.png` (r9 Team avatars).
            Group {
                if let url = memberAvatarURL {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                        MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
                    }
                } else {
                    MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
                }
            }
            .frame(width: 32, height: 32).clipShape(Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if member.name.isEmpty { Text("team.member.unnamed") } else { Text(verbatim: member.name).fixedSize(horizontal: false, vertical: true) }
                }
                Text(member.isCaptain ? "team.member.captain" : member.role == 0 ? "team.member.player" : "team.member.unknownRole").font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let remove { Button("team.remove", role: .destructive, action: remove).accessibilityIdentifier("team.remove.\(member.id)") }
        }
    }
}
@MainActor struct TeamReviewSheet: View {
    @ObservedObject var model: TeamScreenModel
    let review: TeamReview
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    private var isDestructiveAction: Bool {
        switch review.action {
        case .leave, .remove, .disband: return true
        case .create, .join, .changeJoinMode: return false
        }
    }

    private var consequenceKeys: [String] {
        switch review.action {
        case .disband:
            return ["team.consequence.disband.1", "team.consequence.disband.2", "team.consequence.disband.3"]
        case .leave:
            return ["team.consequence.leave.1", "team.consequence.leave.2", "team.consequence.leave.3"]
        case .remove:
            return ["team.consequence.remove.1", "team.consequence.remove.2", "team.consequence.remove.3"]
        default:
            return []
        }
    }

    private var actionTitle: String {
        switch review.action {
        case .disband: return appLocalized("team.disband", locale: locale)
        case .leave: return appLocalized("team.leave", locale: locale)
        default: return appLocalized(String.LocalizationValue(stringLiteral: review.action.key), locale: locale)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let detail = review.detail {
                    Section {
                        LabeledContent {
                            Text(verbatim: "#\(detail.team.id)")
                        } label: {
                            Text(verbatim: detail.team.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if case .remove(_, let memberID) = review.action, let member = review.detail?.members.first(where: { $0.id == memberID }) {
                    Section {
                        Text(verbatim: member.name)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if case .create(let context, let size, let inviteOnly) = review.action {
                    Section {
                        Text(verbatim: context.title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        LabeledContent("team.size") { Text(verbatim: "\(size)") }
                        Text(inviteOnly ? "team.mode.invitation" : "team.mode.public")
                            .foregroundStyle(.secondary)
                    }
                }
                if case .changeJoinMode(_, let mode) = review.action {
                    Section {
                        LabeledContent {
                            Text(LocalizedStringKey(review.detail?.team.joinMode.key ?? "team.mode.unknown"))
                        } label: { Text(verbatim: locale.language.languageCode?.identifier == "zh" ? "当前方式" : "Current mode") }
                        LabeledContent {
                            Text(LocalizedStringKey(mode.key))
                        } label: { Text(verbatim: locale.language.languageCode?.identifier == "zh" ? "确认后的方式" : "Requested mode") }
                    } footer: {
                        Text(verbatim: locale.language.languageCode?.identifier == "zh"
                            ? "仅更改加入队伍的方式，不变更成员或报名。结果不明时会保留锁定，不自动重试。"
                            : "Only the joining mode changes; membership and registration stay unchanged. An unknown outcome remains locked without automatic retry.")
                    }
                } else if consequenceKeys.isEmpty {
                    Section {
                        Text(LocalizedStringKey(TeamSeatPresentation.consequenceKey(review.action, detail: review.detail)))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Section {
                        ForEach(Array(consequenceKeys.enumerated()), id: \.offset) { idx, key in
                            Label {
                                Text(LocalizedStringKey(key))
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: idx == consequenceKeys.count - 1 ? "exclamationmark.triangle" : "info.circle")
                                    .foregroundStyle(idx == consequenceKeys.count - 1 ? Color.red : Color.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                    } footer: {
                        Text(LocalizedStringKey(TeamSeatPresentation.consequenceKey(review.action, detail: review.detail)))
                    }
                }
                Section {
                    TeamNotice(coordinator: model.coordinator)
                    confirmActionButton
                    if case .disband(let teamID) = review.action {
                        Button {
                            model.prepare(.leave(teamID: teamID))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("team.leaveInstead")
                                Text("team.page.leaveAndTransfer")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .disabled(model.running)
                        .accessibilityIdentifier("team.review.leaveInstead")
                    }
                }
            }
            .navigationTitle(Text(verbatim: actionTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("team.cancel") { model.cancel(); dismiss() }
                        .disabled(model.running)
                        .accessibilityIdentifier("team.review.cancel")
                }
            }
        }
        .interactiveDismissDisabled(model.running)
        .cyDomainSheet(detents: [.half, .full])
    }

    @ViewBuilder private var confirmActionButton: some View {
        let button = Button(LocalizedStringKey(model.coordinator.canSimulate ? "team.simulate" : "team.confirmLive")) {
            let permit = model.captureRun()
            Task {
                guard model.coordinator.review == review else { return }
                model.rememberRecovery(review.action)
                if await model.run(permit: permit, { await model.coordinator.confirm(review) }) { dismiss() }
            }
        }
        .disabled(!model.coordinator.canSubmit || model.running)
        .accessibilityIdentifier("team.review.confirm")
        // A Settings-style row action; the destructive ones read in the system red.
        if isDestructiveAction {
            button.foregroundStyle(.red)
        } else {
            button
        }
    }
}
@MainActor struct TeamInvitePreview: View {
    let team: OwnedTeam
    @ObservedObject var model: TeamScreenModel
    @State private var copyMessageKey: String?
    @State private var copyPermit: TeamScreenModel.InviteCopyPermit?
    @State private var copyFeedbackCount = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(verbatim: team.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    if let code = team.inviteCode, TeamLookup.validInvite(code) {
                        Text(verbatim: code)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.tint)
                            .monospaced()
                            .textSelection(.enabled)
                            .accessibilityIdentifier("team.invite.code")
                    } else {
                        Text("team.invite.unavailable")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let copyMessageKey {
                        Text(LocalizedStringKey(copyMessageKey))
                            .font(.subheadline)
                            .foregroundStyle(copyMessageKey == "team.invite.copied" ? Color.green : Color.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("team.invite.copyFeedback")
                    }
                } footer: {
                    Text("team.invite.previewOnly")
                }

                if let code = team.inviteCode, TeamLookup.validInvite(code) {
                    Section {
                        Button("team.invite.copy") { copyInvitationCode(code) }
                            .accessibilityIdentifier("team.invite.copy")
                        ShareLink(item: code) {
                            Label(CoreLoopCopy(locale: locale).t("分享邀请码", "Share invite code"), systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("team.invite.share")
                    }
                }
            }
            .navigationTitle(Text("team.invitePreview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("team.close") { endPreview(); dismiss() }
                        .accessibilityIdentifier("team.invite.close")
                }
            }
        }
        .sensoryFeedback(trigger: copyFeedbackCount, copyFeedback)
        .cyDomainSheet(detents: [.half, .full])
        .onAppear { copyPermit = model.beginInvitePreview() }
        .onChange(of: team) { _, _ in endPreview() }
        .onDisappear { endPreview() }
    }
    private func endPreview() {
        model.endInvitePreview(copyPermit)
        copyPermit = nil
        copyMessageKey = nil
    }
    private func copyInvitationCode(_ code: String) {
        let copied = model.copyInvitationCode(from: team, code: code, permit: copyPermit) { value in
            LocalPasteboard.copy(value)
        }
        copyMessageKey = copied ? "team.invite.copied" : "team.invite.unavailable"
        copyFeedbackCount += 1
    }
}

private extension TeamInvitePreview {
    /// Typed haptic: success when the invite was copied, warning when the copy failed.
    func copyFeedback(_ old: Int, _ new: Int) -> SensoryFeedback? {
        copyMessageKey == "team.invite.copied" ? SensoryFeedback.success : SensoryFeedback.warning
    }
}
