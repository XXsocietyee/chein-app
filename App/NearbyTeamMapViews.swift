import SwiftUI

/// Mini-program subpackageRoam/nearby + my-teams presentation pieces. Read-only: every value comes from
/// already-read rows, the map centre is the manually selected point, and no device location is requested.
enum NearbyTeamViewMode: Hashable { case map, list }
struct NearbyMineLoad { var loading = false; var failed = false; var loaded = false }
enum NearbyRecruitingLoad: Equatable { case idle, loading, loaded, failed, noArea }

/// Count line 附近的队伍 · N 支在招募. The 地图 / 列表 switch lives in the navigation bar (`NearbyTeamViewModePicker`).
struct NearbyTeamCountLine: View {
    let loaded: Bool
    let count: Int
    var body: some View {
        Label {
            Group {
                if loaded { Text("nearby.w208.header \(count)") } else { Text("nearby.w208.header.loading") }
            }.accessibilityIdentifier("nearby.w208.header")
        } icon: {
            Image(systemName: "circle.fill").font(.caption).foregroundStyle(CYColor.textSecondary)
                .accessibilityHidden(true)
        }
        .cyText(.sectionTitle)
    }
}

/// Native segmented 地图 / 列表 switch for the toolbar.
struct NearbyTeamViewModePicker: View {
    @Binding var mode: NearbyTeamViewMode
    var body: some View {
        Picker("nearby.w208.viewMode", selection: $mode) {
            Text("nearby.w208.mode.map").tag(NearbyTeamViewMode.map)
            Text("nearby.w208.mode.list").tag(NearbyTeamViewMode.list)
        }.pickerStyle(.segmented).fixedSize().accessibilityIdentifier("nearby.w208.viewMode")
    }
}

/// xcx `nearbyReadAccess`: login / denied / load failure, each with its own action. The map stays usable.
struct NearbyLoadIssueCard: View {
    let issue: NearbyLoadIssue
    let onSignIn: (() -> Void)?
    let retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(issue.titleKey)).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            Text(LocalizedStringKey(issue.subKey)).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
            if !issue.offersRetry {
                EmptyView()
            } else if issue == .signIn {
                if let onSignIn { CYPillButton(LocalizedStringKey(issue.actionKey), style: .secondary, action: onSignIn).accessibilityIdentifier("nearby.w208.issue.action") }
            } else {
                CYPillButton(LocalizedStringKey(issue.actionKey), style: .secondary, action: retry).accessibilityIdentifier("nearby.w208.issue.action")
            }
        }.fixedSize(horizontal: false, vertical: true).padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            .accessibilityElement(children: .contain).accessibilityIdentifier("nearby.w208.issue.\(issue.rawValue)")
    }
}

/// Original team pins plus explicitly supplied, separately approved typed read layers. No location acquisition.
struct NearbyTeamMapSection: View {
    let center: RoamSearchArea
    let teams: [NearbyTeam]
    let focusedID: NearbyTeamID?
    let onFocus: (NearbyTeamID) -> Void
    let items: [RoamMapItem]
    let selectedExtraID: String?
    let onSelectExtra: ((RoamMapItem) -> Void)?
    init(center: RoamSearchArea, teams: [NearbyTeam], focusedID: NearbyTeamID?, items: [RoamMapItem] = [],
         selectedExtraID: String? = nil, onSelectExtra: ((RoamMapItem) -> Void)? = nil,
         onFocus: @escaping (NearbyTeamID) -> Void) {
        self.center = center; self.teams = teams; self.focusedID = focusedID; self.items = items
        self.selectedExtraID = selectedExtraID; self.onSelectExtra = onSelectExtra; self.onFocus = onFocus
    }
    private var markers: [NearbyTeamMarker] { NearbyTeamBridge.markers(teams) }
    private var pins: [SearchMapPin] {
        let teamPins = markers.compactMap { marker -> SearchMapPin? in
            guard let coordinate = RoamCoordinate(latitude: marker.latitude, longitude: marker.longitude) else { return nil }
            return SearchMapPin(id: marker.id, title: marker.title, coordinate: coordinate, symbol: marker.active ? "person.3.fill" : "person.3")
        }
        let extraPins = items.compactMap { item -> SearchMapPin? in
            guard let coordinate = item.coordinate else { return nil }
            return SearchMapPin(id: "discovery-" + item.id, title: item.title, coordinate: coordinate, symbol: item.symbol)
        }
        return teamPins + extraPins
    }
    var body: some View {
        QuestifyDensityMap(area: center, pins: pins, selectedID: selectedExtraID.map { "discovery-" + $0 } ?? markers.first { $0.teamID == focusedID }?.id,
            mapHeight: 270, initialSpan: 0.045, pinIdentifierPrefix: "nearby.pin.",
            pinHint: { id in
                if let item = items.first(where: { "discovery-" + $0.id == id }) { return Text(item.kindLabel) }
                guard let marker = markers.first(where: { $0.id == id }) else { return Text("") }
                return marker.active ? Text("nearby.w208.badge.joined") : Text("nearby.title")
            }, onSelect: { id in
                if case .team(let teamID)? = NearbyTeamBridge.markerDestination(id), teams.contains(where: { $0.id == teamID }) {
                    onFocus(teamID)
                } else {
                    let rows = items.filter { "discovery-" + $0.id == id && $0.coordinate != nil }
                    if rows.count == 1, let item = rows.first { onSelectExtra?(item) }
                }
            })
            .accessibilityIdentifier("nearby.w208.map")
    }
}

