import SwiftUI

extension AppSession {
    /// Only supplies a destination. Creating the factory does not read the wallet.
    func makeRoamCouponWalletDestination(reader: any RoamReading) -> () -> AnyView {
        let identity = reader.identity
        let area = reader.searchArea
        let readerID = ObjectIdentifier(reader)
        let revision = sessionRevision
        let contentRevision = contentDetailRevision
        let walletScope = accountCollectionReader.scope
        let isCurrent: () -> Bool = { [weak self] in
            guard let self, let identity, let area, identity.accountID > 0 else { return false }
            return self.sessionRevision == revision && self.contentDetailRevision == contentRevision &&
                ObjectIdentifier(self.roamReader) == readerID && reader.isConfigured &&
                reader.identity == identity && reader.searchArea == area &&
                self.accountCollectionReader.scope == walletScope
        }
        return { [weak self] in
            guard let self, isCurrent() else { return AnyView(ContentUnavailableView("roamEvent.unavailable", systemImage: "ticket")) }
            return AnyView(SessionRoamCouponWalletView(session: self, isCurrent: isCurrent))
        }
    }
}

/// Observes owner changes while the place overview sits behind the wallet.
@MainActor private struct SessionRoamCouponWalletView: View {
    @ObservedObject var session: AppSession
    let isCurrent: () -> Bool
    var body: some View {
        Group {
            if isCurrent() {
                AccountCollectionCouponsView(reader: session.accountCollectionReader)
                    .id(session.accountCollectionReader.scope)
                    // Function audit P1-20: the MP coupon page shows the code; same factory as the Me wallet.
                    .environment(\.couponCodeFactory, { session.makeCouponCodeCoordinator(historyID: $0) })
            } else {
                ContentUnavailableView("roamEvent.changed", systemImage: "ticket")
                    .accessibilityIdentifier("roamFeaturedCouponWallet.stale")
            }
        }.privacySensitive()
    }
}
