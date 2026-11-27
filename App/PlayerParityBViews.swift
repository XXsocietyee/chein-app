import SwiftUI

/// Parity package P-B player views. Every section reads `\.playerGapService` (or the roam passport reader)
/// and renders nothing when the shipped China composition did not build that capability for this viewer.

// MARK: analytics client

private struct AnalyticsEventClientKey: EnvironmentKey { static let defaultValue: AnalyticsEventClient? = nil }
extension EnvironmentValues {
    /// Injected by `SessionRootView` only when the player grant admits the batch path; nil tracks nothing.
    var analyticsEventClient: AnalyticsEventClient? {
        get { self[AnalyticsEventClientKey.self] }
        set { self[AnalyticsEventClientKey.self] = newValue }
    }
}

@MainActor private enum AnalyticsEventClientCache {
    static var client: (key: String, value: AnalyticsEventClient)?
}

extension AppSession {
    /// One queue per account and session epoch, as `analytics.js` keys its queue by account.
    var analyticsEventClient: AnalyticsEventClient? {
        guard let service = playerGapService, let context = currentRuntimeDependencyContext else {
            AnalyticsEventClientCache.client = nil; return nil
        }
        let epoch = context.session.epoch, account = context.session.accountID
        let key = "\(account):\(epoch)"
        if let cached = AnalyticsEventClientCache.client, cached.key == key { return cached.value }
        let client = AnalyticsEventClient(accountID: account, store: AnalyticsDefaultsQueueStore(), isCurrent: { [weak self] in
            guard let now = self?.currentRuntimeDependencyContext else { return false }
            return now.session.epoch == epoch && now.session.accountID == account
        }, post: { await service.postAnalyticsBatch($0) })
        AnalyticsEventClientCache.client = (key, client)
        return client
    }
}

/// U08-02: `finish_route_recommendation_shown` once per card, `…_click` on open, with one impression id.
struct FinishRouteAnalyticsModifier: ViewModifier {
    @Environment(\.analyticsEventClient) private var analytics
    let card: PlayFinishRouteCard
    let activityID: Int?
    let topicID: Int?
    let runID: Int?
    let mode: Int?
    @State private var source: FinishRouteAnalyticsSource?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture().onEnded { track("finish_route_recommendation_click") })
            .task(id: card.activityID) {
                let next = FinishRouteAnalyticsSource(activityID: activityID, topicID: topicID, runID: runID)
                source = next
                track("finish_route_recommendation_shown")
            }
    }

    private func track(_ name: String) {
        guard let analytics, let source else { return }
        analytics.track(name, bizType: "activity", bizID: card.activityID, pagePath: "/pages/play/index",
                        properties: source.properties(mode: mode))
    }
}

// MARK: roam passport (pages/roam/index _loadIntroPassport)

/// Server passport stats: 漫游 / 探店 / 活跃日 / 公里, and the 漫游记录 tile into the server history.
/// A missing count is an em dash, never zero. A failed read shows the issue, not local numbers.
@MainActor struct RoamPassportServerSummarySection: View {
    @Environment(\.locale) private var locale
    let reader: any RoamPassportHistoryReading
    @State private var phase: Phase = .loading
    private enum Phase { case loading, failed(Error), loaded(RoamPassportServerSummary) }

    var body: some View {
        let owner = RoamPassportHistoryOwner(reader)
        Section("parityB.passport.title") {
            switch phase {
            case .loading:
                CYSkeleton().accessibilityIdentifier("parityB.passport.loading")
            case .failed(let error):
                RoamExperienceIssue(error: error) { Task { await load() } }
                    .accessibilityIdentifier("parityB.passport.error")
            case .loaded(let summary):
                LabeledContent("parityB.passport.trips") { Text(summary.trips, format: .number) }
                LabeledContent("parityB.passport.shops") { count(summary.shops) }
                LabeledContent("parityB.passport.days") { count(summary.days) }
                LabeledContent(LocalizedStringKey(LocaleDisplay.usesMiles(locale) ? "parityB.passport.mi" : "parityB.passport.km")) {
                    if let meters = summary.distanceM { Text(LocaleDisplay.roadNumber(kilometers: Double(meters) / 1000, locale: locale), format: .number.precision(.fractionLength(1))) }
                    else { Text(verbatim: RoamPassportSummary.unknownText).accessibilityLabel(Text("roam.passport.unknown.a11y")) }
                }
                if owner.configured, owner.storageKey != nil {
                    NavigationLink {
                        RoamPassportHistoryView(reader: reader, localReader: nil, owner: owner)
                    } label: {
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text("parityB.passport.history").cyText(.cardTitle)
                            Text("parityB.passport.historyValue \(Int(summary.trips))").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        }
                    }.accessibilityIdentifier("parityB.passport.history")
                }
            }
        }
        .accessibilityIdentifier("parityB.passport")
        .task(id: owner) { await load() }
    }

    @ViewBuilder private func count(_ value: Int64?) -> some View {
        if let value { Text(value, format: .number) }
        else { Text(verbatim: RoamPassportSummary.unknownText).accessibilityLabel(Text("roam.passport.unknown.a11y")) }
    }

    private func load() async {
        if case .loaded = phase {} else { phase = .loading }
        do { phase = .loaded(try await reader.summary()) }
        catch is CancellationError { return }
        catch { phase = .failed(error) }
    }
}

