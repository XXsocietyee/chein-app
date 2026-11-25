import SwiftUI

/// fix-r8-club: reads behind the compiled `ClubGap*` views mounted on the club page.
/// - CLB-detail-09 / CLB-r7-A-04: 管理中的项目 with 活动导演台 and 场次工具 (MP detail wxml:452-475, js:2988-3031, 1110-1220).
/// - CLB-G04: 可对接的活动 + 我的合作 on 管理 (MP js:3780-3847). Read only: the app has no submitting pool-apply write yet.
/// - CLB-G08: the overview member avatar strip (MP wxml:265-280).
/// Each read is keyed; a newer key (club, account, tab) drops the older result.
@MainActor final class ClubDetailR8MountModel: ObservableObject {
    @Published private(set) var projects: [ClubManagedProjectDirectorItem] = []
    @Published private(set) var coopPool: ClubCoopPoolLoadState = .idle
    @Published private(set) var memberAvatars: [ClubGapMemberAvatarStrip.AvatarItem] = []
    @Published private(set) var memberTotal = 0
    private var projectsKey: String?
    private var poolKey: String?
    private var avatarsKey: String?
    /// MP lists every managed topic; the app reads each topic's sessions up front, so it stops at a page.
    static let maxProjects = 12

    func loadProjects(key: String, clubID: Int, showsDirector: Bool, locale: Locale, access: any ClubGovernanceAccess) async {
        guard projectsKey != key else { return }
        projectsKey = key; projects = []
        let current = { [weak self] in self?.projectsKey == key && !Task.isCancelled }
        do {
            let topics = try await access.read(.topics, scope: .init(clubID: clubID), options: [:]) {
                guard current() else { throw CancellationError() }
            }
            guard current() else { return }
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
                     // The app's pool application ends at a request preview; 申请带队 stays hidden until it submits.
                     canApply: false, applyID: row.applyId)
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
    let open: (ClubDetailR8Route) -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        ClubGapCoopPoolSection(
            state: model.coopPool,
            onRetry: { Task { await model.loadCoopPool(key: reloadKey, reader: session.cooperationReader, locale: locale, force: true) } },
            onApply: { _, _, _ in },
            onOpenApplication: { _ in open(.myCoop) },
            onOpenMyCoop: { open(.myCoop) })
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
