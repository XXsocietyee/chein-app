#if DEBUG
import SwiftUI

/// E3 social fixtures. Each case mounts an existing offline DEBUG host (synthetic data) under the player theme.
/// Variants are selected with the host's own launch arguments, e.g.
/// `--design-fixture e3-social --uitesting-social-destination invites`.
enum E3Fixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e3-inbox": return wrap(MessagingFixtureHostView(scenario: .success))
        case "e3-inbox-empty": return wrap(MessagingFixtureHostView(scenario: .empty))
        case "e3-inbox-error": return wrap(MessagingFixtureHostView(scenario: .error))
        case "e3-chat": return wrap(MessageActionFixtureHost())
        case "e3-poll": return wrap(GroupPollFixtureRoot(scenario: "success"))
        case "e3-social": return wrap(SocialAccountFixtureHostView())
        case "e3-coop": return wrap(CooperationFixtureHostView())
        case "e3-club-community": return wrap(ClubCommunityFixtureRoot())
        default: return nil
        }
    }
    @MainActor private static func wrap<V: View>(_ v: V) -> AnyView { AnyView(v.roleTheme(.player)) }
}
#endif