// MARK: shared session organiser control (club topic-detail director)

/// The organiser's non-money panel for a ROUTE shared session: run status, ledger, and the offline record start.
/// It renders only after `shared/control` answers, which the server serves to the session organiser alone.
@MainActor struct SharedRunControlSection: View {
    @Environment(\.playerGapService) private var service
    let activityID: Int
    /// The director projection revision; a different control revision is a changed run (`GAME_STATE_CONFLICT`).
    var expectedRevision: Int? = nil
    @State private var control: SharedRunControlSummary?
    @State private var export: SharedRunExportSummary?
    @State private var message: LocalizedStringKey?
    @State private var serverMessage: String?
    @State private var writing = false
    @State private var unknown = false
    @State private var confirming = false
    @State private var pendingEpoch: Int?
    /// A lifecycle modifier on an empty group never fires, so a progress row stands in until the first read.
    @State private var loaded = false

    var body: some View {
        Group {
            if service == nil {
                EmptyView()
            } else if !loaded {
                ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity)
            } else if let control {
                Section("parityB.shared.title") {
                    LabeledContent("parityB.shared.status") { statusText(control) }
                    LabeledContent("parityB.shared.teams") { Text(control.teamCount, format: .number) }
                    LabeledContent("parityB.shared.stations") { Text(control.stationCount, format: .number) }
                    if let at = control.anchoredAt {
                        LabeledContent("parityB.shared.anchoredAt") {
                            Text(Date(timeIntervalSince1970: TimeInterval(at) / 1000), format: .dateTime.month().day().hour().minute())
                        }
                    }
                    if let serverMessage { Text(verbatim: serverMessage).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    if let message { Text(message).cyText(.meta).foregroundStyle(unknown ? CYColor.dangerText : CYColor.textSecondary) }
                    if unknown {
                        CYPillButton("parityB.shared.reconcile", style: .secondary) { Task { await reconcile() } }
                            .disabled(writing).listRowBackground(Color.clear)
                            .accessibilityIdentifier("parityB.shared.reconcile")
                    } else if control.offlineAnchorAvailable && control.anchoredAt == nil {
                        CYPillButton("parityB.shared.offlineStart", style: .secondary) { confirming = true }
                            .disabled(writing).listRowBackground(Color.clear)
                            .accessibilityIdentifier("parityB.shared.offlineStart")
                    }
                }
                Section("parityB.shared.ledger") {
                    if let export {
                        LabeledContent("parityB.shared.session") { Text(verbatim: String(export.sessionID)) }
                        LabeledContent("parityB.shared.configHash") { Text(verbatim: String(export.configHash.prefix(12))).cyText(.meta) }
                        LabeledContent("parityB.shared.highWater") { Text(verbatim: String(export.highWaterHash.prefix(12))).cyText(.meta) }
                        if let next = export.manualNextSequence { LabeledContent("parityB.shared.nextSequence") { Text(next, format: .number) } }
                        if export.manualNeedsReview { Text("parityB.shared.needsReview").foregroundStyle(CYColor.dangerText) }
                        if export.revision != control.revision || export.authorityEpoch != control.authorityEpoch {
                            Text("parityB.shared.versionChanged").foregroundStyle(CYColor.dangerText)
                        }
                    } else {
                        CYPillButton("parityB.shared.readLedger", style: .tertiary) { Task { await readExport() } }
                            .listRowBackground(Color.clear).accessibilityIdentifier("parityB.shared.readLedger")
                    }
                }
            }
        }
        .task(id: "\(activityID):\(expectedRevision ?? -1)") { await readControl() }
        .confirmationDialog("parityB.shared.offlineStart", isPresented: $confirming, titleVisibility: .visible) {
            Button("parityB.shared.offlineConfirm") { Task { await anchor() } }
            Button("parityB.shared.offlineLater", role: .cancel) {}
        } message: { Text("parityB.shared.offlineBody") }
    }

