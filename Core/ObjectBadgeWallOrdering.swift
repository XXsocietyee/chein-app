import Foundation

/// Mini-program badge wall (subpackageP3/pages/badge-wall/index) lists 已点亮 before 未解锁
/// (`BADGE_SECTIONS`). Identity cards are the only badges that can be locked, so the native list
/// shows lit identity cards first and keeps the server order inside each group. Nothing is
/// dropped, duplicated or re-labelled.
public enum ObjectBadgeWallOrdering {
    public static func litFirst(_ identities: [ProfileIdentityBadge]) -> [ProfileIdentityBadge] {
        identities.filter(\.unlocked) + identities.filter { !$0.unlocked }
    }
}
