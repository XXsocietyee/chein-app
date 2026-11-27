import SwiftUI

private struct TeamCommandWriterKey: EnvironmentKey { static let defaultValue: TeamCommandWriter? = nil }
extension EnvironmentValues {
    var teamCommandWriter: TeamCommandWriter? {
        get { self[TeamCommandWriterKey.self] }
        set { self[TeamCommandWriterKey.self] = newValue }
    }
}

/// Embed in an existing NavigationStack. A session-owned factory creates isolated route models.
@MainActor struct TeamHomeView: View {
    @StateObject private var model: TeamScreenModel
    @State private var readOwner = ManualMapReadTaskOwner()
    let makeCoordinator: () -> TeamCoordinator
    var onLogin: (() -> Void)?
    var nearbyDestination: (([OwnedTeam]) -> AnyView)?
    var onOpenInvitation: ((TeamInvitationRoute) -> Void)?
    init(coordinator: TeamCoordinator, makeCoordinator: @escaping () -> TeamCoordinator, onLogin: (() -> Void)? = nil, nearbyDestination: (([OwnedTeam]) -> AnyView)? = nil, onOpenInvitation: ((TeamInvitationRoute) -> Void)? = nil) {
        _model = StateObject(wrappedValue: TeamScreenModel(coordinator)); self.makeCoordinator = makeCoordinator; self.onLogin = onLogin; self.nearbyDestination = nearbyDestination; self.onOpenInvitation = onOpenInvitation
    }
    var body: some View {
        List {
            NavigationLink {
                TeamInvitationEntryView(makeCoordinator: makeCoordinator, onLogin: onLogin, onOpen: onOpenInvitation)
            } label: { Label("nativeNav.team.open", systemImage: "person.badge.plus") }
            TeamNotice(coordinator: model.coordinator)
            if !model.coordinator.authenticated {
                if let onLogin { Button("team.signIn", action: onLogin) }
            } else if model.running && model.coordinator.currentTeams.isEmpty {
                ProgressView { Text("team.loading") }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("team.loading")
            }
            else if model.coordinator.hasCurrentTeamsRead && model.coordinator.messageKey == nil && model.coordinator.currentTeams.isEmpty {
                ContentUnavailableView {
                    Label { Text("team.empty").accessibilityIdentifier("team.empty") } icon: { Image(systemName: "person.3") }
                } description: { Text("team.empty.detail") }
            }
            if !model.coordinator.currentTeams.isEmpty {
                Section {
                    ForEach(model.coordinator.currentTeams) { team in
                        NavigationLink { TeamDetailView(lookup: .id(team.id), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator) } label: { TeamHomeRow(team: team) }
                            .accessibilityIdentifier("team.row.\(team.id)")
                    }
                }
            }
            if model.coordinator.authenticated && model.coordinator.configured {
                Button("team.refresh") {
                    let permit = model.captureRun()
                    readOwner.start { await reload(permit: permit) }
                }.disabled(model.running).accessibilityIdentifier("team.refresh")
            }
        }
        .cyPageTitle("team.title")
            .toolbar { if let nearbyDestination { NavigationLink("nearby.title") { nearbyDestination(model.coordinator.currentTeams) } } }
            .task {
                guard !Task.isCancelled else { return }
                readOwner.activate()
                await readOwner.run { await reload() }
            }.refreshable { await readOwner.run { await reload() } }
            .onDisappear { readOwner.deactivate(); model.leave() }
        .themeDomain(.player)
    }
    private func reload(permit: TeamScreenModel.RunPermit? = nil) async {
        await model.run(permit: permit) { await model.coordinator.loadTeams() }
    }
}
/// Settings-style team row: title over status, members and join mode (the same facts `TeamCard` showed).
private struct TeamHomeRow: View {
    let team: OwnedTeam
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                if team.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("team.untitled") }
                else { Text(verbatim: team.title) }
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(team.status.key))
                    Text(verbatim: "·")
                    if let joined = team.joinedCount, let max = team.maxMembers {
                        Text("team.members.count") + Text(verbatim: " \(joined) / \(max)")
                    } else { Text("team.members.unknown") }
                    Text(verbatim: "·")
                    Text(LocalizedStringKey(team.joinMode.key))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: "person.3") }
    }
}

