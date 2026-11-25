import SwiftUI

/// fix-r8-club: reads behind the compiled `ClubGap*` views mounted on the club page.
/// - CLB-detail-09 / CLB-r7-A-04: 管理中的项目 with 活动导演台 and 场次工具 (MP detail wxml:452-475, js:2988-3031, 1110-1220).
/// - CLB-G04: 可对接的活动 + 我的合作 + 申请带队 on 管理 (MP js:3780-3847).
/// - CLB-G08: the overview member avatar strip (MP wxml:265-280).
/// Each read is keyed; a newer key (club, account, tab) drops the older result.
@MainActor final class ClubDetailR8MountModel: ObservableObject {
    @Published private(set) var projects: [ClubManagedProjectDirectorItem] = []
    @Published private(set) var coopPool: ClubCoopPoolLoadState = .idle
    @Published private(set) var memberAvatars: [ClubGapMemberAvatarStrip.AvatarItem] = []
    @Published private(set) var memberTotal = 0
    /// CLB-r7-A-06: 「N 个团」 beside 报名名册 (every club topic, not the capped project page).
    @Published private(set) var topicTotal: Int?
    /// CLB-r7-A-06: 「N 人」 beside 查看客户, or 暂时读不到 when the count read fails (MP js:3591-3601).
    @Published private(set) var customerCountText: String?
    /// CLB-G04: the topic whose 申请带队 is in flight, and the MP toast text after it settles.
    @Published private(set) var coopApplyPendingTopicID: Int?
    @Published var coopApplyNotice: LocalizedStringKey?
    @Published var coopApplyServerNotice: String?
    private var settingsCountsFor: Int?
    private var projectsKey: String?
    private var poolKey: String?
    private var avatarsKey: String?
    /// MP lists every managed topic; the app reads each topic's sessions up front, so it stops at a page.
    static let maxProjects = 12

    /// CLB-r7-A-06 (MP loadSettingsCounts js:3579-3601): read once per club when 俱乐部设置 opens; a failure clears the
    /// guard so the next opening asks again. Owner / admin only, as the MP sends it.
    func loadSettingsCounts(clubID: Int, canSeeCustomers: Bool, access: any ClubGovernanceAccess) async {
        guard canSeeCustomers, settingsCountsFor != clubID else { return }
        settingsCountsFor = clubID
        if topicTotal == nil,
           let topics = try? await access.read(.topics, scope: .init(clubID: clubID), options: [:]),
           settingsCountsFor == clubID, !Task.isCancelled {
            topicTotal = topics.value.array?.count
        }
        do {
            let count = try await access.read(.customerCount, scope: .init(clubID: clubID), options: [:])
            guard settingsCountsFor == clubID, !Task.isCancelled else { return }
            if let total = count.value["total"].int, total > 0 { customerCountText = "\(total) 人" }
        } catch {
            guard settingsCountsFor == clubID, !Task.isCancelled else { return }
            settingsCountsFor = nil
            customerCountText = "暂时读不到"
        }
    }

