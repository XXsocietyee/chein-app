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
    @Bindable var model: PlayHelpLadderModel
    var approvedArtworkHosts: Set<String> = []
    let close: () -> Void
    @State private var confirmLevel: Int?
    @State private var confirmSkip = false
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            CYColor.bgOverlay.ignoresSafeArea().onTapGesture(perform: close)
                .accessibilityLabel(Text("playHelp.close")).accessibilityAddTraits(.isButton)
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("playHelp.title").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button(action: close) {
                            Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(CYColor.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("playHelp.close"))
                        .accessibilityIdentifier("playHelp.close")
                    }
                    if let left = model.freeLeft {
                        Text("playHelp.freeLeft \(left)").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("playHelp.freeLeft")
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
                    if model.showsSkip { skipRow }
                    if let notice = model.notice { noticeText(notice) }
                    receiptGroup
                }
                .padding(CYSpacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: 380, maxHeight: 560)
            .fixedSize(horizontal: false, vertical: true)
            .background(RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous).fill(CYColor.bgElevated))
            .padding(CYSpacing.lg)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityIdentifier("playHelp.panel")
        }
        .onAppear { model.markSavedRequests() }
        .alert(confirmTitle, isPresented: Binding(get: { confirmLevel != nil }, set: { if !$0 { confirmLevel = nil } })) {
            Button("playHelp.view") {
                guard let level = confirmLevel else { return }
                confirmLevel = nil
                Task { await model.use(level) }
            }.accessibilityIdentifier("playHelp.confirm")
            Button("playHelp.cancel", role: .cancel) { confirmLevel = nil }
        } message: { confirmMessage }
        .alert("playHelp.skip", isPresented: $confirmSkip) {
            Button("playHelp.skip.confirm", role: .destructive) { Task { await model.skip() } }
                .accessibilityIdentifier("playHelp.skip.confirm")
            Button("playHelp.cancel", role: .cancel) {}
        } message: { Text("playHelp.skip.consequence") }
    }

    private func layerRow(_ row: PlayHelpRow) -> some View {
        Button { tap(row) } label: {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(LocalizedStringKey(row.typeLabelKey)).font(CYTypography.body).foregroundStyle(CYColor.textPrimary)
                    if let content = row.content { contentView(content, type: row.contentType ?? row.type, level: row.level) }
                    if let charged = row.chargedPoints, charged > 0 {
                        Group {
                            if let balance = row.balanceAfter { Text("playHelp.charged \(charged) \(balance)") }
                            else { Text("playHelp.chargedOnly \(charged)") }
                        }
                        .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("playHelp.charged.\(row.level)")
                    }
                    if let problem = row.problem { problemText(problem).accessibilityIdentifier("playHelp.problem.\(row.level)") }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if model.busyLevel == row.level { ProgressView().accessibilityLabel(Text("playHelp.sending")) }
                else { actionText(row).font(CYTypography.label).foregroundStyle(row.tappable ? CYColor.textPrimary : CYColor.textTertiary) }
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
            case .insufficient: Text("playHelp.insufficient")
            case .refused(let message):
                if let message, !message.isEmpty { Text(verbatim: message) } else { Text("playHelp.refused") }
            }
        }
        .font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
    }

    private var skipRow: some View {
        Button {
            if model.skipPending { Task { await model.skip() } } else { confirmSkip = true }
        } label: {
            HStack {
                Text("playHelp.skip").font(CYTypography.body).foregroundStyle(CYColor.dangerText)
                Spacer()
                if model.skipPending { Text("playHelp.keepChecking").font(CYTypography.label).foregroundStyle(CYColor.textPrimary) }
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.busy)
        .accessibilityIdentifier("playHelp.skip")
    }

    private func noticeText(_ notice: PlayHelpLadderModel.Notice) -> some View {
        Group {
            switch notice {
            case .storageUnavailable: Text("playHelp.storageUnavailable")
            case .pending: Text("playHelp.pending")
            case .refused(let message):
                if let message, !message.isEmpty { Text(verbatim: message) } else { Text("playHelp.skip.refused") }
            }
        }
        .font(CYTypography.meta).foregroundStyle(CYColor.dangerText)
        .accessibilityIdentifier("playHelp.notice")
    }

    private var receiptGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { Task { await model.toggleReceipt() } } label: {
                HStack {
                    Text("playHelp.receipt").font(CYTypography.body).foregroundStyle(CYColor.textPrimary)
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
                    Text("playHelp.receipt.unavailable").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.md)
                        .accessibilityIdentifier("playHelp.receipt.unavailable")
                } else if let lines = model.receipt {
                    PlayHelpReceiptLines(lines: lines).padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.md)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.bottom, CYSpacing.md)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised))
    }

    private func tap(_ row: PlayHelpRow) {
        guard row.tappable, !model.busy else { return }
        if row.needsConfirmation { confirmLevel = row.level }
        else { Task { await model.use(row.level) } }
    }

    private var confirmTitle: LocalizedStringKey {
        guard let level = confirmLevel, let row = model.row(level) else { return "playHelp.title" }
        return LocalizedStringKey(row.typeLabelKey)
    }

    private var confirmMessage: Text {
        guard let level = confirmLevel, let row = model.row(level), row.state == .cost else { return Text("playHelp.confirm.free") }
        return Text("playHelp.confirm.cost \(row.cost)")
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
                    label(line).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    Spacer(minLength: CYSpacing.md)
                    value(line).font(CYTypography.label).foregroundStyle(CYColor.textPrimary).monospacedDigit()
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
