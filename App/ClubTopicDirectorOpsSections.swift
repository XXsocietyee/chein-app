import SwiftUI

/// CLB-G13a (MP `pages/club/topic-detail/index.wxml:198-237`, `director.js:18-26, 862-865`,
/// `pages/club/utils/generic-director-ops.js:4-35`): 通用玩法现场运营 inside the embedded director block.
/// It reads `GET /api/game/session/shared/control` (the server answers the session organiser only) and lists the
/// generic run actions with their Chinese status line. Each action opens the full director page, which owns the
/// reviewed command path.
@MainActor struct ClubTopicGenericOpsSection: View {
    let activityID: Int
    /// The director projection revision; a different control revision means the run moved on.
    let revision: Int
    let onOpenAction: (String) -> Void
    @Environment(\.playerGapService) private var service
    @State private var control: PlayWireValue?

    /// MP `genericOpsActions`: only labelled actions, never `ARRIVAL_ATTEST`, deduplicated; `OFFLINE_ANCHOR` first when offered.
    static let actionOrder = ["ACT_UNLOCK", "ARRIVAL_CONFIRM", "ARRIVAL_REVOKE", "RUN_PAUSE", "RUN_RESUME", "RUN_INTERRUPT",
                              "RUN_CANCEL", "MANUAL_BEGIN", "STAFF_MANUAL_SIGN", "MANUAL_IMPORT", "MANUAL_REVIEW",
                              "AUTHORITY_RESUME", "QUEST_GUIDE", "LOCATION_REBIND", "STAFF_TEAM_EXIT"]
    static func actions(_ control: PlayWireValue) -> [String] {
        guard let epoch = control["run"]["authorityEpoch"].integer, epoch >= 1, control["revision"].integer != nil,
              let offered = control["availableActions"].array else { return [] }
        var seen = Set<String>()
        var out = offered.compactMap(\.text).filter { actionOrder.contains($0) && seen.insert($0).inserted }
        if control["offlineAnchorAvailable"].bool == true { out.insert("OFFLINE_ANCHOR", at: 0) }
        return out
    }

    private var offeredActions: [String] { control.map(Self.actions) ?? [] }

    var body: some View {
        Group {
            if let control, !offeredActions.isEmpty {
                Section {
                    statusLine(control["run"])
                    if let teams = control["teams"].array, !teams.isEmpty {
                        teamsLine(teams)
                    }
                    ForEach(offeredActions, id: \.self) { action in
                        Button { onOpenAction(action) } label: {
                            HStack {
                                Text(LocalizedStringKey("club.topic.genericOps.action." + action)).cyText(.body)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                            }
                        }
                        .accessibilityIdentifier("club.topic.genericOps.\(action)")
                    }
                } header: {
                    Text("club.topic.genericOps.title").cyText(.sectionTitle)
                }
            }
        }
        .task(id: "\(activityID):\(revision)") {
            guard let service, case let .ready(data) = await service.sharedControl(activityID: activityID) else { control = nil; return }
            control = data
        }
    }

    /// MP `genericOpsStatusText`: Chinese labels only, never the backend code.
    private func statusLine(_ run: PlayWireValue) -> some View {
        let status = run["operationStatus"].text.flatMap { ["RUNNING", "PAUSED", "INTERRUPTED", "CANCELLED"].contains($0) ? $0 : nil } ?? "unknown"
        let mode = run["authorityMode"].text.flatMap { ["ONLINE", "MANUAL"].contains($0) ? $0 : nil } ?? "unknown"
        return (Text(LocalizedStringKey("club.topic.genericOps.status." + status)) + Text(verbatim: " · ")
            + Text(LocalizedStringKey("club.topic.genericOps.authority." + mode)))
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
    }

