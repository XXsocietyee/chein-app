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
                if state == .loading { ProgressView().accessibilityHidden(true) }
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
            }.fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.large)
            .disabled(state == .loading || state == .empty)
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
    /// MP `smap-more` 加载更多 inside the sheet, and the 更多活动加载失败 / 重试这一页 inline error above the list.
    var hasMore: Bool = false
    var loadingMore: Bool = false
    var pageFailed: Bool = false
    var loadMore: () -> Void = {}
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // MP order (pages/searchmap 全部结果 sheet): 正在更新商家节点… first, then error / empty / loading,
                    // then 正在更新地图结果…, the refresh or page inline error, the list and 加载更多.
                    if refreshing {
                        Text("searchMap.w208.sheet.refreshingNodes").font(.subheadline).foregroundStyle(.secondary)
                    }
                    if loading {
                        ProgressView("search.r3.loading.map").frame(maxWidth: .infinity).padding(.vertical)
                    } else if failed && rows.isEmpty {
                        ContentUnavailableView {
                            Label("searchMap.w208.sheet.failed", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text("searchMap.w208.sheet.failed.detail")
                        } actions: {
                            Button("searchMap.retry", action: retry).buttonStyle(.bordered)
                        }
                        .accessibilityIdentifier("searchMap.w208.sheet.failed")
                    } else if rows.isEmpty {
                        ContentUnavailableView {
                            Label("searchMap.w208.capsule.empty", systemImage: "mappin.slash")
                        } description: {
                            Text("searchMap.w208.sheet.emptyHint")
                        }
                        .accessibilityIdentifier("searchMap.w208.sheet.empty")
                    }
                    if refreshing && !rows.isEmpty {
                        ProgressView("searchMap.w208.sheet.refreshingActivities")
                    }
                    if refreshFailed {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("searchMap.w208.sheet.refreshFailed", systemImage: "exclamationmark.circle").font(.headline)
                            Text("searchMap.w208.sheet.refreshFailed.detail").font(.subheadline).foregroundStyle(.secondary)
                            Button("mapRefresh.retry", action: retry).buttonStyle(.bordered)
                        }.accessibilityIdentifier("searchMap.w208.sheet.refreshFailed")
                    } else if pageFailed && !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("mapPagination.failed", systemImage: "exclamationmark.circle").font(.headline)
                            Button("mapPagination.retry", action: loadMore).buttonStyle(.bordered)
                        }.accessibilityIdentifier("searchMap.w208.sheet.pageFailed")
                    }
                    let listOnly = rows.filter { !$0.hasValidCoordinates }.count
                    if listOnly > 0 {
                        Text("searchMap.w208.sheet.listOnlyTip \(listOnly)").font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("searchMap.w208.sheet.listOnlyTip")
                    }
                    ForEach(rows) { row in
                        Button { open(row) } label: { SearchMapActivityCard(item: row, offline: offline) }
                            .buttonStyle(.plain)
                            // R7-PC-A5-5: MP result-card address opens the place in the map app.
                            .modifier(HomeFeedOpenPlaceInMaps(url: SearchMapPlaceLink.url(for: row), openURL: openURL))
                            .accessibilityIdentifier("searchMap.w208.sheet.activity.\(row.id)")
                        // R7-PC-A5-5 (r8): the address is also a visible tap target, not long-press only.
                        if let placeURL = SearchMapPlaceLink.url(for: row) {
                            Link(destination: placeURL) {
                                Label("accountCollection.coupon.openInMaps", systemImage: "map")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .accessibilityIdentifier("searchMap.w208.sheet.openInMaps.\(row.id)")
                        }
                    }
                    if hasMore && !rows.isEmpty && (!pageFailed || refreshFailed) {
                        Button {
                            loadMore()
                        } label: {
                            if loadingMore {
                                ProgressView("mapPagination.loading")
                            } else {
                                Text("mapPagination.more")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(loadingMore)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("searchMap.w208.sheet.more")
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