struct NearbyTeamListHeader: View {
    let radius: Int
    let count: Int
    var body: some View {
        Text("nearby.w208.listHeader \(NearbyTeamPresentation.rangeText(radius)) \(count)")
            .cyText(.bodyMedium).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("nearby.w208.listHeader")
    }
}

/// List mode row: name, sub line, badge and joined/max; tapping opens the same team card inline.
struct NearbyTeamListRow: View {
    let team: NearbyTeam
    let expanded: Bool
    let toggle: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if NearbyTeamPresentation.heading(team).isEmpty { Text("nearby.untitled").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
                    else { Text(verbatim: NearbyTeamPresentation.heading(team)).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true) }
                    if typeSize >= .xxLarge {
                        VStack(alignment: .leading, spacing: 8) { NearbyTeamSubLine(team: team); NearbyTeamBadgeView(badge: NearbyTeamBadge(mode: team.mode)) }
                    } else {
                        HStack(spacing: 8) { NearbyTeamSubLine(team: team); NearbyTeamBadgeView(badge: NearbyTeamBadge(mode: team.mode)) }
                    }
                }
                Spacer(minLength: 8)
                Text(verbatim: "\(team.joinedCount)/\(team.maxMembers)").cyText(.numericBody).foregroundStyle(CYColor.textSecondary)
                Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).frame(minHeight: 44).accessibilityIdentifier("nearby.w208.row.\(team.id.rawValue)")
    }
}

/// Corner controls 范围 N km · 我的队伍 (· N).
struct NearbyTeamCornerBar: View {
    let radius: Int
    let mineCount: Int
    let openMine: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            CYStatusChip("nearby.w208.range \(NearbyTeamPresentation.rangeText(radius))", tone: .neutral, systemImage: "scope")
                .accessibilityIdentifier("nearby.w208.range")
            CYPillButton(mineCount > 0 ? "nearby.w208.myTeams.count \(mineCount)" : "nearby.w208.myTeams", style: .secondary, fullWidth: false, action: openMine)
                .accessibilityIdentifier("nearby.w208.myTeams")
        }
    }
}

struct NearbyTeamBadgeView: View {
    let badge: NearbyTeamBadge
    /// my-teams labels the viewer's own team 队长 rather than the map's 我带队.
    var captain = false
    var body: some View {
        CYStatusChip(LocalizedStringKey(captain ? "nearby.w208.badge.captain" : badge.key), tone: tone)
            .accessibilityIdentifier("nearby.w208.badge.\(badge.rawValue)")
    }
    private var tone: CYStatusTone {
        switch badge { case .joined: return .success; case .pending: return .warning; case .rejected: return .danger; case .leader: return .info; case .buy, .apply: return .neutral }
    }
}

