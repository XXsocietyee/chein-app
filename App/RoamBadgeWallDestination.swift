import SwiftUI

@MainActor struct RoamBadgeWallDestination: View {
    let roamReader: any RoamExperienceReading
    var body: some View {
        if roamReader.isOfflineExample {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitesting-roam-experience") {
                RoamBadgeWallFixtureDestination(roamReader: roamReader)
            } else { changed }
            #else
            changed
            #endif
        } else { SessionRoamBadgeWallDestination(roamReader: roamReader) }
    }
    private var changed: some View { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.badgeWall.changed") }
}
@MainActor private struct SessionRoamBadgeWallDestination: View {
    @EnvironmentObject private var session: AppSession
    let roamReader: any RoamExperienceReading
    var body: some View {
        if ObjectIdentifier(roamReader) == ObjectIdentifier(session.roamExperienceReader) || isFinishedWalkOfSession {
            RoamBadgeWallOwnedView(roam: roamReader, profile: session.profileReader,
                media: session.makeObjectCardImageLoader(),
                currentOwner: .init(roam: roamReader, profile: session.profileReader))
        } else { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.badgeWall.changed") }
    }
    /// design-r2-roam (P8/P16): the finish report holds the just-finished walk's local-history reader
    /// (`RoamFinishedHistoryReader`). It may open the badge wall when it still speaks for the session's own roam
    /// account (same scope and epoch). `RoamBadgeWallReader` then re-checks the account against the profile reader
    /// on every read, exactly as for the session reader.
    private var isFinishedWalkOfSession: Bool {
        guard roamReader is RoamFinishedHistoryReader,
              let finished = roamReader.identity, let current = session.roamExperienceReader.identity else { return false }
        return finished.scope.storageKey == current.scope.storageKey && finished.epoch == current.epoch
    }
}
@MainActor private struct RoamBadgeWallOwnedView: View {
    let currentOwner: RoamBadgeWallReadOwner
    let media: (any ObjectCardImageLoading)?
    @State private var reader: RoamBadgeWallReader
    init(roam: any RoamExperienceReading, profile: any ProfileReading, media: (any ObjectCardImageLoading)? = nil, currentOwner: RoamBadgeWallReadOwner) {
        self.currentOwner = currentOwner; self.media = media; _reader = State(initialValue: .init(roam: roam, profile: profile))
    }
    var body: some View {
        if currentOwner == reader.origin, reader.isCurrent {
            ObjectBadgeWallView(reader: reader, media: media)
        } else {
            CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "roam.badgeWall.changed")
                .accessibilityIdentifier("roam.badgeWall.changed")
        }
    }
}
#if DEBUG
/// Only the already-selected synthetic Roam host can construct this paired identity fixture.
/// Its badge payload is the existing synthetic Profile fixture, never a production account read.
@MainActor private struct RoamBadgeWallFixtureDestination: View {
    let roamReader: any RoamExperienceReading
    @State private var profile: RoamBadgeWallFixtureReader
    init(roamReader: any RoamExperienceReading) {
        self.roamReader = roamReader
        let args = ProcessInfo.processInfo.arguments, index = args.firstIndex(of: "--uitesting-roam-badges-scenario")
        let raw = index.flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        let identity = roamReader.identity.map { ProfileReadIdentity(accountID: $0.scope.accountID, epoch: $0.epoch) }
        _profile = State(initialValue: .init(identity: identity, scenario: raw.flatMap(ProfileFixtureScenario.init(rawValue:)) ?? .success))
    }
    var body: some View {
        RoamBadgeWallOwnedView(roam: roamReader, profile: profile, currentOwner: .init(roam: roamReader, profile: profile))
    }
}
@MainActor private final class RoamBadgeWallFixtureReader: ProfileReading {
    let identity: ProfileReadIdentity?
    private let fixture: ProfileFixtureReader
    var isConfigured: Bool { fixture.isConfigured }
    init(identity: ProfileReadIdentity?, scenario: ProfileFixtureScenario) {
        self.identity = scenario == .unauthorized ? nil : identity; fixture = .init(scenario)
    }
    func profileBadges() async throws -> ProfileBadgeWall { try await fixture.profileBadges() }
    func profileOrders() async throws -> [ProfileOrder] { throw APIError.notConfigured }
    func profileOrder(id: Int) async throws -> ProfileOrder { throw APIError.notConfigured }
    func profileParticipants() async throws -> [ProfileParticipant] { throw APIError.notConfigured }
    func profileParticipant(id: Int) async throws -> ProfileParticipant { throw APIError.notConfigured }
}
#endif
