import SwiftUI

/// Insert into AccountView's existing Form/NavigationStack. Session owns the reader.
@MainActor
struct ProfileAccountLinks: View {
    let reader: any ProfileReading
    var scoreAppealsDestination: (@MainActor () -> AnyView)? = nil
    var ordersDestination: (@MainActor () -> AnyView)? = nil
    var participantReader: (any ProfileReading)? = nil
    var participantCoordinator: ParticipantMutationCoordinator? = nil
    var orderLifecycleCoordinator: OrderLifecycleCoordinator? = nil
    var mediaScope: UUID = UUID()
    var makeExternalMaps: (@MainActor () -> PlatformExternalMaps)? = nil
    /// Which rows this instance renders. The Mine tab splits orders and the badge wall into
    /// separate sections to follow the mini-program order; other hosts keep every row.
    enum Part { case all, orders, collection }
    var part: Part = .all
    var body: some View {
        switch part {
        case .all: Section("profile.library") { orderRows; badgeRow }
        case .orders: Section("account.section.orders") { orderRows }
        case .collection: badgeRow
        }
    }
    @ViewBuilder private var orderRows: some View {
        if let scoreAppealsDestination {
            NavigationLink { scoreAppealsDestination() } label: {
                Label { memberScoreText("score.mine.title") } icon: { Image(systemName: "text.bubble") }
            }.accessibilityIdentifier("profile.open.scoreAppeals")
        }
        NavigationLink {
            if let ordersDestination { ordersDestination() }
            else { ProfileOrdersView(reader: reader, lifecycleCoordinator: orderLifecycleCoordinator, mediaScope: mediaScope, makeExternalMaps: makeExternalMaps) }
        } label: {
            Label("profile.orders.title", systemImage: "list.bullet.rectangle")
        }.accessibilityIdentifier("profile.open.orders")
        NavigationLink { ProfileParticipantsView(reader:participantReader ?? reader,coordinator:participantCoordinator) } label: {
            Label("profile.participants.title", systemImage: "person.2")
        }.accessibilityIdentifier("profile.open.participants")
    }
    private var badgeRow: some View {
        NavigationLink { ObjectBadgeWallView(reader: reader) } label: {
            // MP cy-profile index.wxml:336 收集册 · 勋章 pile: `/subpackageMember/images/album/medal-3d.png`.
            Label { Text("profile.badges.title") } icon: { AccountPublishMPGlyph(MPAsset.BadgeMedal.medal3d, side: 22) }
        }.accessibilityIdentifier("profile.open.badges")
    }
}
