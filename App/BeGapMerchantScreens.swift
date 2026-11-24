import SwiftUI

/// Merchant-gap screens. They stay visible when the switches are off and never report a write as done.
struct BeGapMerchantHubView: View {
    private let access = ReviewedAreaSwitch.current

    var body: some View {
        List {
            BeGapSwitchSection(access: access)
            BeGapGateSection(access: access)
            BeGapFactSection()
        }
        .navigationTitle(Text("beGap.hub.title", tableName: "BeGapMerchant")).navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("beGap.hub")
        .cyDomainScreen(.merchant)
    }
}

private struct BeGapSwitchSection: View {
    let access: ReviewedAreaSwitch.Access

    var body: some View {
        Section {
            BeGapSwitchRow(titleKey: "beGap.money.title", open: access.moneyPayments)
            BeGapSwitchRow(titleKey: "beGap.payout.title", open: access.payout)
            BeGapSwitchRow(titleKey: "beGap.writes.title", open: access.merchantWrites)
            BeGapSwitchRow(titleKey: "beGap.password.title", open: access.passwordLogin)
        } header: {
            Text("beGap.switches.title", tableName: "BeGapMerchant")
                .accessibilityAddTraits(.isHeader)
        }
    }
}

private struct BeGapSwitchRow: View {
    let titleKey: String
    let open: Bool

    var body: some View {
        CurA11yLabeled(
            title: BeGapTitleText.make(titleKey),
            value: open ? Text("beGap.switch.on", tableName: "BeGapMerchant") : Text("beGap.switch.off", tableName: "BeGapMerchant"),
            hint: Text("curA11y.beGap.switch.hint", tableName: "CurA11y"),
            selected: open
        )
    }
}

private enum BeGapTitleText {
    static func make(_ key: String) -> Text {
        switch key {
        case "beGap.money.title":
            return Text("beGap.money.title", tableName: "BeGapMerchant")
        case "beGap.payout.title":
            return Text("beGap.payout.title", tableName: "BeGapMerchant")
        case "beGap.writes.title":
            return Text("beGap.writes.title", tableName: "BeGapMerchant")
        default:
            return Text("beGap.password.title", tableName: "BeGapMerchant")
        }
    }
}

private struct BeGapGateSection: View {
    let access: ReviewedAreaSwitch.Access

    var body: some View {
        Section {
            BeGapGateRow(titleKey: "beGap.money.title", open: access.moneyPayments, refusalKey: "beGap.money.refused")
            BeGapGateRow(titleKey: "beGap.payout.title", open: access.payout, refusalKey: "beGap.payout.refused")
            BeGapGateRow(titleKey: "beGap.writes.title", open: access.merchantWrites, refusalKey: "beGap.writes.refused")
            BeGapGateRow(titleKey: "beGap.password.title", open: access.passwordLogin, refusalKey: "beGap.password.refused")
            CurA11yNotice(
                text: Text("beGap.pay.note", tableName: "BeGapMerchant"),
                hint: Text("curA11y.beGap.note.hint", tableName: "CurA11y"),
                tone: CYColor.textSecondary
            )
        }
    }
}

private struct BeGapGateRow: View {
    let titleKey: String
    let open: Bool
    let refusalKey: String

    var body: some View {
        CurA11yLabeled(
            title: BeGapTitleText.make(titleKey),
            value: open ? Text("beGap.notSent", tableName: "BeGapMerchant") : BeGapRefusalText.make(refusalKey),
            hint: Text("curA11y.beGap.gate.hint", tableName: "CurA11y"),
            selected: open,
            identifier: open ? "beGap.notSent" : refusalKey
        )
    }
}

private enum BeGapRefusalText {
    static func make(_ key: String) -> Text {
        switch key {
        case "beGap.money.refused":
            return Text("beGap.money.refused", tableName: "BeGapMerchant")
        case "beGap.payout.refused":
            return Text("beGap.payout.refused", tableName: "BeGapMerchant")
        case "beGap.writes.refused":
            return Text("beGap.writes.refused", tableName: "BeGapMerchant")
        default:
            return Text("beGap.password.refused", tableName: "BeGapMerchant")
        }
    }
}

private struct BeGapFactSection: View {
    var body: some View {
        Section {
            CurA11yLabeled(
                title: Text("beGap.fields.address", tableName: "BeGapMerchant"),
                value: Text("beGap.unknown", tableName: "BeGapMerchant"),
                spokenValue: Text("curA11y.unknown", tableName: "CurA11y"),
                hint: Text("curA11y.beGap.fact.hint", tableName: "CurA11y")
            )
            CurA11yLabeled(
                title: Text("beGap.fields.status", tableName: "BeGapMerchant"),
                value: Text("beGap.unknown", tableName: "BeGapMerchant"),
                spokenValue: Text("curA11y.unknown", tableName: "CurA11y"),
                hint: Text("curA11y.beGap.fact.hint", tableName: "CurA11y")
            )
            CurA11yNotice(
                text: Text("beGap.notSent", tableName: "BeGapMerchant"),
                hint: Text("curA11y.beGap.gate.hint", tableName: "CurA11y"),
                tone: CYColor.textSecondary
            )
        }
    }
}
