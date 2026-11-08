import Foundation

/// Specific, bilingual reasons a quick-publish draft cannot be handed to the professional editor.
/// Mirrors the rule in `QuickPublishDraft.professionalSeed` (title, at least one stop, every stop named and
/// map-confirmed); `professionalSeed` stays the single authority, this only explains the refusal.
public enum QuickPublishIssue: Equatable {
    case titleMissing
    case noStops
    case stopNameMissing(index: Int)
    case placeUnconfirmed(index: Int)

    public var message: String {
        switch self {
        case .titleMissing: return W8Text.t("请先填写路线名称", "Enter a route name first")
        case .noStops: return W8Text.t("至少添加一个站点", "Add at least one stop")
        case .stopNameMissing(let index): return W8Text.t("第 \(index) 站还没有名称", "Stop \(index) needs a name")
        case .placeUnconfirmed(let index): return W8Text.t("请在地图上确认第 \(index) 站的位置", "Confirm the location of stop \(index) on the map")
        }
    }
}

public enum QuickPublishValidation {
    /// Issues in reading order; empty exactly when `professionalSeed` would accept the draft.
    public static func issues(_ draft: QuickPublishDraft) -> [QuickPublishIssue] {
        var result: [QuickPublishIssue] = []
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.titleMissing) }
        if draft.nodes.isEmpty { result.append(.noStops) }
        for (offset, node) in draft.nodes.enumerated() {
            if node.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.stopNameMissing(index: offset + 1)) }
            if node.confirmedPlace == nil { result.append(.placeUnconfirmed(index: offset + 1)) }
        }
        return result
    }
}
