import SwiftUI

/// Mini-program `cy-playkit-journey-check` on the production play grant: hold to roll, the server's
/// dice and verdict, then reroll (luck) or settle. Unknown keeps the original write and only re-reads it.
@MainActor struct PlayCheckRuntimeSection: View {
    let nodeID: Int
    let routeSessionID: Int?
    let nodeDone: Bool
    @Environment(\.playRuntimeGap) private var binding
    @Environment(\.locale) private var locale
    @State private var runtime: PlayCheckRuntime?
    @State private var shown = true

    var body: some View {
        Group {
            if let runtime, shown, !nodeDone { card(runtime) }
            else if runtime != nil, !nodeDone {
                Button { shown = true } label: { Text(verbatim: c("Check", "检定")) }
                    .accessibilityIdentifier("play.check.reopen")
            }
        }
        .task(id: [nodeID, routeSessionID ?? 0]) {
            guard let binding, !nodeDone, let problem = await binding.encounterCheck(nodeID: nodeID) else { runtime = nil; return }
            runtime = binding.checkRuntime(nodeID: nodeID, routeSessionID: routeSessionID, problem: problem)
        }
    }

    private func c(_ en: String, _ zh: String) -> String { CYKitCopy(locale: locale)(en, zh) }

    @ViewBuilder private func card(_ model: PlayCheckRuntime) -> some View {
        let receipt = model.receipt
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                HStack(spacing: CYSpacing.sm) {
                    Image(systemName: "dice.fill").font(.title3).foregroundStyle(CYColor.textSecondary)
                    Text(verbatim: c("Check", "检定")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                }.accessibilityHidden(true)
                Text(verbatim: model.problem.skill).font(CYTypography.display).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("play.check.skill")
                CYDiceTierStrip(tier: model.problem.tier)
                if !model.detailsHidden {
                    DiceD20CanvasView(values: receipt?.dice ?? [], kept: receipt?.kept,
                        rollMode: model.problem.advantage ? "advantage" : (model.problem.disadvantage ? "disadvantage" : "normal"),
                        rolling: model.loading && receipt == nil).frame(maxWidth: .infinity)
                    if let receipt, let dc = receipt.dc, let total = receipt.total {
                        JourneyCheckDCTrack(total: total, dc: dc, success: receipt.success)
                    }
                }
                if let receipt {
                    if let success = receipt.success {
                        // 「过线了 / 没过线」 comes from the receipt; the client never judges.
                        Label { Text(verbatim: success ? c("Over the line", "过线了") : c("Short of the line", "没过线")) }
                            icon: { Image(systemName: success ? "checkmark.seal.fill" : "xmark.seal") }
                            .font(CYTypography.sectionTitle)
                            .foregroundStyle(success ? CYColor.successText : CYColor.warningText)
                            .accessibilityIdentifier("play.check.verdict")
                    }
                    let margin = PlayCheckRuntime.marginText(receipt, hidden: model.detailsHidden)
                    if !margin.isEmpty { Text(verbatim: margin).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                    let nat = PlayCheckRuntime.natTag(receipt)
                    if !nat.isEmpty, !model.detailsHidden { Text(verbatim: nat).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                    if receipt.settled {
                        if !receipt.text.isEmpty { Text(verbatim: receipt.text).font(CYTypography.body).foregroundStyle(CYColor.textSecondary) }
                        if !receipt.failCostLabel.isEmpty { Text(verbatim: receipt.failCostLabel).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                    }
                }
                if !model.disabledReason.isEmpty {
                    Text(verbatim: model.disabledReason).font(CYTypography.meta)
                        .foregroundStyle(model.unknown ? CYColor.warningText : CYColor.dangerText)
                        .accessibilityIdentifier("play.check.reason")
                }
                if model.unknown && !model.loading {
                    CYPillButton(verbatim: c("Check the original result", "再次查询"), style: .secondary) { Task { await model.perform(.recover) } }
                        .accessibilityIdentifier("play.check.recover")
                } else if receipt == nil {
                    CYHoldToRollButton(busy: model.loading) { Task { await model.perform(.roll) } }
                        .disabled(!model.canRoll)
                        .accessibilityIdentifier("play.check.roll")
                } else if receipt?.settled == false {
                    if model.canReroll {
                        CYPillButton(verbatim: c("Reroll (luck)", "花幸运重掷"), style: .secondary) { Task { await model.perform(.reroll) } }
                            .accessibilityIdentifier("play.check.reroll")
                    }
                    CYPillButton(verbatim: c("Settle", "结算")) { Task { await model.perform(.settle) } }
                        .disabled(!model.canSettle)
                        .accessibilityIdentifier("play.check.settle")
                }
                if model.loading { ProgressView() }
                // A failed check still advances: closing never blocks the stop.
                Button { shown = false } label: { Text(verbatim: c("Close", "关闭")) }
                    .font(CYTypography.label).foregroundStyle(CYColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("play.check.close")
            }
            .padding(CYSpacing.xl)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous))
            .sensoryFeedback(.impact(weight: .heavy), trigger: receipt?.dice ?? [])
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)).listRowBackground(Color.clear)
        }
    }
}

