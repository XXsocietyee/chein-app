import SwiftUI

/// `components/cy/map-address-search` remote leg: after 350 ms of no typing, keyword ≥ 2, near the map centre.
/// Results follow the local ones with same-name rows removed; at most five rows are shown.
@MainActor final class MapPlaceSearchModel: ObservableObject {
    @Published private(set) var places: [MapSearchPlayerService.Place] = []
    @Published private(set) var searching = false
    @Published private(set) var remoteError = false
    private var token = 0
    static let maxResults = 5

    func search(_ keyword: String, latitude: Double, longitude: Double, localNames: Set<String>, client: PlayerCapabilityClient) async {
        token += 1
        let current = token
        guard keyword.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2, latitude != 0, longitude != 0 else {
            searching = false; remoteError = false; places = []; return
        }
        searching = true; remoteError = false
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard current == token, !Task.isCancelled else { return }
        do {
            let rows = try await MapSearchPlayerService(client: client)
                .placeSearch(keyword: keyword, latitude: latitude, longitude: longitude, localNames: localNames)
            guard current == token else { return }
            places = Array(rows.prefix(Self.maxResults))
        } catch {
            guard current == token else { return }
            remoteError = true; places = []
        }
        searching = false
    }
}

// Map weather ambience moved to `App/NativeR2/MapHome/MapWeatherLayer.swift` (fix/1128c-ai-weather: particles,
// chip, WeatherKit and the `WeatherContext` hand-off).

/// `open-address.js`: open a text-only address in Maps after `api/map/geocode`; 「暂时无法定位」 on failure.
struct GeocodedAddressButton: View {
    let name: String
    let address: String
    let city: String
    let client: PlayerCapabilityClient
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @State private var missed = false
    @State private var busy = false

    var body: some View {
        Button {
            Task {
                busy = true
                if let point = await MapSearchPlayerService(client: client).geocode(address: address, region: city),
                   let url = URL(string: "maps://?ll=\(point.latitude),\(point.longitude)&q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                    missed = false; openURL(url)
                } else { missed = true }
                busy = false
            }
        } label: {
            Label { Text(verbatim: missed ? PlayerCapabilityCopy.text("暂时无法定位", "Can't find this place right now", locale) : address) } icon: { Image(systemName: "mappin.and.ellipse") }
        }
        .disabled(busy || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityIdentifier("map.geocode.open")
    }
}

/// `pages/search2/result` content leg: signed-in unified search over topic/activity (+post when community read is open).
struct UnifiedSearchResultsView: View {
    let keyword: String
    let cityCode: String
    let includePosts: Bool
    let client: PlayerCapabilityClient
    var open: (MapSearchPlayerService.SearchItem) -> Void = { _ in }
    @Environment(\.locale) private var locale
    @State private var items: [MapSearchPlayerService.SearchItem] = []
    @State private var page = 0
    @State private var hasMore = false
    @State private var loading = false
    @State private var error: String?
    @State private var unavailable = false

    private var types: [String] { includePosts ? ["topic", "activity", "post"] : ["topic", "activity"] }

    var body: some View {
        List {
            ForEach(items) { item in
                Button { open(item) } label: {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: item.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        Text(verbatim: (MapSearchPlayerService.typeLabels[item.type] ?? item.type) + " · " + item.detail)
                            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    }
                }
                .accessibilityIdentifier("search.unified.\(item.id)")
            }
            if hasMore { Button(PlayerCapabilityCopy.text("加载更多", "Load more", locale)) { Task { await load(page + 1) } }.disabled(loading) }
            if let error { Text(verbatim: error).foregroundStyle(CYColor.textSecondary) }
            if unavailable { Text(verbatim: PlayerCapabilityCopy.text("内容搜索暂未开放，可稍后重试", "Content search isn't open yet. Try again later.", locale)).foregroundStyle(CYColor.textSecondary) }
        }
        .task(id: keyword + "|" + cityCode) { items = []; page = 0; await load(1) }
    }

    private func load(_ next: Int) async {
        guard !loading else { return }
        loading = true; error = nil
        do {
            let result = try await MapSearchPlayerService(client: client).unifiedSearch(keyword: keyword, types: types, cityCode: cityCode, page: next)
            var seen = Set(items.map(\.id))
            items += result.items.filter { seen.insert($0.id).inserted }
            page = next; hasMore = MapSearchPlayerService.hasMore(result, pageNumber: next)
        } catch PlayerCapabilityFailure.rejected(let code, _) where code == 503 || code == 404 {
            unavailable = true; hasMore = false
        } catch PlayerCapabilityFailure.rejected(let code, _) where code == 403 {
            items = []; self.error = PlayerCapabilityCopy.text("当前账号无法读取这些内容", "This account can't view these results", locale)
        } catch {
            self.error = PlayerCapabilityCopy.text("内容搜索未完成，重试本页", "Search didn't finish. Try this page again.", locale)
        }
        loading = false
    }
}
