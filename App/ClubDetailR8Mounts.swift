import SwiftUI

/// fix-r8-club: reads behind the compiled `ClubGap*` views mounted on the club page.
/// - CLB-detail-09 / CLB-r7-A-04: 管理中的项目 with 活动导演台 and 场次工具 (MP detail wxml:452-475, js:2988-3031, 1110-1220).
/// - CLB-G04: 可对接的活动 + 我的合作 + 申请带队 on 管理 (MP js:3780-3847).
/// - CLB-G08: the overview member avatar strip (MP wxml:265-280).
/// Each read is keyed; a newer key (club, account, tab) drops the older result.
@MainActor final class ClubDetailR8MountModel: ObservableObject {
    /// CLB-detail-09 (MP `loadTopics` js:2265-2316): every `/api/club/topics` row; sessions are read on tap.
    @Published private(set) var projects: [ClubManagedProjectRow] = []
    @Published private(set) var projectsState: ClubManagedProjectsState = .idle
    @Published private(set) var coopPool: ClubCoopPoolLoadState = .idle
    @Published private(set) var memberAvatars: [ClubGapMemberAvatarStrip.AvatarItem] = []
    @Published private(set) var memberTotal = 0
    /// CLB-r7-A-06: 「N 个团」 beside 报名名册 (every club topic, not the capped project page).
    @Published private(set) var topicTotal: Int?
    /// CLB-r7-A-06: 「N 人」 beside 查看客户, or 暂时读不到 when the count read fails (MP js:3591-3601).
    @Published private(set) var customerCountText: String?
    /// CLB-r11-detail-01: 俱乐部分润 beside 经营 (owner only): the server's settledAmountText, or 暂时读不到 (MP js:3587-3604).
    @Published private(set) var settledAmountText: String?
    @Published private(set) var coopApplyPendingTopicID: Int?
    @Published var coopApplyNoticeKey: String?
    @Published var coopApplyServerNotice: String?
    private var settingsCountsFor: Int?
    private var projectsKey: String?
    private var poolKey: String?
    private var avatarsKey: String?
    /// CLB-r7-A-06 (MP loadSettingsCounts js:3579-3601): read once per club when 俱乐部设置 opens; a failure clears the
    /// guard so the next opening asks again. Owner / admin only, as the MP sends it.
    func loadSettingsCounts(clubID: Int, canSeeCustomers: Bool, isOwner: Bool = false, access: any ClubGovernanceAccess, locale: Locale = .current) async {
        guard canSeeCustomers, settingsCountsFor != clubID else { return }
        settingsCountsFor = clubID
        // CLB-r11-detail-01 (MP detail js:3587-3604): owner only, `api/club/settlement/summary`; the amount is passed
        // through as the server wrote it, and a failure reads 暂时读不到 (a blank would read as zero).
        if isOwner {
            do {
                let summary = try await access.read(.settlement, scope: .init(clubID: clubID), options: [:])
                if settingsCountsFor == clubID, !Task.isCancelled,
                   let text = summary.value["settledAmountText"].string, !text.isEmpty { settledAmountText = text }
            } catch {
                if settingsCountsFor == clubID, !Task.isCancelled {
                    settledAmountText = appLocalized("club.settings.countUnavailable", locale: locale)
                }
            }
        }
        if topicTotal == nil,
           let topics = try? await access.read(.topics, scope: .init(clubID: clubID), options: [:]),
           settingsCountsFor == clubID, !Task.isCancelled {
            topicTotal = topics.value.array?.count
        }
        do {
            let count = try await access.read(.customerCount, scope: .init(clubID: clubID), options: [:])
            guard settingsCountsFor == clubID, !Task.isCancelled else { return }
            if let total = count.value["total"].int, total > 0 { customerCountText = String(format: appLocalized("club.settings.customerCount %lld", locale: locale), total) }
        } catch {
            guard settingsCountsFor == clubID, !Task.isCancelled else { return }
            settingsCountsFor = nil
            customerCountText = appLocalized("club.settings.countUnavailable", locale: locale)
        }
    }

