import Foundation

/// Input limits taken from the mini-program `pages/publish/simple` (maxlength attributes and the seed-idea slice).
/// Pure helpers so the quick-publish form can clamp text deterministically.
public enum QuickPublishFieldLimits {
    public static let idea = 300
    public static let seedIdea = 60
    public static let title = 30
    public static let story = 500
    public static let stopName = 30
    public static let stopStory = 300
    public static let maxAIStops = 3

    public static func clamp(_ text: String, to limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit))
    }

    /// Initial idea carried from the template shelf: trimmed, then cut to 60 characters (mini-program `options.idea`).
    public static func seededIdea(_ raw: String?) -> String {
        clamp((raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines), to: seedIdea)
    }

    public static func clamped(_ draft: QuickPublishDraft) -> QuickPublishDraft {
        var result = draft
        result.title = clamp(draft.title, to: title)
        result.description = clamp(draft.description, to: story)
        result.nodes = draft.nodes.map { node in
            var copy = node
            copy.name = clamp(node.name, to: stopName)
            copy.description = clamp(node.description, to: stopStory)
            return copy
        }
        return result
    }
}