    /// `genericOpsStatusText`: Chinese labels only, never the backend code.
    private func statusText(_ control: SharedRunControlSummary) -> Text {
        let status = control.operationStatus.flatMap { ["RUNNING", "PAUSED", "INTERRUPTED", "CANCELLED"].contains($0) ? $0 : nil }
        let mode = control.authorityMode.flatMap { ["ONLINE", "MANUAL"].contains($0) ? $0 : nil }
        return Text(LocalizedStringKey("parityB.shared.run." + (status ?? "unknown"))) + Text(verbatim: " · ")
            + Text(LocalizedStringKey("parityB.shared.authority." + (mode ?? "unknown"))) + Text(verbatim: " · ")
            + Text("parityB.shared.epoch \(control.authorityEpoch)")
    }

    private func readControl() async {
        defer { loaded = true }
        guard let service else { control = nil; return }
        if case .ready(let data) = await service.sharedControl(activityID: activityID), let summary = SharedRunControlSummary(data) {
            if let expectedRevision, summary.revision != expectedRevision { control = summary; message = "parityB.shared.versionChanged"; return }
            control = summary
            if let pendingEpoch, summary.anchoredAt != nil, summary.authorityEpoch == pendingEpoch {
                self.pendingEpoch = nil; unknown = false; message = "parityB.shared.anchored"
            }
        } else if pendingEpoch == nil { control = nil }
    }

    private func readExport() async {
        guard let service else { return }
        if case .ready(let data) = await service.sharedExport(activityID: activityID) { export = SharedRunExportSummary(data) }
        else { message = "parityB.shared.ledgerUnavailable" }
    }

    /// `startOfflineRecord`: one anchor; a refusal re-reads; anything else is reconciled from control.
    private func anchor() async {
        guard let service, let control, control.offlineAnchorAvailable, !writing else { return }
        writing = true; pendingEpoch = control.authorityEpoch; message = "parityB.shared.anchoring"; serverMessage = nil
        let result = await service.anchorSharedRun(activityID: activityID)
        writing = false
        if case .refused(let text) = result {
            pendingEpoch = nil; message = "parityB.shared.notStarted"; serverMessage = text
            await readControl(); return
        }
        await reconcile()
    }

    /// `_reconcileOfflineAnchor`: only an anchor for the same epoch in a fresh control read settles it.
    private func reconcile() async {
        writing = true
        defer { writing = false }
        await readControl()
        if pendingEpoch != nil { unknown = true; message = "parityB.shared.anchorUnknown" }
        export = nil
    }
}

/// Club topic detail: a session row that opens the organiser panel, shown only when `shared/control` answers.
@MainActor struct SharedRunControlEntry: View {
    @Environment(\.playerGapService) private var service
    let activityID: Int
    @State private var organiser = false
    @State private var probed = false
    var body: some View {
        Group {
            if service == nil {
                EmptyView()
            } else if !probed {
                ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity)
            } else if organiser {
                NavigationLink {
                    List { SharedRunControlSection(activityID: activityID) }.appNavigationTitle("parityB.shared.title").navigationBarTitleDisplayMode(.inline)
                } label: { Label("parityB.shared.open", systemImage: "dot.radiowaves.left.and.right") }
                    .accessibilityIdentifier("parityB.shared.open.\(activityID)")
            }
        }
        .task(id: activityID) {
            defer { probed = true }
            guard let service else { organiser = false; return }
            if case .ready = await service.sharedControl(activityID: activityID) { organiser = true } else { organiser = false }
        }
    }
}

// MARK: lead member ticket scan (pages/play leadVerifyMemberTicket)

@MainActor struct LeadMemberTicketScanButton: View {
    @Environment(\.playerGapService) private var service
    let activityID: Int
    @State private var scanning = false
    @State private var busy = false
    @State private var note: LocalizedStringKey?
    @State private var serverNote: String?
    @State private var tone: CYStatusTone = .neutral

