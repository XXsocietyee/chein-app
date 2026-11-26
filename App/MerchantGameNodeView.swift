import SwiftUI

/// Copy lives in its own table; Core returns catalog keys or already-safe server text.
enum MerchantGameNodeCopy {
    static let table = "MerchantGameNode"
    static func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    static func string(_ key: String) -> String { String(localized: String.LocalizationValue(key), table: table) }
    static func text(_ message: MerchantGameNodeMessage) -> Text {
        switch message { case .key(let key): return text(key); case .server(let value): return Text(verbatim: value) }
    }
    static func format(_ key: String, _ arguments: CVarArg...) -> String { String(format: string(key), arguments: arguments) }
}

@MainActor final class MerchantGameNodeViewModel: ObservableObject {
    @Published private(set) var revision = 0
    let coordinator: MerchantGameNodeCoordinator
    init(service: any MerchantGameNodeServing, activityID: Int?, nodeID: Int?, focusPause: Bool) {
        coordinator = .init(service: service, activityID: activityID, requestedNodeID: nodeID, focusPause: focusPause)
        coordinator.onChange = { [weak self] in self?.revision &+= 1 }
    }
}

/// Native counterpart of pages/merchant/game-node (本站准备与运行).
@MainActor struct MerchantGameNodeView: View {
    @StateObject private var model: MerchantGameNodeViewModel
    @Environment(\.scenePhase) private var scenePhase
    /// MC7-26-4: MP `readyErrors` appear after 确认准备完成 is tapped and clear as each field is fixed.
    @State private var readyAttempted = false
    @State private var showsServiceTime = false
    @StateObject private var submissionImport = MerchantGameNodeImportController()
    init(service: any MerchantGameNodeServing, activityID: Int?, nodeID: Int? = nil, focusPause: Bool = false) {
        _model = StateObject(wrappedValue: .init(service: service, activityID: activityID, nodeID: nodeID, focusPause: focusPause))
    }
    private var c: MerchantGameNodeCoordinator { model.coordinator }
    private var writeBlocked: Bool { c.writeState != .idle || !c.permitsWrites }

