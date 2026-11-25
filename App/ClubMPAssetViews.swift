import SwiftUI

/// Club App helpers from fix-r3-club-a (share link, 活动倾向 icons, host-apply field copy, role activity label).
/// `ClubMPAvatar` and `ClubMoneyText` live in `ClubKit/ClubMPArt.swift`.

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
/// CLB-G16 (MP governance js:211/353, roles js:195/312): a `memberId` on the governance (manage) or roles link
/// preselects that member. The app lists that member first and marks it; the role picker starts with it chosen.
private struct ClubFocusMemberIDKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}
extension EnvironmentValues {
    var clubFocusMemberID: Int? {
        get { self[ClubFocusMemberIDKey.self] }
        set { self[ClubFocusMemberIDKey.self] = newValue }
    }
}
enum ClubFocusMember {
    /// Stable reorder: the focused member first, every other row in its read order.
    static func ordered<T: Identifiable>(_ rows: [T], focus: Int?) -> [T] where T.ID == Int {
        guard let focus, let index = rows.firstIndex(where: { $0.id == focus }), index > 0 else { return rows }
        var copy = rows
        copy.insert(copy.remove(at: index), at: 0)
        return copy
    }
}
enum ClubRoleActivityLabel {
    /// MP `entryLabel`: trimmed, empty → nil, capped so a crafted link cannot flood the header.
    static func entry(_ raw: String?) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return String(text.prefix(60))
    }
}
