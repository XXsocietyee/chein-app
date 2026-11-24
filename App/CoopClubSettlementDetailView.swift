import SwiftUI

/// MC7-35-1 / MP `pages/coop/settlement-detail?source=club`: one club 分润 row from `POST api/club/settlement/summary`
/// (`CoopFlowRead.clubSettlementSummary`), rendered as the MP `buildClubSettlementDetail`. Amounts are the server's
/// strings (`CoopClubSettlementDetail`); nothing is computed or withdrawn here.
@MainActor struct CoopClubSettlementDetailView: View {
    let reader: any CoopFlowReading
    let link: MerchantSettlementDetailLink
    private enum Phase: Equatable { case loading, ready(CoopClubSettlementDetail), missing, failed(String?) }
    @State private var phase: Phase = .loading
    @State private var attempt = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .navigationTitle(Text("merchantCoop.settlement.title")).navigationBarTitleDisplayMode(.inline)
            .cyDomainScreen(.merchant)
            .task(id: attempt) { await load() }
            .refreshable { await load() }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            CYSkeleton(variant: .detail).padding(CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("coop.clubSettlement.loading")
        case .missing:
            MerchantCoopActionState(systemImage: "doc.text.magnifyingglass", title: "merchantCoop.settlement.missing",
                                    actionTitle: "merchantCoop.settlement.back", action: { dismiss() },
                                    identifier: "coop.clubSettlement.missing")
        case .failed(let message):
            MerchantCoopActionState(systemImage: "exclamationmark.triangle", title: "merchantCoop.settlement.failed",
                                    message: message.map { LocalizedStringKey(stringLiteral: $0) },
                                    actionTitle: "action.retry", action: { attempt += 1 },
                                    identifier: "coop.clubSettlement.failed")
        case .ready(let detail):
            List {
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: detail.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text("merchantCoop.settlement.clubPerspective").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        Text(verbatim: detail.amountLabel).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        Text(verbatim: detail.amountText).cyText(.display, monospacedDigit: true).foregroundStyle(CYColor.textPrimary)
                        Text(verbatim: detail.statusText).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("coop.clubSettlement.hero")
                }
                Section {
                    line("merchantCoop.settlement.lineType", detail.lineTypeText)
                    line("merchantCoop.settlement.original", detail.originalAmountText)
                    line("merchantCoop.settlement.adjustment", detail.executedAdjustmentText)
                    line("merchantCoop.settlement.net", detail.netAmountText).fontWeight(.semibold)
                }
                Section {
                    line("merchantCoop.settlement.arrived", detail.arrivedText)
                    line("merchantCoop.settlement.paid", detail.paidText)
                }
            }
            .accessibilityIdentifier("coop.clubSettlement.detail")
        }
    }

    @ViewBuilder private func line(_ label: LocalizedStringKey, _ value: String) -> some View {
        if !value.isEmpty {
            LabeledContent { Text(verbatim: value).monospacedDigit() } label: { Text(label) }
        }
    }

    private func load() async {
        guard let clubID = link.clubID else { phase = .missing; return }
        if case .ready = phase {} else { phase = .loading }
        do {
            let value = try await reader.read(.clubSettlementSummary(clubID: clubID, personal: link.personal))
            let rows = value["topics"].rows ?? []
            let match = rows.first { row in
                let raw = row[link.recordKey]
                return (raw.integer.map(String.init) ?? raw.text) == link.recordID
            }
            guard let match else { phase = .missing; return }
            guard let detail = CoopClubSettlementDetail.resolve(match) else { phase = .failed(nil); return }
            phase = .ready(detail)
        } catch CoopFlowFailure.server(_, let message) {
            phase = .failed(message)
        } catch {
            phase = .failed(nil)
        }
    }
}
