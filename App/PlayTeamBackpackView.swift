import SwiftUI

/// TEAM backpack commands. Personal `PlayThemeBackpackView` stays on `api/play/theme/action`.
/// Unknown command results render an em dash and are not a success.
@available(macOS 14.0, *)
@MainActor struct PlayTeamBackpackView: View {
    @Bindable var model: PlayTeamBackpackCoordinator
    var body: some View {
        List {
            stateRows
            if model.phase == .ready { itemRows }
            if model.phase == .ready, !model.pending.isEmpty { pendingRows }
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
                .accessibilityLabel(Text("play.teamBackpack.loading"))
                .accessibilityIdentifier("play.teamBackpack.loading")
        case .empty:
            Text("play.teamBackpack.empty")
                .accessibilityIdentifier("play.teamBackpack.empty")
        case .failed:
            Text("play.teamBackpack.failed")
                .foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("play.teamBackpack.failed")
            Button("play.teamBackpack.retry") { Task { await model.reload() } }
                .accessibilityIdentifier("play.teamBackpack.retry")
        case .ready:
            EmptyView()
        }
    }

    @ViewBuilder private var itemRows: some View {
        Section("play.teamBackpack.items") {
            ForEach(model.items) { item in
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    itemTitle(item.name, quantity: item.quantity)
                    HStack {
                        if model.canUse {
                            commandButton("play.teamBackpack.use", enabled: item.usable, id: "play.teamBackpack.use." + item.id) {
                                Task { await model.use(item.id) }
                            }
                        }
                        if model.canDiscard {
                            commandButton("play.teamBackpack.discard", enabled: item.discardable, id: "play.teamBackpack.discard." + item.id) {
                                Task { await model.discard(item.id) }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("play.teamBackpack.item." + item.id)
            }
        }
    }

    @ViewBuilder private var pendingRows: some View {
        Section("play.teamBackpack.pending") {
            ForEach(model.pending) { item in
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    itemTitle(item.name, quantity: item.quantity)
                    if model.canReceive {
                        commandButton("play.teamBackpack.receive", enabled: true, id: "play.teamBackpack.receive." + item.id) {
                            Task { await model.receive(item.id) }
                        }
                    }
                }
                .accessibilityIdentifier("play.teamBackpack.pending." + item.id)
            }
        }
    }

    @ViewBuilder private var receiptRows: some View {
        Section("play.teamBackpack.receipt") {
            receiptLabel
            LabeledContent("play.teamBackpack.outcome") { Text(verbatim: model.receipt.outcome).monospacedDigit() }
            LabeledContent("play.teamBackpack.receiptID") { Text(verbatim: model.receipt.receiptID).monospacedDigit() }
            LabeledContent("play.teamBackpack.revision") { Text(verbatim: model.receipt.revision).monospacedDigit() }
            if let message = model.receipt.serverMessage, !message.isEmpty {
                Text(verbatim: message).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityIdentifier("play.teamBackpack.receipt")
    }

    @ViewBuilder private var receiptLabel: some View {
        switch model.receipt.kind {
        case .applied:
            Text("play.teamBackpack.applied").accessibilityIdentifier("play.teamBackpack.applied")
        case .failed:
            Text("play.teamBackpack.failedOutcome").accessibilityIdentifier("play.teamBackpack.failedOutcome")
        case .business:
            Text("play.teamBackpack.failedOutcome").accessibilityIdentifier("play.teamBackpack.business")
        case .unknown:
            Text("play.teamBackpack.unknown").accessibilityIdentifier("play.teamBackpack.unknown")
        case .refused:
            Text("play.teamBackpack.refused").accessibilityIdentifier("play.teamBackpack.refused")
        case .blank:
            EmptyView()
        }
    }

    private func itemTitle(_ name: String?, quantity: Int?) -> some View {
        let title = name ?? PlayTeamCommandInterpretation.dash
        let count = quantity.map(String.init) ?? PlayTeamCommandInterpretation.dash
        return LabeledContent { Text(verbatim: count).monospacedDigit() } label: { Text(verbatim: title) }
    }

    private func commandButton(_ title: LocalizedStringKey, enabled: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .disabled(!enabled || model.busy)
            .accessibilityIdentifier(id)
    }
}
