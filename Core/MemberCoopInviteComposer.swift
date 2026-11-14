import Foundation

/// Validation and copy model for the member-area chapter cooperation invitation sheet (`发送邀约`).
/// Uses only reviewed chapter-replacement invitation inputs (`merchantMemberId`, `chapterId`, `replacementOfOfferId`).
public struct MemberCoopInviteDraft: Equatable {
    public var selectedChapterID: Int?
    public var note: String

    public init(selectedChapterID: Int? = nil, note: String = "") {
        self.selectedChapterID = selectedChapterID
        self.note = note
    }

    public var isReadyToSend: Bool {
        guard let selectedChapterID else { return false }
        return selectedChapterID > 0
    }

    /// Trims and bounds optional invite note length cleanly.
    public var normalizedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(200))
    }
}

/// Summary status for sending a member-area chapter cooperation invite without auto-accepting.
public enum MemberCoopInviteSubmissionState: Equatable {
    case idle
    case loadingTopics
    case ready
    case sending
    case sent(message: String)
    case failed(message: String)
}
