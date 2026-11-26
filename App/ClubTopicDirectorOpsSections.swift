import SwiftUI

/// CLB-G13a: 通用玩法现场运营 inside the topic director block.
/// Reads shared-run control. Each offered action opens its own form sheet (`ClubTopicGenericOpsSheet`, MP
/// topic-detail index.wxml:212-236), 工作人员指导完成 included (answer form). 开始离线记录 is a confirm, then
/// `shared/export/anchor` (MP director.js openGenericOps → startOfflineRecord / _reconcileOfflineAnchor).
/// Rows are disabled while the director write is locked (MP wxml:204-209 `writeLocked`).
@MainActor struct ClubTopicGenericOpsSection: View {
    let activityID: Int
    let revision: Int
    var writeLocked: Bool = false
    let onOpenAction: (String) -> Void
    var onSubmitted: () -> Void = {}
    @Environment(\.playerGapService) private var service
    @State private var control: PlayWireValue?
    @State private var editing: ClubTopicGenericOpsSelection?
    @State private var reloadToken = 0
    @State private var confirmingAnchor = false
    @State private var anchoring = false
    /// The authority epoch an anchor write was sent for, until a control read shows that anchor (MP `_offlineAnchorPending`).
    @State private var pendingAnchorEpoch: Int?
    @State private var anchorMessage: LocalizedStringKey?
    @State private var anchorServerMessage: String?

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
                        Button { open(action) } label: {
                            HStack {
                                Text(LocalizedStringKey("club.topic.genericOps.action." + action))
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary).accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                        .disabled(writeLocked || anchoring)
                        .accessibilityIdentifier("club.topic.genericOps.\(action)")
                    }
                } header: {
                    Text("club.topic.genericOps.title")
                } footer: {
                    anchorFooter
                }
            }
        }
        .task(id: "\(activityID):\(revision):\(reloadToken)") {
            guard let service, case let .ready(data) = await service.sharedControl(activityID: activityID) else {
                control = nil
                return
            }
            control = data
        }
        .sheet(item: $editing) { selection in
            sheet(selection)
        }
        .confirmationDialog("parityB.shared.offlineStart", isPresented: $confirmingAnchor, titleVisibility: .visible) {
            Button("parityB.shared.offlineConfirm") { Task { await startOfflineRecord() } }
            Button("parityB.shared.offlineLater", role: .cancel) {}
        } message: {
            Text("parityB.shared.offlineBody")
        }
    }

    @ViewBuilder private var anchorFooter: some View {
        if anchoring {
            Text("parityB.shared.anchoring")
        } else if let anchorMessage {
            VStack(alignment: .leading, spacing: 4) {
                Text(anchorMessage)
                if let anchorServerMessage { Text(verbatim: anchorServerMessage) }
            }
        }
    }

    /// MP director.js startOfflineRecord: one anchor for the current epoch. A `GAME_*` refusal proves nothing started;
    /// any other reply is settled only by a fresh control read that carries an anchor for the same epoch.
    private func startOfflineRecord() async {
        guard !writeLocked, !anchoring, let service, let control, control["offlineAnchorAvailable"].bool == true,
              let epoch = control["run"]["authorityEpoch"].integer else { return }
        anchoring = true
        anchorServerMessage = nil
        pendingAnchorEpoch = epoch
        let result = await service.anchorSharedRun(activityID: activityID)
        if case .refused(let message) = result {
            pendingAnchorEpoch = nil
            anchorMessage = "parityB.shared.notStarted"
            anchorServerMessage = message
        } else {
            await reconcileAnchor()
        }
        anchoring = false
        reloadToken &+= 1
    }

    /// MP `_reconcileOfflineAnchor`.
    private func reconcileAnchor() async {
        guard let service, let epoch = pendingAnchorEpoch else { return }
        if case let .ready(data) = await service.sharedControl(activityID: activityID),
           data["offlineAnchor"]["epoch"].integer == epoch, (data["offlineAnchor"]["at"].integer ?? 0) >= 1 {
            pendingAnchorEpoch = nil
            anchorMessage = "parityB.shared.anchored"
            control = data
        } else {
            anchorMessage = "parityB.shared.anchorUnknown"
        }
    }

    /// MP director.js openGenericOps: nothing while locked or before control loads.
    private func open(_ action: String) {
        guard !writeLocked, !anchoring, control != nil else { return }
        if action == "OFFLINE_ANCHOR" {
            // An unknown anchor write is re-checked, never sent twice (MP _reconcileOfflineAnchor).
            if pendingAnchorEpoch != nil { Task { await reconcileAnchor() } } else { confirmingAnchor = true }
        } else if PlaySharedRunOps.formActions.contains(action) {
            editing = ClubTopicGenericOpsSelection(action: action)
        } else {
            onOpenAction(action)
        }
    }

    @ViewBuilder private func sheet(_ selection: ClubTopicGenericOpsSelection) -> some View {
        if let snapshot = control {
            ClubTopicGenericOpsSheet(activityID: activityID, action: selection.action, control: snapshot,
                                     writeLocked: writeLocked, onSubmitted: submitted)
        }
    }

    private func submitted() {
        reloadToken &+= 1
        onSubmitted()
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
                        else { Text(verbatim: "\(draft.count)/500").monospacedDigit() }
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