/// `城市定向/自由探索 · {addr}集合/附近 · 距你 X km`.
struct NearbyTeamSubLine: View {
    let team: NearbyTeam
    private var line: Text {
        var parts: [Text] = []
        if let key = team.productLabelKey { parts.append(Text(LocalizedStringKey(key))) }
        if !team.addressName.isEmpty {
            parts.append(NearbyTeamPresentation.placeIsGather(team) ? Text("nearby.w208.place.gather \(team.addressName)") : Text("nearby.w208.place.near \(team.addressName)"))
        }
        if let distance = team.distance { parts.append(Text("nearby.w208.distance \(NearbyTeamPresentation.distanceText(distance))")) }
        guard var result = parts.first else { return Text(verbatim: "") }
        for part in parts.dropFirst() { result = result + Text(verbatim: " · ") + part }
        return result
    }
    var body: some View {
        if team.productLabelKey != nil || !team.addressName.isEmpty || team.distance != nil {
            line.cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// `队长 X · 已组 N 人 · 还差 M 人满员 / 已满员`.
struct NearbyTeamMembersLine: View {
    let team: NearbyTeam
    private var line: Text {
        let leader = team.leaderName.isEmpty ? Text("nearby.w208.members.leaderUnknown") : Text("nearby.w208.members.leader \(team.leaderName)")
        let left = NearbyTeamPresentation.remainingSeats(team)
        let seats = left > 0 ? Text("nearby.w208.members.left \(left)") : Text("nearby.w208.members.full")
        return leader + Text(verbatim: " · ") + Text("nearby.w208.members.joined \(team.joinedCount)") + Text(verbatim: " · ") + seats
    }
    var body: some View { line.cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("nearby.w208.members") }
}

/// Default-face stack. Remote avatar URLs are display data only and are not fetched by this surface.
struct NearbyTeamFaces: View {
    let count: Int
    var body: some View {
        HStack(spacing: -8) {
            // MP my-teams / nearby `avatarsOf`: up to three faces, the MP default /images/d_profile.png.
            ForEach(0..<max(0, min(3, count)), id: \.self) { _ in
                MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
            }
        }.accessibilityHidden(true)
    }
}

/// Card notice per read state (xcx `teamCardState`). Leader and unverified rows have none.
struct NearbyTeamNotice: View {
    let mode: String
    private var key: LocalizedStringKey? {
        switch mode {
        case "joined": return "nearby.w208.notice.joined"
        case "pending": return "nearby.w208.notice.pending"
        case "rejected": return "nearby.w208.notice.rejected"
        case "apply": return "nearby.w208.notice.apply"
        case "buy": return "nearby.w208.notice.buy"
        default: return nil
        }
    }
    var body: some View {
        if let key { Text(key).cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary).accessibilityIdentifier("nearby.w208.notice") }
    }
}

/// my-teams `members()`: 已组 j/m, or 已组 j 人 when capacity is unknown.
struct NearbyMineMembersText: View {
    let joined: Int?
    let maximum: Int?
    var body: some View {
        // A missing joined count is an em dash. A decoded 0 still uses the numeric keys.
        Group {
            if let joined, let maximum {
                Text("nearby.w208.mine.members \(joined) \(maximum)")
            } else if let joined {
                Text("nearby.w208.mine.membersOnly \(joined)")
            } else if let maximum {
                Text("nearby.w208.mine.membersUnknownCap \(maximum)")
            } else {
                Text("nearby.w208.mine.membersUnknown")
            }
        }
        .cyText(.meta)
        .foregroundStyle(CYColor.textTertiary)
    }
}

/// 附近在招募 under an empty 我的: NONE rows only, 需购票 / 可申请, 在地图上看.
struct NearbyRecruitingSection: View {
    let state: NearbyRecruitingLoad
    let teams: [NearbyTeam]
    let retry: () -> Void
    let openOnMap: (NearbyTeamID) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("nearby.w208.recruit.title").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("nearby.w208.recruit.title")
            switch state {
            case .idle: EmptyView()
            case .loading: CYLoadingStateView(rows: 1).accessibilityLabel(Text("nearby.w208.recruit.loading"))
            case .failed:
                CYPillButton("nearby.w208.recruit.failed", style: .secondary, action: retry).accessibilityIdentifier("nearby.w208.recruit.retry")
            case .noArea:
                CYPillButton("nearby.w208.recruit.noArea", style: .secondary, action: retry).accessibilityIdentifier("nearby.w208.recruit.retry")
            case .loaded:
                if teams.isEmpty { CYEmptyState(systemImage: "person.3", "nearby.w208.recruit.empty", messageIdentifier: "nearby.w208.recruit.empty") }
                ForEach(teams) { team in row(team) }
            }
        }
    }
    private func row(_ team: NearbyTeam) -> some View {
        Button { openOnMap(team.id) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    NearbyTeamFaces(count: NearbyTeamPresentation.faceCount(real: team.memberAvatars.count, members: team.joinedCount))
                    if team.title.isEmpty { Text("nearby.w208.mine.untitled").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) } else { Text(verbatim: team.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                    Spacer(minLength: 8)
                    NearbyTeamBadgeView(badge: NearbyTeamBadge(mode: team.mode))
                }
                NearbyTeamSubLine(team: team)
                HStack {
                    NearbyMineMembersText(joined: team.reportedJoinedCount, maximum: team.reportedMaxMembers)
                    Spacer()
                    Text("nearby.w208.recruit.onMap").cyText(.meta, weight: .semibold).foregroundStyle(CYColor.textPrimary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding()
                .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("nearby.w208.recruit.\(team.id.rawValue)")
    }
}
