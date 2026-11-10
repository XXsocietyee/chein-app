import SwiftUI

/// T-06, per order. The cross-order list needs backend B-04; until then the caller injects `loadWallet`, satisfied
/// by the existing single-order host entry. This view never loops `api/registration/list` to fake a list.
/// Counts, validity window and the expired flag are rendered exactly as the server sent them.
@MainActor struct BundleWalletView: View {
    let order: BundleOrderReadModel
    private let table = BundleOrderStatusPresentation.table
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    var body: some View {
        Form {
            Section { CYHeroHeader(verbatim: W8Text.t("次卡钱包", "Bundle wallet")) }.e1HeroRow()
            if order.isLegacy {
                text("order.legacy")
            } else if !order.hasBalanceDetail || order.balances.isEmpty {
                CYEmptyState(systemImage: "wallet.pass", "wallet.noDetail", tableName: table, messageIdentifier: "bundle.wallet.noDetail")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(order.balances, id: \.grantId) { balance in
                    Section {
                        LabeledContent { Text(verbatim: String(balance.unitsTotal)).font(CYTypography.numericBody) } label: { text("wallet.unitsTotal") }
                        ForEach(balance.orderedCountKeys, id: \.self) { key in
                            LabeledContent {
                                Text(verbatim: balance.counts[key].map { String($0) } ?? "—").monospacedDigit()
                            } label: {
                                if let known = BundleOrderStatusPresentation.unitStatusKey(key) { text(known) }
                                else { Text(verbatim: key) }
                            }
                        }
                        LabeledContent { Text(verbatim: balance.validFrom.raw) } label: { text("wallet.validFrom") }
                        LabeledContent { Text(verbatim: balance.validTo.raw) } label: { text("wallet.validTo") }
                        if balance.expired {
                            HStack(spacing: CYSpacing.sm) {
                                Image(systemName: "clock.badge.exclamationmark").accessibilityHidden(true)
                                text("wallet.expired")
                            }
                            .foregroundStyle(CYColor.warningText)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("bundle.wallet.expired")
                        }
                    }
                }
            }
            if !order.units.isEmpty {
                Section {
                    ForEach(order.units, id: \.id) { unit in
                        LabeledContent {
                            if let key = BundleOrderStatusPresentation.unitStatusKey(unit) { text(key) }
                            else { Text(verbatim: unit.status) }
                        } label: { Text(verbatim: unit.unitCode ?? unit.id.text) }
                    }
                } header: { text("wallet.entries") }
            }
        }
        .formStyle(.grouped)
        .cyGroupedSurface()
        .cyHeroScreen()
    }
}
