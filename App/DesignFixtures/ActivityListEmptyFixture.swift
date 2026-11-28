#if DEBUG
import Foundation
import SwiftUI

/// mp-activity r3 ("Next round" item 3, all states): MP `pages/activity/list/index` has three list states
/// (wxml:34-39 skeleton, cy-error 活动列表没能打开, cy-empty per-tab EMPTY_COPY). `rep3-activity-list` and
/// `rep3-activity-list-failed` (mp-home) show content and failure; `rep3-activity-list-empty` shows the empty
/// state on the same `OfficialEventsBrowserView`. Offline, signed in, no rows on any tab.
@MainActor final class ActivityListEmptyFixtureReader: OfficialEventReading {
    let scope = UUID()
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { true }

    func events(city: String?) async throws -> [OfficialEvent] {
        []
    }

    func detail(id: Int) async throws -> OfficialEvent {
        throw APIError.httpStatus(404)
    }

    func myEvents() async throws -> [OfficialEvent] {
        []
    }

    func partyInbox() async throws -> [OfficialPartyInvite] {
        []
    }

    func canPublish() async throws -> Bool { false }

    func myPublished() async throws -> OfficialPublished {
        try JSONDecoder().decode(OfficialPublished.self, from: Data("{}".utf8))
    }

    func broadcastStats(id: Int) async throws -> OfficialBroadcastStats {
        try JSONDecoder().decode(OfficialBroadcastStats.self, from: Data("{}".utf8))
    }
}

/// Pushed page inside a stack, like `HomeActivityListFixture`.
struct ActivityListEmptyFixture: View {
    @State private var reader = ActivityListEmptyFixtureReader()

    var body: some View {
        NavigationStack {
            OfficialEventsBrowserView(reader: reader)
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
    }
}
#endif
