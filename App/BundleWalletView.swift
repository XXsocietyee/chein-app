import SwiftUI

/// T-06, per order. The cross-order list needs backend B-04; until then the caller injects `loadWallet`, satisfied
/// by the existing single-order host entry. This view never loops `api/registration/list` to fake a list.
/// Counts, validity window and the expired flag are rendered exactly as the server sent them.
@MainActor struct BundleWalletView: View {
    let order: BundleOrderReadModel
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    private let table = BundleOrderStatusPresentation.table
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader(verbatim: screenTitle)
                balances
                if !order.units.isEmpty {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        text("wallet.entries")
                            .cyText(.sectionTitle)
                            .foregroundStyle(palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(order.units, id: \.id) { unit in
                            CYListRow(
                                verbatim: WalletCopy.server(unit.unitCode ?? unit.id.text),
                                trailing: .value(unitStatus(unit)),
                                card: true
                            ) {
                                CYRowIcon(systemImage: "ticket")
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.top, CYSpacing.lg)
            .padding(.bottom, CYSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cyDomainPageBackground()
        .themeDomain(.player)
        .cyHeroScreen()
        .appSwitcherPrivacyShield()
    }

    /// Page title. Catalog key `ui.cloud05.wallet.title` (docs/release/ui-strings-cloud-05.json).
    private var screenTitle: String {
        WalletCopy.resolved("ui.cloud05.wallet.title", en: "Bundle balance", zh: "套餐余额", locale: locale)
    }

    @ViewBuilder private var balances: some View {
        if order.isLegacy {
            CYEmptyState(systemImage: "tray", "order.legacy", tableName: table)
        } else if !order.hasBalanceDetail || order.balances.isEmpty {
            CYEmptyState(systemImage: "tray", "wallet.noDetail", tableName: table, messageIdentifier: "bundle.wallet.noDetail")
        } else {
            ForEach(order.balances, id: \.grantId) { balance in
                balanceCard(balance)
            }
        }
    }

    private func balanceCard(_ balance: BundleBalanceRow) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            text("wallet.unitsTotal")
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Text(verbatim: String(balance.unitsTotal))
                .cyText(.data2XL)
                .foregroundStyle(palette.textPrimary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(text("wallet.unitsTotal"))
                .accessibilityValue(Text(verbatim: String(balance.unitsTotal)))
            ForEach(balance.orderedCountKeys, id: \.self) { key in
                CYListRow(verbatim: countLabel(key), trailing: .value(countText(balance.counts[key]))) {
                    CYRowIcon(systemImage: "circle.grid.2x2")
                }
            }
            CYFactRow(label: text("wallet.validFrom"), value: WalletCopy.server(balance.validFrom.raw))
            CYFactRow(label: text("wallet.validTo"), value: WalletCopy.server(balance.validTo.raw))
            if balance.expired {
                CYStatusChip(verbatim: WalletCopy.bundle("wallet.expired"), tone: .warning, systemImage: "clock.badge.exclamationmark")
                    .accessibilityIdentifier("bundle.wallet.expired")
                    .accessibilityLabel(text("wallet.expired"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard()
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
