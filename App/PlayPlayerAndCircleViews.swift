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
                Button("playx.refresh") {
                    if let readback = submissionReadback { Task { await readback.refresh() } }
                }
                    .disabled(submissionReadback?.canRefresh != true)
                if let issue = model.issue ?? issue ?? actionReview.issue { PlayExperienceIssueView(issue: issue) }
                if model.phase == "unknown" {
                    Text("playx.unknown.body")
                    Button("playx.reconcile") { Task { await model.recover() } }.accessibilityIdentifier("playx.player.reconcile")
                    Button("playx.retryExact") { Task { await model.retryExact() } }
                }
            }
            if model.hasCurrentProjection, let projection = model.projection {
                Section("playx.player.role") {
                    if let name = projection.role["name"].text { Text(verbatim: name).font(.headline) }
                    if let brief = projection.role["publicBrief"].text { Text(verbatim: brief) }
                    if projection.roleConfirmed { Label("playx.player.role.confirmed", systemImage: "checkmark.seal") }
                    else { Button("playx.player.role.confirm") { actionReview.prepare(.role, ticket: ticket) }.disabled(!canAct) }
                }
                PlayPlayerTeamStatusView(state: teamReadback?.state ?? .unconfirmed)
                PlayPlayerLeaderboardView(state: leaderboardReadback?.state ?? .hidden)
                ForEach(projection.nodes) { node in
                    Section {
                        Text(verbatim: node.name ?? "#\(node.id)").font(.headline)
                        if let state = node.state { Text(verbatim: state).font(.caption) }
                        if let clue = node.clue { Text(verbatim: clue) }
                        if node.state == "PAUSED" {
                            if let reason = node.pause["reason"].text { Text(verbatim: reason) }
                            if let eta = node.pause["resumeEta"].text { LabeledContent("playx.player.resumeETA") { Text(verbatim: eta) } }
                            if let fallback = node.fallback["playerMessage"].text { Text(verbatim: fallback) }
                        }
                        if let prompt = node.task["prompt"].text { Text(verbatim: prompt) }
                        if node.task.object != nil {
                            PlayPlayerSubmissionStatusView(state: submissionReadback?.state(nodeID: node.id) ?? .unconfirmed)
                        }
                        if node.task["inputType"].text == "TEXT" {
                            TextField("playx.answer.placeholder", text: Binding(get: { sameModel ? actionReview.text(nodeID: node.id) : "" }, set: { actionReview.setText($0, nodeID: node.id, ticket: ticket) }), axis: .vertical)
                                .accessibilityIdentifier("playx.player.text.\(node.id)").disabled(!canAct).focused($focusedNode, equals: node.id)
                            Button("playx.review") {
                                actionReview.prepare(.text(nodeID: node.id, answer: actionReview.text(nodeID: node.id)), ticket: ticket)
                            }.disabled(!canAct)
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
                        ForEach(Array((node.hint["revealedTexts"].array ?? []).enumerated()), id: \.offset) { _, hint in
                            if let text = hint["text"].text { Text(verbatim: text) }
                        }
                        if let level = node.hint["nextLevel"].integer, let impact = node.hint["nextImpactLabel"].text, !impact.isEmpty {
                            Button("playx.hints.request") { actionReview.prepare(.hint(nodeID: node.id), ticket: ticket) }
                                .disabled(!canAct)
                        }
                        if node.hint["revealAvailable"].bool == true, let impact = node.hint["revealImpactLabel"].text, !impact.isEmpty {
                            Button("playx.player.reveal") { actionReview.prepare(.reveal(nodeID: node.id), ticket: ticket) }
                                .disabled(!canAct)
                        }
                        if let completion = node.completionStatus { Text(verbatim: completion).font(.footnote) }
                    }
                }
                if let ending = projection.story["ending"].object {
                    Section("playx.ending") {
                        if let title = ending["title"]?.text { Text(verbatim: title).font(.headline) }
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
            if actionReview.working { ProgressView("playerEvidence.working") }
        }.privacySensitive().navigationTitle("playx.player.title").accessibilityIdentifier("playx.player.view")
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
    @Bindable var model: PlayCircleCoordinator
    @State private var invite = ""
    @State private var notes: [String: String] = [:]
    @State private var answers: [String: String] = [:]
    @State private var pending: PlayCircleIntent?
    @State private var review = false
    @State private var openReview = false

    // Mini-program pages/play/circle: status strip -> hero -> offers -> light interactions
    // -> memory card -> my records -> disclaimer. Player surface (dark), CY tokens.
    var body: some View {
        List {
            statusSection
            if model.card == nil { openSection }
            if let card = model.card {
                heroSection(card)
                offersSection(card)
                interactionSections(card)
                memorySection(card)
                recordsSection(card)
                disclaimerSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .privacySensitive().navigationTitle("playx.circle.title").accessibilityIdentifier("playx.circle.view")
        .task { await model.loadOffers() }
        .confirmationDialog("playx.review", isPresented: $review, titleVisibility: .visible) {
            Button("playx.submit") { if let pending { Task { await model.submit(pending); self.pending = nil } } }
        } message: { Text("playx.circle.notice") }
        .confirmationDialog("playx.circle.open", isPresented: $openReview, titleVisibility: .visible) {
            Button("playx.submit") { Task { await model.open(inviteCode: invite.isEmpty ? nil : invite) } }
        }
    }

    /// Mini-program `.cy-status`: colour only on the dot, narration in type. Unknown receipts re-read, never re-write.
    @ViewBuilder private var statusSection: some View {
        let showsStatus = model.issue != nil || model.phase == "unknown" || model.phase == "unknownOpen"
            || (model.phase == "loading" && model.card == nil)
        if showsStatus {
            Section {
                if model.phase == "loading" && model.card == nil {
                    HStack(spacing: CYSpacing.sm) { ProgressView(); Text("playx.circle.loading").font(CYTypography.label).foregroundStyle(CYColor.textTertiary) }
                }
                if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                if model.phase == "unknown" || model.phase == "unknownOpen" {
                    HStack(alignment: .top, spacing: CYSpacing.sm) {
                        Circle().fill(CYColor.warningText).frame(width: 6, height: 6).padding(.top, 7).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            LabeledContent("playx.state") { PlayRuntimePhaseText(phase: model.phase) }.font(CYTypography.label)
                            if model.phase == "unknownOpen" { Text("playx.circle.openUnknown").font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
                        }
                    }
                    if model.phase == "unknown" {
                        Button("playx.reconcile") { Task { await model.recover() } }
                            .buttonStyle(.cySecondary).accessibilityIdentifier("playx.circle.reconcile")
                    }
                }
            }.listRowBackground(CYColor.bgSurface)
        }
    }

    private var openSection: some View {
        Section("playx.circle.open") {
            TextField("playx.circle.invite", text: $invite).textInputAutocapitalization(.characters).autocorrectionDisabled()
            if model.offers.count < 3 { Text("playx.circle.closed").font(CYTypography.label).foregroundStyle(CYColor.textTertiary) }
            else {
                Button("playx.circle.open") { openReview = true }.buttonStyle(.cyPrimary(fullWidth: true)).disabled(model.phase != "ready")
            }
        }.listRowBackground(CYColor.bgSurface)
    }

    private func recordedIDs(_ card: PlayCircleCard) -> Set<String> {
        Set(card.records.compactMap { PlayCircleCard.identifier($0["offerId"]) })
    }

    /// Mini-program `.hero`: eyebrow, title, progress "已记录 n / 2 家", invite code, share button.
    private func heroSection(_ card: PlayCircleCard) -> some View {
        let count = card.raw["recordedMerchantCount"].tolerantInteger ?? card.records.count
        return Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("playx.circle.eyebrow").font(CYTypography.caption).foregroundStyle(CYColor.accentText)
                Text("playx.circle.title").font(CYTypography.pageTitle).foregroundStyle(CYColor.textPrimary)
                Text("playx.circle.progress \(count)").font(CYTypography.numericBody).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                if let code = card.raw["inviteCode"].text, !code.isEmpty {
                    LabeledContent("playx.circle.inviteLabel") { Text(verbatim: code).monospacedDigit() }
                        .font(CYTypography.caption).foregroundStyle(CYColor.textSecondary)
                    if card.raw["completed"].bool != true {
                        ShareLink(item: code) { Label("playx.circle.shareInvite", systemImage: "square.and.arrow.up") }
                            .buttonStyle(.cySecondary(fullWidth: true))
                    }
                }
            }.padding(.vertical, CYSpacing.xs)
        }.listRowBackground(CYColor.accentSoft)
    }

    private func offersSection(_ card: PlayCircleCard) -> some View {
        let done = recordedIDs(card)
        return Section {
            ForEach(Array(model.offers.enumerated()), id: \.offset) { _, offer in
                if let id = PlayCircleCard.identifier(offer["id"]) ?? PlayCircleCard.identifier(offer["offerId"]) {
                    let recorded = done.contains(id)
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        HStack(spacing: CYSpacing.sm) {
                            if let code = offer["candidateCode"].text {
                                Text(verbatim: code).font(CYTypography.micro).monospacedDigit()
                                    .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                                    .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous))
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                            if let name = offer["candidateName"].text ?? offer["supplyName"].text { Text(verbatim: name).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary) }
                            else { Text("playx.circle.offerUntitled").font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary) }
                            Spacer(minLength: 0)
                            if recorded { Label("playx.circle.recordedBadge", systemImage: "checkmark.circle.fill").font(CYTypography.caption).foregroundStyle(CYColor.successText) }
                        }
                        if offer["candidateName"].text != nil, let supply = offer["supplyName"].text, !supply.isEmpty {
                            Text(verbatim: supply).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                        }
                        if let detail = offer["actionValue"].text, !detail.isEmpty { Text(verbatim: detail).font(CYTypography.label).foregroundStyle(CYColor.textTertiary) }
                        if !recorded && card.raw["completed"].bool != true {
                            TextField("playx.circle.note", text: noteBinding(id), axis: .vertical)
                                .font(CYTypography.label).padding(CYSpacing.sm)
                                .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous))
                            Button("playx.circle.recordOne") {
                                pending = .record(offerID: id, note: notes[id] ?? ""); review = true
                            }.buttonStyle(.cySecondary(fullWidth: true)).disabled(model.phase != "ready")
                                .accessibilityIdentifier("playx.circle.offer.\(id)")
                        }
                    }.padding(.vertical, CYSpacing.xs)
                }
            }
        } header: { Text("playx.circle.offers").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary).textCase(nil) }
        .listRowBackground(CYColor.bgSurface)
    }

    @ViewBuilder private func interactionSections(_ card: PlayCircleCard) -> some View {
        if !card.stages.isEmpty && card.raw["completed"].bool != true {
            Section {
                ForEach(card.stages, id: \.self) { stage in
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text(LocalizedStringKey("playx.circle.stage." + stage)).font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                        if ["FITNESS", "FRIENDS"].contains(card.themeCode) {
                            Picker("playx.choose", selection: binding(stage)) {
                                Text("playx.choose").tag("")
                                ForEach(Array(model.offers.enumerated()), id: \.offset) { _, offer in
                                    if let code = offer["candidateCode"].text { Text(verbatim: offer["candidateName"].text ?? code).tag(code) }
                                }
                            }
                        } else if card.themeCode == "DATE" {
                            Picker("playx.choose", selection: binding(stage)) {
                                Text("playx.choose").tag("")
                                Text("playx.circle.date.q1").tag("Q1"); Text("playx.circle.date.q2").tag("Q2"); Text("playx.circle.date.q3").tag("Q3")
                            }
                        } else if card.themeCode == "SHANGHAI" { Text("playx.circle.shanghaiGate").font(CYTypography.label).foregroundStyle(CYColor.textTertiary) }
                        else { TextField("playx.circle.answer", text: binding(stage), axis: .vertical).font(CYTypography.label) }
                        // The city-keyword stage has no picker yet, so its save button would never enable.
                        if card.themeCode != "SHANGHAI" {
                            Button("playx.circle.save") { pending = .answer(stage: stage, value: answers[stage] ?? ""); review = true }
                                .buttonStyle(.cySecondary(fullWidth: true))
                                .disabled(model.phase != "ready" || (answers[stage] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }.padding(.vertical, CYSpacing.xs)
                }
            } header: { Text("playx.circle.interactions").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary).textCase(nil) }
            .listRowBackground(CYColor.bgSurface)
        }
    }

    /// Mini-program `.complete`: shared memory card shown once the exploration is complete.
    @ViewBuilder private func memorySection(_ card: PlayCircleCard) -> some View {
        if card.raw["completed"].bool == true {
            Section {
                VStack(alignment: .center, spacing: CYSpacing.sm) {
                    if let title = card.raw["memoryTitle"].text, !title.isEmpty { Text(verbatim: title).font(CYTypography.cardTitle) }
                    else { Text("playx.circle.memoryTitle").font(CYTypography.cardTitle) }
                    ForEach(Array(card.memoryLines.enumerated()), id: \.offset) { _, line in Text(verbatim: line).font(CYTypography.label).foregroundStyle(CYColor.textSecondary) }
                    if card.memoryLines.isEmpty { Text("playx.circle.memoryEmpty").font(CYTypography.label).foregroundStyle(CYColor.textSecondary) }
                }.multilineTextAlignment(.center).frame(maxWidth: .infinity).foregroundStyle(CYColor.textPrimary).padding(.vertical, CYSpacing.sm)
            }.listRowBackground(CYColor.accentSoft)
        }
    }

    @ViewBuilder private func recordsSection(_ card: PlayCircleCard) -> some View {
        if !card.records.isEmpty || (!card.memoryLines.isEmpty && card.raw["completed"].bool != true) {
            Section {
                ForEach(Array(card.records.enumerated()), id: \.offset) { _, record in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: record["candidateName"].text ?? record["supplyName"].text ?? "—").font(CYTypography.bodyMedium).foregroundStyle(CYColor.textPrimary)
                        if record["candidateName"].text != nil, let supply = record["supplyName"].text { Text(verbatim: supply).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
                        if let note = record["note"].text, !note.isEmpty { Text(verbatim: note).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary) }
                    }
                }
                if card.raw["completed"].bool != true {
                    ForEach(Array(card.memoryLines.enumerated()), id: \.offset) { _, line in Text(verbatim: line).font(CYTypography.label) }
                }
            } header: { Text("playx.circle.records").font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary).textCase(nil) }
            .listRowBackground(CYColor.bgSurface)
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text("playx.circle.disclaimer").font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }.listRowBackground(Color.clear).listRowSeparator(.hidden)
    }

    private func binding(_ stage: String) -> Binding<String> { Binding(get: { answers[stage] ?? "" }, set: { answers[stage] = $0 }) }
    private func noteBinding(_ id: String) -> Binding<String> { Binding(get: { notes[id] ?? "" }, set: { notes[id] = $0 }) }
}
