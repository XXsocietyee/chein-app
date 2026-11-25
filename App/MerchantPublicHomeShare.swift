import SwiftUI

/// MC8-01-5 / MC8-03-2 (merchant/index/index.js:1757-1764, merchant/profile/index.js:138-145,
/// utils/merchant-home-link.js): the canonical public merchant home is `pages/userinfo/userinfo?userId=<memberId>&tab=about`
/// with no topic context. The link is offered only when this build's universal-link parser accepts it (fail closed).
enum MerchantPublicHomeShareLink {
    static func url(memberID: Int?) -> URL? {
        guard let memberID, memberID > 0,
              let url = URL(string: PublicContentShareLink.httpsOrigin + "/pages/userinfo/userinfo?userId=\(memberID)&tab=about"),
              UniversalLinkParser().parse(url) != nil else { return nil }
        return url
    }
}

/// Toolbar share button: 「店名 · 商家主页」 (MP share title), the canonical URL.
struct MerchantPublicHomeShareButton: View {
    let memberID: Int?
    let storeName: String?
    @Environment(\.locale) private var locale

    var body: some View {
        if let url = MerchantPublicHomeShareLink.url(memberID: memberID) {
            let name = (storeName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = name.isEmpty ? appLocalized("merchantR8.share.fallbackTitle", locale: locale)
                : name + appLocalized("merchantR8.share.titleSuffix", locale: locale)
            ShareLink(item: url, subject: Text(verbatim: title), message: Text(verbatim: title)) {
                Label("merchantR8.share.label", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("merchant.publicHome.share")
        }
    }
}
