import SwiftUI

/// Mini-program "我的" entries for the pages built on ui/mpmissing: passes and gifts (`market/passes`),
/// invites and earnings (`subpackageJourney/pages/promo`), and the creator video bounty (`video-bounty`, reached from
/// earnings in the mini-program). Each row needs its binding; with none injected the whole section is absent.
@MainActor struct MPParityAccountLinks: View {
    @Environment(\.mpParity) private var bindings

    var body: some View {
        // 通行证与礼品 lives under 资产 (`MPPassAssetsLink`), as in the mini-program profile.
        if bindings.journeyPromo != nil || bindings.videoBounty != nil {
            Section {
                if bindings.journeyPromo != nil {
                    NavigationLink { MPParityDestination(route: .journeyPromo) } label: {
                        CYListRow("mp.account.promo", trailing: .none) { CYRowIcon(systemImage: "person.2.wave.2") }
                    }
                    .accessibilityIdentifier("account.mp.promo")
                }
                if bindings.videoBounty != nil {
                    NavigationLink { MPParityDestination(route: .videoBounty(campaignKey: nil, topicID: nil)) } label: {
                        CYListRow("mp.account.videoBounty", trailing: .none) { CYRowIcon(systemImage: "film") }
                    }
                    .accessibilityIdentifier("account.mp.videoBounty")
                }
            } header: {
                Text("mp.account.section")
            }
        }
    }
}

/// Mini-program 我的 → 通行证与礼品 (`components/cy/profile` goPasses): a row inside the assets section, after the wallet
/// (qx-b5: passes and gifts are the player's own purchase records). Hidden for merchants (`!isMerchantView`) and without a binding.
@MainActor struct MPPassAssetsLink: View {
    @Environment(\.mpParity) private var bindings

    var body: some View {
        if bindings.passMarket != nil, !bindings.isMerchant {
            NavigationLink { MPParityDestination(route: .passes(tab: .shop)) } label: {
                CYListRow("mp.account.passes", trailing: .none) { CYRowIcon(systemImage: "ticket") }
            }
            .accessibilityIdentifier("account.mp.passes")
        }
    }
}
