import SwiftUI

/// CLB-group-code-05 (fix-r3-club-b round 4; Gemini's row, taken over while Gemini is out of quota).
///
/// MP `pages/club/group-code/index?topicId=` without an `activityId` (index.js:149-199) reads the topic's sessions
/// (`activityList`), drops self-host shells and invalid ids (`listGroupCodeActivities`), then:
/// - no sessions at all → 选择场次 with 暂无可带队的场次 (MP empty art);
/// - sessions but none that can issue → 暂无可出示团码的场次 + 重试;
/// - exactly one → issue at once (the issue form, no picker);
/// - several → 选择场次 (Gemini's parked `ClubGapGroupCodeSessionPickerView`) → issue for the picked one.
/// The picked label 「名称 · 开始时间」 rides in `clubRoleActivityLabel` for the code card; it never enters command
/// fields. Issuing still goes through `ClubGovernanceCommandForm`, so check-in permission and the provider gate apply.
struct ClubGroupCodeSessionStep: View {
    let clubID: Int?
    let topicID: Int
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let coordinator: ClubGovernanceCoordinator

    private enum Phase: Equatable {
        case loading
        case failed(String)
        case sessions([ClubManagedDirectorSession])
    }
    @Environment(\.locale) private var locale
    @State private var phase: Phase = .loading
    @State private var pickedID: Int?
    @State private var attempt = 0
    /// CLB-group-code-05: 进入俱乐部管理 (MP `goManage` → detail?owner=1&tab=manage, group-code js:225-230).
    @State private var opensManage = false

    var body: some View {
        content
            .task(id: attempt) { await load() }
            .navigationDestination(isPresented: $opensManage) { ClubGroupCodeMissingLinkView.manageDestination }
            .navigationDestination(item: $pickedID) { id in
                if case .sessions(let sessions) = phase, let session = sessions.first(where: { $0.id == id }) {
                    issueForm(session)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView { Text("clubR3b.groupCode.sessionsLoading") }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let title):
            // MP scene-qr-group-code wxml:9 cy-error 团核销码无法打开 · sub errorText · 重试 (re-reads the sessions).
            ContentUnavailableView {
                Label("clubR3b.groupCode.openFailed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(LocalizedStringKey(title))
            } actions: {
                Button("clubR3b.groupCode.retry") { attempt += 1 }
                    .buttonStyle(.bordered)
            }
                .accessibilityIdentifier("club.groupCode.sessions.failed")
        case .sessions(let sessions) where sessions.count == 1:
            issueForm(sessions[0])
        case .sessions(let sessions) where sessions.isEmpty:
            // MP `<cy-empty fill kind="empty" title="暂无可带队的场次" />` under the 选择场次 title.
            ClubMPEmptyState(title: Text("gap.club.groupCode.empty"), messageIdentifier: "club.groupCode.sessions.empty")
                .cyPageTitle(verbatim: ClubRound4Copy.groupCodeSelectTitle)
        case .sessions(let sessions):
            ClubGapGroupCodeSessionPickerView(state: .selecting(sessions),
                                              onSelectSession: { pickedID = $0.id },
                                              onOpenManage: { opensManage = true },
                                              sessionDestination: { AnyView(issueForm($0)) })
        }
    }

    private func issueForm(_ session: ClubManagedDirectorSession) -> some View {
        ClubGovernanceCommandForm(route: .init(operation: .issueGroupCode,
                                               scope: .init(clubID: clubID, topicID: topicID, activityID: session.id)),
                                  identity: identity, access: access, coordinator: coordinator)
            .environment(\.clubRoleActivityLabel, ClubRoleActivityLabel.entry(session.title))
    }

    private func load() async {
        phase = .loading
        do {
            let value = try await access.read(.topicOverview, scope: .init(clubID: clubID, topicID: topicID), options: [:]).value
            guard !Task.isCancelled else { return }
            guard let rows = value["activityList"].array else {
                phase = .failed(appLocalized("clubR3b.groupCode.sessionsFailed", locale: locale)); return
            }
            if rows.isEmpty { phase = .sessions([]); return }
            // MP listGroupCodeActivities: self-host shells are not led sessions; only positive ids can issue.
            let sessions: [ClubManagedDirectorSession] = rows.compactMap { row in
                guard row["selfHostShell"] != .bool(true), let id = row["id"].int, id > 0 else { return nil }
                return ClubManagedDirectorSession(id: id, title: ClubGroupCodePort.sessionLabel(
                    id: id, name: row["name"].string, startDate: row["startDate"].string, startTime: row["startTime"].string))
            }
            phase = sessions.isEmpty ? .failed(appLocalized("clubR3b.groupCode.noIssuable", locale: locale)) : .sessions(sessions)
        } catch {
            guard !Task.isCancelled else { return }
            if ClubOpsNetworkFailureClassifier.classify(error) == .network {
                phase = .failed(appLocalized("clubR3b.groupCode.network", locale: locale))
            } else if let message = (error as? ClubGovernanceFailure)?.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                phase = .failed(message)
            } else {
                phase = .failed(appLocalized("clubR3b.groupCode.sessionsFailed", locale: locale))
            }
        }
    }
}

/// CLB-group-code-05 (MP group-code/index.wxml:17-24, js:219-230): a link with neither `activityId` nor `topicId` is the
/// MP `invalid` state: 团核销码, 缺少路线或场次信息 and 进入俱乐部管理 (no retry, it would fail again).
struct ClubGroupCodeMissingLinkView: View {
    /// MP `goManage`: the viewer's own club on 管理 (`detail?owner=1&tab=manage`).
    static var manageDestination: some View {
        MPReviewedPageScreen(page: "pages/club/detail/index", query: ["owner": "1", "tab": "manage"])
    }

    var body: some View {
        ContentUnavailableView {
            Label("gap.club.groupCode.invalid", systemImage: "exclamationmark.triangle")
        } actions: {
            NavigationLink {
                Self.manageDestination
            } label: {
                Text("gap.club.groupCode.enterManage")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("club.groupCode.enterManage")
        }
        .accessibilityIdentifier("club.groupCode.invalid")
        .navigationTitle(Text("club.groupCode.pageTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
