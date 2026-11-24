import SwiftUI

@MainActor struct PublicMerchantFeaturedContext {
    let scope: UUID
    let isCurrent: () -> Bool
    let activity: (Int) -> AnyView
    let couponWallet: () -> AnyView
    func destination(_ route: PublicMerchantFeaturedRoute) -> AnyView {
        switch route {
        case .activity(let id): return activity(id)
        case .couponWallet: return couponWallet()
        }
    }
}

@MainActor struct PublicMerchantFeaturedCard: View {
    let featured: PublicMerchantFeatured
    let image: ((String) -> AnyView)?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if let url = featured.imageURL {
                Group {
                    if let image { image(url) }
                    else { Label("merchant.publicHome.featured.image", systemImage: "photo").foregroundStyle(CYColor.textSecondary) }
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                .accessibilityLabel(Text("merchant.publicHome.featured.image"))
            }
            Label(LocalizedStringKey(featured.kind == .activity ? "merchant.publicHome.featured.activity" : "merchant.publicHome.featured.coupon"),
                  systemImage: featured.kind == .activity ? "calendar" : "ticket")
                .cyText(.caption)
                .foregroundStyle(CYColor.textSecondary)
            if let name = featured.name {
                Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            } else {
                Text("merchant.publicHome.featured.untitled").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            }
            if let description = featured.description {
                Text(verbatim: description).cyText(.body).foregroundStyle(CYColor.textSecondary).textSelection(.enabled)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("merchant.publicHome.featured.card")
    }
}

extension AppSession {
    func makePublicMerchantFeaturedContext(homeReader: any PublicMerchantHomeReading) -> PublicMerchantFeaturedContext {
        let scope = accountCollectionReader.scope
        let revision = sessionRevision
        let contentRevision = contentDetailRevision
        let isCurrent: () -> Bool = { [weak self] in
            guard let self else { return false }
            return homeReader.isConfigured && self.sessionRevision == revision &&
                self.contentDetailRevision == contentRevision && self.accountCollectionReader.scope == scope
        }
        return .init(scope: scope, isCurrent: isCurrent, activity: { [weak self] id in
            guard let self else { return AnyView(Text("merchant.publicHome.unavailable")) }
            return AnyView(SessionPublicMerchantFeaturedDestination(session: self, route: .activity(id), isCurrent: isCurrent))
        }, couponWallet: { [weak self] in
            guard let self else { return AnyView(Text("merchant.publicHome.unavailable")) }
            return AnyView(SessionPublicMerchantFeaturedDestination(session: self, route: .couponWallet, isCurrent: isCurrent))
        })
    }
}

/// Observe session changes even while the merchant page is behind the destination.
@MainActor private struct SessionPublicMerchantFeaturedDestination: View {
    @ObservedObject var session: AppSession
    let route: PublicMerchantFeaturedRoute
    let isCurrent: () -> Bool
    var body: some View {
        Group {
            if !isCurrent() { Text("merchant.publicHome.unavailable") }
            else {
                switch route {
                case .activity(let id):
                    ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)
                case .couponWallet:
                    AccountCollectionCouponsView(reader: session.accountCollectionReader)
                        .id(session.accountCollectionReader.scope)
                        .environment(\.couponCodeFactory, nil)
                }
            }
        }.privacySensitive()
    }
}