    var body: some View {
        if service != nil {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                CYPillButton("parityB.lead.scan", style: .secondary, systemImage: "qrcode.viewfinder") { scanning = true }
                    .disabled(busy).accessibilityIdentifier("parityB.lead.scan")
                if let serverNote { Text(verbatim: serverNote).cyText(.meta).foregroundStyle(color) }
                else if let note { Text(note).cyText(.meta).foregroundStyle(color) }
            }
            .cySheet(isPresented: $scanning) { Group {
                NativeQRScanner { raw in scanning = false; Task { await verify(raw) } }
            }.cySheet(detents: [.large]) }
        }
    }

    private var color: Color { tone == .success ? CYColor.successText : (tone == .danger ? CYColor.dangerText : CYColor.textSecondary) }

    private func show(_ key: LocalizedStringKey?, server: String? = nil, tone: CYStatusTone) {
        note = key; serverNote = server.flatMap { $0.isEmpty ? nil : $0 }; self.tone = tone
    }

    private func verify(_ raw: String) async {
        guard let service, let account = service.accountID, !busy else { return }
        let code: String
        switch LeadMemberTicket.resolve(raw) {
        case .malformed: show("parityB.lead.badCode", tone: .danger); return
        case .notTopic: show("parityB.lead.topicOnly", tone: .danger); return
        case .code(let value): code = value
        }
        busy = true
        defer { busy = false }
        guard let seat = RegistrationSeatTarget(code: code, activityID: activityID) else {
            switch LeadTicketScanOutcome.classify(await service.scanGroupMemberTicket(code: code, activityID: activityID), seat: nil) {
            case .verified(let text): show("parityB.lead.verified", server: text, tone: .success)
            case .failed(let text): show("parityB.lead.failed", server: text, tone: .danger)
            default: show("parityB.lead.failed", tone: .danger)
            }
            return
        }
        let store = LeadTicketPendingStore(), key = LeadTicketPendingStore.key(accountID: account, target: seat)
        if store.isHeld(key) {
            // A held seat is only reread; the original write is never sent again.
            if LeadTicketScanOutcome.recovered(await service.seatReceipt(seat), seat: seat) {
                store.clear(key); show("parityB.lead.verified", tone: .success)
            } else { show("parityB.lead.seatUnknown", tone: .danger) }
            return
        }
        guard store.hold(key, target: seat) else { show("parityB.lead.storageFailed", tone: .danger); return }
        switch LeadTicketScanOutcome.classify(await service.scanGroupMemberTicket(code: code, activityID: activityID), seat: seat) {
        case .verified(let text): store.clear(key); show("parityB.lead.verified", server: text, tone: .success)
        case .failed(let text): store.clear(key); show("parityB.lead.notSubmitted", server: text, tone: .danger)
        case .review(let text): show("parityB.lead.review", server: text, tone: .danger)
        case .unknown, .blocked: show("parityB.lead.seatUnknown", tone: .danger)
        }
    }
}

// MARK: editor: orienteering alternatives (fabu theme-runtime-structure 找不到时换个方式)

@MainActor struct OrientAlternativeEditorSection: View {
    @Environment(\.playerGapService) private var service
    let topicID: Int
    let taskID: Int
    @State private var rows: [OrientAlternativeRow]?
    @State private var dirty: Set<OrientAlternativeType> = []
    @State private var saving = false
    @State private var issue: LocalizedStringKey?
    @State private var serverIssue: String?
    @State private var saved = false

    var body: some View {
        if service != nil {
            Section {
                if let rows {
                    ForEach(rows.indices, id: \.self) { index in row(index, rows[index]) }
                    if let serverIssue { Text(verbatim: serverIssue).cyText(.meta).foregroundStyle(CYColor.dangerText) }
                    else if let issue { Text(issue).cyText(.meta).foregroundStyle(CYColor.dangerText) }
                    if saved && dirty.isEmpty { Text("parityB.alt.saved").cyText(.meta).foregroundStyle(CYColor.successText) }
                    CYPillButton("parityB.alt.save", style: .secondary) { Task { await save() } }
                        .disabled(saving || dirty.isEmpty).listRowBackground(Color.clear)
                        .accessibilityIdentifier("parityB.alt.save")
                } else if let issue {
                    Text(issue).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    Button("parityB.alt.reload") { Task { await load() } }
                } else { ProgressView() }
            } header: { Text("parityB.alt.title") } footer: { Text("parityB.alt.footer") }
            .task(id: "\(topicID):\(taskID)") { await load() }
        }
    }

