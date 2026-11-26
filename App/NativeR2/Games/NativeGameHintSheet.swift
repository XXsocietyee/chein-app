import SwiftUI

/// The hint ladder as a native `List` sheet (`.medium` / `.large`), opened from the game toolbar.
/// Same server facts and writes as `PlayHelpLadderPanel`: rows in the author's order, the free
/// count and charges come from the server, each paid or free use is confirmed first, skip is
/// destructive and confirmed. Only the UI is new.
@MainActor struct NativeGameHintSheet: View {
    @Bindable var model: PlayHelpLadderModel
    var teamPool: TeamPoolHintModel? = nil
    var approvedArtworkHosts: Set<String> = []
    var onPoolTrimmed: () -> Void = {}
    var analyticsNodeID: Int? = nil
    var analyticsKit: String? = nil
    let close: () -> Void
    @State private var confirmLevel: Int?
    @State private var confirmSkip = false
    @Environment(\.offlineWriteSession) private var offlineWriteSession
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            List {
                if !model.rows.isEmpty {
                    Section {
                        ForEach(model.rows) { row in layerRow(row) }
                    } header: {
                        Text("nativeGames.hint.layers")
                    } footer: {
                        freeLeftFooter
                    }
                } else {
                    Section { EmptyView() } footer: { freeLeftFooter }
                }
                if let teamPool, teamPool.isVisible {
                    Section { TeamPoolHintSection(model: teamPool) }
                }
                if model.showsSkip { skipSection }
                if let notice = model.notice {
                    Section {
                        Label { noticeText(notice) } icon: { Image(systemName: "exclamationmark.triangle") }
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("playHelp.notice")
                    }
                }
                receiptSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("hint.sheet.title", tableName: "DesignR1"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("nativeGames.done", action: close).accessibilityIdentifier("playHelp.close")
                }
            }
            .confirmationDialog(confirmTitle, isPresented: confirmLevelShown, titleVisibility: .visible) {
                Button("playHelp.view") {
                    let level = confirmLevel
                    confirmLevel = nil
                    if let level { use(level) }
                }
                .accessibilityIdentifier("playHelp.confirm")
                Button("playHelp.cancel", role: .cancel) { confirmLevel = nil }
                    .accessibilityIdentifier("playHelp.cancel")
            } message: {
                Text(verbatim: confirmMessage)
            }
            .confirmationDialog(Text("playHelp.skip"), isPresented: $confirmSkip, titleVisibility: .visible) {
                Button("playHelp.skip.confirm", role: .destructive) {
                    confirmSkip = false
                    PlayStageAnalytics.track(analytics, .stageSkip, nodeID: analyticsNodeID, kit: analyticsKit)
                    skip()
                }
                .accessibilityIdentifier("playHelp.skip.confirm")
                Button("playHelp.cancel", role: .cancel) { confirmSkip = false }
                    .accessibilityIdentifier("playHelp.skip.cancel")
            } message: {
                Text("playHelp.skip.consequence")
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("playHelp.panel")
        .onAppear {
            model.markSavedRequests()
            PlayStageAnalytics.track(analytics, .hintOpen, nodeID: analyticsNodeID, kit: analyticsKit)
        }
        .onChange(of: model.poolTrimGeneration) { _, _ in onPoolTrimmed() }
    }

    private var confirmLevelShown: Binding<Bool> {
        Binding(get: { confirmLevel != nil }, set: { if !$0 { confirmLevel = nil } })
    }

    private var confirmTitle: Text {
        guard let level = confirmLevel, let row = model.row(level) else { return Text("nativeGames.hint") }
        return Text(LocalizedStringKey(row.typeLabelKey))
    }

    private var confirmMessage: String {
        guard let level = confirmLevel, let row = model.row(level) else { return "" }
        return row.state == .cost
            ? appLocalized("playHelp.confirm.cost \(row.cost)", locale: locale)
            : appLocalized("playHelp.confirm.free", locale: locale)
    }

