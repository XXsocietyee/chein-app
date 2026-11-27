import SwiftUI

/// Production readers for square stubs 18, 19, and 20. Route maps, deletion, and bookmarks stay unwired.
@MainActor enum CloudSquareSessionBridge {
    @MainActor private final class Slot {
        weak var session: AppSession?
        let activities: SquareCompletedActivityConformer
        let follow: SquareAuthorFollowConformer
        let share: SquarePublicShareLink
        init(session: AppSession) {
            self.session = session
            activities = SquareCompletedActivityConformer(session: session)
            follow = SquareAuthorFollowConformer(session: session)
            share = SquarePublicShareLink()
        }
    }
    private static var slots: [Slot] = []

    private static func slot(for session: AppSession) -> Slot {
        slots.removeAll { $0.session == nil }
        if let existing = slots.first(where: { $0.session === session }) { return existing }
        let created = Slot(session: session)
        slots.append(created)
        return created
    }

    static func activities(for session: AppSession) -> SquareCompletedActivityConformer { slot(for: session).activities }
    static func follow(for session: AppSession) -> SquareAuthorFollowConformer { slot(for: session).follow }
    static func share(for session: AppSession) -> SquarePublicShareLink { slot(for: session).share }
}

/// Ledger row 20. A public URL exists only for a post `SquareL5ShareCard.isPubliclyShareable` accepts
/// and only when that detail path is already parsed. Anything else has no public URL.
@MainActor final class SquarePublicShareLink: SquarePostShareLinkProviding {
    private var recordedID: Int?
    private var recorded: SquareL5ShareCard.Post?

    func note(_ post: SquarePost) {
        recordedID = post.id
        recorded = PublicContentShareLink.l5Post(from: post)
    }

    func shareURL(postID: Int) -> URL? {
        guard recordedID == postID, let recorded else { return nil }
        return PublicContentShareLink.squarePost(recorded)
    }

    /// A post that is not publicly shareable does not get a public or generic URL.
    var genericShareURL: URL? { nil }
}

enum SquarePublicLinkCopy {
    static func copyIfPublic(_ post: SquarePost) {
        guard let url = PublicContentShareLink.squarePost(PublicContentShareLink.l5Post(from: post)) else { return }
        LocalPasteboard.copy(url.absoluteString)
    }
}

/// GET `SquareActivityPicker.completedPath` with `for_public_reference=true`. No write.
@MainActor final class SquareCompletedActivityConformer: SquareCompletedActivityProviding {
    private let session: AppSession
    init(session: AppSession) { self.session = session }

    func completedActivities() async throws -> [CYSquareCompletedActivity] {
        let owner = session.account?.id
        let epoch = session.sessionRevision
        guard owner != nil else { throw APIError.unauthorized }
        let rows = try await session.playerJourneyReader.completedForPublicReference()
        guard !Task.isCancelled, session.account?.id == owner, session.sessionRevision == epoch else { throw CancellationError() }
        return SquareActivityPicker.publicReferenceRows(rows).map {
            CYSquareCompletedActivity(id: $0.id, name: $0.name, cover: $0.cover, doneCount: $0.doneCount, total: $0.total, topicID: $0.topicID)
        }
    }
}

/// Follow flag already decoded onto `SquarePost`. The reviewed `toggleFollow` editor remains the only write.
@MainActor final class SquareAuthorFollowConformer: SquareAuthorFollowStateProviding {
    private let session: AppSession
    private var owner: (Int, UInt64)?
    private var serverFlag: [Int: Bool] = [:]
    private var displayFlag: [Int: Bool] = [:]
    init(session: AppSession) { self.session = session }

    func record(_ post: SquarePost) {
        adoptOwner()
        guard owner != nil, post.memberID > 0, let flag = post.isFollowTheUser else { return }
        let previous = serverFlag[post.memberID]
        serverFlag[post.memberID] = flag
        if previous != Optional(flag) || displayFlag[post.memberID] == nil { displayFlag[post.memberID] = flag }
    }

    /// Applies the receipt from the existing follow write. A missing receipt does not invent a flag.
    func apply(memberID: Int, followed: Bool) {
        adoptOwner()
        guard owner != nil, memberID > 0 else { return }
        displayFlag[memberID] = followed
    }

    func isFollowing(memberID: Int) -> Bool? {
        adoptOwner()
        guard owner != nil, memberID > 0 else { return nil }
        return displayFlag[memberID]
    }

    private func adoptOwner() {
        let next = session.account.map { ($0.id, session.sessionRevision) }
        if next?.0 != owner?.0 || next?.1 != owner?.1 {
            serverFlag.removeAll()
            displayFlag.removeAll()
            owner = next
        }
    }
}

struct CloudSquareStubModifier: ViewModifier {
    let session: AppSession
    func body(content: Content) -> some View {
        content
            .environment(\.squareShareLink, CloudSquareSessionBridge.share(for: session))
            .environment(\.squareCompletedActivities, CloudSquareSessionBridge.activities(for: session))
            .environment(\.squareAuthorFollowState, CloudSquareSessionBridge.follow(for: session))
            .environment(\.squareViewerAvatar, session.account.map { SquareViewerAvatar(memberID: $0.id, avatar: $0.avatar) })
    }
}
