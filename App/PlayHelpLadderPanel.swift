import SwiftUI

/// UG-09: saved help request ids survive a relaunch so "keep checking" resends the same id.
/// Holds only `owner|run|node|action|level -> requestId`; no hint content, answer or balance.
@MainActor final class PlayHelpDefaultsRequestStore: PlayHelpRequestStore {
    static let shared = PlayHelpDefaultsRequestStore()
    private static let key = "play-help-pending:v1"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private var all: [String: String] { defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:] }
    func requestID(for key: String) -> String? { all[key] }
    func remember(_ requestID: String, for key: String) -> Bool {
        var next = all; next[key] = requestID
        defaults.set(next, forKey: Self.key)
        return self.requestID(for: key) == requestID
    }
    func forget(_ key: String) {
        var next = all; next.removeValue(forKey: key)
        defaults.set(next, forKey: Self.key)
    }
}

/// UG-05…UG-09 centred hint dialog (mini-program play-help.wxml, a1-v3-21 "提示应该是弹窗"). Rows follow the
/// server layer list; the free counter, charges and score detail are server facts and never computed here.
@MainActor struct PlayHelpLadderPanel: View {
    @Environment(\.locale) private var locale
    @Bindable var model: PlayHelpLadderModel
    /// Team run: the shared pool section. Hidden unless the server reports an enabled pool.
    var teamPool: TeamPoolHintModel? = nil
    var approvedArtworkHosts: Set<String> = []
    /// Called after POOL_TRIM so the host can re-read the trimmed letter pool. Default does nothing.
    var onPoolTrimmed: () -> Void = {}
    /// Stage analytics codes. Nil until the play host passes the current node.
    var analyticsNodeID: Int? = nil
    var analyticsKit: String? = nil
    let close: () -> Void
    @State private var confirmLevel: Int?
    @State private var confirmSkip = false
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @Environment(\.analyticsEventClient) private var analytics

