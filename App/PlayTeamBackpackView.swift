import SwiftUI

/// TEAM theme backpack on a ROUTE team run (`theme-backpack.wxml` with `themeBag.scope === 'TEAM'`).
/// Read from `GET api/game/session/view` (PLAYER perspective) through the G1 production binding.
/// It offers the two non-command player calls the mini-program makes from this sheet: the shared help
/// sheet on a QUEST row (`POST api/play/help/shared`) and the trade preview (`POST api/game/session/shared/preview`).
/// Item use/discard/receive, quest actions and trade open/confirm/cancel are TEAM commands
/// (`api/game/session/command`), which the player grant does not carry, so no button for them is drawn.
@MainActor struct PlayTeamBackpackSections: View {
    @Environment(\.playRuntimeGap) private var runtimeGap
    @Environment(\.scenePhase) private var scenePhase
    /// True while a TEAM snapshot is shown, so the host hides its personal projection (`scope === 'TEAM'` wins).
    @Binding var active: Bool
    @State private var read: PlayTeamBackpackRead = .hidden
    @State private var help: PlayCoopHelpFlow?
    @State private var tradeForm: PlayThemeTradeForm?

    var body: some View {
        Group {
            switch read {
            case .hidden: EmptyView()
            case .failed(let message):
                // mp-states r3 (MP pages/play/theme-backpack.wxml:16 cy-inline-error title + retry): one failure state, retry inside.
                Section {
                    PlayTeamBackpackFailure(message: message, retry: retry)
                }.accessibilityIdentifier("playTeam.failed")
            case .loaded(let snapshot):
                content(snapshot)
            }
        }
        .task(id: runtimeGap?.activityID) { await reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reload() } } }
        .cySheet(item: Binding(get: { help.map(HelpSheetID.init) }, set: { if $0 == nil { closeHelp() } })) { _ in
            if let help {
                PlayCoopHelpSheet(flow: help) { closeHelp() }
                    .cyDomainSheet(detents: [.half, .full])
            }
        }
        .cySheet(item: Binding(get: { tradeForm.map { TradeSheetID(key: $0.tradeKey) } }, set: { if $0 == nil { tradeForm = nil } })) { _ in
            if case .loaded(let snapshot) = read, let form = tradeForm {
                PlayTeamTradePreviewSheet(form: form, snapshot: snapshot, client: { runtimeGap?.client() },
                                          reload: { await reload(); if case .loaded(let next) = read { return next }; return nil })
                    .cyDomainSheet(detents: [.half, .full])
            }
        }
    }

    private struct HelpSheetID: Identifiable { let id: String; init(_ flow: PlayCoopHelpFlow) { id = flow.questKey } }
    private struct TradeSheetID: Identifiable { let key: String; var id: String { key } }

    private func retry() {
        Task { await reload() }
    }

    private func reload() async {
        guard let gap = runtimeGap, let activityID = gap.activityID, let client = gap.client() else { read = .hidden; active = false; return }
        let next = await PlayTeamBackpackRead.read(client: client, activityID: activityID)
        read = next
        if case .loaded = next { active = true } else { active = false }
    }

    private func closeHelp() {
        guard let flow = help, flow.busyLevel == nil, !flow.isBusy else { return }
        let refresh = flow.finished
        help = nil
        if refresh { Task { await reload() } }
    }

    @ViewBuilder private func content(_ snapshot: PlayTeamBackpackSnapshot) -> some View {
        let bag = snapshot.backpack
        Section {
            LabeledContent { Text("playx.backpack.slots \(bag.used) \(bag.capacity)").cyText(.numericBody) } label: { Text("playTeam.load") }
            ForEach(bag.values, id: \.key) { row in
                LabeledContent {
                    Text(verbatim: row.max.map { "\(row.value) / \($0)" } ?? row.value).cyText(.numericBody)
                        .accessibilityLabel(row.max.map { Text("a11y.value.ofTotalText \(row.value) \($0)") } ?? Text(verbatim: row.value))
                } label: {
                    HStack { valueName(row.name); if row.zero { Text("playx.backpack.zero").foregroundStyle(CYColor.dangerText) } }
                }
            }
            if bag.claimOnly { Text("playx.backpack.claimOnly").cyText(.bodyCompact) }
        } header: { Text("playTeam.title") }
        .accessibilityIdentifier("playTeam.summary")
        if !bag.pending.isEmpty {
            Section("playx.backpack.pending") {
                ForEach(bag.pending) { row in
                    VStack(alignment: .leading) {
                        if let n = row.name { Text(verbatim: n) } else { Text("playx.backpack.pendingReward") }
                        HStack(spacing: 4) {
                            if let q = row.quantity { Text(verbatim: "×\(q)") }
                            if let slots = row.slots { Text("playx.backpack.takesSlots \(slots)") }
                        }.cyText(.meta)
                    }
                }
            }
        }
        if !bag.items.isEmpty {
            Section("playx.backpack.carried") {
                ForEach(bag.items) { item in
                    HStack {
                        valueName(item.name)
                        Spacer()
                        if let q = item.quantity { Text(verbatim: "×\(q)").cyText(.numericBody) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        let quests = snapshot.helpQuests
        if !quests.isEmpty {
            Section("playTeam.quests") {
                ForEach(quests) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: row.title)
                            if !row.statusText.isEmpty { Text(verbatim: row.statusText).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                        }
                        Spacer()
                        Button("playTeam.hint") { openHelp(snapshot, questKey: row.contentId) }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                            .disabled(help != nil)
                            .accessibilityLabel(Text("playTeam.hint.a11y \(row.title)"))
                            .accessibilityIdentifier("playTeam.hint.\(row.contentId)")
                    }
                }
            }
        }
        tradeSection(snapshot)
        if !bag.clues.isEmpty {
            Section("playx.backpack.tab.clues") {
                ForEach(bag.clues) { clue in
                    VStack(alignment: .leading, spacing: 4) {
                        if let n = clue.name { Text(verbatim: n).cyText(.cardTitle) } else { Text("playx.backpack.clue").cyText(.cardTitle) }
                        switch clue.scope {
                        case .publicAll: Text("playx.backpack.scope.public").cyText(.meta)
                        case .team: Text("playx.backpack.scope.team").cyText(.meta)
                        case .none: EmptyView()
                        }
                        if let content = clue.content { Text(verbatim: content).textSelection(.enabled) }
                        ForEach(Array(clue.blocks.enumerated()), id: \.offset) { _, block in
                            if let source = block.source { Text(verbatim: source).cyText(.meta).foregroundStyle(.secondary) }
                            if let text = block.text { Text(verbatim: text).textSelection(.enabled) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func tradeSection(_ snapshot: PlayTeamBackpackSnapshot) -> some View {
        let trade = snapshot.trade
        if !trade.tradeTargets.isEmpty || !trade.tradeRows.isEmpty {
            Section("playTeam.trade") {
                LabeledContent("playTeam.trade.locked") { Text(verbatim: trade.tradeLockedText) }
                ForEach(trade.tradeTargets) { target in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("playTeam.trade.team \(target.teamId)")
                            if target.completed { Text("playTeam.trade.completed").cyText(.meta) }
                            if !target.stationName.isEmpty { Text("playTeam.trade.station \(target.stationName)").cyText(.meta) }
                            if !target.reason.isEmpty { Text(verbatim: target.reason).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                        }
                        Spacer()
                        Button("playTeam.trade.select") { tradeForm = PlayTeamTradePreview.form(target: target, snapshot: snapshot) }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                            .disabled(!target.enabled)
                            .accessibilityIdentifier("playTeam.trade.select.\(target.teamId)")
                    }
                }
                ForEach(trade.tradeRows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.statusText).font(.subheadline)
                        if !row.stationName.isEmpty { Text("playTeam.trade.station \(row.stationName)").cyText(.meta) }
                        LabeledContent("playTeam.trade.give") { Text(verbatim: row.giveText) }.cyText(.meta)
                        LabeledContent("playTeam.trade.take") { Text(verbatim: row.takeText) }.cyText(.meta)
                        if row.confirmed && row.status == "OPEN" { Text("playTeam.trade.confirmedWaiting").cyText(.meta) }
                    }
                }
            }
        }
    }

    private func openHelp(_ snapshot: PlayTeamBackpackSnapshot, questKey: String) {
        guard help == nil else { return }
        let flow = PlayCoopHelpFlow(activityID: snapshot.activityID, cooperation: snapshot.cooperation, questKey: questKey,
                                    client: { [runtimeGap] in runtimeGap?.client() })
        help = flow
        Task { await flow.open() }
    }

    private func valueName(_ value: PlayThemeBackpack.ValueName) -> Text {
        switch value {
        case .server(let text): return Text(verbatim: text)
        case .hp: return Text("playx.themeRecords.hp")
        case .luck: return Text("playx.themeRecords.luck")
        case .actions: return Text("playx.themeRecords.actions")
        case .genericNumber: return Text("playx.backpack.genericNumber")
        case .genericSupply: return Text("playx.backpack.genericSupply")
        }
    }
}

/// `coop-help` popup: free/cost/off rows, the unlocked content, and SKIP behind a confirm.
@MainActor struct PlayCoopHelpSheet: View {
    let flow: PlayCoopHelpFlow
    let close: () -> Void
    @Environment(\.offlineWriteSession) private var offlineWriteSession

    var body: some View {
        NavigationStack {
            List {
                if !flow.freeText.isEmpty { Text(verbatim: flow.freeText).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                ForEach(flow.rows) { row in
                    HStack {
                        Text(verbatim: row.title)
                        Spacer()
                        Button {
                            Task {
                                await SessionOfflineSyncModel.shared.performWriteOptIn(
                                    environmentSession: offlineWriteSession.session,
                                    routes: ["/api/play/help/shared"]
                                ) {
                                    await flow.use(level: row.level)
                                }
                            }
                        } label: {
                            CYBusyLabel(busy: flow.busyLevel == row.level) { Text(verbatim: row.actionText) }
                        }
                        .buttonStyle(CYPillButtonStyle(style: row.state == .unlocked ? .tertiary : .secondary, fullWidth: false, compact: true))
                        .disabled(row.state == .off || flow.busyLevel != nil)
                        .accessibilityIdentifier("playTeam.help.level.\(row.level)")
                    }
                }
                if !flow.content.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: flow.content).textSelection(.enabled)
                        if let points = flow.chargedPoints { Text("playTeam.help.charged \(points)").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    }.accessibilityIdentifier("playTeam.help.content")
                }
                if let skip = flow.skip {
                    HStack {
                        if skip.usable { Text("playTeam.help.skip") } else { Text(verbatim: skip.reason).foregroundStyle(CYColor.textTertiary) }
                        Spacer()
                        if skip.usable && !flow.skipConfirm {
                            Button("playTeam.help.skipButton") { flow.askSkip() }.buttonStyle(CYPillButtonStyle(style: .tertiary, fullWidth: false, compact: true))
                        }
                    }
                }
                if flow.skipConfirm {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("playTeam.help.skipConsequence")
                        HStack {
                            Button("playTeam.help.skipCancel") { flow.cancelSkip() }.buttonStyle(CYPillButtonStyle(style: .tertiary, fullWidth: false, compact: true))
                            Button("playTeam.help.skipConfirm", role: .destructive) {
                                Task {
                                    await SessionOfflineSyncModel.shared.performWriteOptIn(
                                        environmentSession: offlineWriteSession.session,
                                        routes: ["/api/play/help/shared"]
                                    ) {
                                        await flow.confirmSkip()
                                    }
                                }
                            }
                                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                                .disabled(flow.busyLevel != nil)
                        }
                    }
                }
                CYScreenOfflineWriteSection(
                    routes: ["/api/play/help/shared"],
                    session: offlineWriteSession.session
                )
                if let issue = flow.issue { issueText(issue) }
                if flow.loading { ProgressView("playTeam.help.loading") }
            }
            .navigationTitle(Text("playTeam.hint"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("playTeam.close") { close() }.disabled(flow.busyLevel != nil) } }
        }
        .cySheet()
        .interactiveDismissDisabled(flow.busyLevel != nil)
        .onChange(of: flow.finished) { _, done in if done { close() } }
    }

    @ViewBuilder private func issueText(_ issue: PlayCoopHelpFlow.Issue) -> some View {
        Group {
            switch issue {
            case .stale: Text("playTeam.help.stale")
            case .viewUnknown:
                if let message = flow.serverMessage, !message.isEmpty { Text(verbatim: message) }
                Text("playTeam.help.viewUnknown")
            case .writeUnknown:
                if let message = flow.serverMessage, !message.isEmpty { Text(verbatim: message) }
                Text("playTeam.help.writeUnknown")
            case .rejected(let message): Text(verbatim: message)
            }
        }
        .foregroundStyle(issue == .writeUnknown ? CYColor.warningText : CYColor.dangerText)
        .accessibilityIdentifier("playTeam.help.issue")
    }
}

/// `themeTradeForm` sheet: quantities, then the server preview of stock and load. Opening the trade is a
/// TEAM command the player grant does not carry, so the sheet ends at the preview.
@MainActor struct PlayTeamTradePreviewSheet: View {
    @State var form: PlayThemeTradeForm
    let snapshot: PlayTeamBackpackSnapshot
    let client: () -> PlayRuntimeClient?
    let reload: () async -> PlayTeamBackpackSnapshot?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var preview: PlayTeamTradePreview?
    @State private var error: String?
    @State private var busy = false

    init(form: PlayThemeTradeForm, snapshot: PlayTeamBackpackSnapshot, client: @escaping () -> PlayRuntimeClient?,
         reload: @escaping () async -> PlayTeamBackpackSnapshot?) {
        _form = State(initialValue: form); self.snapshot = snapshot; self.client = client; self.reload = reload
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("playTeam.trade.with \(form.toTeamId)").cyText(.cardTitle)
                    Text("playTeam.trade.hint").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }
                ForEach($form.items) { $item in
                    Section(item.name) {
                        LabeledContent("playTeam.trade.give") {
                            TextField("0", text: $item.give).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        }
                        LabeledContent("playTeam.trade.take") {
                            TextField("0", text: $item.take).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        }
                    }
                    .onChange(of: item) { _, _ in preview = nil; error = nil }
                    .disabled(busy)
                }
                if let preview {
                    Section("playTeam.trade.preview") {
                        LabeledContent("playTeam.trade.give") { Text(verbatim: preview.giveText) }
                        LabeledContent("playTeam.trade.take") { Text(verbatim: preview.takeText) }
                        LabeledContent("playTeam.trade.ourLoad") { Text(verbatim: "\(preview.fromUsed) / \(preview.capacity)").monospacedDigit() }
                        LabeledContent("playTeam.trade.theirLoad") { Text(verbatim: "\(preview.toUsed) / \(preview.capacity)").monospacedDigit() }
                    }.accessibilityIdentifier("playTeam.trade.previewResult")
                }
                if let error { Text(verbatim: error).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("playTeam.trade.error") }
                Section {
                    Button { Task { await runPreview() } } label: {
                        CYBusyLabel(busy: busy) { Text("playTeam.trade.previewButton") }
                    }
                    .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: true))
                    .disabled(busy)
                    .accessibilityIdentifier("playTeam.trade.previewButton")
                }
            }
            .navigationTitle(Text("playTeam.trade.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("playTeam.close") { dismiss() }.disabled(busy) } }
        }
        .interactiveDismissDisabled(busy)
    }

    private func runPreview() async {
        guard !busy else { return }
        let payload: PlayThemeTradePayload
        do { payload = try PlayThemeTradeRules.payload(form) } catch { self.error = error.localizedDescription; return }
        guard let client = client() else { error = appLocalized("playTeam.trade.unconfirmed", locale: locale); return }
        busy = true; error = nil; preview = nil
        defer { busy = false }
        var basis = snapshot
        for attempt in 0..<2 {
            switch await PlayTeamTradePreview.read(client: client, snapshot: basis, payload: payload) {
            case .ready(let value): preview = value; return
            case .unconfirmed(let message): error = message ?? appLocalized("playTeam.trade.unconfirmed", locale: locale); return
            case .stale:
                // The backpack is re-read once; a preview still ahead of it is not shown.
                guard attempt == 0, let next = await reload() else { error = appLocalized("playTeam.trade.stale", locale: locale); return }
                basis = next
            }
        }
        error = appLocalized("playTeam.trade.stale", locale: locale)
    }
}

