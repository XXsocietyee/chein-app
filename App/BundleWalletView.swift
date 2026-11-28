import SwiftUI

/// T-06, per order. The cross-order list needs backend B-04; until then the caller injects `loadWallet`, satisfied
/// by the existing single-order host entry. This view never loops `api/registration/list` to fake a list.
/// Counts, validity window and the expired flag are rendered exactly as the server sent them.
@MainActor struct BundleWalletView: View {
    let order: BundleOrderReadModel
    @Environment(\.locale) private var locale
    private let table = BundleOrderStatusPresentation.table
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        // Native r2: an inset-grouped list with a system inline title; facts are LabeledContent.
        List {
            balances
            if !order.units.isEmpty {
                Section {
                    ForEach(order.units, id: \.id) { unit in
                        LabeledContent {
                            Text(verbatim: unitStatus(unit))
                        } label: {
                            Label { Text(verbatim: WalletCopy.server(unit.unitCode ?? unit.id.text)) } icon: { Image(systemName: "ticket") }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    text("wallet.entries")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text(verbatim: screenTitle))
        .navigationBarTitleDisplayMode(.inline)
        .themeDomain(.player)
        .appSwitcherPrivacyShield()
    }

    /// Page title. Catalog key `ui.cloud05.wallet.title` (docs/release/ui-strings-cloud-05.json).
    private var screenTitle: String {
        WalletCopy.resolved("ui.cloud05.wallet.title", en: "Bundle balance", zh: "套餐余额", locale: locale)
    }

    @ViewBuilder private var balances: some View {
        if order.isLegacy {
            Section {
                ContentUnavailableView {
                    Label { text("order.legacy") } icon: { Image(systemName: "tray") }
                }
            }
        } else if !order.hasBalanceDetail || order.balances.isEmpty {
            Section {
                ContentUnavailableView {
                    Label {
                        text("wallet.noDetail").accessibilityIdentifier("bundle.wallet.noDetail")
                    } icon: {
                        Image(systemName: "tray")
                    }
                }
            }
        } else {
            ForEach(order.balances, id: \.grantId) { balance in
                Section { balanceRows(balance) }
            }
        }
    }

    @ViewBuilder private func balanceRows(_ balance: BundleBalanceRow) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            text("wallet.unitsTotal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Text(verbatim: String(balance.unitsTotal))
                .cyText(.dataXL)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(text("wallet.unitsTotal"))
                .accessibilityValue(Text(verbatim: String(balance.unitsTotal)))
        }
        .padding(.vertical, CYSpacing.xs)
        ForEach(balance.orderedCountKeys, id: \.self) { key in
            LabeledContent {
                Text(verbatim: countText(balance.counts[key])).monospacedDigit()
            } label: {
                Label { Text(verbatim: countLabel(key)) } icon: { Image(systemName: "circle.grid.2x2") }
            }
        }
        LabeledContent { Text(verbatim: WalletCopy.server(balance.validFrom.raw)) } label: { text("wallet.validFrom") }
        LabeledContent { Text(verbatim: WalletCopy.server(balance.validTo.raw)) } label: { text("wallet.validTo") }
        if balance.expired {
            Label {
                Text(verbatim: WalletCopy.bundle("wallet.expired"))
            } icon: {
                Image(systemName: "clock.badge.exclamationmark").foregroundStyle(CYColor.warningText)
            }
                .accessibilityIdentifier("bundle.wallet.expired")
                .accessibilityLabel(text("wallet.expired"))
        }
    }

    /// A missing count is an em dash. A real 0 stays 0.
    private func countText(_ value: Int?) -> String {
        guard let value else { return "—" }
        return String(value)
    }

    private func countLabel(_ key: String) -> String {
        if let known = BundleOrderStatusPresentation.unitStatusKey(key) { return WalletCopy.bundle(known) }
        return WalletCopy.server(key)
    }

    private func unitStatus(_ unit: BundleUnitRow) -> String {
        if let key = BundleOrderStatusPresentation.unitStatusKey(unit) { return WalletCopy.bundle(key) }
        return WalletCopy.server(unit.status)
    }
}

private enum WalletCopy {
    static func resolved(_ key: String, en: String, zh: String, locale: Locale) -> String {
        let resolved = String(localized: String.LocalizationValue(stringLiteral: key))
        if resolved == key || resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CYKitCopy(locale: locale)(en, zh)
        }
        return resolved
    }

    static func bundle(_ key: String) -> String {
        let resolved = String(localized: String.LocalizationValue(stringLiteral: key), table: "BundleCommerce")
        if resolved == key || resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "—" }
        return resolved
    }

    static func server(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "—" }
        if trimmed.range(of: #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#, options: .regularExpression) != nil {
            return "—"
        }
        return trimmed
    }
}
