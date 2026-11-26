import SwiftUI

/// CLB-G13a: 通用玩法现场运营 inside the topic director block.
/// Reads shared-run control and opens the director page for each offered action.
@MainActor struct ClubTopicGenericOpsSection: View {
    let activityID: Int
    let revision: Int
    let onOpenAction: (String) -> Void
    /// CLB-G13a (MP topic-detail wxml:204-236): rows are disabled while a director write is in flight or unknown.
    var writeLocked = false
    @Environment(\.playerGapService) private var service
    @State private var control: PlayWireValue?

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
                                Text(LocalizedStringKey("club.topic.genericOps.action." + action))
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary).accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                        .disabled(writeLocked)
                        .accessibilityIdentifier("club.topic.genericOps.\(action)")
                    }
                } header: {
                    Text("club.topic.genericOps.title")
                }
            }
        }
        .task(id: "\(activityID):\(revision)") {
            guard let service, case let .ready(data) = await service.sharedControl(activityID: activityID) else {
                control = nil
                return
            }
            control = data
        }
    }

    private func statusLine(_ run: PlayWireValue) -> some View {
        let status = run["operationStatus"].text.flatMap { ["RUNNING", "PAUSED", "INTERRUPTED", "CANCELLED"].contains($0) ? $0 : nil } ?? "unknown"
        let mode = run["authorityMode"].text.flatMap { ["ONLINE", "MANUAL"].contains($0) ? $0 : nil } ?? "unknown"
        return (Text(LocalizedStringKey("club.topic.genericOps.status." + status)) + Text(verbatim: " · ")
            + Text(LocalizedStringKey("club.topic.genericOps.authority." + mode)))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func teamsLine(_ teams: [PlayWireValue]) -> some View {
        let parts: [Text] = teams.compactMap { team in
            guard let id = team["teamId"].tolerantInteger else { return nil }
            let base = Text("club.topic.genericOps.team \(id)")
            return team["exited"].bool == true ? base + Text("club.topic.genericOps.teamExited") : base
        }
        return parts.enumerated().reduce(Text(verbatim: "")) { partial, item in
            item.offset == 0 ? item.element : partial + Text(verbatim: " · ") + item.element
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// CLB-G13a: 默认结局收尾. A 1–500 character reason, then confirm, then `PLAN_FALLBACK`.
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
                        Text("club.topic.planFallback.available").font(.footnote).foregroundStyle(.secondary)
                        Button("club.topic.planFallback.fill") { draftError = nil; editing = true }
                            .disabled(busy)
                            .accessibilityIdentifier("club.topic.planFallback.fill")
                    } else if !status.reason.isEmpty {
                        Text(verbatim: status.reason).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let failure { Text(failure).font(.footnote).foregroundStyle(.red) }
                } header: {
                    Text("club.topic.planFallback.title")
                }
            }
            if let result {
                Section {
                    Text(verbatim: result.title)
                    Text("club.topic.planFallback.reason \(result.reason)").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .task(id: "\(activityID):\(revision)") { await reload() }
        .cySheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    Section {
                        TextField("club.topic.planFallback.placeholder", text: $draft, axis: .vertical)
                            .lineLimit(3...8)
                            .accessibilityIdentifier("club.topic.planFallback.reasonField")
                    } footer: {
                        if let draftError { Text(draftError).foregroundStyle(.red) }
                        // CLB-r10-nat-topic-detail-07: the length rule, not an n/500 counter (MP topic-detail director 收尾原因 1–500 字).
                        else { Text("club.topic.planFallback.reasonRequired") }
                    }
                }
                .navigationTitle(Text("club.topic.planFallback.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { editing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("club.topic.planFallback.next") {
                            guard (try? PlayPlanFallbackStatus.validatedReason(draft)) != nil else {
                                draftError = "club.topic.planFallback.reasonRequired"
                                return
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

    private func submit() async {
        guard let submit = actions.submitPlanFallback, !busy else { return }
        guard status?.available == true, status?.controlRevision == revision else {
            failure = "club.topic.planFallback.changed"
            return
        }
        busy = true
        failure = nil
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
