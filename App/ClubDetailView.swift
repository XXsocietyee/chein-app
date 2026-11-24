import SwiftUI

@MainActor
struct ClubDetailView<Reader: ClubReading & ObservableObject>: View {
    let id: Int
    @ObservedObject var reader: Reader
    var onSignIn: (() -> Void)? = nil
    var actionCoordinator: ClubActionCoordinator? = nil
    var management:ClubManagementContext? = nil
    var community: ClubCommunityContext? = nil
    /// Dedicated read approval is never inferred from membership or governance.
    var publicRoster: ClubPublicRosterReader? = nil
    /// Deep-link intent (`tab=manage`); honored only after the detail read confirms access.
    var requestedTab: ClubDetailTab? = nil
    /// CLB-detail-31: MP `postId` deep link; lands on 帖文 and scrolls the feed to that post.
    var focusPostID: Int? = nil
    @State private var selectedTab: ClubDetailTab? = nil
    @State private var manageGrant: ClubDetailManageGrant? = nil
    @State private var actionDetail: ClubRecord? = nil
    @State private var actionIdentity: ClubReadIdentity? = nil
    @State private var managementNeedsRefresh = false
    /// Figma 223:3698: 成员 opens as a sheet over the club page (medium / large), not a pushed page.
    @State private var showsMembers = false
    @State private var managementRevision: UInt64 = 0
    @State private var detailGeneration: UInt64 = 0
    @State private var reportingClub = false
    /// r4 workbench (`170:1744`): 待审批 / 去审批 push 入会申请 from the 管理 tab's head.
    @State private var showsApprovals = false
    /// Owner-stage Now card. Nil keeps the approvals headline.
    @State private var ownerStage: ClubOwnerStageResolution?
    @State private var heroScrolledAway = false
    @State private var loadedClubName: String?
    @State private var openedTopicID: Int?
    @Environment(\.clubBadgeHostFactory) private var badgeHost
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    /// verify-r1 1.3: no 俱乐部详情 over the hero; the club's name appears inline once the hero has scrolled away.
    /// CLB-detail-27 (MP detail wxml:1-2, js:784-787): a merchant account sees the club on the merchant light page.
    private var viewerDomain: ThemeDomain {
        (reader as? AppSession)?.account?.effectiveRole == "merchant" ? .merchant : .player
    }
    /// Facts the lead-progress reads already fetch. Admins resolve immediately. A failed read leaves the approvals card.
    private func loadOwnerStage(club: ClubRecord, manage: Bool) async {
        guard manage, club.canGovern, !Task.isCancelled else { ownerStage = nil; return }
        if !club.isOwner {
            ownerStage = ClubOwnerStageMachine.resolve(.init(isOwner: false, canGovern: true, clubID: club.id, topicState: "ready"))
            return
        }
        guard let session = reader as? AppSession, let governance = management?.governance else { ownerStage = nil; return }
        let context = ClubLeadProgressContext(club: club, clubReader: reader, reader: session.cooperationFlowReader,
                                              access: governance.access, projects: session.creatorContentReader)
        guard context.canRead else { ownerStage = nil; return }
        let current = { !Task.isCancelled }
        do {
            let fresh = try await reader.clubDetail(id: club.id, isCurrent: current)
            guard current(), fresh.id == club.id, fresh.isOwner else { return }
            let topics = try await governance.access.read(.topics, scope: .init(clubID: club.id), options: [:]) {
                guard current() else { throw CancellationError() }
            }
            guard current() else { return }
            let invitations = try await session.cooperationFlowReader.read(.invitations, isCurrent: current)
            guard current() else { return }
            let page = try await session.creatorContentReader.projects(query: .init(type: "all", state: "all", ownerType: "club"))
            guard current() else { return }
            ownerStage = ClubOwnerStageNow.resolve(club: fresh, topics: topics, invitations: invitations, projects: page)
        } catch {
            guard current() else { return }
            ownerStage = nil
        }
    }
    /// CLB-detail-20 / CLB-r7-A-01: MP `club.isOwner || canManageActivities` (access/me `club:activity:manage`).
    private func canManageActivities(_ club: ClubRecord) -> Bool {
        club.isOwner || manageGrant?.permissions.contains("club:activity:manage") == true
    }
    private var navigationTitleText: String {
        guard let loadedClubName else { return appLocalized("club.detail", locale: locale) }
        return heroScrolledAway ? loadedClubName : ""
    }
    var body: some View {
        ClubReadScreen(reader: reader, accessibilityPrefix: "club.detail", refreshRevision: managementRevision, showsToolbarRefresh: false, usesClubPageStates: true, onSignIn: onSignIn,
                       load: {
                           detailGeneration &+= 1
                           let revision = detailGeneration, identity = reader.clubIdentity
                           let detail = try await reader.clubDetail(id: id)
                           // Neither an older refresh nor a pre-mutation read can
                           // replace a newer refresh or action readback.
                           guard !Task.isCancelled, revision == detailGeneration, identity == reader.clubIdentity else { throw CancellationError() }
                           // Clear on every accepted read, even if its value equals the
                           // older pre-action snapshot (for example after removal).
                           actionDetail = nil; actionIdentity = nil
                           return detail
                       }) { loadedClub in
            let club = actionIdentity == reader.clubIdentity && actionDetail?.id == id ? (actionDetail ?? loadedClub) : loadedClub
            let facts = detailFacts(club)
            let tabs = ClubDetailTabPolicy(club: club, grant: manageGrant)
            let tab = tabs.resolve(selectedTab ?? tabs.initialTab(requested: focusPostID != nil ? .posts : requestedTab))
            List {
                // skill-r2 hand-off `204:24899` / `204:24850` (Club/Header, MC-22): cover banner, logo beside the name,
                // one meta line 「类型 · N 名成员 · 公开加入」, the host line, and the viewer's status as a tag.
                Section {
                    ClubDetailHeader(club: club, memberText: facts.meta, content: facts.content)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if let actionCoordinator {
                    ClubActionPanel(club: club, identity: reader.clubIdentity, coordinator: actionCoordinator, onSignIn: onSignIn,
                                    leavesAtPageEnd: tab == .overview,
                                    onReadbackStarted: { detailGeneration &+= 1; return detailGeneration }) { detail, identity, generation in
                        guard identity == reader.clubIdentity, detail.id == id, generation == detailGeneration else { return }
                        actionDetail = detail; actionIdentity = identity
                    }
                }
                ClubDetailTabBar(tabs: tabs.tabs, selection: tab) { selectedTab = tabs.select($0, from: tab) }
                // r4 · 主理人工作台 (`170:1744`, MC-28): 现在要做 and the three numbers head the 管理 tab; the project and
                // management rows below keep their order (项目 · 合作与期次 · 管理).
                if tab == .manage, club.canGovern {
                    ClubWorkbenchSection(summary: ClubWorkbenchSummary(club: club),
                                         ownerStage: ownerStage,
                                         onApprovals: management == nil ? nil : { showsApprovals = true },
                                         onEvents: { selectedTab = tabs.select(.events, from: tab) })
                }
                if tab == .posts, (club.isOwner || club.isJoined), reader.clubIdentity.isSignedIn, let session = reader as? AppSession {
                    Section {
                        NavigationLink { SessionClubChatView(clubID: id, session: session) } label: {
                            CYListRow("club.chat.title", trailing: .none, card: true) { CYRowIcon(systemImage: "person.3") }
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("club.chat.entry")
                        NavigationLink { BeGapImDesk(clubID: Int64(id), session: session) } label: {
                            CYListRow("beGapIm.entry", trailing: .none, card: true) { CYRowIcon(systemImage: "list.bullet.rectangle") }
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("beGapIm.entry")
                        if facts.channels {
                        NavigationLink {
                            ClubChannelMessagingHostView(
                                club: club,
                                reader: reader,
                                manageGrant: manageGrant,
                                safetyService: session.makeClubChannelSafetyService(
                                    club: club,
                                    management: management,
                                    community: community
                                ),
                                onSignIn: onSignIn
                            )
                        } label: {
                            Label(locale.pick("俱乐部频道", "Club Channels"), systemImage: "number.square")
                        }
                        .accessibilityIdentifier("club.channels.discordEntry")
                        }
                        NativeChannelManagementClubEntry(club: club, session: session)
                    }
                }
                if tab == .manage, club.isOwner, let session = reader as? AppSession {
                    Section { NavigationLink("context.ai.title") { SessionClubAIDesignView(session: session, clubID: id) }.accessibilityIdentifier("club.context.openAI") }
                    Section { NavigationLink("club.projectLaunch.title") { SessionClubProjectLaunchView(session: session, club: club) }.accessibilityIdentifier("club.projectLaunch.entry") }
                }
                if tab == .manage, let session = reader as? AppSession {
                    // Keep the scope binder mounted for non-owners so owner loss fences old callbacks immediately;
                    // leaving the manage tab unmounts it with the rest of the tab.
                    SessionClubMerchantProfileHost(session: session) {
                        ClubMerchantDiscoveryView(club: club, clubReader: reader, reader: session.cooperationFlowReader)
                    }
                    if let governance = management?.governance {
                        ClubInvitationFeedbackEntry(club: club, clubReader: reader, reader: session.cooperationFlowReader, access: governance.access)
                        ClubLeadProgressEntry(club: club, clubReader: reader, reader: session.cooperationFlowReader, access: governance.access, projects: session.creatorContentReader, destinations: session.clubLeadPrimaryDestinations(club: club, governance: governance))
                    }
                }
                if tab == .posts, community == nil {
                    Section {
                        CYEmptyState(systemImage: "text.bubble", "club.detail.posts.unavailable")
                            .accessibilityIdentifier("club.detail.posts.unavailable")
                    }
                }
                if tab == .posts, let community {
                    Section {
                        ClubCommunityEntry(clubID: id, identity: reader.clubIdentity, context: community, focusPostID: focusPostID)
                            .environment(\.clubEnrollmentProfile, management?.governance?.enrollmentProfile)
                            .environment(\.clubCustomerTopics, management?.governance?.customerTopics ?? .init())
                            .environment(\.clubPostPlayHost, ClubPostPlayHost.session(reader as? AppSession))
                    }
                }
                // CLB-detail-02: 活动 lists the club's current activities inline for every viewer (MP detail
                // wxml:163-216, /api/club/topics). Public topics use their own viewer grant, never access/me.
                if tab == .events, let session = reader as? AppSession {
                    if canManageActivities(club) {
                        // MP 「发布 +」 / 发布主题 for the owner or `club:activity:manage` (wxml:204-213, CLB-detail-20).
                        Section {
                            NavigationLink { SessionClubProjectLaunchView(session: session, club: club) } label: {
                                CYListRow("club.detail.events.publish", trailing: .none) { CYRowIcon(systemImage: "plus") }
                            }
                            .accessibilityIdentifier("club.detail.events.publish")
                        }
                    }
                    SessionClubPublicActivityListView(clubID: id, session: session, onSignIn: onSignIn, embedded: { openedTopicID = $0 })
                }
                // V2 governance has its own access/me model, including delegated event staff.
                if tab == .events, let governance = management?.governance {
                    Section {
                        ClubSessionQuickStartEntry(club: club, reader: reader, governance: governance)
                    }
                }
                // Members without a manage tab still reach their own governance cases from the overview.
                if tab == .manage || (tab == .overview && !tabs.canUseManageTab), let governance = management?.governance {
                    Section {
                        if club.isOwner {
                            NavigationLink {
                                ClubStatsOverviewView(clubID: id, identity: reader.clubIdentity, governance: governance)
                            } label: { Label("club.statsOverview.title", systemImage: "chart.bar") }
                                .accessibilityIdentifier("club.statsOverview.open")
                        }
                        // CLB-r7-A-05 (MP quick action 结算, wxml:384-388, js:1066): owner only, on 管理.
                        if club.isOwner, tab == .manage {
                            NavigationLink {
                                ClubGovernanceReadView(operation: .settlement, scope: .init(clubID: id), identity: reader.clubIdentity,
                                                       access: governance.access, coordinator: governance.coordinator)
                            } label: { Label("club.detail.manage.settlement", systemImage: "yensign.circle") }
                                .accessibilityIdentifier("club.detail.manage.settlement")
                        }
                        ClubGovernanceEntryButton(clubID: id, identity: reader.clubIdentity, access: governance.access, coordinator: governance.coordinator, enrollmentProfile: governance.enrollmentProfile, ownerRefund: governance.ownerRefund, opsTimeFactory: governance.opsTimeFactory, customerTopics: governance.customerTopics, storyTemplates: governance.storyTemplates, terminalSessions: governance.terminalSessions, ownerFunds: governance.ownerFunds, titleKey: tab == .manage ? "club.gov.workspace" : "club.gov.myRecords")
                    }
                }
                if (club.isOwner || club.viewerIsAdmin), tab == .manage, let management {
                    Section {
                        if let operations = management.operations {
                            ClubOperationsEntryButton(target: .club(id), identity: reader.clubIdentity, access: operations.access, coordinator: operations.coordinator, hostApplication: management.governance, onConfirmedReturn: { result in
                                guard result.identity == reader.clubIdentity, result.clubID == id else { return }
                                detailGeneration &+= 1; actionDetail = nil; actionIdentity = nil; manageGrant = nil
                                managementRevision &+= 1
                            }, onWelcomeConfirmedReturn: { result in
                                guard result.matches(target: .club(id), identity: reader.clubIdentity, access: operations.access) else { return }
                                // The saved text is historical evidence, not a current-detail substitute.
                                detailGeneration &+= 1; actionDetail = nil; actionIdentity = nil; manageGrant = nil
                                managementRevision &+= 1
                            })
                        }
                        NavigationLink {
                            ClubManagementView(clubID:id,identity:reader.clubIdentity,access:management.access,coordinator:management.coordinator, viewerRevision:management.viewerRevision, onMembershipChanged: {
                                // Do not reload a hidden NavigationLink source while its
                                // management destination is still showing the receipt.
                                managementNeedsRefresh = true
                            })
                        } label: { Label("club.management.title",systemImage:"person.2.badge.gearshape") }
                        .accessibilityIdentifier("club.openManagement")
                    }
                }
                if tab == .overview {
                    // CLB-detail-21 (MP wxml:219-250): the introduction opens 概览 with no 俱乐部介绍 header (global rule:
                    // no sub-title under a title), then the 俱乐部勋章 row. The MP no longer shows 活动偏好 / 关键词 / 风格.
                    Section {
                        if let description = club.description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(verbatim: description).textSelection(.enabled)
                                .accessibilityIdentifier("club.detail.introduction")
                        } else { Text("club.noIntroduction").foregroundStyle(.secondary) }
                    }
                    if let host = badgeHost(id) { ClubBadgeManagementNavigationEntry(host: host).id(host.id) }
                    Section {
                        if club.canSeeMembers {
                            Button { showsMembers = true } label: {
                                HStack {
                                    Label("club.viewMembers", systemImage: "person.3")
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary).accessibilityHidden(true)
                                }
                                .contentShape(Rectangle())
                            }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showsMembers) {
                                    NavigationStack {
                                        ClubMembersView(id: club.id, reader: reader, profile: management?.governance?.enrollmentProfile, governance: management?.governance, onSignIn: onSignIn)
                                            .toolbar {
                                                ToolbarItem(placement: .cancellationAction) {
                                                    Button { showsMembers = false } label: { Image(systemName: "xmark") }
                                                        .accessibilityLabel(Text("club.ops.close"))
                                                        .accessibilityIdentifier("club.members.close")
                                                }
                                            }
                                    }
                                    .presentationDetents([.medium, .large])
                                    .presentationDragIndicator(.visible)
                                }
                                // verify-r1 2.7: one card per row (no card-in-card), one chevron, no hairline.
                                .listRowSeparator(.hidden)
                                .accessibilityIdentifier("club.openMembers")
                        } else if publicRoster?.authorization?.identity == reader.clubIdentity,
                                  ClubPublicRosterEligibility.mayRequest(club, identity: reader.clubIdentity) {
                            NavigationLink {
                                ClubPublicRosterView(clubID: club.id, reader: reader, source: publicRoster,
                                    profile: nil, viewerRevision: managementRevision, leaderboard: false)
                            } label: { Label("club.viewMembers", systemImage: "person.3") }
                        } else {
                            Text(club.needsApproval ? "club.detail.members.lockedReview" : "club.detail.members.locked")
                                .foregroundStyle(.secondary).accessibilityIdentifier("club.members.gated")
                        }
                    } header: { if let count = Int(facts.raw) { Text("club.detail.membersCount \(count)") } else { Text(verbatim: facts.raw) } }
                    // Mini-program overview: 本团贡献榜 · 本周, gated on member visibility like the source.
                    Section("club.detail.leaderboard.title") {
                        if club.canSeeMembers, let governance = management?.governance {
                            NavigationLink {
                                ClubGovernanceReadView(operation: .leaderboard, scope: .init(clubID: id), identity: reader.clubIdentity, access: governance.access, coordinator: governance.coordinator)
                                    .environment(\.clubEnrollmentProfile, governance.enrollmentProfile)
                            } label: { Label("club.detail.leaderboard.open", systemImage: "trophy") }
                                .accessibilityIdentifier("club.detail.leaderboard.open")
                        } else if club.canSeeMembers {
                            Text("club.detail.leaderboard.unavailable").foregroundStyle(.secondary).accessibilityIdentifier("club.detail.leaderboard.unavailable")
                        } else if publicRoster?.authorization?.identity == reader.clubIdentity,
                                  ClubPublicRosterEligibility.mayRequest(club, identity: reader.clubIdentity) {
                            NavigationLink {
                                ClubPublicRosterView(clubID: club.id, reader: reader, source: publicRoster,
                                    profile: nil, viewerRevision: managementRevision, leaderboard: true)
                            } label: { Label("club.detail.leaderboard.open", systemImage: "trophy") }
                        } else {
                            // CLB-detail-22 (MP js:343-350): 需审核 clubs say 通过审核后可看贡献榜.
                            Text(club.needsApproval ? "club.detail.leaderboard.lockedReview" : "club.detail.leaderboard.locked")
                                .foregroundStyle(.secondary).accessibilityIdentifier("club.detail.leaderboard.locked")
                        }
                    }
                    // CLB-r7-A-02 (MP wxml:288, D13): say so when the server could not confirm the viewer's role.
                    if club.viewerIdentityUnavailable {
                        Section {
                            Text("club.detail.identityUnavailable").cyText(.meta).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("club.detail.identityUnavailable")
                        }
                    }
                    // CLB-r7-A-03 (MP wxml:349-358, P-19): 治理与安全 · 封禁申诉 on 概览 for the owner and administrators only;
                    // it opens the club's governance cases, as MP `governance?mode=appeal` does.
                    if club.isOwner || club.viewerIsAdmin, let governance = management?.governance {
                        Section("club.detail.safety.title") {
                            NavigationLink {
                                ClubGovernanceReadView(operation: .cases, scope: .init(clubID: id), identity: reader.clubIdentity,
                                                       access: governance.access, coordinator: governance.coordinator)
                            } label: { Label("club.detail.safety.appeal", systemImage: "checkmark.shield") }
                                .accessibilityIdentifier("club.detail.safety.appeal")
                        }
                    }
                    // HANDOFF-R1 MC-20: 退出俱乐部 and 举报俱乐部 close 概览 as quiet red rows; 退出 still confirms.
                    if let actionCoordinator {
                        ClubActionPanel(club: club, identity: reader.clubIdentity, coordinator: actionCoordinator, onSignIn: onSignIn,
                                        placement: .pageEnd,
                                        onReportClub: management?.governance == nil ? nil : { reportingClub = true },
                                        onReadbackStarted: { detailGeneration &+= 1; return detailGeneration }) { detail, identity, generation in
                            guard identity == reader.clubIdentity, detail.id == id, generation == detailGeneration else { return }
                            actionDetail = detail; actionIdentity = identity
                        }
                    }
                }
            }
            .cyGroupedSurface()
            .scrollContentBackground(.hidden)
            .cyDomainPageBackground()
            .cyTracksHeroScroll($heroScrolledAway)
            .onChange(of: club.name, initial: true) { _, name in loadedClubName = name }
            .task(id: "\(club.id)|\(tab.rawValue)|\(club.isOwner)|\(club.canGovern)|\(reader.clubIdentity.accountID ?? 0)") {
                await loadOwnerStage(club: club, manage: tab == .manage)
            }
            // CLB-detail-32 (owner native-iOS rule 11-24): the system bar and system back stay visible; the club's
            // name appears inline once the hero has scrolled away.
            .cyPushedChrome(domain: viewerDomain)
            .navigationDestination(isPresented: $showsApprovals) {
                if let management {
                    ClubManagementView(clubID: id, identity: reader.clubIdentity, access: management.access, coordinator: management.coordinator,
                                       viewerRevision: management.viewerRevision, onMembershipChanged: { managementNeedsRefresh = true })
                }
            }
            .toolbar {
                // MC-22: share sits in the bar beside the system back (a glass circle on iOS 26+ bars).
                ToolbarItem(placement: .topBarTrailing) { ClubHeaderShareButton(clubID: club.id) }
            }
            .navigationDestination(item: $openedTopicID) { topicID in
                // CLB-r7-A-01 (MP goTopic js:2957-2966): governors and activity managers open the club topic-detail;
                // everyone else opens the ordinary topic page.
                if (club.canGovern || canManageActivities(club)), let governance = management?.governance {
                    ClubGovernanceReadView(operation: .topicOverview, scope: .init(clubID: id, topicID: topicID),
                                           identity: reader.clubIdentity, access: governance.access, coordinator: governance.coordinator)
                        .environment(\.clubEnrollmentProfile, governance.enrollmentProfile)
                } else if let session = reader as? AppSession { SessionTopicDetailView(id: topicID, session: session) }
            }
            .navigationDestination(isPresented: $reportingClub) {
                if let governance = management?.governance {
                    // 举报俱乐部: the governance case form, target type CLUB for this club.
                    ClubGovernanceCommandForm(route: .init(operation: .report, scope: .init(clubID: id)),
                                              identity: reader.clubIdentity, access: governance.access, coordinator: governance.coordinator)
                }
            }
            .background {
                if let session = reader as? AppSession, let context = session.currentRuntimeDependencyContext,
                   reader.clubIdentity == ClubReadIdentity(accountID: context.session.accountID, epoch: context.session.epoch) {
                    ClubMemberWelcomeHost(club: club, identity: reader.clubIdentity,
                        namespace: context.baseURL.absoluteString + "|" + context.session.namespace,
                        role: context.role, active: !managementNeedsRefresh,
                        goEvents: { selectedTab = .events })
                }
            }
            .task(id: ClubDetailManageGrantKey(clubID: id, identity: reader.clubIdentity, hasGovernance: management?.governance != nil)) {
                await loadManageGrant()
            }
        }.safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Space.s2) {
                if let session = reader as? AppSession {
                    // Same-account history remains reachable after owner loss or failed detail reads.
                    ClubWelcomeNoteRecoveryEntry(clubID: id, identity: reader.clubIdentity,
                        access: session.clubOperationsAccess)
                }
            if let actionCoordinator, reader.clubIdentity.isSignedIn {
                // Outside the loaded-detail closure: failed current reads do not
                // hide an account-owned original request or open a private subtree.
                ClubActionOriginalRecoveryView(clubID: id, identity: reader.clubIdentity, coordinator: actionCoordinator)
                    .id(reader.clubIdentity)
            }
            }
        }.navigationTitle(navigationTitleText).navigationBarTitleDisplayMode(.inline)
            .cyPushedChrome(domain: viewerDomain)
            .cyDomainPageBackground()
            .tint(CYDomainPalette(viewerDomain).brand)
            .id(id)
            .onAppear {
                guard managementNeedsRefresh else { return }
                managementNeedsRefresh = false
                detailGeneration &+= 1
                actionDetail = nil; actionIdentity = nil
                managementRevision &+= 1
            }
            .onChange(of: reader.clubIdentity) { _, _ in actionDetail = nil; actionIdentity = nil; manageGrant = nil; selectedTab = nil }
    }

    /// Projects the decoded club through `ClubDetailPageModel`. `ClubRecord` stores a missing
    /// member count or level as 0, so only source-present facts are forwarded: unknown stays `—`.
    private func detailFacts(_ club: ClubRecord) -> (meta: String, raw: String, channels: Bool, content: ClubDetailPageContent?) {
        var body: [String: Any] = ["id": club.id, "name": club.name, "isOwner": club.isOwner, "isJoined": club.isJoined, "viewerIsAdmin": club.viewerIsAdmin]
        if let count = club.sourceMemberCount { body["memberCount"] = count }
        if club.level > 0 { body["level"] = club.level }
        if let leader = club.leaderName { body["leaderName"] = leader }
        if let city = club.city { body["city"] = city }
        if let address = club.address { body["address"] = address }
        if let type = club.clubType { body["clubType"] = type }
        if let types = club.clubTypes { body["clubTypes"] = types }
        let page = ClubDetailPageModel.resolve(loading: false, payload: try? JSONSerialization.data(withJSONObject: body), failure: nil, signedIn: reader.clubIdentity.isSignedIn, grant: manageGrant, hasCommunity: community != nil, hasGovernance: management?.governance != nil)
        guard case .ready(let ready) = page else {
            let mark = ClubDetailPageModel.unknownMark
            return (mark, mark, false, nil)
        }
        let raw = ready.memberCountText
        return (raw == ClubDetailPageModel.unknownMark ? raw : (Int(raw).map { ClubMemberCountLocalization.text($0, locale: locale) } ?? raw), raw, ready.showsChannels, ready)
    }

    /// `/api/club/access/me` only widens the manage tab; a failed or foreign read revokes
    /// to the legacy owner/admin flags, as `revokeClubAccess` does in the mini-program.
    private func loadManageGrant() async {
        manageGrant = nil
        guard let governance = management?.governance, reader.clubIdentity.isSignedIn else { return }
        let identity = reader.clubIdentity
        let grant: ClubDetailManageGrant?
        do {
            let snapshot = try await governance.access.read(.access, scope: .init(clubID: id), options: [:])
            grant = snapshot.permissions.map { ClubDetailManageGrant($0) }
        } catch { grant = nil }
        guard !Task.isCancelled, identity == reader.clubIdentity else { return }
        manageGrant = grant?.clubID == id ? grant : nil
    }
}