    func loadProjects(key: String, clubID: Int, showsDirector: Bool, locale: Locale, access: any ClubGovernanceAccess,
                      force: Bool = false) async {
        guard force || projectsKey != key else { return }
        projectsKey = key
        // MP CP-03: a refresh keeps the ready list; a first read shows the skeleton.
        if !(force && projectsState == .ready) { projectsState = .loading; projects = [] }
        let current = { [weak self] in self?.projectsKey == key && !Task.isCancelled }
        do {
            let topics = try await access.read(.topics, scope: .init(clubID: clubID), options: [:]) {
                guard current() else { throw CancellationError() }
            }
            guard current() else { return }
            topicTotal = topics.value.array?.count
            projects = (topics.value.array ?? []).compactMap { ClubManagedProjectRow(value: $0, showsDirector: showsDirector, locale: locale) }
            projectsState = .ready
        } catch {
            // MP wxml:456: 项目列表加载失败 + 重新加载 (the next appearance also retries).
            guard current() else { return }
            projectsKey = nil
            projects = []
            projectsState = .failed
        }
    }

    /// MP `_topicActivities` (js:1159-1176): one topic's sessions, read when 活动导演台 or 场次工具 is tapped.
    /// Nil means the read failed (MP E-15f: a failure is not "no sessions").
    static func topicSessions(topicID: Int, clubID: Int, locale: Locale, access: any ClubGovernanceAccess) async -> [ClubManagedDirectorSession]? {
        guard let overview = try? await access.read(.topicOverview, scope: .init(clubID: clubID, topicID: topicID), options: [:]) else {
            return nil
        }
        return sessions(overview.value["activityList"], locale: locale)
    }

