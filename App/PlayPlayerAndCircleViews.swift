import SwiftUI

@MainActor struct PlayPlayerSessionView: View {
    @Bindable var model: PlayPlayerGameCoordinator
    var deviceModel: ((Int) -> PlayDeviceCaptureCoordinator)? = nil
    @State private var evidenceTarget: PlayerTaskEvidenceTarget?
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var actionReview: PlayPlayerActionReviewController
    @FocusState private var focusedNode: Int?
    private var sameModel: Bool { actionReview.model === model }
    private var canAct: Bool { sameModel && actionReview.canInteract }
    init(model: PlayPlayerGameCoordinator, deviceModel: ((Int) -> PlayDeviceCaptureCoordinator)? = nil) {
        self.model = model; self.deviceModel = deviceModel
        _actionReview = StateObject(wrappedValue: .init(model: model))
    }
    @State private var issue: PlayExperienceError?
    @State private var submissionReadback: PlayPlayerSubmissionReadback?
    @State private var teamReadback: PlayPlayerTeamReadback?
    @State private var leaderboardReadback: PlayPlayerLeaderboardReadback?
    var body: some View {
        let ticket = sameModel ? actionReview.capture() : nil
        ScrollViewReader { proxy in
        List {
            Section {
                LabeledContent("playx.state") { PlayRuntimePhaseText(phase: model.phase) }
                CYPillButton("playx.refresh", style: .secondary) {
                    if let readback = submissionReadback { Task { await readback.refresh() } }
                }
                    .listRowBackground(Color.clear)
                    .disabled(submissionReadback?.canRefresh != true)
                if let issue = model.issue ?? issue ?? actionReview.issue { PlayExperienceIssueView(issue: issue) }
                if model.phase == "unknown" {
                    Text("playx.unknown.body")
                    CYPillButton("playx.reconcile", style: .secondary) { Task { await model.recover() } }.listRowBackground(Color.clear).accessibilityIdentifier("playx.player.reconcile")
                    CYPillButton("playx.retryExact", style: .tertiary) { Task { await model.retryExact() } }.listRowBackground(Color.clear)
                }
            }
            if model.hasCurrentProjection, let projection = model.projection {
                Section("playx.player.role") {
                    if let name = projection.role["name"].text { Text(verbatim: name).cyText(.cardTitle) }
                    if let brief = projection.role["publicBrief"].text { Text(verbatim: brief) }
                    if projection.roleConfirmed { CYStatusChip("playx.player.role.confirmed", tone: .success, systemImage: "checkmark.seal") }
                    else { CYPillButton("playx.player.role.confirm") { actionReview.prepare(.role, ticket: ticket) }.listRowBackground(Color.clear).disabled(!canAct) }
                }
                PlayPlayerTeamStatusView(state: teamReadback?.state ?? .unconfirmed)
                    .islandTeamStatus(String(projection.teamID))
                PlayPlayerLeaderboardView(state: leaderboardReadback?.state ?? .hidden)
                ForEach(projection.nodes) { node in
                    Section {
                        Text(verbatim: node.name ?? "#\(node.id)").cyText(.cardTitle)
                        if let state = node.state { Text(verbatim: state).cyText(.meta) }
                        if let clue = node.clue { Text(verbatim: clue) }
                        if let pause = PlayStationPauseNotice(state: node.state, pause: node.pause, fallback: node.fallback) {
                            PlayStationPauseView(notice: pause)
                        }
                        if node.state == "FALLBACK_COMPLETED" {
                            // U05-02: completed through the approved replacement; the history stays.
                            Text("station.fallbackCompleted", tableName: "PlayRecovery").cyText(.caption)
                                .accessibilityIdentifier("playRecovery.fallbackCompleted.\(node.id)")
                        }
                        if let prompt = node.task["prompt"].text {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text("playx.player.stationTask").cyText(.meta).foregroundStyle(.secondary)
                                Text(verbatim: prompt).cyText(.cardTitle)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        if node.task.object != nil {
                            PlayPlayerSubmissionStatusView(state: submissionReadback?.state(nodeID: node.id) ?? .unconfirmed)
                        }
                        if node.task["inputType"].text == "TEXT" {
                            TextField("playx.answer.placeholder", text: Binding(get: { sameModel ? actionReview.text(nodeID: node.id) : "" }, set: { actionReview.setText($0, nodeID: node.id, ticket: ticket) }), axis: .vertical)
                                .accessibilityIdentifier("playx.player.text.\(node.id)").disabled(!canAct).focused($focusedNode, equals: node.id)
                            CYPillButton("playx.review") {
                                actionReview.prepare(.text(nodeID: node.id, answer: actionReview.text(nodeID: node.id)), ticket: ticket)
                            }.listRowBackground(Color.clear).disabled(!canAct)
                        } else if node.task["inputType"].text == "PHOTO" || node.task["inputType"].text == "SCAN" {
                            Button(node.task["inputType"].text == "SCAN" ? "playerEvidence.scan.title" : "playerEvidence.photo.title") {
                                do { evidenceTarget = try model.evidenceTarget(nodeID: node.id) }
                                catch { issue = .invalidAction }
                            }.disabled(model.phase != "ready").accessibilityIdentifier("playerEvidence.open.\(node.id)")
                        }
                        ForEach(Array(node.choices.enumerated()), id: \.offset) { _, choice in
                            if let id = choice["id"].text, let label = choice["label"].text {
                                Button { actionReview.prepare(.choice(nodeID: node.id, choiceID: id), ticket: ticket) } label: { Text(verbatim: label) }
                                    .disabled(!canAct)
                            }
                        }
                        ForEach(Array((node.hint["revealedTexts"].array ?? []).enumerated()), id: \.offset) { offset, hint in
                            if let text = hint["text"].text { Text("playx.player.hintLine \(offset + 1) \(text)") }
                        }
                        if let level = node.hint["nextLevel"].integer, let impact = node.hint["nextImpactLabel"].text, !impact.isEmpty {
                            Button("playx.hints.request") { actionReview.prepare(.hint(nodeID: node.id), ticket: ticket) }
                                .disabled(!canAct)
                            Text(verbatim: impact).cyText(.meta).foregroundStyle(.secondary)
                        }
                        if node.hint["revealAvailable"].bool == true, let impact = node.hint["revealImpactLabel"].text, !impact.isEmpty {
                            Button("playx.player.reveal") { actionReview.prepare(.reveal(nodeID: node.id), ticket: ticket) }
                                .disabled(!canAct)
                            Text(verbatim: impact).cyText(.meta).foregroundStyle(.secondary)
                        }
                        if let completion = node.completionStatus { Text(verbatim: completion).cyText(.bodyCompact) }
                    }
                }
                if let ending = projection.story["ending"].object {
                    Section("playx.ending") {
                        if let title = ending["title"]?.text { Text(verbatim: title).cyText(.cardTitle) }
                        if let text = ending["summary"]?.text ?? ending["text"]?.text { Text(verbatim: text) }
                    }
                }
                if let receipt = model.receipt {
                    Section("playx.player.receipt") {
                        LabeledContent("playx.state") { Text(verbatim: receipt.outcome) }
                        if let answer = receipt.result["answerReveal"].text { Text(verbatim: answer) }
                    }
                }
            }
            if sameModel, let offered = actionReview.review {
                PlayPlayerActionReviewCard(owner: actionReview, offered: offered).id(offered.id)
            }
            if actionReview.working { CYSkeleton().accessibilityLabel(Text("playerEvidence.working")) }
        }.cyGroupedSurface().privacySensitive().cyPageTitle("playx.player.title").accessibilityIdentifier("playx.player.view")
            .task {
                guard !Task.isCancelled else { return }
                submissionReadback?.dismiss()
                teamReadback?.dismiss()
                leaderboardReadback?.dismiss()
                let leaderboard = PlayPlayerLeaderboardReadback(model: model)
                leaderboardReadback = leaderboard
                let team = PlayPlayerTeamReadback(model: model)
                teamReadback = team
                let readback = PlayPlayerSubmissionReadback(model: model)
                submissionReadback = readback
                await readback.open()
                team.acceptFreshRead()
                leaderboard.acceptFreshRead()
            }
            .onDisappear { submissionReadback?.dismiss() }
            .onDisappear { teamReadback?.dismiss() }
            .onDisappear { leaderboardReadback?.dismiss() }
            .onChange(of: model.phase) { _, phase in
                if phase == "ready" { teamReadback?.acceptFreshRead() }
                if phase == "ready" { leaderboardReadback?.acceptFreshRead() }
            }
            .onChange(of: model.projection) { _, _ in
                teamReadback?.acceptFreshRead()
                leaderboardReadback?.acceptFreshRead()
            }
            .navigationDestination(item: $evidenceTarget) { target in
                PlayerTaskEvidenceView(target: target, player: model, device: deviceModel?(target.nodeID))
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar { ToolbarItemGroup(placement: .keyboard) {
                Spacer(); Button("action.done") { focusedNode = nil }
            } }
            .onChange(of: actionReview.review?.id) { _, id in
                if let id, actionReview.review?.id == id { focusedNode = nil; issue = nil; proxy.scrollTo(id, anchor: .top) }
            }
            .background { PlayPlayerActionRoot(owner: actionReview).frame(width: 0, height: 0) }
            .onAppear { actionReview.appear(active: scenePhase == .active) }
            .onDisappear { actionReview.disappear() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { focusedNode = nil; actionReview.background() }
                else { actionReview.sceneChanged(active: phase == .active) }
            }
            .onChange(of: model.hasCurrentProjection) { _, current in if !current { actionReview.retire() } }
            .onChange(of: ObjectIdentifier(model)) { _, _ in actionReview.retire() }
        }
    }
}

@MainActor struct PlayCircleView: View {
    /// `pages/play/circle/index` is `dropped:retired-redirect-shell-in-xcx`.
    /// The screen stays on the unavailable landing. It does not open the live play page.
    @Bindable var model: PlayCircleCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.rootTabSwitch) private var rootTabSwitch

    var body: some View {
        PlayCircleRetiredLinkView(goHome: leave)
            .cyPageTitle("playx.circle.title")
            .accessibilityIdentifier("playx.circle.view")
    }

    /// Home tab when the root switch exists. Otherwise leave this screen.
    /// Neither path opens `pages/play/index`.
    private func leave() {
        _ = model.topicID
        if rootTabSwitch.isAvailable { rootTabSwitch(.home) }
        else { dismiss() }
    }
}
