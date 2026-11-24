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

/// cursor/core-club hand-off (CLB-detail-30): club and post shares carry the MP page path from `ClubShareLink`
/// (`/pages/club/detail/index?id=…[&postId=…]`) as an in-app `chein://mp/…` link, which `MiniProgramPageLink`
/// already routes back to the club page. Registration attribution (CLB-detail-11) stays an owner decision.
enum ClubShareURL {
    static func url(_ link: ClubShareLink?) -> URL? {
        guard let link else { return nil }
        return URL(string: CheinDeepLink.scheme + "://mp" + link.path)
    }
    static func club(_ id: Int?) -> URL? { url(id.flatMap { ClubShareLink.club(id: $0) }) }
    static func post(clubID: Int?, postID: Int) -> URL? { url(clubID.flatMap { ClubShareLink.post(clubID: $0, postID: postID) }) }
}

/// cursor/core-club hand-off (CLB-r7-C-06): the club edit page installs this so the dissolve form can drop the local
/// edit draft (`ClubProfileLocalDraftFlow.clearAfterConfirmedDissolve()`) once the server acknowledged the dissolve.
private struct ClubDissolveAcknowledgedKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> Void)? = nil
}
extension EnvironmentValues {
    var clubDissolveAcknowledged: (@MainActor () -> Void)? {
        get { self[ClubDissolveAcknowledgedKey.self] }
        set { self[ClubDissolveAcknowledgedKey.self] = newValue }
    }
}