    /// Design hand-off r1 PL-15: the hint is a `fit` → `.medium` sheet titled 要点提示吗 (no longer a centred dialog).
    /// The free count is a tag; when the server did not send it, the tag reads "—" with the reason under it.
    var body: some View {
        CYResizableSheet(kind: .hint, title: Text("hint.sheet.title", tableName: "DesignR1"), onClose: close) {
                if model.readFailed, model.rows.isEmpty, !model.enabled {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CYStateView.offline(locale: locale) { Task { await model.load() } }
                            .accessibilityIdentifier("playHelp.offline")
                        CYScreenOfflineWriteBanner(
                            routes: ["/api/play/help/use", "/api/play/help/skip"],
                            session: offlineWriteSession.session
                        )
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("playHelp.panel")
                } else {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    if let left = model.freeLeft {
                        if left > 0 {
                            CYStatusChip(verbatim: appLocalized("playHelp.freeLeft \(left)", locale: locale), tone: .neutral, systemImage: "gift")
                                .accessibilityIdentifier("playHelp.freeLeft")
                        }
                    } else {
                        HStack(spacing: CYSpacing.sm) {
                            CYStatusChip(verbatim: CYUnknownValue.dash, tone: .neutral, systemImage: "gift")
                            Text("hint.freeLeft.unknown", tableName: "DesignR1").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("playHelp.freeLeft")
                    }
                    if model.readFailed {
                        Text("cy.kit.offline.title")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("playHelp.offline")
                    }
                    if !model.rows.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(model.rows) { row in
                                layerRow(row)
                                if row.id != model.rows.last?.id { Divider() }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised))
                    }
                    if let teamPool, teamPool.isVisible { TeamPoolHintSection(model: teamPool) }
                    CYScreenOfflineWriteBanner(
                        routes: ["/api/play/help/use", "/api/play/help/skip"],
                        session: offlineWriteSession.session
                    )
                    // mp-journey r3: MP play-help.wxml order — notice, 分数明细, 跳过 (F01: last of the help rows), 这一站有问题.
                    if let notice = model.notice { noticeText(notice) }
                    receiptGroup
                    if model.showsSkip { skipRow }
                    if PlayStageAnalyticsGate.enabled { issueRow }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("playHelp.panel")
                }
        }
        .onAppear {
            model.markSavedRequests()
            PlayStageAnalytics.track(analytics, .hintOpen, nodeID: analyticsNodeID, kit: analyticsKit)
        }
        .onChange(of: model.poolTrimGeneration) { _, _ in onPoolTrimmed() }
        .overlay {
            if let level = confirmLevel, let row = model.row(level) {
                CYModal(
                    title: appLocalized(String.LocalizationValue(stringLiteral: row.typeLabelKey), locale: locale),
                    message: row.state == .cost
                        ? appLocalized("playHelp.confirm.cost \(row.cost)", locale: locale)
                        : appLocalized("playHelp.confirm.free", locale: locale),
                    cancelTitle: appLocalized("playHelp.cancel", locale: locale),
                    confirmTitle: appLocalized("playHelp.view", locale: locale),
                    confirmIdentifier: "playHelp.confirm",
                    cancelIdentifier: "playHelp.cancel",
                    onCancel: { confirmLevel = nil },
                    onConfirm: {
                        confirmLevel = nil
                        Task {
                            await SessionOfflineSyncModel.shared.performWriteOptIn(
                                environmentSession: offlineWriteSession.session,
                                routes: ["/api/play/help/use"]
                            ) {
                                await model.use(level)
                            }
                        }
                    }
                )
            }
        }
        .overlay {
            if confirmSkip {
                CYModal(
                    title: appLocalized("playHelp.skip", locale: locale),
                    message: appLocalized("playHelp.skip.consequence", locale: locale),
                    cancelTitle: appLocalized("playHelp.cancel", locale: locale),
                    confirmTitle: appLocalized("playHelp.skip.confirm", locale: locale),
                    isDestructive: true,
                    confirmIdentifier: "playHelp.skip.confirm",
                    cancelIdentifier: "playHelp.skip.cancel",
                    onCancel: { confirmSkip = false },
                    onConfirm: {
                        confirmSkip = false
                        PlayStageAnalytics.track(analytics, .stageSkip, nodeID: analyticsNodeID, kit: analyticsKit)
                        Task {
                            await SessionOfflineSyncModel.shared.performWriteOptIn(
                                environmentSession: offlineWriteSession.session,
                                routes: ["/api/play/help/skip"]
                            ) {
                                await model.skip()
                            }
                        }
                    }
                )
            }
        }
    }

    private func layerRow(_ row: PlayHelpRow) -> some View {
        Button { tap(row) } label: {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(LocalizedStringKey(row.typeLabelKey)).cyText(.body).foregroundStyle(CYColor.textPrimary)
                    if let content = row.content { contentView(content, type: row.contentType ?? row.type, level: row.level) }
                    if let charged = row.chargedPoints, charged > 0 {
                        Group {
                            if let balance = row.balanceAfter { Text("playHelp.charged \(charged) \(balance)") }
                            else { Text("playHelp.chargedOnly \(charged)") }
                        }
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("playHelp.charged.\(row.level)")
                    }
                    if let problem = row.problem { problemText(problem).accessibilityIdentifier("playHelp.problem.\(row.level)") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if model.busyLevel == row.level { ProgressView().accessibilityLabel(Text("playHelp.sending")) }
                else { actionText(row).cyText(.label).foregroundStyle(row.tappable ? CYColor.textPrimary : CYColor.textTertiary) }
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!row.tappable || model.busy)
        .accessibilityIdentifier("playHelp.row.\(row.level)")
    }

    @ViewBuilder private func contentView(_ content: String, type: String, level: Int) -> some View {
        if type == "IMAGE" {
            PlayKitArtwork(source: content, approvedHosts: approvedArtworkHosts)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                .accessibilityLabel(Text("playHelp.type.image"))
                .accessibilityIdentifier("playHelp.content.\(level)")
        } else {
            Text(verbatim: content)
                .font(type == "LETTER" || type == "DIGIT" ? CYTypography.pageTitle : CYTypography.body)
                .foregroundStyle(CYColor.textPrimary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("playHelp.content.\(level)")
        }
    }

    private func actionText(_ row: PlayHelpRow) -> Text {
        if row.pending { return Text("playHelp.keepChecking") }
        switch row.state {
        case .review: return Text("playHelp.review")
        case .gated: return Text("playHelp.gated")
        case .free: return Text("playHelp.free")
        case .cost: return Text("playHelp.cost \(row.cost)")
        case .unavailable: return Text("playHelp.unavailable")
        }
    }

    private func problemText(_ problem: PlayHelpRow.Problem) -> some View {
        Group {
            switch problem {
            case .pending: Text("playHelp.pending")
            case .pendingNote(let message): Text(verbatim: message)
            case .insufficient: Text("playHelp.insufficient")
            case .refused(let message):
                if let message, !message.isEmpty { Text(verbatim: message) } else { Text("playHelp.refused") }
            }
        }
        .cyText(.meta).foregroundStyle(CYColor.dangerText)
    }

    private var skipRow: some View {
        Button {
            if model.skipPending {
                Task {
                    await SessionOfflineSyncModel.shared.performWriteOptIn(
                        environmentSession: offlineWriteSession.session,
                        routes: ["/api/play/help/skip"]
                    ) {
                        await model.skip()
                    }
                }
            } else { confirmSkip = true }
        } label: {
            HStack {
                Text("playHelp.skip").cyText(.body).foregroundStyle(CYColor.dangerText)
                Spacer()
                if model.skipPending { Text("playHelp.keepChecking").cyText(.label).foregroundStyle(CYColor.textPrimary) }
            }
            .frame(maxWidth: .infinity)
        }
        // native-r3-b: system bordered button (was a plain button on a hand-drawn raised rectangle).
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(model.busy)
        .accessibilityIdentifier("playHelp.skip")
    }

    private func noticeText(_ notice: PlayHelpLadderModel.Notice) -> some View {
        Group {
            switch notice {
            case .storageUnavailable: Text("playHelp.storageUnavailable")
            case .pending: Text("playHelp.pending")
            case .pendingNote(let message): Text(verbatim: message)
            case .refused(let message):
                if let message, !message.isEmpty { Text(verbatim: message) } else { Text("playHelp.skip.refused") }
            }
        }
        .cyText(.meta).foregroundStyle(CYColor.dangerText)
        .accessibilityIdentifier("playHelp.notice")
    }

    private var receiptGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { Task { await model.toggleReceipt() } } label: {
                HStack {
                    Text("playHelp.receipt").cyText(.body).foregroundStyle(CYColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(model.receiptOpen ? 180 : 0))
                        .foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                }
                .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(model.receiptOpen ? "playHelp.expanded" : "playHelp.collapsed"))
            .accessibilityIdentifier("playHelp.receipt")
            if model.receiptOpen {
                if model.receiptUnavailable {
                    Text("playHelp.receipt.unavailable").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.md)
                        .accessibilityIdentifier("playHelp.receipt.unavailable")
                } else if let lines = model.receipt {
                    PlayHelpReceiptLines(lines: lines).padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.md)
                } else {
                    CYLoadingState().padding(.bottom, CYSpacing.md)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised))
    }

    /// MP CG-09-P2-6 这一站有问题: the last group of the hint dialog; picks one category and records it.
    private var issueRow: some View {
        PlayKitIssueReportMenu(nodeID: analyticsNodeID ?? model.identity.nodeID, kit: analyticsKit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised))
    }

    private func tap(_ row: PlayHelpRow) {
        guard row.tappable, !model.busy else { return }
        if row.needsConfirmation { confirmLevel = row.level }
        else { Task { await model.use(row.level) } }
    }

}