/// TEAM backpack commands. Personal `PlayThemeBackpackView` stays on `api/play/theme/action`.
/// Unknown command results render an em dash and are not a success.
@available(macOS 14.0, *)
@MainActor struct PlayTeamBackpackView: View {
    @Bindable var model: PlayTeamBackpackCoordinator
    var body: some View {
        List {
            stateRows
            if model.phase == .ready || (model.phase == .failed && !model.items.isEmpty) { itemRows }
            if (model.phase == .ready || model.phase == .failed), !model.pending.isEmpty { pendingRows }
            if model.receipt.kind != .blank { receiptRows }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .appNavigationTitle("play.teamBackpack.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.reload() }
        .accessibilityIdentifier("play.teamBackpack")
    }

    @ViewBuilder private var stateRows: some View {
        switch model.phase {
        case .loading:
            CYLoadingStateView(rows: 2)
                .frame(minHeight: CurA11y.hit, alignment: .leading)
                .accessibilityLabel(Text("play.teamBackpack.loading"))
                .accessibilityHint(Text("curA11y.playTeam.retry.hint", tableName: "CurA11y"))
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("play.teamBackpack.loading")
        case .empty:
            CurA11yNotice(
                text: Text("play.teamBackpack.empty"),
                hint: Text("curA11y.playTeam.item.hint", tableName: "CurA11y"),
                identifier: "play.teamBackpack.empty",
                heading: true
            )
        case .failed:
            CurA11yNotice(
                text: Text("play.teamBackpack.failed"),
                hint: Text("curA11y.fixture.failed.hint", tableName: "CurA11y"),
                identifier: "play.teamBackpack.failed",
                heading: true,
                tone: CYColor.dangerText
            )
            CurA11yTextButton(
                title: Text("play.teamBackpack.retry"),
                hint: Text("curA11y.playTeam.retry.hint", tableName: "CurA11y"),
                identifier: "play.teamBackpack.retry",
                action: { Task { await model.reload() } }
            )
        case .ready:
            EmptyView()
        }
    }

    @ViewBuilder private var itemRows: some View {
        Section {
            ForEach(model.items) { item in
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    itemTitle(item.name, quantity: item.quantity)
                    CurA11yActions {
                        if model.canUse {
                            commandButton("play.teamBackpack.use", hint: Text("curA11y.playTeam.use.hint", tableName: "CurA11y"), enabled: item.usable, id: "play.teamBackpack.use." + item.id) {
                                Task { await model.use(item.id) }
                            }
                        }
                        if model.canDiscard {
                            commandButton("play.teamBackpack.discard", hint: Text("curA11y.playTeam.discard.hint", tableName: "CurA11y"), enabled: item.discardable, id: "play.teamBackpack.discard." + item.id) {
                                Task { await model.discard(item.id) }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("play.teamBackpack.item." + item.id)
            }
        } header: {
            Text("play.teamBackpack.items")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder private var pendingRows: some View {
        Section {
            ForEach(model.pending) { item in
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    itemTitle(item.name, quantity: item.quantity)
                    if model.canReceive {
                        commandButton("play.teamBackpack.receive", hint: Text("curA11y.playTeam.receive.hint", tableName: "CurA11y"), enabled: true, id: "play.teamBackpack.receive." + item.id) {
                            Task { await model.receive(item.id) }
                        }
                    }
                }
                .accessibilityIdentifier("play.teamBackpack.pending." + item.id)
            }
        } header: {
            Text("play.teamBackpack.pending")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder private var receiptRows: some View {
        Section {
            receiptLabel
            receiptLine("play.teamBackpack.outcome", model.receipt.outcome)
            receiptLine("play.teamBackpack.receiptID", model.receipt.receiptID)
            receiptLine("play.teamBackpack.revision", model.receipt.revision)
            if let message = model.receipt.serverMessage, !message.isEmpty {
                CurA11yDashText(shown: message, font: CYTypography.meta, color: CYColor.textSecondary)
                    .accessibilityHint(Text("curA11y.playTeam.receipt.hint", tableName: "CurA11y"))
            }
        } header: {
            Text("play.teamBackpack.receipt")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .accessibilityIdentifier("play.teamBackpack.receipt")
    }

    @ViewBuilder private var receiptLabel: some View {
        switch model.receipt.kind {
        case .applied:
            outcome("play.teamBackpack.applied", "play.teamBackpack.applied")
        case .failed:
            outcome("play.teamBackpack.failedOutcome", "play.teamBackpack.failedOutcome")
        case .business:
            outcome("play.teamBackpack.failedOutcome", "play.teamBackpack.failedOutcome")
                .accessibilityIdentifier("play.teamBackpack.business")
        case .unknown:
            outcome("play.teamBackpack.unknown", "play.teamBackpack.unknown")
        case .refused:
            outcome("play.teamBackpack.refused", "play.teamBackpack.refused")
        case .blank:
            EmptyView()
        }
    }

    private func outcome(_ key: LocalizedStringKey, _ identifier: String) -> some View {
        Text(key)
            .cyText(.body)
            .foregroundStyle(CYColor.textPrimary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: CurA11y.hit, alignment: .leading)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier(identifier)
    }

    private func itemTitle(_ name: String?, quantity: Int?) -> some View {
        let title = name ?? PlayTeamCommandInterpretation.dash
        let count = quantity.map(String.init) ?? PlayTeamCommandInterpretation.dash
        return CurA11yPair(
            leading: CurA11yDashText(shown: title, color: CYColor.textPrimary),
            trailing: CurA11yDashText(shown: count, color: CYColor.textSecondary)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("curA11y.playTeam.item.hint", tableName: "CurA11y"))
        .accessibilityAddTraits(.isStaticText)
    }

    private func receiptLine(_ title: LocalizedStringKey, _ shown: String) -> some View {
        CurA11yPair(
            leading: Text(title)
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true),
            trailing: CurA11yDashText(shown: shown, color: CYColor.textSecondary)
        )
        .frame(minHeight: CurA11y.hit, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("curA11y.playTeam.receipt.hint", tableName: "CurA11y"))
        .accessibilityAddTraits(.isStaticText)
    }

    private func commandButton(_ title: LocalizedStringKey, hint: Text, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        CurA11yTextButton(title: Text(title), hint: hint, identifier: id, expands: false, action: action)
            .disabled(!enabled || model.busy)
    }
}

/// Team backpack read failure: 本局状态暂未同步 with the server sentence as the description when sent
/// (MP `cy-inline-error title="{{themeBagError}}"`), 重试 inside the one state.
@MainActor private struct PlayTeamBackpackFailure: View {
    let message: String?
    let retry: () -> Void
    var body: some View {
        CYEmptyState(systemImage: "exclamationmark.triangle", "playTeam.failed", detailVerbatim: detail,
                     actionTitle: "playx.backpack.retry", actionIdentifier: "playTeam.retry", kind: .failure, action: retry)
    }

    private var detail: String? {
        guard let message, !message.isEmpty else { return nil }
        return message
    }
}