    /// MP: `'队伍 ' + teamId + (exited ? '（已退出）' : '')` joined with ` · `.
    private func teamsLine(_ teams: [PlayWireValue]) -> some View {
        let parts: [Text] = teams.compactMap { team in
            guard let id = team["teamId"].tolerantInteger else { return nil }
            let base = Text("club.topic.genericOps.team \(id)")
            return team["exited"].bool == true ? base + Text("club.topic.genericOps.teamExited") : base
        }
        return parts.enumerated().reduce(Text(verbatim: "")) { partial, item in
            item.offset == 0 ? item.element : partial + Text(verbatim: " · ") + item.element
        }
        .cyText(.meta)
        .foregroundStyle(CYColor.textSecondary)
    }
}

/// CLB-G13a (MP `pages/club/topic-detail/index.wxml:238-243`, `plan-fallback.js:1-60`): 默认结局收尾.
/// Status from `shared/control` (`PlayPlanFallbackStatus.present`), a 1–500 character reason, the
/// 确认默认结局收尾 confirm, then `PLAN_FALLBACK` on `/api/game/session/command`.
@MainActor struct ClubTopicPlanFallbackSection: View {
    let activityID: Int
    let revision: Int
    let onApplied: () -> Void
    @Environment(\.popupCloseActions) private var actions
    @State private var status: PlayPlanFallbackStatus?
    @State private var editing = false
    @State private var draft = ""
    @State private var draftError: LocalizedStringKey?
    @State private var confirming = false
    @State private var busy = false
    @State private var result: PlayPlanFallbackResult?
    @State private var failure: LocalizedStringKey?

    var body: some View {
        Group {
            if let status, status.known {
                Section {
                    if status.available {
                        Text("club.topic.planFallback.available").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        Button("club.topic.planFallback.fill") { draftError = nil; editing = true }
                            .disabled(busy)
                            .accessibilityIdentifier("club.topic.planFallback.fill")
                    } else if !status.reason.isEmpty {
                        Text(verbatim: status.reason).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    if let failure { Text(failure).cyText(.meta).foregroundStyle(CYColor.dangerText) }
                } header: {
                    Text("club.topic.planFallback.title").cyText(.sectionTitle)
                }
            }
            if let result {
                Section {
                    Text(verbatim: result.title).cyText(.body)
                    Text("club.topic.planFallback.reason \(result.reason)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
            }
        }
        .task(id: "\(activityID):\(revision)") { await reload() }
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    Section {
                        TextField("club.topic.planFallback.placeholder", text: $draft, axis: .vertical)
                            .lineLimit(3...8)
                            .accessibilityIdentifier("club.topic.planFallback.reasonField")
                        Text(verbatim: "\(draft.count)/500").cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                    } footer: {
                        if let draftError { Text(draftError).foregroundStyle(CYColor.dangerText) }
                    }
                }
                .navigationTitle(Text("club.topic.planFallback.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { editing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("club.topic.planFallback.next") {
                            guard (try? PlayPlanFallbackStatus.validatedReason(draft)) != nil else {
                                draftError = "club.topic.planFallback.reasonRequired"; return
                            }
                            editing = false
                            confirming = true
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert(Text("club.topic.planFallback.confirmTitle"), isPresented: $confirming) {
            Button("common.cancel", role: .cancel) {}
            Button("club.topic.planFallback.confirm", role: .destructive) { Task { await submit() } }
        } message: {
            Text("club.topic.planFallback.confirmBody \(draft.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    private func reload() async {
        guard let load = actions.loadPlanFallback else { status = nil; return }
        status = await load(activityID, revision)
    }

    /// MP `confirmPlanFallback`: re-check availability and the revision before sending.
    private func submit() async {
        guard let submit = actions.submitPlanFallback, !busy else { return }
        guard status?.available == true, status?.controlRevision == revision else {
            failure = "club.topic.planFallback.changed"; return
        }
        busy = true; failure = nil
        defer { busy = false }
        switch await submit(activityID, revision, draft) {
        case let .success(applied):
            result = applied
            draft = ""
            onApplied()
        case .failure:
            failure = "club.topic.planFallback.failed"
            await reload()
        }
    }
}
