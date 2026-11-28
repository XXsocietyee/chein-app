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
            Text(verbatim: LocaleDisplay.monthDay(month: month, day: day, locale: locale) ?? "\(month)月\(day)日")
        }
    }
}

/// Zero balance on 账户收益 (还没有收益). PC-D-5-4: the first-use empty state names its next step, the source CTA
/// 去发布路线 (switches to the 发布 tab where the root tab switch exists).
struct WalletEarningsEmptyNote: View {
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    var body: some View {
        // Native r2: the system ContentUnavailableView. Round 4 image parity: MP `cy-empty kind="empty"`
        // (scene-asset-earnings/index.wxml:22) draws `images/empty_state_bg.svg` + `empty_state_figure.svg`;
        // the shared illustration stays as the icon. Round 4 copy: MP has the title only (还没有收益, no sub line).
        ContentUnavailableView {
            Label {
                Text("member.wallet.noEarnings", tableName: "MemberProfile")
                    .accessibilityIdentifier("wallet.earnings.empty")
            } icon: {
                CYEmptyIllustration(kind: .generic, size: 96)
            }
        } description: {
            EmptyView()
        } actions: {
            if rootTabSwitch.isAvailable {
                Button { rootTabSwitch(.publish) } label: { Text("wallet.earnings.goPublish") }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("wallet.earnings.goPublish")
            }
        }
    }
}