@MainActor struct TeamDetailView: View {
    let lookup: TeamLookup
    @StateObject private var model: TeamScreenModel
    @State private var readOwner = ManualMapReadTaskOwner()
    @State private var invitationPreview = false
    let makeCoordinator: () -> TeamCoordinator
    let requiresMembership: Bool
    let readOnly: Bool
    var onLogin: (() -> Void)?
    /// Source join links that still carry the retired `?teamId=` form (邀请链接已升级).
    var legacyTeamID = false
    @Environment(\.teamReformHooks) private var reformHooks
    @Environment(\.teamChannelManagementHooks) private var channelManagementHooks
    @Environment(\.teamCommandWriter) private var commandWriter
    @State private var reformSheet: TeamReformSheet?
    init(lookup: TeamLookup, coordinator: TeamCoordinator, makeCoordinator: @escaping () -> TeamCoordinator, requiresMembership: Bool = false, readOnly: Bool = false, onLogin: (() -> Void)? = nil, legacyTeamID: Bool = false) {
        self.lookup = lookup; self.makeCoordinator = makeCoordinator; self.requiresMembership = requiresMembership; self.readOnly = readOnly
        self.onLogin = onLogin; self.legacyTeamID = legacyTeamID
        _model = StateObject(wrappedValue: TeamScreenModel(coordinator))
    }
    private var pageKind: TeamPageKind { invitationCode == nil ? .detail : .invitation }
    private var invitationCode: String? { if case .invitation(let code) = lookup { return code.trimmingCharacters(in: .whitespacesAndNewlines) }; return nil }
    var body: some View {
        List {
            TeamNotice(coordinator: model.coordinator)
            // MP detail/join wxml:5-14: the unknown-outcome recovery card sits at the top of the page.
            if !readOnly, let pending = model.coordinator.pending {
                Section {
                    Button("team.checkOutcome") {
                        let permit = model.captureRun()
                        Task { await model.run(permit: permit) { await model.coordinator.checkOutcome() } }
                    }
                        .disabled(model.running || !model.coordinator.canSimulate).accessibilityIdentifier("team.checkOutcome")
                    teamRecoveryButtons(pending: pending)
                }
            }
            if model.running {
                ProgressView { Text(LocalizedStringKey(TeamPagePresentation.loadingKey(pageKind, hasDetail: model.coordinator.detail != nil))) }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("team.loading")
            }
            if !model.running, let state = TeamPagePresentation.blockingState(kind: pageKind, messageKey: model.coordinator.messageKey,
                                                                            hasDetail: model.coordinator.detail != nil, legacyTeamID: legacyTeamID,
                                                                            failure: model.coordinator.readFailure) {
                TeamPageStateView(state: state, signIn: onLogin, reload: stateReload)
            }
            // pages/team/join readout: no detail, no failure, not loading is the empty invitation, never a blank page.
            if invitationCode != nil, !model.running,
               TeamPagePresentation.invitationReadout(loading: model.running, detail: model.coordinator.detail,
                                                      messageKey: model.coordinator.messageKey, failure: model.coordinator.readFailure,
                                                      legacyTeamID: legacyTeamID) == .empty {
                ContentUnavailableView {
                    Label { Text("team.join.empty").accessibilityIdentifier("team.join.empty") } icon: { Image(systemName: "person.3") }
                } description: { Text("team.join.emptyDetail") }
            }
            if let banner = TeamPagePresentation.staleBanner(kind: pageKind, messageKey: model.coordinator.messageKey, hasDetail: model.coordinator.detail != nil) {
                TeamStaleBanner(title: banner.title, detail: banner.detail)
            }
            if model.coordinator.retiredMembershipTeamID != nil {
                Label("team.changed", systemImage: "person.crop.circle.badge.xmark")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamMembershipRetired")
            }
            if let detail = model.coordinator.detail, invitationCode != nil {
                // MP team/join: `.tj-head` (title), then the `.tj-card` (seats, 当前成员 / 加入方式, 邀请到期).
                // The join hint and the one action live in the bottom bar (`.tj-bar`).
                Section {
                    TeamPageHeader(detail: detail, kind: .invitation)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("team.detail.card")
                }
                Section {
                    TeamJoinSeatRow(detail: detail)
                    TeamPageFacts(detail: detail, kind: .invitation)
                    TeamSeatFactsCard(detail: detail, invitation: true)
                }
            } else if let detail = model.coordinator.detail {
                // MP `.team-head`: status, title, join mode, 当前成员 / 场次开始.
                Section {
                    TeamPageHeader(detail: detail, kind: pageKind, confirmedJoinMode: model.coordinator.confirmedJoinMode)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("team.detail.card")
                }
                // U06-01 `.tm-seats`: member seats + open seats, then the seat chips and the invitation deadline.
                Section {
                    TeamDetailSeatStrip(detail: detail)
                    TeamSeatFactsCard(detail: detail)
                }
                // MP `.team-actions` (status 0): 邀请队友, then 二维码 for members or 加入队伍 for non-members.
                Section {
                    if !readOnly, detail.team.status == .recruiting, let code = detail.team.inviteCode, TeamLookup.validInvite(code) {
                        Button("team.page.inviteTeammates") { invitationPreview = true }.disabled(model.actionLocked).accessibilityIdentifier("team.invitePreview")
                    }
                    if !readOnly, detail.team.status == .recruiting, detail.joined == true || detail.leader == true {
                        // l-misc: the team mini-program code and join code come only from the server reply.
                        // C-D10: 二维码 opens the 队伍二维码 sheet, which reads the code as it opens.
                        TeamInviteQRSheetButton(teamID: detail.team.id)
                    }
                    if !readOnly, let code = TeamPagePresentation.joinRouteCode(detail) {
                        NavigationLink {
                            TeamDetailView(lookup: .invitation(code), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator, onLogin: onLogin)
                        } label: { Text("team.page.joinTeam") }
                            .disabled(model.actionLocked).accessibilityIdentifier("teamPage.joinRoute")
                    }
                }
                if detail.leader == true, detail.team.status == .recruiting {
                    // Mini leader card (公开招募): shown right after the actions, before the member list.
                    let currentMode = model.coordinator.confirmedJoinMode ?? detail.team.joinMode
                    // C-D5 (MP index.wxml:75-80): 公开招募 is one switch. Flipping it opens the same review as
                    // before; the switch shows the confirmed mode, so a cancelled review leaves it unchanged.
                    let target: TeamJoinMode = currentMode == .publicApplication ? .invitation : .publicApplication
                    let action = TeamAction.changeJoinMode(teamID: detail.team.id, mode: target)
                    Section {
                        Toggle(isOn: Binding(get: { currentMode == .publicApplication },
                                             set: { _ in if !readOnly, action.isAllowed(detail: detail) { model.prepare(action) } })) {
                            Text("team.mode.public")
                        }
                        .disabled(readOnly || model.actionLocked || currentMode == .unknown || !action.isAllowed(detail: detail))
                        .accessibilityValue(Text(LocalizedStringKey(currentMode.key)))
                        .accessibilityIdentifier("team.mode.change.\(target.rawValue)")
                    } footer: {
                        Text(LocalizedStringKey(TeamPagePresentation.joinModeHelpKey(currentMode)))
                            .accessibilityIdentifier("team.mode.current")
                    }
                    // r8 C-D2 (MP team/detail wxml:76-95, js:340-376): the leader sees and handles 入队申请 here.
                    if !readOnly { TeamDetailApplicantsHost(teamID: detail.team.id) }
                }
                Section {
                    if detail.members.isEmpty {
                        ContentUnavailableView("team.page.membersEmpty", systemImage: "person.2")
                    }
                    ForEach(detail.members, id: \.id) { member in
                        let action = TeamAction.remove(teamID: detail.team.id, memberID: member.id)
                        // Borderless keeps 移出 its own tap target instead of the whole row.
                        TeamMemberRow(member: member, remove: !readOnly && action.isAllowed(detail: detail) ? { model.prepare(action) } : nil)
                            .buttonStyle(.borderless)
                            .disabled(model.actionLocked)
                    }
                } header: { Text("team.members.title") }
                // C-D6: MP order — 队伍进度 / 排名 before the destructive 退出 / 解散 (destructive last).
                if !readOnly {
                    TeamReformEntries(detail: detail, hooks: reformHooks) { reformSheet = $0 }.disabled(model.actionLocked)
                }
                Section {
                    actionButton(.leave(teamID: detail.team.id), detail: detail, labelKey: TeamPagePresentation.leaveLabelKey(detail))
                    actionButton(.disband(teamID: detail.team.id), detail: detail)
                } footer: {
                    if TeamPagePresentation.showsRefundNote(detail) {
                        Text("team.page.refundNote")
                    }
                }
                // C-D3: 举报队伍 for members who are not the leader (the entry hides itself until its access is enabled).
                if detail.leader != true {
                    TeamReportEntryButton(teamID: detail.team.id)
                }
                // App-only extensions the MP page lacks, after every MP section: they render only when the
                // server sends story-role / shared-outcome facts, or when team chat management is installed.
                if detail.roleFacts != nil || detail.sharedOutcome != nil {
                    TeamRoleAndSharedSection(role: detail.roleFacts, shared: detail.sharedOutcome)
                }
                if let channelManagementHooks,
                   let source = NativeTeamChannelManagementSource(coordinator: model.coordinator, lookup: lookup, readOnly: readOnly) {
                    NativeChannelManagementTeamEntry(destinations: channelManagementHooks.destinations, detail: source.detail, makeFlow: { selected in
                        guard source.isCurrent(for: selected) else { return nil }
                        return channelManagementHooks.makeFlow(selected)
                    }).disabled(model.running || model.coordinator.busy)
                }
            }
            // C-D9: 重新加载 only when the read failed; a loaded detail refreshes by pull-to-refresh.
            if lookup.isValid && model.coordinator.authenticated && model.coordinator.retiredMembershipTeamID == nil,
               model.coordinator.readFailure != nil || model.coordinator.detail == nil {
                Button("team.refresh") {
                    let permit = model.captureRun()
                    readOwner.start { await reload(permit: permit) }
                }.disabled(model.running).accessibilityIdentifier("team.refresh")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let invitationCode, let detail = model.coordinator.detail {
                VStack(spacing: 0) {
                    Divider()
                    VStack(spacing: 8) { invitationActions(detail: detail, invitationCode: invitationCode) }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .background(.bar)
            }
        }
        .appNavigationTitle(invitationCode == nil ? "team.detail" : "team.invitation")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard !Task.isCancelled else { return }
                readOwner.activate()
                await readOwner.run { await reload() }
            }.refreshable { await readOwner.run { await reload() } }
            .onDisappear { readOwner.deactivate(); model.leave() }
            .cySheet(item: nonJoinReviewBinding) { TeamReviewSheet(model: model, review: $0).cySheet() }
            .cySheet(isPresented: $invitationPreview) { Group { if let team = model.coordinator.detail?.team { TeamInvitePreview(team: team, model: model) } }.cySheet() }
            .cySheet(item: $reformSheet, onDismiss: { let permit = model.captureRun(); readOwner.start { await reload(permit: permit) } }) { sheet in Group { if let reformHooks { TeamReformSheetHost(sheet: sheet, hooks: reformHooks) } }.cySheet(detents: [.large]) }
        .themeDomain(.player)
    }
    /// C-J5 (MP team/join `.tj-bar`): the invitation's one action sits in the bottom bar, outside the scroll.
    @ViewBuilder private func invitationActions(detail: TeamDetail, invitationCode: String) -> some View {
        let retry = TeamPagePresentation.showsJoinRetry(model.coordinator.writeState, page: pageKind)
        let blocker = TeamSeatPresentation.blockerKey(detail.viewer, entry: .join)
        // MP join wxml:52-53: the refused-join error, else the server's join hint while not joined.
        if retry, model.coordinator.postJoinDetailID == nil, detail.joined != true, TeamPagePresentation.invitationCTA(detail) == .join {
            TeamJoinRetryNotice(reasonKey: model.coordinator.rejectionCode.map { TeamSeatPresentation.rejectionKey($0) })
        } else if detail.joined != true, model.coordinator.postJoinDetailID == nil, let blocker {
            Label(LocalizedStringKey(blocker), systemImage: "exclamationmark.circle")
                .font(.subheadline).foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("teamViewer.joinHint")
        }
        if let teamID = model.coordinator.postJoinDetailID {
            NavigationLink {
                TeamDetailView(lookup: .id(teamID), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator, requiresMembership: true, readOnly: true)
            } label: { Text("team.page.openTeam").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.running || model.coordinator.busy)
                .accessibilityIdentifier("team.postJoin.openDetail")
        }
        else if detail.joined == true {
            // MP join wxml:55 查看队伍 (goDetail) is the one action for a member.
            NavigationLink {
                TeamDetailView(lookup: .id(detail.team.id), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator, requiresMembership: true)
            } label: { Text("team.page.openTeam").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.actionLocked)
                .accessibilityIdentifier("team.invitation.openDetail")
        }
        else if TeamPagePresentation.invitationCTA(detail) == .join {
            // C-J2 (MP team/join wxml:55, js goBuyTicket): a TICKET_REQUIRED rejection, or the `/info` join blocker
            // TICKET_REQUIRED, on an activity team (ownerType 2) makes the primary 去买这一场的票 → registration page.
            if TeamSeatPresentation.showsBuyTicket(errorCode: model.coordinator.rejectionCode) || blocker == "team.blocker.TICKET_REQUIRED",
               let owner = detail.team.ownerKey, owner.type == 2 {
                NavigationLink {
                    MPReviewedPageScreen(page: "pages/activity/baoming/baoming", query: ["activityId": String(owner.id)])
                } label: { Text("fixr3.team.buyTicket").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.actionLocked)
                    .accessibilityIdentifier("teamPage.buyTicket")
            } else {
                actionButton(.join(teamID: detail.team.id, inviteCode: invitationCode), detail: detail,
                             labelKey: retry ? "team.page.retryJoin" : "mpr3.team.acceptJoin")
            }
        }
        else { TeamClosedInvitationButton(cta: TeamPagePresentation.invitationCTA(detail)) }
    }
    /// C-D12 recovery card. `checkOutcome()` stays synthetic. Query, retry, and cancel share one key and the original fields.
    @ViewBuilder private func teamRecoveryButtons(pending: TeamPendingRecord) -> some View {
        let command = model.recoveryCommand?.targetKey == pending.targetKey ? model.recoveryCommand : nil
        let key = command?.key ?? pending.targetKey
        let fields = command?.fields ?? [:]
        Button {
            let permit = model.captureRun()
            Task { await model.run(permit: permit) { _ = await commandWriter?.query(key: key) } }
        } label: { Text(verbatim: TeamCommandRecoveryCopy.query) }
            .disabled(model.running).accessibilityIdentifier("team.recovery.query")
        Button {
            guard fields["action"] != nil else { return }
            let permit = model.captureRun()
            Task { await model.run(permit: permit) {
                if fields["action"] == "handle", AccountPublishContractLane.isInstalled,
                   let memberID = fields["memberId"], let targetID = fields["targetId"] {
                    let approved = fields["approved"] == "true" || fields["approved"] == "1"
                    _ = await AccountPublishContractLane.handleApplicant(memberID: memberID, teamID: targetID, approved: approved)
                } else {
                    _ = await commandWriter?.submit(key: key, path: "api/team/command", fields: fields)
                }
            } }
        } label: { Text(verbatim: TeamCommandRecoveryCopy.retry) }
            .disabled(model.running).accessibilityIdentifier("team.recovery.retry")
        Button {
            guard fields["action"] != nil else { return }
            let permit = model.captureRun()
            Task { await model.run(permit: permit) { _ = await commandWriter?.cancel(key: key, fields: fields) } }
        } label: { Text(verbatim: TeamCommandRecoveryCopy.abort) }
            .disabled(model.running).accessibilityIdentifier("team.recovery.abort")
        Text(verbatim: TeamCommandRecoveryCopy.abortNote)
            .font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("team.recovery.abortNote")
    }
    @ViewBuilder private func actionButton(_ action: TeamAction, detail: TeamDetail, labelKey: String? = nil) -> some View {
        if !readOnly, action.isAllowed(detail: detail) {
            if case .join = action {
                // Mini-program 加入队伍 is the page's one primary action. C-J3 (MP join wxml:57-60): it joins
                // directly and reads 加入中… while the request runs; no review sheet in between.
                Button { joinDirectly(action) } label: {
                    Group {
                        if model.running, case .join? = model.coordinator.review?.action {
                            Text("fixr3.team.joining")
                        } else {
                            Text(LocalizedStringKey(labelKey ?? action.key))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.actionLocked)
                    .accessibilityIdentifier(action.key)
            } else {
                // 解散队伍 is the source's danger action; native destructive role keeps it red.
                if case .disband = action {
                    Button(role: .destructive) { model.prepare(action) } label: { Text(LocalizedStringKey(labelKey ?? action.key)) }
                        .disabled(model.actionLocked)
                        .accessibilityIdentifier(action.key)
                } else {
                    Button(role: destructiveRole(action)) { model.prepare(action) } label: { Text(LocalizedStringKey(labelKey ?? action.key)) }
                        .disabled(model.actionLocked)
                        .accessibilityIdentifier(action.key)
                }
            }
        }
    }
    /// C-J3: prepare and confirm in one tap. Without a submit authority the review stays and its sheet explains why.
    private func joinDirectly(_ action: TeamAction) {
        model.prepare(action)
        model.rememberRecovery(action)
        guard model.coordinator.canSubmit, let review = model.coordinator.review else { return }
        let permit = model.captureRun()
        Task {
            guard model.coordinator.review == review else { return }
            _ = await model.run(permit: permit) { await model.coordinator.confirm(review) }
        }
    }
    /// The join review is confirmed in place (C-J3); every other review keeps its sheet.
    private var nonJoinReviewBinding: Binding<TeamReview?> {
        Binding(get: {
            guard let review = model.coordinator.review else { return nil }
            if case .join = review.action, model.coordinator.canSubmit { return nil }
            return review
        }, set: { model.reviewBinding.wrappedValue = $0 })
    }
    private func destructiveRole(_ action: TeamAction) -> ButtonRole? {
        if case .disband = action { return .destructive }
        return nil
    }
    private var stateReload: (() -> Void)? {
        guard lookup.isValid else { return nil }
        return {
            let permit = model.captureRun()
            readOwner.start { await reload(permit: permit) }
        }
    }
    private func reload(permit: TeamScreenModel.RunPermit? = nil) async {
        await model.run(permit: permit) {
            if readOnly, case .id(let teamID) = lookup { await model.coordinator.loadPostJoinDetail(teamID: teamID) }
            else { await model.coordinator.loadDetail(lookup, requireMembership: requiresMembership) }
        }
    }
}

/// C-D10 (MP team/detail wxml:58, 170-180): 二维码 opens the 队伍二维码 sheet with the mini-program code and 加入码.
/// Absent when no QR reader is installed, like the inline section it wraps.
struct TeamInviteQRSheetButton: View {
    @Environment(\.playerGapService) private var service
    let teamID: Int
    @State private var shown = false
    var body: some View {
        if service != nil {
            Button { shown = true } label: { Label("fixr3.team.qr", systemImage: "qrcode") }
                .accessibilityLabel(Text("fixr3.team.qr.a11y"))
                .accessibilityIdentifier("team.qr.open")
                .cySheet(isPresented: $shown) {
                    NavigationStack {
                        ScrollView { TeamInviteQRSection(teamID: teamID, loadsOnAppear: true).padding() }
                            .navigationTitle(Text("fixr3.team.qr.title")).navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("compliance.close") { shown = false } } }
                    }
                    .presentationDetents([.medium, .large])
                }
        }
    }
}