    /// MP `listGroupCodeActivities`: drops the topic's self-host shell; the label is 「名称 · M月D日 HH:mm」.
    static func sessions(_ list: ClubGovernanceValue?, locale: Locale) -> [ClubManagedDirectorSession] {
        (list?.array ?? []).compactMap { activity in
            guard activity["selfHostShell"].bool != true, let id = activity["id"].int, id > 0 else { return nil }
            let name = activity["name"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = name.isEmpty ? String(format: appLocalized("clubR8.session.fallback %lld", locale: locale), id) : name
            return .init(id: id, title: title, timeLabel: startLabel(activity, locale: locale))
        }
    }

    private static func startLabel(_ activity: ClubGovernanceValue, locale: Locale) -> String? {
        let date = (activity["startDate"].string ?? "").trimmingCharacters(in: .whitespaces)
        let time = (activity["startTime"].string ?? "").trimmingCharacters(in: .whitespaces)
        let dateParts = date.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard dateParts.count == 3 else { return nil }
        let clock = time.isEmpty ? String(date.dropFirst(11)) : time
        let timeParts = clock.split(separator: ":").prefix(2).compactMap { Int($0) }
        guard timeParts.count == 2 else { return nil }
        var parts = DateComponents()
        parts.year = dateParts[0]; parts.month = dateParts[1]; parts.day = dateParts[2]
        parts.hour = timeParts[0]; parts.minute = timeParts[1]
        guard let value = Calendar(identifier: .gregorian).date(from: parts) else { return nil }
        return value.formatted(.dateTime.month().day().hour().minute().locale(locale))
    }

    func loadCoopPool(key: String, reader: any CooperationReading, locale: Locale, force: Bool = false) async {
        guard force || poolKey != key else { return }
        poolKey = key; coopPool = .loading
        do {
            let pool = try await reader.pool()
            guard poolKey == key, !Task.isCancelled else { return }
            guard pool.hasClub else { coopPool = .permission(ClubCoopPoolCopy.becomeOwnerPermission); return }
            coopPool = .ready(pool.rows.map { Self.card($0, locale: locale) })
        } catch {
            guard poolKey == key, !Task.isCancelled else { return }
            coopPool = .error(ClubCoopPoolCopy.networkError)
        }
    }

    private static func card(_ row: CooperationPoolItem, locale: Locale) -> ClubCoopPoolCardItem {
        let deadline: String? = row.recruitDeadline.flatMap { value in
            switch value {
            case .text(let text): return text.isEmpty ? nil : text
            case .milliseconds: return value.date?.formatted(.dateTime.month().day().hour().minute().locale(locale))
            }
        }
        let name = row.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return .init(topicID: row.topicId,
                     name: name.isEmpty ? appLocalized("cooperation.unnamedTopic", locale: locale) : name,
                     stateText: appLocalized(String.LocalizationValue(stringLiteral: row.stateKey), locale: locale),
                     isTaken: ["taken", "cooped", "converted"].contains(row.state ?? ""),
                     merchantNick: row.merchantNick, subtitle: row.subtitle,
                     deadlineText: deadline.map { appLocalized("cooperation.expires", locale: locale) + " " + $0 },
                     canApply: ClubCoopPoolApplyClient.canApply(state: row.state), applyID: row.applyId)
    }

    /// One 申请带队 at a time. Success and an unknown result both re-read the pool.
    func applyCoopPool(topicID: Int, clubID: Int, message: String, session: AppSession, key: String, locale: Locale) async {
        guard coopApplyPendingTopicID == nil, let submit = session.clubCoopPoolApply else { return }
        coopApplyPendingTopicID = topicID
        coopApplyNoticeKey = nil
        coopApplyServerNotice = nil
        defer { coopApplyPendingTopicID = nil }
        do {
            try await submit(topicID, clubID, message)
            coopApplyNoticeKey = "club.coopPool.applied"
            await loadCoopPool(key: key, reader: session.cooperationReader, locale: locale, force: true)
        } catch let refusal as MPGapServerRefusal {
            if let text = refusal.message, !text.isEmpty { coopApplyServerNotice = text } else { coopApplyNoticeKey = "club.coopPool.applyFailed" }
        } catch is CancellationError {
            return
        } catch is APIError {
            coopApplyNoticeKey = "club.coopPool.applyFailed"
        } catch {
            coopApplyNoticeKey = "club.coopPool.applyUnknown"
            await loadCoopPool(key: key, reader: session.cooperationReader, locale: locale, force: true)
        }
    }

    func loadMemberAvatars<Reader: ClubReading>(key: String, clubID: Int, reader: Reader) async {
        guard avatarsKey != key else { return }
        avatarsKey = key; memberAvatars = []; memberTotal = 0
        guard let directory = try? await reader.clubMembers(id: clubID, isCurrent: { [weak self] in self?.avatarsKey == key }),
              avatarsKey == key, !Task.isCancelled else { return }
        memberAvatars = directory.members.prefix(4).map {
            .init(id: String($0.memberId), name: $0.nickname ?? "", url: ClubCloud14HTTPS.url($0.avatar),
                  memberID: $0.memberId, roleKey: $0.isOwner ? "club.strip.owner" : ($0.role == 1 ? "club.strip.admin" : nil))
        }
        memberTotal = max(directory.club.memberCount, directory.members.count)
    }
}

/// Pushed pages the r8 mounts open. `ClubDetailView` owns the one `navigationDestination` (none inside list rows).
enum ClubDetailR8Route: Hashable, Identifiable {
    case director(topicID: Int, activityID: Int)
    case tool(topicID: Int, activityID: Int, ClubSessionToolChoice, label: String?)
    case myCoop
    /// CLB-G06 / CLB-G19: 编辑俱乐部资料 and 解散俱乐部 open the club workspace (which owns both); 改为转让主理人 opens
    /// 成员治理, where the transfer lives (MP scene-club-edit 危险操作 → governance members).
    case workspace
    case transferOwner
    /// CLB-G01: 邀约承接 → that topic's merchant project page (MP merchantinfo?topicId=&scope=MERCHANT).
    case undertake(topicID: Int)
    /// CLB-r7-A-06: 俱乐部设置 · 客户与项目.
    case customers, enroll, eventOps, roles
    /// CLB-r11-detail-01 (MP detail wxml:863-871 goClubFinance): 经营 · 俱乐部分润 → the settlement page.
    case settlement
    /// CLB-detail-20: 发布主题 from the empty 活动 state.
    case publish
    /// CLB-detail-35: 出示团码 / 出示二维码 → that topic's 选择场次 step (MP showGroupCode js:3072-3088).
    case groupCode(topicID: Int)
    var id: Self { self }
}

/// CLB-G04: 可对接的活动 for the owner; 我的合作 and 查看申请 open the pool applications list.
@MainActor struct ClubCoopPoolMount: View {
    let session: AppSession
    @ObservedObject var model: ClubDetailR8MountModel
    let reloadKey: String
    let clubID: Int
    let open: (ClubDetailR8Route) -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        // Lane G: the club coop pool (可对接的活动 / 我的合作) is a coop entry, hidden in Release.
        if PlayerLaunch.merchantCenterEnabled {
            ClubGapCoopPoolSection(
                state: model.coopPool,
                pendingTopicID: model.coopApplyPendingTopicID,
                onRetry: { Task { await model.loadCoopPool(key: reloadKey, reader: session.cooperationReader, locale: locale, force: true) } },
                onApply: { topicID, _, message in
                    Task { await model.applyCoopPool(topicID: topicID, clubID: clubID, message: message, session: session, key: reloadKey, locale: locale) }
                },
                onOpenApplication: { _ in open(.myCoop) },
                onOpenMyCoop: { open(.myCoop) })
            if let key = model.coopApplyNoticeKey {
                Section { Text(LocalizedStringKey(key)).font(.subheadline).foregroundStyle(.secondary) }
                    .accessibilityIdentifier("club.coopPool.notice")
            } else if let notice = model.coopApplyServerNotice {
                Section { Text(verbatim: notice).font(.subheadline).foregroundStyle(.secondary) }
                    .accessibilityIdentifier("club.coopPool.notice")
            }
        }
    }
}

