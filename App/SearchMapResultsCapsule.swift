import SwiftUI

/// Mini-program result capsule under the map. Failure retries; a settled result opens the sheet.
struct SearchMapResultsCapsuleView: View {
    let state: SearchMapResultCapsule
    let retry: () -> Void
    let open: () -> Void
    var body: some View {
        Button {
            if state.opensSheet { open() } else if state == .failed { retry() }
        } label: {
            HStack(spacing: 8) {
                if state == .loading { ProgressView().tint(CYColor.resultSpinner).accessibilityHidden(true) }
                switch state {
                case .results(let total, let listOnly) where listOnly == total:
                    // Mini-program: nothing mappable here, the rows still open in the list.
                    Text("searchMap.w208.capsule.empty")
                    Text("searchMap.w208.capsule.listOnly \(listOnly)").foregroundStyle(.secondary)
                case .results(let total, let listOnly):
                    Text("searchMap.w208.capsule.results \(total)")
                    if listOnly > 0 { Text("searchMap.w208.capsule.listOnly \(listOnly)").foregroundStyle(.secondary) }
                default:
                    Text(LocalizedStringKey(state.key))
                }
            }.cyText(.bodyMedium).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16).padding(.vertical, 10).frame(minHeight: 44)
                .background(CYColor.bgGlass, in: Capsule())
        }.buttonStyle(.plain).disabled(state == .loading || state == .empty)
            .accessibilityIdentifier("searchMap.w208.capsule")
    }
}

/// 全部 N 个结果 sheet. It renders the explorer's current rows only; it never reads by itself.
struct SearchMapAllResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let rows: [ActivitySummary]
    let loading: Bool
    let failed: Bool
    let refreshing: Bool
    let refreshFailed: Bool
    let offline: Bool
    let retry: () -> Void
    let open: (ActivitySummary) -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if refreshing {
                        ProgressView("searchMap.w208.sheet.refreshingActivities")
                        Text("searchMap.w208.sheet.refreshingNodes").cyText(.bodyCompact).foregroundStyle(.secondary)
                    }
                    if refreshFailed {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("searchMap.w208.sheet.refreshFailed", systemImage: "exclamationmark.circle").cyText(.cardTitle)
                            Text("searchMap.w208.sheet.refreshFailed.detail").cyText(.bodyCompact).foregroundStyle(.secondary)
                            Button("mapRefresh.retry", action: retry).frame(minHeight: 44)
                        }.accessibilityIdentifier("searchMap.w208.sheet.refreshFailed")
                    }
                    if loading {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 20).fill(.secondary.opacity(0.1)).frame(height: 96).accessibilityHidden(true)
                        }
                    } else if failed && rows.isEmpty {
                        CYErrorStateView(
                            systemImage: "exclamationmark.triangle",
                            title: "searchMap.w208.sheet.failed",
                            message: "searchMap.w208.sheet.failed.detail",
                            retryTitle: "searchMap.retry",
                            onRetry: retry
                        )
                        .accessibilityIdentifier("searchMap.w208.sheet.failed")
                    } else if rows.isEmpty {
                        CYEmptyStateView(
                            systemImage: "mappin.slash",
                            title: "searchMap.w208.capsule.empty",
                            description: "searchMap.w208.sheet.emptyHint"
                        )
                        .accessibilityIdentifier("searchMap.w208.sheet.empty")
                    }
                    let listOnly = rows.filter { !$0.hasValidCoordinates }.count
                    if listOnly > 0 {
                        Text("searchMap.w208.sheet.listOnlyTip \(listOnly)").cyText(.bodyCompact).foregroundStyle(.secondary)
                            .accessibilityIdentifier("searchMap.w208.sheet.listOnlyTip")
                    }
                    ForEach(rows) { row in
                        Button { open(row) } label: { SearchMapActivityCard(item: row, offline: offline) }
                            .buttonStyle(QuestifyCardButtonStyle())
                            // R7-PC-A5-5: MP result-card address opens the place in the map app.
                            .modifier(HomeFeedOpenPlaceInMaps(url: SearchMapPlaceLink.url(for: row), openURL: openURL))
                            .accessibilityIdentifier("searchMap.w208.sheet.activity.\(row.id)")
                        // R7-PC-A5-5 (r8): the address is also a visible tap target, not long-press only.
                        if let placeURL = SearchMapPlaceLink.url(for: row) {
                            Link(destination: placeURL) {
                                Label("accountCollection.coupon.openInMaps", systemImage: "map")
                                    .cyText(.label).frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                            }
                            .accessibilityIdentifier("searchMap.w208.sheet.openInMaps.\(row.id)")
                        }
                    }
                }.padding()
            }
            .navigationTitle(rows.isEmpty ? Text("searchMap.w208.sheet.title") : Text("searchMap.w208.sheet.titleCount \(rows.count)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("searchMap.cancel") { dismiss() }.accessibilityIdentifier("searchMap.w208.sheet.close")
                }
            }
        }
    }
}

/// Apple Maps link for a result: the coordinate when valid (with the place name), else the address text.
enum SearchMapPlaceLink {
    static func url(for row: ActivitySummary) -> URL? {
        let name = [row.addressName, row.address, row.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        guard row.hasValidCoordinates, let lat = row.latitude, let lng = row.longitude else {
            return HomeFeedMapsLink.url(for: row.addressName ?? row.address)
        }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "ll", value: "\(lat),\(lng)"), URLQueryItem(name: "q", value: name ?? "\(lat),\(lng)")]
        return components?.url
    }
}
