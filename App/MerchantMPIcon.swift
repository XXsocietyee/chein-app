import SwiftUI

/// Round 2 MP-asset rule: a merchant feature icon drawn from the MP artwork (`MPAsset`), at list-icon size.
/// It scales with Dynamic Type and is decorative (the row's text carries the label).
struct MerchantMPIcon: View {
    let image: Image
    var size: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        image
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: size * scale, height: size * scale)
            .accessibilityHidden(true)
    }
}

/// MP `cy-avatar src="{{avatar || '/images/d_profile.png'}}"` (customer list / detail): the HTTPS avatar,
/// otherwise the MP default avatar artwork (`MPAsset.AvatarDefault.dProfile`), clipped to a circle.
struct MerchantMPAvatar: View {
    let url: URL?
    var size: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    private var dimension: CGFloat { size * min(max(scale, 0.85), 1.35) }
    private var remoteURL: URL? { url?.scheme?.lowercased() == "https" ? url : nil }

    var body: some View {
        Group {
            if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFill() } else { fallback }
                }
            } else {
                fallback
            }
        }
        .frame(width: dimension, height: dimension)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(CYColor.borderSubtle, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
    }
}
