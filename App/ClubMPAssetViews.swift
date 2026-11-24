import SwiftUI

/// Round 2 (owner MP-asset rule): club pages show the mini-program default artwork wherever the MP falls back to
/// a bundled image. `docs/mp-assets/mapping.md` rows applied here: `MPAsset.AvatarDefault.dProfile`
/// (`/images/d_profile.png`, every club `cy-avatar` fallback).

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

/// MP `utils/tag-library.js` club 活动倾向 set: every preset direction carries its line icon
/// (`/pages/club/images/tags/*.svg`, template-rendered, so it takes the label colour). Free text has no icon.
enum ClubDirectionIcon {
    static func image(for direction: String) -> Image? {
        switch direction {
        case "轻社交": return MPAsset.FeatureIcon.coffee
        case "深度社交": return MPAsset.FeatureIcon.voice
        case "RPG体验": return MPAsset.FeatureIcon.gameHandle
        case "城市定向": return MPAsset.FeatureIcon.footprints
        case "解谜路线": return MPAsset.FeatureIcon.dices
        case "沉浸式剧情": return MPAsset.FeatureIcon.drama
        case "运动路线": return MPAsset.FeatureIcon.sport
        case "艺术体验": return MPAsset.FeatureIcon.platte
        case "美食体验": return MPAsset.FeatureIcon.noodles
        case "主题聚会": return MPAsset.FeatureIcon.music
        default: return nil
        }
    }
}

/// Toggle/row label with the direction's MP icon (decorative; the text is the label).
struct ClubDirectionLabel: View {
    let value: String
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 18
    var body: some View {
        Label {
            Text(LocalizedStringKey("club.ops.value." + value))
        } icon: {
            if let icon = ClubDirectionIcon.image(for: value) {
                icon.resizable().renderingMode(.template).scaledToFit().frame(width: side, height: side).accessibilityHidden(true)
            }
        }
    }
}

/// CLB-apply-07: MP club/apply required fields (`*`, aria-required).
enum ClubHostApplyFieldCopy {
    static let required: Set<String> = ["leaderName", "phone"]
}

/// CLB-roles-02 (MP roles js:196-200, CU-C-57): a session-scoped role page names the session as 「活动名 · 开始时间」,
/// or 未命名 when the entry did not say, never the id. Set by the event tools and the MP `activityLabel` query.
private struct ClubRoleActivityLabelKey: EnvironmentKey {
    static let defaultValue: String? = nil
}
extension EnvironmentValues {
    var clubRoleActivityLabel: String? {
        get { self[ClubRoleActivityLabelKey.self] }
        set { self[ClubRoleActivityLabelKey.self] = newValue }
    }
}
enum ClubRoleActivityLabel {
    /// MP `entryLabel`: trimmed, empty → nil, capped so a crafted link cannot flood the header.
    static func entry(_ raw: String?) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return String(text.prefix(60))
    }
}