/// UG-07 rows: event on the left, change on the right. Solve score and points stay on separate rows;
/// not-scored never shows 0, and a missing level list says the detail is still to come.
@MainActor struct PlayHelpReceiptLines: View {
    let lines: [PlayHelpReceiptLine]
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline) {
                    label(line).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    Spacer(minLength: CYSpacing.md)
                    value(line).cyText(.label).foregroundStyle(CYColor.textPrimary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("playHelp.receipt." + line.id)
            }
        }
    }

    private func label(_ line: PlayHelpReceiptLine) -> Text {
        switch line {
        case .skipped, .revealed: return Text("playHelp.receipt.question")
        case .notScored: return Text("playHelp.receipt.score")
        case .baseScore: return Text("playHelp.receipt.base")
        case .bonus: return Text("playHelp.receipt.bonus")
        case .helpDeduction: return Text("playHelp.receipt.helpDeduction")
        case .skipDeduction: return Text("playHelp.receipt.skipDeduction")
        case .netScore: return Text("playHelp.receipt.net")
        case .pointsCharged: return Text("playHelp.receipt.points")
        case .level(let level, let type, _, _):
            let key = "playHelp.type." + (PlayHelpProjection.renderable.contains(type) ? type.lowercased() : type == "SKIP" ? "skip" : "other")
            return Text("playHelp.receipt.level \(level)") + Text(verbatim: " · ") + Text(LocalizedStringKey(key))
        case .detailMissing: return Text("playHelp.receipt.detail")
        }
    }

    private func value(_ line: PlayHelpReceiptLine) -> Text {
        switch line {
        case .skipped: return Text("playHelp.receipt.skippedValue")
        case .revealed: return Text("playHelp.receipt.revealedValue")
        case .notScored: return Text("playHelp.receipt.notScored")
        case .baseScore(let value), .netScore(let value): return Text(verbatim: String(value))
        case .bonus(let value): return Text(verbatim: "+" + String(value))
        case .helpDeduction(let value), .skipDeduction(let value): return Text(verbatim: "-" + String(value))
        case .pointsCharged(let value): return Text("playHelp.points \(value)")
        case .level(_, _, let free, let points):
            if free { return Text("playHelp.free") }
            if let points { return Text("playHelp.points \(points)") }
            return Text(verbatim: "")
        case .detailMissing: return Text("playHelp.receipt.detailMissing")
        }
    }
}