@MainActor struct ClubDetailR8Destination: View {
    let route: ClubDetailR8Route
    let club: ClubRecord
    let identity: ClubReadIdentity
    let session: AppSession?
    let management: ClubManagementContext?
    private var clubID: Int { club.id }
    var body: some View {
        if let governance = management?.governance {
            switch route {
            case .director(let topicID, let activityID):
                ClubGovernanceReadView(operation: .topicOverview, scope: .init(clubID: clubID, topicID: topicID, activityID: activityID),
                                       identity: identity, access: governance.access, coordinator: governance.coordinator)
                    .environment(\.clubEnrollmentProfile, governance.enrollmentProfile)
                    // CLB-G13: the director block reads the session's PlayDirectorCoordinator for this activity.
                    .environment(\.clubTopicDirectorHost, session?.clubTopicDirectorHost)
            case .tool(let topicID, let activityID, .rosterAndVerify, _):
                ClubOpsEventView(scope: .init(clubID: clubID, topicID: topicID, activityID: activityID), identity: identity,
                                 access: governance.access, coordinator: governance.coordinator)
            case .tool(_, let activityID, .assignLeader, let label):
                ClubGovernanceReadView(operation: .roles, scope: .init(clubID: clubID, activityID: activityID), identity: identity,
                                       access: governance.access, coordinator: governance.coordinator)
                    .environment(\.clubRoleActivityLabel, ClubRoleActivityLabel.entry(label))
            case .tool(_, let activityID, .notifySessionMembers, _):
                ClubGovernanceCommandForm(route: .init(operation: .sendNotification, scope: .init(clubID: clubID, activityID: activityID)),
                                          identity: identity, access: governance.access, coordinator: governance.coordinator)
            case .customers:
                ClubGovernanceReadView(operation: .customers, scope: .init(clubID: clubID), identity: identity,
                                       access: governance.access, coordinator: governance.coordinator)
            case .enroll:
                ClubEnrollmentView(clubID: clubID, focusTopicID: nil, identity: identity, access: governance.access, coordinator: governance.coordinator)
            case .eventOps:
                ClubOpsEventView(scope: .init(clubID: clubID), identity: identity, access: governance.access, coordinator: governance.coordinator)
            case .roles:
                ClubGovernanceReadView(operation: .roles, scope: .init(clubID: clubID), identity: identity,
                                       access: governance.access, coordinator: governance.coordinator)
            case .transferOwner:
                ClubGovernanceReadView(operation: .members, scope: .init(clubID: clubID), identity: identity,
                                       access: governance.access, coordinator: governance.coordinator)
            case .settlement:
                ClubGovernanceReadView(operation: .settlement, scope: .init(clubID: clubID), identity: identity,
                                       access: governance.access, coordinator: governance.coordinator)
            case .groupCode(let topicID):
                ClubGroupCodeSessionStep(clubID: clubID, topicID: topicID, identity: identity,
                                         access: governance.access, coordinator: governance.coordinator)
            case .myCoop, .workspace, .undertake, .publish:
                nonGovernance
            }
        } else {
            nonGovernance
        }
    }
    @ViewBuilder private var nonGovernance: some View {
        switch route {
        case .myCoop:
            if let session {
                CoopFlowReadView(reader: session.cooperationFlowReader, resource: .applications, title: "coopflow.applications")
                    .cyPushedChrome(domain: .merchant)
            }
        case .workspace:
            if let management, let operations = management.operations {
                ClubOperationsWorkspaceView(target: .club(clubID), identity: identity, access: operations.access,
                                            coordinator: operations.coordinator, hostApplication: management.governance)
            }
        case .undertake(let topicID):
            if let session {
                MerchantContentDocumentView(service: session.merchantContentService, query: .project(topicID: topicID), focusedTopicID: topicID)
                    .cyPushedChrome()
            }
        case .publish:
            if let session { SessionClubProjectLaunchView(session: session, club: club) }
        default:
            EmptyView()
        }
    }
}

