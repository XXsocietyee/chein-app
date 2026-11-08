import SwiftUI

/// Builds the value for the `cooperationRelationPostFeed` environment hook from the club community
/// context the session already owns (the same feed as the club tab's 帖文 segment).
/// Without a community context the Posts segment stays hidden; nothing is faked.
enum CoopRelationPostFeedFactory {
    @MainActor static func make(community: ClubCommunityContext?,
                                identity: @escaping @MainActor () -> ClubReadIdentity?) -> (@MainActor () -> AnyView)? {
        guard let community else { return nil }
        return {
            if let current = identity() {
                return AnyView(ClubCommunityFeedView(context: community, identity: current))
            }
            return AnyView(
                Text("cooperation.login").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("cooprelation.postFeed.signedOut"))
        }
    }
}
