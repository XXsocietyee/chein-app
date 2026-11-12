import SwiftUI

/// Mini-program "我的" entries for the pages built on ui/mpmissing: passes and gifts (`market/passes`),
/// invites and earnings (`subpackageJourney/pages/promo`), and the creator video bounty (`video-bounty`, reached from
/// earnings in the mini-program). Each row needs its binding; with none injected the whole section is absent.
@MainActor struct MPParityAccountLinks: View {
    @Environment(\.mpParity) private var bindings

    var body: some View {
        if bindings.passMarket != nil || bindings.journeyPromo != nil || bindings.videoBounty != nil {
            Section {
                if bindings.passMarket != nil {
                    NavigationLink { MPParityDestination(route: .passes(tab: .shop)) } label: {
                        CYListRow("mp.account.passes", trailing: .none) { CYRowIcon(systemImage: "ticket") }
                    }
                    .accessibilityIdentifier("account.mp.passes")
                }
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