    @ViewBuilder private func row(_ index: Int, _ value: OrientAlternativeRow) -> some View {
        Toggle(isOn: binding(index, \.on)) { Text(LocalizedStringKey("parityB.alt.type." + value.type.rawValue)) }
            .disabled(saving).accessibilityIdentifier("parityB.alt.\(value.type.rawValue)")
        if value.on && value.type != .scan {
            TextField(LocalizedStringKey(value.type == .quiz ? "parityB.alt.question" : "parityB.alt.photoPrompt"), text: binding(index, \.prompt), axis: .vertical)
                .disabled(saving)
        }
        if value.on && value.type == .quiz {
            TextField(LocalizedStringKey(value.answerConfigured ? "parityB.alt.answerKept" : "parityB.alt.answer"), text: binding(index, \.answer))
                .disabled(saving)
        }
        if value.on && value.type == .scan && !value.answerConfigured {
            Text("parityB.alt.scanMissing").cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
    }

    private func binding(_ index: Int, _ path: WritableKeyPath<OrientAlternativeRow, Bool>) -> Binding<Bool> {
        Binding(get: { rows.flatMap { $0.indices.contains(index) ? $0[index][keyPath: path] : nil } ?? false },
                set: { update(index, path, $0) })
    }
    private func binding(_ index: Int, _ path: WritableKeyPath<OrientAlternativeRow, String>) -> Binding<String> {
        Binding(get: { rows.flatMap { $0.indices.contains(index) ? $0[index][keyPath: path] : nil } ?? "" },
                set: { update(index, path, $0) })
    }
    private func update<T>(_ index: Int, _ path: WritableKeyPath<OrientAlternativeRow, T>, _ value: T) {
        guard !saving, var current = rows, current.indices.contains(index) else { return }
        current[index][keyPath: path] = value; rows = current
        dirty.insert(current[index].type); issue = nil; serverIssue = nil; saved = false
    }

    private func load() async {
        guard let service else { return }
        rows = nil; issue = nil; dirty = []
        if let drafts = await service.orientAlternatives(topicID: topicID, taskID: taskID) { rows = OrientAlternativeRow.rows(drafts) }
        else { issue = "parityB.alt.unread" }
    }

    /// `_saveStructureAlts`: only the changed rows, one at a time; the first failure stops with the server's text;
    /// the inputs stay until the author readback shows every written row.
    private func save() async {
        guard let service, let current = rows, !saving else { return }
        let changed = current.filter { dirty.contains($0.type) }
        guard !changed.isEmpty else { return }
        switch OrientAlternativeRow.issue(changed) {
        case .quizNeedsPromptAndAnswer?: issue = "parityB.alt.quizMissing"; return
        case .photoNeedsPrompt?: issue = "parityB.alt.photoMissing"; return
        case .scanNotConfigured?: issue = "parityB.alt.scanMissing"; return
        case nil: break
        }
        saving = true
        defer { saving = false }
        for row in changed {
            let reply = await service.saveOrientAlternative(topicID: topicID, taskID: taskID, row: row)
            guard case .ok = reply else { serverIssue = reply.message; issue = "parityB.alt.saveFailed"; return }
        }
        guard let back = await service.orientAlternatives(topicID: topicID, taskID: taskID) else { issue = "parityB.alt.readbackUnconfirmed"; return }
        guard OrientAlternativeRow.confirms(back, dirty: changed) else { issue = "parityB.alt.readbackMismatch"; return }
        rows = OrientAlternativeRow.rows(back); dirty = []; saved = true
    }
}

// MARK: circle theme host (project-host 30天供给复核 + 选择供给角色)

@MainActor struct CircleThemeHostSection: View {
    @Environment(\.playerGapService) private var service
    let topicID: Int
    @State private var topic: CircleThemeHostTopic?
    @State private var picking = false
    @State private var probed = false

