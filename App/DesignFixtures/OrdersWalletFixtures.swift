#if DEBUG
import SwiftUI

/// D3 design fixtures (synthetic data, debug only). They reuse the existing offline fixture readers so the
/// real screens render, themed as the player domain (dark).
enum OrdersWalletFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "orders-list": return wrap(ProfileOrderFilterFixtureHost(empty: false))
        case "orders-empty": return wrap(ProfileOrderFilterFixtureHost(empty: true))
        case "order-detail": return wrap(OrderLifecycleFixtureHostView())
        case "ticket-list": return wrap(TicketWalletFixtureHostView())
        case "ticket-detail":
            return wrap(NavigationStack { TicketWalletDetailView(id: 901, reader: TicketWalletFixtureReader(scenario: .content)) })
        case "coupons":
            return wrap(NavigationStack { AccountCollectionCouponsView(reader: AccountCollectionFixtureReader(scenario: .content)) })
        case "wallet": return wrap(WalletCommerceFixtureHost())
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player))
    }
}
#endif
