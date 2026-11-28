import Foundation

/// MP `publish/fabu/topic-detail-sheet.wxml:70-77` + `theme-media.js` `uploadThemeAudio` / `clearThemeAudio`:
/// the topic-level 主题配乐 (`formData.audioUrl`), separate from chapter narration. Reading never resolves the URL.
public enum ProjectThemeAudio {
    /// Same topic DTO / `CmsTopicServiceImpl` String.length() bound as the chapter reference.
    public static let maximumReferenceUTF16Count = 512
    public static func reference(in draft: ProjectEditDraft) -> String? {
        draft.preserved["audioUrl"]?.text
    }
    public static func hasAudio(in draft: ProjectEditDraft) -> Bool {
        guard let reference = reference(in: draft) else { return false }
        return !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    /// A non-string legacy value is kept as it is and cannot be replaced or cleared here.
    public static func isUnsupported(in draft: ProjectEditDraft) -> Bool {
        guard let value = draft.preserved["audioUrl"], value != .null else { return false }
        return value.text == nil
    }
    public static func fitsWire(_ reference: String) -> Bool {
        reference.utf16.count <= maximumReferenceUTF16Count
    }
    /// MP `uploadThemeAudio` success: the new url, and `audioDuration` 0 (L03-088: a new file never keeps the old length).
    public static func setting(_ reference: String, in draft: ProjectEditDraft) -> ProjectEditDraft {
        var next = draft
        next.preserved["audioUrl"] = .string(reference)
        next.preserved["audioDuration"] = .number(0)
        return next
    }
    /// MP `clearThemeAudio`: `audioUrl` '' and `audioDuration` 0.
    public static func clearing(in draft: ProjectEditDraft) throws -> ProjectEditDraft {
        guard !isUnsupported(in: draft) else { throw ProjectEditError.invalidDraft }
        guard hasAudio(in: draft) else { return draft }
        var next = draft
        next.preserved["audioUrl"] = .string("")
        next.preserved["audioDuration"] = .number(0)
        return next
    }
}
