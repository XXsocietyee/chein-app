import SwiftUI

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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.lg) {
                NavigationLink {
                    TeamInvitationEntryView(makeCoordinator: makeCoordinator, onLogin: onLogin, onOpen: onOpenInvitation)
                } label: { Label("nativeNav.team.open", systemImage: "person.badge.plus") }
                TeamNotice(coordinator: model.coordinator)
                if !model.coordinator.authenticated {
                    if let onLogin { Button("team.signIn", action: onLogin).buttonStyle(.cyPrimary) }
                } else if model.running && model.coordinator.currentTeams.isEmpty {
                    CYLoadingState("team.loading", messageIdentifier: "team.loading")
                }
                else if model.coordinator.hasCurrentTeamsRead && model.coordinator.messageKey == nil && model.coordinator.currentTeams.isEmpty {
                    CYEmptyState(systemImage: "person.3", "team.empty", detail: "team.empty.detail", messageIdentifier: "team.empty")
                }
                ForEach(model.coordinator.currentTeams) { team in
                    NavigationLink { TeamDetailView(lookup: .id(team.id), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator) } label: { TeamCard(team: team) }
                        .buttonStyle(.plain).accessibilityIdentifier("team.row.\(team.id)")
                }
                if model.coordinator.authenticated && model.coordinator.configured {
                    Button("team.refresh") {
                        let permit = model.captureRun()
                        readOwner.start { await reload(permit: permit) }
                    }.buttonStyle(.cySecondary).disabled(model.running).accessibilityIdentifier("team.refresh")
                }
            }.padding(CYSpacing.pageHorizontal)
        }.background(CYColor.bgPage.ignoresSafeArea()).cyPageTitle("team.title")
            .toolbar { if let nearbyDestination { NavigationLink("nearby.title") { nearbyDestination(model.coordinator.currentTeams) } } }
            .task {
                guard !Task.isCancelled else { return }
                readOwner.activate()
                await readOwner.run { await reload() }
            }.refreshable { await readOwner.run { await reload() } }
            .onDisappear { readOwner.deactivate(); model.leave() }
        .cyDomainScreen(.player)
    }
    private func reload(permit: TeamScreenModel.RunPermit? = nil) async {
        await model.run(permit: permit) { await model.coordinator.loadTeams() }
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
    @State private var reformSheet: TeamReformSheet?
    init(lookup: TeamLookup, coordinator: TeamCoordinator, makeCoordinator: @escaping () -> TeamCoordinator, requiresMembership: Bool = false, readOnly: Bool = false, onLogin: (() -> Void)? = nil, legacyTeamID: Bool = false) {
        self.lookup = lookup; self.makeCoordinator = makeCoordinator; self.requiresMembership = requiresMembership; self.readOnly = readOnly
        self.onLogin = onLogin; self.legacyTeamID = legacyTeamID
        _model = StateObject(wrappedValue: TeamScreenModel(coordinator))
    }
    private var pageKind: TeamPageKind { invitationCode == nil ? .detail : .invitation }
    private var invitationCode: String? { if case .invitation(let code) = lookup { return code.trimmingCharacters(in: .whitespacesAndNewlines) }; return nil }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                TeamNotice(coordinator: model.coordinator)
                if model.running {
                    CYLoadingState(LocalizedStringKey(TeamPagePresentation.loadingKey(pageKind, hasDetail: model.coordinator.detail != nil)), messageIdentifier: "team.loading")
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
                    CYEmptyState(systemImage: "person.3", "team.join.empty", detail: "team.join.emptyDetail",
                                 messageIdentifier: "team.join.empty")
                }
                if let banner = TeamPagePresentation.staleBanner(kind: pageKind, messageKey: model.coordinator.messageKey, hasDetail: model.coordinator.detail != nil) {
                    TeamStaleBanner(title: banner.title, detail: banner.detail)
                }
                if model.coordinator.retiredMembershipTeamID != nil {
                    Label("team.changed", systemImage: "person.crop.circle.badge.xmark")
                        .cyText(.meta).foregroundStyle(CYColor.warningText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("teamMembershipRetired")
                }
                if let detail = model.coordinator.detail {
                    // Mini-program `team-head` is the one header: title, status, mode, members and start time.
                    TeamPageHeader(detail: detail, kind: pageKind, confirmedJoinMode: model.coordinator.confirmedJoinMode)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("team.detail.card")
                    // U06-01: seats, applications and the invitation deadline, separate from the member list.
                    if invitationCode != nil { TeamJoinSeatRow(detail: detail) }
                    TeamSeatFactsCard(detail: detail)
                    TeamRoleAndSharedSection(role: detail.roleFacts, shared: detail.sharedOutcome)
                    TeamViewerRelationshipLine(detail: detail, invitation: invitationCode != nil)
                    if let channelManagementHooks,
                       let source = NativeTeamChannelManagementSource(coordinator: model.coordinator, lookup: lookup, readOnly: readOnly) {
                        NativeChannelManagementTeamEntry(destinations: channelManagementHooks.destinations, detail: source.detail, makeFlow: { selected in
                            guard source.isCurrent(for: selected) else { return nil }
                            return channelManagementHooks.makeFlow(selected)
                        }).disabled(model.running || model.coordinator.busy)
                    }
                    if invitationCode == nil, !readOnly, let code = TeamPagePresentation.joinRouteCode(detail) {
                        NavigationLink {
                            TeamDetailView(lookup: .invitation(code), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator, onLogin: onLogin)
                        } label: { Text("team.page.joinTeam") }
                            .buttonStyle(.cySecondary(fullWidth: true)).disabled(model.actionLocked).accessibilityIdentifier("teamPage.joinRoute")
                    }
                    if !readOnly, detail.team.status == .recruiting, let code = detail.team.inviteCode, TeamLookup.validInvite(code) {
                        // Mini `.team-actions`: 邀请队友 is the primary on the detail page; on the invitation page 加入 is.
                        if invitationCode == nil {
                            Button("team.page.inviteTeammates") { invitationPreview = true }.buttonStyle(.cyPrimary).disabled(model.actionLocked).accessibilityIdentifier("team.invitePreview")
                        } else {
                            Button("team.invitePreview") { invitationPreview = true }.buttonStyle(.cySecondary(fullWidth: true)).disabled(model.actionLocked).accessibilityIdentifier("team.invitePreview")
                        }
                    }
                    if !readOnly, invitationCode == nil, detail.team.status == .recruiting, detail.joined == true || detail.leader == true {
                        // l-misc: the team mini-program code and join code come only from the server reply.
                        TeamInviteQRSheetButton(teamID: detail.team.id)
                    }
                    if detail.leader == true, detail.team.status == .recruiting {
                        // Mini leader card (公开招募): shown right after the actions, before the member list.
                        CYCard {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            let currentMode = model.coordinator.confirmedJoinMode ?? detail.team.joinMode
                            // C-D5 (MP index.wxml:75-80): 公开招募 is one switch. Flipping it opens the same review as
                            // before; the switch shows the confirmed mode, so a cancelled review leaves it unchanged.
                            let target: TeamJoinMode = currentMode == .publicApplication ? .invitation : .publicApplication
                            let action = TeamAction.changeJoinMode(teamID: detail.team.id, mode: target)
                            Toggle(isOn: Binding(get: { currentMode == .publicApplication },
                                                 set: { _ in if !readOnly, action.isAllowed(detail: detail) { model.prepare(action) } })) {
                                Text("team.mode.public").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                            }
                            .disabled(readOnly || model.actionLocked || currentMode == .unknown || !action.isAllowed(detail: detail))
                            .accessibilityValue(Text(LocalizedStringKey(currentMode.key)))
                            .accessibilityIdentifier("team.mode.change.\(target.rawValue)")
                            Text(LocalizedStringKey(TeamPagePresentation.joinModeHelpKey(currentMode)))
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("team.mode.current")
                        }
                        }
                    }
                    Text("team.members.title").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                    // Mini `.team-card`: members share one card, hairline between rows.
                    CYCard(padding: CYSpacing.md) {
                        VStack(spacing: 0) {
                            if detail.members.isEmpty {
                                Text("team.page.membersEmpty").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            }
                            ForEach(Array(detail.members.enumerated()), id: \.element.id) { index, member in
                                let action = TeamAction.remove(teamID: detail.team.id, memberID: member.id)
                                TeamMemberRow(member: member, remove: !readOnly && action.isAllowed(detail: detail) ? { model.prepare(action) } : nil).disabled(model.actionLocked)
                                if index < detail.members.count - 1 { Divider().overlay(CYColor.borderSubtle) }
                            }
                        }
                    }
                    // C-D6: MP order — 队伍进度 / 排名 before the destructive 退出 / 解散 (destructive last).
                    if !readOnly, invitationCode == nil {
                        TeamReformEntries(detail: detail, hooks: reformHooks) { reformSheet = $0 }.disabled(model.actionLocked)
                    }
                    actionButton(.leave(teamID: detail.team.id), detail: detail, labelKey: TeamPagePresentation.leaveLabelKey(detail))
                    actionButton(.disband(teamID: detail.team.id), detail: detail)
                    if TeamPagePresentation.showsRefundNote(detail) {
                        Text("team.page.refundNote").cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    // C-D3: 举报队伍 for members who are not the leader (the entry hides itself until its access is enabled).
                    if invitationCode == nil, detail.leader != true {
                        TeamReportEntryButton(teamID: detail.team.id)
                    }
                }
                if !readOnly, model.coordinator.pending != nil {
                    Button("team.checkOutcome") {
                        let permit = model.captureRun()
                        Task { await model.run(permit: permit) { await model.coordinator.checkOutcome() } }
                    }
                        .buttonStyle(.cySecondary).disabled(model.running || !model.coordinator.canSimulate).accessibilityIdentifier("team.checkOutcome")
                }
                // C-D9: 重新加载 only when the read failed; a loaded detail refreshes by pull-to-refresh.
                if lookup.isValid && model.coordinator.authenticated && model.coordinator.retiredMembershipTeamID == nil,
                   model.coordinator.readFailure != nil || model.coordinator.detail == nil {
                    Button("team.refresh") {
                        let permit = model.captureRun()
                        readOwner.start { await reload(permit: permit) }
                    }.buttonStyle(.cySecondary).disabled(model.running).accessibilityIdentifier("team.refresh")
                }
            }.padding(CYSpacing.pageHorizontal)
        }
        .safeAreaInset(edge: .bottom) {
            if let invitationCode, let detail = model.coordinator.detail {
                CYFooterBar { VStack(spacing: CYSpacing.sm) { invitationActions(detail: detail, invitationCode: invitationCode) } }
            }
        }
        .background(CYColor.bgPage.ignoresSafeArea()).appNavigationTitle(invitationCode == nil ? "team.detail" : "team.invitation")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard !Task.isCancelled else { return }
                readOwner.activate()
                await readOwner.run { await reload() }
            }.refreshable { await readOwner.run { await reload() } }
            .onDisappear { readOwner.deactivate(); model.leave() }
            .sheet(item: nonJoinReviewBinding) { TeamReviewSheet(model: model, review: $0).cySheet() }
            .sheet(isPresented: $invitationPreview) { Group { if let team = model.coordinator.detail?.team { TeamInvitePreview(team: team, model: model) } }.cySheet() }
            .sheet(item: $reformSheet, onDismiss: { let permit = model.captureRun(); readOwner.start { await reload(permit: permit) } }) { sheet in Group { if let reformHooks { TeamReformSheetHost(sheet: sheet, hooks: reformHooks) } }.cySheet(detents: [.large]) }
        .cyDomainScreen(.player)
    }
    /// C-J5 (MP team/join `.tj-bar`): the invitation's one action sits in the bottom bar, outside the scroll.
    @ViewBuilder private func invitationActions(detail: TeamDetail, invitationCode: String) -> some View {
                if let teamID = model.coordinator.postJoinDetailID {
                    NavigationLink {
                        TeamDetailView(lookup: .id(teamID), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator, requiresMembership: true, readOnly: true)
                    } label: { Label("team.detail", systemImage: "person.3") }
                        .buttonStyle(.cyPrimary).disabled(model.running || model.coordinator.busy)
                        .accessibilityIdentifier("team.postJoin.openDetail")
                }
                else if detail.joined == true {
                    Label("team.alreadyJoined", systemImage: "checkmark.circle").cyText(.label).foregroundStyle(CYColor.successText)
                    NavigationLink {
                        TeamDetailView(lookup: .id(detail.team.id), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator, requiresMembership: true)
                    } label: { Label("team.detail", systemImage: "person.3") }
                        .buttonStyle(.cyPrimary).disabled(model.actionLocked)
                        .accessibilityIdentifier("team.invitation.openDetail")
                }
                else if TeamPagePresentation.invitationCTA(detail) == .join {
                    if TeamPagePresentation.showsJoinRetry(model.coordinator.writeState, page: pageKind) {
                        TeamJoinRetryNotice(reasonKey: model.coordinator.rejectionCode.map { TeamSeatPresentation.rejectionKey($0) })
                    }
                    // C-J2 (MP team/join wxml:55, js goBuyTicket): after a TICKET_REQUIRED rejection on an activity
                    // team (ownerType 2), the primary becomes 去买这一场的票 → that activity's registration page.
                    if TeamSeatPresentation.showsBuyTicket(errorCode: model.coordinator.rejectionCode),
                       let owner = detail.team.ownerKey, owner.type == 2 {
                        NavigationLink {
                            MPReviewedPageScreen(page: "pages/activity/baoming/baoming", query: ["activityId": String(owner.id)])
                        } label: { Text("fixr3.team.buyTicket").frame(maxWidth: .infinity) }
                            .buttonStyle(.cyPrimary).disabled(model.actionLocked)
                            .accessibilityIdentifier("teamPage.buyTicket")
                    } else {
                        actionButton(.join(teamID: detail.team.id, inviteCode: invitationCode), detail: detail,
                                     labelKey: TeamPagePresentation.showsJoinRetry(model.coordinator.writeState, page: pageKind) ? "team.page.retryJoin" : nil)
                    }
                }
                else { TeamClosedInvitationButton(cta: TeamPagePresentation.invitationCTA(detail)) }
    }
    @ViewBuilder private func actionButton(_ action: TeamAction, detail: TeamDetail, labelKey: String? = nil) -> some View {
        if !readOnly, action.isAllowed(detail: detail) {
            if case .join = action {
                // Mini-program 加入队伍 is the page's one primary action. C-J3 (MP join wxml:57-60): it joins
                // directly and reads 加入中… while the request runs; no review sheet in between.
                Button { joinDirectly(action) } label: {
                    if model.running, case .join? = model.coordinator.review?.action {
                        Text("fixr3.team.joining")
                    } else {
                        Text(LocalizedStringKey(labelKey ?? action.key))
                    }
                }
                    .buttonStyle(.cyPrimary).disabled(model.actionLocked)
                    .accessibilityIdentifier(action.key)
            } else {
                // 解散队伍 is the source's danger action; native destructive role keeps it red.
                if case .disband = action {
                    Button(role: .destructive) { model.prepare(action) } label: { Text(LocalizedStringKey(labelKey ?? action.key)) }
                        .buttonStyle(.cyDestructive).disabled(model.actionLocked)
                        .accessibilityIdentifier(action.key)
                } else {
                    Button(role: destructiveRole(action)) { model.prepare(action) } label: { Text(LocalizedStringKey(labelKey ?? action.key)) }
                        .buttonStyle(.cySecondary(fullWidth: true)).disabled(model.actionLocked)
                        .accessibilityIdentifier(action.key)
                }
            }
        }
    }
    /// C-J3: prepare and confirm in one tap. Without a submit authority the review stays and its sheet explains why.
    private func joinDirectly(_ action: TeamAction) {
        model.prepare(action)
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
                .buttonStyle(.cySecondary(fullWidth: true))
                .accessibilityLabel(Text("fixr3.team.qr.a11y"))
                .accessibilityIdentifier("team.qr.open")
                .sheet(isPresented: $shown) {
                    NavigationStack {
                        ScrollView { TeamInviteQRSection(teamID: teamID, loadsOnAppear: true).padding(CYSpacing.pageHorizontal) }
                            .navigationTitle(Text("fixr3.team.qr.title")).navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("compliance.close") { shown = false } } }
                    }
                    .presentationDetents([.medium, .large])
                }
        }
    }
}