    @ViewBuilder private var freeLeftFooter: some View {
        if let left = model.freeLeft {
            if left > 0 {
                Text("playHelp.freeLeft \(left)").accessibilityIdentifier("playHelp.freeLeft")
            }
        } else {
            Text("hint.freeLeft.unknown", tableName: "DesignR1").accessibilityIdentifier("playHelp.freeLeft")
        }
    }

    private func layerRow(_ row: PlayHelpRow) -> some View {
        Button { tap(row) } label: {
            VStack(alignment: .leading, spacing: 6) {
                LabeledContent {
                    if model.busyLevel == row.level {
                        ProgressView().accessibilityLabel(Text("playHelp.sending"))
                    } else {
                        actionText(row)
                    }
                } label: {
                    Text(LocalizedStringKey(row.typeLabelKey)).foregroundStyle(.primary)
                }
                if let content = row.content { contentView(content, type: row.contentType ?? row.type, level: row.level) }
                if let charged = row.chargedPoints, charged > 0 {
                    Group {
                        if let balance = row.balanceAfter { Text("playHelp.charged \(charged) \(balance)") }
                        else { Text("playHelp.chargedOnly \(charged)") }
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("playHelp.charged.\(row.level)")
                }
                if let problem = row.problem {
                    problemText(problem).font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier("playHelp.problem.\(row.level)")
                }
            }
        }
        .disabled(!row.tappable || model.busy)
        .accessibilityIdentifier("playHelp.row.\(row.level)")
    }

    @ViewBuilder private func contentView(_ content: String, type: String, level: Int) -> some View {
        if type == "IMAGE" {
            PlayKitArtwork(source: content, approvedHosts: approvedArtworkHosts)
                .accessibilityLabel(Text("playHelp.type.image"))
                .accessibilityIdentifier("playHelp.content.\(level)")
        } else {
            Text(verbatim: content)
                .font(type == "LETTER" || type == "DIGIT" ? .title.bold() : .body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
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

    @ViewBuilder private func problemText(_ problem: PlayHelpRow.Problem) -> some View {
        switch problem {
        case .pending: Text("playHelp.pending")
        case .insufficient: Text("playHelp.insufficient")
        case .refused(let message):
            if let message, !message.isEmpty { Text(verbatim: message) } else { Text("playHelp.refused") }
        }
    }

    @ViewBuilder private func noticeText(_ notice: PlayHelpLadderModel.Notice) -> some View {
        switch notice {
        case .storageUnavailable: Text("playHelp.storageUnavailable")
        case .pending: Text("playHelp.pending")
        case .refused(let message):
            if let message, !message.isEmpty { Text(verbatim: message) } else { Text("playHelp.skip.refused") }
        }
    }

    private var skipSection: some View {
        Section {
            Button(role: .destructive) {
                if model.skipPending { skip() } else { confirmSkip = true }
            } label: {
                LabeledContent {
                    if model.skipPending { Text("playHelp.keepChecking") }
                } label: {
                    Text("playHelp.skip").foregroundStyle(.red)
                }
            }
            .disabled(model.busy)
            .accessibilityIdentifier("playHelp.skip")
        }
    }

    private var receiptSection: some View {
        Section {
            DisclosureGroup(isExpanded: Binding(get: { model.receiptOpen }, set: { _ in Task { await model.toggleReceipt() } })) {
                if model.receiptUnavailable {
                    Text("playHelp.receipt.unavailable").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("playHelp.receipt.unavailable")
                } else if let lines = model.receipt {
                    PlayHelpReceiptLines(lines: lines)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            } label: {
                Text("playHelp.receipt")
            }
            .accessibilityIdentifier("playHelp.receipt")
        }
    }

    private func tap(_ row: PlayHelpRow) {
        guard row.tappable, !model.busy else { return }
        if row.needsConfirmation { confirmLevel = row.level } else { Task { await model.use(row.level) } }
    }

    private func use(_ level: Int) {
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineWriteSession.session,
                routes: ["/api/play/help/use"]
            ) {
                await model.use(level)
            }
        }
    }

    private func skip() {
        Task {
            await SessionOfflineSyncModel.shared.performWriteOptIn(
                environmentSession: offlineWriteSession.session,
                routes: ["/api/play/help/skip"]
            ) {
                await model.skip()
            }
        }
    }
}
