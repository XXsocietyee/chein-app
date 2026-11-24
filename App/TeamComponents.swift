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
    func prepare(_ action: TeamAction) { coordinator.prepare(action); objectWillChange.send() }
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
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if canSimulate { Label("team.fixtureNotice", systemImage: "testtube.2").accessibilityIdentifier("team.fixtureNotice") }
            if let key = messageKey {
                Label(LocalizedStringKey(key), systemImage: hasPending ? "exclamationmark.triangle" : "info.circle")
                    .accessibilityIdentifier("team.message")
            }
        }.cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            .padding(CYSpacing.md).frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
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
    var body: some View {
        // Mini `.team-member`: 32pt avatar, name (600) over role caption, trailing 移出 in danger text.
        HStack(alignment: .center, spacing: CYSpacing.sm) {
            // MP team/detail wxml:102: `memberAvatar || /images/d_profile.png`. Core decodes no avatar yet, so the MP default shows.
            MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
                .frame(width: 32, height: 32).clipShape(Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Group {
                    if member.name.isEmpty { Text("team.member.unnamed") } else { Text(verbatim: member.name).fixedSize(horizontal: false, vertical: true) }
                }.cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                Text(member.isCaptain ? "team.member.captain" : member.role == 0 ? "team.member.player" : "team.member.unknownRole").cyText(.caption).foregroundStyle(CYColor.textSecondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let remove { Button("team.remove", role: .destructive, action: remove).cyText(.label).frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).accessibilityIdentifier("team.remove.\(member.id)") }
        }.padding(.vertical, CYSpacing.xs)
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
        CYSheetContainer(
            title: actionTitle,
            onClose: model.running ? nil : { model.cancel(); dismiss() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    if let detail = review.detail {
                        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                            Text(verbatim: detail.team.title)
                                .cyText(.cardTitle)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: "#\(detail.team.id)")
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    if case .remove(_, let memberID) = review.action, let member = review.detail?.members.first(where: { $0.id == memberID }) {
                        Text(verbatim: member.name)
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if case .create(let context, let size, let inviteOnly) = review.action {
                        Text(verbatim: context.title)
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        LabeledContent("team.size") { Text(verbatim: "\(size)") }
                            .cyText(.body)
                        Text(inviteOnly ? "team.mode.invitation" : "team.mode.public")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                    }
                    if case .changeJoinMode(_, let mode) = review.action {
                        LabeledContent {
                            Text(LocalizedStringKey(review.detail?.team.joinMode.key ?? "team.mode.unknown"))
                        } label: { Text(verbatim: locale.language.languageCode?.identifier == "zh" ? "当前方式" : "Current mode") }
                            .cyText(.body)
                        LabeledContent {
                            Text(LocalizedStringKey(mode.key))
                        } label: { Text(verbatim: locale.language.languageCode?.identifier == "zh" ? "确认后的方式" : "Requested mode") }
                            .cyText(.body)
                        Text(verbatim: locale.language.languageCode?.identifier == "zh"
                            ? "仅更改加入队伍的方式，不变更成员或报名。结果不明时会保留锁定，不自动重试。"
                            : "Only the joining mode changes; membership and registration stay unchanged. An unknown outcome remains locked without automatic retry.")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if consequenceKeys.isEmpty {
                        Text(LocalizedStringKey(TeamSeatPresentation.consequenceKey(review.action, detail: review.detail)))
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(LocalizedStringKey(TeamSeatPresentation.consequenceKey(review.action, detail: review.detail)))
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            ForEach(Array(consequenceKeys.enumerated()), id: \.offset) { idx, key in
                                HStack(alignment: .top, spacing: CYSpacing.sm) {
                                    Image(systemName: idx == consequenceKeys.count - 1 ? "exclamationmark.triangle" : "info.circle")
                                        .cyText(.body)
                                        .foregroundStyle(idx == consequenceKeys.count - 1 ? CYColor.dangerText : CYColor.textSecondary)
                                        .accessibilityHidden(true)
                                    Text(LocalizedStringKey(key))
                                        .cyText(.bodyCompact)
                                        .foregroundStyle(CYColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CYSpacing.md)
                        .background(CYColor.sheetCard, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                    }
                    TeamNotice(coordinator: model.coordinator)
                    confirmActionButton
                    if case .disband(let teamID) = review.action {
                        Button {
                            model.prepare(.leave(teamID: teamID))
                        } label: {
                            VStack(spacing: CYSpacing.xxs) {
                                Text("team.leaveInstead")
                                Text("team.page.leaveAndTransfer")
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
                        .disabled(model.running)
                        .accessibilityIdentifier("team.review.leaveInstead")
                    }
                    Button("team.cancel") { model.cancel(); dismiss() }
                        .buttonStyle(CYGhostButtonStyle(isFullWidth: true))
                        .disabled(model.running)
                        .accessibilityIdentifier("team.review.cancel")
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .interactiveDismissDisabled(model.running)
        .cyDomainSheet(detents: [.half, .full])
    }

    @ViewBuilder private var confirmActionButton: some View {
        let button = Button(LocalizedStringKey(model.coordinator.canSimulate ? "team.simulate" : "team.confirmLive")) {
            let permit = model.captureRun()
            Task {
                guard model.coordinator.review == review else { return }
                if await model.run(permit: permit, { await model.coordinator.confirm(review) }) { dismiss() }
            }
        }
        .disabled(!model.coordinator.canSubmit || model.running)
        .accessibilityIdentifier("team.review.confirm")
        if isDestructiveAction {
            button.buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
        } else {
            button.buttonStyle(CYPrimaryButtonStyle(isFullWidth: true))
        }
    }
}
@MainActor struct TeamInvitePreview: View {
    let team: OwnedTeam
    @ObservedObject var model: TeamScreenModel
    @State private var copyMessageKey: String?
    @State private var copyPermit: TeamScreenModel.InviteCopyPermit?
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .info
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    var body: some View {
        CYSheetContainer(
            title: appLocalized("team.invitePreview", locale: locale),
            onClose: { endPreview(); dismiss() }
        ) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: team.title)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let code = team.inviteCode, TeamLookup.validInvite(code) {
                        Text(verbatim: code)
                            .cyText(.sectionTitle)
                            .foregroundStyle(CYColor.brand)
                            .monospaced()
                            .textSelection(.enabled)
                            .accessibilityIdentifier("team.invite.code")
                    } else {
                        Text("team.invite.unavailable")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let copyMessageKey {
                        Text(LocalizedStringKey(copyMessageKey))
                            .cyText(.bodyCompact)
                            .foregroundStyle(copyMessageKey == "team.invite.copied" ? CYColor.successText : CYColor.dangerText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("team.invite.copyFeedback")
                    }
                    Text("team.invite.previewOnly")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CYSpacing.md)
                .background(CYColor.sheetCard, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))

                if let code = team.inviteCode, TeamLookup.validInvite(code) {
                    Button("team.invite.copy") { copyInvitationCode(code) }
                        .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true))
                        .accessibilityIdentifier("team.invite.copy")
                    ShareLink(item: code) {
                        Label(CoreLoopCopy(locale: locale).t("分享邀请码", "Share invite code"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
                    .accessibilityIdentifier("team.invite.share")
                }

                Button("team.close") { endPreview(); dismiss() }
                    .buttonStyle(CYGhostButtonStyle(isFullWidth: true))
                    .accessibilityIdentifier("team.invite.close")
            }
        }
        .cyToast(message: $toastMessage, tone: toastTone)
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
        toastTone = copied ? .success : .warning
        toastMessage = copied ? "team.invite.copied" : "team.invite.unavailable"
    }
}
