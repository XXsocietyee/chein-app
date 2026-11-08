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
            if order.isLegacy {
                text("order.legacy")
            } else if !order.hasBalanceDetail || order.balances.isEmpty {
                text("wallet.noDetail").accessibilityIdentifier("bundle.wallet.noDetail")
            } else {
                ForEach(order.balances, id: \.grantId) { balance in
                    Section {
                        LabeledContent { Text(verbatim: String(balance.unitsTotal)) } label: { text("wallet.unitsTotal") }
                        ForEach(balance.orderedCountKeys, id: \.self) { key in
                            LabeledContent {
                                Text(verbatim: String(balance.counts[key] ?? 0))
                            } label: {
                                if let known = BundleOrderStatusPresentation.unitStatusKey(key) { text(known) }
                                else { Text(verbatim: key) }
                            }
                        }
                        LabeledContent { Text(verbatim: balance.validFrom.raw) } label: { text("wallet.validFrom") }
                        LabeledContent { Text(verbatim: balance.validTo.raw) } label: { text("wallet.validTo") }
                        if balance.expired { text("wallet.expired").accessibilityIdentifier("bundle.wallet.expired") }
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
    }
}