    func loadProjects(key: String, clubID: Int, showsDirector: Bool, locale: Locale, access: any ClubGovernanceAccess) async {
        guard projectsKey != key else { return }
        projectsKey = key; projects = []
        let current = { [weak self] in self?.projectsKey == key && !Task.isCancelled }
        do {
            let topics = try await access.read(.topics, scope: .init(clubID: clubID), options: [:]) {
                guard current() else { throw CancellationError() }
            }
            guard current() else { return }
            topicTotal = topics.value.array?.count
            var items: [ClubManagedProjectDirectorItem] = []
            for row in (topics.value.array ?? []).prefix(Self.maxProjects) {
                guard let topicID = row["id"].int, topicID > 0 else { continue }
                let overview = try? await access.read(.topicOverview, scope: .init(clubID: clubID, topicID: topicID), options: [:]) {
                    guard current() else { throw CancellationError() }
                }
                guard current() else { return }
                let name = row["name"].string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let gameModule = row["gameModuleEnabled"].bool == true || row["gameModuleEnabled"].int == 1
                items.append(.init(id: topicID,
                                   title: name.isEmpty ? appLocalized("clubR8.project.untitled", locale: locale) : name,
                                   gameModuleEnabled: showsDirector && gameModule,
                                   sessions: Self.sessions(overview?.value["activityList"], locale: locale)))
            }
            projects = items
        } catch {
            // A failed read leaves the section out (MP shows 项目列表加载失败 above it); the next appearance retries.
            guard current() else { return }
            projectsKey = nil
        }
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
                     // CLB-G04: MP decoratePool — open / declined / withdrawn rows offer 申请带队.
                     canApply: ClubCoopPoolApplyClient.canApply(state: row.state), applyID: row.applyId)
    }

    /// MP `applyCoopPool` (`pages/club/detail/index.js:3806-3843`): one application at a time; success and an
    /// unknown result both re-read the pool so the card flips to 已申请.
    func applyCoopPool(topicID: Int, clubID: Int, message: String, session: AppSession, key: String, locale: Locale) async {
        guard coopApplyPendingTopicID == nil, let submit = session.clubCoopPoolApply else { return }
        coopApplyPendingTopicID = topicID; coopApplyNotice = nil; coopApplyServerNotice = nil
        defer { coopApplyPendingTopicID = nil }
        do {
            try await submit(topicID, clubID, message)
            coopApplyNotice = "club.coopPool.applied"
            await loadCoopPool(key: key, reader: session.cooperationReader, locale: locale, force: true)
        } catch let refusal as MPGapServerRefusal {
            if let text = refusal.message, !text.isEmpty { coopApplyServerNotice = text } else { coopApplyNotice = "club.coopPool.applyFailed" }
        } catch {
            coopApplyNotice = "club.coopPool.applyUnknown"
            await loadCoopPool(key: key, reader: session.cooperationReader, locale: locale, force: true)
        }
    }

    func loadMemberAvatars<Reader: ClubReading>(key: String, clubID: Int, reader: Reader) async {
        guard avatarsKey != key else { return }
        avatarsKey = key; memberAvatars = []; memberTotal = 0
        guard let directory = try? await reader.clubMembers(id: clubID, isCurrent: { [weak self] in self?.avatarsKey == key }),
              avatarsKey == key, !Task.isCancelled else { return }
        memberAvatars = directory.members.prefix(4).map {
            .init(id: String($0.memberId), name: $0.nickname ?? "", url: ClubCloud14HTTPS.url($0.avatar))
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
    /// CLB-detail-20: 发布主题 from the empty 活动 state.
    case publish
    var id: Self { self }
}

/// CLB-detail-09: the manage tab's project list; 活动导演台 opens the topic page in director mode (`activityId`),
/// 场次工具 opens 现场名册与核销 / 分配领队与核销员 / 通知本场成员 for that session.
@MainActor struct ClubManagedProjectsMount: View {
    @ObservedObject var model: ClubDetailR8MountModel
    let open: (ClubDetailR8Route) -> Void
    var body: some View {
        ClubGapManagedProjectsDirectorSection(
            projects: model.projects,
            onOpenDirector: { open(.director(topicID: $0, activityID: $1)) },
            onSelectSessionTool: { topicID, activityID, tool in
                open(.tool(topicID: topicID, activityID: activityID, tool, label: sessionTitle(activityID)))
            })
    }
    private func sessionTitle(_ activityID: Int) -> String? {
        model.projects.flatMap(\.sessions).first { $0.id == activityID }.map { session in
            [session.title, session.timeLabel].compactMap { $0 }.joined(separator: " · ")
        }
    }
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
        ClubGapCoopPoolSection(
            state: model.coopPool,
            pendingTopicID: model.coopApplyPendingTopicID,
            onRetry: { Task { await model.loadCoopPool(key: reloadKey, reader: session.cooperationReader, locale: locale, force: true) } },
            onApply: { topicID, _, message in
                Task { await model.applyCoopPool(topicID: topicID, clubID: clubID, message: message, session: session, key: reloadKey, locale: locale) }
            },
            onOpenApplication: { _ in open(.myCoop) },
            onOpenMyCoop: { open(.myCoop) })
        if let notice = model.coopApplyNotice {
            Section { Text(notice).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                .accessibilityIdentifier("club.coopPool.notice")
        } else if let notice = model.coopApplyServerNotice {
            Section { Text(verbatim: notice).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                .accessibilityIdentifier("club.coopPool.notice")
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

@MainActor struct ClubInlineLeaderboardRows: View {
    @ObservedObject var model: ClubInlineLeaderboardModel
    let retry: () -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        switch model.phase {
        case .idle, .loading:
            CYSkeleton(variant: .row).accessibilityLabel(Text("club.loading"))
        case .failed:
            CYEmptyState(systemImage: "exclamationmark.triangle", "clubR8.lb.failed", actionTitle: "action.retry",
                         actionIdentifier: "club.detail.leaderboard.retry", action: retry)
        case .ready(let rows) where rows.isEmpty:
            CYEmptyState(systemImage: "trophy", model.sort.emptyKey, messageIdentifier: "club.detail.leaderboard.empty")
        case .ready(let rows):
            ForEach(rows) { row in
                if let hidden = row.hiddenCount {
                    Text(String(format: appLocalized("clubR8.lb.gap %lld", locale: locale), hidden))
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    rowView(row)
                }
            }
        }
    }
    private func rowView(_ row: ClubInlineLeaderboardModel.Row) -> some View {
        HStack(spacing: CYSpacing.md) {
            Text(row.rank, format: .number).cyText(.cardTitle).monospacedDigit()
                .foregroundStyle(row.rank <= 3 ? CYColor.brand : CYColor.textSecondary)
                .frame(minWidth: 24)
            ClubMPAvatar(url: row.avatar.flatMap(URL.init(string:)), name: row.nickname, size: .sm)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                HStack(spacing: CYSpacing.xs) {
                    Text(verbatim: row.isMe ? appLocalized("clubR8.lb.you", locale: locale)
                         : (row.nickname.isEmpty ? appLocalized("club.community.user", locale: locale) : row.nickname))
                        .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).lineLimit(1)
                    if row.isMe { CYStatusChip("clubR8.lb.me", tone: .info) }
                }
                Text(verbatim: String(format: appLocalized("clubR8.lb.meta %lld %@ %@", locale: locale),
                                      row.clearCount, mileageText(row), durationText(row)))
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            Spacer(minLength: CYSpacing.sm)
            Text(verbatim: primaryText(row)).cyText(.bodyMedium).monospacedDigit().foregroundStyle(CYColor.textPrimary)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("club.detail.leaderboard.row.\(row.memberID)")
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
