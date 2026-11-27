import MapKit
import SwiftUI

/// `RNEAR-2` / `RNEAR-7`: Full-bleed nearby teams map with leader pins and draggable `.sheet`
/// (`presentationDetents([.height(64), .medium, .large])`).
public struct NearbyTeamsMapSheetView: View {
    public let teams: [NearbyTeamMapPin]
    @Binding public var selectedRadiusKM: Int
    @State private var isSheetPresented = true
    @State private var selectedTeamID: Int?

    public var onOpenMyTeams: () -> Void
    public var onSelectTeam: (NearbyTeamMapPin) -> Void

    public init(
        teams: [NearbyTeamMapPin],
        selectedRadiusKM: Binding<Int>,
        onOpenMyTeams: @escaping () -> Void = {},
        onSelectTeam: @escaping (NearbyTeamMapPin) -> Void = { _ in }
    ) {
        self.teams = teams
        self._selectedRadiusKM = selectedRadiusKM
        self.onOpenMyTeams = onOpenMyTeams
        self.onSelectTeam = onSelectTeam
    }

    public var body: some View {
        Map {
            ForEach(teams) { team in
                Annotation(
                    team.teamName,
                    coordinate: CLLocationCoordinate2D(latitude: team.latitude, longitude: team.longitude)
                ) {
                    Button {
                        selectedTeamID = team.id
                        onSelectTeam(team)
                    } label: {
                        // TODO: MPAsset.Avatar.dProfile (`images/d_profile.png`) when cursor/mp-assets lands
                        CYAvatarView(
                            url: URL(string: team.leaderAvatarURL ?? ""),
                            name: team.leaderName,
                            size: .sm,
                            showAccentRing: selectedTeamID == team.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("nearby.radius", selection: $selectedRadiusKM) {
                        Text("1 km").tag(1)
                        Text("3 km").tag(3)
                        Text("5 km").tag(5)
                    }
                    Button("nearby.myTeams", action: onOpenMyTeams)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .accessibilityLabel(Text("nearby.radius"))
                        .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                }
            }
        }
        .sheet(isPresented: $isSheetPresented) {
            List {
                Section("附近共有 \(teams.count) 支队伍") {
                    if teams.isEmpty {
                        ContentUnavailableView("nearby.empty", systemImage: "person.3")
                    } else {
                        ForEach(teams) { team in
                            Button {
                                onSelectTeam(team)
                            } label: {
                                HStack(spacing: CYSpacing.sm) {
                                    // TODO: MPAsset.Avatar.dProfile (`images/d_profile.png`) when cursor/mp-assets lands
                                    CYAvatarView(
                                        url: URL(string: team.leaderAvatarURL ?? ""),
                                        name: team.leaderName,
                                        size: .sm
                                    )
                                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                        Text(team.teamName).cyText(.cardTitle)
                                        Text("队长 \(team.leaderName)")
                                            .cyText(.meta)
                                            .foregroundStyle(CYColor.textSecondary)
                                    }
                                    Spacer()
                                    Text("\(team.memberCount)/\(team.capacity)")
                                        .cyText(.numericBody, monospacedDigit: true)
                                        .foregroundStyle(CYColor.brand)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .presentationDetents([.height(64), .medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .interactiveDismissDisabled()
        }
        .cyPageTitle("nearby.title")
    }
}

/// `RHIST-1` / `RHIST-2`: Merged server + local roam history with partial-failure banner & paging.
public struct RoamMergedHistoryListView: View {
    public let rows: [MergedRoamHistoryRow]
    public let hasPartialServerError: Bool
    public let hasMore: Bool
    public let isLoadingMore: Bool
    public var onRetryServer: () -> Void
    public var onLoadMore: () -> Void
    public var onSelectRow: (MergedRoamHistoryRow) -> Void

    public init(
        rows: [MergedRoamHistoryRow],
        hasPartialServerError: Bool = false,
        hasMore: Bool = false,
        isLoadingMore: Bool = false,
        onRetryServer: @escaping () -> Void = {},
        onLoadMore: @escaping () -> Void = {},
        onSelectRow: @escaping (MergedRoamHistoryRow) -> Void = { _ in }
    ) {
        self.rows = rows
        self.hasPartialServerError = hasPartialServerError
        self.hasMore = hasMore
        self.isLoadingMore = isLoadingMore
        self.onRetryServer = onRetryServer
        self.onLoadMore = onLoadMore
        self.onSelectRow = onSelectRow
    }

    public var body: some View {
        List {
            if hasPartialServerError {
                Section {
                    HStack {
                        Text("roamSub.w208.history.partialError")
                            .cyText(.meta)
                        Spacer()
                        Button("common.retry", action: onRetryServer)
                            .cyText(.label)
                    }
                }
            }

            if rows.isEmpty {
                ContentUnavailableView("roamHistory.empty", systemImage: "figure.walk")
            } else {
                ForEach(rows) { row in
                    Button {
                        onSelectRow(row)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(row.title).cyText(.cardTitle)
                                Text(row.durationText)
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                            Spacer()
                            Text(String(format: "%.1f km", row.distanceKM))
                                .cyText(.numericBody, monospacedDigit: true)
                        }
                    }
                }

                if hasMore {
                    Button {
                        onLoadMore()
                    } label: {
                        HStack {
                            Spacer()
                            CYBusyLabel(busy: isLoadingMore) {
                                Text("common.loadMore").cyText(.label)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoadingMore)
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyPageTitle("roamHistory.title")
    }
}
