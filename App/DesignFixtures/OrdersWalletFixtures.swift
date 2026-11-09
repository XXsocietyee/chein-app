#if DEBUG
import SwiftUI

/// D3 design fixtures (synthetic data, debug only). They reuse the existing offline fixture readers so the
/// real screens render, themed as the player domain (dark).
enum OrdersWalletFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "orders-list": return wrap(ProfileOrderFilterFixtureHost(empty: false, designClean: true))
        case "orders-empty": return wrap(ProfileOrderFilterFixtureHost(empty: true, designClean: true))
        case "order-detail": return wrap(OrderLifecycleFixtureHostView())
        case "order-detail-bottom":
            return wrap(OrderLifecycleFixtureHostView().task { try? await Task.sleep(nanoseconds: 6_000_000_000); scrollToBottom() })
        case "order-detail-full": return wrap(OrderLifecycleFixtureHostView().environment(\.dynamicTypeSize, .xSmall).scaleEffect(0.62, anchor: .top).frame(height: 1400, alignment: .top))
        case "ticket-list": return wrap(TicketWalletFixtureHostView())
        case "ticket-detail":
            return wrap(NavigationStack { TicketWalletDetailView(id: 901, reader: TicketWalletFixtureReader(scenario: .content)) })
        case "coupons":
            return wrap(NavigationStack { AccountCollectionCouponsView(reader: AccountCollectionFixtureReader(scenario: .content)) })
        case "wallet": return wrap(WalletCommerceFixtureHost(designHome: true))
        default: return nil
        }
    }

    /// Debug evidence only: scroll the first scroll view in the key window to its end so lower sections can be shot.
    @MainActor private static func scrollToBottom() {
        func find(_ v: UIView) -> UIScrollView? {
            if let s = v as? UIScrollView, s.contentSize.height > s.bounds.height { return s }
            for c in v.subviews { if let r = find(c) { return r } }
            return nil
        }
        let windows = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows }.flatMap { $0 }
        guard let w = windows.first(where: \.isKeyWindow), let s = find(w) else { return }
        s.setContentOffset(CGPoint(x: 0, y: s.contentSize.height - s.bounds.height + s.adjustedContentInset.bottom), animated: false)
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player))
    }
}
#endif