    var body: some View {
        Group {
            if service == nil {
                EmptyView()
            } else if !probed {
                ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity)
            } else if let topic {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("parityB.circle.review").cyText(.cardTitle)
                    if let day = topic.reviewedOn { Text("parityB.circle.reviewedOn \(day)").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    else { Text("parityB.circle.notReviewed").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    Text("parityB.circle.reviewHint").cyText(.caption).foregroundStyle(CYColor.textSecondary)
                    CYPillButton("parityB.circle.pick", style: .secondary) { picking = true }
                        .accessibilityIdentifier("parityB.circle.pick")
                }
                .cySheet(isPresented: $picking) { Group {
                    CircleThemeConfigureSheet(topicID: topicID, themeCode: topic.themeCode) { await reload() }
                }.cySheet(detents: [.large]) }
            }
        }
        .task(id: topicID) { await reload() }
    }

    private func reload() async { topic = await service?.circleHostTopic(topicID: topicID); probed = true }
}

@MainActor struct CircleThemeConfigureSheet: View {
    @Environment(\.playerGapService) private var service
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let topicID: Int
    let themeCode: String
    let reload: () async -> Void
    /// Opens empty every time: there is no read of the current selection, so nothing is pre-selected.
    @State private var picked: [String] = []
    @State private var hint: Text?
    @State private var errorTitle: LocalizedStringKey?
    @State private var errorText: String?
    @State private var submitting = false

    var body: some View {
        NavigationStack {
            List {
                Section { Text("parityB.circle.subtitle").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                if let candidates = CircleThemeCatalog.theme(themeCode) {
                    Section {
                        ForEach(candidates) { candidate in
                            Button { toggle(candidate.code) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                        Text(verbatim: candidate.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                        (Text(LocalizedStringKey("parityB.circle.role." + candidate.role.rawValue)) + Text(verbatim: " · " + candidate.merchant))
                                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    }
                                    Spacer()
                                    CYStatusChip(picked.contains(candidate.code) ? "parityB.circle.picked" : "parityB.circle.unpicked",
                                                 tone: picked.contains(candidate.code) ? .success : .neutral)
                                }
                            }
                            .disabled(submitting)
                            .accessibilityAddTraits(picked.contains(candidate.code) ? .isSelected : [])
                            .accessibilityIdentifier("parityB.circle.candidate.\(candidate.code)")
                        }
                    }
                } else { Text("parityB.circle.unsupported").foregroundStyle(CYColor.textSecondary) }
                if let hint { hint.cyText(.meta).foregroundStyle(CYColor.dangerText) }
                if let errorTitle {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(errorTitle).cyText(.label).foregroundStyle(CYColor.dangerText)
                        if let errorText { Text(verbatim: errorText).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    }
                }
            }
            .appNavigationTitle("parityB.circle.pick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() }.disabled(submitting) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("parityB.circle.save") { Task { await submit() } }
                        .disabled(submitting || picked.isEmpty).accessibilityIdentifier("parityB.circle.save")
                }
            }
            .interactiveDismissDisabled(submitting)
        }
    }

    private func toggle(_ code: String) {
        guard !submitting else { return }
        if let index = picked.firstIndex(of: code) { picked.remove(at: index) } else { picked.append(code) }
        hint = nil
    }

    private func submit() async {
        guard let service, !submitting, !picked.isEmpty else { return }
        switch CircleThemeCatalog.validate(themeCode: themeCode, codes: picked) {
        case .unknownTheme?: hint = Text("parityB.circle.unsupported"); return
        case .count?: hint = Text("parityB.circle.count"); return
        case .foreign?: hint = Text("parityB.circle.foreign"); return
        case .missing(let roles)?:
            let names = roles.map { appLocalized(String.LocalizationValue(stringLiteral: "parityB.circle.role." + $0.rawValue), locale: locale) }
            hint = Text("parityB.circle.missing \(LocaleDisplay.list(names, locale: locale))"); return
        case nil: break
        }
        submitting = true; errorTitle = nil; errorText = nil
        let reply = await service.configureCircleInstance(topicID: topicID, candidateCodes: picked)
        submitting = false
        switch reply {
        case .ok:
            await reload(); dismiss()
        case .unknown:
            // Offline: the server may have saved. Neither success nor failure; the reread review line speaks.
            errorTitle = "parityB.circle.unconfirmed"; errorText = appLocalized("parityB.circle.reloaded", locale: locale)
            await reload()
        case .refused, .unauthorized:
            errorTitle = "parityB.circle.notSaved"
            errorText = reply.message ?? appLocalized("parityB.circle.saveFailed", locale: locale)
        }
    }
}
