import SwiftUI

/// 今天 / 昨天 / M月D日 for income rows (mini-program income-detail).
struct WalletIncomeDayText: View {
    let day: WalletIncomeDay
    @Environment(\.locale) private var locale
    var body: some View {
        switch day {
        case .today: Text("member.wallet.today", tableName: "MemberProfile")
        case .yesterday: Text("member.wallet.yesterday", tableName: "MemberProfile")
        case .monthDay(let month, let day):
            if locale.language.languageCode?.identifier == "zh" { Text(verbatim: "\(month)月\(day)日") }
            else { Text(verbatim: "\(month)/\(day)") }
        }
    }
}

/// Zero balance on 账户收益 (还没有收益). PC-D-5-4: the first-use empty state names its next step, the source CTA
/// 去发布路线 (switches to the 发布 tab where the root tab switch exists).
struct WalletEarningsEmptyNote: View {
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text("member.wallet.noEarnings", tableName: "MemberProfile").cyText(.cardTitle)
                Text("member.wallet.noEarningsHint", tableName: "MemberProfile").cyText(.bodyCompact).foregroundStyle(.secondary)
            }.accessibilityElement(children: .combine).accessibilityIdentifier("wallet.earnings.empty")
            if rootTabSwitch.isAvailable {
                CYPillButton("wallet.earnings.goPublish", style: .secondary, fullWidth: false) { rootTabSwitch(.publish) }
                    .accessibilityIdentifier("wallet.earnings.goPublish")
            }
        }
    }
}
