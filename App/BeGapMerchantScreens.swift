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
        .navigationTitle(Text("beGap.hub.title", tableName: "BeGapMerchant"))
        .accessibilityIdentifier("beGap.hub")
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
        }
    }
}

private struct BeGapSwitchRow: View {
    let titleKey: String
    let open: Bool

    var body: some View {
        LabeledContent {
            BeGapSwitchValue(open: open)
        } label: {
            BeGapTitle(key: titleKey)
        }
        .font(CYTypography.meta)
    }
}

private struct BeGapTitle: View {
    let key: String

    var body: some View {
        switch key {
        case "beGap.money.title": Text("beGap.money.title", tableName: "BeGapMerchant")
        case "beGap.payout.title": Text("beGap.payout.title", tableName: "BeGapMerchant")
        case "beGap.writes.title": Text("beGap.writes.title", tableName: "BeGapMerchant")
        default: Text("beGap.password.title", tableName: "BeGapMerchant")
        }
    }
}

private struct BeGapSwitchValue: View {
    let open: Bool

    var body: some View {
        if open {
            Text("beGap.switch.on", tableName: "BeGapMerchant")
        } else {
            Text("beGap.switch.off", tableName: "BeGapMerchant")
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
            Text("beGap.pay.note", tableName: "BeGapMerchant")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
        }
    }
}

private struct BeGapGateRow: View {
    let titleKey: String
    let open: Bool
    let refusalKey: String

    var body: some View {
        VStack(alignment: .leading) {
            BeGapTitle(key: titleKey)
            BeGapGateValue(open: open, refusalKey: refusalKey)
        }
    }
}

private struct BeGapGateValue: View {
    let open: Bool
    let refusalKey: String

    var body: some View {
        if open {
            Text("beGap.notSent", tableName: "BeGapMerchant")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("beGap.notSent")
        } else {
            BeGapRefusal(key: refusalKey)
        }
    }
}

private struct BeGapRefusal: View {
    let key: String

    var body: some View {
        switch key {
        case "beGap.money.refused":
            Text("beGap.money.refused", tableName: "BeGapMerchant")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("beGap.money.refused")
        case "beGap.payout.refused":
            Text("beGap.payout.refused", tableName: "BeGapMerchant")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("beGap.payout.refused")
        case "beGap.writes.refused":
            Text("beGap.writes.refused", tableName: "BeGapMerchant")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("beGap.writes.refused")
        default:
            Text("beGap.password.refused", tableName: "BeGapMerchant")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("beGap.password.refused")
        }
    }
}

private struct BeGapFactSection: View {
    var body: some View {
        Section {
            LabeledContent {
                Text("beGap.unknown", tableName: "BeGapMerchant")
            } label: {
                Text("beGap.fields.address", tableName: "BeGapMerchant")
            }
            LabeledContent {
                Text("beGap.unknown", tableName: "BeGapMerchant")
            } label: {
                Text("beGap.fields.status", tableName: "BeGapMerchant")
            }
            Text("beGap.notSent", tableName: "BeGapMerchant")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
        }
    }
}