    var body: some View {
        let importID = submissionImport.session?.id
        page
        .cySheet(isPresented: Binding(get: { c.sheet != nil }, set: { if !$0 { c.closeSheet() } })) {
            sheetContent
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.merchant)
        }
        .cySheet(isPresented: $showsServiceTime) {
            MerchantGameNodeServiceTimeSheet(model: model)
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.merchant)
        }
        .cySheet(isPresented: submissionImport.presentationBinding(), onDismiss: {
            if let identifier = submissionImport.finishDismissal(id: importID), scenePhase == .active {
                c.openVerify(submissionID: identifier)
            }
        }) {
            if let session = submissionImport.session {
                MerchantGameNodeScanImportSheet(session: session,
                    cancel: { submissionImport.cancel(session) },
                    apply: { submissionImport.accept(session) })
                    .cyDomainSheet(detents: [.half, .full])
                    .themeDomain(.merchant)
            }
        }
        .cyModalConfirm(
            isPresented: c.confirmation != nil,
            title: MerchantGameNodeCopy.string(confirmTitleKey),
            message: c.confirmation.map { MerchantGameNodeCopy.string(confirmMessageKey($0)) } ?? "",
            cancelTitle: MerchantGameNodeCopy.string(c.confirmation?.action == .pause ? "merchantGameNode.pause.noFallbackCancel" : "merchantGameNode.cancel"),
            confirmTitle: c.confirmation.map { MerchantGameNodeCopy.string(confirmButtonKey($0)) } ?? MerchantGameNodeCopy.string("merchantGameNode.cancel"),
            isDestructive: c.confirmation?.action == .pause,
            confirmIdentifier: "gameNode.confirm",
            onCancel: { c.cancelConfirmation() },
            onConfirm: {
                if let command = c.confirmation {
                    Task { await c.confirm(command) }
                }
            }
        )
        .cyFullScreenCover(isPresented: Binding(get: { c.checkinVisible }, set: { if !$0 { c.closeCheckin() } })) {
            MerchantGameNodeCheckinView(model: model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { c.closeCheckin(); submissionImport.invalidate() }
        }
        .onChange(of: model.revision) { _, _ in submissionImport.invalidate() }
        .onDisappear { submissionImport.invalidate() }
        .cyToast(
            verbatimMessage: Binding(
                get: {
                    c.toast.map {
                        switch $0 {
                        case .key(let key): MerchantGameNodeCopy.string(key)
                        case .server(let value): value
                        }
                    }
                },
                set: { if $0 == nil { c.clearToast() } }
            ),
            tone: .info,
            duration: 2.0
        )
        .cyDomainScreen(.merchant)
    }
    private func openSubmissionImport() {
        let revision = model.revision, scope = c.service.scope
        let nodeID = c.station?.nodeID
        submissionImport.open { [weak model] in
            guard let model else { return false }
            let owner = model.coordinator
            return scenePhase == .active && model.revision == revision &&
                owner.service.scope == scope && owner.service.isAuthenticated && owner.permitsWrites &&
                owner.viewState == .ready && owner.station?.nodeID == nodeID &&
                owner.station?.canVerify == true && owner.writeState == .idle &&
                owner.sheet == nil && owner.confirmation == nil
        }
    }
    private var confirmationShown: Binding<Bool> {
        Binding(get: { c.confirmation != nil }, set: { if !$0 { c.dismissConfirmation() } })
    }
    @ViewBuilder private func confirmActions(_ command: MerchantGameNodeCommand) -> some View {
        let role: ButtonRole? = command.action == .pause ? .destructive : nil
        Button(role: role) { Task { await c.confirm(command) } } label: { MerchantGameNodeCopy.text(confirmButtonKey(command)) }
            .accessibilityIdentifier("gameNode.confirm")
        Button(role: .cancel) { c.cancelConfirmation() } label: {
            MerchantGameNodeCopy.text(command.action == .pause ? "merchantGameNode.pause.noFallbackCancel" : "merchantGameNode.cancel")
        }
    }
    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if c.writeState == .unknown { unknownBanner }
                switch c.viewState {
                case .loading: ProgressView().frame(maxWidth: .infinity, minHeight: 240).accessibilityIdentifier("gameNode.loading")
                case .empty:
                    stateView(icon: "tray", title: "merchantGameNode.empty.title", message: .key("merchantGameNode.empty.sub"), retry: false)
                        .accessibilityIdentifier("gameNode.empty")
                case .businessError(let message):
                    stateView(icon: "exclamationmark.circle", title: "merchantGameNode.error.title", message: message, retry: true)
                        .accessibilityIdentifier("gameNode.businessError")
                case .networkError(let message):
                    stateView(icon: "wifi.exclamationmark", title: "merchantGameNode.networkError.title", message: message, retry: true)
                        .accessibilityIdentifier("gameNode.networkError")
                case .ready: if let station = c.station { ready(station) }
                }
            }.padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(MerchantGameNodeCopy.string("merchantGameNode.title")).navigationBarTitleDisplayMode(.inline)
        .task { await c.start() }
        .refreshable { if c.writeState == .idle { await c.load() } }
    }

    // MARK: Confirmation copy
    private var confirmTitleKey: String {
        switch c.confirmation?.action {
        case .resume?: return "merchantGameNode.confirm.resumeTitle"
        case .pause?: return "merchantGameNode.pause.noFallbackTitle"
        default: return "merchantGameNode.confirm.acceptTitle"
        }
    }
    private func confirmButtonKey(_ command: MerchantGameNodeCommand) -> String {
        switch command.action {
        case .resume: return "merchantGameNode.pauseInfo.resume"
        case .pause: return "merchantGameNode.pause.submit"
        default: return "merchantGameNode.invite.accept"
        }
    }
    private func confirmMessageKey(_ command: MerchantGameNodeCommand) -> String {
        switch command.action {
        case .resume: return "merchantGameNode.confirm.resumeMessage"
        case .pause: return "merchantGameNode.pause.noFallbackMessage"
        default: return "merchantGameNode.confirm.acceptMessage"
        }
    }

    // MARK: States
    private var unknownBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            MerchantGameNodeCopy.text("merchantGameNode.unknown.title").cyText(.bodyMedium).foregroundStyle(CYColor.warningText)
            if let message = c.writeMessage { MerchantGameNodeCopy.text(message).cyText(.bodyCompact) }
            HStack {
                Button { Task { await c.confirmUnknownWrite() } } label: { MerchantGameNodeCopy.text("merchantGameNode.unknown.confirm") }
                    .buttonStyle(.bordered).accessibilityIdentifier("gameNode.unknown.confirm")
                if c.canRetryUnknownWrite {
                    Button { Task { await c.retryUnknownWrite() } } label: { MerchantGameNodeCopy.text("merchantGameNode.unknown.retry") }
                        .buttonStyle(.bordered).accessibilityIdentifier("gameNode.unknown.retry")
                }
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.warningText.opacity(0.12), in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .accessibilityElement(children: .contain).accessibilityIdentifier("gameNode.unknown")
    }
    private func stateView(icon: String, title: String, message: MerchantGameNodeMessage, retry: Bool) -> some View {
        ContentUnavailableView {
            if icon == "tray" {
                // Image parity: MP cy-empty kind="empty" → the shared MP empty art (MPAsset.EmptyState).
                VStack(spacing: CYSpacing.md) { CYEmptyIllustration(kind: .generic, size: 96); MerchantGameNodeCopy.text(title) }
            } else {
                Label { MerchantGameNodeCopy.text(title) } icon: { Image(systemName: icon) }
            }
        } description: {
            MerchantGameNodeCopy.text(message)
        } actions: {
            if retry {
                Button { Task { await c.load() } } label: { MerchantGameNodeCopy.text("merchantGameNode.retry") }
                    .buttonStyle(.bordered).frame(minHeight: CYSpacing.minTouchTarget).accessibilityIdentifier("gameNode.retry")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }
    @ViewBuilder private var toastView: some View {
        if let toast = c.toast {
            MerchantGameNodeCopy.text(toast).cyText(.bodyCompact).padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                .background(.regularMaterial, in: Capsule()).padding(.bottom, CYSpacing.xxl)
                .accessibilityIdentifier("gameNode.toast")
                .task(id: c.toast) { try? await Task.sleep(nanoseconds: 2_000_000_000); if c.toast == toast { c.clearToast() } }
        }
    }

    // MARK: Ready layout
    @ViewBuilder private func ready(_ station: MerchantGameNodeStation) -> some View {
        if let projection = c.projection, projection.stations.count > 1 {
            Picker(selection: Binding(get: { c.stationIndex }, set: { c.selectStation($0) })) {
                ForEach(Array(projection.stations.enumerated()), id: \.offset) { index, item in
                    Text(verbatim: item.nodeName.isEmpty ? MerchantGameNodeCopy.string("merchantGameNode.hero.untitled") : item.nodeName).tag(index)
                }
            } label: { MerchantGameNodeCopy.text("merchantGameNode.switchStation") }
                .pickerStyle(.menu).disabled(c.writeState != .idle).accessibilityIdentifier("gameNode.stationPicker")
        }
        hero(station)
        if c.writeState != .unknown, let message = c.writeMessage {
            MerchantGameNodeCopy.text(message).cyText(.bodyCompact).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("gameNode.inlineError")
        }
        if !c.permitsWrites {
            MerchantGameNodeCopy.text("merchantGameNode.writesDisabledNotice").cyText(.bodyCompact).foregroundStyle(.secondary)
                .accessibilityIdentifier("gameNode.writesDisabled")
        }
        // MC7-26-3: a playable station shows 本站运行 (出示打卡码 / 核验) before the runbook (game-node/index.wxml:56-65).
        if station.playable { runCard(station) }
        // MC7-26-5: ROUTE stations without a player task have no runbook card (index.wxml:67-69).
        if station.playerTask != nil || c.projection?.playMode != .route { runbook(station) }
        Group {
            // MC7-26-1 (until the endpoint review approves the chapter-node commands): with writes closed the one
            // notice above stands in for the invite / ready / pause / resume / verify actions; no disabled buttons.
            if c.permitsWrites, station.canAccept || station.canDecline { invitation(station) }
            if c.permitsWrites, station.canReady { readyCard(station) }
            if station.status == "PAUSED" { pauseInfo(station) }
            if c.permitsWrites, !station.playable && (station.canPause || station.canVerify) { runCard(station) }
        }
        receiptsCard
        recapCard(station)
    }
    private func card<Content: View>(_ title: String, _ subtitle: String, id: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                MerchantGameNodeCopy.text(title).cyText(.cardTitle)
                MerchantGameNodeCopy.text(subtitle).cyText(.meta).foregroundStyle(.secondary)
            }
            content()
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .contain).accessibilityIdentifier(id)
    }
    private func toneColor(_ tone: MerchantGameNodeSummary.Tone) -> Color {
        switch tone { case .ready: return CYColor.successText; case .paused: return CYColor.warningText; case .pending: return CYColor.infoText; case .muted: return CYColor.textSecondary; case .error: return CYColor.dangerText }
    }
    private var summaryText: String {
        let key = c.summary.textKey
        return key == "merchantGameNode.summary.playablePending"
            ? MerchantGameNodeCopy.format("merchantGameNode.summary.playablePending", Int64(c.summary.pendingVerificationCount))
            : MerchantGameNodeCopy.string(key)
    }
    private func hero(_ station: MerchantGameNodeStation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if station.stationCode.isEmpty { MerchantGameNodeCopy.text("merchantGameNode.hero.eyebrow").cyText(.meta).foregroundStyle(.secondary) }
                    else { Text(verbatim: station.stationCode).cyText(.meta).foregroundStyle(.secondary) }
                    if station.nodeName.isEmpty { MerchantGameNodeCopy.text("merchantGameNode.hero.untitled").cyText(.sheetTitle) }
                    else { Text(verbatim: station.nodeName).cyText(.sheetTitle) }
                }
                Spacer()
                MerchantGameNodeCopy.text(station.statusTextKey).cyText(.meta, weight: .semibold)
                    .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xs)
                    .foregroundStyle(toneColor(c.summary.tone)).background(toneColor(c.summary.tone).opacity(0.14), in: Capsule())
                    .accessibilityIdentifier("gameNode.status")
            }
            Text(verbatim: summaryText).font(.subheadline).accessibilityIdentifier("gameNode.summary")
            HStack {
                fact(Text(verbatim: station.capacity.map(String.init) ?? "—"), "merchantGameNode.fact.capacity")
                fact(Text(verbatim: String(station.pendingVerificationCount)), "merchantGameNode.fact.pending")
                fact(MerchantGameNodeCopy.text(station.playable ? "merchantGameNode.fact.playable" : "merchantGameNode.fact.notPlayable"), "merchantGameNode.fact.playerState")
            }
        }
        .padding(CYSpacing.lg).background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .contain).accessibilityIdentifier("gameNode.hero")
    }
    private func fact(_ value: Text, _ label: String) -> some View {
        VStack(spacing: CYSpacing.xxs) { value.cyText(.numericBody).monospacedDigit(); MerchantGameNodeCopy.text(label).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            .frame(maxWidth: .infinity)
    }
    private func runbook(_ station: MerchantGameNodeStation) -> some View {
        card("merchantGameNode.runbook.title", "merchantGameNode.runbook.sub", id: "gameNode.runbook") {
            if let task = station.playerTask {
                row("merchantGameNode.runbook.yours", station.merchantInstruction, fallback: "merchantGameNode.runbook.yoursDefault")
                row("merchantGameNode.runbook.players", task.prompt, fallback: "merchantGameNode.runbook.yoursDefault")
                row("merchantGameNode.runbook.guard", station.hiddenInfoReminder, fallback: "merchantGameNode.runbook.guardDefault")
                MerchantGameNodeCopy.text("merchantGameNode.runbook.why").cyText(.bodyCompact).foregroundStyle(.secondary)
            } else {
                MerchantGameNodeCopy.text("merchantGameNode.runbook.missing").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
        }
    }
    private func row(_ label: String, _ value: String, fallback: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            MerchantGameNodeCopy.text(label).cyText(.meta, weight: .semibold).foregroundStyle(.secondary)
            if value.isEmpty { MerchantGameNodeCopy.text(fallback) } else { Text(verbatim: value) }
        }
    }
    private func invitation(_ station: MerchantGameNodeStation) -> some View {
        card("merchantGameNode.invite.title", "merchantGameNode.invite.sub", id: "gameNode.invitation") {
            HStack {
                if station.canDecline {
                    Button { c.openDecline() } label: { MerchantGameNodeCopy.text("merchantGameNode.invite.decline").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).disabled(writeBlocked).accessibilityIdentifier("gameNode.decline")
                }
                if station.canAccept {
                    Button { c.prepareAccept() } label: { MerchantGameNodeCopy.text("merchantGameNode.invite.accept").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).disabled(writeBlocked).accessibilityIdentifier("gameNode.accept")
                }
            }
        }
    }
    private func readyCard(_ station: MerchantGameNodeStation) -> some View {
        card("merchantGameNode.ready.title", "merchantGameNode.ready.sub", id: "gameNode.readyCard") {
            ForEach(Array(c.readyDraft.checklist.enumerated()), id: \.element.code) { index, item in
                Button { c.toggleChecklist(index) } label: {
                    Label { Text(verbatim: item.label) } icon: { Image(systemName: item.checked ? "checkmark.square.fill" : "square") }
                }.buttonStyle(.plain).disabled(c.writeState != .idle)
                    .accessibilityAddTraits(item.checked ? .isSelected : []).accessibilityIdentifier("gameNode.check." + item.code)
            }
            readyIssue(.checklist)
            labeled("merchantGameNode.ready.capacity", required: true) {
                TextField(MerchantGameNodeCopy.string("merchantGameNode.ready.capacityPlaceholder"), text: Binding(
                    get: { c.readyDraft.capacity },
                    set: { c.readyDraft.capacity = String($0.filter(\.isASCII).filter(\.isNumber).prefix(4)) }))
                    .keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("gameNode.ready.capacity")
                readyIssue(.capacity)
            }
            labeled("merchantGameNode.ready.date", required: true) {
                MerchantGameNodeCivilDateField(value: Binding(get: { c.readyDraft.serviceDate }, set: { c.readyDraft.serviceDate = $0 }),
                                               placeholder: "merchantGameNode.ready.datePlaceholder", mode: .date)
                    .accessibilityIdentifier("gameNode.ready.date")
                readyIssue(.date)
            }
            labeled("merchantGameNode.ready.window", required: true) {
                Button { showsServiceTime = true } label: {
                    if !c.readyDraft.serviceStartTime.isEmpty && !c.readyDraft.serviceEndTime.isEmpty {
                        Text(verbatim: MerchantGameNodeCopy.format("merchantGameNode.ready.windowValue", c.readyDraft.serviceStartTime, c.readyDraft.serviceEndTime))
                    } else { MerchantGameNodeCopy.text("merchantGameNode.ready.windowPlaceholder") }
                }.disabled(c.writeState != .idle).accessibilityIdentifier("gameNode.ready.window")
                readyIssue(.timeWindow)
            }
            labeled("merchantGameNode.ready.note", required: false) {
                TextField(MerchantGameNodeCopy.string("merchantGameNode.ready.notePlaceholder"), text: Binding(
                    get: { c.readyDraft.note }, set: { c.readyDraft.note = String($0.prefix(200)) }))
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("gameNode.ready.note")
            }
            // MC7-26-4 (round 3 re-apply): per-field errors render under each field (`readyIssue`) once 确认准备完成
            // is tapped, so the merged always-on list of the same issues is not repeated here.
            Button { readyAttempted = true; Task { await c.submitReady() } } label: {
                HStack { if c.writeState == .submitting { ProgressView() }; MerchantGameNodeCopy.text("merchantGameNode.ready.submit") }.frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).disabled(writeBlocked).accessibilityIdentifier("gameNode.ready.submit")
        }
    }
    /// One inline field error under its field (MP `cy-inline-error kind="field"`), from `readyFieldIssues`.
    @ViewBuilder private func readyIssue(_ kind: MerchantGameNodeReadyField.Kind) -> some View {
        if readyAttempted, c.readyFieldIssues.contains(where: { $0.kind == kind }) {
            Label { Text(LocalizedStringKey("merchantCoop.gameNode.readyIssue." + kind.rawValue)) } icon: { Image(systemName: "exclamationmark.circle") }
                .cyText(.meta).foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("gameNode.ready.issue." + kind.rawValue)
        }
    }
    private func labeled<Content: View>(_ key: String, required: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) { MerchantGameNodeCopy.text(key).font(.subheadline); if required { Text(verbatim: "*").foregroundStyle(CYColor.dangerText).accessibilityHidden(true) } }
            content()
        }
    }
    private func pauseInfo(_ station: MerchantGameNodeStation) -> some View {
        card("merchantGameNode.pauseInfo.title", "merchantGameNode.pauseInfo.sub", id: "gameNode.pauseInfo") {
            info("merchantGameNode.pauseInfo.reason", station.pauseReason.isEmpty ? station.pauseReasonCode : station.pauseReason, fallback: "merchantGameNode.pauseInfo.reasonMissing")
            info("merchantGameNode.pauseInfo.eta", station.resumeEta, fallback: "merchantGameNode.pauseInfo.etaMissing")
            info("merchantGameNode.pauseInfo.fallback", station.fallbackPlanCode.isEmpty ? "" : station.fallbackPlanCode + (station.fallbackPlanVersion.map { " v\($0)" } ?? ""),
                 fallback: "merchantGameNode.pauseInfo.fallbackMissing")
            MerchantGameNodeCopy.text("merchantGameNode.pauseInfo.refund").cyText(.bodyCompact).foregroundStyle(.secondary)
            if station.canResume && c.permitsWrites {
                Button { c.prepareResume() } label: { MerchantGameNodeCopy.text("merchantGameNode.pauseInfo.resume").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).disabled(writeBlocked).accessibilityIdentifier("gameNode.resume")
            }
        }
    }
    private func info(_ label: String, _ value: String, fallback: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            MerchantGameNodeCopy.text(label).foregroundStyle(.secondary)
            Spacer()
            if value.isEmpty { MerchantGameNodeCopy.text(fallback) } else { Text(verbatim: value) }
        }.font(.subheadline)
    }
    private func runCard(_ station: MerchantGameNodeStation) -> some View {
        // verify-r1 3.6 / Figma 233:9703 (MR-30): one primary, 核验 N 位玩家 (scan); the two other ways in as a pair of
        // secondaries (出示打卡码 · 输入核验编号); 暂停接待 is a quiet row at the end, not a third button.
        card("merchantGameNode.run.title", "merchantGameNode.run.sub", id: "gameNode.runCard") {
            if station.canVerify && c.permitsWrites {
                Button { openSubmissionImport() } label: {
                    Group {
                        if station.pendingVerificationCount > 0 {
                            Text("r3merchant.station.verifyCount \(station.pendingVerificationCount)", tableName: OpsR3Text.table)
                        } else {
                            MerchantGameNodeCopy.text("merchantGameNode.run.scanVerify")
                        }
                    }
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).disabled(writeBlocked).accessibilityIdentifier("gameNode.verify.scan")
            }
            if station.playable || (station.canVerify && c.permitsWrites) {
                HStack(spacing: CYSpacing.sm) {
                    if station.playable {
                        Button { Task { await c.showCheckin() } } label: { MerchantGameNodeCopy.text("merchantGameNode.run.checkin").frame(maxWidth: .infinity) }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, compact: true))
                            .disabled(c.writeState != .idle).accessibilityIdentifier("gameNode.checkin")
                    }
                    if station.canVerify && c.permitsWrites {
                        Button { c.openVerify() } label: { MerchantGameNodeCopy.text("merchantGameNode.run.manualVerify").frame(maxWidth: .infinity) }
                            .buttonStyle(CYPillButtonStyle(style: .secondary, compact: true))
                            .disabled(writeBlocked).accessibilityIdentifier("gameNode.verify.manual")
                    }
                }
            }
            if station.canPause && c.permitsWrites {
                Button(role: .destructive) { c.openPause() } label: {
                    Label { MerchantGameNodeCopy.text("merchantGameNode.run.pause") } icon: { Image(systemName: "pause.circle") }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(CYColor.dangerText)
                .disabled(writeBlocked).accessibilityIdentifier("gameNode.pause")
            }
        }
    }
    private var receiptsCard: some View {
        card("merchantGameNode.receipts.title", "merchantGameNode.receipts.sub", id: "gameNode.receipts") {
            if c.recentReceipts.isEmpty {
                MerchantGameNodeCopy.text("merchantGameNode.receipts.empty").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
            ForEach(c.recentReceipts) { receipt in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        MerchantGameNodeCopy.text(receipt.actionKey).font(.subheadline)
                        Text(verbatim: MerchantGameNodeCopy.format("merchantGameNode.receipts.revision", Int64(receipt.revision))
                             + (receipt.replayed ? MerchantGameNodeCopy.string("merchantGameNode.receipts.replayed") : ""))
                            .cyText(.meta).foregroundStyle(.secondary)
                    }
                    Spacer()
                    MerchantGameNodeCopy.text(receipt.outcomeKey).cyText(.meta, weight: .semibold)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("gameNode.receipt." + receipt.action)
            }
        }
    }
    private func recapCard(_ station: MerchantGameNodeStation) -> some View {
        card("merchantGameNode.recap.title", "merchantGameNode.recap.sub", id: "gameNode.recap") {
            if let recap = station.recap {
                info("merchantGameNode.recap.arrived", String(recap.arrivedPlayers), fallback: "merchantGameNode.recap.pending")
                info("merchantGameNode.recap.submissions", String(recap.submissionCount), fallback: "merchantGameNode.recap.pending")
                info("merchantGameNode.recap.verified", "\(recap.approvedCount) / \(recap.rejectedCount)", fallback: "merchantGameNode.recap.pending")
                info("merchantGameNode.recap.recorded", String(recap.recordedCount), fallback: "merchantGameNode.recap.pending")
                info("merchantGameNode.recap.completed", "\(recap.normalCompletedCount) / \(recap.fallbackCompletedCount)", fallback: "merchantGameNode.recap.pending")
                info("merchantGameNode.recap.pauses", String(recap.pauseEventCount), fallback: "merchantGameNode.recap.pending")
                info("merchantGameNode.recap.authorized", String(recap.authorizedContentCount), fallback: "merchantGameNode.recap.pending")
                MerchantGameNodeCopy.text("merchantGameNode.recap.policy").cyText(.bodyCompact).foregroundStyle(.secondary)
            } else {
                MerchantGameNodeCopy.text("merchantGameNode.recap.pending").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Sheets
    @ViewBuilder private var sheetContent: some View {
        switch c.sheet {
        case .decline?: MerchantGameNodeDeclineSheet(model: model)
        case .pause?: MerchantGameNodePauseSheet(model: model)
        case .verify?: MerchantGameNodeVerifySheet(model: model)
        case nil: EmptyView()
        }
    }
}

/// Civil date/time strings ('yyyy-MM-dd' / 'HH:mm') edited through a fixed-zone carrier date;
/// no conversion into the phone's timezone.
struct MerchantGameNodeCivilDateField: View {
    enum Mode { case date, time }
    @Binding var value: String
    let placeholder: String
    let mode: Mode
    private static var formatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .gmt; f.calendar = Calendar(identifier: .gregorian); return f
    }
    private var pattern: String { mode == .date ? "yyyy-MM-dd" : "HH:mm" }
    private func parse(_ text: String) -> Date? { let f = Self.formatter; f.dateFormat = pattern; return f.date(from: text) }
    private func render(_ date: Date) -> String { let f = Self.formatter; f.dateFormat = pattern; return f.string(from: date) }
    private func proposal() -> String {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        if mode == .date { return String(format: "%04d-%02d-%02d", parts.year ?? 2026, parts.month ?? 1, parts.day ?? 1) }
        return String(format: "%02d:%02d", parts.hour ?? 12, ((parts.minute ?? 0) / 5) * 5)
    }
    var body: some View {
        if let date = parse(value) {
            DatePicker("", selection: Binding(get: { date }, set: { value = render($0) }), displayedComponents: mode == .date ? .date : .hourAndMinute)
                .labelsHidden().environment(\.timeZone, .gmt)
        } else {
            Button { value = proposal() } label: { MerchantGameNodeCopy.text(placeholder) }
        }
    }
}

@MainActor private struct MerchantGameNodeSheetFrame<Content: View>: View {
    let title: String
    @ObservedObject var model: MerchantGameNodeViewModel
    @ViewBuilder let content: () -> Content
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 16) { content() }.padding() }
                .navigationTitle(MerchantGameNodeCopy.string(title)).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button { model.coordinator.closeSheet() } label: { MerchantGameNodeCopy.text("merchantGameNode.cancel") }
                        .disabled(model.coordinator.writeState == .submitting).accessibilityIdentifier("gameNode.sheet.close")
                } }
        }.interactiveDismissDisabled(model.coordinator.writeState == .submitting)
    }
}
@MainActor private struct MerchantGameNodeChoices: View {
    let reasons: [MerchantGameNodeReason]
    let selected: String?
    let pick: (MerchantGameNodeReason) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
            ForEach(reasons) { reason in
                Button { pick(reason) } label: { MerchantGameNodeCopy.text(reason.labelKey).frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).tint(selected == reason.code ? .accentColor : .secondary)
                    .accessibilityAddTraits(selected == reason.code ? .isSelected : [])
                    .accessibilityIdentifier("gameNode.reason." + reason.code)
            }
        }
    }
}
@MainActor private struct MerchantGameNodeDeclineSheet: View {
    @ObservedObject var model: MerchantGameNodeViewModel
    var body: some View {
        let c = model.coordinator
        MerchantGameNodeSheetFrame(title: "merchantGameNode.decline.title", model: model) {
            MerchantGameNodeCopy.text("merchantGameNode.decline.tip").cyText(.bodyCompact).foregroundStyle(.secondary)
            MerchantGameNodeChoices(reasons: MerchantGameNodeReason.decline, selected: c.declineDraft.reason?.code) { c.declineDraft.reason = $0 }
            Button(role: .destructive) { Task { await c.submitDecline() } } label: {
                HStack { if c.writeState == .submitting { ProgressView() }; MerchantGameNodeCopy.text("merchantGameNode.decline.submit") }.frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).disabled(c.writeState != .idle).accessibilityIdentifier("gameNode.decline.submit")
        }
    }
}
@MainActor private struct MerchantGameNodePauseSheet: View {
    @ObservedObject var model: MerchantGameNodeViewModel
    var body: some View {
        let c = model.coordinator, options = c.fallbackOptions
        MerchantGameNodeSheetFrame(title: "merchantGameNode.pause.title", model: model) {
            MerchantGameNodeCopy.text("merchantGameNode.pause.tip").cyText(.bodyCompact).foregroundStyle(.secondary)
            MerchantGameNodeChoices(reasons: MerchantGameNodeReason.pause, selected: c.pauseDraft.reason?.code) { c.pauseDraft.reason = $0 }
            HStack(spacing: 2) { MerchantGameNodeCopy.text("merchantGameNode.pause.eta").font(.subheadline); Text(verbatim: "*").foregroundStyle(CYColor.dangerText).accessibilityHidden(true) }
            HStack {
                MerchantGameNodeCivilDateField(value: Binding(get: { c.pauseDraft.resumeDate }, set: { c.pauseDraft.resumeDate = $0 }),
                                               placeholder: "merchantGameNode.pause.date", mode: .date).accessibilityIdentifier("gameNode.pause.date")
                MerchantGameNodeCivilDateField(value: Binding(get: { c.pauseDraft.resumeTime }, set: { c.pauseDraft.resumeTime = $0 }),
                                               placeholder: "merchantGameNode.pause.time", mode: .time).accessibilityIdentifier("gameNode.pause.time")
            }
            MerchantGameNodeCopy.text("merchantGameNode.pause.fallback").font(.subheadline)
            if !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { option in Button { c.pauseDraft.fallback = option } label: { Text(verbatim: option.nodeName) } }
                } label: {
                    if let chosen = c.pauseDraft.fallback { Text(verbatim: chosen.nodeName) } else { MerchantGameNodeCopy.text("merchantGameNode.pause.fallbackPlaceholder") }
                }.accessibilityIdentifier("gameNode.pause.fallbackMenu")
            }
            if let chosen = c.pauseDraft.fallback {
                Text(verbatim: MerchantGameNodeCopy.format("merchantGameNode.pause.playerMessage", chosen.playerMessage)).cyText(.bodyCompact).foregroundStyle(.secondary)
            } else if options.isEmpty {
                MerchantGameNodeCopy.text("merchantGameNode.pause.noOptions").cyText(.bodyCompact).foregroundStyle(.secondary)
            } else {
                MerchantGameNodeCopy.text("merchantGameNode.pause.optional").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
            Button(role: .destructive) { Task { await c.submitPause() } } label: {
                HStack { if c.writeState == .submitting { ProgressView() }; MerchantGameNodeCopy.text("merchantGameNode.pause.submit") }.frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).disabled(!c.pauseDraft.canSubmit || c.writeState != .idle).accessibilityIdentifier("gameNode.pause.submit")
        }
    }
}
@MainActor private struct MerchantGameNodeVerifySheet: View {
    @ObservedObject var model: MerchantGameNodeViewModel
    var body: some View {
        let c = model.coordinator
        MerchantGameNodeSheetFrame(title: "merchantGameNode.verify.title", model: model) {
            HStack(spacing: 2) { MerchantGameNodeCopy.text("merchantGameNode.verify.id").font(.subheadline); Text(verbatim: "*").foregroundStyle(CYColor.dangerText).accessibilityHidden(true) }
            TextField(MerchantGameNodeCopy.string("merchantGameNode.verify.idPlaceholder"), text: Binding(
                get: { c.verifyDraft.submissionID },
                set: { c.verifyDraft.submissionID = String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(19)) }))
                .keyboardType(.numberPad).textFieldStyle(.roundedBorder).accessibilityIdentifier("gameNode.verify.id")
            Picker(selection: Binding(get: { c.verifyDraft.approve }, set: { c.verifyDraft.approve = $0; c.verifyDraft.rejectReason = nil })) {
                MerchantGameNodeCopy.text("merchantGameNode.verify.approve").tag(true)
                MerchantGameNodeCopy.text("merchantGameNode.verify.reject").tag(false)
            } label: { MerchantGameNodeCopy.text("merchantGameNode.verify.decision") }
                .pickerStyle(.segmented).accessibilityIdentifier("gameNode.verify.decision")
            if !c.verifyDraft.approve {
                MerchantGameNodeChoices(reasons: MerchantGameNodeReason.reject, selected: c.verifyDraft.rejectReason?.code) { c.verifyDraft.rejectReason = $0 }
            }
            Button { Task { await c.submitVerify() } } label: {
                HStack { if c.writeState == .submitting { ProgressView() }; MerchantGameNodeCopy.text("merchantGameNode.verify.submit") }.frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).disabled(c.writeState != .idle).accessibilityIdentifier("gameNode.verify.submit")
        }
    }
}
/// Paste, inspect an unverified identifier, then explicitly return to the original verify form.
@MainActor private struct MerchantGameNodeScanImportSheet: View {
    @ObservedObject var session: MerchantGameNodeImportSession
    let cancel: () -> Void
    let apply: () -> Void
    /// MC8-26-9 (game-node index.js:532 `wx.scanCode`): the camera scanner fills the code; typing stays the fallback.
    @State private var scanning = false
    var body: some View {
        NavigationStack {
            Form {
                Text("merchantCoop.gameNode.scan.hint").cyText(.bodyCompact)
                if session.code == nil {
                    Button { scanning = true } label: {
                        Label("merchantCoop.gameNode.scan.camera", systemImage: "qrcode.viewfinder").frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .disabled(!session.isCurrent).accessibilityIdentifier("gameNode.scan.camera")
                }
                if let code = session.code {
                    Section("merchant.submissionImport.unverified") {
                        Text(verbatim: code.submissionID)
                        Text("merchant.submissionImport.unverifiedBody").cyText(.bodyCompact)
                        Button("merchant.submissionImport.apply", action: apply)
                            .disabled(!session.isCurrent).accessibilityIdentifier("gameNode.scan.use")
                        Button("merchant.submissionImport.edit") { session.update("") }
                    }
                } else {
                    TextField("merchantCoop.gameNode.scan.placeholder", text: Binding(get: { session.raw }, set: session.update))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .disabled(!session.isCurrent).accessibilityIdentifier("gameNode.scan.text")
                    Button("merchant.submissionImport.preview") { session.preview() }
                        .disabled(!session.isCurrent || session.raw.isEmpty)
                }
                if let issue = session.issue { Text(LocalizedStringKey(issue)).foregroundStyle(.secondary) }
            }
            .navigationTitle(MerchantGameNodeCopy.string("merchantGameNode.run.scanVerify")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button(action: cancel) { MerchantGameNodeCopy.text("merchantGameNode.cancel") }
            } }
            .cySheet(isPresented: $scanning) {
                NativeQRScanner { payload in
                    scanning = false
                    guard session.isCurrent else { return }
                    session.update(payload)
                    session.preview()
                }
            }
        }
    }
}
/// One time range in 5-minute steps; the end must be after the start (cy-time-range).
@MainActor private struct MerchantGameNodeServiceTimeSheet: View {
    @ObservedObject var model: MerchantGameNodeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var start = ""
    @State private var end = ""
    private var choices: [String] {
        var values = stride(from: 0, to: 1440, by: 5).map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
        for existing in [start, end] where !existing.isEmpty && !values.contains(existing) { values.append(existing) }
        return values.sorted()
    }
    private var valid: Bool { !start.isEmpty && !end.isEmpty && start < end }
    var body: some View {
        NavigationStack {
            Form {
                Picker(selection: $start) { ForEach(choices, id: \.self) { Text(verbatim: $0).tag($0) } } label: { MerchantGameNodeCopy.text("merchantGameNode.time.start") }
                    .accessibilityIdentifier("gameNode.time.start")
                Picker(selection: $end) { ForEach(choices, id: \.self) { Text(verbatim: $0).tag($0) } } label: { MerchantGameNodeCopy.text("merchantGameNode.time.end") }
                    .accessibilityIdentifier("gameNode.time.end")
                if !valid { MerchantGameNodeCopy.text("merchantGameNode.time.invalid").cyText(.meta).foregroundStyle(CYColor.dangerText) }
            }
            .navigationTitle(MerchantGameNodeCopy.string("merchantGameNode.ready.window")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { MerchantGameNodeCopy.text("merchantGameNode.cancel") } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        guard valid, model.coordinator.writeState == .idle else { return }
                        model.coordinator.readyDraft.serviceStartTime = start; model.coordinator.readyDraft.serviceEndTime = end; dismiss()
                    } label: { MerchantGameNodeCopy.text("merchantGameNode.time.done") }.disabled(!valid).accessibilityIdentifier("gameNode.time.done")
                }
            }
            .onAppear {
                start = model.coordinator.readyDraft.serviceStartTime.isEmpty ? "10:00" : model.coordinator.readyDraft.serviceStartTime
                end = model.coordinator.readyDraft.serviceEndTime.isEmpty ? "18:00" : model.coordinator.readyDraft.serviceEndTime
            }
        }
    }
}
/// 本站打卡码: shows the server-rendered QR image, counts down the TTL and renews only while visible.
@MainActor private struct MerchantGameNodeCheckinView: View {
    @ObservedObject var model: MerchantGameNodeViewModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        let c = model.coordinator
        VStack(spacing: 18) {
            HStack { Spacer(); Button { c.closeCheckin() } label: { Image(systemName: "xmark").font(.title3) }
                .accessibilityLabel(MerchantGameNodeCopy.string("merchantGameNode.checkin.close")).accessibilityIdentifier("gameNode.checkin.close") }
            MerchantGameNodeCopy.text("merchantGameNode.checkin.title").cyText(.sheetTitle)
            MerchantGameNodeCopy.text("merchantGameNode.checkin.desc").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            switch c.checkinState {
            case .loading: ProgressView().frame(width: 240, height: 240)
            case .ready:
                qrImage(c.checkinQRCodeURL)
                Text(verbatim: MerchantGameNodeCopy.format("merchantGameNode.checkin.countdown", Int64(c.checkinCountdown)))
                    .cyText(.numericBody).accessibilityIdentifier("gameNode.checkin.countdown")
            case .error:
                MerchantGameNodeCopy.text(c.checkinError ?? .key("merchantGameNode.checkin.error")).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("gameNode.checkin.error")
                Button { Task { await c.issueCheckin() } } label: { MerchantGameNodeCopy.text("merchantGameNode.retry") }
                    .buttonStyle(.bordered).accessibilityIdentifier("gameNode.checkin.retry")
            }
            Spacer()
        }
        .padding()
        .privacySensitive()
        .accessibilityElement(children: .contain).accessibilityIdentifier("gameNode.checkin.view")
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled && c.checkinVisible {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                await c.tickCheckin()
            }
        }
    }
    @ViewBuilder private func qrImage(_ value: String) -> some View {
        if let url = URL(string: value), url.scheme == "https" {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().interpolation(.none).scaledToFit() }
                else if phase.error != nil { MerchantGameNodeCopy.text("merchantGameNode.checkin.imageUnavailable") }
                else { ProgressView() }
            }.frame(width: 240, height: 240).background(.white).accessibilityIdentifier("gameNode.checkin.qr")
        } else {
            MerchantGameNodeCopy.text("merchantGameNode.checkin.imageUnavailable").frame(width: 240, height: 240)
                .background(Color(.secondarySystemBackground)).accessibilityIdentifier("gameNode.checkin.qr")
        }
    }
}
