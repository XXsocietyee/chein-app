import SwiftUI

/// Round 2 (owner MP-asset rule): club pages show the mini-program default artwork wherever the MP falls back to
/// a bundled image. `docs/mp-assets/mapping.md` rows applied here: `MPAsset.AvatarDefault.dProfile`
/// (`/images/d_profile.png`, every club `cy-avatar` fallback).

/// Avatar with the MP default: a real HTTPS avatar goes through `CYAvatarView`; no avatar shows `d_profile.png`,
/// as the MP's `src="{{item.avatar || '/images/d_profile.png'}}"` does. Decorative; the row carries the name.
struct ClubMPAvatar: View {
    let url: URL?
    let name: String
    var size: CYAvatarSize = .md
    @ScaledMetric(relativeTo: .body) private var scaleFactor: CGFloat = 1.0

    private var dimension: CGFloat { size.rawValue * min(max(scaleFactor, 0.85), 1.35) }

    var body: some View {
        if let url, url.scheme?.lowercased() == "https" {
            CYAvatarView(url: url, name: name, size: size)
        } else {
            MPAsset.AvatarDefault.dProfile
                .resizable()
                .scaledToFill()
                .frame(width: dimension, height: dimension)
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
    }
}