/// `play-hud-overlays.js` `loadPlayContact`: one read when the run screen opens; no phone, no row.
@MainActor struct PlayContactSection: View {
    let currentNodeID: Int?
    /// A completed run also leaves the server end tombstone (`run-session/clear`).
    var finished = false
    @Environment(\.playRuntimeGap) private var binding
    @Environment(\.locale) private var locale
    @State private var contact: PlayContact?

    var body: some View {
        Group {
            if let contact {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: contact.merchant ? CYKitCopy(locale: locale)("Contact the merchant", contact.label)
                             : CYKitCopy(locale: locale)("Contact the organizer", contact.label))
                            .font(CYTypography.label).foregroundStyle(CYColor.textPrimary)
                        if !contact.name.isEmpty { Text(verbatim: contact.name).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                        // The number is shown as text; the link beside it is a convenience.
                        HStack(spacing: CYSpacing.sm) {
                            Text(verbatim: contact.phone).font(CYTypography.body).monospacedDigit().textSelection(.enabled)
                            if let url = URL(string: "tel:" + contact.phone.filter { $0.isNumber || $0 == "+" }) {
                                Link(destination: url) { Image(systemName: "phone.fill").accessibilityLabel(Text(verbatim: contact.label)) }
                            }
                        }
                    }.accessibilityElement(children: .contain).accessibilityIdentifier("play.contact")
                }
            }
        }
        .task(id: finished) { if finished { await binding?.clearRunSessionOnFinish() } }
        .task(id: currentNodeID ?? 0) {
            guard let binding, let client = binding.client() else { contact = nil; return }
            contact = await PlayContact.read(client: client, scope: binding.scope, currentNodeID: currentNodeID)
        }
    }
}

/// Topic detail 「开局前准备」 (`pages/topic/index` `_loadPrep` / `_buildPrep`). Ticks are local; the
/// play window and `openNow` are the server's. Platform rules stay server-side at start.
@MainActor struct PlayTopicPrepSection: View {
    let topicID: Int
    @Environment(\.playRuntimeTopicClient) private var makeClient
    @Environment(\.locale) private var locale
    @State private var read: PlayTopicSetup.Read?
    @State private var loading = false
    @State private var ticked: Set<Int> = []
    @State private var showing = false

    var body: some View {
        Group {
            if makeClient != nil {
                if loading { Section { Text(verbatim: CYKitCopy(locale: locale)("Loading…", "正在加载…")).foregroundStyle(CYColor.textSecondary) } }
                else if case .failed = read {
                    Section {
                        Button { Task { await load() } } label: {
                            Label { Text(verbatim: CYKitCopy(locale: locale)("Pre-game prep failed to load · tap to retry", "开局前准备加载失败 · 轻点重试")) }
                                icon: { Image(systemName: "exclamationmark.triangle") }
                        }.accessibilityIdentifier("play.prep.retry")
                    }
                } else if case .loaded(let setup) = read {
                    Section {
                        Button { showing = true } label: {
                            Label { Text(verbatim: setup.rowText(ticked: ticked)) }
                                icon: { Image(systemName: setup.closed ? "clock" : setup.ready(ticked: ticked) ? "checkmark.circle" : "info.circle") }
                        }.accessibilityIdentifier("play.prep.row")
                    }
                    .sheet(isPresented: $showing) { sheet(setup) }
                }
            }
        }
        .task(id: topicID) { if read == nil { await load() } }
    }

    private func load() async {
        guard let client = makeClient?() else { read = nil; return }
        loading = true
        read = await PlayTopicSetup.read(client: client, topicID: topicID)
        loading = false
    }

    private func sheet(_ setup: PlayTopicSetup) -> some View {
        NavigationStack {
            List {
                if !setup.windowText.isEmpty {
                    Section { LabeledContent(CYKitCopy(locale: locale)("Play window", "可玩时段"), value: setup.windowText) }
                }
                Section {
                    ForEach(setup.items) { item in
                        Toggle(isOn: Binding(get: { ticked.contains(item.index) },
                                             set: { if $0 { ticked.insert(item.index) } else { ticked.remove(item.index) } })) {
                            Text(verbatim: item.text)
                        }
                    }
                }
            }
            .navigationTitle(Text(verbatim: CYKitCopy(locale: locale)("Pre-game prep", "开局前准备")))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button { showing = false } label: { Text(verbatim: CYKitCopy(locale: locale)("Done", "完成")) } } }
        }
    }
}

/// Personal theme gameplay (`theme-backpack.js` `_themeGameplayCommand` / `_readThemeRewardPreview`).
/// QUEST_RESOLVE and FACILITY_USE read the reward preview first; the action carries its `previewVersion`.
/// While a command is unconfirmed, every tap resends that same command (same `actionId`), never a new one.
@MainActor @Observable final class PlayThemeGameplayFlow {
    struct Preview: Equatable {
        let operation: String; let contentID: String; let selections: [String: PlayWireValue]; let pack: PlayThemeRewardPreview
    }
    private(set) var busy = false
    private(set) var unknown = false
    private(set) var error = ""
    private(set) var preview: Preview?
    private(set) var pendingCommand: [String: PlayWireValue]?