/// CLB-detail-22 (MP detail wxml:308-345, js:345-356, 1811-1850): 本团贡献榜 · 本周 inline on 概览. The full table folds
/// to the top 3, a 「⋯ 中间 N 人」 row, then the rows around 我 (or the last 3); the sort sits in the section head.
@MainActor final class ClubInlineLeaderboardModel: ObservableObject {
    enum Sort: String, CaseIterable, Identifiable {
        case composite, mileage, duration
        var id: String { rawValue }
        var titleKey: LocalizedStringKey { LocalizedStringKey("club.gov.sort." + rawValue) }
        var emptyKey: LocalizedStringKey { LocalizedStringKey("clubR8.lb.empty." + rawValue) }
    }
    struct Row: Identifiable, Equatable {
        let id: String
        let memberID: Int
        let rank: Int
        let nickname: String
        let avatar: String?
        let isMe: Bool
        let clearCount: Int
        let mileage: Double
        let durationMin: Int
        let score: Double
        let hiddenCount: Int?
    }
    enum Phase: Equatable { case idle, loading, ready([Row]), failed }
    @Published private(set) var phase: Phase = .idle
    @Published var sort: Sort = .composite
    private var key: String?

    func load(key: String, clubID: Int, myMemberID: Int?, access: any ClubGovernanceAccess, force: Bool = false) async {
        let full = key + "|" + sort.rawValue
        guard force || self.key != full else { return }
        self.key = full; phase = .loading
        let current = { [weak self] in self?.key == full && !Task.isCancelled }
        do {
            let snapshot = try await access.read(.leaderboard, scope: .init(clubID: clubID), options: ["sortBy": .string(sort.rawValue)]) {
                guard current() else { throw CancellationError() }
            }
            guard current() else { return }
            phase = .ready(Self.fold(snapshot.value.array ?? snapshot.value["rows"].array ?? [], myMemberID: myMemberID))
        } catch {
            guard current() else { return }
            phase = .failed
        }
    }

    /// MP `foldLeaderboard`: ranks are the list order; more than six rows fold after the top 3.
    static func fold(_ values: [ClubGovernanceValue], myMemberID: Int?) -> [Row] {
        let list: [Row] = values.enumerated().compactMap { index, value in
            guard let member = value["memberId"].int else { return nil }
            func number(_ key: String) -> Double {
                if case .decimal(let v) = value[key] { return v }
                return value[key].int.map(Double.init) ?? Double(value[key].string ?? "") ?? 0
            }
            return Row(id: "m\(member)", memberID: member, rank: index + 1,
                       nickname: value["nickname"].string ?? "", avatar: value["avatar"].string,
                       isMe: myMemberID == member, clearCount: Int(number("clearCount")), mileage: number("mileage"),
                       durationMin: Int(number("durationMin")), score: number("score"), hiddenCount: nil)
        }
        guard list.count > 6 else { return list }
        var tailStart = list.count - 3
        if let mine = list.firstIndex(where: \.isMe), mine >= 3 { tailStart = min(tailStart, max(3, mine - 1)) }
        let hidden = tailStart - 3
        var out = Array(list.prefix(3))
        if hidden > 0 {
            out.append(Row(id: "gap", memberID: 0, rank: 0, nickname: "", avatar: nil, isMe: false, clearCount: 0,
                           mileage: 0, durationMin: 0, score: 0, hiddenCount: hidden))
        }
        return out + list[tailStart...]
    }
}

/// MP detail `goMemberProfile` on a 本团贡献榜 row (`index.wxml` catchtap, `index.js`).
/// A positive member opens 公开资料. The owner and administrators also choose 客户档案.
private struct ClubDetailLeaderboardMemberOpen: Hashable, Identifiable {
    let id: UUID
    let memberID: Int
    let customer: Bool
    let clubID: Int
    let identity: ClubReadIdentity
    let viewerRevision: UInt64
}

