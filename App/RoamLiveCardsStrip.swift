import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// MP P-32 `live-peek` (pages/roam/index.wxml:535–545, index.js `_syncEntryMap` / `onLiveCardTap`): the live map's
/// horizontal cards = the entry read's nearby activity cards + nearby team cards (same read, not a new request).
/// The map home hands its loaded read to the live cover; nil (fixtures, legacy browser) shows nothing.
struct RoamLiveCardsFeed {
    let cards: [RoamEntryActivityCard]
    let teams: [NearbyTeam]
    /// MP tap: topic → `pages/topic/index/index`, else `pages/activity/detail/index`.
    let event: ((RoamEventDestination) -> AnyView)?
    /// MP tap on a team card: `_openEntryTeamById`.
    let team: ((NearbyTeamID) -> AnyView)?

    /// MP `entryMap.build`: only rows with a valid point, teams with a positive id and a point.
    var visibleCards: [RoamEntryActivityCard] { cards.filter { $0.activity.coordinate != nil } }
    var visibleTeams: [NearbyTeam] {
        teams.filter { $0.teamID.rawValue > 0 && $0.latitude != nil && $0.longitude != nil }
    }
}

private struct RoamLiveCardsFeedKey: EnvironmentKey {
    static let defaultValue: RoamLiveCardsFeed? = nil
}

extension EnvironmentValues {
    var roamLiveCards: RoamLiveCardsFeed? {
        get { self[RoamLiveCardsFeedKey.self] }
        set { self[RoamLiveCardsFeedKey.self] = newValue }
    }
}

/// The strip as a list section of the session sheet. Empty read = no section (MP 读数为空就不出).
struct RoamLiveCardsSection: View {
    let feed: RoamLiveCardsFeed
    @Environment(\.locale) private var locale

    var body: some View {
        let cards = feed.visibleCards
        let teams = feed.visibleTeams
        if !cards.isEmpty || !teams.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(cards) { card in
                            activityCard(card)
                        }
                        ForEach(teams) { team in
                            teamCard(team)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, CYSpacing.lg, for: .scrollContent)
                .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: 0, bottom: CYSpacing.sm, trailing: 0))
                .accessibilityIdentifier("roam.live.cards")
            }
        }
    }

    @ViewBuilder private func activityCard(_ card: RoamEntryActivityCard) -> some View {
        let tile = RoamLiveCardTile(
            cover: card.activity.coverURL,
            tag: Text(LocalizedStringKey(card.tagKey)),
            title: card.activity.title.isEmpty ? Text("roam.w208.entry.untitled") : Text(verbatim: card.activity.title),
            meta: RoamEntryMetaLine(card: card, locale: locale).text
        )
        if let target = card.destination, let make = feed.event {
            NavigationLink { make(target) } label: { tile }
                .buttonStyle(.plain)
                .accessibilityIdentifier("roam.live.card.\(card.id)")
        } else {
            tile.accessibilityIdentifier("roam.live.card.\(card.id)")
        }
    }

    @ViewBuilder private func teamCard(_ team: NearbyTeam) -> some View {
        let tile = RoamLiveCardTile(
            cover: team.leaderAvatar,
            tag: Text("nativeR2.mapHome.kind.team"),
            title: team.title.isEmpty ? Text("roam.w208.entry.teamUntitled") : Text(verbatim: team.title),
            meta: teamMeta(team)
        )
        if let make = feed.team {
            NavigationLink { make(team.teamID) } label: { tile }
                .buttonStyle(.plain)
                .accessibilityIdentifier("roam.live.team.\(team.teamID.rawValue)")
        } else {
            tile.accessibilityIdentifier("roam.live.team.\(team.teamID.rawValue)")
        }
    }

    /// MP `teamView.meta`: activity name · joined/max 人 · 距你 X km, parts skipped when missing.
    private func teamMeta(_ team: NearbyTeam) -> Text? {
        var parts: [Text] = []
        if !team.activityName.isEmpty { parts.append(Text(verbatim: team.activityName)) }
        if team.maxMembers > 0 { parts.append(Text("roam.live.cards.teamPeople \(team.joinedCount) \(team.maxMembers)")) }
        if let meters = team.distance, meters.isFinite, meters > 0 {
            let km = (meters / 100).rounded() / 10
            let zhText = km.formatted(.number.precision(.fractionLength(1))) + " km"
            parts.append(Text("roam.w208.entry.away \(LocaleDisplay.distanceArgument(meters: km * 1000, zhText: zhText, locale: locale))"))
        }
        guard let first = parts.first else { return nil }
        return parts.dropFirst().reduce(first) { $0 + Text(verbatim: " · ") + $1 }
    }
}

/// One card: cover (MP placeholder art when missing), tag, title, meta. Text sits under the cover so it scales.
private struct RoamLiveCardTile: View {
    let cover: String?
    let tag: Text
    let title: Text
    let meta: Text?
    @ScaledMetric(relativeTo: .subheadline) private var width: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            RoamEntryCover(source: cover, fallbackArt: MPAsset.BannerCover.homeRouteCityPlaceholder)
                .frame(width: width, height: width * 0.56)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            tag.font(.caption.weight(.semibold)).foregroundStyle(.tint)
            title.font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
            if let meta {
                meta.font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
