import Foundation

/// Chapter switch「由工作人员开幕」on `themeRuntimeConfig.gameplayRuntime.acts[].hostUnlock`.
/// Mini-program: `onChapterHostUnlock` syncs chapters, then sets the act that owns this chapter's nodes.
/// Turning the switch off is allowed when solo play still has the flag; turning it on is not.
/// This does not post. The topic save already carries `themeRuntimeConfig`.
public enum ProjectEditRuntimeActs {
    public enum Copy {
        public static let on = "projectEdit.hostUnlock.on"
        public static let off = "projectEdit.hostUnlock.off"
        public static let displayUnsaved = "projectEdit.hostUnlock.display.unsaved"
        public static let displayPlayer = "projectEdit.hostUnlock.display.player"
        public static let refuseMode = "projectEdit.hostUnlock.refuse.mode"
        public static let refuseSaveNodes = "projectEdit.hostUnlock.refuse.saveNodes"
        public static let refuseSplitActs = "projectEdit.hostUnlock.refuse.splitActs"
        public static let refuseNoNodes = "projectEdit.hostUnlock.refuse.noNodes"
        public static let refusePlayer = "projectEdit.hostUnlock.refuse.player"
    }
    public struct ChapterHost: Equatable {
        public let enabled: Bool
        public let summaryKey: String
        public let disabledReasonKey: String?
        /// The row subtitle is the reason when set, otherwise `summaryKey`.
        /// The switch stays usable while the chapter is already opened, so the author can close it.
        public var openingBlocked: Bool { disabledReasonKey != nil }
    }
    public static func chapterHost(in draft: ProjectEditDraft, chapterIndex: Int) -> ChapterHost {
        guard let author = try? NativeRuntimeStructureAuthorDraft(draft: draft) else {
            return ChapterHost(enabled: false, summaryKey: Copy.off, disabledReasonKey: Copy.displayUnsaved)
        }
        let matched = actKey(chapterIndex: chapterIndex, chapters: draft.chapters, author: author)
        let row = author.acts.first { $0["actKey"]?.text == matched }
        let enabled = row?["hostUnlock"] == .bool(true)
        let reason: String? = matched == nil ? Copy.displayUnsaved : (author.mode == .player ? Copy.displayPlayer : nil)
        return ChapterHost(enabled: enabled, summaryKey: enabled ? Copy.on : Copy.off, disabledReasonKey: reason)
    }
    public static func setEnabled(_ enabled: Bool, chapterIndex: Int, in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        guard draft.chapters.indices.contains(chapterIndex) else { throw ProjectEditError.invalidDraft }
        var author = try NativeRuntimeStructureAuthorDraft(draft: draft)
        if let blocked = refusalBeforeSync(author) { throw ProjectEditRuntimeActsError.refused(blocked) }
        try author.synchronizeChapters()
        guard let matched = actKey(chapterIndex: chapterIndex, chapters: author.original.chapters, author: author) else {
            throw ProjectEditRuntimeActsError.refused(Copy.refuseNoNodes)
        }
        if enabled, author.mode == .player { throw ProjectEditRuntimeActsError.refused(Copy.refusePlayer) }
        try author.host(actKey: matched, enabled: enabled)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ProjectEditJSON.object(author.theme))
        guard let text = String(data: data, encoding: .utf8), text.utf16.count <= 200_000 else { throw ProjectEditError.invalidDraft }
        var next = draft
        next.preserved["themeRuntimeConfig"] = .string(text)
        return next
    }
    private static func actKey(chapterIndex: Int, chapters: [ProjectEditChapter], author: NativeRuntimeStructureAuthorDraft) -> String? {
        guard chapters.indices.contains(chapterIndex) else { return nil }
        let ids = Set(chapters[chapterIndex].nodes.compactMap { $0.localMetadata["id"]?.integer })
        guard let matched = author.quests.first(where: { ids.contains($0["nodeId"]?.integer ?? -1) })?["actKey"]?.text,
              author.acts.contains(where: { $0["actKey"]?.text == matched }) else { return nil }
        return matched
    }
    /// Same gates as `syncChapters` before it rewrites acts. Keys, not the Chinese sentences.
    static func refusalBeforeSync(_ author: NativeRuntimeStructureAuthorDraft) -> String? {
        if author.mode == nil { return Copy.refuseMode }
        let ids = author.nodes.compactMap { $0.localMetadata["id"]?.integer }
        if ids.count != author.nodes.count || ids.contains(where: { $0 < 1 }) || Set(ids).count != ids.count { return Copy.refuseSaveNodes }
        for chapter in author.original.chapters {
            let members = Set(chapter.nodes.compactMap { $0.localMetadata["id"]?.integer })
            let keys = Set(author.quests.filter { members.contains($0["nodeId"]?.integer ?? 0) }.compactMap { $0["actKey"]?.text })
            if keys.count > 1 { return Copy.refuseSplitActs }
        }
        return nil
    }
}
public enum ProjectEditRuntimeActsError: Error, Equatable {
    case refused(String)
}