@MainActor struct ClubInlineLeaderboardRows: View {
    @ObservedObject var model: ClubInlineLeaderboardModel
    let club: ClubRecord
    let identity: ClubReadIdentity
    let governance: ClubGovernanceContext
    let retry: () -> Void
    @Environment(\.locale) private var locale
    @State private var destination: ClubDetailLeaderboardMemberOpen?
    @State private var choice: ClubDetailLeaderboardMemberOpen?
    @State private var choosing = false
    var body: some View {
        rows
            .navigationDestination(item: $destination) { destinationPage($0) }
            .confirmationDialog(Text("club.detail.leaderboard.member.open", tableName: "ClubPublicRoster"),
                                isPresented: $choosing, titleVisibility: .visible) { choiceActions }
            .onChange(of: choosing) { _, open in if !open { choice = nil } }
            .onChange(of: identity) { _, _ in reset() }
            .onChange(of: governance.viewerRevision) { _, _ in reset() }
            .onChange(of: model.phase) { _, _ in prune() }
    }
    @ViewBuilder private var rows: some View {
        switch model.phase {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).accessibilityLabel(Text("club.loading"))
        case .failed:
            ContentUnavailableView {
                Label("clubR8.lb.failed", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("action.retry", action: retry)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("club.detail.leaderboard.retry")
            }
        case .ready(let rows) where rows.isEmpty:
            ContentUnavailableView {
                Label { Text(model.sort.emptyKey).accessibilityIdentifier("club.detail.leaderboard.empty") } icon: {
                    Image(systemName: "trophy")
                }
            }
        case .ready(let rows):
            ForEach(rows) { row in
                if let hidden = row.hiddenCount {
                    Text(String(format: appLocalized("clubR8.lb.gap %lld", locale: locale), hidden))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    rowView(row)
                }
            }
        }
    }
    @ViewBuilder private func rowView(_ row: ClubInlineLeaderboardModel.Row) -> some View {
        if row.memberID > 0, profileOpenable || offersCustomer {
            Button { open(row.memberID) } label: { rowBody(row).foregroundStyle(Color.primary) }
                .accessibilityHint(Text("club.detail.leaderboard.member.hint", tableName: "ClubPublicRoster"))
                .accessibilityIdentifier("club.detail.leaderboard.row.\(row.memberID)")
        } else {
            rowBody(row).accessibilityIdentifier("club.detail.leaderboard.row.\(row.memberID)")
        }
    }
    private func rowBody(_ row: ClubInlineLeaderboardModel.Row) -> some View {
        HStack(spacing: 12) {
            Text(row.rank, format: .number).font(.headline).monospacedDigit()
                .foregroundStyle(row.rank <= 3 ? Color.accentColor : Color.secondary)
                .frame(minWidth: 24)
            ClubMPAvatar(url: row.avatar.flatMap(URL.init(string:)), name: row.nickname, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(verbatim: row.isMe ? appLocalized("clubR8.lb.you", locale: locale)
                         : (row.nickname.isEmpty ? appLocalized("club.community.user", locale: locale) : row.nickname))
                        .lineLimit(1)
                    if row.isMe { Text("clubR8.lb.me").font(.caption).foregroundStyle(.tint) }
                }
                Text(verbatim: String(format: appLocalized("clubR8.lb.meta %lld %@ %@", locale: locale),
                                      row.clearCount, mileageText(row), durationText(row)))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(verbatim: primaryText(row)).monospacedDigit()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
    private var offersCustomer: Bool { (club.isOwner || club.viewerIsAdmin) && customerOpenable }
    private var profileOpenable: Bool {
        guard identity.isSignedIn, let profile = governance.enrollmentProfile else { return false }
        return profile.reader.isConfigured && profile.reader.identity.accountID == identity.accountID
            && profile.reader.identity.epoch == identity.epoch
    }
    private var customerOpenable: Bool {
        identity.isSignedIn && governance.access.isConfigured && governance.access.identity == identity
    }
    private func onBoard(_ memberID: Int) -> Bool {
        guard case .ready(let rows) = model.phase else { return false }
        return rows.contains { $0.memberID == memberID && $0.hiddenCount == nil }
    }
    /// A refresh in flight keeps the member already opened. The next ready board drops them if they are gone.
    private func stillListed(_ memberID: Int) -> Bool {
        if onBoard(memberID) { return true }
        guard case .loading = model.phase else { return false }
        return destination?.memberID == memberID || choice?.memberID == memberID
    }
    private func current(_ target: ClubDetailLeaderboardMemberOpen) -> Bool {
        guard target.identity == identity, target.viewerRevision == governance.viewerRevision, target.clubID == club.id,
              target.memberID > 0, stillListed(target.memberID) else { return false }
        if target.customer { return offersCustomer }
        return profileOpenable
    }
    private func open(_ memberID: Int) {
        guard destination == nil, !choosing, memberID > 0, onBoard(memberID) else { return }
        guard profileOpenable || offersCustomer else { return }
        let pick = ClubDetailLeaderboardMemberOpen(id: UUID(), memberID: memberID, customer: false, clubID: club.id,
                                                    identity: identity, viewerRevision: governance.viewerRevision)
        if profileOpenable && offersCustomer {
            choice = pick
            choosing = true
        } else if profileOpenable {
            destination = pick
        } else {
            destination = ClubDetailLeaderboardMemberOpen(id: UUID(), memberID: memberID, customer: true, clubID: club.id,
                                                           identity: identity, viewerRevision: governance.viewerRevision)
        }
    }
    /// The 公开主页 / 客户详情 choice is a system confirmation dialog (action sheet).
    @ViewBuilder private var choiceActions: some View {
        // Read `choice` inside the actions: the buttons reset the @State `choice`, and shadowing it crashes swift-frontend.
        if let pending = choice, current(pending) {
            Button { pickChoice(customer: false) } label: {
                Text("club.detail.leaderboard.member.public", tableName: "ClubPublicRoster")
            }
            .accessibilityIdentifier("club.detail.leaderboard.choice.public")
            Button { pickChoice(customer: true) } label: {
                Text("club.detail.leaderboard.member.customer", tableName: "ClubPublicRoster")
            }
            .accessibilityIdentifier("club.detail.leaderboard.choice.customer")
        }
        Button("action.cancel", role: .cancel) { choosing = false; choice = nil }
    }
    private func pickChoice(customer: Bool) {
        guard let picked = choice, current(picked) else { choosing = false; choice = nil; return }
        let next = ClubDetailLeaderboardMemberOpen(id: UUID(), memberID: picked.memberID, customer: customer,
                                                    clubID: club.id, identity: identity, viewerRevision: governance.viewerRevision)
        guard current(next) else { choosing = false; choice = nil; return }
        destination = next
        choosing = false
        choice = nil
    }
    @ViewBuilder private func destinationPage(_ target: ClubDetailLeaderboardMemberOpen) -> some View {
        if current(target), target.customer {
            ClubGovernanceReadView(operation: .customer, scope: .init(clubID: target.clubID, memberID: target.memberID),
                                   identity: target.identity, access: governance.access, coordinator: governance.coordinator)
                .environment(\.clubCustomerTopics, governance.customerTopics)
                .environment(\.clubEnrollmentProfile, governance.enrollmentProfile)
                .id(target.id)
        } else if current(target), let profile = governance.enrollmentProfile {
            SocialPublicProfileView(memberID: target.memberID, reader: profile.reader, squareReader: profile.squareReader,
                                    actions: profile.actions, isCurrent: { current(target) })
                .id(target.id)
        } else {
            Color.clear.onAppear { if destination?.id == target.id { destination = nil } }
        }
    }
    private func reset() { destination = nil; choice = nil; choosing = false }
    private func prune() {
        if let destination, !current(destination) { self.destination = nil }
        if let choice, !current(choice) { self.choice = nil; choosing = false }
    }
    private func mileageText(_ row: ClubInlineLeaderboardModel.Row) -> String {
        row.mileage.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " km"
    }
    private func durationText(_ row: ClubInlineLeaderboardModel.Row) -> String {
        guard row.durationMin > 0 else { return "—" }
        let hours = row.durationMin / 60, minutes = row.durationMin % 60
        return hours > 0 ? String(format: appLocalized("clubR8.lb.hoursMinutes %lld %lld", locale: locale), hours, minutes)
            : String(format: appLocalized("clubR8.lb.minutes %lld", locale: locale), minutes)
    }
    private func primaryText(_ row: ClubInlineLeaderboardModel.Row) -> String {
        switch model.sort {
        case .mileage: return mileageText(row)
        case .duration: return durationText(row)
        case .composite:
            return String(format: appLocalized("clubR8.lb.points %@", locale: locale),
                          row.score.formatted(.number.precision(.fractionLength(1)).locale(locale)))
        }
    }
}

private enum ClubCloud14HTTPS {
    static func url(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}

/// CLB-r9-detail-01 (MP detail wxml:266-277, `goMemberProfile` js:2529-2534): a tapped strip avatar opens 公开资料;
/// the owner and administrators first choose 公开资料 / 客户档案, as on the 本团贡献榜 rows above.
/// `tapped` is set by the strip and cleared here once the tap is routed.
@MainActor struct ClubDetailStripMemberOpen: ViewModifier {
    @Binding var tapped: Int?
    let club: ClubRecord
    let identity: ClubReadIdentity
    let governance: ClubGovernanceContext?
    @State private var destination: ClubDetailLeaderboardMemberOpen?
    @State private var choice: ClubDetailLeaderboardMemberOpen?
    @State private var choosing = false

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $destination) { destinationPage($0) }
            .confirmationDialog(Text("club.detail.leaderboard.member.open", tableName: "ClubPublicRoster"),
                                isPresented: $choosing, titleVisibility: .visible) { choiceActions }
            .onChange(of: tapped) { _, memberID in route(memberID) }
            .onChange(of: choosing) { _, open in if !open { choice = nil } }
            .onChange(of: identity) { _, _ in destination = nil; choice = nil; choosing = false }
    }
    private var revision: UInt64 { governance?.viewerRevision ?? 0 }
    private var profileOpenable: Bool {
        guard identity.isSignedIn, let profile = governance?.enrollmentProfile else { return false }
        return profile.reader.isConfigured && profile.reader.identity.accountID == identity.accountID
    }
    private var offersCustomer: Bool {
        guard club.isOwner || club.viewerIsAdmin, identity.isSignedIn, let governance else { return false }
        return governance.access.isConfigured && governance.access.identity == identity
    }
    private func target(_ memberID: Int, customer: Bool) -> ClubDetailLeaderboardMemberOpen {
        ClubDetailLeaderboardMemberOpen(id: UUID(), memberID: memberID, customer: customer, clubID: club.id,
                                        identity: identity, viewerRevision: revision)
    }
    private func current(_ target: ClubDetailLeaderboardMemberOpen) -> Bool {
        guard target.identity == identity, target.viewerRevision == revision, target.clubID == club.id, target.memberID > 0 else { return false }
        return target.customer ? offersCustomer : profileOpenable
    }
    private func route(_ memberID: Int?) {
        guard let memberID else { return }
        tapped = nil
        guard memberID > 0, destination == nil, !choosing else { return }
        if profileOpenable && offersCustomer {
            choice = target(memberID, customer: false); choosing = true
        } else if profileOpenable {
            destination = target(memberID, customer: false)
        } else if offersCustomer {
            destination = target(memberID, customer: true)
        }
    }
    @ViewBuilder private var choiceActions: some View {
        // Read `choice` inside the actions; shadowing the @State with if-let crashes swift-frontend.
        if let pending = choice, current(pending) {
            Button { pick(customer: false) } label: {
                Text("club.detail.leaderboard.member.public", tableName: "ClubPublicRoster")
            }
            .accessibilityIdentifier("club.detail.memberStrip.choice.public")
            Button { pick(customer: true) } label: {
                Text("club.detail.leaderboard.member.customer", tableName: "ClubPublicRoster")
            }
            .accessibilityIdentifier("club.detail.memberStrip.choice.customer")
        }
        Button("action.cancel", role: .cancel) { choosing = false; choice = nil }
    }
    private func pick(customer: Bool) {
        guard let picked = choice else { choosing = false; return }
        let next = target(picked.memberID, customer: customer)
        choosing = false; choice = nil
        if current(next) { destination = next }
    }
    @ViewBuilder private func destinationPage(_ target: ClubDetailLeaderboardMemberOpen) -> some View {
        if current(target), target.customer, let governance {
            ClubGovernanceReadView(operation: .customer, scope: .init(clubID: target.clubID, memberID: target.memberID),
                                   identity: target.identity, access: governance.access, coordinator: governance.coordinator)
                .environment(\.clubCustomerTopics, governance.customerTopics)
                .environment(\.clubEnrollmentProfile, governance.enrollmentProfile)
                .id(target.id)
        } else if current(target), let profile = governance?.enrollmentProfile {
            SocialPublicProfileView(memberID: target.memberID, reader: profile.reader, squareReader: profile.squareReader,
                                    actions: profile.actions, isCurrent: { current(target) })
                .id(target.id)
        } else {
            Color.clear.onAppear { if destination?.id == target.id { destination = nil } }
        }
    }
}
