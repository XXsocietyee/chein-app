import SwiftUI

/// Mini-program "我的" entries for the pages built on ui/mpmissing: passes and gifts (`market/passes`),
/// invites and earnings (`subpackageJourney/pages/promo`), and the creator video bounty (`video-bounty`, reached from
/// earnings in the mini-program). Each row needs its binding; with none injected the whole section is absent.
@MainActor struct MPParityAccountLinks: View {
    @Environment(\.mpParity) private var bindings
    @EnvironmentObject private var session: AppSession
    @State private var showsRedeem = false
    /// mp-mine r3: MP 项目 order puts 视频悬赏 before 我的资产; the app-only host-tip rows come after it.
    enum Part { case all, bounty, extras }
    var part: Part = .all

    var body: some View {
        if part != .bounty { extrasSection }
        if part != .extras { bountySection }
    }

    @ViewBuilder private var extrasSection: some View {
        Section {
            NavigationLink { HostTipConfigScreen(session: session) } label: {
                CYListRow("hostTip.entry.config", trailing: .none) { CYRowIcon(systemImage: "heart") }
            }
            .accessibilityIdentifier("account.hostTip.config")
            NavigationLink { HostTipPlayerScreen(session: session) } label: {
                CYListRow("hostTip.entry.player", trailing: .none) { CYRowIcon(systemImage: "heart.text.square") }
            }
            .accessibilityIdentifier("account.hostTip.player")
            Button { showsRedeem = true } label: {
                CYListRow("channelRedeem.entry", trailing: .none) { CYRowIcon(systemImage: "ticket") }
            }
            .accessibilityIdentifier("account.channelRedeem")
            NavigationLink { ContentLandingScreen(session: session) } label: {
                CYListRow("contentLanding.entry", trailing: .none) { CYRowIcon(systemImage: "doc.text") }
            }
            .accessibilityIdentifier("account.contentLanding")
        } header: {
            Text("hostTip.section")
        }
        .cySheet(isPresented: $showsRedeem) { ChannelRedeemSheet(session: session) }
    }

    @ViewBuilder private var bountySection: some View {
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