private struct ClubDetailManageGrantKey: Hashable {
    let clubID: Int
    let identity: ClubReadIdentity
    let hasGovernance: Bool
}

/// Club cover hero: the real cover when there is one, the MP default artwork otherwise (round 2, MP assets:
/// `club_cover_default.png` for the cover, `d_logo.png` for the logo).
private struct ClubDetailCover: View {
    let source: String?
    var seed: String = ""
    var showsSymbol = true
    var fallback: Image? = nil
    @QuestifyReduceMotion private var reduceMotion
    var body: some View {
        ZStack {
            if let fallback {
                fallback.resizable().scaledToFill()
            } else {
                CYIMCoverArt(seed: seed, symbolSize: showsSymbol ? 48 : 0)
            }
            if let url = QuestifyCardArtwork.safeURL(source) {
                AsyncImage(url: url, transaction: Transaction(animation: reduceMotion ? nil : QuestifyMotion.content)) { phase in
                    if let image = phase.image { image.resizable().scaledToFill().transition(.opacity) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        .accessibilityHidden(true)
    }
}

/// Club/Header (skill-r2 `204:24899`, MC-22). Cover banner; logo 52 pt beside the name and one meta line; the host
/// line 「主理人 X · 城市」 (known facts only, never an em dash); the viewer's role as a neutral tag. Large type drops the
/// logo and lets every line wrap.
private struct ClubDetailHeader: View {
    let club: ClubRecord
    let memberText: String
    let content: ClubDetailPageContent?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .title) private var bannerHeight: CGFloat = 160  // CLB-detail-37: MP cover-wrap 160

    private static func known(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty || text == ClubDetailPageModel.unknownMark ? nil : text
    }
    private var typeText: String? { Self.known(content?.typeText ?? club.clubType ?? club.clubTypes) }
    private var leaderText: String? { Self.known(content?.leaderText ?? club.leaderName) }
    private var cityText: String? { Self.known(content?.cityText ?? club.city ?? club.address) }

    private var metaLine: String {
        var parts: [String] = []
        if let typeText { parts.append(typeText) }
        if memberText != ClubDetailPageModel.unknownMark { parts.append(memberText) }
        if club.joinPolicySupported {
            parts.append(appLocalized(club.needsApproval ? "club.detail.joinPolicy.review" : "club.detail.joinPolicy.open", locale: locale))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            ClubDetailCover(source: club.cover, seed: club.name + String(club.id), showsSymbol: false,
                            fallback: MPAsset.BannerCover.clubCoverDefault)
                .frame(height: typeSize.isAccessibilitySize ? 96 : bannerHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                // CLB-detail-32: back and share live in the system navigation bar, not on the cover.
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    if !typeSize.isAccessibilitySize {
                        ClubDetailCover(source: club.logo, seed: club.name, showsSymbol: false, fallback: MPAsset.BrandLogo.dLogo)
                            .frame(width: 56, height: 56)  // CLB-detail-37: MP logo 112 rpx
                            .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).stroke(CYNight.glassEdgeTop, lineWidth: 1))
                            .accessibilityIdentifier("club.detail.logo")
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        ClubName(value: club.name).cyText(.pageTitle).foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("club.detail.name")
                            .cyHeroTitleRise()
                        if !metaLine.isEmpty {
                            Text(verbatim: metaLine).cyText(.meta).foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("club.detail.fact.memberCount")
                        }
                    }
                    Spacer(minLength: 0)
                }
                if leaderText != nil || cityText != nil {
                    HStack(spacing: 4) {
                        if let leaderText {
                            Text(verbatim: appLocalized("club.leader", locale: locale) + " " + leaderText)
                                .accessibilityIdentifier("club.detail.fact.leader")
                        }
                        if leaderText != nil, cityText != nil { Text(verbatim: "·").accessibilityHidden(true) }
                        if let cityText { Text(verbatim: cityText).accessibilityIdentifier("club.detail.fact.city") }
                    }
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("club.detail.factsGrid")
                }
                statusTags
                // MC-22 Member / Manager header: 邀请朋友加入 is the header's one full-width action (the visitor's 加入
                // stays in the action panel right under the header).
                // CLB-detail-24: MP gives 邀请成员 to the owner and administrators only (wxml:260, 765).
                if club.isOwner || club.viewerIsAdmin {
                    ClubHeaderInviteButton(clubName: club.name)
                        .padding(.top, CYSpacing.xs)
                }
            }
            .padding(.horizontal, CYSpacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The viewer's relation to the club: role tags are neutral; pending is amber, a declined request red with its reason.
    @ViewBuilder private var statusTags: some View {
        if club.isOwner || club.isJoined || club.joinPending || club.myJoinStatus == 2 || club.viewerIsAdmin {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                HStack(spacing: CYSpacing.sm) {
                    if club.isOwner { CYStatusChip("club.role.creator", tone: .neutral, systemImage: "person.crop.circle.badge.checkmark") }
                    else if club.isJoined { CYStatusChip("club.membership.joined", tone: .neutral, systemImage: "checkmark.circle") }
                    else if club.joinPending { CYStatusChip("club.membership.pending", tone: .warning, systemImage: "clock") }
                    else if club.myJoinStatus == 2 { CYStatusChip("club.membership.rejected", tone: .danger, systemImage: "xmark.circle") }
                    if club.viewerIsAdmin { CYStatusChip("club.viewerAdministrator", tone: .neutral, systemImage: "person.badge.shield.checkmark") }
                }
                if club.myJoinStatus == 2, let reason = club.myJoinReviewReason {
                    Text(verbatim: locale.pick("申请未通过：\(reason)", "Application not approved: \(reason)"))
                        .cyText(.meta)
                        .foregroundStyle(CYColor.dangerText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("club.membership.rejectedReason")
                }
            }
        }
    }
}