    func start(operation: String, contentID: String, costOption: Int?, choiceKey: String?, view: PlayWireValue,
               client: PlayRuntimeClient?, applied: @escaping @MainActor (PlayWireValue) async -> Void) async {
        guard !busy, let client else { return }
        if let pendingCommand { await send(pendingCommand, client: client, applied: applied); return }
        var selections: [String: PlayWireValue] = [:]
        if let costOption { selections["costOption"] = .integer(Int64(costOption)) }
        if let choiceKey, !choiceKey.isEmpty { selections["choiceKey"] = .string(choiceKey) }
        if ["QUEST_RESOLVE", "FACILITY_USE"].contains(operation) {
            busy = true; error = ""
            let read = await PlayThemeGameplayExchange.preview(client: client, view: view, operation: operation,
                contentID: contentID, choices: selections)
            busy = false
            guard let pack = read.pack else { error = read.error; return }
            preview = Preview(operation: operation, contentID: contentID, selections: selections, pack: pack)
            return
        }
        guard let command = PlayThemeGameplayExchange.command(view: view, operation: operation, contentID: contentID,
            actionID: PlayThemeGameplayExchange.newActionID(), selections: selections) else { error = "操作失败"; return }
        await send(command, client: client, applied: applied)
    }

    func confirmPreview(view: PlayWireValue, client: PlayRuntimeClient?, applied: @escaping @MainActor (PlayWireValue) async -> Void) async {
        guard !busy, let client, let preview, !preview.pack.overflow else { return }
        var selections = preview.selections
        selections["previewVersion"] = .string(preview.pack.previewVersion)
        self.preview = nil
        guard let command = PlayThemeGameplayExchange.command(view: view, operation: preview.operation, contentID: preview.contentID,
            actionID: PlayThemeGameplayExchange.newActionID(), selections: selections) else { error = "操作失败"; return }
        await send(command, client: client, applied: applied)
    }

    func cancelPreview() { if !busy { preview = nil } }

    func retry(client: PlayRuntimeClient?, applied: @escaping @MainActor (PlayWireValue) async -> Void) async {
        guard !busy, let client, let pendingCommand else { return }
        await send(pendingCommand, client: client, applied: applied)
    }

    private func send(_ command: [String: PlayWireValue], client: PlayRuntimeClient,
                      applied: @MainActor (PlayWireValue) async -> Void) async {
        pendingCommand = command; busy = true; error = ""
        let outcome = await PlayThemeGameplayExchange.action(client: client, command: command)
        busy = false
        switch outcome {
        case .applied(let receipt):
            pendingCommand = nil; unknown = false
            await applied(receipt)
        case .rejected(let message):
            pendingCommand = nil; unknown = false; error = message
        case .unknown:
            unknown = true; error = "操作结果未确认，点击重试"
        }
    }
}

@MainActor struct PlayThemeGameplayFlowSection: View {
    let flow: PlayThemeGameplayFlow
    let view: PlayWireValue
    let client: @MainActor () -> PlayRuntimeClient?
    let applied: @MainActor (PlayWireValue) async -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        if flow.preview != nil || !flow.error.isEmpty || flow.busy {
            Section {
                if let preview = flow.preview {
                    ForEach(preview.pack.owners.filter(\.own)) { owner in
                        ForEach(owner.rewards) { reward in
                            LabeledContent(reward.name) { Text(verbatim: "×\(reward.quantity)").monospacedDigit() }
                        }
                        LabeledContent(CYKitCopy(locale: locale)("Backpack", "背包")) { Text(verbatim: "\(owner.finalUsed) / \(owner.capacity)").monospacedDigit() }
                    }
                    if preview.pack.overflow {
                        // Discarding to make room is not offered natively yet; the button stays off.
                        Text(verbatim: CYKitCopy(locale: locale)("Your backpack is full. Make room before claiming.", "背包放不下，请先腾出空间"))
                            .foregroundStyle(CYColor.warningText)
                    }
                    CYPillButton(verbatim: CYKitCopy(locale: locale)("Confirm", "确认")) {
                        Task { await flow.confirmPreview(view: view, client: client(), applied: applied) }
                    }.disabled(preview.pack.overflow || flow.busy).accessibilityIdentifier("play.gameplay.confirm")
                    Button { flow.cancelPreview() } label: { Text(verbatim: CYKitCopy(locale: locale)("Cancel", "取消")) }
                }
                if flow.busy { ProgressView() }
                if !flow.error.isEmpty {
                    Text(verbatim: flow.error).foregroundStyle(flow.unknown ? CYColor.warningText : CYColor.dangerText)
                        .accessibilityIdentifier("play.gameplay.error")
                }
                if flow.unknown {
                    Button { Task { await flow.retry(client: client(), applied: applied) } } label: {
                        Text(verbatim: CYKitCopy(locale: locale)("Retry the same action", "重试原操作"))
                    }.disabled(flow.busy).accessibilityIdentifier("play.gameplay.retry")
                }
            }
        }
    }
}
